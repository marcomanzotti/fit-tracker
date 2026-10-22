// Renders a constant list as SQL string literals for CHECK constraints, e.g.
// ["a", "b"] -> 'a', 'b'. Only used with compile-time constants, never user input.
export function inList(values: readonly string[]): string {
  return values.map((value) => `'${value.replaceAll("'", "''")}'`).join(", ");
}
