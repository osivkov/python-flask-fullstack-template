import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

// Preserve the browser's Host so Flask can validate same-origin POST requests.
const backendProxy = { target: "http://backend:8000", changeOrigin: false };

export default defineConfig({
  plugins: [react()],
  cacheDir: "/tmp/vite-cache",
  server: {
    proxy: {
      "/api": backendProxy,
      "/healthz": backendProxy,
      "/readyz": backendProxy,
    },
  },
  test: {
    fsModuleCachePath: "/tmp/vitest-modules",
    environment: "jsdom",
    clearMocks: true,
  },
});
