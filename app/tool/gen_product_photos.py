#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""V4 产品图抓取流水线（D71–D73 / R19/R22/R24）——「不降级」版。

目标：相机 111 + 镜头 197 = 308 条**全部**拿到该型号真实产品照；
灯具 157 + 附件 28 尽力（找不到宁可 missing，也不用氛围图冒充）。
tier=product：该型号真实照片；tier=series：全网无该型号开放许可照片时，
用同系列（或同品牌同类）照片并标注「同系列示意（非该型号）」。

来源与顺序：
  1. Wikimedia Commons（**必须 DoH**，见 doh.py；LicenseShortName 仅接受 CC0/PD/CC BY，排除 SA/NC/ND）
  2. Openverse API（license=cc0,by,pdm；记录 thumbnail 作为 runtimeUrl）
  3. Wikipedia 页面 infobox 图（DoH；图源仍是 Commons，逐图核验许可）
  4. 同系列/同类回退（tier=series）
  5. missing

规范（供 normalize_product_photos.py 使用）：候选标题必须严格匹配 品牌+型号 token
（数码/罗马数字齐全），多候选取最佳（白底优先、分辨率、主体占比）。

用法：
  python -X utf8 tool/gen_product_photos.py --only-kind camera,lens [--workers 6]
      [--raw <dir>] [--limit N] [--no-openverse] [--no-wikipedia] [--retry-missing]
      [--audit]

