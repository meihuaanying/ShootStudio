# -*- coding: utf-8 -*-
"""gear_photos_v3 provider 注册表。"""
from __future__ import annotations

from .amazon import AmazonProvider
from .base import Candidate, Provider
from .jd import JdProvider
from .keyword import KeywordProvider
from .official import OfficialProvider
from .retail import RetailProvider
from .taobao import TaobaoProvider

PROVIDER_ORDER = ('official', 'retail', 'jd', 'amazon', 'taobao', 'keyword')


def build_providers(names=None, pexels_key: str = '') -> list:
    wanted = set(names or PROVIDER_ORDER)
    out = []
    if 'official' in wanted:
        out.append(OfficialProvider())
    if 'retail' in wanted:
        out.append(RetailProvider())
    if 'jd' in wanted:
        out.append(JdProvider())
    if 'amazon' in wanted:
        out.append(AmazonProvider())
    if 'taobao' in wanted:
        out.append(TaobaoProvider())
    if 'keyword' in wanted:
        out.append(KeywordProvider(pexels_key=pexels_key))
    return out


__all__ = ['Candidate', 'Provider', 'PROVIDER_ORDER', 'build_providers']
