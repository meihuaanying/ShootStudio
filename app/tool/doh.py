#!/usr/bin/env python3
"""DoH（DNS over HTTPS）下载辅助 + 解析补丁（Q1b 写实模式 / V4 产品图抓取）。

背景（本次实测）：
  * static.makehumancommunity.org / download.blender.org 经普通 DNS 可达，但
    Wikimedia / Blender 官方站等域名存在 DNS 污染风险，统一走 DoH 更稳。
  * files2.makehumancommunity.org 的大文件（如 makehuman_system_assets_cc0.zip，
    280,737,770 B）在单连接下常被中途截断（十余 MB 后 HTTP 200 提前结束），
    但支持 Range（HTTP 206 / Accept-Ranges: bytes），故提供分块并行 + 校验。
  * Wikimedia（commons/upload/wikipedia）DNS 被污染（198.18.x.x），Python 侧
    requests 抓取必须先 `install()` 打 socket.getaddrinfo 补丁（DoH JSON + 缓存
    + 直连回退），见下文「DoH 解析补丁」。

用法：
  # 单文件（自动分块并行，断点续传，末尾校验字节数）
  python tool/doh.py get <url> <输出路径> [--size N] [--chunk 10000000] [--jobs 6]

  # 只做 HEAD（打印状态码 / Content-Length），用于记录 URL→状态码证据
  python tool/doh.py head <url>

  # 解析页面里的下载链接（用于 MakeHuman 这类“链接需从页面解析”的站点）
  python tool/doh.py links <页面url> [关键词]

  # 解析主机名（DoH）并打印 A 记录
  python tool/doh.py resolve <host> [host...]

  # Python 侧：
  from doh import install; install()
  import requests; requests.get('https://commons.wikimedia.org/...')

依赖：系统 curl（Windows 10+ 自带）+ Python 3 标准库；DoH 端点使用 Cloudflare 1.1.1.1。
"""
import argparse
import concurrent.futures
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time

DOH_URL = "https://1.1.1.1/dns-query"
USER_AGENT = "ShootStudio-doh/1.0"


def curl_base() -> list:
    exe = shutil.which("curl") or shutil.which("curl.exe")
    if not exe:
        raise RuntimeError("未找到 curl（Windows 10+ 自带，或安装 curl 后重试）")
    return [exe, "-sS", "-L", "--doh-url", DOH_URL, "-A", USER_AGENT]


def head(url: str) -> dict:
    cmd = curl_base() + ["-I", "--max-time", "60", url]
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    text = out.stdout or ""
    code = ""
    length = None
    accept_ranges = ""
    for line in text.splitlines():
        low = line.lower()
        if low.startswith("http/"):
            code = line.split()[1] if len(line.split()) > 1 else ""
        elif low.startswith("content-length:"):
            try:
                length = int(line.split(":", 1)[1].strip())
            except ValueError:
                pass
        elif low.startswith("accept-ranges:"):
            accept_ranges = line.split(":", 1)[1].strip()
    return {"url": url, "status": code, "contentLength": length, "acceptRanges": accept_ranges,
            "raw": text.strip().splitlines()[:12]}


def links(url: str, keyword: str = "") -> list:
    cmd = curl_base() + ["--max-time", "60", url]
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    found = []
    for href in re.findall(r'href="([^"]+)"', out.stdout or ""):
        if keyword and keyword.lower() not in href.lower():
            continue
        if re.search(r"\.(zip|exe|7z|tgz|tar\.gz|msi)(\?|$)", href, re.I):
            found.append(href)
    return found


def _fetch_range(url: str, start: int, end: int, dest: str, retries: int = 5) -> int:
    if os.path.exists(dest) and os.path.getsize(dest) == end - start + 1:
        return os.path.getsize(dest)
    cmd = curl_base() + ["--retry", str(retries), "--retry-all-errors", "--max-time", "600",
                         "-r", f"{start}-{end}", "-o", dest, url]
    last = None
    for attempt in range(retries):
        try:
            subprocess.run(cmd, check=True, capture_output=True)
        except subprocess.CalledProcessError as exc:
            last = exc
            continue
        if os.path.exists(dest) and os.path.getsize(dest) == end - start + 1:
            return os.path.getsize(dest)
    raise RuntimeError(f"分块下载失败 {start}-{end}: {last}")


