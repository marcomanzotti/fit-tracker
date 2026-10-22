// Italian names for the values the server uses, shown on every screen.

export const ROLE_LABEL: Record<string, string> = {
  pt: "personal trainer",
  nutrition: "nutrizionista",
  physio: "fisioterapista",
};

// What each scope lets a professional see, in the words the client reads
// before consenting.
export const SCOPE_LABEL: Record<string, string> = {
  training: "schede e allenamenti",
  nutrition: "alimentazione",
  body: "peso e misure",
  sleep: "sonno",
  vitals: "battito, HRV e parametri vitali",
  notes: "note",
};

export const MUSCLE_LABEL: Record<string, string> = {
  chest: "Petto",
  back: "Schiena",
  legs: "Gambe",
  shoulders: "Spalle",
  arms: "Braccia",
  core: "Core",
  fullbody: "Total body",
  cardio: "Cardio",
  other: "Altro",
};

export function listItalian(values: string[]): string {
  if (values.length <= 1) return values.join("");
  return `${values.slice(0, -1).join(", ")} e ${values.at(-1)}`;
}
