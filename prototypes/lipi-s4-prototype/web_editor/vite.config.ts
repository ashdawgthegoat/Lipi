import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: '../assets/web',
    emptyOutDir: true,
  },
  define: {
    'process.env.IS_PREACT': JSON.stringify('true'),
  },
});
