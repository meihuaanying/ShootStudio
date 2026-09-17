// 细分规划（纯逻辑，无 three 依赖）：运行时 character.js 与构建期 tool/subdivide_characters.mjs 共用。
// 策略：每个 SkinnedMesh 先做 1 次 Loop 细分（4 倍面数）；若整角色仍不足目标下限，
// 按当前面数从大到小挑选网格追加第 2 次细分（每次 x4），使每角色落入 40k–60k（默认）
// 或 80k–120k（level 2），永不突破 120k 硬上限。R18/D62 允许「调整细分次数或补充顶点密度」。
export const DEFAULT_LEVEL = 1;
export const HARD_MAX_TRIANGLES = 120000;
export const MAX_ITERATIONS_PER_MESH = 2;

export function levelTargets(level) {
  return level >= 2
    ? { min: 80000, max: 120000 }
    : { min: 40000, max: 60000 };
}

// 返回每个网格应施加的 Loop 细分次数（长度与 meshTriangles 一致）。
export function planSubdivision(meshTriangles, level = DEFAULT_LEVEL) {
  const counts = (Array.isArray(meshTriangles) ? meshTriangles : [])
    .map((n) => Math.max(0, Number(n) || 0));
  const iterations = counts.map(() => 0);
  if (level <= 0 || !counts.length) return iterations;
  const order = counts
    .map((n, i) => ({ n, i }))
    .sort((a, b) => b.n - a.n || a.i - b.i);
  for (const { i } of order) iterations[i] = 1;
  let total = counts.reduce((sum, n, i) => sum + n * 4 ** iterations[i], 0);
  const { min, max } = levelTargets(level);
  while (total < min) {
    let best = -1;
    let bestScore = Infinity;
    for (const { i } of order) {
      if (iterations[i] >= MAX_ITERATIONS_PER_MESH) continue;
      const current = counts[i] * 4 ** iterations[i];
      const next = total + current * 3;
      if (next > HARD_MAX_TRIANGLES) continue;
      let score;
      if (next >= min && next <= max) score = next - min; // 优先靠下限，避免不必要的面数
      else if (next > max) score = 1e6 + next;
      else score = min - next;
      if (score < bestScore) { bestScore = score; best = i; }
    }
    if (best < 0) break;
    iterations[best] += 1;
    total += counts[best] * 4 ** (iterations[best] - 1) * 3;
  }
  return iterations;
}

export function plannedTriangles(meshTriangles, level = DEFAULT_LEVEL) {
  const counts = (Array.isArray(meshTriangles) ? meshTriangles : [])
    .map((n) => Math.max(0, Number(n) || 0));
  const iterations = planSubdivision(counts, level);
  return counts.reduce((sum, n, i) => sum + n * 4 ** iterations[i], 0);
}
