import { useEffect, useRef, useState } from "react";
import type React from "react";
import { useStore } from "../state/store";
import { HIERARCHY_LABELS } from "../schema/types";
import type { HierarchyElem } from "../schema/types";
import { shadowHierarchyNote, shadowedByEquality } from "../schema/shadowed";

/**
 * Reusable pointer-driven drag reordering, shared by every list in the GUI
 * that has a meaningful order (the hierarchy, a parameter's own value list, a
 * register list, ...).
 *
 * Pointer events rather than the HTML5 drag-and-drop API, for the same
 * reason [HierarchyEditor] originally chose them: WebKitGTK/Wayland's drop
 * event is unreliable, pointer events are not. Position is found by nearest
 * bounding-rect *center* rather than a simple vertical band, so this also
 * works for a wrapping horizontal layout (the token list) and not just a
 * single-column vertical stack (the hierarchy).
 */
export function useDragReorder<T>(items: T[], onChange: (next: T[]) => void) {
  const [dragging, setDragging] = useState<number | null>(null);
  const dragIndex = useRef<number | null>(null);
  const itemRefs = useRef<(HTMLElement | null)[]>([]);

  const move = (from: number, to: number) => {
    if (from === to) return;
    const next = [...items];
    const [item] = next.splice(from, 1);
    next.splice(to, 0, item);
    onChange(next);
  };

  const setRef = (i: number) => (el: HTMLElement | null) => {
    itemRefs.current[i] = el;
  };

  const beginDrag = (e: React.PointerEvent, index: number) => {
    if (e.button !== 0) return;
    // Stops the press turning into a text selection while dragging.
    e.preventDefault();
    e.currentTarget.setPointerCapture(e.pointerId);
    dragIndex.current = index;
    setDragging(index);
  };

  const onDragMove = (e: React.PointerEvent) => {
    const from = dragIndex.current;
    if (from === null) return;
    const rects = itemRefs.current.map((el) => el?.getBoundingClientRect() ?? null);
    const target = nearestIndex(rects, e.clientX, e.clientY);
    if (target !== null && target !== from) {
      move(from, target);
      dragIndex.current = target;
      setDragging(target);
    }
  };

  const endDrag = (e: React.PointerEvent) => {
    if (dragIndex.current === null) return;
    if (e.currentTarget.hasPointerCapture(e.pointerId)) {
      e.currentTarget.releasePointerCapture(e.pointerId);
    }
    dragIndex.current = null;
    setDragging(null);
  };

  return { dragging, setRef, beginDrag, onDragMove, endDrag, move };
}

/** The item whose bounding-rect center is nearest the pointer. */
function nearestIndex(rects: (DOMRect | null)[], x: number, y: number): number | null {
  let best: number | null = null;
  let bestDist = Infinity;
  rects.forEach((r, i) => {
    if (!r) return;
    const cx = r.left + r.width / 2;
    const cy = r.top + r.height / 2;
    const dist = (cx - x) ** 2 + (cy - y) ** 2;
    if (dist < bestDist) {
      bestDist = dist;
      best = i;
    }
  });
  return best;
}

/**
 * A parameter's list: the raw supply of values everything else indexes into.
 *
 * Each entry shows its index, because the index is what the tables refer to.
 * Seeing "3 → mf" here and "3" in the table is what connects the two halves
 * of the chain. Order is meaningful (e.g. for the `sequence` principle, or
 * simply for the composer's own bookkeeping), so entries can be dragged by
 * their grip to reorder them - this changes which index each *other* value
 * has, so double-check any table that already refers to this list by index
 * after reordering it.
 *
 * Values that appear more than once are marked, not blocked: a repeated
 * value is never invalid here (a table row's *indices* are what a duplicate
 * check should actually gate, since that is where repetition changes
 * meaning under some principles), but it is easy to type by accident, so
 * it's worth a quiet visual note.
 */
