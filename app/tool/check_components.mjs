// V8/D147 · R74/R82 组件收口门禁（软门禁，只降不升；CI 强制）。
//
// 目的：R74 已把弹层全部收口到 sanctioned API，但 feature 侧仍有绕过设计系统的
// 裸用法。这条门禁把它们**冻结在当前数量**：只允许随重构下降，不允许上涨 ——
// 即「新代码不许再绕过」，而不是「存量必须立刻清完」（存量清单见
// `docs/qa/v8-11-batch-b-audit.md`，逐处改造另排轮次）。
//
// 统计范围：`lib/features/**/*.dart`（注释行不计入）
//   textField      `TextField(`           → 应改用 SsTextInput / SsSearchField
//   textFormField  `TextFormField(`       → 同上（含校验场景）
//   bottomSheet    `showModalBottomSheet(`→ 应改用 showSsSheet
//   alertDialog    `AlertDialog(`         → 应改用 showSsDialog / SsDialog
//
// 用法：
//   node tool/check_components.mjs                        # 校验
//   node tool/check_components.mjs --json <输出路径>       # 校验并落证据
//   node tool/check_components.mjs --write-baseline        # 用当前实测重写基线（只允许下调）
//   node tool/check_components.mjs --write-baseline --allow-increase
//                                                          # 允许上调（需人工复核，会打印涨了什么）
// 退出码：0 = 通过；1 = 有指标上涨，或基线写入被拒。

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const argv = process.argv.slice(2);
const hasFlag = (name) => argv.includes(`--${name}`);
const argOf = (name, dflt) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : dflt;
};

const baselinePath = path.join(here, 'component_baseline.json');
const writeBaseline = hasFlag('write-baseline');
const allowIncrease = hasFlag('allow-increase');
const jsonOut = argOf('json', '');
const SCAN_DIR = 'lib/features';

// 注意：Dart 泛型调用会在名字与 `(` 之间夹一个类型实参，如
// `showModalBottomSheet<void>(` / `showModalBottomSheet<CharacterSelection>(`。
// 因此每个模式都必须允许可选的 `<…>`，否则会**漏计**（本门禁初版就漏了 4 处
// showModalBottomSheet，是反向验证时才发现的）。
const TYPE_ARGS = String.raw`(?:\s*<[^<>()]*>)?`;

const METRICS = [
  {
    key: 'textField',
    re: new RegExp(String.raw`\bTextField${TYPE_ARGS}\s*\(`, 'g'),
    hint: 'SsTextInput / SsSearchField',
  },
  {
    key: 'textFormField',
    re: new RegExp(String.raw`\bTextFormField${TYPE_ARGS}\s*\(`, 'g'),
    hint: 'SsTextInput（含校验场景）',
  },
  {
    key: 'bottomSheet',
    re: new RegExp(String.raw`\bshowModalBottomSheet${TYPE_ARGS}\s*\(`, 'g'),
    hint: 'showSsSheet',
  },
  {
    key: 'alertDialog',
    re: new RegExp(String.raw`\bAlertDialog${TYPE_ARGS}\s*\(`, 'g'),
    hint: 'showSsDialog / SsDialog',
  },
];

function walk(dir, acc = []) {
  if (!fs.existsSync(dir)) return acc;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, acc);
    else if (entry.name.endsWith('.dart')) acc.push(full);
  }
  return acc;
}

