import { useState } from "react";
import { useStore } from "../state/store";
import { Field, Section, DiagnosticList } from "../components/Field";
import { TableEditor } from "../components/TableEditor";
import { EnsembleEditor, PrincipleEditor } from "../components/PrincipleEditor";
import { diagnosticsFor, dedupeForDisplay } from "../engine/diagnostics";
import type { Instrument } from "../schema/types";

/**
 * Instruments are the reference parameter: they decide what is playable at
 * all. A dynamic or a performance mode can only be assigned to a note if the
 * instrument holding that note can produce it, so these definitions quietly
 * constrain every other screen.
 */
export function InstrumentsScreen() {
  const { project, update, diagnostics } = useStore();
  const [open, setOpen] = useState<number | null>(0);

  const addInstrument = () => {
    update((p) => {
      p.instruments.push({
        name: `instrument${p.instruments.length + 1}`,
        chordSizeMin: 1,
        chordSizeMax: 1,
        performance: p.performance.slice(0, 1),
        dynamics: p.dynamics.slice(),
        percussion: false,
        compassLow: { octave: 1, pitch: 1 },
        compassHigh: { octave: 5, pitch: 12 },
        durationMin: "0.1",
        durationMax: "4.0",
      });
    });
    setOpen(project.instruments.length);
  };

  return (
    <div className="screen">
      <h1 className="screen__title">Instruments</h1>
      <p className="screen__intro">
        What each instrument can play — how many notes at once, in what modes, at what
        dynamics, over what range. Nothing elsewhere can ask an instrument for something it
        cannot produce.
      </p>

      <Section title="Definitions">
        <div>
          {project.instruments.map((inst, i) => (
            <InstrumentCard
              key={i}
              index={i}
              instrument={inst}
              open={open === i}
              onToggle={() => setOpen(open === i ? null : i)}
            />
          ))}

          {project.instruments.length === 0 && (
            <div className="empty-note">No instruments yet.</div>
          )}

          <button type="button" className="btn" onClick={addInstrument} style={{ marginTop: 8 }}>
            + Add instrument
          </button>
        </div>

        <div style={{ marginTop: 12 }}>
          <DiagnosticList
            diagnostics={dedupeForDisplay(
              diagnosticsFor(diagnostics, "instrument.list"),
            )}
          />
        </div>
      </Section>

      <Section title="Groups">
        <Field
          label="Number of instrument groups"
          helpKey="fields/number-of-instrument-groups"
          path="instrument.number-of-instrument-groups"
          hint="How many groups are drawn per layer. Other parameters use one group per layer unless they are set to combination."
        >
          <input
            type="number"
            className="input--narrow"
            min={1}
            value={project.numberOfInstrumentGroups}
            onChange={(e) =>
              update((p) => (p.numberOfInstrumentGroups = Number(e.target.value)))
            }
          />
        </Field>

        <Field
          label="Instrument table"
          helpKey="fields/instrument-table"
          path="instrument.table"
          hint="Each row is a group of instruments. The numbers are positions in the list above."
        >
          <TableEditor
            table={project.instrumentTable}
            onChange={(v) => update((p) => (p.instrumentTable = v))}
            values={project.instruments.map((i) => i.name || "unnamed")}
            path="instrument.table"
            valueLabel="instrument"
            rowNames={project.instrumentGroupNames}
            onRowNamesChange={(v) => update((p) => (p.instrumentGroupNames = v))}
          />
        </Field>
      </Section>

      <Section title="Selection">
        <Field
          label="Ensemble principle"
          helpKey="fields/instrument-ensemble"
          path="instrument.combination"
          hint="How a group is chosen from the table. Instruments cannot use combination — they are what the other parameters would be following."
        >
          <EnsembleEditor
            ensemble={project.instrumentEnsemble}
            onChange={(v) => update((p) => (p.instrumentEnsemble = v))}
            groupCount={project.instrumentTable.length}
            allowCombination={false}
            groupNames={project.instrumentGroupNames}
          />
        </Field>

        <Field
          label="Order principle"
          helpKey="fields/instrument-order"
          path="instrument.principle"
          hint="How instruments are drawn from within the active group."
        >
          <PrincipleEditor
            principle={project.instrumentPrinciple}
            onChange={(v) => update((p) => (p.instrumentPrinciple = v))}
            values={project.instruments.map((i) => i.name || "unnamed")}
            valueLabel="instrument"
          />
        </Field>
      </Section>
    </div>
  );
}

