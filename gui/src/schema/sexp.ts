import type {
  Density,
  DurationRelation,
  Ensemble,
  Instrument,
  Pitch,
  Principle,
  Project,
  Register,
  Table,
} from "./types";

/**
 * Emits the engine's structure formula.
 *
 * The grammar has a few sharp edges this file exists to get right in one
 * place:
 *
 *  - `sequence` is spelled differently depending on slot. As an *order*
 *    principle it wraps its values in an inner list - `(sequence (0 1 2))` -
 *    but as an *ensemble* selector the values are inline - `(sequence 2)`.
 *    Getting this backwards is a parse error, not a silent misread.
 *  - `entrydelays`, `durations`, `performance`, `dynamics` and `hierarchy` are
 *    all double-nested: `(durations (0.1 0.2))`, not `(durations 0.1 0.2)`.
 *  - Instrument-level `(durations min max)` is the *flat* two-float form, and
 *    is a different thing entirely from the top-level duration list.
 *  - Every top-level field is required; the engine has no defaults. Unknown
 *    and duplicate fields are silently ignored, so a typo here fails quietly -
 *    which is why nothing in this file is optional.
 */

const indent = (level: number) => "  ".repeat(level);

function sexpList(head: string, body: string, level = 1): string {
  return `${indent(level)}(${head}${body})`;
}

/** Rows are groups. Written one per line so tables stay readable by hand. */
function emitTable(name: string, table: Table, level = 1): string {
  if (table.length === 0) return `${indent(level)}(${name})`;
  const rows = table.map((row) => `${indent(level + 1)}(${row.join(" ")})`).join("\n");
  return `${indent(level)}(${name}\n${rows})`;
}

function emitPrinciple(p: Principle): string {
  switch (p.kind) {
    case "alea":
      return "alea";
    case "series":
      return "series";
    case "sequence":
      // Order principle: values wrapped in an inner list.
      return `(sequence (${p.values.join(" ")}))`;
    case "ratio": {
      const pairs = p.pairs.map((r) => `(${r.index} ${r.weight})`).join(" ");
      return `(ratio (${pairs}))`;
    }
    case "group":
      return (
        `(group (element ${p.element}) (repetition ${p.repetition}) ` +
        `(repetitions ${p.minRepetitions} ${p.maxRepetitions}))`
      );
    case "tendency": {
      const sections = p.sections
        .map(
          (s) =>
            `(section ${fmt(s.portion)} (start ${fmt(s.startMin)} ${fmt(s.startMax)}) ` +
            `(end ${fmt(s.endMin)} ${fmt(s.endMax)}))`,
        )
        .join(" ");
      return `(tendency ${sections})`;
    }
  }
}

function emitEnsemble(e: Ensemble): string {
  switch (e.kind) {
    case "alea":
      return "alea";
    case "series":
      return "series";
    case "sequence":
      // Ensemble selector: values inline, no inner list.
      return `(sequence ${e.values.join(" ")})`;
    case "combination":
      return "combination";
  }
}

function emitDensity(d: Density): string {
  if (d.kind === "instrument-density") return "  (density instrument-density)";
  return (
    `  (density (autonomous (low ${d.low}) (high ${d.high}) ` +
    `(principle ${emitPrinciple(d.principle)})))`
  );
}

function emitRelation(r: DurationRelation): string {
  switch (r.kind) {
    case "equals-entry":
      // The bare-atom form: no parentheses around it.
      return "equals-entry";
    case "independent":
      return `(independent ${r.mode})`;
    case "shorter-than-entry":
      return `(shorter-than-entry ${r.mode})`;
  }
}

function emitInstrument(i: Instrument): string {
  const compass = i.percussion
    ? "(compass percussion)"
    : `(compass (${i.compassLow.octave} ${pad2(i.compassLow.pitch)}) ` +
      `(${i.compassHigh.octave} ${pad2(i.compassHigh.pitch)}))`;
  return [
    `    (instrument ${i.name || "unnamed"}`,
    `      (chordsize ${i.chordSizeMin} ${i.chordSizeMax})`,
    `      (performance (${i.performance.join(" ")}))`,
    `      (dynamics (${i.dynamics.join(" ")}))`,
    `      ${compass}`,
    `      (durations ${i.durationMin} ${i.durationMax}))`,
  ].join("\n");
}

/** Pitch positions are conventionally two digits in the manual's notation. */
function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

function emitPitch(p: Pitch): string {
  return `(${p.octave} ${pad2(p.pitch)})`;
}

