/** V8/D147 · S3 设计 spike / S10 官网重做：Tailwind 主题。
 *  颜色、字号、间距、圆角、阴影、动效时长全部指向 styles/tokens.css 的 CSS 变量
 *  （§3 唯一来源，值与 App AppTokensV2 逐字一致）。S10 已删除旧蓝紫 `ss.*` 体系，
 *  页面只允许用 `v8-*` 工具类（R71：禁硬编码字面值）。 */
/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'media',
  content: ['./src/**/*.{astro,html,js,ts,md}'],
  theme: {
    extend: {
      colors: {
        v8: {
          bg: 'var(--bg)',
          surface: 'var(--surface)',
          sunken: 'var(--surface-sunken)',
          ink: 'var(--ink)',
          'ink-soft': 'var(--ink-soft)',
          muted: 'var(--muted)',
          rule: 'var(--rule)',
          accent: 'var(--accent)',
          'accent-soft': 'var(--accent-soft)',
          film: 'var(--film)',
          gold: 'var(--gold)',
          danger: 'var(--danger)',
        },
      },
      fontFamily: {
        sans: [
          'var(--font-body)',
        ],
        display: [
          'var(--font-display)',
        ],
        mono: [
          'var(--font-mono)',
        ],
      },
      fontSize: {
        'v8-display': ['var(--type-display)', { lineHeight: 'var(--lh-display)' }],
        'v8-h1': ['var(--type-h1)', { lineHeight: 'var(--lh-h1)' }],
        'v8-h2': ['var(--type-h2)', { lineHeight: 'var(--lh-h2)' }],
        'v8-h3': ['var(--type-h3)', { lineHeight: 'var(--lh-h3)' }],
        'v8-body': ['var(--type-body)', { lineHeight: 'var(--lh-body)' }],
        'v8-small': ['var(--type-small)', { lineHeight: 'var(--lh-small)' }],
        'v8-caption': ['var(--type-caption)', { lineHeight: 'var(--lh-caption)' }],
      },
      spacing: {
        'v8-1': 'var(--sp-1)',
        'v8-2': 'var(--sp-2)',
        'v8-3': 'var(--sp-3)',
        'v8-4': 'var(--sp-4)',
        'v8-5': 'var(--sp-5)',
        'v8-6': 'var(--sp-6)',
        'v8-7': 'var(--sp-7)',
        'v8-8': 'var(--sp-8)',
      },
      borderRadius: {
        'v8-chip': 'var(--radius-chip)',
        'v8-control': 'var(--radius-control)',
        'v8-frame': 'var(--radius-frame)',
      },
      boxShadow: {
        'v8-paper': 'var(--shadow-paper)',
        'v8-overlay': 'var(--shadow-overlay)',
      },
      transitionDuration: {
        'v8-fast': 'var(--motion-fast)',
        'v8-normal': 'var(--motion-normal)',
        'v8-slow': 'var(--motion-slow)',
      },
    },
  },
  plugins: [],
};
