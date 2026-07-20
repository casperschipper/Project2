import { useState } from "react";
import { useStore } from "../state/store";
import { diagnosticsFor } from "../engine/diagnostics";
import type { Table } from "../schema/types";

/**
 * The table editor.
 *
 * A table row is a group, and a cell is an *index into the parameter's own
 * list* - not a value. That indirection is the thing composers most often
 * trip over, so the editor makes it visible: every cell shows the index and,
 * beside it, the value that index actually resolves to. When an index points
 * nowhere the cell turns red and says so, rather than waiting for the engine
 * to fail on a formula that looked fine.
 *
 * Indices are stored 0-based (what the engine reads) but displayed according
 * to the project's start-index setting, so a composer used to counting from 1
 * can work that way without the file changing meaning.
 */
export function TableEditor({
  table,
  onChange,
  /** The list this table indexes into, already rendered as display strings. */
  values,
  path,
  valueLabel,
}: {
  table: Table;
  onChange: (next: Table) => void;
  values: string[];
  /** Diagnostic path of the table, e.g. `dynamics.table`. */
  path: string;
  /** What one element is called, for tooltips: "dynamic", "entry delay", ... */
  valueLabel: string;
}) {
  const { project, diagnostics } = useStore();
  const offset = project.startIndex;

  const setRow = (r: number, row: number[]) => {
    const next = table.map((existing, i) => (i === r ? row : existing));
    onChange(next);
  };

  const addRow = () => onChange([...table, []]);
  const removeRow = (r: number) => onChange(table.filter((_, i) => i !== r));
  const duplicateRow = (r: number) =>
    onChange([...table.slice(0, r + 1), [...table[r]], ...table.slice(r + 1)]);

  if (table.length === 0) {
    return (
      <div className="stack">
        <div className="empty-note">
          No groups yet. A table needs at least one group.
        </div>
        <div>
          <button type="button" className="btn btn--small" onClick={addRow}>
            + Add group
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="table-editor">
      {table.map((row, r) => {
        const rowPath = `${path}.row[${r}]`;
        const rowHasError = diagnosticsFor(diagnostics, rowPath).some(
          (d) => d.severity === "error",
        );

        return (
          <div
            key={r}
            className={`table-editor__row${rowHasError ? " table-editor__row--error" : ""}`}
          >
            <div className="table-editor__group-label">
              Group {r + offset}
            </div>

            <div className="table-editor__cells">
              {row.map((cell, c) => (
                <Cell
                  key={c}
                  index={cell}
                  offset={offset}
                  values={values}
                  valueLabel={valueLabel}
                  onChange={(v) =>
                    setRow(
                      r,
                      row.map((existing, i) => (i === c ? v : existing)),
                    )
                  }
                  onRemove={() =>
                    setRow(
                      r,
                      row.filter((_, i) => i !== c),
                    )
                  }
                />
              ))}
              <button
                type="button"
                className="btn btn--ghost btn--small"
                onClick={() => setRow(r, [...row, nextIndex(row, values.length)])}
                title="Add an element to this group"
              >
                +
              </button>
            </div>

            <div className="table-editor__actions">
              <button
                type="button"
                className="btn btn--ghost btn--icon"
                onClick={() => duplicateRow(r)}
                title="Duplicate this group"
              >
                ⧉
              </button>
              <button
                type="button"
                className="btn btn--ghost btn--icon btn--danger"
                onClick={() => removeRow(r)}
                title="Remove this group"
              >
                ×
              </button>
            </div>
          </div>
        );
      })}

      <div className="table-editor__footer">
        <button type="button" className="btn btn--small" onClick={addRow}>
          + Add group
        </button>
      </div>
    </div>
  );
}

/** Suggest the next unused index so adding a cell usually needs no editing. */
function nextIndex(row: number[], listLength: number): number {
  for (let i = 0; i < listLength; i += 1) if (!row.includes(i)) return i;
  return 0;
}

function Cell({
  index,
  offset,
  values,
  valueLabel,
  onChange,
  onRemove,
}: {
  index: number;
  offset: 0 | 1;
  values: string[];
  valueLabel: string;
  onChange: (v: number) => void;
  onRemove: () => void;
}) {
  const [hover, setHover] = useState(false);
  const defined = Number.isInteger(index) && index >= 0 && index < values.length;
  const value = defined ? values[index] : null;

  return (
    <span
      className={`cell ${defined ? "cell--defined" : "cell--undefined"} tooltip`}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
    >
      <input
        className="cell__input"
        type="number"
        value={index + offset}
        onChange={(e) => {
          const raw = Number(e.target.value);
          onChange(Number.isNaN(raw) ? 0 : raw - offset);
        }}
        aria-label={`Index ${index + offset}`}
      />
      <span className="cell__value">{defined ? value : "?"}</span>
      <button
        type="button"
        className="cell__remove"
        onClick={onRemove}
        aria-label="Remove"
        title="Remove from group"
      >
        ×
      </button>
      {hover && (
        <span className="tooltip__content">
          {defined
            ? `Index ${index + offset} → ${valueLabel} “${value}”`
            : values.length === 0
              ? `Index ${index + offset} points into an empty list`
              : `Index ${index + offset} does not exist — valid indices are ${offset} to ${
                  values.length - 1 + offset
                }`}
        </span>
      )}
    </span>
  );
}
