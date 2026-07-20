import { useStore } from "../state/store";
import type { Ensemble, Principle, PrincipleKind, EnsembleKind } from "../schema/types";

/**
 * Choosing and configuring a selection principle.
 *
 * A dropdown picks the principle and only the fields that principle actually
 * needs appear beneath it - a tendency mask shows its sections, a group shows
 * its repetition bounds, alea and series show nothing at all. Switching
 * principles keeps whatever the new one can use and quietly supplies sensible
 * defaults for the rest, so experimenting between them is cheap.
 */

const PRINCIPLE_LABELS: Record<PrincipleKind, string> = {
  alea: "Alea — free random choice",
  series: "Series — each element once before repeating",
  sequence: "Sequence — a fixed order you specify",
  ratio: "Ratio — weighted proportions",
  group: "Group — repeated runs of the same element",
  tendency: "Tendency — a mask that moves across the list over time",
};

const ENSEMBLE_LABELS: Record<EnsembleKind, string> = {
  alea: "Alea — free random choice of group",
  series: "Series — each group once before repeating",
  sequence: "Sequence — a fixed order of groups",
  combination: "Combination — follow the instrument groups",
};

function defaultPrinciple(kind: PrincipleKind, listLength: number): Principle {
  switch (kind) {
    case "alea":
      return { kind: "alea" };
    case "series":
      return { kind: "series" };
    case "sequence":
      return { kind: "sequence", values: listLength > 0 ? [0] : [] };
    case "ratio":
      return {
        kind: "ratio",
        pairs: Array.from({ length: listLength }, (_, i) => ({ index: i, weight: 1 })),
      };
    case "group":
      return {
        kind: "group",
        element: "series",
        repetition: "series",
        minRepetitions: 1,
        maxRepetitions: 3,
      };
    case "tendency":
      return {
        kind: "tendency",
        sections: [{ portion: 1, startMin: 0, startMax: 1, endMin: 0, endMax: 1 }],
      };
  }
}

export function PrincipleEditor({
  principle,
  onChange,
  values,
  valueLabel,
}: {
  principle: Principle;
  onChange: (p: Principle) => void;
  /** Display strings of the list this principle draws from. */
  values: string[];
  valueLabel: string;
}) {
  const { project } = useStore();
  const offset = project.startIndex;

  return (
    <div className="stack">
      <select
        className="input--medium"
        value={principle.kind}
        onChange={(e) => onChange(defaultPrinciple(e.target.value as PrincipleKind, values.length))}
        style={{ width: 340 }}
      >
        {(Object.keys(PRINCIPLE_LABELS) as PrincipleKind[]).map((k) => (
          <option key={k} value={k}>
            {PRINCIPLE_LABELS[k]}
          </option>
        ))}
      </select>

      {principle.kind === "sequence" && (
        <IndexSequenceEditor
          values={principle.values}
          onChange={(v) => onChange({ kind: "sequence", values: v })}
          list={values}
          valueLabel={valueLabel}
          offset={offset}
        />
      )}

      {principle.kind === "ratio" && (
        <RatioEditor principle={principle} onChange={onChange} list={values} offset={offset} />
      )}

      {principle.kind === "group" && (
        <div className="stack" style={{ maxWidth: 460 }}>
          <div className="field__row">
            <label className="faint" style={{ width: 130 }}>
              Choose element by
            </label>
            <select
              className="input--medium"
              value={principle.element}
              onChange={(e) =>
                onChange({ ...principle, element: e.target.value as "alea" | "series" })
              }
            >
              <option value="alea">Alea</option>
              <option value="series">Series</option>
            </select>
          </div>
          <div className="field__row">
            <label className="faint" style={{ width: 130 }}>
              Choose run length by
            </label>
            <select
              className="input--medium"
              value={principle.repetition}
              onChange={(e) =>
                onChange({ ...principle, repetition: e.target.value as "alea" | "series" })
              }
            >
              <option value="alea">Alea</option>
              <option value="series">Series</option>
            </select>
          </div>
          <div className="field__row">
            <label className="faint" style={{ width: 130 }}>
              Run length
            </label>
            <input
              type="number"
              className="input--tiny"
              min={1}
              value={principle.minRepetitions}
              onChange={(e) =>
                onChange({ ...principle, minRepetitions: Number(e.target.value) })
              }
            />
            <span className="faint">to</span>
            <input
              type="number"
              className="input--tiny"
              min={1}
              value={principle.maxRepetitions}
              onChange={(e) =>
                onChange({ ...principle, maxRepetitions: Number(e.target.value) })
              }
            />
            <span className="faint">times</span>
          </div>
        </div>
      )}

      {principle.kind === "tendency" && (
        <TendencyEditor principle={principle} onChange={onChange} />
      )}
    </div>
  );
}

