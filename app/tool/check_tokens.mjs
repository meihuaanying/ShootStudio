// V8/D147 · R71 设计令牌唯一来源门禁（CI 强制）。
//
// 规则：`lib/**.dart` 里任何**颜色 / 字号 / 字重 / 间距 / 圆角 / 时长**都必须引用令牌，
// 不得出现裸字面量。四类扫描：
//   1. color   `Color(0x…)`                     —— 自造色值
//   2. colors  `Colors.white/black/grey…`       —— Flutter 内置色板绕过令牌
//   3. size    `fontSize: <数字>` / `fontWeight: FontWeight.w<N>` / `Duration(ms)`
//   4. metric  `EdgeInsets*` / `Radius*` / `BorderRadius*` 里的裸数字
//
// 三类豁免（与 FIX_CONTRACT_V8.0.md 的 R71 条款一致）：
//   a. 令牌定义文件本身（颜色/间距/字号/圆角就是在那儿定义的）；
//   b. PDF / 位图渲染管线（`exporter_pdf*.dart`、`exporter_render.dart`、`exporter_draw.dart`）——
//      导出的是「文档」，它的配色由排版决定，不是 App 的皮肤；
//   c. `CustomPainter` 内部绘图（画笔颜色是图元属性，不是 UI 皮肤）。
//
// 软门禁（V8/E2 · 偏差 1/5 的收编）：`AppSpaceFine` / `AppFontSize` /
// `AppRadiusFine` 三组「细阶」不在合同刻度上，也不适合标 `@Deprecated`
// （存量调用点多，`analyze --fatal-infos` 会因 `deprecated_member_use` 变红），
// 因此这里改为**计数并锁上限**：基线存 `tool/token_baseline.json`，只降不升。
//
// 用法：node tool/check_tokens.mjs [--json=<输出路径>] [--write-baseline]
// 退出码：0 = 通过；1 = 有裸字面量或细阶用量上升。

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const argv = process.argv.slice(2);
const argOf = (name, dflt) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : dflt;
};
const jsonOut = argOf('json', '');
const writeBaseline = argv.includes('--write-baseline');

// ── 豁免清单 ────────────────────────────────────────────────────────────────
const TOKEN_DEFS = new Set([
  'lib/core/design/tokens.dart',
  'lib/core/design/typography.dart',
  'lib/core/design/feature_colors.dart',
  'lib/core/design/spacing.dart',
]);
const RENDER_PIPELINE = new Set([
  'lib/features/export/exporter_pdf.dart',
  'lib/features/export/exporter_pdf_press.dart',
  'lib/features/export/exporter_render.dart',
  'lib/features/export/exporter_draw.dart',
]);
// CustomPainter 内部绘图：逐个点名，附理由，便于 review 时判断豁免是否还成立。
const PAINTER_FILES = {
  'lib/features/lighting/widgets/lighting_effect_widgets.dart': 'FaceLightPainter 脸部/布光示意图元',
  'lib/features/poses/pose_skeleton.dart': 'PoseSkeletonPainter 骨架图元',
  'lib/features/lighting/camera_helpers.dart': '构图辅助线图元',
  'lib/features/lighting/widgets/lighting_canvas_view.dart': '画布参考线图元',
  'lib/features/lighting/widgets/lighting_workbench.dart': 'CompositionGuidePainter 构图辅助图元',
  'lib/features/poses/pose_import_page_layout.dart': '骨架预览图元',
};

