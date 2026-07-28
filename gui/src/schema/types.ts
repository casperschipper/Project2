/**
 * The project model.
 *
 * This mirrors the engine's sexp grammar one-to-one, with three deliberate
 * departures:
 *
 *  1. Time values (entry delays, durations) are kept as *strings*, because the
 *     engine accepts literal fractions like `1/2` alongside decimals and the
 *     composer's chosen notation is meaningful. They are parsed for validation
 *     but written back verbatim.
 *
 *  2. Table cells are always stored as 0-based indices, even for the
 *     performance and dynamics tables where the engine would also accept
 *     names. One representation keeps the table editor uniform; the UI
 *     resolves indices to names for display and tooltips.
 *
 *  3. A few fields are GUI-only and are never emitted (`comment`,
 *     `startIndex`). `startIndex` changes how indices are *displayed* only -
 *     what is written to the sexp is always 0-based, since that is what the
 *     engine reads.
 */

export type HierarchyElem = "Ins" | "Per" | "Dyn" | "Ent" | "Dur" | "Reg" | "Har";

export const HIERARCHY_ELEMS: HierarchyElem[] = [
  "Ins",
  "Per",
  "Dyn",
  "Ent",
  "Dur",
  "Reg",
  "Har",
];

export const HIERARCHY_LABELS: Record<HierarchyElem, string> = {
  Ins: "Instrument",
  Per: "Performance",
  Dyn: "Dynamics",
  Ent: "Entry delay",
  Dur: "Duration",
  Reg: "Register",
  Har: "Harmony",
};

export type NoteMode = "per-chord" | "per-note";

/** Selector used for both the `element` and `repetition` slots of a group. */
export type GroupSelector = "alea" | "series";

export type RatioPair = { index: number; weight: number };

export type TendencySection = {
  portion: number;
  startMin: number;
  startMax: number;
  endMin: number;
  endMax: number;
};

/**
 * A selection principle - the `order` slot of a parameter.
 *
 * Note the sexp asymmetry the emitter has to honour: as an *order* principle
 * a sequence is written `(sequence (0 1 2))` with the inner list, but as an
 * *ensemble* selector it is written `(sequence 2)` with the values inline.
 */
export type Principle =
  | { kind: "alea" }
  | { kind: "series" }
  | { kind: "sequence"; values: number[] }
  | { kind: "ratio"; pairs: RatioPair[] }
  | {
      kind: "group";
      element: GroupSelector;
      repetition: GroupSelector;
      minRepetitions: number;
      maxRepetitions: number;
    }
  | { kind: "tendency"; sections: TendencySection[] };

export type PrincipleKind = Principle["kind"];

/** The `ensemble` slot. `combination` is not permitted for instruments. */
export type Ensemble =
  | { kind: "alea" }
  | { kind: "series" }
  | { kind: "sequence"; values: number[] }
  | { kind: "combination" };

export type EnsembleKind = Ensemble["kind"];

export type DurationRelation =
  | { kind: "independent"; mode: NoteMode }
  | { kind: "equals-entry" }
  | { kind: "shorter-than-entry"; mode: NoteMode };

export type Density =
  | { kind: "instrument-density" }
  | { kind: "autonomous"; low: number; high: number; principle: Principle };

/** An absolute pitch: an octave digit (1-9) plus a relative pitch/step within it. */
export type Pitch = { octave: number; pitch: number };

/**
 * A range between two absolute pitches, or an explicit percussion entry -
 * never PR-2's (0,0) sentinel. The same shape appears in two places in the
 * sexp (the `(pitch-range ...)` grammar): an instrument's own range, and
 * each entry of REGISTER's own list.
 */
export type PitchRange = { kind: "percussion" } | { kind: "pitch"; low: Pitch; high: Pitch };

export type Instrument = {
  name: string;
  chordSizeMin: number;
  chordSizeMax: number;
  /** Must all be members of the master performance list. */
  performance: string[];
  /** Must all be members of the master dynamics list. */
  dynamics: string[];
  /** A percussion instrument has no pitch range at all. */
  pitchRange: PitchRange;
  durationMin: string;
  durationMax: string;
};

/** REGISTER (EMR-3 7.1): structurally the same as an instrument's own pitch range. */
export type Register = PitchRange;

/** TRANSP-ROW (EMR-3 8.2, entry 20): how the row is transposed once exhausted. */
export type Transposition = "none" | "alea" | "series" | "chromatic" | "serial";