export function EnsembleEditor({
  ensemble,
  onChange,
  groupCount,
  allowCombination = true,
}: {
  ensemble: Ensemble;
  onChange: (e: Ensemble) => void;
  groupCount: number;
  /** Instruments may not combine: they are what the others would follow. */
  allowCombination?: boolean;
}) {
  const { project } = useStore();
  const offset = project.startIndex;

  const kinds = (Object.keys(ENSEMBLE_LABELS) as EnsembleKind[]).filter(
    (k) => allowCombination || k !== "combination",
  );

  return (
    <div className="stack">
      <select
        value={ensemble.kind}
        onChange={(e) => {
          const kind = e.target.value as EnsembleKind;
          onChange(kind === "sequence" ? { kind, values: [0] } : ({ kind } as Ensemble));
        }}
        style={{ width: 340 }}
      >
        {kinds.map((k) => (
          <option key={k} value={k}>
            {ENSEMBLE_LABELS[k]}
          </option>
        ))}
      </select>

      {ensemble.kind === "sequence" && (
        <IndexSequenceEditor
          values={ensemble.values}
          onChange={(v) => onChange({ kind: "sequence", values: v })}
          list={Array.from({ length: groupCount }, (_, i) => `group ${i + offset}`)}
          valueLabel="group"
          offset={offset}
        />
      )}
    </div>
  );
}

/** An ordered run of indices, shown with what each one resolves to. */
function IndexSequenceEditor({
  values,
  onChange,
  list,
  valueLabel,
  offset,
}: {
  values: number[];
  onChange: (v: number[]) => void;
  list: string[];
  valueLabel: string;
  offset: 0 | 1;
}) {
  return (
    <div className="token-list">
      {values.map((v, i) => {
        const defined = v >= 0 && v < list.length;
        return (
          <span
            key={i}
            className={`cell ${defined ? "cell--defined" : "cell--undefined"}`}
            title={
              defined
                ? `Position ${i + 1}: ${valueLabel} “${list[v]}”`
                : `Index ${v + offset} does not exist`
            }
          >
            <input
              className="cell__input"
              type="number"
              value={v + offset}
              onChange={(e) =>
                onChange(values.map((x, j) => (j === i ? Number(e.target.value) - offset : x)))
              }
            />
            <span className="cell__value">{defined ? list[v] : "?"}</span>
            <button
              type="button"
              className="cell__remove"
              onClick={() => onChange(values.filter((_, j) => j !== i))}
              title="Remove"
            >
              ×
            </button>
          </span>
        );
      })}
      <button
        type="button"
        className="btn btn--ghost btn--small"
        onClick={() => onChange([...values, 0])}
      >
        +
      </button>
    </div>
  );
}

/**
 * Ratio weights.
 *
 * Every element of the list gets a row, including the ones weighted zero.
 * The engine treats an unmentioned index as weight zero - that is, blocked -
 * and showing all of them makes that visible rather than something you have
 * to remember.
 */
