/**
 * A directed graph view of HARMONY's INTERVAL principle matrix - the same
 * data `MatrixEditor` shows as a grid, laid out instead so a dead end (a
 * node with no outgoing arrow) is visible at a glance rather than requiring
 * a scan across a row of checkboxes.
 *
 * Deliberately hand-rolled in plain SVG rather than pulling in a graph-
 * layout library: nodes sit at fixed positions around a circle (no physics
 * simulation needed for this), and every edge is a single quadratic Bézier
 * curve bowed away from the straight line between its two nodes - enough to
 * keep a pair of opposite-direction edges (`i -> j` and `j -> i`) visually
 * distinct instead of overlapping into one line. Edges *will* cross for a
 * busy matrix; that's expected and not worth solving for here; the point is
 * spotting isolated nodes, not producing a publication-quality diagram.
 */

const VIEW_SIZE = 400;
const CENTER = VIEW_SIZE / 2;
const RADIUS = 155;
const NODE_RADIUS = 13;

function nodePos(i: number, total: number) {
  const theta = (2 * Math.PI * (i - 1)) / total - Math.PI / 2;
  return { x: CENTER + RADIUS * Math.cos(theta), y: CENTER + RADIUS * Math.sin(theta) };
}

export function IntervalGraph({ size, matrix }: { size: number; matrix: boolean[][] }) {
  if (size <= 0) {
    return (
      <div className="empty-note">
        Tones-per-octave is too small for an interval matrix (needs at least 2).
      </div>
    );
  }

  const edges: { from: number; to: number }[] = [];
  for (let i = 1; i <= size; i += 1) {
    for (let j = 1; j <= size; j += 1) {
      if (matrix[i - 1]?.[j - 1]) edges.push({ from: i, to: j });
    }
  }

  return (
    <svg
      viewBox={`0 0 ${VIEW_SIZE} ${VIEW_SIZE}`}
      className="interval-graph"
      role="img"
      aria-label="Interval transition graph - an arrow from one interval to another means it may follow it"
    >
      <defs>
        <marker
          id="interval-graph-arrow"
          viewBox="0 0 10 10"
          refX="8.5"
          refY="5"
          markerWidth="6"
          markerHeight="6"
          orient="auto-start-reverse"
        >
          <path d="M0,0 L10,5 L0,10 z" className="interval-graph__arrowhead" />
        </marker>
      </defs>

      {edges.map(({ from, to }, k) => {
        if (from === to) {
          const p = nodePos(from, size);
          const dx = p.x - CENTER;
          const dy = p.y - CENTER;
          const len = Math.hypot(dx, dy) || 1;
          const nx = dx / len;
          const ny = dy / len;
          const loop = NODE_RADIUS * 1.8;
          const c1x = p.x + nx * loop - ny * loop * 0.6;
          const c1y = p.y + ny * loop + nx * loop * 0.6;
          const c2x = p.x + nx * loop + ny * loop * 0.6;
          const c2y = p.y + ny * loop - nx * loop * 0.6;
          return (
            <path
              key={k}
              d={`M ${p.x} ${p.y} C ${c1x} ${c1y}, ${c2x} ${c2y}, ${p.x} ${p.y}`}
              className="interval-graph__edge"
              markerEnd="url(#interval-graph-arrow)"
            />
          );
        }

        const a = nodePos(from, size);
        const b = nodePos(to, size);
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const dist = Math.hypot(dx, dy) || 1;
        const mx = (a.x + b.x) / 2;
        const my = (a.y + b.y) / 2;
        const perpX = -dy / dist;
        const perpY = dx / dist;
        const bow = dist * 0.2 * (from < to ? 1 : -1);
        const cx = mx + perpX * bow;
        const cy = my + perpY * bow;

        // Pull the endpoint back to the node's edge, so the arrowhead sits
        // just outside the circle rather than underneath it.
        const endDx = b.x - cx;
        const endDy = b.y - cy;
        const endDist = Math.hypot(endDx, endDy) || 1;
        const endX = b.x - (endDx / endDist) * (NODE_RADIUS + 2);
        const endY = b.y - (endDy / endDist) * (NODE_RADIUS + 2);

        return (
          <path
            key={k}
            d={`M ${a.x} ${a.y} Q ${cx} ${cy} ${endX} ${endY}`}
            className="interval-graph__edge"
            markerEnd="url(#interval-graph-arrow)"
          />
        );
      })}

      {Array.from({ length: size }, (_, idx) => {
        const i = idx + 1;
        const p = nodePos(i, size);
        return (
          <g key={i}>
            <circle cx={p.x} cy={p.y} r={NODE_RADIUS} className="interval-graph__node" />
            <text x={p.x} y={p.y} className="interval-graph__label">
              {i}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
