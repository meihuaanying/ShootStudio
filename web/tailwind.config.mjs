/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'media',
  content: ['./src/**/*.{astro,html,js,ts,md}'],
  theme: {
    extend: {
      colors: {
        // V8/D147 · S3：v8-* 直接映射 src/styles/tokens.css 的 CSS 变量
        // （§3 唯一来源；App 端同名令牌在 app/lib/core/design/tokens.dart）。
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
        // 旧蓝紫体系：S10 官网重做后删除。
        ss: {
          accent: '#4D6BFE',
          accent2: '#7B5CFF',
          success: '#2BA471',
          warning: '#E37318',
          danger: '#D54941',
          ink: { DEFAULT: '#1F2329', dark: '#E8EAF0' },
          muted: { DEFAULT: '#646A73', dark: '#8A919E' },
          bg: { DEFAULT: '#FFFFFF', dark: '#0B0E14' },
          surface: { DEFAULT: '#F7F8FA', dark: '#11151D' },
          card: { DEFAULT: '#FFFFFF', dark: '#161B25' },
          rule: { DEFAULT: '#E5E7EB', dark: '#262D3A' },
        },
      },
      fontFamily: {
        sans: ['-apple-system', 'Segoe UI', 'PingFang SC', 'Microsoft YaHei', 'sans-serif'],
        // V8 衬线展示字族（与 App AppFonts.display 一致）+ mono 追加 CJK 回退。
        display: ['NotoSerifSC', 'Songti SC', 'SimSun', 'serif'],
        mono: ['JetBrains Mono', 'ui-monospace', 'SFMono-Regular', 'Consolas', 'monospace',
          'Microsoft YaHei', 'Noto Sans SC', 'sans-serif'],
      },
      fontSize: {
        'v8-display': ['40px', { lineHeight: '1.2' }],
        'v8-h1': ['28px', { lineHeight: '1.3' }],
        'v8-h2': ['22px', { lineHeight: '1.35' }],
        'v8-h3': ['17px', { lineHeight: '1.4' }],
        'v8-body': ['14px', { lineHeight: '1.6' }],
        'v8-small': ['12.5px', { lineHeight: '1.5' }],
        'v8-caption': ['11px', { lineHeight: '1.4' }],
      },
      spacing: {
        'v8-1': '4px', 'v8-2': '8px', 'v8-3': '12px', 'v8-4': '16px',
        'v8-5': '24px', 'v8-6': '32px', 'v8-7': '48px', 'v8-8': '64px',
      },
      borderRadius: {
        'v8-chip': '2px', 'v8-control': '4px', 'v8-frame': '8px',
        ss: '10px', sslg: '16px',
      },
      boxShadow: {
        'v8-paper': 'var(--shadow-paper)',
        'v8-overlay': 'var(--shadow-overlay)',
        ss: '0 10px 30px rgba(77, 107, 254, 0.10)',
        sslg: '0 20px 60px rgba(11, 14, 20, 0.18)',
      },
      transitionDuration: {
        'v8-fast': '160ms', 'v8-normal': '280ms', 'v8-slow': '420ms',
      },
    },
  },
  plugins: [],
};
