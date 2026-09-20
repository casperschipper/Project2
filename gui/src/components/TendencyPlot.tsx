import type { TendencySection } from "../schema/types";

/**
 * A plot of a tendency mask, in percentages only.
 *
 * Horizontal: the run, as a share of its total length (each section's width is
 * its portion over the sum of portions). Vertical: position in the list, 0 =
 * first element, 1 = last. Neither the number of events nor the size of the
 * ensemble is known here, so neither is drawn - the shape is all the mask
 * itself defines.
 *
 * Monochrome, thick lines, hatched windows - after a 1970s computer manual.
 */

const W = 520;
const H = 200;
const LEFT = 46;
const RIGHT = 8;
const TOP = 22;
const BOTTOM = 26;
const STEPS = 24;

const clamp01 = (n: number) => Math.min(1, Math.max(0, Number.isFinite(n) ? n : 0));
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/** Hatch angle differs per section so neighbours stay distinguishable. */
const HATCH_ANGLES = [45, 135, 0, 90];

export function TendencyPlot({ sections }: { sections: TendencySection[] }) {
  const weights = sections.map((s) => (s.portion > 0 ? s.portion : 0));
  const total = weights.reduce((a, b) => a + b, 0);
  if (sections.length === 0 || total <= 0) {
    return (
      <div className="tendency-plot tendency-plot--empty">
        No section has a portion above 0, so there is nothing to plot.
      </div>
    );
  }

  const plotW = W - LEFT - RIGHT;
  const plotH = H - TOP - BOTTOM;
  const x = (share: number) => LEFT + share * plotW;
  const y = (v: number) => TOP + (1 - clamp01(v)) * plotH;

  let acc = 0;
  const laid = sections.map((s, i) => {
    const x0 = acc / total;
    acc += weights[i];
    const x1 = acc / total;
    // Same rule as the engine: bounds are interpolated, then swapped if crossed.
    const lo: [number, number][] = [];
    const hi: [number, number][] = [];
    for (let k = 0; k <= STEPS; k++) {
      const t = k / STEPS;
      const a = lerp(clamp01(s.startMin), clamp01(s.endMin), t);
      const b = lerp(clamp01(s.startMax), clamp01(s.endMax), t);
      const px = x(lerp(x0, x1, t));
      lo.push([px, y(Math.min(a, b))]);
      hi.push([px, y(Math.max(a, b))]);
    }
    const pts = (ps: [number, number][]) => ps.map(([px, py]) => `${px},${py}`).join(" ");
    const outline = `${pts(hi)} ${pts([...lo].reverse())}`;
    const invalid =
      s.portion <= 0 ||
      [s.startMin, s.startMax, s.endMin, s.endMax].some((n) => n < 0 || n > 1);
    return { x0, x1, hi: pts(hi), lo: pts(lo), outline, invalid };
  });

  return (
    <figure className="tendency-plot">
      <svg
        viewBox={`0 0 ${W} ${H}`}
        width="100%"
        role="img"
        aria-label="Tendency mask: window position in the list against share of the run"
      >
        <defs>
          {HATCH_ANGLES.map((angle, i) => (
            <pattern
              key={i}
              id={`tendency-hatch-${i}`}
              width="6"
              height="6"
              patternUnits="userSpaceOnUse"
              patternTransform={`rotate(${angle})`}
            >
              <line x1="0" y1="0" x2="0" y2="6" stroke="currentColor" strokeWidth="1.2" />
            </pattern>
          ))}
        </defs>

        {/* section windows */}
        {laid.map((s, i) => (
          <g key={i}>
            <polygon
              points={s.outline}
              fill={`url(#tendency-hatch-${i % HATCH_ANGLES.length})`}
              stroke="none"
            />
            <polyline
              points={s.hi}
              fill="none"
              stroke="currentColor"
              strokeWidth="3"
              strokeLinecap="square"
              strokeLinejoin="miter"
              strokeDasharray={s.invalid ? "7 5" : undefined}
            />
            <polyline
              points={s.lo}
              fill="none"
              stroke="currentColor"
              strokeWidth="3"
              strokeLinecap="square"
              strokeLinejoin="miter"
              strokeDasharray={s.invalid ? "7 5" : undefined}
            />
          </g>
        ))}

        {/* section dividers and labels */}
        {laid.map((s, i) => (
          <g key={`d${i}`}>
            <line
              x1={x(s.x0)}
              x2={x(s.x0)}
              y1={TOP}
              y2={TOP + plotH}
              stroke="currentColor"
              strokeWidth="3"
              strokeLinecap="square"
            />
            <text
              x={x((s.x0 + s.x1) / 2)}
              y={TOP - 7}
              textAnchor="middle"
              className="tendency-plot__label"
            >
              SEC {i + 1}
            </text>
            <text
              x={x((s.x0 + s.x1) / 2)}
              y={H - 8}
              textAnchor="middle"
              className="tendency-plot__label"
            >
              {Math.round((s.x1 - s.x0) * 100)}%
            </text>
          </g>
        ))}
        <line
          x1={x(1)}
          x2={x(1)}
          y1={TOP}
          y2={TOP + plotH}
          stroke="currentColor"
          strokeWidth="3"
          strokeLinecap="square"
        />

        {/* frame: value axis on the left, floor and ceiling */}
        <line x1={LEFT} x2={x(1)} y1={y(0)} y2={y(0)} stroke="currentColor" strokeWidth="2" />
        <line x1={LEFT} x2={x(1)} y1={y(1)} y2={y(1)} stroke="currentColor" strokeWidth="2" />
        <text x={LEFT - 8} y={y(1) + 4} textAnchor="end" className="tendency-plot__label">
          LAST
        </text>
        <text x={LEFT - 8} y={y(0.5) + 4} textAnchor="end" className="tendency-plot__label">
          .5
        </text>
        <text x={LEFT - 8} y={y(0) + 4} textAnchor="end" className="tendency-plot__label">
          FIRST
        </text>
      </svg>
      <figcaption className="tendency-plot__caption">
        Hatched band = the part of the list a draw may come from. Width = share of the run;
        one pass of the mask.
      </figcaption>
    </figure>
  );
}
