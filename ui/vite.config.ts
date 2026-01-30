/// <reference types="vitest" />
import { defineConfig, Plugin, ViteDevServer } from 'vite'
import vue from '@vitejs/plugin-vue'
import { viteSingleFile } from 'vite-plugin-singlefile'

const isWeb = process.env.VITE_RUNTIME === 'web'

function watchPublicPlugin(): Plugin {
  return {
    name: 'watch-public',
    configureServer(server: ViteDevServer) {
      const publicDir = server.config.publicDir
      server.watcher.add(publicDir)
      server.watcher.on('all', (_event: string, filePath: string) => {
        if (filePath.startsWith(publicDir)) {
          server.ws.send({ type: 'full-reload' })
        }
      })
    },
  }
}

export default defineConfig({
  plugins: [
    vue(),
    watchPublicPlugin(),
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
