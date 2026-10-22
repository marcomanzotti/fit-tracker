// Comparable form of a free-text name: lower case, no accents, single spaces,
// only letters and digits ("Panca  piana – Bilanciere" -> "panca piana bilanciere").
export function normalizeName(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

export function slugify(value: string): string {
  return normalizeName(value).replaceAll(" ", "-");
}
