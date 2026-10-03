import { useStore } from "../state/store";
import { Field, Section } from "../components/Field";
import { TokenListEditor } from "../components/ListEditors";
import { MatrixEditor } from "../components/MatrixEditor";
import { IntervalGraph } from "../components/IntervalGraph";
import { RowPreview } from "../components/RowPreview";
import { PrincipleEditor } from "../components/PrincipleEditor";
import { effectiveIntervalMatrix, emptyIntervalMatrix } from "../schema/defaults";
import type { ChordTransposition, HarmonyPrinciple, Transposition } from "../schema/types";

/**
 * HARMONY (EMR-3 8.2): ROW and INTERVAL, its two "row principles", plus
 * CHORD. ROW/INTERVAL never decide *which* octave a relative pitch lands in
 * - that is REGISTER's job, on its own screen - and their relative order in
 * the Structure screen's hierarchy decides which one constrains the other
 * for a given note. Neither has a "per chord" mode either: every note in a
 * chord always takes its own next value, ignoring the entry point entirely
 * (EMR-3 has no MOD-HARM call number for either).
 *
 * CHORD is different in kind: it decides a whole chord (tones *and* how
 * many of them) per entry point, becomes HARMONY's "main parameter", and
 * takes over vertical density itself (EMR-3 §9.2) - the Structure screen's
 * own density selector reflects that (see there). Switching into or out of
 * CHORD here keeps `density` in sync automatically, so the two settings can
 * never quietly disagree.
 */