function InstrumentCard({
  index,
  instrument,
  open,
  onToggle,
}: {
  index: number;
  instrument: Instrument;
  open: boolean;
  onToggle: () => void;
}) {
  const { project, update, diagnostics, startIndexOffset } = useInstrumentCard();
  const path = `instrument[${index}]`;
  const mine = dedupeForDisplay(diagnosticsFor(diagnostics, path));
  const hasError = mine.some((d) => d.severity === "error");

  const set = (mutate: (i: Instrument) => void) =>
    update((p) => mutate(p.instruments[index]));

  const toggle = (field: "performance" | "dynamics", value: string) =>
    set((i) => {
      i[field] = i[field].includes(value)
        ? i[field].filter((v) => v !== value)
        : [...i[field], value];
    });

  return (
    <div className={`instrument${hasError ? " instrument--error" : ""}`}>
      <button type="button" className="instrument__header" onClick={onToggle}>
        <span className="instrument__index">{index + startIndexOffset}</span>
        <span className="instrument__name">{instrument.name || "unnamed"}</span>
        <span className="instrument__summary">
          {instrument.chordSizeMin === instrument.chordSizeMax
            ? `${instrument.chordSizeMin} note${instrument.chordSizeMin === 1 ? "" : "s"}`
            : `${instrument.chordSizeMin}–${instrument.chordSizeMax} notes`}
          {" · "}
          {instrument.performance.length} mode
          {instrument.performance.length === 1 ? "" : "s"}
          {" · "}
          {instrument.dynamics.length} dynamic
          {instrument.dynamics.length === 1 ? "" : "s"}
        </span>
        {hasError && <span className="badge badge--error">!</span>}
        <span className="faint">{open ? "▾" : "▸"}</span>
      </button>

      {open && (
        <div className="instrument__body">
          <div className="grid-2">
            <Field label="Name" helpKey="fields/instruments" path={`${path}.name`}>
              <input
                type="text"
                className="input--medium"
                value={instrument.name}
                onChange={(e) => set((i) => (i.name = e.target.value))}
              />
            </Field>

            <Field
              label="Chord size"
              helpKey="fields/instrument-chordsize"
              path={`${path}.chordsize`}
              hint="Fewest and most notes this instrument can sound at once."
            >
              <div className="field__row">
                <input
                  type="number"
                  className="input--tiny"
                  min={1}
                  value={instrument.chordSizeMin}
                  onChange={(e) => set((i) => (i.chordSizeMin = Number(e.target.value)))}
                />
                <span className="faint">to</span>
                <input
                  type="number"
                  className="input--tiny"
                  min={1}
                  value={instrument.chordSizeMax}
                  onChange={(e) => set((i) => (i.chordSizeMax = Number(e.target.value)))}
                />
              </div>
            </Field>
          </div>

          <div className="grid-2">
            <Field
              label="Compass"
              helpKey="fields/instrument-compass"
              path={`${path}.compass`}
              hint={
                instrument.percussion
                  ? "Percussion instruments have no pitch range - REGISTER will always resolve to its percussion entry for this instrument."
                  : "Lowest and highest pitch, as octave and step."
              }
            >
              <label className="field__row" style={{ marginBottom: 8 }}>
                <input
                  type="checkbox"
                  checked={instrument.percussion}
                  onChange={(e) => set((i) => (i.percussion = e.target.checked))}
                />
                <span>Percussion (no fixed pitch)</span>
              </label>

              {!instrument.percussion && (
                <div className="field__row">
                  <input
                    type="number"
                    className="input--tiny"
                    value={instrument.compassLow.octave}
                    onChange={(e) => set((i) => (i.compassLow.octave = Number(e.target.value)))}
                    title="Lowest octave"
                  />
                  <input
                    type="number"
                    className="input--tiny"
                    value={instrument.compassLow.pitch}
                    onChange={(e) => set((i) => (i.compassLow.pitch = Number(e.target.value)))}
                    title="Lowest step"
                  />
                  <span className="faint">to</span>
                  <input
                    type="number"
                    className="input--tiny"
                    value={instrument.compassHigh.octave}
                    onChange={(e) => set((i) => (i.compassHigh.octave = Number(e.target.value)))}
                    title="Highest octave"
                  />
                  <input
                    type="number"
                    className="input--tiny"
                    value={instrument.compassHigh.pitch}
                    onChange={(e) => set((i) => (i.compassHigh.pitch = Number(e.target.value)))}
                    title="Highest step"
                  />
                </div>
              )}
            </Field>

            <Field
              label="Duration range"
              helpKey="fields/instrument-durations"
              path={`${path}.durations`}
              hint="Shortest and longest note this instrument can hold, in seconds."
            >
              <div className="field__row">
                <input
                  type="text"
                  className="input--tiny"
                  value={instrument.durationMin}
                  onChange={(e) => set((i) => (i.durationMin = e.target.value))}
                />
                <span className="faint">to</span>
                <input
                  type="text"
                  className="input--tiny"
                  value={instrument.durationMax}
                  onChange={(e) => set((i) => (i.durationMax = e.target.value))}
                />
              </div>
            </Field>
          </div>

          <Field
            label="Performance modes"
            helpKey="fields/instrument-performance"
            path={`${path}.performance`}
            hint="Type a new mode to add it. Modes listed here appear automatically in the Performance screen."
          >
            <ModeEditor
              selected={instrument.performance}
              available={project.performance}
              onToggle={(v) => toggle("performance", v)}
              onAdd={(v) =>
                set((i) => {
                  if (v && !i.performance.includes(v)) i.performance.push(v);
                })
              }
            />
          </Field>

          <Field
            label="Dynamics"
            helpKey="fields/instrument-dynamics"
            path={`${path}.dynamics`}
            hint="Which of the dynamics this instrument can actually play."
          >
            <div className="pills">
              {project.dynamics.map((d) => (
                <button
                  type="button"
                  key={d}
                  className={`pill${instrument.dynamics.includes(d) ? " pill--on" : ""}`}
                  onClick={() => toggle("dynamics", d)}
                >
                  {d}
                </button>
              ))}
              {project.dynamics.length === 0 && (
                <span className="faint">Define some dynamics first.</span>
              )}
            </div>
          </Field>

          <div className="row" style={{ justifyContent: "flex-end", marginTop: 4 }}>
            <button
              type="button"
              className="btn btn--small btn--danger"
              onClick={() => update((p) => p.instruments.splice(index, 1))}
            >
              Remove instrument
            </button>
          </div>

          {mine.length > 0 && <DiagnosticList diagnostics={mine} />}
        </div>
      )}
    </div>
  );
}

