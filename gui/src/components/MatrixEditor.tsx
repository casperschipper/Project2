/**
 * A dense `(tr-1) x (tr-1)` grid of checkboxes for HARMONY's INTERVAL
 * principle transition matrix (EMR-3 8.2, entries 21-24) - real
 * `<input type="checkbox">` cells rather than a custom click target, so
 * what's rendered is always exactly what gets toggled, and no state can
 * exist that isn't a plain boolean grid. Rows are the "given" interval,
 * columns the "succeeding" interval allowed to follow it - checking cell
 * `[i][j]` means interval `j+1` may immediately follow interval `i+1`.
 *
 * The matrix itself always auto-resizes to match `octaveDivision` (see
 * `resizeIntervalMatrix` in `schema/defaults.ts`), so `size` here is always
 * exactly `value.length` in practice - it's taken as its own prop only so a
 * mismatched `value` (e.g. freshly loaded from a hand-edited file) still
 * renders something sensible rather than crashing on a ragged array.
 *
 * `readOnly` renders the same grid with every cell disabled - used for the
 * live preview while "derive from chord" is active, where the matrix is a
 * result to look at, not something to hand-edit directly (see
 * `HarmonyScreen`'s "Use as editable matrix" button for switching to that).
 */
export function MatrixEditor({
  size,
  value,
  onChange,
  readOnly = false,
}: {
  size: number;
  value: boolean[][];
  onChange?: (next: boolean[][]) => void;
  readOnly?: boolean;
}) {
  const cellAt = (i: number, j: number) => value[i]?.[j] ?? false;

  const toggle = (i: number, j: number) => {
    if (readOnly || !onChange) return;
    const next = Array.from({ length: size }, (_, ri) =>
      Array.from({ length: size }, (_, ci) =>
        ri === i && ci === j ? !cellAt(ri, ci) : cellAt(ri, ci),
      ),
    );
    onChange(next);
  };

  if (size <= 0) {
    return (
      <div className="empty-note">
        Tones-per-octave is too small for an interval matrix (needs at least 2).
      </div>
    );
  }

  return (
    <div className={`matrix-editor${readOnly ? " matrix-editor--readonly" : ""}`}>
      <table className="matrix-editor__table">
        <thead>
          <tr>
            <th className="matrix-editor__corner" title="given ↓ / succeeding →">
              ↓ / →
            </th>
            {Array.from({ length: size }, (_, j) => (
              <th
                key={j}
                className="matrix-editor__col-header"
                title={`Succeeding interval ${j + 1}`}
              >
                {j + 1}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {Array.from({ length: size }, (_, i) => (
            <tr key={i}>
              <th className="matrix-editor__row-header" title={`Given interval ${i + 1}`}>
                {i + 1}
              </th>
              {Array.from({ length: size }, (_, j) => (
                <td key={j} className="matrix-editor__cell">
                  <input
                    type="checkbox"
                    checked={cellAt(i, j)}
                    disabled={readOnly}
                    onChange={() => toggle(i, j)}
                    aria-label={`interval ${i + 1} may be followed by interval ${j + 1}`}
                  />
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
