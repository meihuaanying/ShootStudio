"""V7/D140：把姿势参考图中的「手部」「神态」两类替换为「杂志大片」「影视感」（Pexels 可商用杂志风）。

- 原地替换（保持 id 与总量 120）：hand p085–p096 → editorial（杂志大片）；expression p097–p108 → cinematic（影视感）。
- 源：Pexels（主，key 取自 assets/config/image_sources.json 的 pexels.apiKey）；许可仅 Pexels License / CC0 / PD / CC BY。
- 更新 photos_manifest.json（category/categoryId/name + 照片元数据 + candidatePool 新类目）与 attribution.json（逐图登记，R63）。
- 删除被替换图的旧骨架/叠加产物（R68：数据变更后需全量重跑骨架/关节/QA）。

用法（在 app/ 下执行）：
  python tool/gen_pose_photos_v7.py --force                 # 替换全部 24 张
  python tool/gen_pose_photos_v7.py --ids p085,p086         # 只替换指定 id
  python tool/gen_pose_photos_v7.py --categories editorial   # 按新类目筛选
  python tool/gen_pose_photos_v7.py --dry-run               # 只看候选，不下载
"""

import io
import json
import os
import sys
import time
import urllib.parse
import urllib.request

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

POSE_DIR = 'assets/content/poses3'
PHOTOS_DIR = POSE_DIR + '/photos'
MANIFEST = POSE_DIR + '/photos_manifest.json'
ATTRIBUTION = 'assets/content/attribution.json'
CONFIG = 'assets/config/image_sources.json'
QA_DIR = '../docs/pose-qa3'

MAX_EDGE = 1080
MAX_BYTES = 250 * 1024
MIN_HEIGHT = 1000
MIN_ASPECT = 1.1

ASIAN_HINTS = ('asian', 'japanese', 'korean', 'chinese', 'taiwanese',
               'vietnamese', 'thai', 'filipino')

PEXELS_SEARCH = 'https://api.pexels.com/v1/search'
PEXELS_PHOTO = 'https://api.pexels.com/v1/photos/%s'
UA = 'ShootStudio/1.2 (poses3-v7)'

# 旧类目 → 新类目（V7/D140）
CATEGORY_SWAP = {
    'hand': {
        'categoryId': 'editorial',
        'category': '杂志大片',
        'name': '杂志大片参考',
        'queries': [
            'asian woman editorial fashion magazine portrait',
            'asian man fashion editorial studio',
            'asian model high fashion pose studio',
            'asian woman magazine cover style',
        ],
    },
    'expression': {
        'categoryId': 'cinematic',
        'category': '影视感',
        'name': '影视感参考',
        'queries': [
            'asian woman cinematic portrait moody light',
            'asian man cinematic film still portrait',
            'korean woman dramatic portrait studio',
            'japanese woman neon portrait',
        ],
    },
}


def read_json(path, fallback):
    if not os.path.exists(path):
        return fallback
    with open(path, 'r', encoding='utf-8') as fh:
        return json.load(fh)


def write_json(path, payload):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write('\n')


def pexels_key():
    cfg = read_json(CONFIG, {})
    return str((cfg.get('pexels') or {}).get('apiKey') or '').strip()


def http_json(url, headers=None, timeout=40, retries=4):
    last = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers=headers or {'User-Agent': UA})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except Exception as exc:  # noqa: BLE001 - 网络重试
            last = exc
            time.sleep(1.5 * attempt)
    raise RuntimeError('request failed: %s (%s)' % (url, last))


def pexels_search(key, query, page=1, per_page=30):
    params = urllib.parse.urlencode({
        'query': query,
        'per_page': per_page,
        'page': page,
        'orientation': 'portrait',
    })
    headers = {'Authorization': key, 'User-Agent': UA}
    payload = http_json('%s?%s' % (PEXELS_SEARCH, params), headers=headers)
    return payload.get('photos') or []


def asian_score(alt):
    low = (alt or '').lower()
    return sum(1 for hint in ASIAN_HINTS if hint in low)


def candidate_ok(photo):
    width = int(photo.get('width') or 0)
    height = int(photo.get('height') or 0)
    if width <= 0 or height <= 0:
        return False
    if height < MIN_HEIGHT:
        return False
    return height / width >= MIN_ASPECT


