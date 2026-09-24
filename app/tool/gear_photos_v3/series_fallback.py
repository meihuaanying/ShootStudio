# -*- coding: utf-8 -*-
"""V7/D142 第③层：同系列/同品牌近似兜底（tier=series，不触网）。

用法（工作目录 app/）：
  python tool/gear_photos_v3/series_fallback.py            # 补齐缺失项（写 sources）
  python tool/gear_photos_v3/series_fallback.py --dry-run  # 只打印阶梯分布

阶梯（R70：近似图必须标注）：
  ① 同品牌 + 同类目 donor（优先共享系列词）→ tier=series
  ② 同品牌（跨类目）donor → tier=series
  ③ 无 donor → 跳过（交由 keyword provider 氛围实拍 tier=atmosphere 兜底）

donor 来源：`gear_photo_sources.json`（有真实池路径）优先，其次
`gear_photos2.json` 的 byId/byModel（借 runtimeUrl/sourceUrl 等元数据）。
已有 sources 记录的条目不会被覆盖（除非 --force）。
"""
from __future__ import annotations

import argparse
import os
import sys

TOOL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if TOOL_DIR not in sys.path:
    sys.path.insert(0, TOOL_DIR)

from gear_photos_v3 import common, run  # noqa: E402

PROVIDER = 'series-fallback'


def _photos2_entries(photos2: dict) -> list:
    out = []
    for key in ('byId', 'byModel'):
        bucket = photos2.get(key) or {}
        for value in bucket.values():
            if isinstance(value, dict):
                out.append(value)
            elif isinstance(value, list):
                out.extend(v for v in value if isinstance(v, dict))
    return out


def _donors(sources: dict) -> dict:
    """id -> donor 元数据（仅 sources 来源；须有本地池副本 sha1+rawPath）。

    V7 修正：photos2 条目无本地池文件（sha1/rawPath 为空），借图后元数据不完整，
    与 D130/R47「图源登记元数据完整」冲突 → 不再作为 donor（缺口转氛围实拍）。
    借图条目（provider=series-fallback）同样不作为 donor，避免链式借用。
    """
    donors = {}
    for gid, rec in (sources.get('items') or {}).items():
        if not isinstance(rec, dict) or not rec.get('imageUrl'):
            continue
        if not rec.get('sha1') or not rec.get('rawPath'):
            continue
        if rec.get('provider') == PROVIDER:
            continue
        donors[gid] = {
            'imageUrl': rec.get('imageUrl', ''),
            'pageUrl': rec.get('pageUrl', ''),
            'license': rec.get('license', ''),
            'title': rec.get('title', ''),
            'sha1': rec.get('sha1', ''),
            'width': rec.get('width') or 0,
            'height': rec.get('height') or 0,
            'bytes': rec.get('bytes') or 0,
            'format': rec.get('format', ''),
            'rawPath': rec.get('rawPath', ''),
            'normPath': rec.get('normPath', ''),
            'brand': rec.get('brand', ''),
            'kind': rec.get('kind', ''),
            'model': rec.get('model', ''),
            'origin': 'sources',
        }
    return donors


def _series_token(item: dict) -> str:
    specs = item.get('specs') or {}
    series = str(specs.get('series') or '').strip()
    if series:
        return series.lower()
    model = str(item.get('model') or '')
    return model.split()[0].lower() if model else ''


def _pick_donor(item: dict, donors: dict) -> tuple:
    """返回 (donor_id, donor, level) 或 (None, None, None)。"""
    brand = str(item.get('brand') or '')
    kind = str(item.get('kind') or '')
    token = _series_token(item)
    same_brand = [
        (gid, d) for gid, d in donors.items()
        if str(d.get('brand') or '') == brand and gid != item.get('id')
    ]
    if not same_brand:
        return None, None, None
    same_kind = [(gid, d) for gid, d in same_brand if str(d.get('kind') or '') == kind]
    pool = same_kind or same_brand
    level = 1 if same_kind else 2
    if token:
        for gid, d in pool:
            if token and token in str(d.get('model') or '').lower():
                return gid, d, level
    return pool[0][0], pool[0][1], level


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()

    items = run.load_items()
    sources = common.read_json(common.SOURCES_ASSET, {})
    records = dict(sources.get('items') or {})
    photos2 = common.read_json(common.PHOTOS2_ASSET, {})
    donors = _donors(sources)
    covered = set(records)
    for entry in _photos2_entries(photos2):
        gid = str(entry.get('id') or '')
        if gid:
            covered.add(gid)

    missing = [it for it in items if str(it.get('id')) not in covered]
    print('[series] 缺失 %d 条（donor 池 %d）' % (len(missing), len(donors)))

    added = 0
    levels = {1: 0, 2: 0}
    no_donor = []
    for item in missing:
        gid = str(item.get('id'))
        if gid in records and not args.force:
            continue
        donor_id, donor, level = _pick_donor(item, donors)
        if not donor:
            no_donor.append(gid)
            continue
        levels[level] += 1
        if args.dry_run:
            continue
        title = '%s %s（同品牌近似示意，非该型号）' % (
            donor.get('brand', ''), donor.get('model', ''))
        rec = {
            'gearId': gid,
            'kind': item.get('kind', ''),
            'brand': item.get('brand', ''),
            'model': item.get('model', ''),
            'provider': PROVIDER,
            'imageUrl': donor['imageUrl'],
            'pageUrl': donor['pageUrl'],
            'title': title,
            'license': donor.get('license') or '产品图版权归原品牌/平台，仅供选型参考',
            'fetchedAt': common.now_iso(),
            'sha1': donor.get('sha1', ''),
            'width': donor.get('width') or 0,
            'height': donor.get('height') or 0,
            'bytes': donor.get('bytes') or 0,
            'format': donor.get('format', ''),
            'rawPath': donor.get('rawPath', ''),
            'normPath': donor.get('normPath', ''),
            'extra': {
                'tier': 'series',
                'layer': 'series',
                'refId': donor_id,
                'refOrigin': donor.get('origin', ''),
                'refModel': donor.get('model', ''),
                'borrowed': True,
            },
        }
        records[gid] = rec
        added += 1

    print('[series] 阶梯① 同品牌同类 %d ｜ 阶梯② 同品牌跨类 %d ｜ 无 donor %d'
          % (levels[1], levels[2], len(no_donor)))
    if no_donor:
        print('[series] 无 donor（转氛围实拍）：%s' % ','.join(no_donor[:40]))
    if args.dry_run:
        print('[series] dry-run：未写盘')
        return 0

    sources['items'] = records
    sources.setdefault('version', 1)
    sources['note'] = ('V6/E D129–D131 + V7/D142 四层来源：官网 official / 授权零售商 retail / '
                       '同系列近似 series-fallback / 氛围实拍 pexels；逐条登记（R63）。')
    sources['generatedAt'] = common.now_iso()
    sources['count'] = len(records)
    common.write_json(common.SOURCES_ASSET, sources)
    print('[series] 写入 %d 条，sources 共 %d 条 -> %s'
          % (added, len(records), os.path.relpath(common.SOURCES_ASSET, common.REPO_ROOT)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
