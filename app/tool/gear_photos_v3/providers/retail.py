# -*- coding: utf-8 -*-
"""授权零售商 provider（V7/D142 第②层：B&H / Adorama；京东见 jd.py）。

- 用途：品牌官网不可达/无该型号时，从授权零售商公开搜索页取商品图（尽力而为）；
- 反爬/无服务端图链时记录 ``last_reason`` 并顺延（由第③层 series 兜底接管）；
- R48 离线 fixture：``fixtures/retail/<site>.html``（``GEAR_V3_OFFLINE=1`` 时不触网）。
"""
from __future__ import annotations

import os
import re
import urllib.parse

from .. import common
from .base import Candidate, Provider

FIXTURES = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'fixtures'
)

SITES = [
    {
        'id': 'bh',
        'label': 'B&H',
        'search': 'https://www.bhphotovideo.com/c/search?q=%s',
        'img_re': r'https://static\.bhphoto\.com/[^"\'\s>]+?\.(?:jpe?g|png)',
        'license': 'B&H 商品图（版权归品牌/平台，仅供选型参考）',
    },
    {
        'id': 'adorama',
        'label': 'Adorama',
        'search': 'https://www.adorama.com/searchsite/default.aspx?searchinfo=%s',
        'img_re': r'https://www\.adorama\.com/images/[^"\'\s>]+?\.(?:jpe?g|png)',
        'license': 'Adorama 商品图（版权归品牌/平台，仅供选型参考）',
    },
]


class RetailProvider(Provider):
    """授权零售商（B&H/Adorama）尽力而为 provider。"""

    name = 'retail'

    def __init__(self, sites=None):
        self.sites = list(sites or SITES)
        self.last_reason = ''

    def _html(self, site: dict, keyword: str) -> str:
        if common.offline():
            path = os.path.join(FIXTURES, 'retail', '%s.html' % site['id'])
            if not os.path.exists(path):
                return ''
            with open(path, encoding='utf-8') as fh:
                return fh.read()
        url = site['search'] % urllib.parse.quote(keyword)
        return common.polite_get(url, timeout=30)

    def search(self, item: dict) -> list:
        brand = str(item.get('brand') or '')
        model = str(item.get('model') or '')
        keyword = ('%s %s' % (brand, model)).strip()
        if not keyword:
            return []
        reasons = []
        for site in self.sites:
            try:
                html = self._html(site, keyword)
            except Exception as exc:  # noqa: BLE001
                reasons.append('%s：%s' % (site['label'], exc))
                continue
            if not html:
                reasons.append('%s：无响应内容' % site['label'])
                continue
            urls = [
                u
                for u in dict.fromkeys(re.findall(site['img_re'], html, re.I))
                if not re.search(r'logo|icon|sprite|placeholder', u, re.I)
            ]
            if not urls:
                reasons.append('%s：无服务端图链（JS 渲染/反爬）' % site['label'])
                continue
            self.last_reason = ''
            return [
                Candidate(
                    provider=self.name,
                    image_url=urls[0],
                    page_url=site['search'] % urllib.parse.quote(keyword),
                    title=keyword,
                    license=site['license'],
                    kind_hint=item.get('kind', ''),
                    extra={'site': site['id'], 'layer': 'retail'},
                )
            ]
        self.last_reason = '；'.join(reasons)
        return []
