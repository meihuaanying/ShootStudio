// V8/D147 · R73 文件行数门禁（CI 强制）。
//
// 规则：
//   1. `lib/features/**\/*.dart` 单文件 ≤ 600 行；
//   2. `lib/core/design/*.dart` 单文件 ≤ 300 行；
//   3. 现存超限文件走 `tool/file_size_baseline.json` 基线白名单（当前行数 + 40 行余量），
//      只允许在拆分文件后**下调**，禁止上调（故白名单值不得大于「实际行数 + 40」）。
//
// 用法：node tool/check_file_size.mjs [--json <输出路径>]
// 退出码：0 = 通过；1 = 有文件超限或基线被抬高。

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
const baselinePath = path.join(here, 'file_size_baseline.json');
const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf8'));
const HEADROOM = 40;

const LIMITS = [
  { dir: 'lib/features', ext: '.dart', limit: 600, label: 'lib/features/**' },
  { dir: 'lib/core/design', ext: '.dart', limit: 300, label: 'lib/core/design/*' },
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

const rows = [];
for (const rule of LIMITS) {
  for (const file of walk(path.join(appRoot, rule.dir))) {
    const rel = path.relative(appRoot, file).split(path.sep).join('/');
    const lines = fs.readFileSync(file, 'utf8').split('\n').length;
    const allowed = lines > rule.limit ? (baseline.baseline[rel] ?? 0) : rule.limit;
    rows.push({ rel, lines, limit: rule.limit, allowed, over: lines > allowed });
  }
}

rows.sort((a, b) => b.lines - a.lines);

// 基线只降不升：白名单值不得超过「实际行数 + 余量」
const inflated = [];
for (const [rel, ceiling] of Object.entries(baseline.baseline ?? {})) {
  const row = rows.find((r) => r.rel === rel);
  if (!row) continue;
  if (Number(ceiling) > row.lines + HEADROOM) {
    inflated.push({ rel, ceiling: Number(ceiling), lines: row.lines });
  }
}

const violations = rows.filter((r) => r.over);
const pass = violations.length === 0 && inflated.length === 0;

console.log(`[file-size] 扫描 ${rows.length} 个 Dart 文件（limits: 600 / 300，基线白名单 ${Object.keys(baseline.baseline ?? {}).length} 项）`);
for (const r of violations) {
  console.error(`  ✗ ${r.rel}: ${r.lines} 行 > 允许 ${r.allowed}（上限 ${r.limit}）`);
}
for (const r of inflated) {
  console.error(`  ✗ 基线上调：${r.rel} 白名单 ${r.ceiling} > 实际 ${r.lines} + ${HEADROOM}`);
}
const top = rows.slice(0, 5);
for (const r of top) console.log(`  · ${String(r.lines).padStart(5)} 行  ${r.rel}`);
console.log(`[file-size] ${pass ? 'PASS' : 'FAIL'}`);

if (jsonOut) {
  const payload = {
    version: 1,
    note: 'V8/S3 R73 file size gate (lib/features <= 600, lib/core/design <= 300, baseline allowlist)',
    at: new Date().toISOString(),
    limits: { features: 600, design: 300, headroom: HEADROOM },
    files: rows.map((r) => ({ file: r.rel, lines: r.lines, limit: r.limit, allowed: r.allowed })),
    violations,
    inflatedBaseline: inflated,
    pass,
  };
  const out = path.isAbsolute(jsonOut) ? jsonOut : path.join(appRoot, jsonOut);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`[file-size] 报告 ${path.relative(appRoot, out)}`);
}

process.exit(pass ? 0 : 1);
