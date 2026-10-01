// 官网动效（V8/S10）：只保留滚动叙事 reveal + 首屏文案入场。
//
// S10 变更：删掉光圈叶片 / 胶片流线 / 视差 / 滚动加速速率等互动 —— 它们服务的
// 是旧的纯装饰 SVG 首屏，而 D157 要求首屏改为真实产品静帧。这些 DOM 已不存在，
// 逻辑留着就是死代码（呼应 §6 D158：删除未使用代码）。
//
// 动效约定：GSAP 只负责「何时进场」，具体过渡由 global.css 的 [data-reveal] /
// .is-in 承担，时长与缓动统一走 tokens.css 的 --motion-slow / --motion-ease（R71）。
// 尊重 prefers-reduced-motion；脚本失败或超时会兜底为全部可见。
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

const root = document.documentElement;
root.classList.add('js-ready');

const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
if (reduced) root.classList.add('no-motion');

/** 兜底：无论动效是否成功，1.2s 内所有内容可见（无 JS / 降级 / 低端机都不白屏）。 */
function revealAll() {
  document
    .querySelectorAll('[data-reveal], [data-hero-item]')
    .forEach((el) => el.classList.add('is-in'));
  const heroVisual = document.querySelector('[data-hero-visual]');
  if (heroVisual) heroVisual.classList.add('is-in');
}

window.setTimeout(revealAll, 1200);
window.addEventListener('error', revealAll, { once: true });

if (reduced) {
  revealAll();
} else {
  try {
    gsap.registerPlugin(ScrollTrigger);

    // 首屏文案与静帧：进入视口即进场（首屏本来就在视口内，start 放宽到 99%）。
    gsap.utils.toArray('[data-hero-item], [data-hero-visual]').forEach((el) => {
      ScrollTrigger.create({
        trigger: el,
        start: 'top 99%',
        once: true,
        onEnter: () => el.classList.add('is-in'),
      });
      // 首屏若因布局异常始终没触发（例如元素被折叠），兜底加类，避免永久隐藏。
      window.setTimeout(() => el.classList.add('is-in'), 600);
    });

    // 正文分节：滚到视口 88% 处进场，同屏多块用 batch 合并成一次回调。
    ScrollTrigger.batch('[data-reveal]', {
      start: 'top 88%',
      once: true,
      onEnter: (batch) => {
        batch.forEach((el, i) => {
          window.setTimeout(() => el.classList.add('is-in'), i * 40);
        });
      },
    });
  } catch (err) {
    // GSAP 或 ScrollTrigger 不可用：内容直接可见。
    revealAll();
  }
}
