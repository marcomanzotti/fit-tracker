// Where to go after signing in: only paths on this site, never another origin
// ("//evil.example" and "/\evil.example" are protocol-relative tricks).
export function safeNext(value: string | null | undefined, fallback = "/"): string {
  if (!value || !value.startsWith("/") || value.startsWith("//") || value.startsWith("/\\")) return fallback;
  return value;
}
