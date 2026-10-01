// V8/S10 · D157：官网 5 页截图门禁（桌面 + 移动 × 明暗双主题）。
//
// 用法（仓库根或 web/ 下均可）：
//   node web/tool/shot_s10.mjs
//   node web/tool/shot_s10.mjs --pages=/,/features --viewports=390x844
// 前置：web/ 内已 `npm run build`（Astro 产出 dist/）。
// 输出：docs/screenshots/v8/s10-web-<page>-<theme>-<w>x<h>.png
//       docs/qa/v8-s10-web-screenshots.json（含 announcements 通道检查结果）
//
// 与 S1 的 shot.mjs 的差别（都是刻意改动）：
//  1. 主题不再靠 `?t=darkroom` + 页面内联脚本（那套只服务已下线的 spike-hero），
//     改用 CDP `Emulation.setEmulatedMedia` 模拟 `prefers-color-scheme` —— 与
//     tailwind `darkMode: 'media'` 同源，一次构建即覆盖双主题。
//  2. 视口增加移动档 390x844（`mobile: true`），桌面两档沿用 1280x800 / 1920x1080。
//  3. 就绪标记用 motion.js 加的 `js-ready` class，而不是 spike-hero 的 `spike-ready`。
//  4. 顺带验证 announcements 通道（D157 要求通道不回归）：/downloads 的 8 个
//     DOM id 必须被 announcements.json 写入。
//  5. 顺带检查「禁止占位图」（R82）：页面里不允许出现 0 字节或缺失的 <img>。

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(here, '..');
const repoRoot = path.resolve(webRoot, '..');
const distDir = path.join(webRoot, 'dist');
const shotDir = path.join(repoRoot, 'docs', 'screenshots', 'v8');
const qaDir = path.join(repoRoot, 'docs', 'qa');

const argv = process.argv.slice(2);
const argOf = (name, dflt) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : dflt;
};
/** 5 个正式页（spike-hero 是 S1 残留，不在 D157 的 5 页内）。 */
const pages = argOf('pages', '/,/features,/downloads,/templates,/changelog')
  .split(',')
  .filter(Boolean);
const themes = argOf('themes', 'paper,darkroom').split(',').filter(Boolean);
/** 末档 390x844 视为移动端（mobile: true 才会套 meta viewport 的移动断点）。 */
const MOBILE = '390x844';
const viewports = argOf('viewports', '1280x800,1920x1080,390x844').split(',').filter(Boolean);
const outJson = path.join(qaDir, argOf('index', 'v8-s10-web-screenshots.json'));

if (!fs.existsSync(path.join(distDir, 'index.html'))) {
  console.error('[shot] 未找到 web/dist/index.html：请先在 web/ 执行 npm run build');
  process.exit(2);
}
fs.mkdirSync(shotDir, { recursive: true });
fs.mkdirSync(qaDir, { recursive: true });

const EDGE = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
].find((p) => fs.existsSync(p));
if (!EDGE) {
  console.error('[shot] 未找到 Edge 可执行文件');
  process.exit(2);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff',
  '.txt': 'text/plain; charset=utf-8',
  '.ico': 'image/x-icon',
};

const server = http.createServer((req, res) => {
  let pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
  if (pathname.endsWith('/')) pathname += 'index.html';
  const file = path.join(distDir, pathname);
  if (!file.startsWith(distDir)) {
    res.writeHead(403);
    res.end();
    return;
  }
  fs.readFile(file, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('not found');
      return;
    }
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(pathname).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(data);
  });
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const serverPort = server.address().port;

const edgePort = 9992;
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-s10shot-'));
const proc = spawn(
  EDGE,
  [
    '--headless=new',
    '--hide-scrollbars',
    '--no-first-run',
    '--no-default-browser-check',
    '--force-device-scale-factor=1',
    '--disable-lcd-text',
    '--font-render-hinting=none',
    `--remote-debugging-port=${edgePort}`,
    `--user-data-dir=${profile}`,
    'about:blank',
  ],
  { stdio: 'ignore' },
);