function emitRegister(r: Register): string {
  return r.kind === "percussion" ? "(percussion)" : `(${emitPitch(r.low)} ${emitPitch(r.high)})`;
}

/** Trim trailing zeros but always keep a decimal point, as OCaml expects. */
function fmt(n: number): string {
  return Number.isInteger(n) ? `${n}.0` : String(n);
}

/** Prefix each line of the composer's comment with `;;` so it survives. */
function emitComment(comment: string): string {
  const trimmed = comment.trim();
  if (!trimmed) return "";
  return (
    trimmed
      .split("\n")
      .map((line) => `;; ${line}`)
      .join("\n") + "\n\n"
  );
}

export function toSexp(p: Project): string {
  const parts: string[] = [];

  parts.push(`  (seed ${p.seed})`);
  parts.push(`  (variant-duration ${p.variantDuration})`);
  parts.push(`  (octave-division ${p.octaveDivision})`);
  parts.push("");

  parts.push(`  (dynamics (${p.dynamics.join(" ")}))`);
  parts.push(emitTable("dynamics-table", p.dynamicsTable));
  parts.push("");

  parts.push(`  (performance (${p.performance.join(" ")}))`);
  parts.push(emitTable("performance-table", p.performanceTable));
  parts.push("");

  parts.push(`  (number-of-instrument-groups ${p.numberOfInstrumentGroups})`);
  parts.push(`  (instruments\n${p.instruments.map(emitInstrument).join("\n\n")})`);
  parts.push(emitTable("instrument-table", p.instrumentTable));
  parts.push("");

  parts.push(`  (entrydelays (${p.entrydelays.join(" ")}))`);
  parts.push(emitTable("entrydelay-table", p.entrydelayTable));
  parts.push("");

  parts.push(`  (durations (${p.durations.join(" ")}))`);
  parts.push(emitTable("duration-table", p.durationTable));
  parts.push("");

  parts.push(
    `  (registers (\n` + p.registers.map((r) => `    ${emitRegister(r)}`).join("\n") + `))`,
  );
  parts.push(emitTable("register-table", p.registerTable));
  parts.push("");

  parts.push(
    `  (harmony\n` +
      `    (row (${p.row.join(" ")}))\n` +
      `    (transposition ${p.transposition})\n` +
      `    (mode ${p.harmonyMode}))`,
  );
  parts.push("");

  // The principles block. Note the per-parameter asymmetry: instrument takes
  // no mode and no relation (and may not use `combination`); performance and
  // dynamics require a mode; duration requires a relation instead.
  const principles = [
    sexpList(
      "instrument ",
      `(ensemble ${emitEnsemble(p.instrumentEnsemble)}) (order ${emitPrinciple(
        p.instrumentPrinciple,
      )})`,
      2,
    ),
    sexpList(
      "entrydelay ",
      `(ensemble ${emitEnsemble(p.entrydelayEnsemble)}) (order ${emitPrinciple(
        p.entrydelayPrinciple,
      )})`,
      2,
    ),
    sexpList(
      "performance ",
      `(ensemble ${emitEnsemble(p.performanceEnsemble)}) (order ${emitPrinciple(
        p.performancePrinciple,
      )}) (mode ${p.performanceMode})`,
      2,
    ),
    sexpList(
      "dynamics ",
      `(ensemble ${emitEnsemble(p.dynamicsEnsemble)}) (order ${emitPrinciple(
        p.dynamicsPrinciple,
      )}) (mode ${p.dynamicsMode})`,
      2,
    ),
    sexpList(
      "duration ",
      `(ensemble ${emitEnsemble(p.durationEnsemble)}) (order ${emitPrinciple(
        p.durationPrinciple,
      )}) (relation ${emitRelation(p.durationRelation)})`,
      2,
    ),
    sexpList(
      "register ",
      `(ensemble ${emitEnsemble(p.registerEnsemble)}) (order ${emitPrinciple(
        p.registerPrinciple,
      )}) (mode ${p.registerMode})`,
      2,
    ),
  ].join("\n");
  parts.push(`  (principles\n${principles})`);
  parts.push("");

  parts.push(`  (hierarchy (${p.hierarchy.join(" ")}))`);
  parts.push(`  (union ${p.union})`);
  parts.push(emitDensity(p.density));

  return (
    ";;; structure formula - generated by the Projekt 2 GUI\n" +
    emitComment(p.comment) +
    "(structure-formula\n\n" +
    parts.join("\n") +
    "\n)\n"
  );
}