/**
 * Performance modes are free-form strings rather than a fixed vocabulary, so
 * this offers the modes already in use elsewhere as one-click pills and lets
 * a genuinely new one be typed.
 */
function ModeEditor({
  selected,
  available,
  onToggle,
  onAdd,
}: {
  selected: string[];
  available: string[];
  onToggle: (v: string) => void;
  onAdd: (v: string) => void;
}) {
  const [draft, setDraft] = useState("");
  const known = Array.from(new Set([...available, ...selected]));

  return (
    <div className="stack">
      <div className="pills">
        {known.map((m) => (
          <button
            type="button"
            key={m}
            className={`pill${selected.includes(m) ? " pill--on" : ""}`}
            onClick={() => onToggle(m)}
          >
            {m}
          </button>
        ))}
      </div>
      <div className="field__row">
        <input
          type="text"
          className="input--medium"
          placeholder="New mode, e.g. sul tasto"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              onAdd(draft.trim());
              setDraft("");
            }
          }}
        />
        <button
          type="button"
          className="btn btn--small"
          onClick={() => {
            onAdd(draft.trim());
            setDraft("");
          }}
        >
          Add
        </button>
      </div>
    </div>
  );
}

function useInstrumentCard() {
  const { project, update, diagnostics } = useStore();
  return { project, update, diagnostics, startIndexOffset: project.startIndex };
}
