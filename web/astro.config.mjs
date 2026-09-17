import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';

// 官网：静态站部署 GitHub Pages；模板/公告 JSON 由 CI 发版时更新（内容包通道）。
export default defineConfig({
  site: 'https://shoot-studio.github.io',
  integrations: [tailwind()],
  outDir: './dist',
  trailingSlash: 'ignore',
});
