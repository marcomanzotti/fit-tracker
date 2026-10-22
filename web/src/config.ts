// Product identity in one place: the name is provisional and changes only here
// (plus android/app/src/main/res/values/strings.xml once the app exists).
export const APP = {
  name: "FitTracker",
  description: "Allenamento, recupero e nutrizione seguiti dal tuo studio.",
  defaultLocale: "it",
} as const;

// Version of the privacy notice and consent texts the user is shown. Bump it when
// the texts change: consents given on an older version are asked again.
export const PRIVACY_POLICY_VERSION = "2026-10-22-draft";

export const INVITATION_TTL_DAYS = 7;
