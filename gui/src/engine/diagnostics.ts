import type { Diagnostic } from "../schema/types";

/**
 * Routing diagnostics to the place the composer can act on them.
 *
 * Both the engine and the GUI validator emit the same dotted-path vocabulary
 * (`instrument[2].chordsize`, `duration.table.row[3]`), so one routing table
 * serves both. A field claims a diagnostic when the diagnostic's path is the
 * field's path or sits beneath it, which lets a table claim every cell error
 * inside it while a cell still claims only its own.
 */

export type ScreenId =
  | "structure"
  | "instruments"
  | "entrydelay"
  | "duration"
  | "dynamics"
  | "performance"
  | "register"
  | "rest"
  | "harmony"
  | "output";

export const SCREENS: { id: ScreenId; label: string }[] = [
  { id: "structure", label: "Structure" },
  { id: "instruments", label: "Instruments" },
  { id: "entrydelay", label: "Entry delay" },
  { id: "duration", label: "Duration" },
  { id: "dynamics", label: "Dynamics" },
  { id: "performance", label: "Performance" },
  { id: "register", label: "Register" },
  { id: "rest", label: "Rest" },
  { id: "harmony", label: "Harmony" },
  { id: "output", label: "Output" },
];

/**
 * Which screen owns a diagnostic.
 *
 * Mostly the first path segment decides, with two deliberate exceptions:
 * the duration *relation* and the density both describe how the whole
 * structure is put together rather than the duration supply, so they live on
 * the structure screen alongside the hierarchy they interact with.
 */
export function screenOf(d: Diagnostic): ScreenId {
  const path = d.path;
  const head = path.split(/[.[]/)[0];

  if (path.startsWith("duration.relation")) return "structure";
  // REST's own mode + entry-range live on the Structure screen, alongside
  // union/hierarchy (see StructureScreen.tsx) - only its list/table/
  // ensemble/order belong to the Rest screen itself.
  if (path.startsWith("rest.rest-mode")) return "structure";

  switch (head) {
    case "global":
    case "seed":
    case "variant-duration":
    case "hierarchy":
    case "union":
    case "density":
      return "structure";
    case "instrument":
      return "instruments";
    case "entrydelay":
      return "entrydelay";
    case "duration":
      return "duration";
    case "dynamics":
      return "dynamics";
    case "performance":
      return "performance";
    case "register":
      return "register";
    case "rest":
      return "rest";
    case "harmony":
      return "harmony";
    default:
      return "structure";
  }
}

/** Does `path` sit at or beneath `fieldPath`? */
export function pathMatches(fieldPath: string, path: string): boolean {
  return (
    path === fieldPath || path.startsWith(`${fieldPath}.`) || path.startsWith(`${fieldPath}[`)
  );
}

export function diagnosticsFor(all: Diagnostic[], fieldPath: string): Diagnostic[] {
  return all.filter((d) => pathMatches(fieldPath, d.path));
}

export function countsByScreen(all: Diagnostic[]): Record<ScreenId, { errors: number; warnings: number }> {
  const empty = () => ({ errors: 0, warnings: 0 });
  const counts: Record<string, { errors: number; warnings: number }> = {};
  for (const { id } of SCREENS) counts[id] = empty();
  for (const d of all) {
    const screen = screenOf(d);
    if (d.severity === "error") counts[screen].errors += 1;
    else counts[screen].warnings += 1;
  }
  return counts as Record<ScreenId, { errors: number; warnings: number }>;
}

/**
 * The engine reports a combination row mismatch three times - once against
 * each of the three fields involved - so that every one of them can be
 * highlighted. That is right for field markers but wrong for a list, where it
 * reads as three separate problems.
 */
export function dedupeForDisplay(diags: Diagnostic[]): Diagnostic[] {
  const seen = new Set<string>();
  return diags.filter((d) => {
    const signature = `${d.id}|${d.message}`;
    if (seen.has(signature)) return false;
    seen.add(signature);
    return true;
  });
}
