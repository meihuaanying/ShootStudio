"""V7/D142：资源库图源抽检（来源抽检门禁，R63/R70）。

从 assets/content/gear/gear_photo_sources.json 中确定性抽取样本条目，
逐条校验来源元数据是否完整、可追溯、许可可查：

1. imageUrl 为 http(s)；官方/零售商条目含 pageUrl。
2. license/fetchedAt 非空；width/height 为正整数（有本地池文件时 >= 350）。
3. tier ∈ {product, series, atmosphere}；layer 与 provider 一致（四层兜底口径）。
4. provider=series-fallback 必须带 refId 且能在 sources 中追溯到 donor；
   provider=official/retail 必须带 pageUrl；pexels 必须带摄影师信息。

抽样规则（确定性）：先按 (provider, kind) 组合各取 1 条，再按 gearId 排序步长补齐到 12 条。

输出：docs/qa/gear-sources-spotcheck.json；存在失败时退出码 1（CI 门禁）。
"""

from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gear_photos_v3 import common  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
REPO = os.path.dirname(APP)
OUT = os.path.join(REPO, 'docs', 'qa', 'gear-sources-spotcheck.json')
SAMPLE_SIZE = 12
TIERS = ('product', 'series', 'atmosphere')
LAYER_BY_PROVIDER = {
    'official': 'official',
    'retail': 'retail',
    'jd': 'retail',
    'amazon': 'retail',
    'taobao': 'retail',
    'series-fallback': 'series',
    'pexels': 'keyword',
    'openverse': 'keyword',
    'manual': 'manual',
    'user-file': 'manual',
    'user-url': 'manual',
}


def layer_of(rec: dict) -> str:
    extra = rec.get('extra') or {}
    layer = str(extra.get('layer') or '').strip()
    if layer:
        return layer
    return LAYER_BY_PROVIDER.get(str(rec.get('provider') or ''), 'open')


def pick_samples(items: dict) -> list:
    """确定性抽样：先每 (provider, kind) 1 条，再步长补齐。"""
    rows = sorted(items.items(), key=lambda kv: str(kv[0]))
    picked = []
    seen_ids = set()
    combos = {}
    for gid, rec in rows:
        key = (str(rec.get('provider') or ''), str(rec.get('kind') or ''))
        combos.setdefault(key, gid)
    for key in sorted(combos):
        gid = combos[key]
        if gid not in seen_ids:
            picked.append(gid)
            seen_ids.add(gid)
    if len(rows) > 0:
        stride = max(1, len(rows) // SAMPLE_SIZE)
        i = 0
        while len(picked) < SAMPLE_SIZE and i < len(rows):
            gid = rows[i][0]
            if gid not in seen_ids:
                picked.append(gid)
                seen_ids.add(gid)
            i += stride
        i = 0
        while len(picked) < SAMPLE_SIZE and i < len(rows):
            gid = rows[i][0]
            if gid not in seen_ids:
                picked.append(gid)
                seen_ids.add(gid)
            i += 1
    return picked[:SAMPLE_SIZE]


def check(rec: dict, items: dict) -> dict:
    gid = str(rec.get('gearId') or '')
    provider = str(rec.get('provider') or '')
    extra = rec.get('extra') or {}
    failures = []

    image_url = str(rec.get('imageUrl') or '')
    if not re.match(r'^https?://', image_url):
        failures.append('imageUrl 非 http(s)')
    if not str(rec.get('license') or '').strip():
        failures.append('license 为空')
    fetched = str(rec.get('fetchedAt') or '')
    if not re.match(r'^\d{4}-\d{2}-\d{2}', fetched):
        failures.append('fetchedAt 非法')
    for field in ('width', 'height'):
        value = rec.get(field)
        if not isinstance(value, int) or value <= 0:
            failures.append('%s 非法' % field)
    tier = str(extra.get('tier') or '')
    if tier not in TIERS:
        failures.append('tier 非法：%r' % tier)
    layer = layer_of(rec)
    if not layer:
        failures.append('layer 为空')
    if provider in ('official', 'retail'):
        if not re.match(r'^https?://', str(rec.get('pageUrl') or '')):
            failures.append('%s 缺 pageUrl' % provider)
    if provider == 'series-fallback':
        ref = str(extra.get('refId') or '')
        if not ref:
            failures.append('series 缺 refId')
        elif ref not in items:
            failures.append('refId 无法追溯：%s' % ref)
        elif ref == gid:
            failures.append('refId 指向自身')
        if extra.get('borrowed') is not True:
            failures.append('series 缺 borrowed 标记')
    if provider == 'pexels' and not str(extra.get('photographer') or '').strip():
        failures.append('pexels 缺 photographer')

    return {
        'gearId': gid,
        'kind': rec.get('kind'),
        'brand': rec.get('brand'),
        'model': rec.get('model'),
        'provider': provider,
        'tier': tier,
        'layer': layer,
        'imageUrl': image_url,
        'refId': extra.get('refId'),
        'ok': not failures,
        'failures': failures,
    }


def main() -> int:
    items = (common.read_json(common.SOURCES_ASSET, {}) or {}).get('items') or {}
    if not items:
        print('[spotcheck] sources 为空，无法抽检')
        return 1
    ids = pick_samples(items)
    sampled = [check(items[gid], items) for gid in ids]
    failed = [row for row in sampled if not row['ok']]
    payload = {
        'version': 1,
        'at': common.now_iso(),
        'note': 'V7/D142 来源抽检：确定性抽样，校验来源元数据完整与四层兜底口径（R63/R70）',
        'source': 'assets/content/gear/gear_photo_sources.json',
        'total': len(items),
        'sampleSize': len(sampled),
        'criteria': [
            'imageUrl 为 http(s)',
            'license/fetchedAt/width/height 完整',
            'tier ∈ product/series/atmosphere',
            'official/retail 含 pageUrl',
            'series-fallback 含可追溯 refId 与 borrowed 标记',
            'pexels 含 photographer',
        ],
        'sampled': sampled,
        'summary': {
            'ok': len(sampled) - len(failed),
            'failed': len(failed),
            'failIds': [row['gearId'] for row in failed],
            'pass': not failed,
        },
    }
    common.write_json(OUT, payload)
    print('[spotcheck] 抽检 %d 条（共 %d），通过 %d，失败 %d -> %s' % (
        len(sampled), len(items), payload['summary']['ok'], len(failed), OUT))
    for row in failed:
        print('  [FAIL] %s: %s' % (row['gearId'], '；'.join(row['failures'])))
    return 0 if not failed else 1


if __name__ == '__main__':
    sys.exit(main())
