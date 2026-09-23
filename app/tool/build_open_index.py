# -*- coding: utf-8 -*-
"""构建 NGA / Walters 开放获取精选索引（D134/R63）。

数据源（CC0，均来自官方 GitHub）：
  - NGA Open Data Program：objects.csv + published_images.csv（openaccess=1 主图）
    https://github.com/NationalGalleryOfArt/opendata
  - Walters Art Museum 静态数据：art.csv + media.csv（防御性门控：pre-1928 + 有图）
    https://github.com/WaltersArtMuseum/api-thewalters-org

输出（入 git，随包）：
  app/assets/content/search/open_index/nga.json
  app/assets/content/search/open_index/walters.json

用法（工作目录 app/）：
  python tool/build_open_index.py            # 增量：缓存存在则跳过下载
  python tool/build_open_index.py --force    # 强制重新下载
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import os
import sys
import time
import urllib.request

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
APP_ROOT = os.path.dirname(TOOL_DIR)
CACHE_DIR = os.path.join(TOOL_DIR, 'open_index_cache')
OUT_DIR = os.path.join(APP_ROOT, 'assets', 'content', 'search', 'open_index')

TARGET_PER_MUSEUM = 300
UA = 'ShootStudio-open-index/1.3 (+https://github.com/meihuaanying/ShootStudio)'

NGA_OBJECTS = 'https://raw.githubusercontent.com/NationalGalleryOfArt/opendata/main/data/objects.csv'
NGA_IMAGES = 'https://raw.githubusercontent.com/NationalGalleryOfArt/opendata/main/data/published_images.csv'
WALTERS_ART = 'https://raw.githubusercontent.com/WaltersArtMuseum/api-thewalters-org/main/art.csv'
WALTERS_MEDIA = 'https://raw.githubusercontent.com/WaltersArtMuseum/api-thewalters-org/main/media.csv'
WALTERS_CREATORS = 'https://raw.githubusercontent.com/WaltersArtMuseum/api-thewalters-org/main/creators.csv'


def download(url: str, force: bool = False) -> str:
    os.makedirs(CACHE_DIR, exist_ok=True)
    name = url.rsplit('/', 1)[-1]
    path = os.path.join(CACHE_DIR, name)
    if os.path.exists(path) and os.path.getsize(path) > 1024 and not force:
        print('  [cache] %s (%d bytes)' % (name, os.path.getsize(path)))
        return path
    last = None
    for attempt in range(1, 4):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': UA})
            with urllib.request.urlopen(req, timeout=120) as resp, open(path + '.part', 'wb') as fh:
                total = int(resp.headers.get('Content-Length') or 0)
                done = 0
                while True:
                    chunk = resp.read(1024 * 512)
                    if not chunk:
                        break
                    fh.write(chunk)
                    done += len(chunk)
                    if total:
                        pct = done * 100 // total
                        print('\r  [down] %s %d%% (%d/%d)' % (name, pct, done, total), end='')
            print('')
            os.replace(path + '.part', path)
            return path
        except Exception as exc:  # noqa: BLE001
            last = exc
            print('\n  [retry %d] %s：%s' % (attempt, name, exc))
            time.sleep(2 * attempt)
    raise RuntimeError('下载失败：%s（%s）' % (url, last))


def read_csv(path: str):
    with open(path, 'r', encoding='utf-8-sig', newline='') as fh:
        yield from csv.DictReader(fh)


def sample_even(items: list, target: int) -> list:
    if len(items) <= target:
        return items
    step = len(items) / target
    return [items[int(i * step)] for i in range(target)]


def build_nga(force: bool) -> dict:
    print('[NGA] 下载/缓存')
    objects_path = download(NGA_OBJECTS, force)
    images_path = download(NGA_IMAGES, force)
    print('[NGA] 索引 objects.csv（82MB，稍候）')
    objects = {}
    for row in read_csv(objects_path):
        oid = (row.get('objectid') or '').strip()
        if not oid:
            continue
        title = (row.get('title') or '').strip()
        if not title:
            continue
        objects[oid] = {
            'title': title,
            'artist': (row.get('attribution') or row.get('attributioninverted') or '').strip(),
            'date': (row.get('displaydate') or '').strip(),
            'classification': (row.get('classification') or '').strip(),
        }
    print('  objects：%d' % len(objects))
    items = []
    for row in read_csv(images_path):
        if (row.get('openaccess') or '').strip() != '1':
            continue
        if (row.get('viewtype') or '').strip() != 'primary':
            continue
        oid = (row.get('depictstmsobjectid') or '').strip()
        base = (row.get('iiifurl') or '').strip()
        if not oid or not base or oid not in objects:
            continue
        obj = objects[oid]
        items.append({
            'id': 'nga-%s' % oid,
            'title': obj['title'],
            'artist': obj['artist'],
            'date': obj['date'],
            'thumbUrl': (row.get('iiifthumburl') or '').strip(),
            'fullUrl': '%s/full/!1200,1200/0/default.jpg' % base.rstrip('/'),
            'pageUrl': 'https://www.nga.gov/collection/art-object-page.%s.html' % oid,
            'width': int(row.get('width') or 0),
            'height': int(row.get('height') or 0),
            'classification': obj['classification'],
        })
    items.sort(key=lambda it: it['id'])
    picked = sample_even(items, TARGET_PER_MUSEUM)
    print('  openaccess=1 主图：%d → 精选 %d' % (len(items), len(picked)))
    return {
        'version': 1,
        'source': 'nga',
        'label': '美国国家美术馆',
        'attribution': 'National Gallery of Art',
        'note': 'NGA Open Data Program（CC0）精选：openaccess=1 主图，图片热链 api.nga.gov IIIF。',
        'license': 'CC0 1.0',
        'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'count': len(picked),
        'items': picked,
    }


def _walters_ok(row: dict) -> bool:
    begin = (row.get('DateBeginYear') or '').strip()
    end = (row.get('DateEndYear') or '').strip()
    year = 0
    for raw in (begin, end):
        try:
            year = int(float(raw))
            break
        except Exception:  # noqa: BLE001
            continue
    if not year or year >= 1928:
        return False
    if not (row.get('Title') or '').strip():
        return False
    text = ' '.join(
        (row.get(k) or '') for k in ('Description', 'CreditLine', 'Provenance')
    ).lower()
    if 'loan' in text or 'copyright' in text:
        return False
    return True


def _walters_creators(raw: str, creators: dict) -> str:
    """art.csv 的 Creators 为 creator id 列表（| 分隔），映射为姓名。"""
    names = []
    for cid in (raw or '').split('|'):
        cid = cid.strip()
        if not cid:
            continue
        name = creators.get(cid, '')
        if name and name not in names:
            names.append(name)
    return ', '.join(names[:3])


def build_walters(force: bool) -> dict:
    print('[Walters] 下载/缓存')
    art_path = download(WALTERS_ART, force)
    media_path = download(WALTERS_MEDIA, force)
    creators_path = download(WALTERS_CREATORS, force)
    print('[Walters] 读取 creators.csv')
    creators = {}
    for row in read_csv(creators_path):
        cid = (row.get('id') or '').strip()
        name = (row.get('name') or row.get('sort_name') or '').strip()
        if cid and name:
            creators[cid] = name
    print('  creators：%d' % len(creators))
    print('[Walters] 读取 media.csv')
    media = {}
    for row in read_csv(media_path):
        oid = (row.get('ObjectID') or '').strip()
        url = (row.get('ImageURL') or '').strip()
        if not oid or not url:
            continue
        primary = (row.get('IsPrimary') or '').strip() == '1'
        rank = (row.get('Rank') or '').strip() == '1'
        if oid not in media or (primary and not media[oid]['primary']) or rank:
            media[oid] = {'url': url, 'primary': primary}
    print('  media：%d' % len(media))
    print('[Walters] 过滤 art.csv（pre-1928 + 有图 + 排除出借/涉版权）')
    items = []
    for row in read_csv(art_path):
        oid = (row.get('ObjectID') or '').strip()
        if not oid or oid not in media or not _walters_ok(row):
            continue
        items.append({
            'id': 'walters-%s' % oid,
            'title': (row.get('Title') or '').strip(),
            'artist': _walters_creators(row.get('Creators'), creators),
            'date': (row.get('DateText') or '').strip(),
            'thumbUrl': media[oid]['url'],
            'fullUrl': media[oid]['url'],
            'pageUrl': (row.get('ResourceURL') or '').strip(),
            'width': 0,
            'height': 0,
            'classification': (row.get('Classification') or '').strip(),
        })
    items.sort(key=lambda it: it['id'])
    picked = sample_even(items, TARGET_PER_MUSEUM)
    print('  合格：%d → 精选 %d' % (len(items), len(picked)))
    return {
        'version': 1,
        'source': 'walters',
        'label': '沃尔特斯艺术博物馆',
        'attribution': 'Walters Art Museum',
        'note': ('Walters 静态数据集（馆方 CC0 声明）防御性门控精选：pre-1928 + 有图，'
                 '排除出借/涉版权记录；图片热链 art.thewalters.org。'),
        'license': 'CC0 1.0',
        'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'count': len(picked),
        'items': picked,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description='构建 NGA/Walters 开放索引（D134）')
    parser.add_argument('--force', action='store_true', help='强制重新下载')
    args = parser.parse_args()
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, builder in (('nga', build_nga), ('walters', build_walters)):
        data = builder(args.force)
        out = os.path.join(OUT_DIR, '%s.json' % name)
        with open(out, 'w', encoding='utf-8') as fh:
            json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))
            fh.write('\n')
        print('  → %s（%d 条，%d KB）' % (
            os.path.relpath(out, APP_ROOT), data['count'], os.path.getsize(out) // 1024))
    print('[open-index] 完成')
    return 0


if __name__ == '__main__':
    sys.exit(main())
