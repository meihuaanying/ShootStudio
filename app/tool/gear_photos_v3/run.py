# -*- coding: utf-8 -*-
"""gear_photos_v3 抓取入口（D129–D131）。

用法（工作目录 app/）：
  python tool/gear_photos_v3/run.py fetch --kinds light,accessory --limit 20
  python tool/gear_photos_v3/run.py fetch --ids light-205,acc-g6-237 --providers official,keyword
  python tool/gear_photos_v3/run.py fetch --retry-failed
  python tool/gear_photos_v3/run.py status

约定：
  - 图片只落 tool/gear_photo_pool/v3/（不入 git）；元数据写 assets/content/gear/gear_photo_sources.json；
  - 断点续跑：state.json 记录 done/failed/attempts，默认跳过已成功项；
  - 离线自测（R48）：GEAR_V3_OFFLINE=1 时 provider 读 fixtures/、图片从 fixtures 取；
    一键自测：python tool/gear_photos_v3/selftest.py（不触网）。
"""
from __future__ import annotations

import argparse
import os
import sys

TOOL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if TOOL_DIR not in sys.path:
    sys.path.insert(0, TOOL_DIR)

from gear_photos_v3 import common  # noqa: E402
from gear_photos_v3.brands import brand_config  # noqa: E402
from gear_photos_v3.providers import build_providers  # noqa: E402

FIXTURES = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fixtures')


def _offline() -> bool:
    return common.offline()


def load_items() -> list:
    gear = common.read_json(common.GEAR_ASSET, {})
    items = []
    for it in gear.get('items') or []:
        items.append({
            'id': it.get('id'),
            'kind': it.get('kind'),
            'brand': it.get('brand') or '',
            'model': it.get('model') or '',
        })
    props = common.read_json(os.path.join(common.APP_ROOT, 'assets', 'content', 'props',
                                          'props_presets.json'), {})
    for p in props.get('props') or []:
        items.append({
            'id': p.get('id'),
            'kind': 'props',
            'brand': '',
            'model': p.get('name') or '',
        })
    return items


def covered_ids() -> set:
    out = set()
    p2 = common.read_json(common.PHOTOS2_ASSET, {})
    for key in ('byId', 'byModel'):
        out.update(str(k) for k in (p2.get(key) or {}))
    sources = common.read_json(common.SOURCES_ASSET, {})
    out.update(str(k) for k in (sources.get('items') or {}))
    return out


def _pexels_key() -> str:
    cfg = common.read_json(os.path.join(common.APP_ROOT, 'assets', 'config',
                                        'image_sources.json'), {})
    return str(((cfg.get('pexels') or {}).get('apiKey') or '')).strip()


def _download(candidate, item) -> bytes:
    if _offline():
        cfg = brand_config(item.get('brand', ''))
        roots = []
        if cfg:
            roots.append(os.path.join(FIXTURES, cfg['label']))
        roots.append(FIXTURES)
        for root in roots:
            for ext in ('.jpg', '.jpeg', '.png', '.webp'):
                path = os.path.join(root, '%s%s' % (item['id'], ext))
                if os.path.exists(path):
                    with open(path, 'rb') as fh:
                        return fh.read()
        raise common.FetchError('offline fixture 缺图片：%s' % item['id'])
    data, mime = common.polite_get(candidate.image_url, timeout=40, retries=3, binary=True)
    if mime and mime not in common.ALLOWED_MIME:
        raise common.FetchError('非图片 MIME：%s' % mime)
    return data