/** Display string for one register entry, e.g. in the table/principle editors. */
export function registerLabel(r: Register): string {
  if (r.kind === "percussion") return "percussion";
  return `${r.low.octave}.${String(r.low.pitch).padStart(2, "0")}–${r.high.octave}.${String(
    r.high.pitch,
  ).padStart(2, "0")}`;
}

/** Rows are groups; cells are 0-based indices into the parameter's own list. */
export type Table = number[][];

/** The six parameters that carry a principles block. */
export type ParamId =
  | "instrument"
  | "entrydelay"
  | "performance"
  | "dynamics"
  | "duration"
  | "register";

export type Project = {
  formatVersion: 1;

  // --- structure ------------------------------------------------------
  seed: number;
  variantDuration: string;
  octaveDivision: number;
  hierarchy: HierarchyElem[];
  union: "none" | "union";
  density: Density;
  durationRelation: DurationRelation;
  /** GUI-only: display indices as 0- or 1-based. Emission is always 0-based. */
  startIndex: 0 | 1;
  /** GUI-only: the composer's own notes about this formula. */
  comment: string;
  /** GUI-only: where an explicit Run persists score/entries/MIDI output.
   * Chosen once (via a folder picker) and remembered from then on. */
  outputDir: string | null;

  // --- instruments ----------------------------------------------------
  numberOfInstrumentGroups: number;
  instruments: Instrument[];
  instrumentTable: Table;
  /** GUI-only: one label per instrumentTable row, shown wherever that row's group is referenced elsewhere. Never emitted. */
  instrumentGroupNames: string[];
  instrumentEnsemble: Ensemble;
  instrumentPrinciple: Principle;

  // --- entry delay ----------------------------------------------------
  entrydelays: string[];
  entrydelayTable: Table;
  entrydelayEnsemble: Ensemble;
  entrydelayPrinciple: Principle;

  // --- duration -------------------------------------------------------
  durations: string[];
  durationTable: Table;
  durationEnsemble: Ensemble;
  durationPrinciple: Principle;

  // --- dynamics -------------------------------------------------------
  dynamics: string[];
  dynamicsTable: Table;
  dynamicsEnsemble: Ensemble;
  dynamicsPrinciple: Principle;
  dynamicsMode: NoteMode;

  // --- performance ----------------------------------------------------
  /**
   * The master list of performance modes.
   *
   * The engine's README notes the intent that this be *derived* from the
   * instrument definitions rather than typed by hand, so that the two can
   * never disagree. The GUI follows that: this list is maintained
   * automatically as the union of every instrument's modes (see
   * `derivePerformanceList`), and is shown read-only.
   */
  performance: string[];
  performanceTable: Table;
  performanceEnsemble: Ensemble;
  performancePrinciple: Principle;
  performanceMode: NoteMode;

  // --- register ---------------------------------------------------------
  registers: Register[];
  registerTable: Table;
  registerEnsemble: Ensemble;
  registerPrinciple: Principle;
  registerMode: NoteMode;

  // --- harmony (ROW only - see harmony.md) -------------------------------
  /**
   * Each entry is either a relative pitch (1..octaveDivision, as a decimal
   * string like the other time-value lists) or the literal token "p",
   * marking an explicit percussion event - never a magic 0.
   */
  row: string[];
  transposition: Transposition;
  harmonyMode: NoteMode;
};

// ---------------------------------------------------------------------
// Diagnostics
// ---------------------------------------------------------------------

/**
 * One diagnostic. This is exactly the shape the engine emits with `--json`;
 * the GUI's own client-side checks produce the same shape so that both
 * sources can be routed, displayed and explained by identical code.
 */
export type Segment = { key: string } | { index: number };

export type Diagnostic = {
  /** Stable kebab-case id; also the filename of its explanatory markdown. */
  id: string;
  severity: "error" | "warning";
  /** Flat dotted path, e.g. `instrument[2].performance`. */
  path: string;
  location: Segment[];
  message: string;
  data?: Record<string, unknown>;
  /** Set for GUI-produced diagnostics that the engine cannot yet report. */
  fromGui?: boolean;
};

export type EngineResult = {
  ok: boolean;
  errors: Diagnostic[];
  warnings: Diagnostic[];
  log?: string;
  score?: string;
  entries?: string;
  /** Set only for an explicit (persisted) Run - the `.mid` files produced. */
  midiFiles?: string[];
  /** Set when the engine could not be started or produced unparseable output. */
  engineError?: string;
};
