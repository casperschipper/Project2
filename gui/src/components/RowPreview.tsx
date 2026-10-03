import { useMemo, useState } from "react";
import { CENTER, NODE_RADIUS, VIEW_SIZE, nodePos } from "./IntervalGraph";

/**
 * A preview of one possible "infinite row" for HARMONY's INTERVAL principle,
 * drawn on a circle of the tr relative pitches: every step is an arrow from
 * one tone to the next, so a matrix that keeps returning to the same few
 * tones shows up as a few thick, well-trodden lines.
 *
 * The walk mirrors the engine's `interval_next` (pr26/lib/score_generation.ml)
 * minus condition (2): REGISTER/INSTRUMENT play no part here. Forbidden tones
 * (XCL-FRQ) are never produced, a tone not heard since the last reset is
 * preferred (condition 3, dropped when nothing else is possible), and when
 * the matrix leaves no way on at all the engine's fallback (interval 1,
 * "INTERVAL RESTRICTIONS TOO STRICT") is taken and marked as such. The
 * engine draws its own random numbers, so this is the kind of row a matrix
 * makes, not the one the score will contain - the UI says so.
 */

const DEFAULT_STEPS = 32;
const MAX_STEPS = 128;

type Step = { tone: number; interval: number | null; tooStrict: boolean };

function pick<T>(xs: T[]): T {
  return xs[Math.floor(Math.random() * xs.length)];
}

function walkRow(
  tr: number,
  matrix: boolean[][],
  forbidden: number[],
  length: number,
  start: number | null,
): Step[] {
  const isForbidden = (t: number) => forbidden.includes(t);
  const producible = tr - new Set(forbidden.filter((t) => t >= 1 && t <= tr)).size;
  const rowHasSuccessor = (i: number) => (matrix[i - 1] ?? []).some(Boolean);
  const successors = (i: number) =>
    Array.from({ length: tr - 1 }, (_, j) => j + 1).filter((j) => matrix[i - 1]?.[j - 1]);
  const transpose = (k: number, n: number) => ((n - 1 + k) % tr) + 1;

  let seen = new Set<number>();
  const remember = (t: number) => {
    seen.add(t);
    if (seen.size >= producible) seen = new Set();
  };

  // Same relaxation order as the engine: postponement first, then nothing
  // but the forbidden tones (no register condition to drop in between).
  const choose = (candidates: [number, number][]) => {
    const fresh = candidates.filter(([, t]) => !isForbidden(t) && !seen.has(t));
    if (fresh.length) return pick(fresh);
    const allowed = candidates.filter(([, t]) => !isForbidden(t));
    return allowed.length ? pick(allowed) : null;
  };

  const out: Step[] = [];
  const first =
    start !== null && !isForbidden(start)
      ? start
      : (choose(Array.from({ length: tr }, (_, i) => [i + 1, i + 1]))?.[1] ?? 1);
  out.push({ tone: first, interval: null, tooStrict: false });
  remember(first);

  let base = first;
  let given: number | null = null;
  while (out.length < length) {
    const intervals =
      given === null
        ? Array.from({ length: tr - 1 }, (_, i) => i + 1).filter(rowHasSuccessor)
        : successors(given);
    const chosen = choose(intervals.map((i) => [i, transpose(i, base)]));
    const [interval, tone] = chosen ?? [1, transpose(1, base)];
    out.push({ tone, interval, tooStrict: !chosen });
    base = tone;
    given = interval;
    remember(tone);
  }
  return out;
}

