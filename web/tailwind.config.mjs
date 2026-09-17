/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'media',
  content: ['./src/**/*.{astro,html,js,ts,md}'],
  theme: {
    extend: {
      colors: {
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
        mono: ['ui-monospace', 'SFMono-Regular', 'Consolas', 'monospace'],
      },
      borderRadius: { ss: '10px', sslg: '16px' },
      boxShadow: {
        ss: '0 10px 30px rgba(77, 107, 254, 0.10)',
        sslg: '0 20px 60px rgba(11, 14, 20, 0.18)',
      },
    },
  },
  plugins: [],
};
