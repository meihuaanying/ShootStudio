# -*- coding: utf-8 -*-
"""gear_photos_v3 公共设施：礼貌 HTTP、断点状态、图片校验与规范化。

约定（D129–D131 / R47 / R48）：
  - 抓取限速：同域请求间隔 >= MIN_INTERVAL 秒，失败退避重试；
  - 抓取产物（原图/规范图）只落 `tool/gear_photo_pool/`（不入 git）；
  - 入库元数据只写 `assets/content/gear/gear_photo_sources.json`（含来源/许可/时间）；
  - 一切网络访问可被 offline fixture 替换，保证测试离线可跑。
"""
from __future__ import annotations

import hashlib
import io
import json
import os
import re
import time
import urllib.parse
import urllib.request

from PIL import Image

UA = (
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0 Safari/537.36'
)
MIN_INTERVAL = 2.0
MAX_IMAGE_BYTES = 8 * 1024 * 1024
ALLOWED_MIME = ('image/jpeg', 'image/png', 'image/webp', 'image/bmp')
LONG_EDGE = 1100
JPEG_QUALITY = 84

APP_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPO_ROOT = os.path.dirname(APP_ROOT)
POOL_DIR = os.path.join(APP_ROOT, 'tool', 'gear_photo_pool', 'v3')
SOURCES_ASSET = os.path.join(APP_ROOT, 'assets', 'content', 'gear', 'gear_photo_sources.json')
GEAR_ASSET = os.path.join(APP_ROOT, 'assets', 'content', 'gear', 'gear.json')
PHOTOS2_ASSET = os.path.join(APP_ROOT, 'assets', 'content', 'gear', 'gear_photos2.json')

_last_request_at = 0.0


def offline() -> bool:
    """R48：离线 fixture 模式；开启后禁止任何联网（自测保证不依赖外网）。"""
    return os.environ.get('GEAR_V3_OFFLINE') == '1'


def now_iso() -> str:
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())


def ensure_dirs() -> None:
    os.makedirs(POOL_DIR, exist_ok=True)
    os.makedirs(os.path.join(POOL_DIR, 'raw'), exist_ok=True)
    os.makedirs(os.path.join(POOL_DIR, 'norm'), exist_ok=True)
    os.makedirs(os.path.join(POOL_DIR, 'sitemaps'), exist_ok=True)


def read_json(path: str, fallback):
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return fallback


def write_json(path: str, payload) -> None:
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write('\n')


class FetchError(RuntimeError):
    pass


def polite_get(url: str, timeout: int = 30, retries: int = 3, binary: bool = False,
               interval: float = MIN_INTERVAL, headers: dict = None):
    """全局限速 GET；binary=True 返回 (bytes, mime)，否则返回解码文本。"""
    if offline():
        raise FetchError('GEAR_V3_OFFLINE=1 离线模式禁止联网：%s' % url)
    global _last_request_at
    last_exc = None
    for attempt in range(1, retries + 1):
        wait = interval - (time.time() - _last_request_at)
        if wait > 0:
            time.sleep(wait)
        try:
            req_headers = {
                'User-Agent': UA,
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                'Accept': '*/*',
            }
            if headers:
                req_headers.update(headers)
            req = urllib.request.Request(url, headers=req_headers)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                data = resp.read()
                mime = str(resp.headers.get('Content-Type') or '').split(';')[0].strip().lower()
            _last_request_at = time.time()
            if binary:
                return data, mime
            return data.decode('utf-8', 'replace')
        except Exception as exc:  # noqa: BLE001
            _last_request_at = time.time()
            last_exc = exc
            time.sleep(1.5 * attempt)
    raise FetchError('GET failed: %s (%s)' % (url, last_exc))


