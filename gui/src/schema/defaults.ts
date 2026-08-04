import type { Instrument, Project } from "./types";

/**
 * The starting project mirrors the engine's own `formula.sexp`, so a fresh
 * window opens on something that actually generates a score rather than on an
 * empty form that reports a dozen errors before the composer has done
 * anything.
 */

function instrument(
  name: string,
  chordSizeMin: number,
  chordSizeMax: number,
  performance: string[],
  dynamics: string[],
  percussion = false,
): Instrument {
  return {
    name,
    chordSizeMin,
    chordSizeMax,
    performance,
    dynamics,
    pitchRange: percussion
      ? { kind: "percussion" }
      : { kind: "pitch", low: { octave: 1, pitch: 1 }, high: { octave: 5, pitch: 12 } },
    durationMin: "0.1",
    durationMax: "4.0",
  };
}

export function defaultProject(): Project {
  return {
    formatVersion: 1,

    seed: 3,
    variantDuration: "30.0",
    numberOfVariants: 1,
    octaveDivision: 12,
    hierarchy: ["Ins", "Reg", "Har", "Per", "Dyn", "Ent", "Dur"],
    union: "none",
    density: {
      kind: "autonomous",
      low: 1,
      high: 2,
      principle: {
        kind: "group",
        element: "series",
        repetition: "series",
        minRepetitions: 1,
        maxRepetitions: 4,
      },
    },
    durationRelation: { kind: "independent", mode: "per-note" },
    startIndex: 0,
    comment: "",
    outputDir: null,

    numberOfInstrumentGroups: 2,
    instruments: [
      instrument("guitar1", 6, 6, ["normal", "muted", "overtone1"], ["p", "mf", "f", "ppp"]),
      instrument("guitar2", 1, 6, ["normal", "muted", "overtone1"], ["p", "mf", "f", "ff"]),
      instrument("piano", 1, 10, ["normal", "pizzicato"], [
        "ppp",
        "pp",
        "p",
        "mf",
        "f",
        "ff",
        "fff",
      ]),
      instrument(
        "basedrum",
        1,
        1,
        ["normal", "bowing"],
        ["ppp", "pp", "p", "mf", "f", "ff", "fff"],
        true,
      ),
      instrument("marimba", 1, 4, ["normal", "bowing"], ["mf", "f", "ff", "fff"]),
    ],
    instrumentTable: [
      [0, 1, 2, 3],
      [0],
      [2, 3],
    ],
    instrumentGroupNames: ["", "", ""],
    instrumentEnsemble: { kind: "series" },
    instrumentPrinciple: { kind: "series" },

    entrydelays: ["0.1", "0.2", "0.3", "0.4", "0.5", "0.6", "0.7", "0.8"],
    entrydelayTable: [
      [0, 1, 2],
      [3, 4, 5],
      [0, 1, 2, 3, 4, 5, 6, 7],
    ],
    entrydelayEnsemble: { kind: "series" },
    entrydelayPrinciple: {
      kind: "ratio",
      pairs: [
        { index: 0, weight: 1 },
        { index: 1, weight: 3 },
        { index: 2, weight: 1 },
        { index: 3, weight: 5 },
        { index: 4, weight: 2 },
        { index: 5, weight: 1 },
        { index: 6, weight: 1 },
        { index: 7, weight: 10 },
      ],
    },

    durations: ["0.1", "0.2", "0.3", "0.5", "0.8", "5.0"],
    durationTable: [
      [0, 1, 2, 3, 4],
      [2, 3, 4],
      [0, 1, 2],
    ],
    durationEnsemble: { kind: "series" },
    durationPrinciple: { kind: "series" },

    dynamics: ["ppp", "pp", "p", "mf", "f", "ff", "fff"],
    dynamicsTable: [
      [0, 1, 2, 3, 4, 5, 6],
      [2, 3, 4],
      [0, 6],
    ],
    dynamicsEnsemble: { kind: "series" },
    dynamicsPrinciple: { kind: "series" },
    dynamicsMode: "per-chord",

    performance: ["normal", "muted", "overtone1", "pizzicato", "bowing"],
    performanceTable: [
      [0, 1, 2, 3, 4],
      [0, 1, 2],
      [0],
    ],
    performanceEnsemble: { kind: "sequence", values: [2] },
    performancePrinciple: { kind: "alea" },
    performanceMode: "per-note",

    registers: [
      { kind: "percussion" },
      { kind: "pitch", low: { octave: 1, pitch: 1 }, high: { octave: 3, pitch: 12 } },
      { kind: "pitch", low: { octave: 3, pitch: 1 }, high: { octave: 5, pitch: 12 } },
    ],
    registerTable: [
      [0, 1, 2],
      [1, 2],
      [0, 2],
    ],
    registerEnsemble: { kind: "series" },
    registerPrinciple: { kind: "series" },
    registerMode: "per-chord",

    restMode: { kind: "off" },
    rests: ["0.5", "1.0"],
    restTable: [[0, 1]],
    restEnsemble: { kind: "alea" },
    restPrinciple: { kind: "alea" },

    harmonyPrinciple: "row",
    row: ["1", "2", "3", "p", "5", "7", "9", "11", "12", "4", "6", "8", "10"],
    transposition: "none",
    intervalMatrixSource: { kind: "matrix", rows: emptyIntervalMatrix(12) },
    forbiddenTones: [],
    chords: [["1", "3", "5"]],
    chordOrder: { kind: "series" },
    chordTransposition: "none",
  };
}