// ── 扫描规则 ────────────────────────────────────────────────────────────────
// 说明：所有规则都跑在「剥掉注释与文档注释之后的代码」上，避免注释里的示例
// 色值（例如文档里举例 `Color(0xFF000000 | …)`）被当成真违规。
const RULES = [
  {
    id: 'color',
    label: 'Color(0x…) 自造色值',
    re: /\bColor\s*\(\s*0x[0-9A-Fa-f]+/g,
  },
  {
    id: 'colors',
    label: 'Colors.* 内置色板',
    // 必须排除 pdfx.PdfColors.grey900 —— 它含有子串 "Colors.grey"。
    re: /(?<![.\w])Colors\s*\.\s*(?:white|black|grey|gray|red|green|blue|orange|yellow|purple)\b(?!\s*\d)/g,
  },
  {
    id: 'size',
    label: '字号 / 字重 / 时长字面量',
    re: /\b(?:fontSize|blurRadius|strokeWidth)\s*:\s*\d|\bfontWeight\s*:\s*FontWeight\s*\.\s*w\d|\bDuration\s*\(\s*(?:milliseconds|seconds|minutes)\s*:\s*\d/g,
  },
];

// metric 规则需要括号配平 + 剥离令牌引用，单独处理。
const METRIC_OPEN = /\b(EdgeInsets(?:\.\w+)*|Radius(?:\.\w+)*|BorderRadius(?:\.\w+)*)\s*\(/g;
const TOKEN_REF = /\b(?:AppSpace|AppSpaceFine|AppRadius|AppFontSize|AppDuration|AppScrim)\s*\.\s*[A-Za-z0-9_]+/g;

// Fine 细阶（不在合同刻度上）——计数并锁上限，只降不升。
const FINE_STEPS = [
  { id: 'appSpaceFine', label: 'AppSpaceFine 细阶', re: /\bAppSpaceFine\s*\./g },
  { id: 'appFontSize', label: 'AppFontSize 细阶', re: /\bAppFontSize\s*\./g },
  { id: 'appRadiusFine', label: 'AppRadiusFine 细阶', re: /\bAppRadiusFine\s*\./g },
];
const fineBaselinePath = path.join(appRoot, 'tool', 'token_baseline.json');

function stripComments(src) {
  // 粗粒度但够用：连续字符串里的 // 与 /* */。
  let out = '';
  let i = 0;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    const d = src[i + 1];
    if (c === '/' && d === '/') {
      while (i < n && src[i] !== '\n') i += 1;
      continue;
    }
    if (c === '/' && d === '*') {
      i += 2;
      while (i < n && !(src[i] === '*' && src[i + 1] === '/')) i += 1;
      i += 2;
      continue;
    }
    if (c === '"' || c === "'") {
      // 三引号文档注释
      if ((c === "'" && src[i + 1] === "'" && src[i + 2] === "'") ||
          (c === '"' && src[i + 1] === '"' && src[i + 2] === '"')) {
        const q = c.repeat(3);
        i += 3;
        while (i < n && src.slice(i, i + 3) !== q) i += 1;
        i += 3;
        continue;
      }
      const q = c;
      out += c;
      i += 1;
      while (i < n) {
        if (src[i] === '\\') { out += src.slice(i, i + 2); i += 2; continue; }
        out += src[i];
        if (src[i] === q) { i += 1; break; }
        i += 1;
      }
      continue;
    }
    out += c;
    i += 1;
  }
  return out;
}

function balancedFrom(src, openIdx) {
  let depth = 0;
  let i = openIdx;
  for (; i < src.length; i += 1) {
    if (src[i] === '(') depth += 1;
    else if (src[i] === ')') {
      depth -= 1;
      if (depth === 0) return src.slice(openIdx + 1, i);
    }
  }
  return '';
}

function walk(dir, acc = []) {
  if (!fs.existsSync(dir)) return acc;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, acc);
    else if (entry.name.endsWith('.dart')) acc.push(full);
  }
  return acc;
}

const findings = [];
const scanned = [];
// Fine 细阶用量统计（偏差 1/5：合同刻度之外的「细阶」保持只降不升）。
const fineCounts = { appSpaceFine: 0, appFontSize: 0, appRadiusFine: 0 };
for (const file of walk(path.join(appRoot, 'lib'))) {
  const rel = path.relative(appRoot, file).split(path.sep).join('/');
  const raw = fs.readFileSync(file, 'utf8');
  const src = stripComments(raw);
  for (const step of FINE_STEPS) {
    const hits = src.match(step.re);
    if (hits) fineCounts[step.id] += hits.length;
  }
  const exempt =
    TOKEN_DEFS.has(rel) || RENDER_PIPELINE.has(rel) || Boolean(PAINTER_FILES[rel]);
  scanned.push({ rel, exempt, reason: TOKEN_DEFS.has(rel) ? '令牌定义'
    : RENDER_PIPELINE.has(rel) ? 'PDF/位图渲染管线'
    : PAINTER_FILES[rel] ? `CustomPainter 内部：${PAINTER_FILES[rel]}` : '' });

  const push = (id, label, index, text) => {
    findings.push({ rule: id, label, file: rel, line: src.slice(0, index).split('\n').length, text: text.trim().slice(0, 120) });
  };

  for (const rule of RULES) {
    if (exempt) break;
    const re = new RegExp(rule.re.source, rule.re.flags);
    let m;
    while ((m = re.exec(src)) !== null) {
      push(rule.id, rule.label, m.index, m[0]);
    }
  }

  if (!exempt) {
    const re = new RegExp(METRIC_OPEN.source, METRIC_OPEN.flags);
    let m;
    while ((m = re.exec(src)) !== null) {
      const open = m.index + m[0].length - 1;
      const args = balancedFrom(src, open);
      // 先剥令牌引用，再剥三元条件 —— 条件里的数字是索引/状态码，不是间距值
      // （如 `right: i == 3 ? 0 : AppSpaceFine.n10`，那个 3 是列表下标）。
      const stripped = args
        .replace(TOKEN_REF, '')
        .replace(/[A-Za-z_][\w.\[\]()]*\s*(?:[=!<>]=?|==)\s*-?\d+(?:\.\d+)?\s*\?/g, 'COND?')
        .replace(/[A-Za-z_][\w.\[\]()]*\s*\?\s*(?=[^:]*:)/g, 'COND?')
        // 令牌名里允许带数字档位（AppRadiusFine.n1_5 / oversizeSoft20），
        // 前面一步只剥掉了 "AppRadiusFine." 前缀，剩余的 "n1_5"、"oversizeSoft20"
        // 会被当成裸数字。整段剥掉标识符里内嵌的数字。
        .replace(/\b[A-Za-z_]\w*\d[\w.]*\b/g, 'TOK');
      // 0 是「没有内边距」而不是设计刻度，一律放行。
      // 运行时派生的值（widget.height / 2）同样不是字面量，剥掉除法运算。
      const bare = stripped
        .replace(/[\w.\[\]()!]+\s*\/\s*[\w.\[\]()!]+/g, 'DERIVED')
        .replace(/(?<![\d.])0+(?![\d.])/g, '');
      // 只在参数里还有裸数字时才报；AppSpace.s4 之类的引用已被剥掉。
      if (/\d/.test(bare)) {
        push('metric', '间距 / 圆角裸数字', m.index, `${m[1]}(${stripped.split(/\s+/).join(' ')})`);
      }
      re.lastIndex = open + 1;
    }
  }
}

