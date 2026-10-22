import { describe, expect, it } from "vitest";
import { createRateLimiter } from "./rate-limit";

describe("createRateLimiter", () => {
  it("allows up to the limit per key within a window, then refuses", () => {
    const allow = createRateLimiter(2, 1000);

    expect([allow("a", 0), allow("a", 10), allow("a", 20)]).toEqual([true, true, false]);
    expect(allow("b", 20)).toBe(true);
  });

  it("starts a new window once the old one ends", () => {
    const allow = createRateLimiter(1, 1000);
    allow("a", 0);

    expect(allow("a", 500)).toBe(false);
    expect(allow("a", 1000)).toBe(true);
  });
});