幂等：manifest 中 status/tier 已达标且 raw 文件存在则跳过；中断重跑续作。
"""

from __future__ import annotations

import argparse
import difflib
import html
import json
import math
import os
import re
import sys
import tempfile
import threading
import time
import unicodedata
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from doh import install as install_doh  # noqa: E402

import numpy as np  # noqa: E402
import requests  # noqa: E402
from PIL import Image, ImageOps  # noqa: E402

WM_API = 'https://commons.wikimedia.org/w/api.php'
WP_API = 'https://en.wikipedia.org/w/api.php'
OV_API = 'https://api.openverse.org/v1/images/'
UA = ('ShootStudio/1.0.4 gear-photo-pipeline '
      '(https://shootstudio.local; dev@shootstudio.local)')

TARGET_KINDS = ('camera', 'lens', 'light', 'accessory')
PRODUCT_FREE_KINDS = ('camera', 'lens')

BRAND_EN = {
    '佳能': 'Canon', '索尼': 'Sony', '尼康': 'Nikon', '富士': 'Fujifilm',
    '松下': 'Panasonic', '徕卡': 'Leica', '适马': 'Sigma', '奥林巴斯': 'Olympus',
    '理光': 'Ricoh', '哈苏': 'Hasselblad', '宾得': 'Pentax', '腾龙': 'Tamron',
    '蔡司': 'Zeiss', '老蛙': 'Laowa', '中一光学': 'Zhongyi', '七工匠': '7artisans',
    '铭匠': 'TTArtisan', '唯卓仕': 'Viltrox', '神牛 Godox': 'Godox',
    '神牛': 'Godox', '爱图仕 Aputure': 'Aputure', '爱图仕': 'Aputure',
    '南冠': 'Nanlite', '南光 Nanlux': 'Nanlux', '南光 Nanlite': 'Nanlite',
    '智云 Zhiyun': 'Zhiyun', '智云': 'Zhiyun', '永诺 YONGNUO': 'Yongnuo',
    '永诺': 'Yongnuo', '金贝': 'Jinbei', '保荣': 'Bowens', '布朗': 'Broncolor',
    '易领': 'Elinchrom', '影聚': 'Pika', '奈特科尔': 'Nitecore', '锐玛': 'Rima',
    '锋影': 'Fengying', '世光': 'Sekonic', '莱斯': 'Aladdin', '思锐': 'Sirui',
    '曼富图': 'Manfrotto', '捷信': 'Gitzo', '图瑞斯': 'Teris', '威陀士': 'Weifeng',
    '天利': 'Tianli', '富图宝': 'Fotopro',
}

MODEL_ZH_EN = {
    '环形闪光灯': 'Ring Flash', '环形闪': 'Ring Flash', '微距闪': 'Macro Flash',
    '微距': 'Macro', '柔光箱': 'Softbox', '柔光伞': 'Umbrella Softbox',
    '反光伞': 'Umbrella', '雷达罩': 'Beauty Dish', '束光筒': 'Snoot',
    '灯笼球': 'Lantern', '八角伞': 'Octabox', '三脚架': 'Tripod',
    '碳纤维': 'Carbon Fiber', '球形云台': 'Ball Head', '云台': 'Head',
    '反光板': 'Reflector', '套装': 'Kit', '背景纸架': 'Backdrop Stand',
    '减光镜': 'ND Filter', '快门线': 'Remote Shutter', '支架': 'Stand',
    '灯架': 'Light Stand', '五合一': '5-in-1', '圆形': 'Round',
    '饼干': 'Pancake', '微距镜头': 'Macro Lens',
}

CATEGORY_WORDS = ('softbox', 'lantern', 'beauty dish', 'snoot', 'octabox',
                  'umbrella', 'reflector', 'tripod', 'ball head', 'head',
                  'stand', 'ring flash', 'macro flash', 'kit', 'nd filter')

BAD_TITLE = re.compile(
    r'(diagram|schematic|patent|drawing|logo|icon|screenshot|chart|scan|'
    r'manual|blueprint|render|test chart|color chart|poster|map|stamp|'
    r'graph|illustration|sketch|nebula|galaxy|moon|astrophoto|milky way|'
    r'landscape|sunset|sunrise|portrait of|wedding|wildlife|bird|insect|'
    r'flower|fireworks|cityscape|astro|test shot|shot with|taken with|'
    r'modified)', re.I)
GOOD_TITLE = re.compile(
    r'\b(front|rear|back|body|top|side|product|view|no body cap|'
    r'white background|studio)\b', re.I)
BAD_CONTEXT = re.compile(
    r'\b(with|using|attached|mounted|holding|on a|taken with|sample|'
    r'example|review|comparison)\b', re.I)
ROMAN = {'ii', 'iii', 'iv', 'vi', 'vii', 'viii', 'ix', 'x', 'v', 'i'}


def jload(path, default):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return default


def jsave(path, obj):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


def clean_html(s):
    s = html.unescape(str(s or ''))
    s = re.sub(r'<[^>]+>', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def clean_url(u):
    u = str(u or '').strip()
    if '?' not in u:
        return u
    base, query = u.split('?', 1)
    keep = [p for p in query.split('&') if p and not p.startswith('utm_')]
    return base + (('?' + '&'.join(keep)) if keep else '')


_CONFUSABLE = str.maketrans({
    'α': 'a', 'β': 'b', 'γ': 'g', 'μ': 'u', 'Ω': 'o', 'ω': 'w', 'і': 'i',
    'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'х': 'x', 'у': 'y',
})


def norm_text(s):
    s = unicodedata.normalize('NFKC', str(s or ''))
    return s.lower().translate(_CONFUSABLE)


def tokens(s):
    return re.findall(r'[a-z0-9]+', norm_text(s))


def brand_en(brand):
    b = str(brand or '').strip()
    if b in BRAND_EN:
        return BRAND_EN[b]
    compact = re.sub(r'\s+', '', b)
    if compact in BRAND_EN:
        return BRAND_EN[compact]
    latin = re.sub(r'[^A-Za-z0-9 ]+', ' ', b).strip()
    return latin or b


def model_en(model):
    s = str(model or '')
    for zh, en in sorted(MODEL_ZH_EN.items(), key=lambda kv: -len(kv[0])):
        s = s.replace(zh, ' %s ' % en)
    s = s.replace('（', ' ').replace('）', ' ')
    s = re.sub(r'[()\[\]【】]', ' ', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s


class Item:
    __slots__ = ('id', 'kind', 'brand', 'model', 'display_name', 'price',
                 'series', 'mount')

    def __init__(self, raw):
        self.id = str(raw.get('id'))
        self.kind = str(raw.get('kind') or '')
        self.brand = str(raw.get('brand') or '')
        self.model = str(raw.get('model') or '')
        self.display_name = '%s %s' % (self.brand, self.model)
        self.price = float(raw.get('priceRef') or 0)
        specs = raw.get('specs') or {}
        self.series = str(specs.get('series') or '') if isinstance(specs, dict) else ''
        self.mount = str(raw.get('mount') or '')

    @property
    def brand_en(self):
        return brand_en(self.brand)

    @property
    def model_en(self):
        return model_en(self.model)

    @property
    def queries(self):
        b, m = self.brand_en, self.model_en
        out = []
        if b and m:
            out.append('%s %s' % (b, m))
        if m:
            out.append(m)
        if self.kind == 'lens':
            foc = re.search(r'(\d+(?:-\d+)?)\s*mm', m, re.I)
            if foc:
                prefix = m[:foc.end()]
                if b:
                    out.append('%s %s' % (b, prefix))
                out.append(prefix)
        if self.kind in ('light', 'accessory'):
            head = re.match(r'^([A-Za-z]+\d+[A-Za-z]*)', m)
            if head and head.group(1) != m:
                if b:
                    out.append('%s %s' % (b, head.group(1)))
                out.append(head.group(1))
        for alias in self.aliases:
            if b:
                out.append('%s %s' % (b, alias))
            out.append(alias)
        tt = tokens(m)
        if len(tt) >= 2:
            fused = [tt[0] + tt[1], ''.join(tt)]
            for f in fused:
                if f != tt[0]:
                    out.append(('%s %s' % (b, f)) if b else f)
                    out.append(f)
        seen = set()
        result = []
        for q in out:
            q = q.strip()
            if q and q.lower() not in seen:
                seen.add(q.lower())
                result.append(q)
        return result[:6]

    def category(self):
        text = self.model_en.lower()
        for word in CATEGORY_WORDS:
            if word in text:
                return word
        return ''

    @property
    def aliases(self):
        """型号别名（Sony ILCE-xxxx 机身代码、Mark→数字写法）。"""
        out = []
        m = self.model_en.strip()
        if 'sony' in self.brand_en.lower():
            roman = {'i': '1', 'ii': '2', 'iii': '3', 'iv': '4', 'v': '5',
                     'vi': '6', 'vii': '7', 'viii': '8'}
            parts = m.split()
            hm = re.match(r'^A(\d+)([RCS]*)$', parts[0], re.I) if parts else None
            if hm:
                num, letters = hm.group(1), hm.group(2).upper()
                if len(parts) >= 2:
                    second = parts[1].upper()
                    if second.lower() in roman:
                        out.append('ILCE-%s%sM%s' %
                                   (num, letters, roman[second.lower()]))
                    elif re.fullmatch(r'[RSC]', second):
                        out.append('ILCE-%s%s%s' % (num, letters, second))
                elif letters:
                    out.append('ILCE-%s%s' % (num, letters))
            m4 = re.match(r'^A(\d{4})$', m)
            if m4:
                out.append('ILCE-%s' % m4.group(1))
        m_mark = re.match(r'^(.*?)\s+Mark\s+(I{1,3}|IV|V)$', m, re.I)
        if m_mark:
            digit = {'i': '1', 'ii': '2', 'iii': '3', 'iv': '4',
                     'v': '5'}.get(m_mark.group(2).lower(), '')
            if digit:
                out.append('%s %s' % (m_mark.group(1), digit))
        seen = set()
        result = []
        for alias in out:
            if alias.lower() not in seen:
                seen.add(alias.lower())
                result.append(alias)
        return result


# ---------------------------------------------------------------- match score

def _decomposable(word, mt):
    """word 是否可由型号 token 的连续子序列拼接而成（如 r5c = r5 + c）。"""
    for start in range(len(mt)):
        acc = ''
        for tok in mt[start:]:
            acc += tok
            if acc == word:
                return True
            if not word.startswith(acc):
                break
    return False


def _model_conflict(t_words, mt):
    """标题含型号外的记号（Mark II/III、R5C vs R5 等）→ 视为不同型号。"""
    mt_set = set(mt)
    for i, w in enumerate(t_words):
        if w in mt_set or not w:
            continue
        if w == 'mark' or w in ROMAN:
            return True
        if any(ch.isdigit() for ch in w) or len(w) <= 4:
            for tok in mt:
                if len(tok) >= 2 and w.startswith(tok) and w != tok \
                        and not _decomposable(w, mt):
                    return True
    return False


BRAND_ALIASES = {
    'olympus': ('om system', 'om'),
    'panasonic': ('lumix',),
    'fujifilm': ('fujinon', 'fuji'),
    'nikon': ('nikkor',),
    'leica': ('leitz',),
    'hasselblad': ('hb',),
    'sigma': ('art',),
    'canon': ('eos',),
    'sony': ('alpha', 'ilce'),
}


def _brand_ok(t_words, t_squash, item):
    bt = tokens(item.brand_en)
    if not bt:
        return False
    if all(tok in t_words or tok in t_squash for tok in bt):
        return True
    for alias in BRAND_ALIASES.get(item.brand_en.lower(), ()):
        at = tokens(alias)
        if at and all(tok in t_words or tok in t_squash for tok in at):
            return True
    return False


def _adjacent(t_words, a, b):
    """a、b 是否作为相邻整词出现，或拼合成标题中的单个整词（r5 + c = r5c）。"""
    for i in range(len(t_words) - 1):
        if t_words[i] == a and t_words[i + 1] == b:
            return True
    fused = a + b
    return any(w == fused for w in t_words)


def _core_hits(mt, t_words, t_set, t_squash, mm_tolerant):
    hit = 0
    for i, tok in enumerate(mt):
        if tok in t_set:
            hit += 1
            continue
        if mm_tolerant and tok.endswith('mm') and tok[:-2] in t_set:
            hit += 1
            continue
        joined = False
        if i > 0 and _adjacent(t_words, mt[i - 1], tok):
            joined = True
        if not joined and i + 1 < len(mt) and _adjacent(t_words, tok, mt[i + 1]):
            joined = True
        if joined or (len(tok) >= 4 and any(ch.isalpha() for ch in tok)
                      and tok in t_squash):
            hit += 1
    return hit


def _split_aperture(mt):
    """型号 token → (核心 token, 光圈签名)。光圈签名如 F1.2L → '12'。"""
    core = []
    ap = ''
    i = 0
    while i < len(mt):
        tok = mt[i]
        if re.fullmatch(r'f\d+(?:x\d+)?', tok):
            digits = tok[1:]
            j = i + 1
            while j < len(mt) and re.fullmatch(r'\d+(?:x\d+)?[a-z]{0,2}', mt[j]):
                part = mt[j]
                m = re.match(r'^(\d+(?:x\d+)?)', part)
                if not m:
                    break
                digits += m.group(1)
                j += 1
            ap = digits.replace('x', '')
            i = j
            continue
        core.append(tok)
        i += 1
    return core, ap


def _title_aperture(t_words, core):
    """标题中的光圈签名：优先 f 前缀；否则焦距后的 1~2 个纯数字。"""
    for i, w in enumerate(t_words):
        if re.fullmatch(r'f\d+(?:x\d+)?', w):
            digits = w[1:]
            j = i + 1
            while j < len(t_words) and re.fullmatch(
                    r'\d+(?:x\d+)?[a-z]{0,2}', t_words[j]):
                m = re.match(r'^(\d+(?:x\d+)?)', t_words[j])
                if not m:
                    break
                digits += m.group(1)
                j += 1
            return digits.replace('x', '')
    focal = [tok for tok in core if tok.endswith('mm')][:1]
    if focal:
        base = focal[0][:-2]
        try:
            idx = t_words.index(base)
        except ValueError:
            return ''
        digits = ''
        j = idx + 1
        while j < len(t_words) and len(digits) < 3:
            w = t_words[j]
            if re.fullmatch(r'\d{1,2}', w):
                digits += w
                j += 1
                continue
            break
        return digits
    return ''


def _relaxed_lens_score(title, item):
    """镜头：忽略光圈 token 的匹配（要求其余核心 token 全中且光圈不冲突）。"""
    if item.kind != 'lens':
        return 0.0
    t_words = tokens(title)
    t_set = set(t_words)
    t_squash = ''.join(t_words)
    mt = tokens(item.model_en)
    if not mt or _model_conflict(t_words, mt):
        return 0.0
    core, model_ap = _split_aperture(mt)
    if not core or len(core) < 2:
        return 0.0
    if _core_hits(core, t_words, t_set, t_squash, True) < len(core):
        return 0.0
    title_ap = _title_aperture(t_words, core)
    if model_ap and title_ap and title_ap != model_ap:
        return 0.0
    return 1.0


def match_score(title, item):
    """标题对「品牌 型号」的严格匹配度 0..1；品牌缺失额外扣分。"""
    t_words = tokens(title)
    t_set = set(t_words)
    t_squash = ''.join(t_words)

    mt = tokens(item.model_en)
    if not mt:
        return 0.0
    if item.kind == 'camera' and mt[-1] == 'kit':
        mt = mt[:-1]  # Kit 为套装后缀，机身照片（同型号）同样适用
    if not mt:
        return 0.0
    if _model_conflict(t_words, mt):
        return 0.0
    hit = _core_hits(mt, t_words, t_set, t_squash, False)
    score = hit / float(len(mt))

    if _brand_ok(t_words, t_squash, item):
        for alias in item.aliases:
            a = ''.join(tokens(alias))
            if a and a in t_squash:
                return 1.0
    if item.kind == 'lens':
        relaxed = _relaxed_lens_score(title, item)
        if relaxed >= 1.0:
            return 1.0

    bt = tokens(item.brand_en)
    if bt:
        if not _brand_ok(t_words, t_squash, item):
            score *= 0.55
    else:
        score *= 0.8
    return round(min(score, 1.0), 4)


BAD_CAMERA_TITLE = re.compile(
    r'\b(bag|case|battery|charger|cage|rig|gimbal|tripod|cover|skin|pouch|'
    r'sleeve|adapter|strap|box)\b', re.I)
BAD_LENS_TITLE = re.compile(
    r'\b(case|pouch|box|filter|adapter|converter|teleconverter)\b', re.I)


def title_purity(title, item):
    """标题「纯净度」：型号/品牌之外的词越少越像产品图。"""
    known = set(tokens(item.brand_en) + tokens(item.model_en))
    extra = 0
    t_words = tokens(title)
    for w in t_words:
        if w in known:
            continue
        if any(len(tok) >= 2 and (w.startswith(tok) or tok.startswith(w))
               for tok in known):
            continue
        if w.isdigit() and len(w) >= 4:
            continue
        extra += 1
    return max(0.0, 1.0 - extra / 6.0), t_words


def title_ok(cand, item, min_score=1.0):
    title = cand['title'] or ''
    if BAD_TITLE.search(title):
        return False
    if item.kind == 'camera' and BAD_CAMERA_TITLE.search(title):
        return False
    if item.kind == 'lens' and BAD_LENS_TITLE.search(title):
        return False
    if match_score(title, item) < min_score:
        return False
    purity, t_words = title_purity(title, item)
    known = set(tokens(item.brand_en) + tokens(item.model_en))
    first_alpha = next((w for w in t_words if not w.isdigit()), '')
    if first_alpha and first_alpha not in known and purity < 0.5:
        return False
    return True


# ---------------------------------------------------------------- licenses

def license_ok(text):
    """许可口径（V4 / D76 + 本任务网络口径）：接受 CC0 / Public domain / CC BY
    （含 CC BY-SA，商业可用，逐图署名）；排除 NC / ND / GFDL / 合理使用等。
    注：报告单列许可分布，若需收紧为「非 SA」可一键改回。"""
    s = str(text or '').lower().strip()
    if not s:
        return False
    if re.search(r'(\bnc\b|\bnd\b|non.?commercial|no.?derivative|gfdl|'
                 r'fair.?use|fal|aboc)', s):
        return False
    return bool(re.search(r'cc0|public domain|\bpd\b|pd-|no restrictions|'
                          r'cc.?by|attribution', s))


def license_label(text):
    s = str(text or '').strip()
    return s or 'See source page'


# ---------------------------------------------------------------- http plumbing

_thread_local = threading.local()
_rl_lock = threading.Lock()
_rl_last = [0.0]
_rl_min_interval = 0.22


def session():
    s = getattr(_thread_local, 'sess', None)
    if s is None:
        s = requests.Session()
        adapter = requests.adapters.HTTPAdapter(pool_connections=4,
                                                pool_maxsize=8, max_retries=0)
        s.mount('https://', adapter)
        s.headers.update({'User-Agent': UA, 'Accept-Language': 'en-US,en;q=0.9'})
        _thread_local.sess = s
    return s


def rate_limit():
    with _rl_lock:
        now = time.time()
        wait = _rl_last[0] + _rl_min_interval - now
        if wait > 0:
            time.sleep(wait)
            now = time.time()
        _rl_last[0] = now


_breaker: dict[str, list] = {}
_breaker_lock = threading.Lock()
_breaker_tripped = [False]


def _breaker_blocked(host):
    with _breaker_lock:
        rec = _breaker.get(host)
        if not rec:
            return False
        return time.time() < rec[1]


def _breaker_note(host, ok):
    with _breaker_lock:
        rec = _breaker.get(host) or [0, 0.0]
        if ok:
            rec[0] = 0
        else:
            rec[0] += 1
            if rec[0] >= 10:
                rec[1] = time.time() + 90
                rec[0] = 0
                _breaker_tripped[0] = True
        _breaker[host] = rec


def _breaker_wait(max_wait=100.0):
    """若有主机处于熔断，等待其恢复。"""
    now = time.time()
    waits = [rec[1] - now for rec in _breaker.values() if rec[1] > now]
    if waits:
        time.sleep(min(max_wait, max(waits)) + 1.0)


def http_get_json(url, params, retries=2, timeout=14):
    host = url.split('/')[2] if '//' in url else url
    if _breaker_blocked(host):
        return None, 'breaker'
    last = None
    for attempt in range(1, retries + 1):
        rate_limit()
        try:
            r = session().get(url, params=params, timeout=timeout)
            if r.status_code == 429 or r.status_code >= 500:
                last = 'HTTP %s' % r.status_code
                _breaker_note(host, False)
                time.sleep((3.0 + 2.0 * attempt)
                           if r.status_code == 429 else 2.0 * attempt)
                continue
            if r.status_code != 200:
                return None, 'HTTP %s' % r.status_code
            _breaker_note(host, True)
            return r.json(), ''
        except Exception as e:  # noqa: BLE001
            last = str(e)
            _breaker_note(host, False)
            if _breaker_blocked(host):
                break
            time.sleep(1.5 * attempt)
    return None, last or 'unknown'


def http_get_bytes(url, retries=2, timeout=30, max_bytes=32 * 1024 * 1024):
    host = url.split('/')[2] if '//' in url else url
    if _breaker_blocked(host):
        return None
    for attempt in range(1, retries + 1):
        try:
            r = session().get(url, timeout=timeout, stream=True)
            if r.status_code == 429 or r.status_code >= 500:
                r.close()
                time.sleep(2.0 * attempt)
                continue
            if r.status_code != 200:
                r.close()
                return None
            chunks = []
            total = 0
            for chunk in r.iter_content(65536):
                if not chunk:
                    continue
                chunks.append(chunk)
                total += len(chunk)
                if total > max_bytes:
                    r.close()
                    return None
            r.close()
            data = b''.join(chunks)
            if len(data) < 4096:
                return None
            _breaker_note(host, True)
            return data
        except Exception:  # noqa: BLE001
            _breaker_note(host, False)
            time.sleep(1.5 * attempt)
    return None


# ---------------------------------------------------------------- quality eval

def eval_image_bytes(data):
    """快速质量评估（白底、主体占比、长边）。返回 dict 或 None。"""
    try:
        import io
        with Image.open(io.BytesIO(data)) as im0:
            im = ImageOps.exif_transpose(im0).convert('RGB')
    except Exception:  # noqa: BLE001
        return None
    w, h = im.size
    long_edge = max(w, h)
    if long_edge < 500 or min(w, h) < 200:
        return None
    if long_edge / float(min(w, h)) > 3.4:
        return None
    scale = 480.0 / max(w, h)
    if scale < 1.0:
        im = im.resize((max(1, int(w * scale)), max(1, int(h * scale))),
                       Image.BILINEAR)
        w, h = im.size
    arr = np.asarray(im, dtype=np.uint8)
    bh = max(1, int(h * 0.06))
    bw = max(1, int(w * 0.06))
    border = np.concatenate([
        arr[:bh, :, :].reshape(-1, 3), arr[h - bh:, :, :].reshape(-1, 3),
        arr[:, :bw, :].reshape(-1, 3), arr[:, w - bw:, :].reshape(-1, 3),
    ])
    edge_mean = float(border.mean())
    edge_std = float(border.std())
    white = edge_mean > 224 and edge_std < 26
    gray = np.asarray(im.convert('L'), dtype=np.uint8)
    try:
        thr = np.percentile(gray, 35)
        mask = gray > thr
        if mask.mean() > 0.98:
            mask = gray > (gray.mean() - gray.std())
        ys, xs = np.where(mask)
        if len(xs) > 0:
            x0, x1 = int(xs.min()), int(xs.max())
            y0, y1 = int(ys.min()), int(ys.max())
            fill = ((x1 - x0 + 1) * (y1 - y0 + 1)) / float(w * h)
            subject_frac = mask.mean()
        else:
            fill, subject_frac = 0.0, 0.0
    except Exception:  # noqa: BLE001
        fill, subject_frac = 0.0, 0.0
    return {
        'white': bool(white),
        'edgeMean': round(edge_mean, 1),
        'edgeStd': round(edge_std, 1),
        'fill': round(fill, 3),
        'subject': round(subject_frac, 3),
        'long': long_edge,
        'w': im0.size[0],
        'h': im0.size[1],
    }


def cand_sort_key(c, item):
    q = c.get('quality') or {}
    white = 1 if q.get('white') else 0
    fill = float(q.get('fill') or 0)
    long_edge = int(q.get('long') or 0)
    purity, _ = title_purity(c['title'], item)
    penalty = 0
    t = c['title'] or ''
    if BAD_CONTEXT.search(t):
        penalty += 1
    if ' on ' in t.lower():
        penalty += 1
    return (white, round(purity, 3), fill >= 0.18, long_edge, -penalty)


# ---------------------------------------------------------------- sources

def _wm_cand(page, info):
    em = info.get('extmetadata') or {}
    lic = clean_html((em.get('LicenseShortName') or {}).get('value', ''))
    if not license_ok(lic):
        return None
    image = str(info.get('thumburl') or info.get('url') or '')
    if not image:
        return None
    author = clean_html((em.get('Artist') or {}).get('value', ''))
    return {
        'source': 'wikimedia',
        'title': str(page.get('title') or '').replace('File:', ''),
        'license': license_label(lic),
        'author': author or 'Wikimedia Commons contributor',
        'pageUrl': clean_url(info.get('descriptionurl') or ''),
        'sourceUrl': clean_url(info.get('url') or image),
        'imageUrl': clean_url(image),
        'runtimeUrl': clean_url(image),  # upload.wikimedia（1400px 缩略）
        'width': int(info.get('thumbwidth') or info.get('width') or 0),
        'height': int(info.get('thumbheight') or info.get('height') or 0),
        'mime': str(info.get('mime') or ''),
    }


def _wm_pages(data):
    return [p for p in (((data or {}).get('query') or {}).get('pages') or
                        {}).values() if isinstance(p, dict)]


def wikimedia_candidates(item, limit=14):
    cands = []
    seen = set()
    for q in item.queries:
        data, err = http_get_json(WM_API, {
            'action': 'query', 'format': 'json', 'generator': 'search',
            'gsrsearch': '%s filetype:bitmap' % q, 'gsrnamespace': '6',
            'gsrlimit': str(limit), 'prop': 'imageinfo',
            'iiprop': 'url|size|extmetadata|mime',
            'iiurlwidth': '1400',
        })
        if not data:
            if err:
                print('  wm search err: %s' % err)
            continue
        for page in _wm_pages(data):
            info = (page.get('imageinfo') or [{}])[0]
            cand = _wm_cand(page, info)
            if cand is None or cand['title'] in seen:
                continue
            seen.add(cand['title'])
            cands.append(cand)
    return cands


def wikimedia_category_candidates(item, limit=30):
    """Commons 分类（Category:品牌 型号）内的文件——按名称搜索的补充。"""
    cands = []
    seen = set()
    for q in item.queries:
        data, _ = http_get_json(WM_API, {
            'action': 'query', 'format': 'json', 'list': 'categorymembers',
            'cmtitle': 'Category:%s' % q, 'cmtype': 'file', 'cmlimit': str(limit),
        })
        titles = [str(m.get('title')) for m in
                  (((data or {}).get('query') or {}).get('categorymembers') or [])
                  if m.get('title')]
        if not titles:
            continue
        data, _ = http_get_json(WM_API, {
            'action': 'query', 'format': 'json',
            'titles': '|'.join(titles[:50]), 'prop': 'imageinfo',
            'iiprop': 'url|size|extmetadata|mime', 'iiurlwidth': '1400',
        })
        for page in _wm_pages(data):
            info = (page.get('imageinfo') or [{}])[0]
            cand = _wm_cand(page, info)
            if cand is None or cand['title'] in seen:
                continue
            seen.add(cand['title'])
            cands.append(cand)
        if cands:
            break
    return cands


def _file_key(url):
    """URL → 归一化文件名（去缩略前缀/扩展名/编码），用于同图判定。"""
    from urllib.parse import unquote
    try:
        name = unquote(str(url or '').split('/')[-1].split('?')[0])
    except Exception:
        return ''
    name = re.sub(r'^.*(?:lossy-page\d+-|\d+px-)', '', name)
    for _ in range(2):
        name = re.sub(r'\.(jpe?g|png|tiff?|webp)$', '', name, flags=re.I)
    return re.sub(r'[^a-z0-9]+', '', name.lower())


def _openverse_thumb_for(rec):
    """为已选 Wikimedia 图查 Openverse 同图代理缩略图（国内可达的运行时源）。"""
    title = str(rec.get('title') or '').strip()
    key = _file_key(rec.get('sourceUrl') or '')
    if not key:
        return ''
    stop = {'by', 'the', 'and', 'with', 'of', 'in', 'on', 'a', 'an', 'from',
            'photo', 'jpg', 'jpeg', 'png', 'tif', 'tiff'}
    words = [w for w in re.sub(r'[^A-Za-z0-9 ]+', ' ', title).split()
             if w.lower() not in stop and not (w.isdigit() and len(w) >= 5)]
    queries = []
    for n in (6, 4, 3):
        if len(words) >= max(2, n - 1):
            q = ' '.join(words[:n])
            if q not in queries:
                queries.append(q)
    if not queries:
        queries = [title]
    seen = set()
    for q in queries:
        q = q.strip()
        if not q or q.lower() in seen:
            continue
        seen.add(q.lower())
        data, _ = http_get_json(OV_API, {
            'q': q, 'license': 'cc0,by,by-sa,pdm', 'page_size': '16',
            'mature': 'false',
        })
        for r in ((data or {}).get('results') or []):
            if _file_key(r.get('url')) == key \
                    or _file_key(r.get('foreign_landing_url')) == key:
                thumb = str(r.get('thumbnail') or '')
                if thumb:
                    return thumb
    return ''


def openverse_candidates(item, limit=16):
    cands = []
    data, err = http_get_json(OV_API, {
        'q': '%s %s' % (item.brand_en, item.model_en),
        'license': 'cc0,by,pdm', 'page_size': str(limit), 'mature': 'false',
    })
    if not data:
        if err:
            print('  ov err: %s' % err)
        return cands
    for r in (data.get('results') or []):
        title = str(r.get('title') or '')
        lic = str(r.get('license') or '').lower()
        if lic == 'cc0':
            lic_label = 'CC0'
        elif lic == 'pdm':
            lic_label = 'Public domain'
        else:
            lic_label = 'CC BY %s' % (r.get('license_version') or '')
        url = str(r.get('url') or '')
        if not url:
            continue
        thumb = str(r.get('thumbnail') or '')
        cands.append({
            'source': 'openverse',
            'title': title,
            'license': lic_label.strip(),
            'author': str(r.get('creator') or 'Openverse contributor'),
            'pageUrl': str(r.get('foreign_landing_url') or ''),
            'sourceUrl': url,
            'imageUrl': url,
            'runtimeUrl': thumb or url,
            'width': int(r.get('width') or 0),
            'height': int(r.get('height') or 0),
            'mime': str(r.get('filetype') or ''),
        })
    return cands


def wikipedia_candidates(item):
    """Wikipedia 页面 infobox 图（DoH）→ Commons 许可核验。"""
    cands = []
    for q in item.queries[:1]:
        data, _ = http_get_json(WP_API, {
            'action': 'query', 'format': 'json', 'list': 'search',
            'srsearch': '%s camera' % q if item.kind == 'camera' else
                        ('%s lens' % q if item.kind == 'lens' else q),
            'srlimit': '3', 'srnamespace': '0',
        })
        pages = ((data or {}).get('query') or {}).get('search') or []
        titles = [p.get('title') for p in pages if p.get('title')]
        if not titles:
            continue
        data, _ = http_get_json(WP_API, {
            'action': 'query', 'format': 'json', 'titles': '|'.join(titles),
            'prop': 'pageimages', 'piprop': 'original|name|thumbnail',
            'pithumbsize': '1400', 'redirects': '1',
        })
        for page in ((data or {}).get('query') or {}).get('pages', {}).values():
            original = page.get('original') or {}
            img_url = str(original.get('source') or '')
            fname = str(page.get('pageimage') or '')
            if not img_url and not fname:
                continue
            url_name = fname or img_url.rsplit('/', 1)[-1]
            lic, author, page_url = '', '', ''
            if fname:
                info, _ = http_get_json(WM_API, {
                    'action': 'query', 'format': 'json',
                    'titles': 'File:%s' % fname, 'prop': 'imageinfo',
                    'iiprop': 'url|size|extmetadata',
                })
                for p in ((info or {}).get('query') or {}).get('pages', {}).values():
                    ii = (p.get('imageinfo') or [{}])[0]
                    em = ii.get('extmetadata') or {}
                    lic = clean_html((em.get('LicenseShortName') or {}).get('value', ''))
                    author = clean_html((em.get('Artist') or {}).get('value', ''))
                    page_url = str(ii.get('descriptionurl') or '')
                    if not img_url:
                        img_url = str(ii.get('url') or '')
            if not license_ok(lic):
                continue
            if not img_url:
                continue
            title = url_name.replace('_', ' ')
            cands.append({
                'source': 'wikipedia',
                'title': title,
                'license': license_label(lic),
                'author': author or 'Wikimedia Commons contributor',
                'pageUrl': page_url or str(page.get('title') or ''),
                'sourceUrl': img_url,
                'imageUrl': img_url,
                'runtimeUrl': img_url,
                'width': int(original.get('width') or 0),
                'height': int(original.get('height') or 0),
                'mime': '',
            })
    return cands


# ---------------------------------------------------------------- download

def _wm_thumb(url, width=1400):
    m = re.match(
        r'(https://upload\.wikimedia\.org/wikipedia/[^/]+)/([0-9a-f])/'
        r'([0-9a-f]{2})/([^/]+)$', url)
    if not m:
        return ''
    base, d1, d2, name = m.groups()
    if name.lower().endswith(('.svg',)):
        return ''
    return '%s/thumb/%s/%s/%s/%dpx-%s' % (base, d1, d2, name, width, name)


def _candidate_urls(cand):
    src = str(cand.get('imageUrl') or cand.get('sourceUrl') or '')
    urls = []
    if 'upload.wikimedia.org' in src and '/thumb/' not in src:
        t = _wm_thumb(src)
        if t:
            urls.append(t)
    if src:
        urls.append(src)
    if cand.get('source') == 'openverse':
        thumb = str(cand.get('runtimeUrl') or '')
        if thumb and thumb not in urls:
            urls.append(thumb)
    return urls


def download_candidate(cand, item, raw_dir, idx=0):
    data = None
    q = None
    for url in _candidate_urls(cand):
        got = http_get_bytes(url, max_bytes=24 * 1024 * 1024)
        if got is None:
            continue
        gq = eval_image_bytes(got)
        if gq is None:
            continue
        if q is None or int(gq.get('long') or 0) > int(q.get('long') or 0):
            data, q = got, gq
        if int(gq.get('long') or 0) >= 1000:
            break
    if data is None or q is None:
        return None
    src = str(cand.get('imageUrl') or cand.get('sourceUrl') or '')
    ext = '.png' if src.lower().split('?')[0].endswith('.png') else '.jpg'
    path = os.path.join(raw_dir, '%s-c%d%s' % (item.id, idx, ext))
    with open(path, 'wb') as f:
        f.write(data)
    cand['quality'] = q
    cand['rawFile'] = path
    cand['bytes'] = len(data)
    return cand


def finalize_raw(chosen, raw_dir, item):
    """把选中的候选 raw 归位为 <id>.jpg/.png，清掉落选候选文件。"""
    src = chosen.get('rawFile') or ''
    if not src:
        return
    base = os.path.splitext(os.path.basename(src))[0]
    stem = base.split('-c')[0]
    ext = os.path.splitext(src)[1].lower()
    dst = os.path.join(raw_dir, '%s%s' % (stem, ext))
    try:
        if os.path.abspath(src) != os.path.abspath(dst):
            if os.path.exists(dst):
                os.remove(dst)
            os.replace(src, dst)
        chosen['rawFile'] = dst
    except OSError:
        chosen['rawFile'] = src
    for name in os.listdir(raw_dir):
        if name.startswith(stem + '-c') and name != os.path.basename(
                chosen['rawFile']):
            try:
                os.remove(os.path.join(raw_dir, name))
            except OSError:
                pass


def reuse_candidate(entry, item):
    if not entry or entry.get('status') != 'ok':
        return None
    if entry.get('tier') != 'product':
        return None
    raw = str(entry.get('rawFile') or '')
    if not raw or not os.path.exists(raw):
        return None
    if match_score(str(entry.get('title') or ''), item) < 1.0:
        return None
    if not license_ok(str(entry.get('license') or '')):
        return None
    try:
        with Image.open(raw) as im0:
            im = ImageOps.exif_transpose(im0)
            if max(im.size) < 560:
                return None
            import io
            buf = io.BytesIO()
            im.convert('RGB').save(buf, format='JPEG', quality=88)
            data = buf.getvalue()
    except Exception:  # noqa: BLE001
        return None
    q = eval_image_bytes(data)
    if q is None:
        return None
    return {
        'source': str(entry.get('source') or 'wikimedia'),
        'title': str(entry.get('title') or ''),
        'license': str(entry.get('license') or ''),
        'author': str(entry.get('author') or ''),
        'pageUrl': str(entry.get('pageUrl') or ''),
        'sourceUrl': str(entry.get('sourceUrl') or ''),
        'imageUrl': str(entry.get('sourceUrl') or ''),
        'runtimeUrl': str(entry.get('runtimeUrl') or entry.get('sourceUrl') or ''),
        'width': int(entry.get('width') or 0),
        'height': int(entry.get('height') or 0),
        'mime': '',
        'quality': q,
        'rawFile': raw,
        'bytes': int(entry.get('bytes') or 0),
        'reused': True,
    }


# ---------------------------------------------------------------- per item

def process_item(item, old_entry, raw_dir, use_openverse, use_wikipedia):
    reuse = reuse_candidate(old_entry, item)
    if reuse and not _want_upgrade(reuse):
        return _ok_record(item, reuse)

    wm = [c for c in wikimedia_candidates(item) if title_ok(c, item)]
    if not wm:
        wm = [c for c in wikimedia_category_candidates(item) if title_ok(c, item)]
    ov = []
    if not wm and use_openverse:
        ov = [c for c in openverse_candidates(item) if title_ok(c, item)]
    wp = []
    if not wm and not ov and use_wikipedia:
        wp = [c for c in wikipedia_candidates(item) if title_ok(c, item)]

    pool = wm + ov + wp
    if reuse:
        pool.insert(0, reuse)
    if not pool:
        return _miss_record(item)

    pool.sort(key=lambda c: cand_sort_key(c, item), reverse=True)
    chosen = None
    # 已有可用图：先看候选是否更优（白底/分辨率），否则不重复下载。
    if reuse:
        ranked = [c for c in pool if not c.get('reused')]
        best_new = ranked[0] if ranked else None
        if best_new is not None and int(best_new.get('width') or 0) >= 700:
            got = download_candidate(best_new, item, raw_dir, 0)
            if got and cand_sort_key(got, item) > cand_sort_key(reuse, item):
                chosen = got
        chosen = chosen or reuse
    else:
        for idx, cand in enumerate(pool[:3]):
            got = download_candidate(cand, item, raw_dir, idx)
            if got is None:
                continue
            if chosen is None or cand_sort_key(got, item) > cand_sort_key(chosen, item):
                chosen = got
            q = got.get('quality') or {}
            if q.get('white') and float(q.get('fill') or 0) >= 0.15 and int(q.get('long') or 0) >= 900:
                break
    if chosen is None:
        return _miss_record(item)
    if not chosen.get('reused'):
        finalize_raw(chosen, raw_dir, item)
    return _ok_record(item, chosen)


def _want_upgrade(reuse):
    q = reuse.get('quality') or {}
    return not q.get('white')


def _ok_record(item, cand):
    q = cand.get('quality') or {}
    return {
        'status': 'ok',
        'id': item.id,
        'kind': item.kind,
        'brand': item.brand,
        'model': item.model,
        'displayName': item.display_name,
        'tier': 'product',
        'source': cand.get('source') or 'wikimedia',
        'license': cand.get('license') or '',
        'author': cand.get('author') or '',
        'pageUrl': cand.get('pageUrl') or '',
        'sourceUrl': cand.get('sourceUrl') or '',
        'runtimeUrl': cand.get('runtimeUrl') or cand.get('sourceUrl') or '',
        'thumbnailUrl': cand.get('runtimeUrl') if cand.get('source') == 'openverse' else '',
        'title': cand.get('title') or '',
        'rawFile': cand.get('rawFile') or '',
        'width': int(q.get('w') or cand.get('width') or 0),
        'height': int(q.get('h') or cand.get('height') or 0),
        'score': int(round(100 * match_score(cand.get('title') or '', item))),
        'quality': {k: q.get(k) for k in ('white', 'edgeMean', 'edgeStd', 'fill',
                                          'subject', 'long')},
        'reused': bool(cand.get('reused')),
    }


def _miss_record(item):
    return {
        'status': 'miss',
        'id': item.id,
        'kind': item.kind,
        'brand': item.brand,
        'model': item.model,
        'displayName': item.display_name,
    }


# ---------------------------------------------------------------- series fallback

def series_fallback(items, manifest):
    ok = {}
    for item in items:
        e = manifest.get(item.id) or {}
        if e.get('status') == 'ok' and e.get('tier') == 'product':
            ok[item.id] = item
    filled = 0
    for item in items:
        e = manifest.get(item.id) or {}
        if e.get('status') == 'ok':
            continue
        sib = _pick_sibling(item, ok)
        if not sib:
            continue
        src = manifest[sib.id]
        rec = {
            'status': 'ok',
            'id': item.id,
            'kind': item.kind,
            'brand': item.brand,
            'model': item.model,
            'displayName': item.display_name,
            'tier': 'series',
            'source': src.get('source') or '',
            'license': src.get('license') or '',
            'author': src.get('author') or '',
            'pageUrl': src.get('pageUrl') or '',
            'sourceUrl': src.get('sourceUrl') or '',
            'runtimeUrl': src.get('runtimeUrl') or '',
            'thumbnailUrl': src.get('thumbnailUrl') or '',
            'title': src.get('title') or '',
            'rawFile': src.get('rawFile') or '',
            'width': src.get('width') or 0,
            'height': src.get('height') or 0,
            'score': 0,
            'seriesOf': sib.id,
            'note': '同系列示意（非该型号，参考 %s）' % sib.display_name
            if item.kind in ('camera', 'lens') else
            '同品牌同类示意（非该型号，参考 %s）' % sib.display_name,
            'quality': src.get('quality') or {},
        }
        manifest[item.id] = rec
        filled += 1
    return filled


def _digit_family_match(mt, ot):
    """型号数字族匹配：如 a7s~a7、z50~z50、gfx50s~gfx100s（仅共享 s 等不算）。"""
    digit_a = [t for t in mt if any(ch.isdigit() for ch in t)]
    digit_b = [t for t in ot if any(ch.isdigit() for ch in t)]
    if not digit_a or not digit_b:
        return True
    for a in digit_a:
        for b in digit_b:
            if a == b or a.startswith(b) or b.startswith(a):
                return True
    return False


def _pick_sibling(item, ok):
    pool = []
    for other in ok.values():
        if other.id == item.id or other.kind != item.kind:
            continue
        if brand_en(other.brand) != brand_en(item.brand):
            continue
        same_series = bool(item.series) and other.series == item.series
        same_cat = (item.kind in ('light', 'accessory') and item.category()
                    and other.category() == item.category())
        same_mount = (item.kind == 'lens' and bool(item.mount)
                      and other.mount == item.mount)
        if not (same_series or same_cat or same_mount):
            continue
        mt = tokens(item.model_en)
        ot = tokens(other.model_en)
        ratio = difflib.SequenceMatcher(None, mt, ot).ratio()
        if same_series:
            ratio += 0.35
        if same_mount:
            ratio += 0.25
        if same_cat:
            ratio += 0.20
        if item.price > 0 and other.price > 0:
            ratio += 0.12 * max(0.0, 1.0 - abs(
                math.log(other.price / item.price)))
        threshold = 0.45 if item.kind == 'camera' else 0.32
        if ratio < threshold:
            continue
        if item.kind == 'lens':
            shared = [t for t in set(mt) & set(ot)
                      if t not in ('rf', 'fe', 'z', 'ef', 'xf', 'xc', 'gf',
                                   'e', 'l', 's', 'g', 'dg', 'dn', 'di',
                                   'iii', 'art', 'usm', 'stm', 'is', 'oss',
                                   'vc', 'vxd', 'rxd', 'wr', 'lm', 'macro',
                                   'ii')]
            if not shared:
                continue
        pool.append((ratio, other))
    if not pool:
        return None
    pool.sort(key=lambda t: t[0], reverse=True)
    return pool[0][1]


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--raw', default=os.path.join(
        tempfile.gettempdir(), 'shootstudio_gear_raw2'))
    ap.add_argument('--old-raw', default=os.path.join(
        tempfile.gettempdir(), 'shootstudio_gear_raw'))
    ap.add_argument('--gear', default='assets/content/gear/gear.json')
    ap.add_argument('--only-kind', default='')
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--workers', type=int, default=5)
    ap.add_argument('--download-workers', type=int, default=8)
    ap.add_argument('--no-openverse', action='store_true')
    ap.add_argument('--no-wikipedia', action='store_true')
    ap.add_argument('--no-reuse', action='store_true')
    ap.add_argument('--retry-missing', action='store_true')
    ap.add_argument('--audit', action='store_true')
    ap.add_argument('--series-only', action='store_true',
                    help='仅重算同系列回退（先清除既有 series 记录）')
    ap.add_argument('--openverse-runtime', action='store_true',
                    help='为 Wikimedia 来源条目补齐 Openverse 代理缩略图 runtimeUrl')
    args = ap.parse_args()

    install_doh()

    gear = jload(args.gear, {'items': []})
    items = [Item(raw) for raw in gear.get('items', [])]
    only = {s.strip() for s in args.only_kind.split(',') if s.strip()}
    if only:
        items = [it for it in items if it.kind in only]
    if args.limit > 0:
        items = items[:args.limit]

    os.makedirs(args.raw, exist_ok=True)
    manifest_path = os.path.join(args.raw, 'manifest.json')
    manifest = {}
    if os.path.exists(manifest_path):
        manifest = (jload(manifest_path, {}) or {}).get('items') or {}

    old_manifest = {}
    if not args.no_reuse:
        old_manifest = (jload(os.path.join(args.old_raw, 'manifest.json'),
                              {}) or {}).get('items') or {}

    if args.audit:
        prod = sum(1 for it in items
                   if (manifest.get(it.id) or {}).get('status') == 'ok')
        reuse = sum(1 for it in items if reuse_candidate(old_manifest.get(it.id), it))
        print('items=%d ok=%d reuse_ok=%d' % (len(items), prod, reuse))
        return 0

    if args.openverse_runtime:
        targets = [it for it in items
                   if (manifest.get(it.id) or {}).get('status') == 'ok'
                   and (manifest.get(it.id) or {}).get('source') != 'openverse']
        print('[ov-runtime] 待补齐 %d 条' % len(targets))
        done = [0]
        lock = threading.Lock()

        def work_runtime(item):
            rec = manifest[item.id]
            thumb = _openverse_thumb_for(rec)
            with lock:
                done[0] += 1
                if done[0] % 20 == 0:
                    print('[ov-runtime] %d/%d' % (done[0], len(targets)),
                          flush=True)
                    jsave(manifest_path, {'version': 2, 'items': manifest})
            return item.id, thumb

        with ThreadPoolExecutor(max_workers=3) as pool:
            for fut in as_completed([pool.submit(work_runtime, it)
                                     for it in targets]):
                iid, thumb = fut.result()
                if thumb:
                    manifest[iid]['runtimeUrl'] = thumb
                    manifest[iid]['thumbnailUrl'] = thumb
                    manifest[iid]['runtimeVia'] = 'openverse'
        jsave(manifest_path, {'version': 2, 'items': manifest})
        got = sum(1 for it in targets
                  if manifest[it.id].get('runtimeVia') == 'openverse')
        print('[ov-runtime] 补齐 %d/%d' % (got, len(targets)))
        return 0

    if args.series_only:
        cleared = 0
        for it in items:
            rec = manifest.get(it.id) or {}
            if rec.get('tier') == 'series':
                manifest[it.id] = _miss_record(it)
                cleared += 1
        filled = series_fallback(items, manifest)
        jsave(manifest_path, {'version': 2, 'items': manifest})
        print('[series-only] 清除 %d, 回退补齐 %d' % (cleared, filled))
        for kind in sorted({it.kind for it in items}):
            st = {'product': 0, 'series': 0, 'miss': 0}
            for it in items:
                if it.kind != kind:
                    continue
                rec = manifest.get(it.id) or {}
                st[rec.get('tier') if rec.get('tier') in ('product', 'series')
                   else 'miss'] += 1
            print('%s: product=%d series=%d miss=%d' %
                  (kind, st['product'], st['series'], st['miss']))
        return 0

    done = 0
    total = len(items)
    t0 = time.time()
    lock = threading.Lock()
    force_ids = set()

    def work(item):
        prev = manifest.get(item.id) or {}
        raw = str(prev.get('rawFile') or '')
        if prev.get('status') == 'ok' and raw and os.path.exists(raw) \
                and prev.get('tier') == 'product':
            return item.id, prev, 'skip'
        if prev.get('status') == 'miss' and item.id not in force_ids \
                and not args.retry_missing and not args.no_reuse:
            return item.id, prev, 'skip-miss'
        rec = process_item(item, old_manifest.get(item.id), args.raw,
                           not args.no_openverse, not args.no_wikipedia)
        return item.id, rec, 'done'

    def run_pass(work_items, phase):
        nonlocal done
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {pool.submit(work, it): it for it in work_items}
            for fut in as_completed(futures):
                item = futures[fut]
                try:
                    iid, rec, kind = fut.result()
                except Exception as e:  # noqa: BLE001
                    iid, rec, kind = item.id, _miss_record(item), 'error'
                    rec['error'] = str(e)
                with lock:
                    manifest[iid] = rec
                    done += 1
                    if kind == 'done' or kind == 'error':
                        tier = rec.get('tier') or 'miss'
                        print('[%s %d/%d] %s %s -> %s %.0fs' % (
                            phase, done, total, iid, item.display_name, tier,
                            time.time() - t0), flush=True)
                    if done % 20 == 0:
                        jsave(manifest_path, {'version': 2, 'items': manifest})

    run_pass(items, '1')
    # 熔断恢复后，对首批因断网熔断而 miss 的条目再来一轮。
    for extra in (1, 2):
        if not _breaker_tripped[0]:
            break
        misses = [it for it in items
                  if (manifest.get(it.id) or {}).get('status') != 'ok']
        if not misses:
            break
        _breaker_wait()
        _breaker_tripped[0] = False
        force_ids.update(it.id for it in misses)
        print('[retry%d] 熔断恢复，重试 %d 条 miss' % (extra, len(misses)),
              flush=True)
        run_pass(misses, 'r%d' % extra)

    # series 回退（仅对未达 product 的条目）
    kinds = {it.kind for it in items}
    if 'camera' in kinds or 'lens' in kinds or True:
        filled = series_fallback(items, manifest)
        if filled:
            print('[series] 同系列/同类回退补齐 %d 条' % filled)

    jsave(manifest_path, {'version': 2, 'items': manifest})

    stats = {}
    for it in items:
        rec = manifest.get(it.id) or {}
        stats.setdefault(it.kind, {'product': 0, 'series': 0, 'miss': 0})
        stats[it.kind][rec.get('tier') if rec.get('tier') in
                       ('product', 'series') else 'miss'] += 1
    for kind, st in sorted(stats.items()):
        print('%s: product=%d series=%d miss=%d' %
              (kind, st['product'], st['series'], st['miss']))

    def key_total(key_kinds, n):
        pool = [it for it in items if it.kind in key_kinds]
        pool.sort(key=lambda it: (-it.price, it.id))
        return sum(1 for it in pool[:n]
                   if (manifest.get(it.id) or {}).get('tier') == 'product')

    print('Top100 全 product: %s (cam=%d/60 lens=%d/40)' % (
        'YES' if key_total(('camera',), 60) == 60 and key_total(('lens',), 40) == 40
        else 'NO', key_total(('camera',), 60), key_total(('lens',), 40)))
    print('raw: %s' % args.raw)
    return 0


if __name__ == '__main__':
    sys.exit(main())
