import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // Fixed port so agents and CI always know where the app lives.
  server: { port: 5173, strictPort: true },
})
