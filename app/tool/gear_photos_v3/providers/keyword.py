# -*- coding: utf-8 -*-
"""关键词图源 provider（开放许可 + 氛围兜底）。

用途：
  - 道具（props）：无品牌型号，用显式英文关键词；
  - 通用附件/灯具：中文术语转英文关键词后检索；
  - 相机/镜头/灯具：Openverse 仅作补充（官网优先）。
许可约束（R24/R56）：只用 CC0 / CC BY / PDM；Pexels 仅作「氛围实拍」兜底并标注。
"""
from __future__ import annotations

import re
import urllib.parse

from .. import common
from .base import Candidate, Provider

OV_API = 'https://api.openverse.org/v1/images/'
PEXELS_SEARCH = 'https://api.pexels.com/v1/search'

PROP_QUERIES = {
    'prop-1': 'photography reflector silver gold',
    'prop-2': 'transparent umbrella photography',
    'prop-3': 'flower bouquet still life',
    'prop-4': 'smoke bomb photography',
    'prop-5': 'vintage leather suitcase',
    'prop-6': 'black fabric backdrop studio',
    'prop-7': 'folding chair',
    'prop-8': 'hand fan',
    'prop-9': 'paper lantern warm light',
    'prop-10': 'helium balloons',
    'prop-11': 'old books stack',
    'prop-12': 'pinwheel windmill toy',
    'prop-13': 'candle flame',
    'prop-14': 'sheer curtain light',
}

ACCESSORY_TERMS = (
    ('柔光箱', 'softbox'),
    ('八角', 'octabox softbox'),
    ('雷达罩', 'beauty dish'),
    ('雷达', 'beauty dish'),
    ('束光筒', 'snoot'),
    ('聚光筒', 'spotlight attachment'),
    ('蜂巢', 'honeycomb grid'),
    ('反光板', 'photography reflector'),
    ('反光伞', 'reflective umbrella'),
    ('透光伞', 'shoot through umbrella'),
    ('伞', 'umbrella'),
    ('旗板', 'flag panel'),
    ('色片', 'color gel filter'),
    ('背景纸', 'seamless paper backdrop'),
    ('背景布', 'photo backdrop'),
    ('三脚架', 'tripod'),
    ('独脚架', 'monopod'),
    ('云台', 'ball head tripod'),
    ('灯架', 'light stand'),
    ('支架', 'c stand'),
    ('快装板', 'quick release plate'),
    ('快门线', 'shutter release cable'),
    ('减光镜', 'nd filter'),
    ('滤镜', 'camera filter'),
    ('相机包', 'camera bag'),
    ('沙袋', 'sandbag'),
)

LICENSE_ALLOW = 'cc0,by,pdm'


def _openverse(query: str, limit: int = 6) -> list:
    params = urllib.parse.urlencode({
        'q': query,
        'license': LICENSE_ALLOW,
        'page_size': max(1, min(20, limit)),
        'mature': 'false',
    })
    url = '%s?%s' % (OV_API, params)
    try:
        text = common.polite_get(url, timeout=12, retries=1)
        import json as _json
        payload = _json.loads(text)
    except Exception:  # noqa: BLE001
        return []
    out = []
    for r in payload.get('results') or []:
        image_url = str(r.get('url') or '')
        if not image_url:
            continue
        out.append(Candidate(
            provider='openverse',
            image_url=image_url,
            page_url=str(r.get('foreign_landing_url') or ''),
            title=str(r.get('title') or '')[:120],
            license=str(r.get('license') or '') + ' ' + str(r.get('license_version') or ''),
            extra={'creator': str(r.get('creator') or 'Openverse contributor')},
        ))
    return out


def _pexels(query: str, key: str, limit: int = 3) -> list:
    """Pexels 氛围实拍兜底（V4 规则：仅道具/通用附件，标注非官方产品图）。"""
    if not key:
        return []
    params = urllib.parse.urlencode({'query': query, 'per_page': max(1, min(10, limit))})
    try:
        text = common.polite_get(
            '%s?%s' % (PEXELS_SEARCH, params), timeout=30,
            headers={'Authorization': key})
        import json as _json
        payload = _json.loads(text)
    except Exception:  # noqa: BLE001
        return []
    out = []
    for p in payload.get('photos') or []:
        src = p.get('src') or {}
        image_url = src.get('large2x') or src.get('original') or src.get('large')
        if not image_url:
            continue
        out.append(Candidate(
            provider='pexels',
            image_url=image_url,
            page_url=str(p.get('url') or ''),
            title=str(p.get('alt') or '')[:120],
            license='Pexels License（氛围实拍，非官方产品图）',
            extra={'photographer': str(p.get('photographer') or 'Pexels')},
        ))
    return out


def queries_for(item: dict) -> list:
    kind = str(item.get('kind') or '')
    gear_id = str(item.get('id') or '')
    if kind == 'props':
        q = PROP_QUERIES.get(gear_id)
        return [q] if q else [str(item.get('model') or '')]
    model = str(item.get('model') or '')
    brand = str(item.get('brand') or '')
    qs = []
    if kind == 'accessory':
        text = model
        terms = []
        for cn, en in ACCESSORY_TERMS:
            if cn in text:
                terms.append(en)
                text = text.replace(cn, ' ')
        digits = re.findall(r'\d+(?:\.\d+)?\s*(?:cm|mm|m|寸|英寸)?', text)
        base = ' '.join(terms) or (brand + ' ' + model).strip()
        if digits:
            base = '%s %s' % (base, ' '.join(digits[:2]))
        qs.append(base.strip())
    else:
        qs.append(('%s %s' % (brand, model)).strip())
    return [q for q in qs if q]


class KeywordProvider(Provider):
    name = 'keyword'

    def __init__(self, pexels_key: str = ''):
        self.pexels_key = pexels_key
        self.last_reason = ''

    def search(self, item: dict) -> list:
        out = []
        for query in queries_for(item):
            out.extend(_openverse(query))
            if len(out) >= 4:
                break
        if not out and str(item.get('kind')) in ('props', 'accessory') and self.pexels_key:
            for query in queries_for(item):
                out.extend(_pexels(query, self.pexels_key))
                if out:
                    break
        if not out:
            self.last_reason = '开放图源无结果（Openverse license=cc0,by,pdm）'
        else:
            self.last_reason = ''
        return out[:4]