def get(url: str, dest: str, size: int = 0, chunk: int = 10_000_000, jobs: int = 6) -> str:
    if not size:
        info = head(url)
        size = info["contentLength"] or 0
        print(f"[doh] HEAD {url} -> {info['status']} size={size} ranges={info['acceptRanges']}")
    if not size:
        cmd = curl_base() + ["--max-time", "900", "-o", dest, url]
        subprocess.run(cmd, check=True)
        print(f"[doh] 单连接下载完成：{dest} {os.path.getsize(dest)} B")
        return dest

    os.makedirs(os.path.dirname(os.path.abspath(dest)) or ".", exist_ok=True)
    workdir = tempfile.mkdtemp(prefix="ss-doh-")
    ranges = []
    start = 0
    index = 0
    while start < size:
        end = min(start + chunk - 1, size - 1)
        ranges.append((index, start, end))
        start = end + 1
        index += 1

    parts = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
        futures = {}
        for i, s, e in ranges:
            part = os.path.join(workdir, f"part_{i:04d}")
            parts.append(part)
            futures[pool.submit(_fetch_range, url, s, e, part)] = i
        done = 0
        for fut in concurrent.futures.as_completed(futures):
            fut.result()
            done += 1
            if done % 5 == 0 or done == len(ranges):
                sys.stdout.write(f"\r[doh] 分块 {done}/{len(ranges)}")
                sys.stdout.flush()
    print()
    with open(dest, "wb") as out:
        for i, part in enumerate(parts):
            with open(part, "rb") as fh:
                shutil.copyfileobj(fh, out, 1024 * 1024)
    got = os.path.getsize(dest)
    if got != size:
        raise RuntimeError(f"下载大小不一致：期望 {size} 实际 {got}")
    shutil.rmtree(workdir, ignore_errors=True)
    print(f"[doh] 完成 {dest} {got} B（分块 {len(ranges)} × ≤{chunk}）")
    return dest


# ---------------------------------------------------------------------------
# DoH 解析补丁（V4 产品图抓取）：JSON 解析 + socket 猴子补丁 + 缓存 + 直连回退
# ---------------------------------------------------------------------------

DOH_ENDPOINTS = (
    "https://1.1.1.1/dns-query",
    "https://cloudflare-dns.com/dns-query",
    "https://dns.google/resolve",
)
DOH_CACHE_TTL = 3600.0

_doh_cache: dict = {}
_doh_cache_lock = threading.Lock()
_doh_installed = False
_doh_original_getaddrinfo = socket.getaddrinfo
_doh_local = threading.local()
_doh_stats = {"doh_hit": 0, "doh_query": 0, "fallback": 0, "failed": 0}


def _doh_cache_path() -> str:
    base = os.environ.get("SHOOTSTUDIO_DOH_CACHE") or os.path.join(
        tempfile.gettempdir(), "shootstudio_doh_cache.json")
    return base


def _doh_load_cache() -> None:
    path = _doh_cache_path()
    if not os.path.exists(path):
        return
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        now = time.time()
        with _doh_cache_lock:
            for host, rec in (data.get("hosts") or {}).items():
                ips = rec.get("ips") or []
                ts = float(rec.get("ts") or 0)
                if ips and now - ts < DOH_CACHE_TTL:
                    _doh_cache[str(host)] = (ts, [str(x) for x in ips])
    except Exception:
        pass


def _doh_save_cache() -> None:
    path = _doh_cache_path()
    try:
        with _doh_cache_lock:
            hosts = {h: {"ts": ts, "ips": ips}
                     for h, (ts, ips) in _doh_cache.items()}
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"hosts": hosts}, f)
        os.replace(tmp, path)
    except Exception:
        pass


def _doh_query_endpoint(endpoint: str, host: str, timeout: float) -> list:
    import urllib.parse
    import urllib.request
    params = {"name": host, "type": "A"}
    url = endpoint + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"accept": "application/dns-json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    ips = []
    for ans in data.get("Answer") or []:
        if int(ans.get("type") or 0) in (1, 28):
            ip = str(ans.get("data") or "").strip()
            if ip:
                ips.append(ip)
    return ips