/** An all-forbidden `(tr-1) x (tr-1)` matrix - the starting point before the
 * composer switches to the INTERVAL principle and toggles any cells on. */
export function emptyIntervalMatrix(octaveDivision: number): boolean[][] {
  const size = Math.max(octaveDivision - 1, 0);
  return Array.from({ length: size }, () => Array(size).fill(false) as boolean[]);
}

/**
 * Resizes the matrix to match a new `octaveDivision`, preserving every cell
 * that still fits and padding new rows/columns with `false`. Unlike the
 * other `octaveDivision`-dependent lists in this app (which just flag a size
 * mismatch as a diagnostic and leave the composer to fix it by hand), the
 * matrix auto-resizes - there's no per-cell "this row doesn't exist"
 * affordance the way an out-of-range token in a list can be flagged one at a
 * time. See `intervalMatrixWouldLoseData` for the accompanying
 * shrink-confirmation check.
 */
export function resizeIntervalMatrix(rows: boolean[][], newOctaveDivision: number): boolean[][] {
  const size = Math.max(newOctaveDivision - 1, 0);
  return Array.from({ length: size }, (_, i) =>
    Array.from({ length: size }, (_, j) => rows[i]?.[j] ?? false),
  );
}

/** True iff shrinking to `newOctaveDivision` would silently discard an
 * already-`true` cell - used to gate a confirmation prompt before the shrink
 * is applied. */
export function intervalMatrixWouldLoseData(rows: boolean[][], newOctaveDivision: number): boolean {
  const size = Math.max(newOctaveDivision - 1, 0);
  return rows.some((row, i) => row.some((cell, j) => cell && (i >= size || j >= size)));
}

/**
 * Derives an interval matrix from a chord's own interval content (CHORD-INT,
 * EMR-3 8.2 example 8-6) - a direct port of `Parameters.matrix_of_chord`
 * (`pr26/lib/parameters.ml`), kept for the GUI's live preview while a chord
 * is being edited. The two implementations must never quietly diverge - see
 * the cross-check against the manual's own worked example in
 * `scripts/check-emitter.ts`'s sibling checks.
 *
 * Walks the chord as a cycle of tones in both directions; within each
 * direction, every consecutive pair of intervals (cyclically) becomes an
 * allowed transition. Returns `null` if the chord is empty, contains an
 * out-of-range tone, or repeats a tone between two neighbours (including the
 * wraparound) - the same cases `validate.ts` already flags as errors.
 */
export function deriveIntervalMatrixFromChord(
  chordRaw: string[],
  octaveDivision: number,
): boolean[][] | null {
  const tr = octaveDivision;
  const n = chordRaw.length;
  if (n === 0 || tr < 2) return null;

  const chord = chordRaw.map(Number);
  if (chord.some((v) => !Number.isInteger(v) || v < 1 || v > tr)) return null;

  const stepAt = (k: number) => chord[((k % n) + n) % n];
  for (let i = 0; i < n; i += 1) {
    if (stepAt(i) === stepAt(i + 1)) return null;
  }

  const interval = (a: number, b: number) => (((b - a) % tr) + tr) % tr;
  const size = tr - 1;
  const matrix: boolean[][] = Array.from({ length: size }, () => Array(size).fill(false));

  const traversal = (dir: 1 | -1) =>
    Array.from({ length: n }, (_, k) => interval(stepAt(k * dir), stepAt((k + 1) * dir)));
  const mark = (seq: number[]) => {
    seq.forEach((given, i) => {
      const succ = seq[(i + 1) % n];
      matrix[given - 1][succ - 1] = true;
    });
  };
  mark(traversal(1));
  mark(traversal(-1));
  return matrix;
}

/**
 * The matrix a project's INTERVAL principle actually uses at run time -
 * whichever `intervalMatrixSource` resolves to. Inverting is a one-shot
 * action on the matrix's own cells (see the "Invert" button in
 * `HarmonyScreen.tsx`), not a modifier applied here, so this is just the
 * plain resolution: the hand-toggled rows verbatim, or the chord-derived
 * preview. The single source of truth consumed by the live preview, the
 * graph view, and the dead-end-row warning in `validate.ts`. Returns `null`
 * when there's nothing valid to show (an empty or invalid chord).
 */
export function effectiveIntervalMatrix(project: {
  intervalMatrixSource: Project["intervalMatrixSource"];
  octaveDivision: number;
}): boolean[][] | null {
  return project.intervalMatrixSource.kind === "matrix"
    ? project.intervalMatrixSource.rows
    : deriveIntervalMatrixFromChord(project.intervalMatrixSource.chord, project.octaveDivision);
}

/**
 * The master performance list is derived, never typed.
 *
 * The engine's README argues for this: if the list of modes is built from the
 * instrument definitions, the two cannot contradict each other and the
 * composer has one less place to make a mistake. Order is first-appearance
 * across instruments, which keeps existing table indices stable when a new
 * instrument only adds modes that are already present.
 */
export function derivePerformanceList(instruments: Instrument[]): string[] {
  const seen: string[] = [];
  for (const inst of instruments) {
    for (const mode of inst.performance) {
      if (mode && !seen.includes(mode)) seen.push(mode);
    }
  }
  return seen;
}
