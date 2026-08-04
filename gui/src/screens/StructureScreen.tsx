import { useStore } from "../state/store";
import { Field, Section } from "../components/Field";
import { HierarchyEditor } from "../components/ListEditors";
import { PrincipleEditor } from "../components/PrincipleEditor";
import { intervalMatrixWouldLoseData, resizeIntervalMatrix } from "../schema/defaults";
import type { DurationRelation, RestMode } from "../schema/types";

/**
 * The structure screen holds the decisions that shape the piece as a whole -
 * how long it is, how dense it is, and in what order the parameters resolve.
 * Everything here affects every other screen, which is why the hierarchy and
 * the density live together: they are the two settings that most change what
 * the other screens are allowed to say.
 */
export function StructureScreen() {
  const { project, update, setScreen } = useStore();

  return (
    <div className="screen">
      <h1 className="screen__title">Structure</h1>
      <p className="screen__intro">
        The shape of the whole piece: its length, how many notes sound at once, and the order
        in which the parameters are decided.
      </p>

      <Section title="The variant">
        <Field
          label="Seed"
          helpKey="fields/seed"
          path="global.seed"
          hint="The same seed and the same formula always produce exactly the same score. Change it to hear another variant of the same structure."
        >
          <input
            type="number"
            className="input--narrow"
            min={0}
            value={project.seed}
            onChange={(e) => update((p) => (p.seed = Number(e.target.value)))}
          />
        </Field>

        <Field
          label="Duration"
          helpKey="fields/variant-duration"
          path="global.variant-duration"
          hint="Total length of the variant, in seconds."
        >
          <input
            type="text"
            className="input--narrow"
            value={project.variantDuration}
            onChange={(e) => update((p) => (p.variantDuration = e.target.value))}
          />
        </Field>

        <Field
          label="Number of variants"
          helpKey="fields/n-variants"
          path="global.n-variants"
          hint="How many variants to calculate in this run. All of them share one continuing selection-cycle state - the same principles simply keep drawing, uninterrupted, from one variant into the next."
        >
          <input
            type="number"
            className="input--narrow"
            min={1}
            value={project.numberOfVariants}
            onChange={(e) => update((p) => (p.numberOfVariants = Number(e.target.value)))}
          />
        </Field>

        <Field
          label="Octave division"
          helpKey="fields/octave-division"
          hint="Tones per octave (tr). Relative pitches in the row and register steps both go 1..tr."
        >
          <input
            type="number"
            className="input--narrow"
            min={1}
            value={project.octaveDivision}
            onChange={(e) => {
              const next = Number(e.target.value);
              // The interval matrix always auto-resizes to match - but
              // shrinking silently discards any checked cell outside the
              // new size, so that specifically needs a confirmation first.
              if (
                project.intervalMatrixSource.kind === "matrix" &&
                intervalMatrixWouldLoseData(project.intervalMatrixSource.rows, next)
              ) {
                const proceed = window.confirm(
                  "Lowering the octave division shrinks the interval matrix, discarding any checked cells outside the new size. Continue?",
                );
                if (!proceed) return;
              }
              update((p) => {
                p.octaveDivision = next;
                if (p.intervalMatrixSource.kind === "matrix") {
                  p.intervalMatrixSource = {
                    kind: "matrix",
                    rows: resizeIntervalMatrix(p.intervalMatrixSource.rows, next),
                  };
                }
              });
            }}
          />
        </Field>
      </Section>

      <Section title="Vertical density">
        <Field
          label="Density"
          helpKey="fields/density"
          path="density"
          hint="How many notes sound together. Either drawn by its own principle, taken from the chord size of whichever instrument is playing, or - under the CHORD harmony principle - fixed by whichever chord was drawn."
        >
          {project.harmonyPrinciple === "chord" ? (
            <div className="field__hint">
              Fixed to the size of whichever chord is drawn - HARMONY's CHORD principle
              (chosen on the Harmony screen) makes HARMONY the main parameter, deciding
              vertical density itself.
            </div>
          ) : (
            <>
              <select
                style={{ width: 340 }}
                value={project.density.kind}
                onChange={(e) =>
                  update((p) => {
                    p.density =
                      e.target.value === "instrument-density"
                        ? { kind: "instrument-density" }
                        : {
                            kind: "autonomous",
                            low: 1,
                            high: 2,
                            principle: { kind: "series" },
                          };
                  })
                }
              >
                <option value="autonomous">Autonomous — density has its own principle</option>
                <option value="instrument-density">
                  From instruments — the instrument's chord size decides
                </option>
              </select>

              {project.density.kind === "autonomous" && (
                <div className="stack" style={{ marginTop: 12 }}>
                  <div className="field__row">
                    <span className="faint" style={{ width: 130 }}>
                      Notes at once
                    </span>
                    <input
                      type="number"
                      className="input--tiny"
                      min={1}
                      value={project.density.low}
                      onChange={(e) =>
                        update((p) => {
                          if (p.density.kind === "autonomous")
                            p.density.low = Number(e.target.value);
                        })
                      }
                    />
                    <span className="faint">to</span>
                    <input
                      type="number"
                      className="input--tiny"
                      min={1}
                      value={project.density.high}
                      onChange={(e) =>
                        update((p) => {
                          if (p.density.kind === "autonomous")
                            p.density.high = Number(e.target.value);
                        })
                      }
                    />
                  </div>
                  <div>
                    <div className="faint" style={{ fontSize: 11.5, marginBottom: 6 }}>
                      How the density is chosen within that range:
                    </div>
                    <PrincipleEditor
                      principle={project.density.principle}
                      onChange={(v) =>
                        update((p) => {
                          if (p.density.kind === "autonomous") p.density.principle = v;
                        })
                      }
                      values={densityRange(project.density.low, project.density.high)}
                      valueLabel="density"
                    />
                  </div>
                </div>
              )}

              {project.density.kind === "instrument-density" && (
                <div className="field__hint" style={{ marginTop: 8 }}>
                  Instrument must come first in the hierarchy, since the chord size is what
                  decides how many notes there are.
                </div>
              )}
            </>
          )}
        </Field>
      </Section>

      <Section title="Hierarchy">
        <Field
          label="Order of resolution"
          helpKey="fields/hierarchy"
          path="hierarchy"
          hint="Drag to reorder. Parameters resolved earlier constrain the ones after them: whatever is decided first is decided freely, and everything later must fit around it."
        >
          <HierarchyEditor
            hierarchy={project.hierarchy}
            onChange={(h) => update((p) => (p.hierarchy = h))}
          />
        </Field>
      </Section>

      <Section title="Duration and entry delay">
        <Field
          label="Duration relation"
          helpKey="fields/duration-relation"
          path="duration.relation"
          hint="Whether a note's duration is free, equal to the entry delay, or held below it."
        >
          <select
            style={{ width: 340 }}
            value={project.durationRelation.kind}
            onChange={(e) =>
              update((p) => {
                const kind = e.target.value as DurationRelation["kind"];
                p.durationRelation =
                  kind === "equals-entry"
                    ? { kind: "equals-entry" }
                    : { kind, mode: "per-note" };
              })
            }
          >
            <option value="independent">Independent — duration is chosen freely</option>
            <option value="equals-entry">Equal to the entry delay — notes join end to end</option>
            <option value="shorter-than-entry">
              Shorter than the entry delay — always leaves a gap
            </option>
          </select>

          {project.durationRelation.kind !== "equals-entry" && (
            <select
              style={{ width: 340, marginTop: 8 }}
              value={project.durationRelation.mode}
              onChange={(e) =>
                update((p) => {
                  if (p.durationRelation.kind !== "equals-entry") {
                    p.durationRelation.mode = e.target.value as "per-chord" | "per-note";
                  }
                })
              }
            >
              <option value="per-chord">Per chord — every note in a chord shares a duration</option>
              <option value="per-note">Per note — each note gets its own duration</option>
            </select>
          )}
        </Field>
      </Section>

      <Section title="Layers">
        <Field
          label="Union"
          helpKey="fields/union"
          path="union"
          hint="Whether the instrument groups are merged into one layer, kept as separate layers with their own independent harmony, or kept as separate layers that still share one continuous harmony stream."
        >
          <select
            style={{ width: 340 }}
            value={project.union}
            onChange={(e) => {
              const next = e.target.value as "none" | "union" | "common-harmony";
              update((p) => {
                p.union = next;
                // CHORD forces Har first; union = common-harmony forces Har
                // last - mutually exclusive (validate.ts also enforces
                // this).
                if (next === "common-harmony" && p.harmonyPrinciple === "chord") {
                  p.harmonyPrinciple = "row";
                  p.density = { kind: "instrument-density" };
                }
              });
            }}
          >
            <option value="none">None — one layer per instrument group, each with its own harmony</option>
            <option value="union">Union — groups are combined into one layer</option>
            <option value="common-harmony">
              Common harmony — separate layers, one shared harmony stream across all of them
            </option>
          </select>

          {project.union === "common-harmony" && (
            <div className="field__hint" style={{ marginTop: 8 }}>
              Harmony must come last in the hierarchy under common harmony, since it resolves
              once, after every layer's own rhythm is already fixed.
            </div>
          )}
        </Field>
      </Section>

      <Section title="Rest">
        <Field
          label="Rest mode"
          helpKey="fields/rest-mode"
          path="rest.rest-mode"
          hint="Whether autonomous rests are inserted into the timeline at all, and, if so, whether they may land on an entry still concealed by an earlier tone's sustain."
        >
          <select
            style={{ width: 340 }}
            value={project.restMode.kind}
            onChange={(e) =>
              update((p) => {
                const kind = e.target.value as RestMode["kind"];
                p.restMode = kind === "off" ? { kind: "off" } : { kind, d1: 5, d2: 20 };
              })
            }
          >
            <option value="off">Off — no rests are inserted</option>
            <option value="before-sound-entry">
              Before a sound entry — placed before the next tone onset, regardless of sustain
            </option>
            <option value="before-general-entry">
              Before a general entry — skips onsets still concealed by an earlier tone's sustain
            </option>
          </select>

          {project.restMode.kind !== "off" && (
            <div className="field__row" style={{ marginTop: 8 }}>
              <span className="faint" style={{ width: 130 }}>
                Entry range (%)
              </span>
              <input
                type="number"
                className="input--tiny"
                min={0}
                max={100}
                value={project.restMode.d1}
                onChange={(e) =>
                  update((p) => {
                    if (p.restMode.kind !== "off") p.restMode.d1 = Number(e.target.value);
                  })
                }
              />
              <span className="faint">to</span>
              <input
                type="number"
                className="input--tiny"
                min={0}
                max={100}
                value={project.restMode.d2}
                onChange={(e) =>
                  update((p) => {
                    if (p.restMode.kind !== "off") p.restMode.d2 = Number(e.target.value);
                  })
                }
              />
            </div>
          )}

          {project.restMode.kind !== "off" && (
            <div className="field__hint" style={{ marginTop: 8 }}>
              Percentages of the variant duration: each rest's placement is drawn from this
              window and added onward from the last one. Rest lengths and their own order are
              set on the{" "}
              <button
                type="button"
                className="btn btn--ghost btn--small"
                style={{ display: "inline" }}
                onClick={() => setScreen("rest")}
              >
                Rest screen
              </button>
              .
            </div>
          )}
        </Field>
      </Section>

      <Section title="This formula">
        <Field
          label="Start index"
          helpKey="fields/start-index"
          hint="Whether the first element of a list is called 0 or 1. This changes only what is shown; the formula itself is unaffected."
        >
          <select
            style={{ width: 200 }}
            value={project.startIndex}
            onChange={(e) => update((p) => (p.startIndex = Number(e.target.value) as 0 | 1))}
          >
            <option value={0}>Count from 0</option>
            <option value={1}>Count from 1</option>
          </select>
        </Field>

        <Field
          label="Notes"
          helpKey="fields/comment"
          hint="Your own notes about this formula. Saved with the project and written into the generated file as comments."
        >
          <textarea
            value={project.comment}
            placeholder="What are you trying to achieve with this structure?"
            onChange={(e) => update((p) => (p.comment = e.target.value))}
          />
        </Field>
      </Section>
    </div>
  );
}

/** The density range, as display strings, for weighting under ratio. */
function densityRange(low: number, high: number): string[] {
  const out: string[] = [];
  for (let n = low; n <= high; n += 1) out.push(`${n} note${n === 1 ? "" : "s"}`);
  return out;
}