const byRule = findings.reduce((acc, f) => {
  acc[f.rule] = (acc[f.rule] ?? 0) + 1;
  return acc;
}, {});

// Fine 细阶软门禁：只降不升（数据基线 tool/token_baseline.json）。
const fineBaseline = fs.existsSync(fineBaselinePath)
  ? JSON.parse(fs.readFileSync(fineBaselinePath, 'utf8'))
  : null;
const fineRegressions = [];
if (writeBaseline) {
  fs.writeFileSync(
    fineBaselinePath,
    `${JSON.stringify({ version: 1, note: 'V8/E2 R71 fine-step usage ceiling (only-down)', at: new Date().toISOString(), counts: fineCounts }, null, 2)}\n`,
  );
  console.log('[tokens] Fine 细阶基线已写入 tool/token_baseline.json');
} else if (fineBaseline) {
  for (const step of FINE_STEPS) {
    const was = fineBaseline.counts?.[step.id] ?? 0;
    if (fineCounts[step.id] > was) {
      fineRegressions.push({ label: step.label, was, now: fineCounts[step.id] });
    }
  }
}

const pass = findings.length === 0 && fineRegressions.length === 0;

console.log(`[tokens] 扫描 lib 下 ${scanned.length} 个 Dart 文件（豁免 ${scanned.filter((s) => s.exempt).length} 个：令牌定义 / 渲染管线 / CustomPainter）`);
for (const rule of RULES.concat([{ id: 'metric', label: '间距 / 圆角裸数字' }])) {
  console.log(`  · ${rule.label}：${byRule[rule.id] ?? 0} 处`);
}
console.log('[tokens] Fine 细阶用量（只降不升）：');
for (const step of FINE_STEPS) {
  const now = fineCounts[step.id];
  const was = fineBaseline?.counts?.[step.id];
  const mark = was == null ? '·' : now > was ? '✗ 升' : now < was ? '↓ 降' : '· 持平';
  console.log(`  · ${step.label}：${now} 处${was == null ? '' : `（基线 ${was}）`}  ${mark}`);
}
for (const r of fineRegressions) {
  console.error(`  ✗ ${r.label} 由 ${r.was} 升到 ${r.now}（细阶只降不升，新增请改用合同刻度令牌）`);
}
for (const f of findings) {
  console.error(`  ✗ ${f.file}:${f.line}  [${f.rule}] ${f.text}`);
}
console.log(`[tokens] ${pass ? 'PASS' : 'FAIL'}`);

if (jsonOut) {
  const payload = {
    version: 1,
    note: 'V8/D147 R71 design-token gate: color/colors/size/metric literals must reference tokens',
    at: new Date().toISOString(),
    counts: byRule,
    fineSteps: fineCounts,
    fineRegressions,
    exemptions: scanned.filter((s) => s.exempt).map((s) => ({ file: s.rel, reason: s.reason })),
    findings,
    pass,
  };
  const out = path.isAbsolute(jsonOut) ? jsonOut : path.join(appRoot, jsonOut);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`[tokens] 报告 ${path.relative(appRoot, out)}`);
}

process.exit(pass ? 0 : 1);
