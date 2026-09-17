#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""器材产品图规范化（D71–D73 / R22/R24）——「官网展示标准」版。

输入：tool/gen_product_photos.py 的原始图清单（<raw>/manifest.json，version 2）
输出：
  - app/assets/content/gear/photo2/<gearId>.jpg  纯白 4:3、长边 1100、JPEG q84、去 EXIF
  - app/assets/content/gear/gear_photos2.json    byModel/byKind/byId + stats（含 Top100 内置标记）
  - app/assets/content/attribution.json          追加 photo2 条目（保留原 items，按 file 去重）

规范化：
  白/中性底检测 → Otsu 最大连通域 bbox（无则中心 80% 裁切）→ 纯白 4:3 画布、
  主体占比 ≥70%（6% 边距）、长边 1100、JPEG q84、去 EXIF、灰世界白平衡（≤8%）、轻度去噪。
  内置 = camera priceRef 前 60 + lens 前 40（必须 tier=product）；内置文件总量 ≤15MB，
  超预算优先降 q/长边，不缩减覆盖。非内置文件同样落盘（builtin=false），由构建侧决定打包。

用法：
  python3 tool/normalize_product_photos.py [--raw <dir>] [--limit N]
      [--long 1100] [--quality 84] [--only-kind camera,lens]