function RatioEditor({
  principle,
  onChange,
  list,
  offset,
}: {
  principle: Extract<Principle, { kind: "ratio" }>;
  onChange: (p: Principle) => void;
  list: string[];
  offset: 0 | 1;
}) {
  const weightOf = (index: number) =>
    principle.pairs.find((p) => p.index === index)?.weight ?? 0;

  const setWeight = (index: number, weight: number) => {
    const others = principle.pairs.filter((p) => p.index !== index);
    onChange({
      kind: "ratio",
      pairs: [...others, { index, weight }].sort((a, b) => a.index - b.index),
    });
  };

  const total = list.reduce((sum, _, i) => sum + Math.max(0, weightOf(i)), 0);

  if (list.length === 0) {
    return <div className="empty-note">Add values to the list before weighting them.</div>;
  }

  return (
    <div className="table-editor" style={{ maxWidth: 460 }}>
      {list.map((value, i) => {
        const weight = weightOf(i);
        const share = total > 0 ? (Math.max(0, weight) / total) * 100 : 0;
        return (
          <div className="table-editor__row" key={i}>
            <div className="table-editor__group-label">{i + offset}</div>
            <div style={{ flex: 1, minWidth: 0 }}>{value}</div>
            <input
              type="number"
              className="input--tiny"
              min={0}
              value={weight}
              onChange={(e) => setWeight(i, Number(e.target.value))}
            />
            <div
              className="faint mono"
              style={{ width: 76, textAlign: "right", fontSize: 11.5 }}
            >
              {weight <= 0 ? "blocked" : `${share.toFixed(1)}%`}
            </div>
          </div>
        );
      })}
    </div>
  );
}

/**
 * A tendency mask: sections that each move a window across the list.
 *
 * Bounds are proportions of the list (0 = its first element, 1 = its last),
 * not indices, which is why they are constrained to that range.
 */
function TendencyEditor({
  principle,
  onChange,
}: {
  principle: Extract<Principle, { kind: "tendency" }>;
  onChange: (p: Principle) => void;
}) {
  const set = (i: number, patch: Partial<(typeof principle.sections)[number]>) =>
    onChange({
      kind: "tendency",
      sections: principle.sections.map((s, j) => (j === i ? { ...s, ...patch } : s)),
    });

  const num = (
    value: number,
    onValue: (n: number) => void,
    props: { min?: number; max?: number; step?: number } = {},
  ) => (
    <input
      type="number"
      className="input--tiny"
      step={props.step ?? 0.1}
      min={props.min}
      max={props.max}
      value={value}
      onChange={(e) => onValue(Number(e.target.value))}
    />
  );

  return (
    <div className="stack">
      {principle.sections.map((s, i) => (
        <div className="table-editor" key={i} style={{ maxWidth: 520 }}>
          <div className="table-editor__row">
            <div className="table-editor__group-label">Sec {i + 1}</div>
            <div className="stack" style={{ flex: 1, gap: 6 }}>
              <div className="field__row">
                <span className="faint" style={{ width: 90 }}>
                  Portion
                </span>
                {num(s.portion, (n) => set(i, { portion: n }), { min: 0, step: 0.1 })}
                <span className="faint" style={{ fontSize: 11.5 }}>
                  relative length of this section
                </span>
              </div>
              <div className="field__row">
                <span className="faint" style={{ width: 90 }}>
                  Start range
                </span>
                {num(s.startMin, (n) => set(i, { startMin: n }), { min: 0, max: 1 })}
                <span className="faint">to</span>
                {num(s.startMax, (n) => set(i, { startMax: n }), { min: 0, max: 1 })}
              </div>
              <div className="field__row">
                <span className="faint" style={{ width: 90 }}>
                  End range
                </span>
                {num(s.endMin, (n) => set(i, { endMin: n }), { min: 0, max: 1 })}
                <span className="faint">to</span>
                {num(s.endMax, (n) => set(i, { endMax: n }), { min: 0, max: 1 })}
              </div>
            </div>
            <div className="table-editor__actions">
              <button
                type="button"
                className="btn btn--ghost btn--icon btn--danger"
                onClick={() =>
                  onChange({
                    kind: "tendency",
                    sections: principle.sections.filter((_, j) => j !== i),
                  })
                }
                title="Remove this section"
              >
                ×
              </button>
            </div>
          </div>
        </div>
      ))}
      <div>
        <button
          type="button"
          className="btn btn--small"
          onClick={() =>
            onChange({
              kind: "tendency",
              sections: [
                ...principle.sections,
                { portion: 1, startMin: 0, startMax: 1, endMin: 0, endMax: 1 },
              ],
            })
          }
        >
          + Add section
        </button>
      </div>
      <div className="faint" style={{ fontSize: 11.5 }}>
        Bounds are proportions of the list: 0 is its first element, 1 its last.
      </div>
    </div>
  );
}