export function TokenListEditor({
  values,
  onChange,
  placeholder,
  readOnly = false,
  invalid,
  bulkPlaceholder,
}: {
  values: string[];
  onChange?: (v: string[]) => void;
  placeholder?: string;
  readOnly?: boolean;
  /** Returns true when this entry is malformed, e.g. an unparseable number. */
  invalid?: (value: string, index: number) => boolean;
  /** Example text for the bulk-entry box, e.g. "1 2 3 p 5 7 9 11 12". */
  bulkPlaceholder?: string;
}) {
  const { project } = useStore();
  const offset = project.startIndex;
  const { dragging, setRef, beginDrag, onDragMove, endDrag } = useDragReorder(
    values,
    (next) => onChange?.(next),
  );
  const duplicates = duplicateValues(values);
  const [bulkDraft, setBulkDraft] = useState(() => values.join(" "));
  const bulkFocused = useRef(false);
  const commitButtonRef = useRef<HTMLButtonElement>(null);

  // Keeps the bulk box showing the list's current serialization - so a drag
  // reorder, an add/remove, or editing a pill's own value all show up here
  // too - except while the composer is actively typing in it, so an edit in
  // progress here is never clobbered by an edit happening elsewhere.
  useEffect(() => {
    if (!bulkFocused.current) setBulkDraft(values.join(" "));
  }, [values]);

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

  // Whatever tokens come out just become the new list - the pills' own
  // [invalid]/duplicate highlighting takes it from there, same as if each
  // token had been typed by hand.
  const commitBulk = () => {
    const tokens = bulkDraft.trim().split(/\s+/).filter(Boolean);
    if (tokens.length > 0) {
      onChange?.(tokens);
      setBulkDraft(tokens.join(" "));
    }
  };

  return (
    <div className="token-list-editor">
      <div className="token-list-bulk">
        <input
          type="text"
          className="token-list-bulk__input"
          value={bulkDraft}
          placeholder={bulkPlaceholder ?? "Type the whole list, space-separated"}
          onFocus={() => {
            bulkFocused.current = true;
          }}
          onBlur={(e) => {
            bulkFocused.current = false;
            // Tabbing to the commit button also blurs the input first, same
            // as a mouse click does - but here focus genuinely does move (a
            // keyboard Tab can't be blocked the way the button's own
            // mousedown is, without breaking normal tab order). relatedTarget
            // says where focus is headed, so a reset is skipped exactly when
            // it's headed for the button about to read this same draft.
            if (e.relatedTarget === commitButtonRef.current) return;
            setBulkDraft(values.join(" "));
          }}
          onChange={(e) => setBulkDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              commitBulk();
            }
          }}
        />
        <button
          ref={commitButtonRef}
          type="button"
          className="btn btn--ghost btn--small"
          // A plain mouse click blurs the input first (focus moves to the
          // button before the click fires), which would run the blur handler
          // above and reset the draft to the *old* list before commitBulk
          // ever sees it. Blocking the mousedown's default keeps focus - and
          // the just-typed draft - in the input until commitBulk has read it.
          // (Keyboard Tab-then-Enter is handled separately, via the blur
          // handler's relatedTarget check above, since a Tab's focus change
          // can't be blocked the same way without breaking tab order.)
          onMouseDown={(e) => e.preventDefault()}
          onClick={commitBulk}
          title="Replace the whole list with what's typed above"
        >
          Set list
        </button>
      </div>
      <div className="token-list">
        {values.map((v, i) => (
        <span
          ref={setRef(i)}
          className={
            "token" +
            (invalid?.(v, i) ? " is-error" : "") +
            (v !== "" && duplicates.has(v) ? " token--duplicate" : "") +
            (dragging === i ? " token--dragging" : "")
          }
          key={i}
          title={v !== "" && duplicates.has(v) ? `"${v}" appears more than once in this list` : undefined}
        >
          <span
            className="token__grip"
            onPointerDown={(e) => beginDrag(e, i)}
            onPointerMove={onDragMove}
            onPointerUp={endDrag}
            onPointerCancel={endDrag}
            title="Drag to reorder"
            aria-hidden
          >
            ⣿
          </span>
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
    </div>
  );
}

/** Values (ignoring blanks) that occur more than once. */
export function duplicateValues<T>(values: T[]): Set<T> {
  const seen = new Set<T>();
  const dupes = new Set<T>();
  for (const v of values) {
    if (v === "") continue;
    if (seen.has(v)) dupes.add(v);
    seen.add(v);
  }
  return dupes;
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
 *
 * This uses pointer events rather than the HTML5 drag-and-drop API. WebKitGTK
 * implements HTML5 dragging poorly and under Wayland the `drop` event
 * frequently never arrives, so the row lifts but cannot be released. Pointer
 * events have none of that history and behave the same on every platform.
 *
 * Rows reorder live as the pointer passes them rather than on release, which
 * removes the notion of a drop target altogether: there is nothing to miss.
 * Keying each row by its element name is what makes this work - the dragged
 * DOM node keeps its identity as the list reorders around it, so it retains
 * the captured pointer.
 */
export function HierarchyEditor({
  hierarchy,
  onChange,
}: {
  hierarchy: HierarchyElem[];
  onChange: (h: HierarchyElem[]) => void;
}) {
  const { dragging, setRef, beginDrag, onDragMove, endDrag, move } = useDragReorder(
    hierarchy,
    onChange,
  );
  const { project } = useStore();
  const shadow = shadowedByEquality(project);

  return (
    <div className="hierarchy">
      {hierarchy.map((elem, i) => (
        <div
          key={elem}
          ref={setRef(i)}
          className={
            "hierarchy__item" + (dragging === i ? " hierarchy__item--dragging" : "")
          }
          onPointerDown={(e) => beginDrag(e, i)}
          onPointerMove={onDragMove}
          onPointerUp={endDrag}
          onPointerCancel={endDrag}
        >
          <span className="hierarchy__rank">{i + 1}</span>
          <span className="hierarchy__grip" aria-hidden>
            ⣿
          </span>
          <span className="hierarchy__name">{HIERARCHY_LABELS[elem]}</span>
          <span
            className={
              "hierarchy__note" +
              (shadow?.ignored === elem ? " hierarchy__note--ignored" : "")
            }
          >
            {(shadow && shadowHierarchyNote(elem, shadow)) || noteFor(elem, i, hierarchy)}
          </span>

          {/* Keyboard equivalent: dragging alone would make the ordering
              unreachable without a mouse. The pointer-down guard keeps a
              click on these from being read as the start of a drag. */}
          <button
            type="button"
            className="btn btn--ghost btn--icon"
            disabled={i === 0}
            onPointerDown={(e) => e.stopPropagation()}
            onClick={() => move(i, i - 1)}
            title="Move earlier"
          >
            ↑
          </button>
          <button
            type="button"
            className="btn btn--ghost btn--icon"
            disabled={i === hierarchy.length - 1}
            onPointerDown={(e) => e.stopPropagation()}
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
