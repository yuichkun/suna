/// <reference types="vite/client" />
/// <reference types="vue/ref-macros" />

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<{}, {}, any>
  export default component
}

interface ImportMetaEnv {
  readonly VITE_RUNTIME: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
