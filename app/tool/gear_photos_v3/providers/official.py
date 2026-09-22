# -*- coding: utf-8 -*-
"""官网产品图 provider（D130 第一优先级）。

流程：品牌 sitemap/类目页 → 产品页索引（含锚文本）→ 型号匹配 → 产品页主图。
支持离线 fixture（GEAR_V3_OFFLINE=1 时读 tool/gear_photos_v3/fixtures/<label>/）。
"""
from __future__ import annotations

import json
import os
import re
import urllib.parse

from .. import common
from ..brands import brand_config
from .base import Candidate, Provider

FIXTURES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'fixtures')
INDEX_TTL_SECONDS = 7 * 24 * 3600
IMG_EXT_RE = re.compile(r'\.(jpe?g|png|webp)(?:\?|$)', re.I)
SKIP_TOKENS = ('logo', 'icon', 'sprite', 'favicon', 'qrcode', 'avatar')


def _offline() -> bool:
    return common.offline()


def _index_cache_path(label: str) -> str:
    return os.path.join(common.POOL_DIR, 'sitemaps', '%s_index.json' % label)


def _collect_sitemap(url: str, depth: int = 0, label: str = '') -> list:
    if _offline():
        # R48：sitemap 从 fixtures/<label>/<basename> 读取，支持 sitemapindex 递归。
        if not label:
            return []
        path = os.path.join(FIXTURES, label, os.path.basename(urllib.parse.urlparse(url).path))
        if not os.path.exists(path):
            return []
        with open(path, encoding='utf-8') as fh:
            text = fh.read()
    else:
        text = common.polite_get(url, timeout=40)
    locs = re.findall(r'<loc>\s*(.*?)\s*</loc>', text, re.S)
    if '<sitemapindex' in text and depth < 2:
        parent_host = urllib.parse.urlparse(url).netloc.lower()
        base = '.'.join(parent_host.split('.')[-2:])
        urls = []
        for child in locs:
            if '.xml' not in child.split('?')[0]:
                continue
            if not urllib.parse.urlparse(child).netloc.lower().endswith(base):
                continue  # sitemapindex 可能混入同集团其它品牌站点
            try:
                urls.extend(_collect_sitemap(child, depth + 1, label))
            except Exception:  # noqa: BLE001
                continue
        return urls
    return [u for u in locs if u.startswith('http')]


def _strip_tags(text: str) -> str:
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', text or '')).strip()


def _parse_anchors(html: str, base_url: str) -> list:
    out = []
    for m in re.finditer(r'<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>', html, re.S | re.I):
        href = m.group(1)
        out.append((urllib.parse.urljoin(base_url, href), _strip_tags(m.group(2))[:160]))
    return out


