import { twoFactorClient } from "better-auth/client/plugins";
import { createAuthClient } from "better-auth/react";

// Better Auth in the browser: sign-up, sign-in, 2FA, sign-out. Same origin, so
// no base URL is needed.
export const authClient = createAuthClient({ plugins: [twoFactorClient()] });
