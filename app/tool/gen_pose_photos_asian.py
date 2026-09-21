# -*- coding: utf-8 -*-
"""D122: replace the 120 pose reference photos with Asian subjects.

Sources:
  - Pexels API (primary, key from assets/config/image_sources.json)
  - Wikimedia Commons (fallback, CC0 / Public domain / CC BY only)

Rules:
  - keep ids p001..p120 and their categories; replace photo + manifest metadata
  - prefer portrait full-body photos (h/w >= 1.1, height >= 1000)
  - prefer alt text containing Asian-related words; never reuse a source id
  - normalize to max edge 1080 and <= 250 KB JPEG
  - drop stale <id>.skeleton.json / overlays so the MediaPipe pipeline re-runs
  - rewrite attribution.json entries for the replaced files

Usage (from app/):
  python tool/gen_pose_photos_asian.py --force
  python tool/gen_pose_photos_asian.py --ids p001,p002 --force
  python tool/gen_pose_photos_asian.py --ids p071 --force --query "asian woman lying down studio"
  python tool/gen_pose_photos_asian.py --ids p071 --force --source-id 8484012
  python tool/gen_pose_photos_asian.py --dry-run
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import doh  # noqa: E402

POSE_DIR = os.path.join('assets', 'content', 'poses3')
PHOTOS_DIR = os.path.join(POSE_DIR, 'photos')
MANIFEST = os.path.join(POSE_DIR, 'photos_manifest.json')
ATTRIBUTION = os.path.join('assets', 'content', 'attribution.json')
CONFIG = os.path.join('assets', 'config', 'image_sources.json')
QA_DIR = os.path.join('..', 'docs', 'pose-qa3')

MAX_EDGE = 1080
MAX_BYTES = 250 * 1024
MIN_HEIGHT = 1000
MIN_ASPECT = 1.1

ASIAN_HINTS = (
    'asian', 'japanese', 'korean', 'chinese', 'taiwanese', 'vietnamese',
    'thai', 'filipino',
)

CATEGORY_QUERIES = {
    'standing': [
        'asian woman standing full body studio',
        'asian man standing full body white background',
        'japanese woman standing pose fashion',
    ],
    'sitting': [
        'asian woman sitting pose full body studio',
        'asian man sitting chair studio',
        'korean woman sitting fashion portrait',
    ],
    'squat': [
        'asian woman squat pose studio',
        'asian man squat full body',
        'asian woman crouching street style',
    ],
    'kneeling': [
        'asian woman kneeling pose studio',
        'asian man kneeling',
        'japanese woman kneeling kimono',
    ],
    'leaning': [
        'asian woman leaning wall pose',
        'asian man leaning studio',
        'asian woman leaning model white background',
    ],
    'lying': [
        'asian woman lying down pose studio',
        'asian man lying floor studio',
        'asian woman lying fashion editorial',
    ],
    'dynamic': [
        'asian woman dancing jump motion',
        'asian dancer motion studio',
        'asian man martial arts kick',
    ],
    'hand': [
        'asian woman hand gesture portrait',
        'asian hands close up pose',
        'asian woman hands face studio',
    ],
    'expression': [
        'asian woman portrait expression studio',
        'asian man portrait studio',
        'japanese woman face closeup',
    ],
    'props': [
        'asian woman with umbrella pose',
        'asian woman with chair studio',
        'asian man with chair props studio',
    ],
}

PEXELS_SEARCH = 'https://api.pexels.com/v1/search'
COMMONS_API = 'https://commons.wikimedia.org/w/api.php'


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
        fh.write('\n')


def pexels_key():
    cfg = read_json(CONFIG, {})
    return str(((cfg.get('pexels') or {}).get('apiKey') or '')).strip()


def http_json(url, headers=None, timeout=40, retries=4):
    last = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers=headers or {})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode('utf-8', 'replace'))
        except Exception as exc:  # noqa: BLE001
            last = exc
            time.sleep(1.5 * attempt)
    raise RuntimeError('request failed: %s (%s)' % (url, last))


def pexels_search(key, query, page=1, per_page=30):
    params = urllib.parse.urlencode(
        {'query': query, 'per_page': per_page, 'page': page, 'orientation': 'portrait'}
    )
    payload = http_json(
        '%s?%s' % (PEXELS_SEARCH, params),
        headers={'Authorization': key, 'User-Agent': 'ShootStudio/1.2 (poses3)'},
    )
    return payload.get('photos') or []


def pexels_photo(key, photo_id):
    """按 id 直取单张（定向补图：检索排序不理想或已被 used 排除时用）。"""
    payload = http_json(
        'https://api.pexels.com/v1/photos/%s' % photo_id,
        headers={'Authorization': key, 'User-Agent': 'ShootStudio/1.2 (poses3)'},
    )
    return payload or None


def asian_score(alt):
    text = str(alt or '').lower()
    return sum(1 for hint in ASIAN_HINTS if hint in text)


def candidate_ok(photo):
    width = int(photo.get('width') or 0)
    height = int(photo.get('height') or 0)
    if width <= 0 or height <= 0:
        return False
    if height < MIN_HEIGHT:
        return False
    return height / width >= MIN_ASPECT


def to_jpeg(raw, max_edge=MAX_EDGE, max_bytes=MAX_BYTES):
    image = Image.open(io.BytesIO(raw))
    image = image.convert('RGB')
    if max(image.size) > max_edge:
        scale = max_edge / max(image.size)
        image = image.resize(
            (int(image.width * scale), int(image.height * scale)),
            Image.LANCZOS,
        )
    quality = 86
    while True:
        buffer = io.BytesIO()
        image.save(buffer, format='JPEG', quality=quality, optimize=True)
        data = buffer.getvalue()
        if len(data) <= max_bytes or quality <= 45:
            return data
        quality -= 8


def download(url, timeout=60, retries=4):
    last = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(
                url, headers={'User-Agent': 'ShootStudio/1.2 (poses3)'}
            )
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read()
        except Exception as exc:  # noqa: BLE001
            last = exc
            time.sleep(1.5 * attempt)
    raise RuntimeError('download failed: %s (%s)' % (url, last))


def commons_fallback(query, used_ids, want=1):
    """Commons backup; strict CC0/PD/CC BY licenses."""
    params = urllib.parse.urlencode(
        {
            'action': 'query',
            'format': 'json',
            'generator': 'search',
            'gsrsearch': '%s filetype:bitmap' % query,
            'gsrnamespace': '6',
            'gsrlimit': '20',
            'prop': 'imageinfo',
            'iiprop': 'url|extmetadata|mime',
            'iiurlwidth': '1400',
        }
    )
    try:
        raw = doh.fetch('%s?%s' % (COMMONS_API, params), timeout=40, retries=3)
        payload = json.loads(raw.decode('utf-8', 'replace'))
    except Exception:  # noqa: BLE001
        return []
    pages = ((payload.get('query') or {}).get('pages') or {})
    out = []
    for page in pages.values():
        infos = page.get('imageinfo') or []
        if not infos:
            continue
        info = infos[0]
        if not str(info.get('mime', '')).startswith('image/'):
            continue
        meta = info.get('extmetadata') or {}

        def meta_value(key):
            return re.sub(
                r'<[^>]*>', ' ',
                str((meta.get(key) or {}).get('value', '')),
            ).strip()

        license_name = meta_value('LicenseShortName')
        low = re.sub(r'[\s_\-]+', ' ', license_name.lower()).strip()
        toks = set(low.split())
        allowed = (
            'cc0' in toks
            or low.startswith('cc0')
            or 'public domain' in low
            or ('cc' in toks and 'by' in toks and not ({'sa', 'nc', 'nd'} & toks))
        )
        if not allowed:
            continue
        url = info.get('thumburl') or info.get('url')
        source_id = 'commons-%s' % page.get('pageid', '')
        if source_id in used_ids:
            continue
        out.append(
            {
                'origin': 'wikimedia',
                'source': 'https://commons.wikimedia.org/wiki/%s'
                % urllib.parse.quote(str(page.get('title', '')).replace(' ', '_')),
                'license': license_name or 'Public domain',
                'author': meta_value('Artist') or 'Wikimedia Commons',
                'imageUrl': url,
                'sourceId': source_id,
                'alt': meta_value('ImageDescription'),
            }
        )
        if len(out) >= want:
            break
    return out


def remove_artifacts(pose_id):
    for path in (
        os.path.join(PHOTOS_DIR, '%s.skeleton.json' % pose_id),
        os.path.join(PHOTOS_DIR, '%s.overlay.png' % pose_id),
        os.path.join(PHOTOS_DIR, '%s.combo.png' % pose_id),
        os.path.join(QA_DIR, 'overlay-%s.png' % pose_id),
        os.path.join(QA_DIR, 'compare-%s.png' % pose_id),
    ):
        if os.path.exists(path):
            os.remove(path)


def apply_photo(entry, pose_id, jpeg, meta):
    out_path = os.path.join(PHOTOS_DIR, '%s.jpg' % pose_id)
    with open(out_path, 'wb') as fh:
        fh.write(jpeg)
    with Image.open(io.BytesIO(jpeg)) as im:
        width, height = im.size
    entry.update(
        {
            'photo': 'assets/content/poses3/photos/%s.jpg' % pose_id,
            'source': meta['source'],
            'license': meta['license'],
            'author': meta['author'],
            'origin': meta['origin'],
            'sourceId': meta['sourceId'],
            'query': meta.get('query', ''),
            'alt': meta.get('alt', ''),
            'fetchedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'imageSize': [width, height],
        }
    )
    remove_artifacts(pose_id)
    return width, height


def main():
    parser = argparse.ArgumentParser(description='Replace pose photos with Asian subjects')
    parser.add_argument('--force', action='store_true')
    parser.add_argument('--ids', default='')
    parser.add_argument('--query', default='', help='覆盖检索词（单/少 id 定向补图时用）')
    parser.add_argument('--source-id', default='', help='直接指定 Pexels photo id（定向补图）')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--categories', default='')
    args = parser.parse_args()

    key = pexels_key()
    if not key:
        print('[asian] missing pexels.apiKey in %s' % CONFIG)
        return 2

    manifest = read_json(MANIFEST, {})
    photos = manifest.get('photos') or []
    if not photos:
        print('[asian] missing %s' % MANIFEST)
        return 2

    wanted = {x.strip() for x in args.ids.split(',') if x.strip()} or None
    cats = {x.strip() for x in args.categories.split(',') if x.strip()} or None
    used = {str(p.get('sourceId') or '') for p in photos if p.get('sourceId')}

    by_category = {}
    for p in photos:
        by_category.setdefault(str(p.get('categoryId') or ''), []).append(p)

    attribution = read_json(ATTRIBUTION, {'items': []})
    replaced = {}
    total = 0

    for category_id, entries in by_category.items():
        if cats is not None and category_id not in cats:
            continue
        targets = [
            e for e in entries
            if wanted is None or str(e.get('id')) in wanted
        ]
        if not targets:
            continue
        queries = [args.query] if args.query else (
            CATEGORY_QUERIES.get(category_id) or ['portrait pose asian']
        )
        candidates = []
        if args.source_id:
            photo = pexels_photo(key, args.source_id.strip())
            if photo:
                candidates.append((args.query or 'pexels:%s' % args.source_id, photo))
        else:
            for query in queries:
                for page in (1, 2):
                    try:
                        found = pexels_search(key, query, page=page)
                    except Exception as exc:  # noqa: BLE001
                        print('[asian] search failed "%s": %s' % (query, exc))
                        found = []
                    candidates.extend((query, photo) for photo in found if photo)
                    if len(candidates) >= len(targets) * 5:
                        break
                if len(candidates) >= len(targets) * 5:
                    break
        candidates.sort(
            key=lambda item: (asian_score(item[1].get('alt')),
                              int(item[1].get('height') or 0)),
            reverse=True,
        )

        index = 0
        for entry in targets:
            pose_id = str(entry.get('id'))
            # 单个候选下载失败时顺延下一个候选（Pexels 偶发 5xx / large2x 缺失）。
            while index < len(candidates):
                query, photo = candidates[index]
                index += 1
                source_id = str(photo.get('id') or '')
                if not source_id or source_id in used:
                    continue
                if not candidate_ok(photo):
                    continue
                if args.dry_run:
                    print('[dry] %s -> pexels %s asian=%d %s' % (
                        pose_id, source_id, asian_score(photo.get('alt')),
                        str(photo.get('alt'))[:56]))
                    used.add(source_id)
                    total += 1
                    break
                src = photo.get('src') or {}
                url = src.get('large2x') or src.get('original') or src.get('large')
                if not url:
                    continue
                try:
                    jpeg = to_jpeg(download(url))
                except Exception as exc:  # noqa: BLE001
                    print('[asian] %s download failed: %s' % (pose_id, exc))
                    continue
                meta = {
                    'source': str(photo.get('url') or ''),
                    'license': 'Pexels License',
                    'author': str(photo.get('photographer') or 'Pexels'),
                    'origin': 'pexels',
                    'sourceId': source_id,
                    'query': query,
                    'alt': str(photo.get('alt') or ''),
                }
                width, height = apply_photo(entry, pose_id, jpeg, meta)
                used.add(source_id)
                replaced['assets/content/poses3/photos/%s.jpg' % pose_id] = {
                    'file': 'assets/content/poses3/photos/%s.jpg' % pose_id,
                    'name': '姿势参考（%s）' % entry.get('category', ''),
                    'source': meta['source'],
                    'license': meta['license'],
                    'author': meta['author'],
                }
                total += 1
                print('[asian] %s <- pexels %s (%.0fx%.0f) asian=%d' % (
                    pose_id, source_id, width, height, asian_score(meta['alt'])))
                break

    if args.dry_run:
        print('[asian] dry-run: %d slots would be replaced' % total)
        return 0

    manifest['photos'] = photos
    manifest['generatedAt'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    manifest['note'] = (
        '姿势照片（V6/D122）：全部亚洲人；Pexels 主 + Wikimedia Commons 备（严格许可）；'
        'photo 为 app 根相对路径。'
    )
    write_json(MANIFEST, manifest)

    items = attribution.get('items') or []
    items = [
        it for it in items
        if str(it.get('file') or '') not in replaced
    ]
    items.extend(replaced.values())
    attribution['items'] = items
    attribution['note'] = (
        '素材许可登记（V6）：姿势照片为亚洲人（Pexels License / Wikimedia CC0/PD/CC BY）。'
    )
    write_json(ATTRIBUTION, attribution)

    print('[asian] replaced %d photos, attribution entries: %d' % (
        total, len(replaced)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
