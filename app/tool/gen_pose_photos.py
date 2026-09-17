# -*- coding: utf-8 -*-
"""姿势照片 Wikimedia 备源（V4 / D65、D77）：Pexels 抓不到的槽位用 Commons 实拍补图。

网络：Wikimedia DNS 被污染，全部请求经 tool/doh.py（Cloudflare DoH）解析。
许可：仅接受 CC0 / Public Domain / CC BY（**排除 CC BY-SA / NC / ND**，D76）。
输出：与 gen_pose_photos.dart 同一清单结构——覆盖 assets/content/poses3/photos/<id>.jpg，
      更新 photos_manifest.json 对应条目，重建 attribution.json（保留非 poses3 条目，按 file 去重），
      并删除被替换照片的骨架产物（<id>.skeleton.json / <id>.overlay.png）。

用法（工作目录 app/，需先 pip install pillow）：
  python tool/gen_pose_photos.py wikimedia --ids p084 --query "ballet dancer jumping"
  python tool/gen_pose_photos.py wikimedia --ids p084,p109 --query "dancer" --thumb-width 1280
  python tool/gen_pose_photos.py search --query "ballet dancer" [--limit 20]
"""
import argparse
import io
import json
import os
import sys

from PIL import Image, ImageOps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import doh  # noqa: E402

POSE_DIR = os.path.join('assets', 'content', 'poses3')
PHOTOS_DIR = os.path.join(POSE_DIR, 'photos')
MANIFEST = os.path.join(POSE_DIR, 'photos_manifest.json')
ATTRIBUTION = os.path.join('assets', 'content', 'attribution.json')
MANAGED_PREFIX = 'assets/content/poses3/photos/'
MAX_EDGE = 1080
MAX_BYTES = 250 * 1024

API = 'https://commons.wikimedia.org/w/api.php'


def read_json(path, fallback):
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return fallback


def write_json(path, payload):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)


def strip_html(value):
    import re
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]*>', ' ', str(value))).strip()


def license_ok(name):
    """严格许可白名单：CC0 / PD / CC BY（排除 SA/NC/ND）。"""
    import re
    s = re.sub(r'[\s_\-]+', ' ', str(name).lower()).strip()
    toks = set(s.split())
    if 'cc0' in toks or s.startswith('cc0') or 'public domain' in s:
        return True
    if 'cc' in toks and 'by' in toks:
        return not ({'sa', 'nc', 'nd'} & toks)
    if 'pd' in toks or s == 'pd' or s.startswith('pd '):
        return True
    return False


def api(params):
    import urllib.parse
    query = urllib.parse.urlencode(params)
    raw = doh.fetch('%s?%s' % (API, query), timeout=40, retries=4)
    return json.loads(raw.decode('utf-8', 'replace'))


def search(query, limit=20, thumb_width=1280):
    """Commons 文件搜索，返回许可合格的候选（未去重）。"""
    payload = api({
        'action': 'query', 'format': 'json', 'generator': 'search',
        'gsrsearch': '%s filetype:bitmap' % query, 'gsrnamespace': '6',
        'gsrlimit': str(limit), 'prop': 'imageinfo',
        'iiprop': 'url|extmetadata|mime', 'iiurlwidth': str(thumb_width),
    })
    pages = ((payload.get('query') or {}).get('pages') or {})
    out = []
    for page in pages.values():
        info_list = page.get('imageinfo') or []
        if not info_list:
            continue
        info = info_list[0]
        if not str(info.get('mime', '')).startswith('image/'):
            continue
        meta = info.get('extmetadata') or {}
        def meta_value(key):
            return strip_html((meta.get(key) or {}).get('value', ''))
        license_name = meta_value('LicenseShortName')
        if not license_ok(license_name):
            continue
        title = page.get('title', '')
        out.append({
            'title': title,
            'pageUrl': 'https://commons.wikimedia.org/wiki/%s' % title.replace(' ', '_'),
            'imageUrl': info.get('thumburl') or info.get('url') or '',
            'license': license_name or 'Public domain',
            'author': meta_value('Artist') or 'Wikimedia Commons contributor',
            'alt': meta_value('ImageDescription'),
        })
    return out


def compress_jpeg(raw, max_edge=MAX_EDGE, max_bytes=MAX_BYTES):
    image = Image.open(io.BytesIO(raw))
    image = ImageOps.exif_transpose(image).convert('RGB')
    if max(image.size) > max_edge:
        if image.width >= image.height:
            image = image.resize((max_edge, max(1, round(image.height * max_edge / image.width))), Image.LANCZOS)
        else:
            image = image.resize((max(1, round(image.width * max_edge / image.height)), max_edge), Image.LANCZOS)
    for quality in (88, 84, 80, 74, 68, 62, 56, 50):
        buf = io.BytesIO()
        image.save(buf, format='JPEG', quality=quality, optimize=True)
        if buf.tell() <= max_bytes:
            return buf.getvalue()
    return buf.getvalue()


