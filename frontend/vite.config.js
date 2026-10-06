import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Development: the React app runs on :5173 and forwards /api requests to Rails on :3000, so the
// browser only talks to one origin (cookies just work, no CORS setup needed).
// Production: `npm run build` writes the app into backend/public, where Rails serves it.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: { "/api": { target: "http://localhost:3000", changeOrigin: true } },
  },
  build: { outDir: "../backend/public", emptyOutDir: true },
  test: { environment: "jsdom", globals: true },   // globals lets Testing Library clean up between tests
});
