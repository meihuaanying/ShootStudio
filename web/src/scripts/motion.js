// 官网动效（W2/D27）：GSAP 滚动叙事 + SVG 光圈/胶片 hero 入场。无 WebGL。
// 尊重 prefers-reduced-motion；脚本失败或超时自动降级为静态可见。
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

document.documentElement.classList.add('js-ready');

const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
if (reduced) {
  document.documentElement.classList.add('no-motion');
}

function revealAll() {
  document.querySelectorAll('[data-reveal]').forEach((el) => {
    el.style.opacity = '1';
    el.style.transform = 'none';
  });
  document.querySelectorAll('[data-hero-item]').forEach((el) => {
    el.style.opacity = '1';
    el.style.transform = 'none';
  });
  // 英雄区装饰元素：无论动效是否推进，都必须可见。
  document.querySelectorAll('.film-strip-roll, .aperture-blades, [data-hero-visual]').forEach((el) => {
    el.style.opacity = '1';
  });
}

// 兜底：无论动效是否成功，1.2s 内所有内容可见。
window.setTimeout(revealAll, 1200);
window.addEventListener('error', revealAll, { once: true });

if (!reduced) {
  try {
    gsap.registerPlugin(ScrollTrigger);
    // 通用滚动 reveal。
    gsap.utils.toArray('[data-reveal]').forEach((el) => {
      gsap.to(el, {
        opacity: 1,
        y: 0,
        duration: 0.7,
        ease: 'power3.out',
        scrollTrigger: { trigger: el, start: 'top 88%' },
      });
    });

    // 首屏文案入场。
    const hero = document.querySelector('[data-hero]');
    if (hero) {
      gsap.from(hero.querySelectorAll('[data-hero-item]'), {
        opacity: 0,
        y: 22,
        duration: 0.8,
        ease: 'power3.out',
        stagger: 0.08,
      });
    }

    // 光圈叶片入场：由闭合展开（fromTo 保证结束态可见）。
    const blades = document.querySelector('.aperture-blades');
    if (blades) {
      gsap.fromTo(
        blades,
        { rotate: -48, scale: 0.72, opacity: 0 },
        { rotate: 0, scale: 1, opacity: 1, duration: 1.1, ease: 'power3.out' },
      );
    }

    // 胶片流线入场（只动位置，不隐藏，确保低性能/节流下仍可见）。
    const strips = gsap.utils.toArray('.film-strip-roll');
    strips.forEach((strip, i) => {
      gsap.fromTo(
        strip,
        { x: i === 0 ? -18 : 18 },
        { x: 0, duration: 0.9, ease: 'power2.out', delay: 0.15 + i * 0.08 },
      );
    });
    gsap.fromTo(
      '[data-hero-visual]',
      { scale: 0.96 },
      { scale: 1, duration: 1, ease: 'power3.out' },
    );
  } catch (err) {
    revealAll();
  }
}

