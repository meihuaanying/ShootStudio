# -*- coding: utf-8 -*-
"""R48 离线 fixture 自测：不触网验证抓取管线（provider + 端到端 fetch）。

用法（工作目录 app/）：
  python tool/gear_photos_v3/selftest.py

覆盖：
  1. offline 守卫：GEAR_V3_OFFLINE=1 时 polite_get 直接拒绝联网；
  2. 官网 provider 三种路径：
     - godox：index.json + 产品页主图（product 命中）；
     - aputure：Shopify suggest.json；
     - viltrox：sitemapindex → urlset → 产品页主图（series 命中）；
  3. run.fetch 端到端（临时池在 app/build/ 内，结束后清理，不写入真实
     tool/gear_photo_pool 与 assets 元数据）：
     - 成功项写元数据 + 原图/规范图 + 指纹（1100×825/4:3）；
     - 缺 fixture 项登记失败，默认跳过；--retry-failed/--force 重试计数；
  4. 失败即非零退出码，可直接接 CI/本地门禁。
"""
from __future__ import annotations

import os
import shutil
import sys
import tempfile
import traceback
from types import SimpleNamespace

TOOL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if TOOL_DIR not in sys.path:
    sys.path.insert(0, TOOL_DIR)

os.environ['GEAR_V3_OFFLINE'] = '1'

from gear_photos_v3 import common, run  # noqa: E402
from gear_photos_v3.providers import build_providers  # noqa: E402

# (id, brand, model, tier)：与 fixtures/ 下样例一一对应。
CASES = (
    ('light-g6-18', '神牛', 'SL100W', 'product'),
    ('light-g6-169', '爱图仕', 'Amaran 60d', 'product'),
    ('lens-g6-109', '唯卓仕', 'AF 16mm F1.8', 'series'),
)
MISSING_ID = 'light-g6-19'  # 神牛 AD100Pro：无 fixture，用于失败/重试状态机。
GEAR_ITEMS = {c[0]: c for c in CASES}


def check(cond, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)
    print('  ok - %s' % msg)


def _fetch_args(ids, retry_failed=False, force=False):
    return SimpleNamespace(ids=set(ids), kinds=None, limit=0, providers='official',
                           retry_failed=retry_failed, force=force)


def test_offline_guard() -> None:
    print('[selftest] 1/4 offline 守卫')
    check(common.offline(), 'GEAR_V3_OFFLINE=1 生效')
    try:
        common.polite_get('https://example.com/never-reached.jpg')
    except common.FetchError as exc:
        check('离线模式禁止联网' in str(exc), 'polite_get 拒绝联网（%s）' % str(exc)[:60])
    else:
        raise AssertionError('离线模式仍发起了网络请求')


def test_providers() -> None:
    print('[selftest] 2/4 官网 provider（godox/aputure/viltrox）')
    items = {it['id']: it for it in run.load_items()}
    providers = {p.name: p for p in build_providers(names=['official'], pexels_key='')}
    official = providers['official']
    for gear_id, brand, model, tier in CASES:
        item = items[gear_id]
        check(item['brand'] == brand and item['model'] == model,
              '%s 目录项 %s %s' % (gear_id, brand, model))
        cands = official.search(item)
        check(bool(cands), '%s 命中候选 %d 条' % (gear_id, len(cands)))
        cand = cands[0]
        check(cand.provider == 'official' and cand.image_url.startswith('http'),
              '%s imageUrl=%s' % (gear_id, cand.image_url[:64]))
        check(cand.extra.get('tier') == tier,
              '%s tier=%s（期望 %s）' % (gear_id, cand.extra.get('tier'), tier))
        data = run._download(cand, item)
        fp = common.image_fingerprint(data)
        check(fp['width'] >= 350 and fp['height'] >= 350,
              '%s fixture 图片 %dx%d' % (gear_id, fp['width'], fp['height']))


def _read_state(pool_dir):
    return common.read_json(os.path.join(pool_dir, 'state.json'), {})