def rebuild_attribution(manifest):
    root = read_json(ATTRIBUTION, {})
    items = [i for i in (root.get('items') or []) if isinstance(i, dict)
             and not str(i.get('file', '')).startswith(MANAGED_PREFIX)]
    for entry in manifest.get('photos', []):
        items.append({
            'file': entry.get('photo', ''),
            'name': entry.get('name', '姿势参考'),
            'source': entry.get('source', ''),
            'license': entry.get('license', ''),
            'author': entry.get('author', ''),
        })
    root['items'] = items
    if not str(root.get('note') or '').strip():
        root['note'] = '内置第三方素材署名（G6/V3）'
    write_json(ATTRIBUTION, root)
    return len(items)


def replace(ids, query, thumb_width=1280, limit=24, dry_run=False):
    manifest = read_json(MANIFEST, {})
    photos = manifest.get('photos') or []
    by_id = {p.get('id'): p for p in photos}
    missing = [i for i in ids if i not in by_id]
    if missing:
        print('[wikimedia] 清单中不存在：%s' % ','.join(missing))
    used = {(p.get('origin'), str(p.get('sourceId', ''))) for p in photos}
    candidates = [c for c in search(query, limit=limit, thumb_width=thumb_width)
                  if ('wikimedia', c['title']) not in used]
    print('[wikimedia] 查询 "%s" 命中 %d 个许可合格候选' % (query, len(candidates)))
    if dry_run:
        for c in candidates:
            print('  - %s [%s] %s' % (c['title'], c['license'], c['author'][:60]))
        return 0
    replaced = []
    for pid in ids:
        entry = by_id.get(pid)
        if not entry:
            continue
        pick = None
        while candidates:
            cand = candidates.pop(0)
            if ('wikimedia', cand['title']) in used:
                continue
            pick = cand
            break
        if pick is None:
            print('[wikimedia] %s 无可用候选（查询 %s）' % (pid, query))
            continue
        try:
            raw = doh.fetch(pick['imageUrl'], timeout=60, retries=4)
            jpeg = compress_jpeg(raw)
        except Exception as exc:  # noqa: BLE001
            print('[wikimedia] %s 下载/压缩失败：%s' % (pid, exc))
            continue
        target = os.path.join(PHOTOS_DIR, '%s.jpg' % pid)
        with open(target, 'wb') as fh:
            fh.write(jpeg)
        for suffix in ('.skeleton.json', '.overlay.png', '.combo.png'):
            stale = os.path.join(PHOTOS_DIR, '%s%s' % (pid, suffix))
            if os.path.exists(stale):
                os.remove(stale)
        entry.update({
            'source': pick['pageUrl'],
            'license': pick['license'],
            'author': pick['author'],
            'origin': 'wikimedia',
            'sourceId': pick['title'],
            'query': query,
            'alt': pick['alt'][:400],
        })
        used.add(('wikimedia', pick['title']))
        replaced.append(pid)
        print('[wikimedia] %s ← %s [%s] %s（%.0f KB）' % (
            pid, pick['title'], pick['license'], pick['author'][:40], len(jpeg) / 1024))
    manifest['generatedAt'] = __import__('time').strftime('%Y-%m-%dT%H:%M:%SZ', __import__('time').gmtime())
    manifest['total'] = len(photos)
    write_json(MANIFEST, manifest)
    total_attr = rebuild_attribution(manifest)
    print('[wikimedia] 替换 %d 张；manifest 共 %d 条；attribution 共 %d 条' % (len(replaced), len(photos), total_attr))
    return 0 if replaced else 1


def main(argv=None):
    ap = argparse.ArgumentParser(description='Wikimedia Commons 备源补图（DoH）')
    ap.add_argument('command', choices=['wikimedia', 'search'])
    ap.add_argument('--ids', default='')
    ap.add_argument('--query', required=True)
    ap.add_argument('--limit', type=int, default=24)
    ap.add_argument('--thumb-width', type=int, default=1280)
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args(argv)
    doh.install()
    if args.command == 'search':
        for c in search(args.query, limit=args.limit, thumb_width=args.thumb_width):
            print('%s [%s] %s\n    %s' % (c['title'], c['license'], c['author'][:70], c['imageUrl']))
        return 0
    ids = [s.strip() for s in args.ids.split(',') if s.strip()]
    if not ids:
        ap.error('wikimedia 需要 --ids p001,p002')
    return replace(ids, args.query, thumb_width=args.thumb_width, limit=args.limit, dry_run=args.dry_run)


if __name__ == '__main__':
    sys.exit(main())