def doh_resolve(host: str, timeout: float = 6.0) -> list:
    """DoH 解析主机名；失败返回 []（不抛出）。"""
    import urllib.request  # noqa: F401
    now = time.time()
    with _doh_cache_lock:
        rec = _doh_cache.get(host)
    if rec and now - rec[0] < DOH_CACHE_TTL:
        _doh_stats["doh_hit"] += 1
        return list(rec[1])
    for endpoint in DOH_ENDPOINTS:
        try:
            ips = _doh_query_endpoint(endpoint, host, timeout)
        except Exception:
            continue
        if ips:
            _doh_stats["doh_query"] += 1
            with _doh_cache_lock:
                _doh_cache[host] = (time.time(), ips)
            _doh_save_cache()
            return ips
    return []


def _doh_is_ip(name: str) -> bool:
    try:
        socket.inet_pton(socket.AF_INET, name)
        return True
    except OSError:
        pass
    try:
        socket.inet_pton(socket.AF_INET6, name)
        return True
    except OSError:
        return False


def _doh_getaddrinfo(host, port, family=0, type=0, proto=0, flags=0):
    try:
        name = host.decode("ascii") if isinstance(host, bytes) else str(host)
    except Exception:
        name = ""
    if (not name or name in ("localhost", "127.0.0.1", "::1")
            or _doh_is_ip(name)):
        return _doh_original_getaddrinfo(host, port, family, type, proto, flags)
    if getattr(_doh_local, "in_resolve", False):
        return _doh_original_getaddrinfo(host, port, family, type, proto, flags)
    _doh_local.in_resolve = True
    try:
        ips = doh_resolve(name)
    finally:
        _doh_local.in_resolve = False
    if not ips:
        _doh_stats["fallback"] += 1
        return _doh_original_getaddrinfo(host, port, family, type, proto, flags)
    results = []
    for ip in ips:
        try:
            if ":" in ip:
                if family not in (0, socket.AF_INET6):
                    continue
                results.append((socket.AF_INET6, type or socket.SOCK_STREAM,
                                proto or socket.IPPROTO_TCP, "", (ip, port, 0, 0)))
            else:
                if family not in (0, socket.AF_INET):
                    continue
                results.append((socket.AF_INET, type or socket.SOCK_STREAM,
                                proto or socket.IPPROTO_TCP, "", (ip, port)))
        except Exception:
            continue
    if not results:
        _doh_stats["failed"] += 1
        return _doh_original_getaddrinfo(host, port, family, type, proto, flags)
    return results


def install() -> None:
    """安装 socket.getaddrinfo 补丁（幂等）。所有 Wikimedia 抓取必须调用。"""
    global _doh_installed
    if _doh_installed:
        return
    _doh_load_cache()
    socket.getaddrinfo = _doh_getaddrinfo
    _doh_installed = True


def doh_stats() -> dict:
    return dict(_doh_stats)


def main() -> int:
    parser = argparse.ArgumentParser(prog="doh.py", description="DoH 下载辅助（见文件头注释）")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_get = sub.add_parser("get", help="下载（自动分块并行 + 校验）")
    p_get.add_argument("url")
    p_get.add_argument("dest")
    p_get.add_argument("--size", type=int, default=0)
    p_get.add_argument("--chunk", type=int, default=10_000_000)
    p_get.add_argument("--jobs", type=int, default=6)
    p_head = sub.add_parser("head", help="HEAD 探测（URL→状态码证据）")
    p_head.add_argument("url")
    p_links = sub.add_parser("links", help="解析页面内的下载链接")
    p_links.add_argument("url")
    p_links.add_argument("keyword", nargs="?", default="")
    p_resolve = sub.add_parser("resolve", help="DoH 解析主机名并打印 A 记录")
    p_resolve.add_argument("host", nargs="+")
    args = parser.parse_args()

    if args.cmd == "get":
        get(args.url, args.dest, args.size, args.chunk, args.jobs)
    elif args.cmd == "head":
        info = head(args.url)
        print(f"{info['status']} {info['url']} length={info['contentLength']} ranges={info['acceptRanges']}")
    elif args.cmd == "links":
        for link in links(args.url, args.keyword):
            print(link)
    elif args.cmd == "resolve":
        install()
        for host in args.host:
            ips = doh_resolve(host)
            print("%s -> %s" % (host, ", ".join(ips) if ips else "(DoH 失败，回退直连)"))
        print("stats: %s" % json.dumps(doh_stats()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