// ---------- E1/E2（D57）：鼠标视差 + 滚动加速胶片流线（原生 rAF + lerp） ----------
// 任何失败都只影响互动本身，不影响 revealAll 兜底与无 JS 可见性。
function initHeroInteractions() {
  if (reduced) return;

  const heroZone = document.querySelector('[data-hero-zone]');
  const apertureWrap = document.querySelector('[data-aperture-parallax]');
  const filmWraps = Array.from(document.querySelectorAll('[data-film-parallax]'));
  const filmRolls = Array.from(document.querySelectorAll('.film-strip-roll'));
  const heroVisual = document.querySelector('[data-hero-visual]');

  // E1：光圈/胶片视差——仅桌面精确指针启用，且 hero 在视口内。
  if (heroZone && apertureWrap && window.matchMedia('(min-width: 768px) and (pointer: fine)').matches) {
    const LERP = 0.08;
    const APERTURE_PX = 10;
    const APERTURE_DEG = 3;
    const FILM_PX = 6;
    let targetX = 0;
    let targetY = 0;
    let curX = 0;
    let curY = 0;
    let rafId = 0;

    const apply = () => {
      apertureWrap.style.transform =
        `translate(${(curX * APERTURE_PX).toFixed(2)}px, ${(curY * APERTURE_PX).toFixed(2)}px)` +
        ` rotate(${(curX * APERTURE_DEG).toFixed(2)}deg)`;
      filmWraps.forEach((el, i) => {
        el.style.transform = `translateX(${(curX * FILM_PX * (i === 0 ? -1 : 1)).toFixed(2)}px)`;
      });
    };

    const tick = () => {
      curX += (targetX - curX) * LERP;
      curY += (targetY - curY) * LERP;
      if (Math.abs(targetX - curX) < 0.001 && Math.abs(targetY - curY) < 0.001) {
        curX = targetX;
        curY = targetY;
        apply();
        rafId = 0;
        return;
      }
      apply();
      rafId = requestAnimationFrame(tick);
    };

    const kick = () => {
      if (!rafId) rafId = requestAnimationFrame(tick);
    };

    const recenter = () => {
      targetX = 0;
      targetY = 0;
      kick();
    };

    heroZone.addEventListener(
      'pointermove',
      (e) => {
        const rect = heroZone.getBoundingClientRect();
        if (!rect.width || !rect.height) return;
        targetX = Math.max(-1, Math.min(1, ((e.clientX - rect.left) / rect.width) * 2 - 1));
        targetY = Math.max(-1, Math.min(1, ((e.clientY - rect.top) / rect.height) * 2 - 1));
        kick();
      },
      { passive: true },
    );

    // 离开 hero / 窗口失焦：缓动回中；滚出视口：直接归位避免无谓帧。
    heroZone.addEventListener('pointerleave', recenter, { passive: true });
    window.addEventListener('blur', recenter);
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(
        (entries) => {
          if (entries.some((en) => en.isIntersecting)) return;
          targetX = 0;
          targetY = 0;
          curX = 0;
          curY = 0;
          apply();
        },
        { threshold: 0.05 },
      ).observe(heroZone);
    }
  }

  // E2：滚动速度（px/s 平滑）→ 胶片动画速率；空闲 300ms 后平滑回落到基准速度。
  if (filmRolls.length && heroVisual) {
    const MAX_RATE = 3;
    const IDLE_MS = 300;
    let speed = 0;
    let rate = 1;
    let targetRate = 1;
    let lastY = window.scrollY;
    let lastT = performance.now();
    let idleTimer = 0;
    let rafId = 0;

    const applyRate = () => {
      heroVisual.style.setProperty('--film-rate', rate.toFixed(3));
    };

    const tickRate = () => {
      rate += (targetRate - rate) * 0.1;
      if (Math.abs(targetRate - rate) < 0.002) {
        rate = targetRate;
        applyRate();
        rafId = 0;
        return;
      }
      applyRate();
      rafId = requestAnimationFrame(tickRate);
    };

    const kickRate = () => {
      if (!rafId) rafId = requestAnimationFrame(tickRate);
    };

    window.addEventListener(
      'scroll',
      () => {
        const now = performance.now();
        const y = window.scrollY;
        const dt = Math.max(now - lastT, 8) / 1000;
        speed = speed * 0.8 + (Math.abs(y - lastY) / dt) * 0.2;
        lastY = y;
        lastT = now;
        targetRate = Math.min(1 + speed / 1400, MAX_RATE);
        window.clearTimeout(idleTimer);
        idleTimer = window.setTimeout(() => {
          speed = 0;
          targetRate = 1;
          kickRate();
        }, IDLE_MS);
        kickRate();
      },
      { passive: true },
    );
  }
}

try {
  initHeroInteractions();
} catch (err) {
  // 互动初始化失败：保持静态 hero，revealAll 兜底不受影响。
}
