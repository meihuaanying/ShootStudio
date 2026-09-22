# -*- coding: utf-8 -*-
"""淘宝 provider（D130 末位优先级：反爬严重，记录跳过原因）。"""
from __future__ import annotations

from .base import Provider


class TaobaoProvider(Provider):
    name = 'taobao'
    last_reason = ''

    def search(self, item: dict) -> list:
        self.last_reason = '淘宝反爬（无可用匿名接口），按合同降级跳过'
        return []
