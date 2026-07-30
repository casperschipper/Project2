import type {
  Diagnostic,
  Ensemble,
  Principle,
  Project,
  Segment,
  Table,
} from "./types";
import { HIERARCHY_ELEMS, HIERARCHY_LABELS } from "./types";
import { effectiveIntervalMatrix } from "./defaults";

/**
 * Client-side validation.
 *
 * This runs on every edit, without waiting for the engine, and exists for two
 * reasons beyond speed:
 *
 *  1. It can be *more precise* than the engine. The engine reports a bad table
 *     index as a whole-formula failure (it raises during generation); here we
 *     can point at the individual cell, which is what makes the table editor's
 *     per-cell feedback possible.
 *
 *  2. It catches inconsistencies the engine does not check at all - a table
 *     index past the end of its list, a tendency value outside [0,1], more
 *     instrument groups than the table has rows. Left to the engine these are
 *     uncaught exceptions or silent misbehaviour.
 *
 * Diagnostics use the same shape and the same path vocabulary as the engine's,
 * so both flow through identical routing and explanation code. `fromGui`
 * marks them only so the UI can note where a message came from.
 */

function diag(
  id: string,
  severity: "error" | "warning",
  location: Segment[],
  message: string,
  data?: Record<string, unknown>,
): Diagnostic {
  return { id, severity, location, path: pathOf(location), message, data, fromGui: true };
}

/** Mirrors the engine's `location_to_string`: dots between keys, `[n]` inline. */
export function pathOf(location: Segment[]): string {
  return location
    .map((seg, i) =>
      "index" in seg ? `[${seg.index}]` : `${i === 0 ? "" : "."}${seg.key}`,
    )
    .join("");
}

const key = (k: string): Segment => ({ key: k });
const idx = (i: number): Segment => ({ index: i });

/**
 * Parse a time value. The engine accepts decimals and literal fractions
 * (`1/2`), so both are valid here; anything else is a typo worth reporting
 * before the engine sees it.
 */
export function parseTimeValue(s: string): number | null {
  const t = s.trim();
  if (t === "") return null;
  const fraction = /^(\d+(?:\.\d+)?)\s*\/\s*(\d+(?:\.\d+)?)$/.exec(t);
  if (fraction) {
    const den = Number(fraction[2]);
    return den === 0 ? null : Number(fraction[1]) / den;
  }
  return /^-?\d*\.?\d+$/.test(t) ? Number(t) : null;
}

/** The list a given table indexes into, and where its cells' errors belong. */
type TableSpec = {
  paramKey: string;
  table: Table;
  listLength: number;
  /** Human name of the list, for the message. */
  listName: string;
};

function checkTable(spec: TableSpec, out: Diagnostic[]) {
  const base = [key(spec.paramKey), key("table")];

  if (spec.table.length === 0) {
    out.push(
      diag("empty-table", "error", base, `the ${spec.listName} table has no groups; add at least one row`),
    );
    return;
  }

  spec.table.forEach((row, r) => {
    const rowLoc = [...base, key("row"), idx(r)];

    if (row.length === 0) {
      out.push(
        diag(
          "empty-table-row",
          "error",
          rowLoc,
          `group ${r + 1} is empty; a group with no elements can never produce a value`,
        ),
      );
      return;
    }

    row.forEach((cell, c) => {
      if (!Number.isInteger(cell) || cell < 0 || cell >= spec.listLength) {
        out.push(
          diag(
            "index-out-of-range",
            "error",
            [...rowLoc, key("cell"), idx(c)],
            spec.listLength === 0
              ? `index ${cell} points into an empty ${spec.listName} list`
              : `index ${cell} does not exist - the ${spec.listName} list has ` +
                `${spec.listLength} element${spec.listLength === 1 ? "" : "s"} ` +
                `(valid indices are 0 to ${spec.listLength - 1})`,
            { index: cell, listLength: spec.listLength },
          ),
        );
      }
    });

    const duplicates = row.filter((v, i) => row.indexOf(v) !== i);
    if (duplicates.length > 0) {
      out.push(
        diag(
          "duplicate-index-in-group",
          "warning",
          rowLoc,
          `group ${r + 1} repeats index ${[...new Set(duplicates)].join(", ")}; ` +
            `a repeated index weights that element more heavily under some principles`,
          { duplicates: [...new Set(duplicates)] },
        ),
      );
    }
  });
}