def product_index(cfg: dict) -> list:
    """产品页索引 [{url,text}]；sitemap 直取 + 类目页展开，缓存 7 天。"""
    label = cfg['label']
    if _offline():
        entries = common.read_json(os.path.join(FIXTURES, label, 'index.json'), None)
        if isinstance(entries, list):
            return entries
        # 无 index.json 时退回 fixture sitemap 解析（R48）。
        product_re = re.compile(cfg.get('product_re') or r'/product')
        urls = []
        for sitemap in cfg.get('sitemaps') or []:
            urls.extend(_collect_sitemap(sitemap, label=label))
        return [{'url': u, 'text': ''} for u in dict.fromkeys(urls) if product_re.search(u)]
    cache_path = _index_cache_path(label)
    cache = common.read_json(cache_path, {})
    if cache.get('entries') and cache.get('fetchedAt'):
        try:
            import time as _t
            age = _t.time() - _t.mktime(_t.strptime(cache['fetchedAt'], '%Y-%m-%dT%H:%M:%SZ'))
            if age < INDEX_TTL_SECONDS:
                return cache['entries']
        except Exception:  # noqa: BLE001
            pass
    product_re = re.compile(cfg.get('product_re') or r'/product')
    entries = []
    seen = set()

    def add(url: str, text: str = '') -> None:
        url = url.split('#')[0]
        if not url or url in seen:
            return
        seen.add(url)
        entries.append({'url': url, 'text': text})

    for sitemap in cfg.get('sitemaps') or []:
        try:
            urls = _collect_sitemap(sitemap)
        except Exception as exc:  # noqa: BLE001
            print('[official] sitemap 失败 %s：%s' % (sitemap, exc))
            continue
        for u in urls:
            if product_re.search(u):
                add(u)

    listings = list(cfg.get('listings') or [])
    for page in cfg.get('index_pages') or []:
        try:
            html = common.polite_get(page, timeout=40)
        except Exception:  # noqa: BLE001
            continue
        pattern = cfg.get('listing_link_re') or r'href="(/[A-Za-z][A-Za-z0-9\-]*/)"'
        for href in re.findall(pattern, html):
            listings.append(urllib.parse.urljoin(page, href))
    listings = [u for u in dict.fromkeys(listings)]
    for page in listings[:80]:
        try:
            html = common.polite_get(page, timeout=40)
        except Exception:  # noqa: BLE001
            continue
        for url, text in _parse_anchors(html, page):
            if product_re.search(url):
                add(url, text)
    common.write_json(cache_path, {'fetchedAt': common.now_iso(), 'entries': entries})
    return entries


def _series_candidates(model: str) -> list:
    """型号 → 系列 slug 候选（如 'SL100 III' → 'sliii'/'sl100'；'SL60W' → 'sl60'）。"""
    model = str(model or '').strip()
    out = []
    roman = re.search(r'([IVX]+)\s*$', model, re.I)
    letters = re.match(r'([A-Za-z]+)', model)
    if roman and letters:
        out.append((letters.group(1) + roman.group(1)).lower())
    m = re.match(r'([A-Za-z]+)\s*0*(\d{1,4})', model)
    if m:
        out.append((m.group(1) + m.group(2)).lower())
        out.append(m.group(1).lower())
    return [common.norm_text(x) for x in out]


def match_entries(entries: list, model: str, brand: str = '', limit: int = 4) -> list:
    """按 URL slug / 锚文本匹配；返回 [{url,text,tier}]，product 优先于 series。"""
    cands = common.slug_candidates(model, brand)
    norm_model = common.norm_text(model)
    series_cands = [c for c in _series_candidates(model) if len(c) >= 4]
    scored = []
    for e in entries:
        url = e.get('url', '')
        slug = common.url_path_slug(url)
        text_norm = common.norm_text(e.get('text', ''))
        tier = None
        if norm_model and len(norm_model) >= 4 and (
                slug == norm_model or text_norm == norm_model
                or (len(text_norm) >= 4 and norm_model in text_norm)):
            tier = 'product'
        else:
            pool = set(cands) | set(series_cands)
            for cand in pool:
                if len(cand) < 4:
                    continue
                if (slug == cand or text_norm == cand or cand in slug or cand in text_norm
                        or (len(slug) >= 4 and slug in cand)):
                    tier = 'series'
                    break
        if tier:
            scored.append((0 if tier == 'product' else 1, -len(common.norm_text(e.get('text', ''))),
                           url, tier, e.get('text', '')))
    scored.sort(key=lambda t: (t[0], t[1], len(t[2])))
    out = []
    for _, _, url, tier, text in scored:
        if any(o['url'] == url for o in out):
            continue
        out.append({'url': url, 'text': text, 'tier': tier})
        if len(out) >= limit:
            break
    return out


