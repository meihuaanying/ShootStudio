# -*- coding: utf-8 -*-
"""Provider 基类与候选数据结构。"""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Candidate:
    provider: str
    image_url: str
    page_url: str = ''
    title: str = ''
    license: str = ''
    kind_hint: str = ''
    extra: dict = field(default_factory=dict)

    def as_record(self) -> dict:
        return {
            'provider': self.provider,
            'imageUrl': self.image_url,
            'pageUrl': self.page_url,
            'title': self.title,
            'license': self.license,
            'kindHint': self.kind_hint,
            **({'extra': self.extra} if self.extra else {}),
        }


class Provider:
    name = 'base'

    def search(self, item: dict) -> list:
        """item 来自 gear.json；返回按优先级排序的 Candidate 列表。"""
        raise NotImplementedError