def to_jpeg(raw, max_edge=MAX_EDGE, max_bytes=MAX_BYTES):
    image = Image.open(io.BytesIO(raw)).convert('RGB')
    if max(image.size) > max_edge:
        scale = max_edge / float(max(image.size))
        image = image.resize(
            (max(1, int(image.width * scale)), max(1, int(image.height * scale))),
            Image.LANCZOS,
        )
    quality = 86
    while True:
        buf = io.BytesIO()
        image.save(buf, format='JPEG', quality=quality, optimize=True)
        if buf.tell() <= max_bytes or quality <= 45:
            return buf.getvalue(), image.size
        quality -= 8


def download(url, timeout=60, retries=4):
    last = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': UA})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read()
        except Exception as exc:  # noqa: BLE001 - 网络重试
            last = exc
            time.sleep(1.5 * attempt)
    raise RuntimeError('download failed: %s (%s)' % (url, last))


def remove_artifacts(pose_id):
    for path in (
        '%s/%s.skeleton.json' % (PHOTOS_DIR, pose_id),
        '%s/%s.overlay.png' % (PHOTOS_DIR, pose_id),
        '%s/%s.combo.png' % (PHOTOS_DIR, pose_id),
        '%s/overlay-%s.png' % (QA_DIR, pose_id),
        '%s/compare-%s.png' % (QA_DIR, pose_id),
    ):
        if os.path.exists(path):
            os.remove(path)


def apply_photo(entry, pose_id, jpeg, meta):
    os.makedirs(PHOTOS_DIR, exist_ok=True)
    photo_path = '%s/%s.jpg' % (PHOTOS_DIR, pose_id)
    with open(photo_path, 'wb') as fh:
        fh.write(jpeg)
    with Image.open(photo_path) as image:
        width, height = image.size
    entry.update({
        'photo': 'assets/content/poses3/photos/%s.jpg' % pose_id,
        'source': meta['source'],
        'license': meta['license'],
        'author': meta['author'],
        'origin': meta['origin'],
        'sourceId': meta['sourceId'],
        'query': meta['query'],
        'alt': meta['alt'],
        'fetchedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'imageSize': [width, height],
    })
    remove_artifacts(pose_id)
    return width, height


