# -*- coding: utf-8 -*-
"""京东搜索 provider（D130 第二优先级，尽力而为）。

京东搜索页为 JS 渲染 + 风控，能拿到的图链有限；拿不到时记录原因并顺延。
"""
from __future__ import annotations

import re
import urllib.parse

from .. import common
from .base import Candidate, Provider


class JdProvider(Provider):
    name = 'jd'
    SEARCH = 'https://search.jd.com/Search'

    def __init__(self):
        self.last_reason = ''

    def search(self, item: dict) -> list:
        brand = str(item.get('brand') or '')
        model = str(item.get('model') or '')
        keyword = ('%s %s' % (brand, model)).strip()
        if not keyword:
            return []
        params = urllib.parse.urlencode({'keyword': keyword, 'enc': 'utf-8'})
        try:
            html = common.polite_get('%s?%s' % (self.SEARCH, params), timeout=30)
        except Exception as exc:  # noqa: BLE001
            self.last_reason = '搜索失败：%s' % exc
            return []
        urls = []
        for raw in re.findall(r'data-lazy-img=["\']([^"\']+)["\']', html, re.I):
            urls.append(raw if raw.startswith('http') else 'https:' + raw)
        urls += re.findall(r'(//img\d+\.360buyimg\.com/[^"\'\s>]+\.(?:jpe?g|png))', html, re.I)
        urls = ['https:' + u if u.startswith('//') else u for u in urls]
        urls = [u for u in dict.fromkeys(urls) if not re.search(r'logo|icon|sprite', u, re.I)]
        if not urls:
            self.last_reason = '搜索页无服务端图链（JS 渲染/风控）'
            return []
        self.last_reason = ''
        return [Candidate(
            provider=self.name,
            image_url=urls[0],
            page_url='%s?%s' % (self.SEARCH, params),
            title=keyword,
            license='京东商品图（版权归品牌/平台，仅供选型参考）',
            kind_hint=item.get('kind', ''),
        )]
