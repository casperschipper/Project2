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
    percussion,
    compassLow: { octave: 1, pitch: 1 },
    compassHigh: { octave: 5, pitch: 12 },
    durationMin: "0.1",
    durationMax: "4.0",
  };
}

export function defaultProject(): Project {
  return {
    formatVersion: 1,

    seed: 3,
    variantDuration: "30.0",
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

    row: ["1", "2", "3", "p", "5", "7", "9", "11", "12", "4", "6", "8", "10"],
    transposition: "none",
    harmonyMode: "per-chord",
  };
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
