import { useState } from "react";
import { useStore } from "../state/store";
import { HIERARCHY_LABELS } from "../schema/types";
import type { HierarchyElem } from "../schema/types";

/**
 * A parameter's list: the raw supply of values everything else indexes into.
 *
 * Each entry shows its index, because the index is what the tables refer to.
 * Seeing "3 → mf" here and "3" in the table is what connects the two halves
 * of the chain.
 */
export function TokenListEditor({
  values,
  onChange,
  placeholder,
  readOnly = false,
  invalid,
}: {
  values: string[];
  onChange?: (v: string[]) => void;
  placeholder?: string;
  readOnly?: boolean;
  /** Returns true when this entry is malformed, e.g. an unparseable number. */
  invalid?: (value: string, index: number) => boolean;
}) {
  const { project } = useStore();
  const offset = project.startIndex;

  if (readOnly) {
    return (
      <div className="token-list">
        {values.length === 0 && <span className="faint">Nothing here yet.</span>}
        {values.map((v, i) => (
          <span className="token token--readonly" key={i}>
            <span className="token__index">{i + offset}</span>
            {v}
          </span>
        ))}
      </div>
    );
  }

  const set = (i: number, value: string) =>
    onChange?.(values.map((v, j) => (j === i ? value : v)));

  return (
    <div className="token-list">
      {values.map((v, i) => (
        <span className={`token${invalid?.(v, i) ? " is-error" : ""}`} key={i}>
          <span className="token__index">{i + offset}</span>
          <input
            className="token__input"
            value={v}
            placeholder={placeholder}
            onChange={(e) => set(i, e.target.value)}
            onKeyDown={(e) => {
              // Enter appends, so a list can be typed without reaching for
              // the mouse between entries.
              if (e.key === "Enter") {
                e.preventDefault();
                onChange?.([...values.slice(0, i + 1), "", ...values.slice(i + 1)]);
              }
            }}
          />
          <button
            type="button"
            className="token__remove"
            onClick={() => onChange?.(values.filter((_, j) => j !== i))}
            title="Remove"
          >
            ×
          </button>
        </span>
      ))}
      <button
        type="button"
        className="btn btn--ghost btn--small"
        onClick={() => onChange?.([...values, ""])}
      >
        + Add
      </button>
    </div>
  );
}

/**
 * The hierarchy: a total ordering of the five parameters, reordered by
 * dragging.
 *
 * Order is meaningful rather than cosmetic - a parameter resolved earlier
 * constrains the ones after it, and several rules in the engine depend on
 * what precedes what. The note beside each row states the consequence of its
 * current position so the effect of a drag is legible without leaving the
 * screen.
 */
export function HierarchyEditor({
  hierarchy,
  onChange,
}: {
  hierarchy: HierarchyElem[];
  onChange: (h: HierarchyElem[]) => void;
}) {
  const [dragging, setDragging] = useState<number | null>(null);
  const [over, setOver] = useState<number | null>(null);

  const move = (from: number, to: number) => {
    if (from === to) return;
    const next = [...hierarchy];
    const [item] = next.splice(from, 1);
    next.splice(to, 0, item);
    onChange(next);
  };

  return (
    <div className="hierarchy">
      {hierarchy.map((elem, i) => (
        <div
          key={elem}
          className={
            "hierarchy__item" +
            (dragging === i ? " hierarchy__item--dragging" : "") +
            (over === i && dragging !== null && dragging !== i ? " hierarchy__item--over" : "")
          }
          draggable
          onDragStart={() => setDragging(i)}
          onDragEnd={() => {
            setDragging(null);
            setOver(null);
          }}
          onDragOver={(e) => {
            e.preventDefault();
            setOver(i);
          }}
          onDrop={(e) => {
            e.preventDefault();
            if (dragging !== null) move(dragging, i);
            setDragging(null);
            setOver(null);
          }}
        >
          <span className="hierarchy__rank">{i + 1}</span>
          <span className="hierarchy__grip" aria-hidden>
            ⣿
          </span>
          <span className="hierarchy__name">{HIERARCHY_LABELS[elem]}</span>
          <span className="hierarchy__note">{noteFor(elem, i, hierarchy)}</span>

          {/* Keyboard equivalent: dragging alone would make the ordering
              unreachable without a mouse. */}
          <button
            type="button"
            className="btn btn--ghost btn--icon"
            disabled={i === 0}
            onClick={() => move(i, i - 1)}
            title="Move earlier"
          >
            ↑
          </button>
          <button
            type="button"
            className="btn btn--ghost btn--icon"
            disabled={i === hierarchy.length - 1}
            onClick={() => move(i, i + 1)}
            title="Move later"
          >
            ↓
          </button>
        </div>
      ))}
    </div>
  );
}

/** A short statement of what this parameter's position currently implies. */
function noteFor(elem: HierarchyElem, index: number, hierarchy: HierarchyElem[]): string {
  if (index === 0) return "resolved first, unconstrained";
  const insIndex = hierarchy.indexOf("Ins");
  if (elem === "Ins") return "constrained by what came before";
  if (insIndex < index) return "constrained by the chosen instrument";
  return "chosen before the instrument";
}
