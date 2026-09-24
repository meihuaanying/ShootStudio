# -*- coding: utf-8 -*-
"""资源库参考图覆盖率报告（V7/D142：六类 100% + 四层来源统计）。

六类口径：
  camera/lens/light/accessory：内置（gear_photos2.json byId/byModel）∪ 抓取图源
                               （gear_photo_sources.json）视为已覆盖；
  clothing：clothing.json 类目在 clothing_photos.json 有至少 1 张实际存在的照片；
  props：props_presets.json 条目在 gear_photo_sources.json 有条目。

四层兜底（D142）与层归属：
  ① 品牌官网   -> layer=official（provider=official）
  ② 授权零售商 -> layer=retail（provider=retail；B&H/Adorama/JD）
  ③ 同系列近似 -> layer=series（provider=series-fallback，tier=series，extra.refId 指向 donor）
  ④ 补图       -> layer=manual（provider=manual/user-*；本地/链接 + 来源登记，运行期在工作区）
  其他：layer=open（Pexels/Openverse 等开放图源）、layer=builtin（photo2 内置产品图）。

输出：docs/qa/gear-coverage-v7.json（每类覆盖率、缺口清单、来源/层/tier 分布、目标判定）。
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
OUT = os.path.join(REPO_ROOT, 'docs', 'qa', 'gear-coverage-v7.json')

TARGETS = {
    'camera': 1.0,
    'lens': 1.0,
    'light': 1.0,
    'accessory': 1.0,
    'clothing': 1.0,
    'props': 1.0,
}

# 四层兜底 + 开放图源/内置（用于来源统计口径）。
LAYERS = ('official', 'retail', 'series', 'manual', 'open', 'builtin')

_LAYER_BY_PROVIDER = {
    'official': 'official',
    'retail': 'retail',
    'series-fallback': 'series',
    'manual': 'manual',
    'user-file': 'manual',
    'user-url': 'manual',
    'pexels': 'open',
    'openverse': 'open',
    'wikimedia': 'open',
    'builtin': 'builtin',
}

_OPEN_PROVIDERS = ('pexels', 'openverse', 'wikimedia', 'wikipedia')


def read_json(path, fallback):
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return fallback


def layer_of(provider: str, extra: dict | None) -> str:
    """层归属：extra.layer 优先，其次 provider 映射，未知归 open。"""
    explicit = (extra or {}).get('layer')
    if explicit:
        return str(explicit)
    return _LAYER_BY_PROVIDER.get(provider or '', 'open')


def tier_of(provider: str, extra: dict | None) -> str:
    """tier 归属：extra.tier 优先；开放图源默认 atmosphere，其余默认 product。"""
    explicit = (extra or {}).get('tier')
    if explicit:
        return str(explicit)
    return 'atmosphere' if (provider or '') in _OPEN_PROVIDERS else 'product'


def collect_gear(covered_union, sources):
    gear = read_json(os.path.join(GEAR_DIR, 'gear.json'), {})
    photos2 = read_json(os.path.join(GEAR_DIR, 'gear_photos2.json'), {})
    stats = collections.defaultdict(lambda: {
        'total': 0, 'covered': 0, 'missing': [], 'sources': collections.Counter(),
        'tier': collections.Counter(), 'layer': collections.Counter(),
    })
    for item in gear.get('items') or []:
        kind = item.get('kind')
        if kind not in TARGETS or kind == 'clothing':
            continue
        stat = stats[kind]
        stat['total'] += 1
        gid = item.get('id')
        record = sources.get(gid)
        builtin = gid in (photos2.get('byId') or {}) or gid in (photos2.get('byModel') or {})
        if gid in covered_union:
            stat['covered'] += 1
            if record:
                provider = record.get('provider') or 'unknown'
                extra = record.get('extra') or {}
                stat['sources'][provider] += 1
                stat['tier'][tier_of(provider, extra)] += 1
                stat['layer'][layer_of(provider, extra)] += 1
            elif builtin:
                stat['sources']['builtin'] += 1
                stat['tier']['product'] += 1
                stat['layer']['builtin'] += 1
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
            'sources': collections.Counter({'pexels': covered}),
            'tier': collections.Counter({'product': covered}),
            'layer': collections.Counter({'open': covered})}


def collect_props(sources):
    presets = read_json(os.path.join(APP_ROOT, 'assets', 'content', 'props',
                                     'props_presets.json'), {})
    props = presets.get('props') or []
    covered = 0
    missing = []
    src = collections.Counter()
    tier = collections.Counter()
    layer = collections.Counter()
    for p in props:
        gid = p.get('id')
        record = sources.get(gid)
        if record:
            covered += 1
            provider = record.get('provider') or 'unknown'
            extra = record.get('extra') or {}
            src[provider] += 1
            tier[tier_of(provider, extra)] += 1
            layer[layer_of(provider, extra)] += 1
        else:
            missing.append({'id': gid, 'brand': '', 'model': p.get('name') or ''})
    return {'total': len(props), 'covered': covered, 'missing': missing,
            'sources': src, 'tier': tier, 'layer': layer}


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
    by_layer_total = collections.Counter()
    by_tier_total = collections.Counter()
    for kind, target in TARGETS.items():
        stat = stats.get(kind, {'total': 0, 'covered': 0, 'missing': [], 'sources': collections.Counter(),
                                'tier': collections.Counter(), 'layer': collections.Counter()})
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
            'byLayer': dict(stat['layer']),
            'missing': stat['missing'],
            'missingCount': len(stat['missing']),
        }
        pass_by_kind[kind] = categories[kind]['pass']
        by_layer_total.update(stat['layer'])
        by_tier_total.update(stat['tier'])

    payload = {
        'version': 2,
        'generatedAt': __import__('time').strftime('%Y-%m-%dT%H:%M:%SZ', __import__('time').gmtime()),
        'note': ('V7/D142：六类 100% 口径 = 内置产品图（photo2）∪ 已核验图源（官网/授权零售商/'
                 '同系列近似/补图/开放图源，图片仅存工作区/工具池，不入 git）；'
                 '四层兜底见 layers 字段（official/retail/series/manual）。'),
        'targets': TARGETS,
        'layers': list(LAYERS),
        'categories': categories,
        'byLayer': dict(by_layer_total),
        'byTier': dict(by_tier_total),
        'fallbackLayers': {
            'official': by_layer_total.get('official', 0),
            'retail': by_layer_total.get('retail', 0),
            'series': by_layer_total.get('series', 0),
            'manual': by_layer_total.get('manual', 0),
            'note': ('D142 四层兜底计数：①官网 ②授权零售商（B&H/Adorama/JD）'
                     '③同系列近似（tier=series）④补图（工作区 images/gear/sources.json，'
                     '资产侧计 0；入口保留）'),
        },
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
    print('byLayer:', dict(by_layer_total))
    print('byTier:', dict(by_tier_total))
    print('overall:', 'PASS' if payload['pass'] else 'GAP', '->', OUT)
    return 0 if payload['pass'] else 1


if __name__ == '__main__':
    sys.exit(main())
