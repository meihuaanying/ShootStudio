# -*- coding: utf-8 -*-
"""亚马逊 provider（D130 末位优先级：反爬严重，记录跳过原因）。"""
from __future__ import annotations

from .base import Provider


class AmazonProvider(Provider):
    name = 'amazon'
    last_reason = ''

    def search(self, item: dict) -> list:
        self.last_reason = '亚马逊反爬（无可用匿名接口），按合同降级跳过'
        return []