export function HarmonyScreen() {
  const { project, update } = useStore();
  const matrixSize = Math.max(project.octaveDivision - 1, 0);
  // What the INTERVAL principle actually resolves to at run time - chord-
  // derived if applicable. `null` while the chord (or, in principle, a
  // malformed direct matrix) isn't valid yet.
  const effective = effectiveIntervalMatrix(project);

  return (
    <div className="screen">
      <h1 className="screen__title">Harmony</h1>
      <p className="screen__intro">
        The relative pitch a tone takes. See the Register screen for how a relative pitch is
        placed into an actual octave.
      </p>

      <Section title="Principle">
        <Field
          label="Principle"
          helpKey="fields/harmony-principle"
          path="harmony.principle"
          hint="Which mechanism produces the stream of relative pitches."
        >
          <select
            style={{ width: 340 }}
            value={project.harmonyPrinciple}
            onChange={(e) => {
              const next = e.target.value as HarmonyPrinciple;
              update((p) => {
                p.harmonyPrinciple = next;
                // Keep density in lockstep: CHORD requires chord-density and
                // vice versa (validate.ts also enforces this, but syncing it
                // here means the two can never actually drift apart through
                // the UI in the first place).
                if (next === "chord") {
                  p.density = { kind: "chord-density" };
                  // CHORD forces Har first; union = common-harmony forces Har
                  // last - mutually exclusive (validate.ts also enforces
                  // this).
                  if (p.union === "common-harmony") p.union = "none";
                } else if (p.density.kind === "chord-density") {
                  p.density = { kind: "instrument-density" };
                }
              });
            }}
          >
            <option value="row">Row — a fixed sequence, transposed once exhausted</option>
            <option value="interval">
              Interval — an unending chain walked over a matrix of allowed intervals
            </option>
            <option value="chord">
              Chord — a whole chord per entry point, deciding vertical density itself
            </option>
          </select>
        </Field>
      </Section>

      {project.harmonyPrinciple === "row" && (
        <>
          <Section title="Row">
            <Field
              label="Row"
              helpKey="fields/harmony-row"
              path="harmony.row"
              hint={`Relative pitches 1..${project.octaveDivision}, or 'p' for an explicit percussion event. Drag the grip to reorder.`}
            >
              <TokenListEditor
                values={project.row}
                onChange={(v) => update((p) => (p.row = v))}
                placeholder="p"
                bulkPlaceholder="1 2 3 p 5 7 9 11 12"
                invalid={(v) => {
                  if (v === "p") return false;
                  const n = Number(v);
                  return !Number.isInteger(n) || n < 1 || n > project.octaveDivision;
                }}
              />
            </Field>
          </Section>

          <Section title="Transposition">
            <Field
              label="Transposition"
              helpKey="fields/harmony-transposition"
              path="harmony.transposition"
              hint="How the row is transposed each time it has been used up in full."
            >
              <select
                style={{ width: 340 }}
                value={project.transposition}
                onChange={(e) =>
                  update((p) => (p.transposition = e.target.value as Transposition))
                }
              >
                <option value="none">None — the row repeats unchanged</option>
                <option value="alea">Alea — a random interval each pass</option>
                <option value="series">Series — each interval once before repeating</option>
                <option value="chromatic">Chromatic — up one more semitone with every pass</option>
                <option value="serial">
                  Serial — the row itself reused as transposition intervals
                </option>
              </select>
            </Field>
          </Section>
        </>
      )}

      {project.harmonyPrinciple === "interval" && (
        <>
          <Section title="Matrix">
            <Field
              label="Matrix source"
              helpKey="fields/harmony-matrix"
              path="harmony.intervalMatrixSource"
              hint="Which intervals may follow which, walked as an unending chain."
            >
              <div className="kind-switch" role="radiogroup">
                <button
                  type="button"
                  className={`kind-switch__option${
                    project.intervalMatrixSource.kind === "matrix"
                      ? " kind-switch__option--active"
                      : ""
                  }`}
                  aria-pressed={project.intervalMatrixSource.kind === "matrix"}
                  onClick={() =>
                    update((p) => {
                      if (p.intervalMatrixSource.kind !== "matrix") {
                        // Leaving chord mode keeps what the chord produced
                        // (the chord itself is dropped) - an empty grid only
                        // when the chord isn't valid yet.
                        p.intervalMatrixSource = {
                          kind: "matrix",
                          rows: effectiveIntervalMatrix(p) ?? emptyIntervalMatrix(p.octaveDivision),
                        };
                      }
                    })
                  }
                >
                  Matrix
                </button>
                <button
                  type="button"
                  className={`kind-switch__option${
                    project.intervalMatrixSource.kind === "chord"
                      ? " kind-switch__option--active"
                      : ""
                  }`}
                  aria-pressed={project.intervalMatrixSource.kind === "chord"}
                  onClick={() =>
                    update((p) => {
                      if (p.intervalMatrixSource.kind !== "chord") {
                        p.intervalMatrixSource = { kind: "chord", chord: [] };
                      }
                    })
                  }
                >
                  Derive from chord
                </button>
              </div>
            </Field>

            {project.intervalMatrixSource.kind === "chord" && (
              <Field
                label="Chord"
                helpKey="fields/harmony-matrix"
                path="harmony.chord"
                hint={`Relative pitches 1..${project.octaveDivision}. The matrix below updates live as you edit this - walked both ways, cyclically. See the help for the worked example.`}
              >
                <TokenListEditor
                  values={project.intervalMatrixSource.chord}
                  onChange={(chord) =>
                    update((p) => (p.intervalMatrixSource = { kind: "chord", chord }))
                  }
                  placeholder="1"
                  bulkPlaceholder="1 3 7"
                  invalid={(v) => {
                    const n = Number(v);
                    return !Number.isInteger(n) || n < 1 || n > project.octaveDivision;
                  }}
                />
              </Field>
            )}

            <Field
              label={
                project.intervalMatrixSource.kind === "matrix"
                  ? "Allowed transitions"
                  : "Derived matrix (read-only)"
              }
              helpKey="fields/harmony-matrix"
              path={project.intervalMatrixSource.kind === "matrix" ? "harmony.matrix" : "harmony.chord"}
              hint={
                project.intervalMatrixSource.kind === "matrix"
                  ? "Row = the interval just used; column = the interval allowed to follow it. Check a cell to allow that transition."
                  : "What the chord above actually produces - a preview, not directly editable. Use the button below to fork it into a hand-editable matrix."
              }
            >
              <div className="field__row" style={{ marginBottom: 8 }}>
                {project.intervalMatrixSource.kind === "matrix" && (
                  <button
                    type="button"
                    className="btn btn--ghost btn--small"
                    style={{ marginLeft: "auto" }}
                    disabled={!project.intervalMatrixSource.rows.some((row) => row.some(Boolean))}
                    title="Uncheck every cell, to start the matrix over"
                    onClick={() => {
                      // No undo in the GUI, so ask first.
                      if (!window.confirm("Clear the whole interval matrix?")) return;
                      update((p) => {
                        if (p.intervalMatrixSource.kind !== "matrix") return;
                        p.intervalMatrixSource.rows = emptyIntervalMatrix(p.octaveDivision);
                      });
                    }}
                  >
                    Clear all
                  </button>
                )}

                {project.intervalMatrixSource.kind === "matrix" && (
                  <button
                    type="button"
                    className="btn btn--ghost btn--small"
                    title="Flip every cell: every allowed transition becomes forbidden and vice versa"
                    onClick={() =>
                      update((p) => {
                        if (p.intervalMatrixSource.kind !== "matrix") return;
                        p.intervalMatrixSource.rows = p.intervalMatrixSource.rows.map((row) =>
                          row.map((cell) => !cell),
                        );
                      })
                    }
                  >
                    Invert
                  </button>
                )}

                {project.intervalMatrixSource.kind === "chord" && (
                  <button
                    type="button"
                    className="btn btn--ghost btn--small"
                    disabled={!effective}
                    title={
                      effective
                        ? "Fork the derived matrix above into a hand-editable one"
                        : "Enter a valid chord first"
                    }
                    style={{ marginLeft: "auto" }}
                    onClick={() =>
                      update((p) => {
                        if (!effective) return;
                        p.intervalMatrixSource = { kind: "matrix", rows: effective };
                      })
                    }
                  >
                    Use as editable matrix
                  </button>
                )}
              </div>

              {project.intervalMatrixSource.kind === "matrix" ? (
                <div className="matrix-views">
                  <MatrixEditor
                    size={matrixSize}
                    value={project.intervalMatrixSource.rows}
                    onChange={(rows) =>
                      update((p) => (p.intervalMatrixSource = { kind: "matrix", rows }))
                    }
                  />
                  <div className="matrix-graphs">
                    <IntervalGraphPanel size={matrixSize} matrix={effective ?? []} />
                    {effective && (
                      <RowPreview
                        tr={project.octaveDivision}
                        matrix={effective}
                        forbiddenTones={project.forbiddenTones}
                      />
                    )}
                  </div>
                </div>
              ) : effective ? (
                <div className="matrix-views">
                  <MatrixEditor size={matrixSize} value={effective} readOnly />
                  <div className="matrix-graphs">
                    <IntervalGraphPanel size={matrixSize} matrix={effective} />
                    <RowPreview
                      tr={project.octaveDivision}
                      matrix={effective}
                      forbiddenTones={project.forbiddenTones}
                    />
                  </div>
                </div>
              ) : (
                <div className="empty-note">Enter a valid chord above to see its matrix.</div>
              )}
            </Field>

          </Section>

          <Section title="Forbidden tones">
            <Field
              label="Forbidden tones"
              helpKey="fields/harmony-forbidden-tones"
              path="harmony.forbiddenTones"
              hint={`Relative pitches (1..${project.octaveDivision}) the interval principle may never produce - not even as its first tone.`}
            >
              <TokenListEditor
                values={project.forbiddenTones}
                onChange={(v) => update((p) => (p.forbiddenTones = v))}
                placeholder="7"
                bulkPlaceholder="3 7"
                invalid={(v) => {
                  const n = Number(v);
                  return !Number.isInteger(n) || n < 1 || n > project.octaveDivision;
                }}
              />
            </Field>
          </Section>
        </>
      )}

      {project.harmonyPrinciple === "chord" && (
        <>
          <Section title="Chord table">
            <Field
              label="Chords"
              helpKey="fields/harmony-chord"
              path="harmony.chord"
              hint={`One chord per group - each entry a relative pitch (1..${project.octaveDivision}) or 'p' for percussion. A chord's own size becomes the vertical density whenever it's drawn.`}
            >
              <ChordTableEditor
                chords={project.chords}
                onChange={(chords) => update((p) => (p.chords = chords))}
                octaveDivision={project.octaveDivision}
              />
            </Field>
          </Section>

          <Section title="Order of chords">
            <Field
              label="Order"
              helpKey="fields/harmony-chord-order"
              path="harmony.order"
              hint="How the next chord is chosen from the table above."
            >
              <PrincipleEditor
                principle={project.chordOrder}
                onChange={(v) => update((p) => (p.chordOrder = v))}
                values={project.chords.map(
                  (c, i) => `chord ${i + 1} (${c.length} tone${c.length === 1 ? "" : "s"})`,
                )}
                valueLabel="chord"
              />
            </Field>
          </Section>

          <Section title="Transposition">
            <Field
              label="Transposition"
              helpKey="fields/harmony-chord-transposition"
              path="harmony.transposition"
              hint="How the whole table is transposed each time every chord in it has been drawn once (one pass)."
            >
              <select
                style={{ width: 340 }}
                value={
                  typeof project.chordTransposition === "string"
                    ? project.chordTransposition
                    : "given"
                }
                onChange={(e) => {
                  const kind = e.target.value;
                  const next: ChordTransposition =
                    kind === "given"
                      ? { kind: "given", values: ["1"] }
                      : (kind as "none" | "alea" | "series");
                  update((p) => (p.chordTransposition = next));
                }}
              >
                <option value="none">None — the table repeats unchanged</option>
                <option value="alea">Alea — a random interval each pass</option>
                <option value="series">Series — each interval once before repeating</option>
                <option value="given">Given — an explicit list of intervals you provide</option>
              </select>

              {typeof project.chordTransposition !== "string" && (
                <div style={{ marginTop: 8 }}>
                  <TokenListEditor
                    values={project.chordTransposition.values}
                    onChange={(v) =>
                      update((p) => {
                        if (typeof p.chordTransposition !== "string")
                          p.chordTransposition.values = v;
                      })
                    }
                    placeholder="1"
                    bulkPlaceholder="2 5"
                    invalid={(v) => {
                      const n = Number(v);
                      return !Number.isInteger(n) || n < 1 || n > project.octaveDivision;
                    }}
                  />
                </div>
              )}
            </Field>
          </Section>
        </>
      )}
    </div>
  );
}

