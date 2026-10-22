import { afterEach, describe, expect, it, vi } from "vitest";
import { sendMail } from "./mail";

const MAIL = { to: "client@example.test", subject: "Conferma", text: "http://localhost:3000/verify" };

afterEach(() => {
  vi.unstubAllEnvs();
  vi.restoreAllMocks();
});

describe("sendMail", () => {
  it("prints the mail to the server console in development", async () => {
    vi.stubEnv("NODE_ENV", "development");
    const info = vi.spyOn(console, "info").mockImplementation(() => undefined);

    await sendMail(MAIL);

    expect(info).toHaveBeenCalledWith(expect.stringContaining("http://localhost:3000/verify"));
  });

  it("refuses to send in production until a provider is wired in", async () => {
    vi.stubEnv("NODE_ENV", "production");

    await expect(sendMail(MAIL)).rejects.toThrow("Mail provider not configured");
  });
});
