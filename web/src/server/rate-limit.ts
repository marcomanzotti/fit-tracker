// Fixed-window counter per key, in memory. The app is one process on one VPS, so
// a process-local map is enough; counters reset on restart, which is acceptable.
type Window = { count: number; resetAt: number };

const MAX_KEYS = 10_000;

export function createRateLimiter(limit: number, windowMs: number) {
  const windows = new Map<string, Window>();

  function prune(now: number): void {
    for (const [key, window] of windows) if (window.resetAt <= now) windows.delete(key);
  }

  // True when the call is allowed, false when the key is over its limit.
  return function allow(key: string, now = Date.now()): boolean {
    if (windows.size > MAX_KEYS) prune(now);
    const current = windows.get(key);
    if (!current || current.resetAt <= now) {
      windows.set(key, { count: 1, resetAt: now + windowMs });
      return true;
    }
    current.count += 1;
    return current.count <= limit;
  };
}
