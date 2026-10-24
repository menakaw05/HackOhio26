import { defineConfig } from 'vite';

// Forward /api to your backend so the browser never sees the Azure key
// and you avoid CORS during development. Not 5000: macOS AirPlay Receiver owns it.
export default defineConfig({
  server: {
    proxy: {
      '/api': 'http://localhost:5250',
    },
  },
});
