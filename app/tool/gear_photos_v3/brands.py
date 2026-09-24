# -*- coding: utf-8 -*-
"""品牌 → 官网配置（E/D130：官网 > 京东 > 亚马逊 > 淘宝）。

每个品牌提供 sitemap（XML urlset 或 sitemapindex）与产品页过滤规则；
offline fixture 模式下由 providers.official 读取 fixtures 目录，不触网。
"""
from __future__ import annotations

BRAND_CONFIG = [
    {
        'names': ('神牛', 'godox'),
        'label': 'godox',
        'sitemaps': ['https://www.godox.com/sitemap.xml'],
        'product_re': r'/product[-\w]*/[^"\']+?\.html',
        'index_pages': ['https://www.godox.com/lists_216/'],
        'listing_link_re': r'href="(/[A-Za-z][A-Za-z0-9\-]*/)"',
        'guess_urls': [
            'https://www.godox.com/product-d/%s.html',
            'https://www.godox.com/product-c/%s.html',
            'https://www.godox.com/product-b/%s.html',
            'https://www.godox.com/product-a/%s.html',
            'https://www.godox.com/product-e/%s.html',
            'https://www.godox.com/product-d/LED/%s.html',
            'https://www.godox.com/product-e/LED/%s.html',
        ],
        'note': '无产品 sitemap：类目页展开 + 直猜产品 URL 兜底',
    },
    {
        'names': ('爱图仕', 'aputure'),
        'label': 'aputure',
        'sitemaps': ['https://aputure.com/sitemap.xml'],
        'product_re': r'/products/',
        'suggest_sites': ['https://www.aputure.com'],
        'note': 'Shopify：sitemapindex + suggest.json',
    },
    {
        'names': ('南冠', '南光', 'nanlite', 'nanlux'),
        'label': 'nanlite',
        'sitemaps': ['https://www.nanliteus.com/sitemap.xml'],
        'product_re': r'/products/',
        'suggest_sites': ['https://www.nanliteus.com'],
        'note': 'Nanlite US（Shopify）',
    },
    {
        'names': ('永诺', 'yongnuo'),
        'label': 'yongnuo',
        'sitemaps': ['https://www.hkyongnuo.com/sitemap.xml'],
        'product_re': r'.',
    },
    {
        'names': ('老蛙', 'laowa'),
        'label': 'laowa',
        'sitemaps': ['https://www.laowalens.com/sitemap.xml'],
        'product_re': r'.',
    },
    {
        'names': ('唯卓仕', 'viltrox'),
        'label': 'viltrox',
        'sitemaps': ['https://viltrox.com/sitemap.xml'],
        'product_re': r'/products?/',
        'suggest_sites': ['https://viltrox.com'],
    },
    {
        'names': ('曼富图', 'manfrotto'),
        'label': 'manfrotto',
        'sitemaps': ['https://www.manfrotto.com/sitemap.xml'],
        'product_re': r'/products?/',
    },
    {
        'names': ('哈苏', 'hasselblad'),
        'label': 'hasselblad',
        'sitemaps': ['https://www.hasselblad.com/sitemap.xml'],
        'product_re': r'/products?/',
    },
    {
        'names': ('腾龙', 'tamron'),
        'label': 'tamron',
        'sitemaps': ['https://www.tamron.com/sitemap.xml'],
        'product_re': r'/global/products',
    },
    {
        'names': ('金贝', 'jinbei'),
        'label': 'jinbei',
        'sitemaps': [],
        'product_re': r'.',
        'note': '官网无可用 sitemap（连接被重置），降级 JD/关键词源',
    },
    {
        'names': ('智云', 'zhiyun'),
        'label': 'zhiyun',
        'sitemaps': ['https://store.zhiyun-tech.com/sitemap.xml'],
        'product_re': r'/products?/',
        'note': '官网无 sitemap，用官方商店（store 子站）',
    },
    {
        'names': ('布朗', 'broncolor'),
        'label': 'broncolor',
        'sitemaps': ['https://broncolor.swiss/sitemap.xml'],
        'product_re': r'/products?/|/en/',
    },
    {
        'names': ('奈特科尔', 'nitecore'),
        'label': 'nitecore',
        'sitemaps': ['https://www.nitecore.com/sitemap.xml'],
        'product_re': r'/product',
    },
    {
        'names': ('蔡司', 'zeiss'),
        'label': 'zeiss',
        'sitemaps': ['https://www.zeiss.com/sitemap.xml'],
        'product_re': r'/products?/|/camera-lenses/',
    },
    {
        'names': ('铭匠', 'ttartisan'),
        'label': 'ttartisan',
        'sitemaps': ['https://www.ttartisan.com/sitemap.xml'],
        'product_re': r'/products?/',
    },
    {
        'names': ('富图宝', 'fotopro'),
        'label': 'fotopro',
        'sitemaps': ['https://www.fotopro.com/sitemap.xml'],
        'product_re': r'/products?/',
    },
    {
        'names': ('斯莫格', 'smallrig'),
        'label': 'smallrig',
        'sitemaps': ['https://www.smallrig.com/sitemap.xml'],
        'product_re': r'/products?/',
    },
    # ---- V7/D142：品牌配置扩展（相机/镜头/无人机九家）----
    {
        'names': ('佳能', 'canon'),
        'label': 'canon',
        'sitemaps': [
            'https://www.usa.canon.com/sitemap.xml',
            'https://www.canon.com.cn/sitemap.xml',
        ],
        'product_re': r'/products?/|/cameras/|/lenses/',
        'note': 'V7/D142：官网 sitemap 优先，反爬时降级授权零售商/系列兜底',
    },
    {
        'names': ('尼康', 'nikon'),
        'label': 'nikon',
        'sitemaps': [
            'https://www.nikon.com/sitemap.xml',
            'https://www.nikonusa.com/sitemap.xml',
        ],
        'product_re': r'/products?/|/cameras/|/lenses/',
        'note': 'V7/D142：官网 sitemap 优先',
    },
    {
        'names': ('索尼', 'sony'),
        'label': 'sony',
        'sitemaps': [
            'https://www.sony.com/sitemap.xml',
            'https://www.sony.com.cn/sitemap.xml',
        ],
        'product_re': r'/products?/|/electronics/|/cameras/',
        'note': 'V7/D142：官网 sitemap 优先',
    },
    {
        'names': ('松下', 'panasonic'),
        'label': 'panasonic',
        'sitemaps': [
            'https://www.panasonic.com/sitemap.xml',
            'https://www.panasonic.com.cn/sitemap.xml',
        ],
        'product_re': r'/products?/|/cameras/|/lenses/',
        'note': 'V7/D142：官网 sitemap 优先',
    },
    {
        'names': ('适马', 'sigma'),
        'label': 'sigma',
        'sitemaps': [
            'https://www.sigma-global.com/sitemap.xml',
            'https://www.sigma-global.com/en/sitemap.xml',
        ],
        'product_re': r'/products?/|/lenses/',
        'note': 'V7/D142：官网 sitemap 优先',
    },
    {
        'names': ('富士', 'fujifilm'),
        'label': 'fujifilm',
        'sitemaps': [
            'https://www.fujifilm.com/sitemap.xml',
            'https://fujifilm-x.com/sitemap.xml',
        ],
        'product_re': r'/products?/|/cameras/|/lenses/',
        'note': 'V7/D142：官网 + X 系列子站 sitemap',
    },
    {
        'names': ('徕卡', 'leica'),
        'label': 'leica',
        'sitemaps': [
            'https://leica-camera.com/sitemap.xml',
            'https://leica-camera.com/en-US/sitemap.xml',
        ],
        'product_re': r'/products?/|/photography/',
        'note': 'V7/D142：官网 sitemap 优先',
    },
    {
        'names': ('大疆', 'dji'),
        'label': 'dji',
        'sitemaps': [
            'https://www.dji.com/sitemap.xml',
            'https://www.dji.com/cn/sitemap.xml',
        ],
        'product_re': r'/products?/|/cameras/|/gimbals/',
        'note': 'V7/D142：官网 sitemap 优先',
    },
]


def brand_config(brand: str):
    text = str(brand or '').strip().lower()
    for cfg in BRAND_CONFIG:
        if any(name.lower() in text for name in cfg['names']):
            return cfg
    return None