def image_fingerprint(data: bytes) -> dict:
    """校验图片字节并给出指纹；非图片/过小直接抛错。"""
    if len(data) < 4096:
        raise FetchError('image too small: %d bytes' % len(data))
    if len(data) > MAX_IMAGE_BYTES:
        raise FetchError('image too large: %d bytes' % len(data))
    try:
        with Image.open(io.BytesIO(data)) as im:
            im.verify()
        with Image.open(io.BytesIO(data)) as im:
            width, height = im.size
            fmt = im.format or ''
    except Exception as exc:  # noqa: BLE001
        raise FetchError('not a valid image: %s' % exc) from exc
    return {
        'bytes': len(data),
        'width': width,
        'height': height,
        'format': fmt,
        'sha1': hashlib.sha1(data).hexdigest(),
    }


def normalize_jpeg(data: bytes, long_edge: int = LONG_EDGE,
                   quality: int = JPEG_QUALITY) -> bytes:
    """V4 规范：白底 4:3、长边 <=1100、JPEG q84、去 EXIF。"""
    with Image.open(io.BytesIO(data)) as im:
        im = im.convert('RGB')
        target = (long_edge, int(round(long_edge * 3 / 4)))
        scale = min(target[0] / im.width, target[1] / im.height)
        if scale < 1:
            im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))),
                           Image.LANCZOS)
        canvas = Image.new('RGB', target, (255, 255, 255))
        canvas.paste(im, ((target[0] - im.width) // 2, (target[1] - im.height) // 2))
        buf = io.BytesIO()
        canvas.save(buf, format='JPEG', quality=quality, optimize=True)
        return buf.getvalue()


def save_raw(gear_id: str, data: bytes, ext: str = '.jpg') -> str:
    ensure_dirs()
    path = os.path.join(POOL_DIR, 'raw', '%s%s' % (gear_id, ext))
    with open(path, 'wb') as fh:
        fh.write(data)
    return path


def save_norm(gear_id: str, data: bytes) -> str:
    path = os.path.join(POOL_DIR, 'norm', '%s.jpg' % gear_id)
    with open(path, 'wb') as fh:
        fh.write(normalize_jpeg(data))
    return path


def ext_from_mime(mime: str) -> str:
    return {
        'image/jpeg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'image/bmp': '.bmp',
    }.get(mime, '.jpg')


def norm_text(text: str) -> str:
    """型号/URL slug 归一：只留小写字母数字。"""
    return re.sub(r'[^a-z0-9]+', '', str(text or '').lower())


def slug_candidates(model: str, brand: str = '') -> list:
    """由型号生成可能的 URL slug（按优先级）。"""
    model = str(model or '')
    brand = str(brand or '')
    out = []
    for base in (model, '%s %s' % (brand, model)):
        parts = re.split(r'[\s/＋+]+', base.strip())
        for sep in ('', '-', '_'):
            s = norm_text(sep.join(parts))
            if s and s not in out:
                out.append(s)
    return out


def url_path_slug(url: str) -> str:
    path = urllib.parse.urlparse(url).path
    stem = os.path.splitext(path.rstrip('/').rsplit('/', 1)[-1])[0]
    return norm_text(stem)


class Bucket:
    """抓取台账：done/failed/attempts 落盘，支持断点续跑（D131）。"""

    def __init__(self, filename: str = 'state.json'):
        ensure_dirs()
        self.path = os.path.join(POOL_DIR, filename)
        data = read_json(self.path, {})
        self.done = dict(data.get('done') or {})
        self.failed = dict(data.get('failed') or {})
        self.attempts = dict(data.get('attempts') or {})

    def mark_done(self, gear_id: str, payload: dict) -> None:
        self.done[gear_id] = payload
        self.failed.pop(gear_id, None)
        self.save()

    def mark_failed(self, gear_id: str, reason: str) -> None:
        self.attempts[gear_id] = int(self.attempts.get(gear_id, 0)) + 1
        self.failed[gear_id] = {'reason': reason, 'attempts': self.attempts[gear_id],
                                'at': now_iso()}
        self.save()

    def save(self) -> None:
        write_json(self.path, {
            'updatedAt': now_iso(),
            'done': self.done,
            'failed': self.failed,
            'attempts': self.attempts,
        })