/** One `TokenListEditor` per chord, with add/remove-chord affordances - the
 * CHORD table's own list-of-lists, alongside every other chord-table row
 * being just a `row`-shaped token list underneath. */
function ChordTableEditor({
  chords,
  onChange,
  octaveDivision,
}: {
  chords: string[][];
  onChange: (chords: string[][]) => void;
  octaveDivision: number;
}) {
  const invalid = (v: string) => {
    if (v === "p") return false;
    const n = Number(v);
    return !Number.isInteger(n) || n < 1 || n > octaveDivision;
  };

  return (
    <div className="stack">
      {chords.map((chord, i) => (
        <div className="field__row" key={i}>
          <span className="faint" style={{ width: 60 }}>
            Chord {i + 1}
          </span>
          <div style={{ flex: 1 }}>
            <TokenListEditor
              values={chord}
              onChange={(v) => onChange(chords.map((c, j) => (j === i ? v : c)))}
              placeholder="1"
              bulkPlaceholder="1 3 5"
              invalid={invalid}
            />
          </div>
          <button
            type="button"
            className="btn btn--ghost btn--icon btn--danger"
            onClick={() => onChange(chords.filter((_, j) => j !== i))}
            title="Remove this chord"
          >
            ×
          </button>
        </div>
      ))}
      <div>
        <button type="button" className="btn btn--small" onClick={() => onChange([...chords, ["1"]])}>
          + Add chord
        </button>
      </div>
    </div>
  );
}

/** The interval graph with its caption, matching `RowPreview`'s header. */
function IntervalGraphPanel({ size, matrix }: { size: number; matrix: boolean[][] }) {
  return (
    <figure className="graph-panel">
      <figcaption className="graph-panel__caption">
        <span className="graph-panel__title">Interval graph</span>
        <span className="graph-panel__sub">arrow = interval that may follow</span>
      </figcaption>
      <IntervalGraph size={size} matrix={matrix} />
    </figure>
  );
}
