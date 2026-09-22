import type React from "react";
import { useStore } from "../state/store";
import { Field, Section, PercussionSwitch } from "../components/Field";
import { TableEditor } from "../components/TableEditor";
import { useDragReorder, duplicateValues } from "../components/ListEditors";
import { EnsembleEditor, PrincipleEditor } from "../components/PrincipleEditor";
import { registerLabel } from "../schema/types";
import type { NoteMode, Register } from "../schema/types";

/**
 * REGISTER (EMR-3 7.1): the range of absolute pitches a tone may be placed
 * in - or, for a percussion entry, that it has no pitch at all (never PR-2's
 * (0,0) sentinel). See the Harmony screen for the other half of how a note's
 * pitch is decided; their relative order in the Structure screen's hierarchy
 * decides which one constrains the other for a given note.
 */
export function RegisterScreen() {
  const { project, update } = useStore();
  const labels = project.registers.map(registerLabel);

  const addRegister = () =>
    update((p) => {
      p.registers.push({
        kind: "pitch",
        low: { octave: 1, pitch: 1 },
        high: { octave: 5, pitch: 12 },
      });
    });

  const { dragging, setRef, beginDrag, onDragMove, endDrag } = useDragReorder(
    project.registers,
    (next) => update((p) => (p.registers = next)),
  );
  const duplicates = duplicateValues(project.registers.map((r) => JSON.stringify(r)));

  return (
    <div className="screen">
      <h1 className="screen__title">Register</h1>
      <p className="screen__intro">
        Which octave range a tone is placed in - or, for a percussion instrument, that it
        has no pitch at all. See the Harmony screen for the relative pitch this range
        eventually gets combined with.
      </p>

      <Section title="Registers — the supply of pitch ranges">
        <Field
          label="Registers"
          helpKey="fields/register-list"
          path="register.list"
          hint="A range between two absolute pitches (octave + step), or an explicit percussion entry. Drag the grip to reorder; reordering changes which index every other value here has."
        >
          <div className="stack">
            {project.registers.map((r, i) => (
              <RegisterRow
                key={i}
                index={i}
                register={r}
                setRef={setRef(i)}
                dragging={dragging === i}
                duplicate={duplicates.has(JSON.stringify(r))}
                onDragHandlers={{
                  onPointerDown: (e) => beginDrag(e, i),
                  onPointerMove: onDragMove,
                  onPointerUp: endDrag,
                  onPointerCancel: endDrag,
                }}
                onChange={(next) =>
                  update((p) => {
                    p.registers[i] = next;
                  })
                }
                onRemove={() =>
                  update((p) => {
                    p.registers.splice(i, 1);
                  })
                }
              />
            ))}
            {project.registers.length === 0 && (
              <div className="empty-note">No registers yet.</div>
            )}
            <button type="button" className="btn btn--ghost btn--small" onClick={addRegister}>
              + Add register
            </button>
          </div>
        </Field>
      </Section>

      <Section title="Table — groups of indices into the list">
        <Field
          label="Table"
          helpKey="fields/register-table"
          path="register.table"
          hint="Each row is a group. The numbers are positions in the list above, not values."
        >
          <TableEditor
            table={project.registerTable}
            onChange={(v) => update((p) => (p.registerTable = v))}
            values={labels}
            path="register.table"
            valueLabel="register"
            readOnlyRowLabels={project.instrumentGroupNames}
          />
        </Field>
      </Section>

      <Section title="Ensemble — which group is active">
        <Field
          label="Ensemble principle"
          helpKey="fields/register-ensemble"
          path="register.combination"
          hint="How a group is chosen from the table for each layer."
        >
          <EnsembleEditor
            ensemble={project.registerEnsemble}
            onChange={(v) => update((p) => (p.registerEnsemble = v))}
            groupCount={project.registerTable.length}
          />
        </Field>
      </Section>

      <Section title="Order — how values are drawn from the ensemble">
        <Field
          label="Order principle"
          helpKey="fields/register-order"
          path="register.principle"
          hint="How successive registers are selected from within the active ensemble."
        >
          <PrincipleEditor
            principle={project.registerPrinciple}
            onChange={(v) => update((p) => (p.registerPrinciple = v))}
            values={labels}
            valueLabel="register"
          />
        </Field>

        <Field
          label="Chord or note"
          helpKey="fields/register-mode"
          path="register.mode"
          hint="Whether one register covers a whole chord, or each note gets its own."
        >
          <select
            style={{ width: 340 }}
            value={project.registerMode}
            onChange={(e) => update((p) => (p.registerMode = e.target.value as NoteMode))}
          >
            <option value="per-chord">Per chord — one value shared by every note</option>
            <option value="per-note">Per note — drawn again for each note</option>
          </select>
        </Field>
      </Section>
    </div>
  );
}

function RegisterRow({
  index,
  register,
  setRef,
  dragging,
  duplicate,
  onDragHandlers,
  onChange,
  onRemove,
}: {
  index: number;
  register: Register;
  setRef: (el: HTMLElement | null) => void;
  dragging: boolean;
  duplicate: boolean;
  onDragHandlers: {
    onPointerDown: React.PointerEventHandler;
    onPointerMove: React.PointerEventHandler;
    onPointerUp: React.PointerEventHandler;
    onPointerCancel: React.PointerEventHandler;
  };
  onChange: (next: Register) => void;
  onRemove: () => void;
}) {
  const { project } = useStore();
  const isPercussion = register.kind === "percussion";

  return (
    <div
      ref={setRef}
      className={
        "token register-row" +
        (dragging ? " token--dragging" : "") +
        (duplicate ? " token--duplicate" : "")
      }
      title={duplicate ? "This register is identical to another one in the list" : undefined}
    >
      <div className="field__row">
        <span
          className="token__grip"
          title="Drag to reorder"
          aria-hidden
          {...onDragHandlers}
        >
          ⣿
        </span>
        <span className="token__index">{index + project.startIndex}</span>
        <PercussionSwitch
          percussion={isPercussion}
          onChange={(percussion) =>
            onChange(
              percussion
                ? { kind: "percussion" }
                : {
                    kind: "pitch",
                    low: { octave: 1, pitch: 1 },
                    high: { octave: 5, pitch: 12 },
                  },
            )
          }
        />
        <button
          type="button"
          className="token__remove"
          onClick={onRemove}
          title="Remove"
          style={{ marginLeft: "auto" }}
        >
          ×
        </button>
      </div>

      {!isPercussion && register.kind === "pitch" && (
        <div className="pitch-range-grid">
          <span />
          <span className="faint">Octave</span>
          <span className="faint">Relative pitch</span>

          <span className="faint">Low</span>
          <input
            type="number"
            className="input--tiny"
            value={register.low.octave}
            onChange={(e) =>
              onChange({ ...register, low: { ...register.low, octave: Number(e.target.value) } })
            }
            title="Lowest octave"
          />
          <input
            type="number"
            className="input--tiny"
            value={register.low.pitch}
            onChange={(e) =>
              onChange({ ...register, low: { ...register.low, pitch: Number(e.target.value) } })
            }
            title="Lowest step"
          />

          <span className="faint">High</span>
          <input
            type="number"
            className="input--tiny"
            value={register.high.octave}
            onChange={(e) =>
              onChange({ ...register, high: { ...register.high, octave: Number(e.target.value) } })
            }
            title="Highest octave"
          />
          <input
            type="number"
            className="input--tiny"
            value={register.high.pitch}
            onChange={(e) =>
              onChange({ ...register, high: { ...register.high, pitch: Number(e.target.value) } })
            }
            title="Highest step"
          />
        </div>
      )}
    </div>
  );
}
