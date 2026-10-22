import type { NextConfig } from "next";

const SECURITY_HEADERS = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
];

const nextConfig: NextConfig = {
  // Self-contained server bundle for the Docker image (deploy/, phase F6).
  output: "standalone",
  // PGlite ships WebAssembly and data files that must load from node_modules.
  serverExternalPackages: ["@electric-sql/pglite"],
  // The SQL migrations are read from disk at startup (src/db/client.ts).
  outputFileTracingIncludes: { "/**": ["./drizzle/**"] },
  poweredByHeader: false,
  cacheComponents: true,
  partialPrefetching: true,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
  async headers() {
    return [
      { source: "/:path*", headers: SECURITY_HEADERS },
      // API answers carry health data and auth tokens: never store them in a cache.
      { source: "/api/:path*", headers: [{ key: "Cache-Control", value: "no-store" }] },
    ];
  },
};

export default nextConfig;
