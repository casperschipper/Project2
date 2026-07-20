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

export type HierarchyElem = "Ins" | "Per" | "Dyn" | "Ent" | "Dur";

export const HIERARCHY_ELEMS: HierarchyElem[] = ["Ins", "Per", "Dyn", "Ent", "Dur"];

export const HIERARCHY_LABELS: Record<HierarchyElem, string> = {
  Ins: "Instrument",
  Per: "Performance",
  Dyn: "Dynamics",
  Ent: "Entry delay",
  Dur: "Duration",
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

export type Pitch = { register: number; pitch: number };

export type Instrument = {
  name: string;
  chordSizeMin: number;
  chordSizeMax: number;
  /** Must all be members of the master performance list. */
  performance: string[];
  /** Must all be members of the master dynamics list. */
  dynamics: string[];
  compassLow: Pitch;
  compassHigh: Pitch;
  durationMin: string;
  durationMax: string;
};

/** Rows are groups; cells are 0-based indices into the parameter's own list. */
export type Table = number[][];

/** The five parameters that carry a principles block. */
export type ParamId = "instrument" | "entrydelay" | "performance" | "dynamics" | "duration";

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

  // --- instruments ----------------------------------------------------
  numberOfInstrumentGroups: number;
  instruments: Instrument[];
  instrumentTable: Table;
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
  /** Set when the engine could not be started or produced unparseable output. */
  engineError?: string;
};
