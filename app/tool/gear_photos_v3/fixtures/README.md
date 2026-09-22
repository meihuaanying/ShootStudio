# gear_photos_v3 离线 fixture（R48）

抓取器离线测试样例：**不触网**即可验证 provider 解析与端到端抓取/断点续跑状态机。
CI 不依赖外网；live 抓取仅作门禁证据。

## 目录结构

```
fixtures/
├── <label>/                    # label 见 tool/gear_photos_v3/brands.py
│   ├── index.json              # 产品页索引 [{url,text}]（可选，优先于 sitemap）
│   ├── suggest.json            # Shopify search/suggest.json 原样响应（可选）
│   ├── sitemap.xml             # 根 sitemap（sitemapindex 可递归到同级子 sitemap）
│   ├── sitemap_products.xml    # 子 sitemap 文件名 = URL basename
│   ├── page_<slug>.html        # 产品页；slug = URL 路径末段归一（小写字母数字）
│   └── <gear-id>.jpg           # 图片按 gear.json 条目 id 命名
```

## 自测

```powershell
cd app
python tool/gear_photos_v3/selftest.py     # 输出 [selftest] PASS，退出码 0
```

覆盖：offline 守卫（拒绝联网）、godox（index.json + 产品页）、aputure（suggest.json）、
viltrox（sitemapindex → urlset → 产品页）、`run.fetch` 端到端（元数据/原图/规范图
1100×825）、断点续跑与 `--retry-failed`/`--force` 状态机。

## 手工单点复现

```powershell
$env:GEAR_V3_OFFLINE='1'
python tool/gear_photos_v3/run.py fetch --ids light-g6-18 --providers official
```

样例图片为程序生成的示意占位（标注 `R48 OFFLINE FIXTURE - NOT A PRODUCT PHOTO`），
不是真实产品图，仅用于测试解析与下载链路。