/** Principles that index into a list must stay inside it. */
function checkPrinciple(
  paramKey: string,
  principle: Principle,
  listLength: number,
  out: Diagnostic[],
) {
  const base = [key(paramKey), key("principle")];

  if (principle.kind === "sequence") {
    if (principle.values.length === 0) {
      out.push(diag("empty-sequence", "error", base, "the sequence has no values"));
    }
    principle.values.forEach((v, i) => {
      if (v < 0 || v >= listLength) {
        out.push(
          diag(
            "index-out-of-range",
            "error",
            [...base, idx(i)],
            `sequence position ${i + 1} refers to index ${v}, which does not exist ` +
              `(valid indices are 0 to ${Math.max(0, listLength - 1)})`,
            { index: v, listLength },
          ),
        );
      }
    });
  }

  if (principle.kind === "ratio") {
    principle.pairs.forEach((pair, i) => {
      if (pair.index < 0 || pair.index >= listLength) {
        out.push(
          diag(
            "index-out-of-range",
            "error",
            [...base, idx(i)],
            `ratio refers to index ${pair.index}, which does not exist ` +
              `(valid indices are 0 to ${Math.max(0, listLength - 1)})`,
            { index: pair.index, listLength },
          ),
        );
      }
      if (pair.weight < 0) {
        out.push(
          diag("negative-weight", "error", [...base, idx(i)], "a ratio weight may not be negative"),
        );
      }
    });
    if (principle.pairs.every((p) => p.weight === 0)) {
      out.push(
        diag(
          "ratio-all-blocked",
          "error",
          base,
          "every weight is zero, so no element could ever be chosen",
        ),
      );
    }
  }

  if (principle.kind === "group") {
    if (principle.minRepetitions < 1) {
      out.push(
        diag("invalid-repetitions", "error", base, "the minimum number of repetitions must be at least 1"),
      );
    }
    if (principle.maxRepetitions < principle.minRepetitions) {
      out.push(
        diag(
          "invalid-repetitions",
          "warning",
          base,
          "the maximum number of repetitions is below the minimum; the engine will swap them",
        ),
      );
    }
  }

  if (principle.kind === "tendency") {
    if (principle.sections.length === 0) {
      out.push(diag("empty-tendency", "error", base, "a tendency mask needs at least one section"));
    }
    principle.sections.forEach((s, i) => {
      const loc = [...base, idx(i)];
      // The engine raises an uncaught exception on out-of-range values here
      // rather than reporting them, so catching it in the GUI matters.
      for (const [name, v] of [
        ["start minimum", s.startMin],
        ["start maximum", s.startMax],
        ["end minimum", s.endMin],
        ["end maximum", s.endMax],
      ] as const) {
        if (!(v >= 0 && v <= 1)) {
          out.push(
            diag(
              "tendency-out-of-unit-range",
              "error",
              loc,
              `the ${name} of section ${i + 1} is ${v}; tendency bounds are ` +
                `proportions of the list and must lie between 0 and 1`,
              { value: v },
            ),
          );
        }
      }
      if (s.portion <= 0) {
        out.push(
          diag("invalid-portion", "error", loc, `section ${i + 1} has a portion of ${s.portion}; it must be above 0`),
        );
      }
      if (s.startMin > s.startMax) {
        out.push(
          diag("tendency-bounds-crossed", "warning", loc, `section ${i + 1}: the start minimum is above the start maximum`),
        );
      }
      if (s.endMin > s.endMax) {
        out.push(
          diag("tendency-bounds-crossed", "warning", loc, `section ${i + 1}: the end minimum is above the end maximum`),
        );
      }
    });
  }
}