"""

import argparse
import json
import os
import re
import sys
import tempfile
import time

import numpy as np
from PIL import Image, ImageFilter, ImageOps


def clean_url(value):
    """去掉 Wikimedia API 附带的 utm_* 查询参数。"""
    u = str(value or '').strip()
    if '?' not in u:
        return u
    base, query = u.split('?', 1)
    keep = [p for p in query.split('&')
            if p and not p.startswith('utm_')]
    return base + (('?' + '&'.join(keep)) if keep else '')


def runtime_url(entry):
    """运行时源：Openverse 缩略图代理优先；Wikimedia 用 1400px 缩略（体积可控）。"""
    rt = clean_url(entry.get('runtimeUrl') or entry.get('sourceUrl') or '')
    rt = rt.replace('https://thumb.wikimedia.org/', 'https://upload.wikimedia.org/')
    src = clean_url(entry.get('sourceUrl') or '')
    if 'api.openverse.org' in rt:
        return rt
    if 'upload.wikimedia.org' in src and '/thumb/' not in src:
        m = re.match(
            r'(https://upload\.wikimedia\.org/wikipedia/[^/]+)/([0-9a-f])/'
            r'([0-9a-f]{2})/([^/]+)$', src)
        if m:
            base, d1, d2, name = m.groups()
            if not name.lower().endswith('.svg'):
                return '%s/thumb/%s/%s/%s/1400px-%s' % (base, d1, d2, name, name)
    return rt

WHITE = (255, 255, 255)
A4_W, A4_H = 4, 3  # 4:3 画布
BUILTIN_BUDGET = 15 * 1000 * 1000


def load_json(path, default):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return default


def save_json(path, obj):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


def otsu_threshold(gray):
    hist = np.bincount(gray.ravel(), minlength=256).astype(np.float64)
    total = hist.sum()
    if total <= 0:
        return 127
    sum_all = float(np.dot(np.arange(256), hist))
    sum_b = 0.0
    w_b = 0.0
    best_t = 127
    best_var = -1.0
    for t in range(256):
        w_b += hist[t]
        if w_b <= 0:
            continue
        w_f = total - w_b
        if w_f <= 0:
            break
        sum_b += t * hist[t]
        m_b = sum_b / w_b
        m_f = (sum_all - sum_b) / w_f
        var = w_b * w_f * (m_b - m_f) ** 2
        if var > best_var:
            best_var = var
            best_t = t
    return best_t


def largest_component_bbox(mask, max_edge=224):
    """mask: 2D bool → 最大连通区域 bbox (x0,y0,x1,y1) 或 None。"""
    h, w = mask.shape
    if h < 2 or w < 2 or not mask.any():
        return None
    scale = max(h, w) / float(max_edge)
    if scale > 1.0:
        sw = max(1, int(round(w / scale)))
        sh = max(1, int(round(h / scale)))
        small = np.asarray(
            Image.fromarray((mask * 255).astype(np.uint8)).resize(
                (sw, sh), Image.NEAREST)) > 96
    else:
        small = mask
        sh, sw = h, w

    parent = {}

    def find(x):
        root = x
        while parent[root] != root:
            root = parent[root]
        while parent[x] != root:
            parent[x], x = root, parent[x]
        return root

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    next_id = 0
    prev = []
    runs = []
    for y in range(sh):
        row = small[y]
        d = np.diff(row.astype(np.int8))
        starts = (np.where(d == 1)[0] + 1).tolist()
        ends = (np.where(d == -1)[0] + 1).tolist()
        if row[0]:
            starts = [0] + starts
        if row[-1]:
            ends = ends + [sw]
        cur = []
        for s, e in zip(starts, ends):
            next_id += 1
            parent[next_id] = next_id
            for ps, pe, pid in prev:
                if ps < e and s < pe:
                    union(pid, next_id)
            cur.append((s, e, next_id))
            bord = 0
            if y == 0 or y == sh - 1:
                bord += e - s
            if s == 0:
                bord += 1
            if e == sw:
                bord += 1
            runs.append((y, s, e, next_id, bord))
        prev = cur

    comps = {}
    for y, s, e, rid, bord in runs:
        r = find(rid)
        st = comps.get(r)
        if st is None:
            comps[r] = [e - s, s, y, e, y, bord]
        else:
            st[0] += e - s
            st[1] = min(st[1], s)
            st[2] = min(st[2], y)
            st[3] = max(st[3], e)
            st[4] = max(st[4], y)
            st[5] += bord

    best = None
    for st in comps.values():
        area, x0, y0, x1, y1, bord = st
        if bord > area * 0.6 and area > 0.1 * sh * sw:
            continue
        if (x1 - x0) >= 0.96 * sw and (y1 - y0) >= 0.96 * sh:
            continue
        if area < 0.001 * sh * sw:
            continue
        if best is None or area > best[0]:
            best = (area, x0, y0, x1, y1)
    if best is None:
        return None
    _, x0, y0, x1, y1 = best
    fx = w / float(sw)
    fy = h / float(sh)
    return (int(x0 * fx), int(y0 * fy), int((x1 + 1) * fx), int((y1 + 1) * fy))


def gray_world(img, max_shift=0.08):
    arr = np.asarray(img, dtype=np.float32)
    means = arr.reshape(-1, 3).mean(axis=0)
    target = float(means.mean())
    factors = np.clip(target / np.maximum(means, 1.0), 1.0 - max_shift,
                      1.0 + max_shift)
    if np.allclose(factors, 1.0, atol=1e-3):
        return img
    out = np.clip(arr * factors.reshape(1, 1, 3), 0, 255).astype(np.uint8)
    return Image.fromarray(out, 'RGB')


def apply_gain(img, gain):
    arr = np.asarray(img, dtype=np.float32)
    out = np.clip(arr * np.asarray(gain, dtype=np.float32).reshape(1, 1, 3), 0,
                  255).astype(np.uint8)
    return Image.fromarray(out, 'RGB')


def compose_white(img_crop, long_edge):
    """主体裁剪 → 4:3 纯白底画布，居中，长边留 6% 边距（主体占比 ≥70%）。"""
    w, h = img_crop.size
    cw = int(long_edge)
    ch = int(round(long_edge * A4_H / A4_W))
    fit = min(cw * 0.88 / float(w), ch * 0.88 / float(h))
    nw = max(1, int(round(w * fit)))
    nh = max(1, int(round(h * fit)))
    resized = img_crop.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new('RGB', (cw, ch), WHITE)
    canvas.paste(resized, ((cw - nw) // 2, (ch - nh) // 2))
    fill = max(nw / float(cw), nh / float(ch))
    return canvas, fill


def saliency_box(im, frac=0.8):
    """非白底且无可靠主体 bbox 时：按边缘能量取 80% 窗口（替代中心裁切）。"""
    w, h = im.size
    sw = max(1, w // 8)
    sh = max(1, h // 8)
    g = np.asarray(im.convert('L').resize((sw, sh), Image.BILINEAR),
                   dtype=np.float32)
    gx = np.abs(np.diff(g, axis=1))
    gy = np.abs(np.diff(g, axis=0))
    energy = np.zeros_like(g)
    energy[:, :-1] += gx
    energy[:-1, :] += gy
    ii = energy.cumsum(axis=0).cumsum(axis=1)

    def rect_sum(x0, y0, x1, y1):
        total = ii[y1 - 1, x1 - 1]
        if x0 > 0:
            total -= ii[y1 - 1, x0 - 1]
        if y0 > 0:
            total -= ii[y0 - 1, x1 - 1]
        if x0 > 0 and y0 > 0:
            total += ii[y0 - 1, x0 - 1]
        return total

    bw = max(1, int(round(sw * frac)))
    bh = max(1, int(round(sh * frac)))
    step = max(1, min(sw, sh) // 24)
    best = None
    for y0 in range(0, sh - bh + 1, step):
        for x0 in range(0, sw - bw + 1, step):
            score = rect_sum(x0, y0, min(sw, x0 + bw), min(sh, y0 + bh))
            if best is None or score > best[0]:
                best = (score, x0, y0)
    if best is None:
        return None
    _, x0, y0 = best
    fx = w / float(sw)
    fy = h / float(sh)
    return (int(x0 * fx), int(y0 * fy), int(min(w, (x0 + bw) * fx)),
            int(min(h, (y0 + bh) * fy)))


def border_stats(img):
    arr = np.asarray(img.convert('L'), dtype=np.float32)
    h, w = arr.shape
    bh = max(1, int(round(h * 0.02)))
    bw = max(1, int(round(w * 0.02)))
    edge = np.concatenate([
        arr[:bh, :].ravel(),
        arr[h - bh:, :].ravel(),
        arr[:, :bw].ravel(),
        arr[:, w - bw:].ravel(),
    ])
    return float(edge.mean()), float(edge.std())


def normalize_image(src_path, long_edge, quality):
    """返回 (PIL.Image, info) 或 (None, reason)。"""
    try:
        with Image.open(src_path) as im0:
            im = ImageOps.exif_transpose(im0)
            im = im.convert('RGB')
    except Exception as e:  # noqa: BLE001
        return None, 'open-failed:%s' % e
    w, h = im.size
    if w < 240 or h < 240:
        return None, 'too-small:%dx%d' % (w, h)
    if max(w, h) > 2200:
        f = 2200.0 / max(w, h)
        im = im.resize((max(1, int(round(w * f))), max(1, int(round(h * f)))),
                       Image.LANCZOS)
        w, h = im.size

    arr = np.asarray(im, dtype=np.uint8)
    gray = np.asarray(im.convert('L'), dtype=np.uint8)
    bh = max(1, int(round(h * 0.02)))
    bw = max(1, int(round(w * 0.02)))
    border = np.concatenate([
        arr[:bh, :, :].reshape(-1, 3),
        arr[h - bh:, :, :].reshape(-1, 3),
        arr[:, :bw, :].reshape(-1, 3),
        arr[:, w - bw:, :].reshape(-1, 3),
    ])
    edge_mean = float(border.mean())
    edge_std = float(border.std())
    white_bg = edge_mean > 232 and edge_std < 14

    bbox = None
    if white_bg:
        mask = gray < 245
        bbox = largest_component_bbox(mask)
        mode = 'white'
    else:
        t = otsu_threshold(gray)
        bbox_dark = largest_component_bbox(gray < t)
        bbox_light = largest_component_bbox(gray >= t)

        def area(b):
            return max(0, b[2] - b[0]) * max(0, b[3] - b[1])

        cands = [b for b in (bbox_dark, bbox_light) if b is not None]
        if cands:
            pick = max(cands, key=area)
            # 几乎整图 → 视为无主体，走 80% 裁切
            if area(pick) < 0.90 * w * h:
                bbox = pick
        mode = 'cutout'
    if bbox is None:
        bbox = saliency_box(im, 0.8)
        if bbox is None:
            bbox = (int(w * 0.1), int(h * 0.1), int(w * 0.9), int(h * 0.9))
        mode += '+saliency80'
    pad = int(round(min(w, h) * 0.03))
    x0 = max(0, bbox[0] - pad)
    y0 = max(0, bbox[1] - pad)
    x1 = min(w, bbox[2] + pad)
    y1 = min(h, bbox[3] + pad)
    if x1 - x0 < 40 or y1 - y0 < 40:
        x0, y0, x1, y1 = int(w * 0.1), int(h * 0.1), int(w * 0.9), int(h * 0.9)
    crop = im.crop((x0, y0, x1, y1))
    if white_bg:
        gain = np.clip(255.0 / np.maximum(border.mean(axis=0), 1.0), 1.0, 1.15)
        crop = apply_gain(crop, gain)

    crop = gray_world(crop)
    crop = crop.filter(ImageFilter.GaussianBlur(0.4))  # 轻度去噪
    canvas, fill = compose_white(crop, long_edge)
    bm, bs = border_stats(canvas)
    return canvas, {
        'mode': mode,
        'srcBorderMean': round(edge_mean, 1),
        'srcBorderStd': round(edge_std, 1),
        'fill': round(fill, 3),
        'outBorderMean': round(bm, 1),
        'outBorderStd': round(bs, 1),
    }


def encode_jpeg(img, path, quality):
    img.save(path, format='JPEG', quality=quality, optimize=True,
             progressive=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--raw', default=os.path.join(
        tempfile.gettempdir(), 'shootstudio_gear_raw2'))
    ap.add_argument('--gear', default='assets/content/gear/gear.json')
    ap.add_argument('--out', default='assets/content/gear/photo2')
    ap.add_argument('--json-out', default='assets/content/gear/gear_photos2.json')
    ap.add_argument('--attribution', default='assets/content/attribution.json')
    ap.add_argument('--quality', type=int, default=84)
    ap.add_argument('--long', type=int, default=1100)
    ap.add_argument('--only-kind', default='')
    ap.add_argument('--limit', type=int, default=0)
    args = ap.parse_args()

    gear = load_json(args.gear, {'items': []})
    items = gear.get('items', [])
    by_id_item = {str(i['id']): i for i in items}
    only = {s.strip() for s in args.only_kind.split(',') if s.strip()}

    def top(kind, n):
        pool = [i for i in items if i.get('kind') == kind]
        pool.sort(key=lambda i: (-(i.get('priceRef') or 0), str(i.get('id'))))
        return [str(i['id']) for i in pool[:n]]

    builtin_top100 = top('camera', 60) + top('lens', 40)
    builtin_set = set(builtin_top100)

    manifest = load_json(os.path.join(args.raw, 'manifest.json'), {})
    entries = manifest.get('items', {}) if isinstance(manifest, dict) else {}

    os.makedirs(args.out, exist_ok=True)
    produced = {}
    missing = []
    failed = []
    t0 = time.time()
    done = 0

    for gid, entry in entries.items():
        if args.limit and done >= args.limit:
            break
        kind = str(entry.get('kind') or (by_id_item.get(gid) or {}).get('kind')
                   or 'other')
        if only and kind not in only:
            continue
        done += 1
        if entry.get('status') != 'ok':
            missing.append(gid)
            continue
        raw = str(entry.get('rawFile') or '')
        if not raw or not os.path.exists(raw):
            missing.append(gid)
            continue
        img, info = normalize_image(raw, args.long, args.quality)
        if img is None:
            failed.append('%s:%s' % (gid, info))
            missing.append(gid)
            continue
        out_path = os.path.join(args.out, '%s.jpg' % gid)
        encode_jpeg(img, out_path, args.quality)
        size = os.path.getsize(out_path)
        item = by_id_item.get(gid) or {}
        produced[gid] = {
            'file': '%s.jpg' % gid,
            'id': gid,
            'kind': kind,
            'brand': str(entry.get('brand') or item.get('brand') or ''),
            'model': str(entry.get('model') or item.get('model') or ''),
            'displayName': str(
                entry.get('displayName')
                or '%s %s' % (item.get('brand') or '',
                              item.get('model') or '')).strip(),
            'tier': str(entry.get('tier') or 'product'),
            'source': str(entry.get('source') or ''),
            'license': str(entry.get('license') or ''),
            'author': str(entry.get('author') or ''),
            'pageUrl': clean_url(entry.get('pageUrl') or ''),
            'sourceUrl': clean_url(entry.get('sourceUrl') or ''),
            'runtimeUrl': runtime_url(entry),
            'builtin': gid in builtin_set,
            'bytes': size,
            'fill': info['fill'],
            'width': img.size[0],
            'height': img.size[1],
        }
        if entry.get('note'):
            produced[gid]['note'] = str(entry['note'])
        if entry.get('seriesOf'):
            produced[gid]['seriesOf'] = str(entry['seriesOf'])
        if (done % 50) == 0:
            print('[norm] %d  %.1fs  last=%s %dKB fill=%.2f' %
                  (done, time.time() - t0, gid, size // 1024, info['fill']),
                  flush=True)

    # ---- 内置预算（R22：内置产品图 ≤15MB；不缩覆盖，只降质量/尺寸） ----
    def builtin_bytes():
        return sum(r['bytes'] for r in produced.values() if r['builtin'])

    def builtin_list():
        return [gid for gid, r in produced.items() if r['builtin']]

    budget_note = ''
    for quality in (78, 72, 66):
        if builtin_bytes() <= BUILTIN_BUDGET:
            break
        for gid in builtin_list():
            rec = produced[gid]
            path = os.path.join(args.out, rec['file'])
            with Image.open(path) as im:
                encode_jpeg(im.convert('RGB'), path, quality)
            rec['bytes'] = os.path.getsize(path)
        budget_note = 'q=%d' % quality
    if builtin_bytes() > BUILTIN_BUDGET:
        long_edge = 1000
        for gid in builtin_list():
            rec = produced[gid]
            raw = str((entries.get(gid) or {}).get('rawFile') or '')
            if not raw or not os.path.exists(raw):
                continue
            img, _ = normalize_image(raw, long_edge, 72)
            if img is None:
                continue
            path = os.path.join(args.out, rec['file'])
            encode_jpeg(img, path, 72)
            rec['bytes'] = os.path.getsize(path)
            rec['width'], rec['height'] = img.size
        budget_note = 'long=%d q=72' % long_edge

    # 清理历史残留（photo2 中已无对应 manifest 条目的 jpg）
    keep = {'%s.jpg' % gid for gid in produced}
    for name in os.listdir(args.out):
        if name.lower().endswith('.jpg') and name not in keep:
            try:
                os.remove(os.path.join(args.out, name))
            except OSError:
                pass
    for gid in list(produced):
        path = os.path.join(args.out, produced[gid]['file'])
        if not os.path.exists(path):
            produced.pop(gid)
            missing.append(gid)

    # ---- byModel / byKind / byId ----
    def public_rec(rec):
        out = {k: rec[k] for k in (
            'file', 'tier', 'source', 'license', 'author', 'runtimeUrl',
            'id', 'kind', 'brand', 'model', 'displayName', 'builtin', 'bytes',
            'pageUrl', 'sourceUrl', 'width', 'height', 'fill') if k in rec}
        if rec.get('note'):
            out['note'] = rec['note']
        if rec.get('seriesOf'):
            out['seriesOf'] = rec['seriesOf']
        return out

    by_model = {}
    by_kind = {}
    by_id = {}
    for gid, rec in sorted(produced.items()):
        pub = public_rec(rec)
        by_id[gid] = pub
        by_kind.setdefault(rec['kind'], []).append(pub)
        name = rec['displayName']
        if name and name not in by_model:
            by_model[name] = pub

    # ---- stats ----
    kind_totals = {}
    for item in items:
        kind_totals[str(item.get('kind'))] = kind_totals.get(
            str(item.get('kind')), 0) + 1
    coverage = {}
    for kind, total in kind_totals.items():
        covered = sum(1 for r in produced.values() if r['kind'] == kind)
        tier_product = sum(1 for r in produced.values()
                           if r['kind'] == kind and r['tier'] == 'product')
        coverage[kind] = {
            'covered': covered,
            'product': tier_product,
            'total': total,
            'ratio': round(covered / total, 4) if total else 0.0,
        }
    tier_counts = {'product': 0, 'series': 0}
    tiers_by_kind = {}
    src_counts = {'openverse': 0, 'wikimedia': 0, 'wikipedia': 0, 'other': 0}
    runtime_src = {'openverse': 0, 'wikimedia': 0, 'other': 0}
    series_detail = []
    for gid, rec in sorted(produced.items()):
        tier = rec['tier']
        tier_counts[tier] = tier_counts.get(tier, 0) + 1
        tiers_by_kind.setdefault(rec['kind'], {'product': 0, 'series': 0})
        tiers_by_kind[rec['kind']][tier] = \
            tiers_by_kind[rec['kind']].get(tier, 0) + 1
        src = rec['source'] if rec['source'] in src_counts else 'other'
        src_counts[src] += 1
        rt = rec['runtimeUrl']
        if 'api.openverse.org' in rt:
            runtime_src['openverse'] += 1
        elif 'upload.wikimedia.org' in rt:
            runtime_src['wikimedia'] += 1
        else:
            runtime_src['other'] += 1
        if tier == 'series':
            series_detail.append({
                'id': gid,
                'displayName': rec['displayName'],
                'seriesOf': rec.get('seriesOf', ''),
                'note': rec.get('note', '同系列示意'),
            })
    missing_ids = []
    for item in items:
        gid = str(item.get('id'))
        if only and str(item.get('kind')) not in only:
            continue
        if gid not in produced:
            missing_ids.append(gid)
    missing_detail = []
    for gid in missing_ids:
        item = by_id_item.get(gid) or {}
        missing_detail.append({
            'id': gid,
            'kind': str(item.get('kind') or ''),
            'displayName': '%s %s' % (item.get('brand') or '',
                                      item.get('model') or ''),
        })
    builtin_present = [gid for gid in builtin_top100 if gid in produced]
    builtin_product = [gid for gid in builtin_present
                       if produced[gid]['tier'] == 'product']
    builtin_missing = [gid for gid in builtin_top100 if gid not in produced]
    b_bytes = builtin_bytes()

    stats = {
        'cameraCoverage': coverage.get('camera', {}).get('ratio', 0.0),
        'lensCoverage': coverage.get('lens', {}).get('ratio', 0.0),
        'lightCoverage': coverage.get('light', {}).get('ratio', 0.0),
        'accessoryCoverage': coverage.get('accessory', {}).get('ratio', 0.0),
        'coverage': coverage,
        'tier': tier_counts,
        'tierByKind': tiers_by_kind,
        'sources': src_counts,
        'runtimeSources': runtime_src,
        'missing': missing_ids,
        'missingDetail': missing_detail,
        'missingCount': len(missing_ids),
        'series': [d['id'] for d in series_detail],
        'seriesDetail': series_detail,
        'seriesCount': len(series_detail),
        'photoCount': len(produced),
        'builtinTop100': builtin_top100,
        'builtinCovered': len(builtin_present),
        'builtinProduct': len(builtin_product),
        'builtinMissingProduct': [gid for gid in builtin_present
                                  if produced[gid]['tier'] != 'product'],
        'builtinMissing': builtin_missing,
        'builtinCount': len(builtin_present),
        'builtinBytes': b_bytes,
        'budgetNote': budget_note,
        'foundBytes': sum(r['bytes'] for r in produced.values()),
        'failed': failed[:50],
    }
    out = {
        'version': 1,
        'note': ('构建期规范化器材图（D71–D73）：真实型号照片（Wikimedia/Openverse 的 '
                 'CC0/PD/CC BY/CC BY-SA），氛围图不冒充型号图。Top100（相机 60 + 镜头 '
                 '40）内置，本批 product=%d/%d；其余可运行时同步（runtimeUrl：'
                 'Openverse 缩略图优先，其次 Wikimedia 缩略）；tier=series 为同系列'
                 '示意（非该型号），缺图见 stats.missing。' %
                 (len(builtin_product), len(builtin_top100))),
        'generatedAt': time.strftime('%Y-%m-%d'),
        'builtinTop100': builtin_top100,
        'byModel': by_model,
        'byKind': by_kind,
        'byId': by_id,
        'stats': stats,
    }
    save_json(args.json_out, out)

    # ---- attribution 追加（保留原 items；按 file 去重，photo2 前缀替换） ----
    attr = load_json(args.attribution, {'items': []})
    prefix = 'assets/content/gear/photo2/'
    old_items = [it for it in attr.get('items', [])
                 if isinstance(it, dict)
                 and not str(it.get('file', '')).startswith(prefix)]
    for gid, rec in sorted(produced.items()):
        name = '器材图（%s）' % rec['displayName']
        if rec['tier'] == 'series':
            name += '·同系列示意（非该型号）'
        entry = {
            'file': '%s%s' % (prefix, rec['file']),
            'name': name,
            'source': rec['pageUrl'] or rec['sourceUrl'],
            'license': rec['license'] or 'See source page',
            'author': rec['author'] or 'See source page',
            'kind': rec['kind'],
            'tier': rec['tier'],
            'builtin': rec['builtin'],
        }
        if rec.get('note'):
            entry['note'] = rec['note']
        old_items.append(entry)
    attr['items'] = old_items
    if not str(attr.get('note', '')).strip():
        attr['note'] = '内置第三方素材署名'
    save_json(args.attribution, attr)

    mb = b_bytes / 1024.0 / 1024.0
    print('==== 规范化完成 %.1fs ====' % (time.time() - t0))
    print('photo2: %d 张（内置 %d / 预算 %.2fMB ≤15MB: %s）| 全部 %.1fMB' %
          (len(produced), len(builtin_present), mb,
           'OK' if mb <= 15 else '超预算!',
           stats['foundBytes'] / 1024.0 / 1024.0))
    for kind in ('camera', 'lens', 'light', 'accessory'):
        c = coverage.get(kind)
        if c:
            print('%s覆盖率: %d/%d = %.1f%% (product %d)' %
                  (kind, c['covered'], c['total'], c['ratio'] * 100,
                   c['product']))
    print('tier: product=%d series=%d | runtimeUrl: openverse=%d wikimedia=%d' %
          (tier_counts.get('product', 0), tier_counts.get('series', 0),
           runtime_src['openverse'], runtime_src['wikimedia']))
    print('Top100: %d/100 有图, 其中 product=%d, 非product=%s' %
          (len(builtin_present), len(builtin_product),
           stats['builtinMissingProduct'][:8]))
    if missing_ids:
        print('缺图 %d 例: %s' % (len(missing_ids), ', '.join(missing_ids[:12])))
    if failed:
        print('规范化失败 %d 例: %s' % (len(failed), '; '.join(failed[:6])))
    print('JSON: %s | photo2: %s | attribution: %s' %
          (args.json_out, args.out, args.attribution))
    return 0


if __name__ == '__main__':
    sys.exit(main())
