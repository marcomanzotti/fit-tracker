import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
      // Tests run outside React Server Components; use the package's own no-op.
      "server-only": fileURLToPath(new URL("./node_modules/server-only/empty.js", import.meta.url)),
    },
  },
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
    // Booting a fresh PGlite (WebAssembly Postgres) takes several seconds on CI
    // runners, more with coverage on.
    testTimeout: 30_000,
    hookTimeout: 30_000,
    coverage: {
      include: ["src/**/*.ts"],
      exclude: ["src/**/*.test.ts"],
      thresholds: { lines: 80, statements: 80 },
    },
  },
});