function checkEnsemble(paramKey: string, ens: Ensemble, tableRows: number, out: Diagnostic[]) {
  if (ens.kind !== "sequence") return;
  const base = [key(paramKey), key("combination")];
  if (ens.values.length === 0) {
    out.push(diag("empty-sequence", "error", base, "the ensemble sequence has no values"));
    return;
  }
  ens.values.forEach((v, i) => {
    if (v < 0 || v >= tableRows) {
      out.push(
        diag(
          "index-out-of-range",
          "error",
          [...base, idx(i)],
          `the ensemble sequence refers to group ${v}, but the table has ` +
            `${tableRows} group${tableRows === 1 ? "" : "s"} ` +
            `(valid indices are 0 to ${Math.max(0, tableRows - 1)})`,
          { index: v, listLength: tableRows },
        ),
      );
    }
  });
}

/** A time list: non-empty, parseable, non-negative. */
function checkTimeList(paramKey: string, values: string[], label: string, out: Diagnostic[]) {
  const base = [key(paramKey), key("list")];
  if (values.length === 0) {
    out.push(diag("empty-list", "error", base, `the ${label} list is empty`));
  }
  values.forEach((raw, i) => {
    const n = parseTimeValue(raw);
    if (n === null) {
      out.push(
        diag(
          "unparseable-value",
          "error",
          [...base, idx(i)],
          `"${raw}" is not a number; write a decimal like 0.25 or a fraction like 1/4`,
          { raw },
        ),
      );
    } else if (n < 0) {
      out.push(
        diag(
          paramKey === "entrydelay" ? "negative-entry" : "negative-duration",
          "error",
          [...base, idx(i)],
          `${raw} is negative; ${label} values must be zero or above`,
          { value: n },
        ),
      );
    }
  });
}