def fetch(args) -> int:
    common.ensure_dirs()
    bucket = common.Bucket()
    sources = common.read_json(common.SOURCES_ASSET, {})
    records = dict(sources.get('items') or {})
    items = load_items()
    by_id = {i['id']: i for i in items}

    todo = []
    for item in items:
        gid = item['id']
        if args.ids and gid not in args.ids:
            continue
        if args.kinds and item['kind'] not in args.kinds:
            continue
        if gid in records and not args.force:
            continue
        if gid in bucket.failed and not args.retry_failed and not args.force:
            continue
        todo.append(item)
    if args.limit:
        todo = todo[:args.limit]

    providers = build_providers(
        names=[p.strip() for p in args.providers.split(',') if p.strip()],
        pexels_key=_pexels_key(),
    )
    print('[gear-v3] 待抓取 %d 条（已覆盖 %d / 目录 %d）' % (len(todo), len(records), len(items)))

    done_now = 0
    for item in todo:
        gid = item['id']
        manual = os.environ.get('GEAR_V3_MANUAL_IMAGE')  # 调试用：直接给图片路径
        reasons = []
        saved = False
        if manual and os.path.exists(manual):
            try:
                with open(manual, 'rb') as fh:
                    data = fh.read()
                fp = common.image_fingerprint(data)
                raw_path = common.save_raw(gid, data, os.path.splitext(manual)[1] or '.jpg')
                norm_path = common.save_norm(gid, data)
                records[gid] = _record(item, 'manual', manual, '', '手动补图', fp,
                                       raw_path, norm_path)
                bucket.mark_done(gid, {'provider': 'manual', 'at': common.now_iso()})
                done_now += 1
                print('[gear-v3] %s <- manual %s (%dx%d)' % (gid, manual, fp['width'], fp['height']))
                saved = True
            except Exception as exc:  # noqa: BLE001
                reasons.append('manual 失败：%s' % exc)
        if not saved:
            for provider in providers:
                try:
                    candidates = provider.search(item)
                except Exception as exc:  # noqa: BLE001
                    reasons.append('%s 异常：%s' % (provider.name, exc))
                    continue
                if not candidates:
                    reason = getattr(provider, 'last_reason', '')
                    if reason:
                        reasons.append('%s：%s' % (provider.name, reason))
                    continue
                for cand in candidates:
                    try:
                        data = _download(cand, item)
                        fp = common.image_fingerprint(data)
                        ratio = fp['width'] / max(1, fp['height'])
                        if min(fp['width'], fp['height']) < 350 or not (0.45 <= ratio <= 2.2):
                            raise common.FetchError('尺寸/比例不适合产品图（%dx%d）'
                                                    % (fp['width'], fp['height']))
                        raw_path = common.save_raw(gid, data)
                        norm_path = common.save_norm(gid, data)
                        records[gid] = _record(item, cand.provider, cand.image_url,
                                               cand.page_url, cand.license, cand.title,
                                               fp, raw_path, norm_path, cand.extra)
                        bucket.mark_done(gid, {'provider': cand.provider, 'at': common.now_iso()})
                        done_now += 1
                        print('[gear-v3] %s <- %s (%dx%d %dKB)' % (
                            gid, cand.provider, fp['width'], fp['height'], fp['bytes'] // 1024))
                        saved = True
                        break
                    except Exception as exc:  # noqa: BLE001
                        reasons.append('%s 下载失败：%s' % (cand.provider, exc))
                if saved:
                    break
        if not saved:
            bucket.mark_failed(gid, '; '.join(reasons)[:400] or '无候选')
            print('[gear-v3] %s 未获取：%s' % (gid, (reasons or ['无候选'])[0][:120]))
        if done_now and done_now % 5 == 0:
            _write_sources(records)
    _write_sources(records)
    print('[gear-v3] 完成：本轮新增 %d，累计 %d' % (done_now, len(records)))
    return 0


def _record(item, provider, image_url, page_url, license_text, title, fp,
            raw_path='', norm_path='', extra=None) -> dict:
    return {
        'gearId': item['id'],
        'kind': item['kind'],
        'brand': item.get('brand', ''),
        'model': item.get('model', ''),
        'provider': provider,
        'imageUrl': image_url,
        'pageUrl': page_url or '',
        'title': title or '',
        'license': license_text or '',
        'fetchedAt': common.now_iso(),
        'sha1': fp['sha1'],
        'width': fp['width'],
        'height': fp['height'],
        'bytes': fp['bytes'],
        'format': fp['format'],
        'rawPath': os.path.relpath(raw_path, common.REPO_ROOT).replace('\\', '/') if raw_path else '',
        'normPath': os.path.relpath(norm_path, common.REPO_ROOT).replace('\\', '/') if norm_path else '',
        **({'extra': extra} if extra else {}),
    }


def _write_sources(records: dict) -> None:
    common.write_json(common.SOURCES_ASSET, {
        'version': 1,
        'note': ('V6/E（D129–D131）：器材/道具参考图元数据（来源/许可/时间）。'
                 '图片仅存工作区与 tool/gear_photo_pool（不入 git、不入安装包）。'),
        'generatedAt': common.now_iso(),
        'count': len(records),
        'items': records,
    })


def status(args) -> int:
    items = load_items()
    records = common.read_json(common.SOURCES_ASSET, {}).get('items') or {}
    bucket = common.Bucket()
    by_kind = {}
    for it in items:
        stat = by_kind.setdefault(it['kind'], {'total': 0, 'covered': 0})
        stat['total'] += 1
        if it['id'] in records:
            stat['covered'] += 1
    for kind, stat in sorted(by_kind.items()):
        ratio = stat['covered'] / stat['total'] if stat['total'] else 0
        print('%-10s %3d/%-3d %.1f%%' % (kind, stat['covered'], stat['total'], ratio * 100))
    print('sources 条目：%d；失败暂存：%d' % (len(records), len(bucket.failed)))
    if bucket.failed:
        for gid, info in list(bucket.failed.items())[:10]:
            print('  - %s %s' % (gid, str(info.get('reason'))[:100]))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description='gear 参考图抓取（V6/E）')
    sub = parser.add_subparsers(dest='command')
    p_fetch = sub.add_parser('fetch')
    p_fetch.add_argument('--ids', default='')
    p_fetch.add_argument('--kinds', default='')
    p_fetch.add_argument('--limit', type=int, default=0)
    p_fetch.add_argument('--providers', default='official,jd,amazon,taobao,keyword')
    p_fetch.add_argument('--retry-failed', action='store_true')
    p_fetch.add_argument('--force', action='store_true')
    sub.add_parser('status')
    args = parser.parse_args()
    args.command = args.command or 'fetch'
    if args.command == 'fetch':
        if args.ids:
            args.ids = {x.strip() for x in args.ids.split(',') if x.strip()}
        if args.kinds:
            args.kinds = {x.strip() for x in args.kinds.split(',') if x.strip()}
        return fetch(args)
    return status(args)


if __name__ == '__main__':
    sys.exit(main())