// 去掉注释再计数：行尾 `//…` 与 `/* … */` 块内文本不算用法。
// （行内字符串里的 `//`（如 URL）会被一并截断，对本门禁的四个模式无影响。）
function stripComments(src) {
  const out = [];
  let inBlock = false;
  for (const raw of src.split('\n')) {
    let line = raw;
    if (inBlock) {
      const end = line.indexOf('*/');
      if (end === -1) continue;
      line = line.slice(end + 2);
      inBlock = false;
    }
    line = line.replace(/\/\*.*?\*\//g, '');
    const open = line.indexOf('/*');
    if (open !== -1) {
      inBlock = true;
      line = line.slice(0, open);
    }
    line = line.replace(/\/\/.*$/, '');
    out.push(line);
  }
  return out.join('\n');
}

const files = walk(path.join(appRoot, SCAN_DIR));
const perFile = {};
const totals = {};
for (const m of METRICS) totals[m.key] = 0;

for (const file of files) {
  const rel = path.relative(appRoot, file).split(path.sep).join('/');
  const code = stripComments(fs.readFileSync(file, 'utf8'));
  const hits = {};
  let any = false;
  for (const m of METRICS) {
    const n = (code.match(m.re) ?? []).length;
    if (n > 0) {
      hits[m.key] = n;
      totals[m.key] += n;
      any = true;
    }
  }
  if (any) perFile[rel] = hits;
}

const baseline = fs.existsSync(baselinePath)
  ? JSON.parse(fs.readFileSync(baselinePath, 'utf8'))
  : { version: 1, metrics: {}, totals: {}, files: {} };
const baseTotals = baseline.totals ?? {};

const increases = [];
for (const m of METRICS) {
  const now = totals[m.key];
  const base = baseTotals[m.key] ?? 0;
  if (now > base) increases.push({ key: m.key, base, now, hint: m.hint });
}

const baseFiles = baseline.files ?? {};
const fileIncreases = [];
for (const [rel, hits] of Object.entries(perFile)) {
  const prev = baseFiles[rel] ?? {};
  for (const [key, n] of Object.entries(hits)) {
    const before = prev[key] ?? 0;
    if (n > before) {
      fileIncreases.push({ file: rel, key, before, now: n });
    }
  }
}

const pass = increases.length === 0;

console.log(
  `[components] 扫描 ${files.length} 个 Dart 文件（${SCAN_DIR}）` +
    `，基线 ${path.relative(appRoot, baselinePath).split(path.sep).join('/')}`,
);
for (const m of METRICS) {
  const now = totals[m.key];
  const base = baseTotals[m.key] ?? 0;
  const mark = now > base ? '✗' : now < base ? '↓' : '·';
  console.log(
    `  ${mark} ${m.key.padEnd(14)} ${String(now).padStart(4)} 处` +
      `（基线 ${String(base).padStart(4)}；应改用 ${m.hint}）`,
  );
}
for (const inc of increases) {
  console.error(
    `  ✗ ${inc.key} 上涨：${inc.base} → ${inc.now}（应改用 ${inc.hint}）`,
  );
}
for (const fi of fileIncreases.slice(0, 20)) {
  console.error(`    · ${fi.file}: ${fi.key} ${fi.before} → ${fi.now}`);
}
console.log(`[components] ${pass ? 'PASS' : 'FAIL'}`);

if (writeBaseline) {
  if (!pass && !allowIncrease) {
    console.error(
      '[components] 拒绝写基线：有指标上涨。若确为有意为之，' +
        '请人工复核后加 --allow-increase 重跑。',
    );
    process.exit(1);
  }
  const payload = {
    version: 1,
    note:
      'V8/D147 R74/R82 组件收口软门禁基线（lib/features 内裸 TextField/TextFormField/showModalBottomSheet/AlertDialog，只降不升）',
    at: new Date().toISOString(),
    metrics: Object.fromEntries(METRICS.map((m) => [m.key, m.hint])),
    totals,
    files: perFile,
  };
  fs.writeFileSync(baselinePath, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(
    `[components] 基线已写入 ${path.relative(appRoot, baselinePath).split(path.sep).join('/')}`,
  );
}

if (jsonOut) {
  const payload = {
    version: 1,
    note: 'V8/D147 R74/R82 component-conformance gate (lib/features bare widgets)',
    at: new Date().toISOString(),
    scanDir: SCAN_DIR,
    scannedFiles: files.length,
    metrics: Object.fromEntries(METRICS.map((m) => [m.key, m.hint])),
    totals,
    baselineTotals: baseTotals,
    increases,
    fileIncreases,
    files: perFile,
    pass,
  };
  const out = path.isAbsolute(jsonOut) ? jsonOut : path.join(appRoot, jsonOut);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(
    `[components] 报告 ${path.relative(appRoot, out).split(path.sep).join('/')}`,
  );
}

process.exit(pass ? 0 : 1);
