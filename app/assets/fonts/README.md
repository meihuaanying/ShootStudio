# 随包字体（V8/D147 · §3.2）

| 文件 | 用途 | 大小 | 许可 |
| --- | --- | --- | --- |
| `NotoSerifSC-ShootStudio.otf` | Display / 标题（§3.2 展示字体） | 566,132 B（0.54 MB） | SIL Open Font License 1.1（见 `NotoSerifSC-OFL.txt`） |
| `NotoSerifSC-OFL.txt` | 许可全文 | 4,301 B | — |

## 来源

- 上游：`notofonts/noto-cjk`（Google Noto CJK）→ `Serif/SubsetOTF/SC/NotoSerifSC-Regular.otf`
- 原始文件：11,625,800 B（11.1 MB）；下载通道 jsDelivr（`https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Serif/SubsetOTF/SC/NotoSerifSC-Regular.otf`，github.com 本机不可达）
- 许可：SIL Open Font License 1.1（`https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Serif/LICENSE`），可随包分发与嵌入，署名见本目录。

## 子集化（R80 / D147「随包子集化 ≤2MB」）

- 字符集 = `app/lib/**` 与 `app/test/**` 全部字符串字面量中的 CJK 字符（**1,663 个**）+ 基础集（ASCII、CJK 标点 `U+3000–303F`、常用排版符号 `U+2010–203B`、全角 `U+FF01–FF5E`、箭头与制表符）= **2,074 个字符**
- 工具：fontTools 4.54.1（`pyftsubset`，`--layout-features=* --no-hinting --desubroutinize`）
- 结果：11,625,800 B → **566,132 B（0.54 MB）**，满足 ≤2 MB
- 缺字回退：子集外的汉字由系统字体回退（Windows 微软雅黑 / Android Roboto），不会出现豆腐块

复现命令（app 之外执行）：

```bash
pyftsubset NotoSerifSC-Regular.otf \
  --output-file=NotoSerifSC-ShootStudio.otf \
  --text-file=noto_serif_sc_chars.txt \
  --layout-features='*' --no-hinting --desubroutinize --name-IDs='*' --drop-tables+=DSIG
```

## 正文与数据字体

- 正文：系统无衬线（Windows: Microsoft YaHei UI；Android: Roboto；回退 sans）→ **不随包**（系统字体，不涉分发）
- 数据（mono）：JetBrains Mono（延续现有实现）→ 随包文件待 S3 与 S5 之前的字体资产批次补齐；S1 spike 截图用系统 Consolas 代跑（仅本地渲染，不入仓）
