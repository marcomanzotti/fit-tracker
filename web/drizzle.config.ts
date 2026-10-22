import { defineConfig } from "drizzle-kit";

// Only used to generate SQL migrations (`npm run db:generate`); the app applies
// them itself on startup (src/server/runtime.ts).
export default defineConfig({
  dialect: "postgresql",
  schema: "./src/db/schema/index.ts",
  out: "./drizzle",
});