def test_fetch_pipeline(tmp: str) -> None:
    print('[selftest] 3/4 run.fetch 端到端（临时池）')
    common.POOL_DIR = os.path.join(tmp, 'v3')
    common.SOURCES_ASSET = os.path.join(tmp, 'gear_photo_sources.json')
    real_sources = os.path.join(common.APP_ROOT, 'assets', 'content', 'gear',
                                'gear_photo_sources.json')
    before = open(real_sources, 'rb').read() if os.path.exists(real_sources) else b''

    run.fetch(_fetch_args(GEAR_ITEMS))
    sources = common.read_json(common.SOURCES_ASSET, {})
    records = sources.get('items') or {}
    check(set(records) == set(GEAR_ITEMS), '元数据写入 3 条：%s' % sorted(records))
    for gear_id, record in records.items():
        check(record['provider'] == 'official', '%s provider=official' % gear_id)
        check(record['license'] and record['fetchedAt'].count('T') == 1,
              '%s 许可/时间齐全' % gear_id)
        check(len(record['sha1']) == 40 and record['width'] > 0 and record['height'] > 0,
              '%s 指纹/尺寸齐全' % gear_id)
        raw = os.path.join(common.REPO_ROOT, record['rawPath'])
        norm = os.path.join(common.REPO_ROOT, record['normPath'])
        check(os.path.exists(raw) and os.path.exists(norm),
              '%s 原图/规范图落临时池' % gear_id)
        with open(norm, 'rb') as fh:
            fp = common.image_fingerprint(fh.read())
        check(fp['width'] == 1100 and fp['height'] == 825,
              '%s 规范图 1100x825（4:3）' % gear_id)

    state = _read_state(common.POOL_DIR)
    check(set(state.get('done') or {}) == set(GEAR_ITEMS), 'state.done 3 条')
    check(not (state.get('failed') or {}), 'state.failed 为空')
    after = open(real_sources, 'rb').read() if os.path.exists(real_sources) else b''
    check(before == after, '真实元数据未被污染')

    print('[selftest] 4/4 断点续跑 / 失败重试 / --force')
    run.fetch(_fetch_args({MISSING_ID}))
    state = _read_state(common.POOL_DIR)
    failed = state.get('failed') or {}
    check(MISSING_ID in failed and failed[MISSING_ID]['attempts'] == 1,
          '%s 失败登记 attempts=1' % MISSING_ID)
    check(bool(failed[MISSING_ID]['reason']), '失败原因已记录')
    records = common.read_json(common.SOURCES_ASSET, {}).get('items') or {}
    check(MISSING_ID not in records, '失败项不写元数据')

    run.fetch(_fetch_args({MISSING_ID}))
    state = _read_state(common.POOL_DIR)
    check((state.get('failed') or {})[MISSING_ID]['attempts'] == 1,
          '未 --retry-failed 时跳过（attempts 不再增加）')
    run.fetch(_fetch_args({MISSING_ID}, retry_failed=True))
    state = _read_state(common.POOL_DIR)
    check((state.get('failed') or {})[MISSING_ID]['attempts'] == 2,
          '--retry-failed 重试（attempts=2）')

    done_id = CASES[0][0]
    first_at = (common.read_json(common.SOURCES_ASSET, {})
                .get('items', {}).get(done_id, {}).get('fetchedAt'))
    run.fetch(_fetch_args({done_id}))
    same_at = (common.read_json(common.SOURCES_ASSET, {})
               .get('items', {}).get(done_id, {}).get('fetchedAt'))
    check(first_at == same_at, 'done 项默认跳过（fetchedAt 未变）')
    run.fetch(_fetch_args({done_id}, force=True))
    records = common.read_json(common.SOURCES_ASSET, {}).get('items') or {}
    check(done_id in records, '--force 重新抓取仍写回元数据')


def main() -> int:
    base = os.path.join(common.APP_ROOT, 'build')
    os.makedirs(base, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix='gear_v3_selftest_', dir=base)
    try:
        test_offline_guard()
        test_providers()
        test_fetch_pipeline(tmp)
        print('[selftest] PASS：R48 离线 fixture（3 品牌 / 端到端 / 断点续跑 / 失败重试）')
        return 0
    except Exception:  # noqa: BLE001
        traceback.print_exc()
        print('[selftest] FAIL')
        return 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
