# -*- coding: utf-8 -*-
"""资源库参考图覆盖率报告（V6/E，D129/D131）。

六类口径：
  camera/lens/light/accessory：内置（gear_photos2.json byId/byModel）∪ 抓取图源
                               （gear_photo_sources.json）视为已覆盖；
  clothing：clothing.json 类目在 clothing_photos.json 有至少 1 张实际存在的照片；
  props：props_presets.json 条目在 gear_photo_sources.json 有条目。

输出：docs/qa/gear-coverage-v6.json（含每类覆盖率、缺口清单、来源分布、目标判定）。
用法（工作目录 app/）：python tool/gear_coverage.py
"""
from __future__ import annotations

import collections
import io
import json
import os
import sys

if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

APP_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_ROOT = os.path.dirname(APP_ROOT)
GEAR_DIR = os.path.join(APP_ROOT, 'assets', 'content', 'gear')
OUT = os.path.join(REPO_ROOT, 'docs', 'qa', 'gear-coverage-v6.json')

TARGETS = {
    'camera': 0.95,
    'lens': 0.95,
    'light': 0.90,
    'accessory': 0.90,
    'clothing': 0.90,
    'props': 0.90,
}


def read_json(path, fallback):
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return fallback


def collect_gear(covered_union, sources):
    gear = read_json(os.path.join(GEAR_DIR, 'gear.json'), {})
    stats = collections.defaultdict(lambda: {
        'total': 0, 'covered': 0, 'missing': [], 'sources': collections.Counter(),
        'tier': collections.Counter(),
    })
    for item in gear.get('items') or []:
        kind = item.get('kind')
        if kind not in TARGETS or kind == 'clothing':
            continue
        stat = stats[kind]
        stat['total'] += 1
        gid = item.get('id')
        record = sources.get(gid)
        p2 = read_json(os.path.join(GEAR_DIR, 'gear_photos2.json'), {})
        builtin = gid in (p2.get('byId') or {}) or gid in (p2.get('byModel') or {})
        if gid in covered_union:
            stat['covered'] += 1
            if record:
                stat['sources'][record.get('provider') or 'unknown'] += 1
                stat['tier'][(record.get('extra') or {}).get('tier') or 'product'] += 1
            elif builtin:
                stat['sources']['builtin'] += 1
        else:
            stat['missing'].append({
                'id': gid,
                'brand': item.get('brand') or '',
                'model': item.get('model') or '',
            })
    return stats


def collect_clothing():
    clothing = read_json(os.path.join(APP_ROOT, 'assets', 'content', 'clothing', 'clothing.json'), {})
    photos = read_json(os.path.join(APP_ROOT, 'assets', 'content', 'clothing',
                                    'clothing_photos.json'), {})
    by_cat = photos.get('byCategory') or {}
    photo_dir = os.path.join(APP_ROOT, 'assets', 'content', 'clothing', 'photo')
    total = covered = 0
    missing = []
    for cat in clothing.get('categories') or []:
        total += 1
        files = by_cat.get(cat.get('id')) or []
        cat_dir = os.path.join(photo_dir, str(cat.get('id')))
        exists = any(os.path.exists(os.path.join(cat_dir, str(f.get('file') or '')))
                     for f in files if isinstance(f, dict))
        if exists and files:
            covered += 1
        else:
            missing.append({'id': cat.get('id'), 'brand': '', 'model': cat.get('category') or ''})
    return {'total': total, 'covered': covered, 'missing': missing,
            'sources': collections.Counter({'pexels': covered}), 'tier': collections.Counter()}


def collect_props(sources):
    presets = read_json(os.path.join(APP_ROOT, 'assets', 'content', 'props',
                                     'props_presets.json'), {})
    props = presets.get('props') or []
    covered = 0
    missing = []
    src = collections.Counter()
    for p in props:
        gid = p.get('id')
        if gid in sources:
            covered += 1
            src[sources[gid].get('provider') or 'unknown'] += 1
        else:
            missing.append({'id': gid, 'brand': '', 'model': p.get('name') or ''})
    return {'total': len(props), 'covered': covered, 'missing': missing,
            'sources': src, 'tier': collections.Counter()}


def main() -> int:
    photos2 = read_json(os.path.join(GEAR_DIR, 'gear_photos2.json'), {})
    sources_doc = read_json(os.path.join(GEAR_DIR, 'gear_photo_sources.json'), {})
    sources = sources_doc.get('items') or {}
    covered_union = set(photos2.get('byId') or {}) | set(photos2.get('byModel') or {}) | set(sources)

    stats = collect_gear(covered_union, sources)
    stats['clothing'] = collect_clothing()
    stats['props'] = collect_props(sources)

    categories = {}
    pass_by_kind = {}
    for kind, target in TARGETS.items():
        stat = stats.get(kind, {'total': 0, 'covered': 0, 'missing': [], 'sources': collections.Counter(),
                                'tier': collections.Counter()})
        total = stat['total']
        covered = stat['covered']
        ratio = round(covered / total, 4) if total else 0.0
        categories[kind] = {
            'total': total,
            'covered': covered,
            'ratio': ratio,
            'target': target,
            'pass': ratio >= target,
            'bySource': dict(stat['sources']),
            'byTier': dict(stat['tier']),
            'missing': stat['missing'],
            'missingCount': len(stat['missing']),
        }
        pass_by_kind[kind] = categories[kind]['pass']

    payload = {
        'version': 1,
        'generatedAt': __import__('time').strftime('%Y-%m-%dT%H:%M:%SZ', __import__('time').gmtime()),
        'note': ('V6/E D129：覆盖率口径 = 内置产品图（photo2）∪ 已核验图源'
                 '（官网/平台/开放图源，图片仅存工作区/工具池，不入 git）。'),
        'targets': TARGETS,
        'categories': categories,
        'passByKind': pass_by_kind,
        'pass': all(pass_by_kind.values()),
        'missingTotal': sum(categories[k]['missingCount'] for k in categories),
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    for kind in TARGETS:
        c = categories[kind]
        print('%-10s %3d/%-3d %6.1f%%  target %4.0f%%  %s' % (
            kind, c['covered'], c['total'], c['ratio'] * 100, c['target'] * 100,
            'PASS' if c['pass'] else 'GAP %d' % c['missingCount']))
    print('overall:', 'PASS' if payload['pass'] else 'GAP', '->', OUT)
    return 0 if payload['pass'] else 1


if __name__ == '__main__':
    sys.exit(main())