export function validateProject(p: Project): Diagnostic[] {
  const out: Diagnostic[] = [];

  // --- lists ----------------------------------------------------------
  checkTimeList("entrydelay", p.entrydelays, "entry delay", out);
  checkTimeList("duration", p.durations, "duration", out);

  if (p.dynamics.length === 0) {
    out.push(diag("empty-list", "error", [key("dynamics"), key("list")], "the dynamics list is empty"));
  }
  p.dynamics.forEach((d, i) => {
    if (p.dynamics.indexOf(d) !== i) {
      out.push(
        diag(
          "duplicate-name",
          "error",
          [key("dynamics"), key("list"), idx(i)],
          `"${d}" appears more than once; each dynamic must be distinct so indices are unambiguous`,
          { name: d },
        ),
      );
    }
  });

  if (p.performance.length === 0) {
    out.push(
      diag(
        "empty-list",
        "error",
        [key("performance"), key("list")],
        "no performance modes are defined; add modes to your instruments and they will appear here",
      ),
    );
  }

  if (p.registers.length === 0) {
    out.push(diag("empty-list", "error", [key("register"), key("list")], "the register list is empty"));
  }

  // HARMONY: ROW's own checks only apply when it's the active principle -
  // the Ins-before-Har ordering check further below is unconditional, since
  // both principles are always per-note.
  if (p.harmonyPrinciple === "row") {
    // ROW: each entry is either the literal "p" (percussion) or a relative
    // pitch 1..tr - never a magic 0.
    p.row.forEach((raw, i) => {
      if (raw === "p") return;
      const n = Number(raw);
      if (!Number.isInteger(n) || n < 1 || n > p.octaveDivision) {
        out.push(
          diag(
            "invalid-relative-pitch",
            "error",
            [key("harmony"), key("row"), idx(i)],
            `"${raw}" is not a valid row entry - use a relative pitch 1..${p.octaveDivision}, or 'p' for percussion`,
            { raw, tr: p.octaveDivision },
          ),
        );
      }
    });
    if (p.row.length === 0) {
      out.push(diag("empty-list", "error", [key("harmony"), key("row")], "the row is empty"));
    }
  } else {
    // INTERVAL (EMR-3 8.2, entries 21-24). The matrix always auto-resizes
    // with octaveDivision (see MatrixEditor/resizeIntervalMatrix), so a size
    // mismatch should only ever arise from a hand-edited file - checked
    // defensively anyway, mirroring the engine's own `InvalidIntervalMatrixSize`.
    const tr = p.octaveDivision;
    const matrixSize = Math.max(tr - 1, 0);

    // Only meaningful once the matrix's own shape is known to be right - a
    // malformed dense matrix already gets its own error below, and a row
    // index wouldn't correspond to a real interval number anyway.
    let matrixShapeOk = true;

    if (p.intervalMatrixSource.kind === "matrix") {
      const rows = p.intervalMatrixSource.rows;
      matrixShapeOk =
        rows.length === matrixSize && rows.every((row) => row.length === matrixSize);
      if (!matrixShapeOk) {
        out.push(
          diag(
            "invalid-interval-matrix-size",
            "error",
            [key("harmony"), key("matrix")],
            `the interval matrix must be ${matrixSize} x ${matrixSize} (tones-per-octave minus one)`,
            { expected: matrixSize },
          ),
        );
      }
    } else {
      // CHORD-INT: the chord is a plain list of relative pitches (no "p" -
      // an interval can't be computed to/from a percussion event).
      p.intervalMatrixSource.chord.forEach((raw, i) => {
        const n = Number(raw);
        if (!Number.isInteger(n) || n < 1 || n > tr) {
          out.push(
            diag(
              "invalid-relative-pitch",
              "error",
              [key("harmony"), key("chord"), idx(i)],
              `"${raw}" is not a valid chord tone - use a relative pitch 1..${tr}`,
              { raw, tr },
            ),
          );
        }
      });
      if (p.intervalMatrixSource.chord.length === 0) {
        out.push(
          diag("empty-list", "error", [key("harmony"), key("chord")], "the chord is empty"),
        );
      } else {
        const chord = p.intervalMatrixSource.chord;
        const n = chord.length;
        if (chord.some((v, i) => v === chord[(i + 1) % n])) {
          out.push(
            diag(
              "interval-chord-has-repeated-adjacent-tone",
              "error",
              [key("harmony"), key("chord")],
              "this chord repeats a tone between two tones that are next to each other (including wrapping from the last tone back to the first), so no interval can be computed between them",
            ),
          );
        }
      }
    }

    // Fig. 8-5's own well-formedness warning: a row with no allowed
    // successor at all is a dead end - the runtime still copes (falling
    // back to "INTERVAL RESTRICTIONS TOO STRICT"), but it's worth flagging.
    // Checked against the *effective* matrix (chord-derived if applicable,
    // then inverted if set) - the engine's own equivalent check runs against
    // the already-inverted matrix too, so this has to match or the two could
    // disagree on the exact same formula.
    if (matrixShapeOk) {
      const matrixFieldKey = p.intervalMatrixSource.kind === "matrix" ? "matrix" : "chord";
      effectiveIntervalMatrix(p)?.forEach((row, i) => {
        if (!row.some((cell) => cell)) {
          out.push(
            diag(
              "interval-matrix-row-has-no-successor",
              "warning",
              [key("harmony"), key(matrixFieldKey), idx(i)],
              `interval ${i + 1} has no allowed successor - reaching it will always fall back to "INTERVAL RESTRICTIONS TOO STRICT"`,
              { interval: i + 1 },
            ),
          );
        }
      });
    }

    // XCL-FRQ, entry 23.
    p.forbiddenTones.forEach((raw, i) => {
      const n = Number(raw);
      if (!Number.isInteger(n) || n < 1 || n > tr) {
        out.push(
          diag(
            "invalid-relative-pitch",
            "error",
            [key("harmony"), key("forbiddenTones"), idx(i)],
            `"${raw}" is not a valid forbidden tone - use a relative pitch 1..${tr}`,
            { raw, tr },
          ),
        );
      }
    });
    const distinctForbidden = new Set(
      p.forbiddenTones
        .map((raw) => Number(raw))
        .filter((n) => Number.isInteger(n) && n >= 1 && n <= tr),
    );
    if (tr > 0 && distinctForbidden.size >= tr) {
      out.push(
        diag(
          "all-tones-forbidden",
          "error",
          [key("harmony"), key("forbiddenTones")],
          `every tone from 1 to ${tr} is forbidden, leaving nothing the interval principle could ever produce`,
          { tr },
        ),
      );
    }
  }

  // --- tables ---------------------------------------------------------
  checkTable(
    { paramKey: "instrument", table: p.instrumentTable, listLength: p.instruments.length, listName: "instrument" },
    out,
  );
  checkTable(
    { paramKey: "entrydelay", table: p.entrydelayTable, listLength: p.entrydelays.length, listName: "entry delay" },
    out,
  );
  checkTable(
    { paramKey: "duration", table: p.durationTable, listLength: p.durations.length, listName: "duration" },
    out,
  );
  checkTable(
    { paramKey: "dynamics", table: p.dynamicsTable, listLength: p.dynamics.length, listName: "dynamics" },
    out,
  );
  checkTable(
    { paramKey: "performance", table: p.performanceTable, listLength: p.performance.length, listName: "performance" },
    out,
  );
  checkTable(
    { paramKey: "register", table: p.registerTable, listLength: p.registers.length, listName: "register" },
    out,
  );

  // --- principles and ensembles ---------------------------------------
  checkPrinciple("instrument", p.instrumentPrinciple, p.instruments.length, out);
  checkPrinciple("entrydelay", p.entrydelayPrinciple, p.entrydelays.length, out);
  checkPrinciple("duration", p.durationPrinciple, p.durations.length, out);
  checkPrinciple("dynamics", p.dynamicsPrinciple, p.dynamics.length, out);
  checkPrinciple("performance", p.performancePrinciple, p.performance.length, out);
  checkPrinciple("register", p.registerPrinciple, p.registers.length, out);

  checkEnsemble("instrument", p.instrumentEnsemble, p.instrumentTable.length, out);
  checkEnsemble("entrydelay", p.entrydelayEnsemble, p.entrydelayTable.length, out);
  checkEnsemble("duration", p.durationEnsemble, p.durationTable.length, out);
  checkEnsemble("dynamics", p.dynamicsEnsemble, p.dynamicsTable.length, out);
  checkEnsemble("performance", p.performanceEnsemble, p.performanceTable.length, out);
  checkEnsemble("register", p.registerEnsemble, p.registerTable.length, out);

  // The engine parses the instrument ensemble with a selector that has no
  // `combination` case, so this would be a bare parse error with no
  // explanation of why it isn't allowed.
  if (p.instrumentEnsemble.kind === "combination") {
    out.push(
      diag(
        "instrument-cannot-combine",
        "error",
        [key("instrument"), key("combination")],
        "instruments cannot use 'combination': combination means following the " +
          "instrument ensemble's groups, and the instrument parameter is what " +
          "the others would be following",
      ),
    );
  }

  // --- combination row alignment --------------------------------------
  const combinationParams: Array<[string, Ensemble, Table]> = [
    ["entrydelay", p.entrydelayEnsemble, p.entrydelayTable],
    ["duration", p.durationEnsemble, p.durationTable],
    ["dynamics", p.dynamicsEnsemble, p.dynamicsTable],
    ["performance", p.performanceEnsemble, p.performanceTable],
    ["register", p.registerEnsemble, p.registerTable],
  ];
  for (const [name, ens, table] of combinationParams) {
    if (ens.kind === "combination" && table.length !== p.instrumentTable.length) {
      out.push(
        diag(
          "table-size-mismatch",
          "warning",
          [key(name), key("combination")],
          `instrument table has ${p.instrumentTable.length} group(s) but this ` +
            `table has ${table.length}; combination pairs the groups one to one, ` +
            `so the counts must match`,
          { instrumentRows: p.instrumentTable.length, otherRows: table.length },
        ),
      );
    }
  }

  // --- instruments -----------------------------------------------------
  if (p.instruments.length === 0) {
    out.push(diag("no-instruments", "error", [key("instrument"), key("list")], "no instruments are defined"));
  }

  p.instruments.forEach((inst, i) => {
    const base = [key("instrument"), idx(i)];

    if (!inst.name.trim()) {
      out.push(diag("invalid-instrument-name", "error", [...base, key("name")], "this instrument has no name"));
    } else if (p.instruments.findIndex((o) => o.name === inst.name) !== i) {
      out.push(
        diag(
          "duplicate-name",
          "error",
          [...base, key("name")],
          `another instrument is also called "${inst.name}"`,
          { name: inst.name },
        ),
      );
    }

    if (inst.chordSizeMin === 0 || inst.chordSizeMax === 0) {
      out.push(
        diag("invalid-chord-size", "error", [...base, key("chordsize")], "a chord size may not be zero"),
      );
    }
    if (inst.chordSizeMin > inst.chordSizeMax) {
      out.push(
        diag(
          "invalid-chord-size",
          "warning",
          [...base, key("chordsize")],
          "the smallest chord size is larger than the largest; the engine will swap them",
        ),
      );
    }

    if (inst.pitchRange.kind === "pitch") {
      const low = inst.pitchRange.low.octave * 100 + inst.pitchRange.low.pitch;
      const high = inst.pitchRange.high.octave * 100 + inst.pitchRange.high.pitch;
      if (low > high) {
        out.push(
          diag(
            "invalid-pitch-range",
            "error",
            [...base, key("pitch-range")],
            "the lowest pitch is above the highest",
          ),
        );
      }
    }

    for (const [field, raw] of [
      ["shortest duration", inst.durationMin],
      ["longest duration", inst.durationMax],
    ] as const) {
      const n = parseTimeValue(raw);
      if (n === null) {
        out.push(
          diag("unparseable-value", "error", [...base, key("durations")], `the ${field} "${raw}" is not a number`, { raw }),
        );
      } else if (n < 0) {
        out.push(
          diag("duration-range-negative", "error", [...base, key("durations")], `the ${field} may not be negative`),
        );
      }
    }
    const dMin = parseTimeValue(inst.durationMin);
    const dMax = parseTimeValue(inst.durationMax);
    if (dMin !== null && dMax !== null && dMin > dMax) {
      out.push(
        diag(
          "duration-range-max-below-min",
          "error",
          [...base, key("durations")],
          "the shortest duration is longer than the longest",
        ),
      );
    }

    if (inst.performance.length === 0) {
      out.push(
        diag(
          "no-performance-modes",
          "error",
          [...base, key("performance")],
          `${inst.name || "this instrument"} has no performance modes, so it can never play a note`,
        ),
      );
    }
    if (inst.dynamics.length === 0) {
      out.push(
        diag(
          "no-dynamics",
          "error",
          [...base, key("dynamics")],
          `${inst.name || "this instrument"} has no dynamics, so it can never play a note`,
        ),
      );
    }
    for (const d of inst.dynamics) {
      if (!p.dynamics.includes(d)) {
        out.push(
          diag(
            "unknown-dynamic",
            "error",
            [...base, key("dynamics")],
            `"${d}" is not in the dynamics list`,
            { name: d },
          ),
        );
      }
    }
  });

  // The engine never compares these, and a mismatch quietly changes how many
  // groups are drawn rather than failing.
  if (p.numberOfInstrumentGroups > p.instrumentTable.length) {
    out.push(
      diag(
        "more-groups-than-rows",
        "warning",
        [key("instrument"), key("number-of-instrument-groups")],
        `${p.numberOfInstrumentGroups} instrument groups are requested but the ` +
          `instrument table defines only ${p.instrumentTable.length}`,
        { requested: p.numberOfInstrumentGroups, available: p.instrumentTable.length },
      ),
    );
  }
  if (p.numberOfInstrumentGroups < 1) {
    out.push(
      diag(
        "invalid-group-count",
        "error",
        [key("instrument"), key("number-of-instrument-groups")],
        "at least one instrument group is needed",
      ),
    );
  }

  // --- hierarchy -------------------------------------------------------
  const missing = HIERARCHY_ELEMS.filter((e) => !p.hierarchy.includes(e));
  if (missing.length > 0) {
    out.push(
      diag(
        "incomplete-hierarchy",
        "error",
        [key("hierarchy")],
        `the hierarchy is missing ${missing.map((m) => HIERARCHY_LABELS[m]).join(", ")}`,
        { missing },
      ),
    );
  }
  const dupes = p.hierarchy.filter((e, i) => p.hierarchy.indexOf(e) !== i);
  if (dupes.length > 0) {
    out.push(
      diag("duplicate-hierarchy", "error", [key("hierarchy")], "a parameter appears more than once in the hierarchy"),
    );
  }

  const posOf = (e: string) => p.hierarchy.indexOf(e as never);
  const insPos = posOf("Ins");

  if (p.density.kind === "instrument-density" && insPos !== 0) {
    out.push(
      diag(
        "instrument-density-requires-ins-first",
        "error",
        [key("hierarchy")],
        "when density comes from the instruments' chord sizes, Instrument must " +
          "be first in the hierarchy - the chord size is what decides how many " +
          "notes there are",
      ),
    );
  }

  // Per-note parameters need the chord size, which only exists once an
  // instrument has been chosen.
  if (p.performanceMode === "per-note" && insPos > posOf("Per")) {
    out.push(
      diag(
        "per-note-requires-ins-first",
        "error",
        [key("performance"), key("mode")],
        "performance is set per note, so Instrument must come before " +
          "Performance in the hierarchy - until an instrument is chosen there " +
          "is no chord size and so no notes to assign modes to",
      ),
    );
  }
  if (p.dynamicsMode === "per-note" && insPos > posOf("Dyn")) {
    out.push(
      diag(
        "per-note-requires-ins-first",
        "error",
        [key("dynamics"), key("mode")],
        "dynamics are set per note, so Instrument must come before Dynamics in the hierarchy",
      ),
    );
  }
  const durMode = p.durationRelation.kind === "equals-entry" ? "per-chord" : p.durationRelation.mode;
  if (durMode === "per-note" && insPos > posOf("Dur")) {
    out.push(
      diag(
        "per-note-requires-ins-first",
        "error",
        [key("duration"), key("relation")],
        "durations are set per note, so Instrument must come before Duration in the hierarchy",
      ),
    );
  }
  if (p.registerMode === "per-note" && insPos > posOf("Reg")) {
    out.push(
      diag(
        "per-note-requires-ins-first",
        "error",
        [key("register"), key("mode")],
        "register is set per note, so Instrument must come before Register in the hierarchy",
      ),
    );
  }
  if (insPos > posOf("Har")) {
    out.push(
      diag(
        "per-note-requires-ins-first",
        "error",
        [key("harmony")],
        "harmony is always set per note, so Instrument must come before Harmony in the hierarchy",
      ),
    );
  }
  if (p.durationRelation.kind === "shorter-than-entry" && posOf("Ent") > posOf("Dur")) {
    out.push(
      diag(
        "duration-needs-entry-first",
        "error",
        [key("duration"), key("relation")],
        "this duration relation is measured against the entry delay, so Entry " +
          "delay must come before Duration in the hierarchy",
      ),
    );
  }

  // --- density ---------------------------------------------------------
  if (p.density.kind === "autonomous") {
    if (p.density.low < 1) {
      out.push(diag("density-too-small", "error", [key("density")], "the lowest density must be at least 1"));
    }
    if (p.density.high < p.density.low) {
      out.push(
        diag("density-max-below-min", "error", [key("density")], "the highest density is below the lowest"),
      );
    }
    if (p.density.high > p.instruments.length) {
      out.push(
        diag(
          "density-exceeds-instruments",
          "warning",
          [key("density")],
          `a density of ${p.density.high} needs ${p.density.high} instruments ` +
            `sounding together, but only ${p.instruments.length} are defined`,
          { high: p.density.high, instruments: p.instruments.length },
        ),
      );
    }
    checkPrinciple("density", p.density.principle, p.density.high - p.density.low + 1, out);
  }

  // --- global ----------------------------------------------------------
  if (parseTimeValue(p.variantDuration) === null) {
    out.push(
      diag("unparseable-value", "error", [key("global"), key("variant-duration")], "the variant duration is not a number"),
    );
  } else if ((parseTimeValue(p.variantDuration) ?? 0) <= 0) {
    out.push(
      diag("invalid-variant-duration", "error", [key("global"), key("variant-duration")], "the variant duration must be above zero"),
    );
  }
  if (!Number.isInteger(p.seed) || p.seed < 0) {
    out.push(diag("invalid-seed", "error", [key("global"), key("seed")], "the seed must be a whole number, zero or above"));
  }
  if (!Number.isInteger(p.numberOfVariants) || p.numberOfVariants < 1) {
    out.push(
      diag(
        "invalid-n-variants",
        "error",
        [key("global"), key("n-variants")],
        "the number of variants must be a whole number, at least 1",
      ),
    );
  }

  return out;
}