export function RowPreview({
  tr,
  matrix,
  forbiddenTones,
}: {
  tr: number;
  matrix: boolean[][];
  forbiddenTones: string[];
}) {
  // Kept as typed, so clearing the box to type a new number doesn't snap
  // back mid-edit; the walk uses the clamped value.
  const [stepsText, setStepsText] = useState(String(DEFAULT_STEPS));
  const typed = Math.round(Number(stepsText));
  const steps = Number.isFinite(typed) && typed >= 2 ? Math.min(MAX_STEPS, typed) : DEFAULT_STEPS;
  const [start, setStart] = useState<number | null>(null);
  const [variant, setVariant] = useState(0);
  const forbidden = forbiddenTones.map(Number).filter(Number.isInteger);
  const forbiddenKey = forbidden.join(",");
  const pinnedStart = start !== null && start <= tr && !forbidden.includes(start) ? start : null;

  const row = useMemo(
    () => (tr >= 2 ? walkRow(tr, matrix, forbidden, steps, pinnedStart) : []),
    // `variant` only exists to force a fresh draw on "Another variant".
    [tr, matrix, forbiddenKey, steps, pinnedStart, variant],
  );

  if (!row.length) return null;

  const visits = new Map<number, number>();
  for (const s of row) visits.set(s.tone, (visits.get(s.tone) ?? 0) + 1);
  const first = row[0].tone;
  const last = row[row.length - 1].tone;
  const tooStrict = row.some((s) => s.tooStrict);

  return (
    <div className="graph-panel row-preview">
      <div className="graph-panel__caption">
        <span className="graph-panel__title">Row preview</span>
        <span className="row-preview__badge">Preview</span>
        <span className="graph-panel__sub">one possible row</span>
      </div>
      <svg
        viewBox={`0 0 ${VIEW_SIZE} ${VIEW_SIZE}`}
        className="interval-graph row-preview__graph"
        role="img"
        aria-label={`One possible row of ${row.length} relative pitches: ${row
          .map((s) => s.tone)
          .join(" ")}`}
      >
        <defs>
          <marker
            id="row-preview-arrow"
            viewBox="0 0 10 10"
            refX="8.5"
            refY="5"
            markerWidth="6"
            markerHeight="6"
            orient="auto-start-reverse"
          >
            <path d="M0,0 L10,5 L0,10 z" className="row-preview__arrowhead" />
          </marker>
        </defs>

        {row.slice(1).map((s, k) => {
          const a = nodePos(row[k].tone, tr);
          const b = nodePos(s.tone, tr);
          const dx = b.x - a.x;
          const dy = b.y - a.y;
          const dist = Math.hypot(dx, dy) || 1;
          const ux = dx / dist;
          const uy = dy / dist;
          const pad = NODE_RADIUS + 2;
          return (
            <line
              key={k}
              x1={a.x + ux * pad}
              y1={a.y + uy * pad}
              x2={b.x - ux * pad}
              y2={b.y - uy * pad}
              className={`row-preview__step${s.tooStrict ? " row-preview__step--wrong" : ""}`}
              markerEnd="url(#row-preview-arrow)"
            >
              <title>
                {`Step ${k + 2}: ${row[k].tone} → ${s.tone} (interval ${s.interval})${
                  s.tooStrict ? " - restrictions too strict, fallback" : ""
                }`}
              </title>
            </line>
          );
        })}

        {Array.from({ length: tr }, (_, idx) => {
          const t = idx + 1;
          const p = nodePos(t, tr);
          const isForbidden = forbidden.includes(t);
          const count = visits.get(t) ?? 0;
          const cls = [
            "interval-graph__node",
            count > 0 ? "row-preview__node--visited" : "",
            isForbidden ? "row-preview__node--forbidden" : "",
            t === first ? "row-preview__node--start" : "",
          ]
            .filter(Boolean)
            .join(" ");
          return (
            <g
              key={t}
              className={isForbidden ? undefined : "row-preview__pick"}
              onClick={
                isForbidden ? undefined : () => setStart(pinnedStart === t ? null : t)
              }
            >
              <title>
                {isForbidden
                  ? `${t}: forbidden tone`
                  : `${t}: ${count}× in this preview. Click to ${
                      pinnedStart === t ? "start anywhere again" : "start here"
                    }.`}
              </title>
              {t === last && <circle cx={p.x} cy={p.y} r={NODE_RADIUS + 4} className="row-preview__last" />}
              <circle cx={p.x} cy={p.y} r={NODE_RADIUS} className={cls} />
              <text x={p.x} y={p.y} className="interval-graph__label">
                {t}
              </text>
            </g>
          );
        })}

        <text x={CENTER} y={CENTER} className="row-preview__center">
          {pinnedStart === null ? "random start" : `start ${pinnedStart}`}
        </text>
      </svg>

      <div className="field__row row-preview__controls">
        <label className="faint">
          Steps{" "}
          <input
            type="number"
            className="input--tiny"
            min={2}
            max={MAX_STEPS}
            value={stepsText}
            onChange={(e) => setStepsText(e.target.value)}
            onBlur={() => setStepsText(String(steps))}
          />
        </label>
        <button
          type="button"
          className="btn btn--ghost btn--small"
          onClick={() => setVariant((v) => v + 1)}
        >
          Another variant
        </button>
      </div>
      <p className="row-preview__note">
        One possible row from this matrix, register ignored. The score draws its own, so its
        pitches will differ. Thick filled circle = start, ring = last tone; click a tone to start
        there.
        {tooStrict && " Red dashed = restrictions too strict (the engine falls back to interval 1)."}
      </p>
    </div>
  );
}
