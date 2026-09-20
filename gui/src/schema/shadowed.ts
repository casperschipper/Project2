import type { HierarchyElem, Project } from "./types";

/**
 * Under "duration = entry delay" the two parameters are one value, so only the
 * one resolved first (higher in the hierarchy) is actually drawn; the other
 * just copies it. That later parameter's own list, table, ensemble and order
 * principle never take part. This is communication only - nothing is removed
 * or blocked, so switching the relation back restores everything as it was.
 *
 * Returns null when the relation is not "equals-entry".
 */
export function shadowedByEquality(
  p: Project,
): { ignored: Extract<HierarchyElem, "Ent" | "Dur">; leading: Extract<HierarchyElem, "Ent" | "Dur"> } | null {
  if (p.durationRelation.kind !== "equals-entry") return null;
  const ent = p.hierarchy.indexOf("Ent");
  const dur = p.hierarchy.indexOf("Dur");
  if (ent < 0 || dur < 0) return null;
  return ent < dur ? { ignored: "Dur", leading: "Ent" } : { ignored: "Ent", leading: "Dur" };
}

const NAME = { Ent: "entry delay", Dur: "duration" } as const;

/** The one-line explanation shown on the ignored parameter's own screen. */
export function shadowNotice(ignored: "Ent" | "Dur", leading: "Ent" | "Dur"): string {
  return (
    `Not used at the moment: the duration relation is "equal to the entry delay", and ${NAME[leading]} ` +
    `comes earlier in the hierarchy, so ${NAME[ignored]} simply copies it. Anything entered on this ` +
    `screen is kept, but takes no part until the relation or the hierarchy order changes.`
  );
}

/** Short hierarchy-row note for either side of the pair. */
export function shadowHierarchyNote(elem: HierarchyElem, s: NonNullable<ReturnType<typeof shadowedByEquality>>): string | null {
  if (elem === s.ignored) return `not used — copies the ${NAME[s.leading]} (duration = entry delay)`;
  if (elem === s.leading) return `also sets the ${NAME[s.ignored]} (duration = entry delay)`;
  return null;
}