const shots = [];
let failed = 0;
/** announcements 通道检查结果（D157「通道不变」的门禁证据）。 */
let announcement = null;
try {
  let ready = false;
  for (let i = 0; i < 100; i++) {
    try {
      if ((await fetch(`http://127.0.0.1:${edgePort}/json/version`)).ok) {
        ready = true;
        break;
      }
    } catch (_) {
      /* retry */
    }
    await sleep(200);
  }
  if (!ready) throw new Error('Edge 调试端口未就绪');
  const target = await (
    await fetch(`http://127.0.0.1:${edgePort}/json/new?url=about:blank`, { method: 'PUT' })
  ).json();
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((res, rej) => {
    ws.onopen = res;
    ws.onerror = rej;
  });
  let id = 0;
  const pending = new Map();
  const jsErrors = [];
  ws.onmessage = (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pending.has(m.id)) {
      pending.get(m.id)(m);
      pending.delete(m.id);
      return;
    }
    if (m.method === 'Runtime.exceptionThrown') {
      jsErrors.push(String(m.params?.exceptionDetails?.text ?? 'exception'));
    }
  };
  const call = (method, params = {}) =>
    new Promise((res) => {
      const i = ++id;
      pending.set(i, res);
      ws.send(JSON.stringify({ id: i, method, params }));
    });
  const ev = async (expr) => {
    const r = await call('Runtime.evaluate', {
      expression: expr,
      returnByValue: true,
      awaitPromise: true,
    });
    return r?.result?.result?.value;
  };
  await call('Page.enable');
  await call('Runtime.enable');

  for (const theme of themes) {
    // D157：明暗跟随系统（tokens.css 的 [data-theme='darkroom'] + darkMode:'media'），
    // 所以用 CDP 模拟 prefers-color-scheme，而不是 URL 参数。
    // 注意 prefers-color-scheme 只接受 light|dark；paper/darkroom 是本站的内部命名。
    await call('Emulation.setEmulatedMedia', {
      features: [
        { name: 'prefers-color-scheme', value: theme === 'darkroom' ? 'dark' : 'light' },
      ],
    });
    for (const page of pages) {
      const slug = page === '/' ? 'index' : page.replace(/^\/+/, '').replace(/\/+$/, '');
      for (const vp of viewports) {
        const [w, h] = vp.split('x').map(Number);
        const isMobile = vp === MOBILE;
        await call('Emulation.setDeviceMetricsOverride', {
          width: w,
          height: h,
          deviceScaleFactor: 1,
          mobile: isMobile,
        });
        // astro 的 trailingSlash:'ignore' 会把页面输出成 dist/<page>/index.html，
        // 所以导航 URL 必须带尾斜杠，否则静态服务器会去读目录名而 404。
        const urlPath = page.endsWith('/') ? page : `${page}/`;
        await call('Page.navigate', { url: `http://127.0.0.1:${serverPort}${urlPath}` });
        // 就绪：readyState complete + motion.js 已加 js-ready。
        for (let i = 0; i < 120; i++) {
          const ok = await ev(
            "document.readyState === 'complete' && document.documentElement.classList.contains('js-ready')",
          );
          if (ok) break;
          await sleep(150);
        }
        await ev('document.fonts.ready.then(() => true)');
        // 等 reveal 兜底与首屏静帧入场结束。
        await sleep(900);

        const info = await ev(
          `JSON.stringify({
            theme: document.documentElement.dataset.theme || null,
            bg: getComputedStyle(document.body).backgroundColor,
            ink: getComputedStyle(document.body).color,
            scrollH: document.body.scrollHeight,
            // R82：不允许占位图。loading="lazy" 的屏外图尚未开始下载是正常的，
            // 只把「已加载完但 naturalWidth === 0」（真失败）算作 broken；
            // 非 lazy 的图没加载完就算 broken。
            brokenImgs: Array.from(document.images)
              .filter((i) => {
                const loaded = i.complete && i.naturalWidth > 0;
                if (i.loading === 'lazy') return i.complete && i.naturalWidth === 0;
                return !loaded;
              })
              .map((i) => i.getAttribute('src')),
            // 只统计「已进入视口却仍未 reveal」的块：屏外的屏外块本就该等滚动。
            hidden: Array.from(document.querySelectorAll('[data-reveal], [data-hero-item]'))
              .filter((el) => {
                const r = el.getBoundingClientRect();
                const inView = r.top < (window.innerHeight || 0) && r.bottom > 0;
                return inView && getComputedStyle(el).opacity === '0';
              })
              .length
          })`,
        );
        const meta = info ? JSON.parse(info) : {};

        if (page === '/downloads' && !announcement) {
          const ann = await ev(
            `JSON.stringify({
              winVer: document.getElementById('win-ver')?.textContent ?? null,
              andVer: document.getElementById('and-ver')?.textContent ?? null,
              winMirror: document.getElementById('win-mirror')?.getAttribute('href') ?? null,
              andMirror: document.getElementById('and-mirror')?.getAttribute('href') ?? null,
              winSha: document.getElementById('win-sha')?.textContent ?? null,
              andSha: document.getElementById('and-sha')?.textContent ?? null
            })`,
          );
          announcement = ann ? JSON.parse(ann) : null;
        }

        const cap = await call('Page.captureScreenshot', {
          format: 'png',
          captureBeyondViewport: false,
          fromSurface: true,
        });
        const data = cap?.result?.data;
        const name = `s10-web-${slug}-${theme}-${vp}`;
        if (!data) {
          console.error(`[shot] 截图失败：${name}`);
          failed += 1;
          continue;
        }
        const buf = Buffer.from(data, 'base64');
        fs.writeFileSync(path.join(shotDir, `${name}.png`), buf);
        shots.push({
          name,
          page,
          theme,
          size: vp,
          mobile: isMobile,
          bytes: buf.length,
          domTheme: meta.theme ?? null,
          bodyBg: meta.bg ?? null,
          bodyInk: meta.ink ?? null,
          scrollHeight: meta.scrollH ?? null,
          brokenImgs: meta.brokenImgs ?? [],
          unrevealed: meta.hidden ?? null,
        });
        console.log(
          `[shot] ${name}.png  ${buf.length} B  theme=${meta.theme}  bg=${meta.bg}  broken=${(meta.brokenImgs ?? []).length}  unrevealed=${meta.hidden}`,
        );
      }
    }
  }
  if (jsErrors.length) {
    console.error(`[shot] 页面存在 JS 异常 ${jsErrors.length} 条：${jsErrors.slice(0, 3).join(' | ')}`);
    failed += 1;
  }
  ws.close();
} finally {
  try {
    proc.kill();
  } catch (_) {
    /* ignore */
  }
  server.close();
  try {
    fs.rmSync(profile, { recursive: true, force: true });
  } catch (_) {
    /* ignore */
  }
}

const payload = {
  version: 1,
  note: 'V8/S10 · D157 官网 5 页截图（明暗双主题 × 桌面 1280x800 / 1920x1080 + 移动 390x844）',
  at: new Date().toISOString(),
  pages,
  themes,
  viewports,
  expect: pages.length * themes.length * viewports.length,
  count: shots.length,
  announcement,
  brokenImgs: shots.filter((s) => s.brokenImgs.length).map((s) => s.name),
  shots,
};
fs.writeFileSync(outJson, `${JSON.stringify(payload, null, 2)}\n`);
console.log(
  `[shot] 写出 ${shots.length}/${payload.expect} 张 → ${path.relative(repoRoot, shotDir)}；索引 ${path.relative(repoRoot, outJson)}`,
);
if (announcement) console.log(`[shot] announcements 通道：${JSON.stringify(announcement)}`);
if (failed || shots.length !== payload.expect) process.exit(1);
