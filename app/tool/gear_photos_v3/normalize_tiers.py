"""V7/D142：图源 tier/layer 标注补齐（幂等）。

历史（V6/E）图源条目中，部分 pexels 条目没有 extra.tier/layer 字段，
导致 UI 无法按四层兜底口径标注、来源抽检无法校验。本脚本按 provider 语义补齐：

- pexels/openverse（开放图源）→ tier='atmosphere'、layer='keyword'（氛围实拍/品类实拍）。
- 其余 provider 保持原样（official→official、retail→retail、series-fallback→series）。

用法（app/ 下）：python tool/gear_photos_v3/normalize_tiers.py [--dry-run]
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))  # app/tool

from gear_photos_v3 import common  # noqa: E402

OPEN_PROVIDERS = ('pexels', 'openverse')


def main() -> int:
    dry = '--dry-run' in sys.argv[1:]
    payload = common.read_json(common.SOURCES_ASSET, {}) or {}
    items = payload.get('items') or {}
    changed = []
    for gid in sorted(items):
        rec = items[gid]
        provider = str(rec.get('provider') or '')
        extra = rec.get('extra')
        if not isinstance(extra, dict):
            extra = {}
        if extra.get('tier'):
            continue
        if provider not in OPEN_PROVIDERS:
            continue
        extra['tier'] = 'atmosphere'
        extra['layer'] = 'keyword'
        extra['tierNote'] = 'V7/D142 标注补齐：开放图源按氛围实拍登记'
        rec['extra'] = extra
        changed.append(gid)
    print('[tiers] 待补齐 %d 条' % len(changed))
    if dry or not changed:
        return 0
    payload['items'] = items
    payload['generatedAt'] = common.now_iso()
    note = str(payload.get('note') or '')
    tag = 'V7/D142：开放图源 tier/layer 标注补齐（幂等）'
    if tag not in note:
        payload['note'] = (note + '；' + tag).strip('；')
    common.write_json(common.SOURCES_ASSET, payload)
    print('[tiers] 已写回 %s' % common.SOURCES_ASSET)
    return 0


if __name__ == '__main__':
    sys.exit(main())
