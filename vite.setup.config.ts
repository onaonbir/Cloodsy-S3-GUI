import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

// The Windows setup's window (installer/setup): its own page in src-setup/,
// the GUI's look (tokens, fonts, brand mark from src/ and assets/).
export default defineConfig({
  root: 'src-setup',
  plugins: [vue()],
  clearScreen: false,
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: { port: 1441, strictPort: true, fs: { allow: ['..'] } },
  build: { target: ['es2022', 'chrome110'], outDir: '../dist-setup', emptyOutDir: true, sourcemap: false },
});