def main():
    args = sys.argv[1:]

    def flag(name):
        return name in args

    def opt(name, default=None):
        if name in args:
            idx = args.index(name)
            if idx + 1 < len(args):
                return args[idx + 1]
        return default

    force = flag('--force')
    dry_run = flag('--dry-run')
    wanted_ids = None
    if opt('--ids'):
        wanted_ids = {p.strip() for p in opt('--ids').split(',') if p.strip()}
    query_override = opt('--query')
    source_id_override = opt('--source-id')
    wanted_cats = None
    if opt('--categories'):
        wanted_cats = {c.strip() for c in opt('--categories').split(',') if c.strip()}

    key = pexels_key()
    if not key:
        print('[v7] 缺少 Pexels API Key（assets/config/image_sources.json）', file=sys.stderr)
        return 2

    manifest = read_json(MANIFEST, {})
    photos = manifest.get('photos') or []
    if not photos:
        print('[v7] manifest 无 photos', file=sys.stderr)
        return 2

    pool = manifest.get('candidatePool') or {}
    attribution = read_json(ATTRIBUTION, {'items': []})
    items = attribution.get('items') or []

    used_ids = {str(p.get('sourceId')) for p in photos if p.get('sourceId')}
    replaced = {}
    total = 0
    new_pools = {}

    for old_cat, spec in CATEGORY_SWAP.items():
        if wanted_cats and old_cat not in wanted_cats and spec['categoryId'] not in wanted_cats:
            continue
        entries = [p for p in photos if p.get('categoryId') == old_cat]
        if force:
            entries += [p for p in photos if p.get('categoryId') == spec['categoryId']]
        targets = [
            e for e in entries
            if wanted_ids is None or str(e.get('id')) in wanted_ids
        ]
        if not targets:
            continue
        queries = [query_override] if query_override else spec['queries']
        candidates = []
        if source_id_override:
            candidates = [('pexels:%s' % source_id_override, {
                'id': int(source_id_override), 'width': 2000, 'height': 3000,
                'alt': '', 'photographer': 'Pexels',
                'url': 'https://www.pexels.com/photo/%s/' % source_id_override,
                'src': {}, '_direct': True,
            })]
        else:
            limit = len(targets) * 10
            for query in queries:
                for page in (1, 2, 3):
                    try:
                        found = pexels_search(key, query, page=page)
                    except Exception as exc:  # noqa: BLE001
                        print('[v7] search failed: %s (%s)' % (query, exc))
                        found = []
                    for photo in found:
                        candidates.append((query, photo))
                    if len(candidates) >= limit:
                        break
                if len(candidates) >= limit:
                    break
        candidates.sort(
            key=lambda item: (asian_score(item[1].get('alt')), int(item[1].get('height') or 0)),
            reverse=True,
        )
        pool.setdefault(spec['categoryId'], [])
        seen_pool = {str(c.get('sourceId')) for c in pool[spec['categoryId']]}
        for query, photo in candidates[:40]:
            src = photo.get('src') or {}
            sid = str(photo.get('id') or '')
            if not sid or sid in seen_pool:
                continue
            seen_pool.add(sid)
            pool[spec['categoryId']].append({
                'sourceId': sid,
                'query': query,
                'alt': (photo.get('alt') or '')[:120],
                'imageUrl': src.get('large') or src.get('original') or '',
            })
        new_pools[spec['categoryId']] = pool[spec['categoryId']]

        index = 0
        for slot_idx, entry in enumerate(targets, start=1):
            pose_id = str(entry.get('id'))
            if entry.get('categoryId') != old_cat and not force:
                continue
            placed = False
            while index < len(candidates):
                query, photo = candidates[index]
                index += 1
                source_id = str(photo.get('id') or '')
                if not source_id or source_id in used_ids:
                    continue
                if not photo.get('_direct') and not candidate_ok(photo):
                    continue
                # V6/D122 前提：参考图人物全部为亚洲人；alt 无亚洲线索的候选不采用（R70：不用近似图充数）。
                if not photo.get('_direct') and asian_score(photo.get('alt')) < 1:
                    continue
                if dry_run:
                    print('[dry] %s -> %s pexels %s asian=%d %s' % (
                        pose_id, spec['categoryId'], source_id,
                        asian_score(photo.get('alt')), (photo.get('alt') or '')[:56]))
                    used_ids.add(source_id)
                    total += 1
                    placed = True
                    break
                src = photo.get('src') or {}
                url = (src.get('large2x') or src.get('original') or src.get('large')
                       or 'https://images.pexels.com/photos/%s/pexels-photo-%s.jpeg' % (source_id, source_id))
                try:
                    raw = download(url)
                    jpeg, _size = to_jpeg(raw)
                except Exception as exc:  # noqa: BLE001
                    print('[v7] %s download failed: %s' % (pose_id, exc))
                    continue
                meta = {
                    'source': photo.get('url') or 'https://www.pexels.com/photo/%s/' % source_id,
                    'license': 'Pexels License',
                    'author': photo.get('photographer') or 'Pexels',
                    'origin': 'pexels',
                    'sourceId': source_id,
                    'query': query,
                    'alt': photo.get('alt') or '',
                }
                width, height = apply_photo(entry, pose_id, jpeg, meta)
                entry['category'] = spec['category']
                entry['categoryId'] = spec['categoryId']
                entry['name'] = '%s%02d' % (spec['name'], slot_idx)
                used_ids.add(source_id)
                file_rel = 'assets/content/poses3/photos/%s.jpg' % pose_id
                replaced[file_rel] = {
                    'file': file_rel,
                    'name': '姿势参考（%s）' % spec['category'],
                    'source': meta['source'],
                    'license': meta['license'],
                    'author': meta['author'],
                }
                total += 1
                placed = True
                print('[v7] %s <- pexels %s (%dx%d) %s asian=%d' % (
                    pose_id, source_id, width, height, spec['category'],
                    asian_score(meta['alt'])))
                break
            if not placed:
                print('[v7] %s 无可用候选（保持原图）' % pose_id)

    if dry_run:
        print('[v7] dry-run 完成，可替换 %d 张' % total)
        return 0

    manifest['photos'] = photos
    manifest['generatedAt'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    manifest['note'] = ('姿势照片（V6/D122 全部亚洲人；V7/D140 将「手部」「神态」替换为'
                        '「杂志大片」「影视感」）：Pexels 主 + Wikimedia Commons 备（严格许可）；'
                        'photo 为 app 根相对路径。')
    manifest['candidatePool'] = pool
    write_json(MANIFEST, manifest)

    keep = [it for it in items if it.get('file') not in replaced]
    attribution['items'] = keep + list(replaced.values())
    attribution['note'] = attribution.get('note') or '图片素材逐条署名（R63）'
    write_json(ATTRIBUTION, attribution)

    print('[v7] replaced %d photos, attribution entries: %d' % (total, len(attribution['items'])))
    return 0


if __name__ == '__main__':
    sys.exit(main())
