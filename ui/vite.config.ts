/// <reference types="vitest" />
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { viteSingleFile } from 'vite-plugin-singlefile'

const isWeb = process.env.VITE_RUNTIME === 'web'

export default defineConfig({
  plugins: [
    vue(),
    // Single-file mode for JUCE embedding
    ...(!isWeb ? [viteSingleFile()] : [])
  ],
  define: {
    'import.meta.env.VITE_RUNTIME': JSON.stringify(process.env.VITE_RUNTIME || 'juce'),
  },
  base: isWeb ? '/' : './',
  build: {
    outDir: isWeb ? 'dist-web' : 'dist',
    assetsInlineLimit: isWeb ? 4096 : 100000000
  },
  server: {
    port: 5173
  },
  test: {
    environment: 'jsdom'
  }
})