def extract_image_urls(html: str, page_url: str, model: str = '', limit: int = 6) -> list:
    """按优先级返回候选主图列表（alt 含型号 > og:image > 产品区块 > 其余内容图）。"""
    norm_model = common.norm_text(model)

    def absolute(raw: str) -> str:
        return urllib.parse.urljoin(page_url, raw)

    def usable(raw: str) -> bool:
        low = raw.lower()
        if not IMG_EXT_RE.search(raw):
            return False
        return not any(tok in low for tok in SKIP_TOKENS)

    imgs = re.findall(r'<img[^>]*>', html, re.I)
    parsed = []
    for tag in imgs:
        src = re.search(r'src=["\']([^"\']+)["\']', tag, re.I)
        if not src:
            continue
        alt = re.search(r'(?:alt|title)=["\']([^"\']*)["\']', tag, re.I)
        parsed.append((src.group(1), alt.group(1) if alt else ''))

    out = []

    def add(raw: str) -> None:
        url = absolute(raw)
        if url not in out:
            out.append(url)

    for raw, alt in parsed:
        if norm_model and len(norm_model) >= 4 and norm_model in common.norm_text(alt) and usable(raw):
            add(raw)
    og = re.findall(
        r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)["\']', html, re.I)
    og += re.findall(
        r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:image["\']', html, re.I)
    for raw in og:
        if usable(raw):
            add(raw)
    idx = html.find('productDesc')
    head = html[idx:idx + 4000] if idx >= 0 else ''
    for raw, _alt in parsed:
        if usable(raw) and head and raw in head:
            add(raw)
    for raw, _alt in parsed:
        if usable(raw):
            add(raw)
    return out[:limit]


def suggest_products(base: str, query: str, limit: int = 5,
                     offline_payload: dict = None) -> list:
    """Shopify search/suggest.json：返回 [{title,url,imageUrl}]（品牌官方店）。"""
    if offline_payload is not None:
        payload = offline_payload
    else:
        url = '%s/search/suggest.json?q=%s&resources[type]=product&resources[limit]=%d' % (
            base.rstrip('/'), urllib.parse.quote(query), limit)
        try:
            text = common.polite_get(url, timeout=25, retries=1)
            payload = json.loads(text)
        except Exception:  # noqa: BLE001
            return []
    prods = (((payload.get('resources') or {}).get('results') or {}).get('products')) or []
    out = []
    for p in prods:
        title = str(p.get('title') or '')
        page = urllib.parse.urljoin(base, str(p.get('url') or '').split('?')[0])
        image = str((p.get('featured_image') or {}).get('url') or '')
        if not image and p.get('image'):
            image = str(p.get('image') or '')
        if not page:
            continue
        out.append({'title': title, 'url': page, 'imageUrl': image})
    return out


class OfficialProvider(Provider):
    name = 'official'

    def _suggest_candidates(self, cfg: dict, item: dict) -> list:
        sites = cfg.get('suggest_sites') or []
        if not sites:
            return []
        model = str(item.get('model') or '')
        brand = str(item.get('brand') or '')
        norm_model = common.norm_text(model)
        query = model if norm_model else '%s %s' % (brand, model)
        if len(norm_model) < 3:
            query = ('%s %s' % (brand, model)).strip()
        out = []
        for base in sites:
            payload = None
            if _offline():
                payload = common.read_json(
                    os.path.join(FIXTURES, cfg['label'], 'suggest.json'), None)
                if payload is None:
                    continue
            for p in suggest_products(base, query, offline_payload=payload):
                title_norm = common.norm_text(p['title'])
                matched = norm_model and len(norm_model) >= 4 and norm_model in title_norm
                if not matched and len(norm_model) <= 3:
                    matched = norm_model in title_norm and common.norm_text(brand) in title_norm
                if not matched:
                    continue
                out.append(p)
                if len(out) >= 4:
                    break
            if out:
                break
        return out

    def _guess_candidates(self, cfg: dict, item: dict) -> list:
        """直猜产品 URL 兜底（无产品索引时，标题必须含型号，避免误匹配）。"""
        patterns = cfg.get('guess_urls') or []
        if not patterns:
            return []
        model = str(item.get('model') or '')
        norm_model = common.norm_text(model)
        if len(norm_model) < 3:
            return []
        slugs = []
        for variant in (model.replace(' ', ''), model.replace(' ', '-'), model):
            v = common.norm_text(variant)
            if v and v not in slugs:
                slugs.append(v)
        out = []
        for pat in patterns:
            for slug in slugs[:2]:
                url = pat % slug
                try:
                    if _offline():
                        path = os.path.join(FIXTURES, cfg['label'],
                                            'page_%s.html' % common.url_path_slug(url))
                        html = (open(path, encoding='utf-8').read()
                                if os.path.exists(path) else '')
                    else:
                        html = common.polite_get(url, timeout=25, retries=1)
                except Exception:  # noqa: BLE001
                    continue
                if not html:
                    continue
                m = re.search(r'<title[^>]*>(.*?)</title>', html, re.S | re.I)
                title = _strip_tags(m.group(1)) if m else ''
                if norm_model not in common.norm_text(title):
                    continue
                for image_url in extract_image_urls(html, url, model):
                    out.append(Candidate(
                        provider=self.name,
                        image_url=image_url,
                        page_url=url,
                        title=title[:120],
                        license='官网产品图（版权归品牌，仅供选型参考）',
                        kind_hint=item.get('kind', ''),
                        extra={'brandLabel': cfg['label'], 'tier': 'product'},
                    ))
                if out:
                    return out[:6]
        return out

    def search(self, item: dict) -> list:
        cfg = brand_config(item.get('brand', ''))
        if not cfg:
            self.last_reason = '品牌未配置官网源'
            return []
        suggested = self._suggest_candidates(cfg, item)
        if suggested:
            out = []
            for p in suggested:
                if not p.get('imageUrl'):
                    continue
                out.append(Candidate(
                    provider=self.name,
                    image_url=p['imageUrl'],
                    page_url=p['url'],
                    title=p['title'][:120],
                    license='官网产品图（版权归品牌，仅供选型参考）',
                    kind_hint=item.get('kind', ''),
                    extra={'brandLabel': cfg['label'], 'tier': 'product'},
                ))
            if out:
                self.last_reason = ''
                return out[:6]
        if not cfg.get('sitemaps') and not cfg.get('index_pages') and not cfg.get('listings'):
            self.last_reason = cfg.get('note') or '官网无可用索引'
            return []
        entries = product_index(cfg)
        matches = match_entries(entries, item.get('model', ''), item.get('brand', ''))
        if not matches:
            guessed = self._guess_candidates(cfg, item)
            if guessed:
                self.last_reason = ''
                return guessed
            self.last_reason = '官网索引无型号匹配（索引 %d 条）' % len(entries)
            return []
        out = []
        for match in matches:
            page_url = match['url']
            try:
                if _offline():
                    slug = common.url_path_slug(page_url)
                    path = os.path.join(FIXTURES, cfg['label'], 'page_%s.html' % slug)
                    html = open(path, encoding='utf-8').read() if os.path.exists(path) else ''
                else:
                    html = common.polite_get(page_url, timeout=30)
            except Exception as exc:  # noqa: BLE001
                print('[official] %s 页面失败 %s：%s' % (item.get('id'), page_url, exc))
                continue
            if not html:
                continue
            title = ''
            m = re.search(r'<title[^>]*>(.*?)</title>', html, re.S | re.I)
            if m:
                title = _strip_tags(m.group(1))[:120]
            for image_url in extract_image_urls(html, page_url, item.get('model', '')):
                out.append(Candidate(
                    provider=self.name,
                    image_url=image_url,
                    page_url=page_url,
                    title=title or match.get('text', ''),
                    license='官网产品图（版权归品牌，仅供选型参考）',
                    kind_hint=item.get('kind', ''),
                    extra={'brandLabel': cfg['label'], 'tier': match['tier']},
                ))
            if len(out) >= 6:
                break
        if not out:
            self.last_reason = '官网匹配页无可用主图'
        return out[:6]
