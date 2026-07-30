import { useState } from "react";
import { useStore } from "../state/store";
import { Field, Section } from "../components/Field";
import { TokenListEditor } from "../components/ListEditors";
import { MatrixEditor } from "../components/MatrixEditor";
import { IntervalGraph } from "../components/IntervalGraph";
import { effectiveIntervalMatrix, emptyIntervalMatrix } from "../schema/defaults";
import type { HarmonyPrinciple, Transposition } from "../schema/types";

/**
 * HARMONY (EMR-3 8.2): ROW and INTERVAL, its two implemented "row
 * principles" (CHORD is out of scope - see harmony.md: it becomes main
 * parameter and takes over vertical density itself, a fundamentally
 * different mechanism). Neither ever decides *which* octave a relative
 * pitch lands in - that is REGISTER's job, on its own screen. Their
 * relative order in the Structure screen's hierarchy decides which one
 * constrains the other for a given note.
 *
 * Unlike performance/dynamics/duration/register, neither has a "per chord"
 * mode: every note in a chord always takes its own next value, ignoring the
 * entry point entirely (EMR-3 has no MOD-HARM call number for either). A
 * genuinely shared-per-chord harmony is the CHORD principle, not built yet.
 */
export function HarmonyScreen() {
  const { project, update } = useStore();
  const matrixSize = Math.max(project.octaveDivision - 1, 0);
  // Grid vs. graph is purely a display choice - not part of the project, so
  // it isn't persisted or emitted, just local to this screen.
  const [view, setView] = useState<"grid" | "graph">("grid");
  // What the INTERVAL principle actually resolves to at run time - chord-
  // derived if applicable, then inverted if set. `null` while the chord
  // (or, in principle, a malformed direct matrix) isn't valid yet.
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
            onChange={(e) =>
              update((p) => (p.harmonyPrinciple = e.target.value as HarmonyPrinciple))
            }
          >
            <option value="row">Row — a fixed sequence, transposed once exhausted</option>
            <option value="interval">
              Interval — an unending chain walked over a matrix of allowed intervals
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
                        p.intervalMatrixSource = {
                          kind: "matrix",
                          rows: emptyIntervalMatrix(p.octaveDivision),
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
                path="harmony.intervalMatrixSource.chord"
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
              path={
                project.intervalMatrixSource.kind === "matrix"
                  ? "harmony.intervalMatrixSource.rows"
                  : "harmony.intervalMatrixSource.chord"
              }
              hint={
                project.intervalMatrixSource.kind === "matrix"
                  ? "Row = the interval just used; column = the interval allowed to follow it. Check a cell to allow that transition."
                  : "What the chord above actually produces (after inversion, if on) - a preview, not directly editable. Use the button below to fork it into a hand-editable matrix."
              }
            >
              <div className="field__row" style={{ marginBottom: 8 }}>
                <div className="kind-switch" role="radiogroup">
                  <button
                    type="button"
                    className={`kind-switch__option${
                      view === "grid" ? " kind-switch__option--active" : ""
                    }`}
                    aria-pressed={view === "grid"}
                    onClick={() => setView("grid")}
                  >
                    Grid
                  </button>
                  <button
                    type="button"
                    className={`kind-switch__option${
                      view === "graph" ? " kind-switch__option--active" : ""
                    }`}
                    aria-pressed={view === "graph"}
                    onClick={() => setView("graph")}
                  >
                    Graph
                  </button>
                </div>

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
                        p.invertMatrix = false;
                      })
                    }
                  >
                    Use as editable matrix
                  </button>
                )}
              </div>

              {project.intervalMatrixSource.kind === "matrix" ? (
                view === "grid" ? (
                  <MatrixEditor
                    size={matrixSize}
                    value={project.intervalMatrixSource.rows}
                    onChange={(rows) =>
                      update((p) => (p.intervalMatrixSource = { kind: "matrix", rows }))
                    }
                  />
                ) : (
                  <IntervalGraph size={matrixSize} matrix={effective ?? []} />
                )
              ) : effective ? (
                view === "grid" ? (
                  <MatrixEditor size={matrixSize} value={effective} readOnly />
                ) : (
                  <IntervalGraph size={matrixSize} matrix={effective} />
                )
              ) : (
                <div className="empty-note">Enter a valid chord above to see its matrix.</div>
              )}
            </Field>
          </Section>

          <Section title="Forbidden tones and inversion">
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

            <Field
              label="Invert matrix"
              helpKey="fields/harmony-invert-matrix"
              path="harmony.invertMatrix"
              hint="Flip every cell of the resulting matrix - allowed transitions become forbidden and vice versa."
            >
              <div className="kind-switch" role="radiogroup">
                <button
                  type="button"
                  className={`kind-switch__option${
                    !project.invertMatrix ? " kind-switch__option--active" : ""
                  }`}
                  aria-pressed={!project.invertMatrix}
                  onClick={() => update((p) => (p.invertMatrix = false))}
                >
                  No
                </button>
                <button
                  type="button"
                  className={`kind-switch__option${
                    project.invertMatrix ? " kind-switch__option--active" : ""
                  }`}
                  aria-pressed={project.invertMatrix}
                  onClick={() => update((p) => (p.invertMatrix = true))}
                >
                  Yes
                </button>
              </div>
            </Field>
          </Section>
        </>
      )}
    </div>
  );
}
