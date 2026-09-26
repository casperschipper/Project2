import { isTauri } from "./backend";

/**
 * Whole-window zoom.
 *
 * The stylesheet sizes things in px throughout (boxes, grid columns, input
 * widths), so scaling only the font would overflow them. Zooming the webview
 * scales everything as one unit, exactly like a browser's page zoom, and the
 * layout is recomputed at the zoomed size, so nothing breaks.
 *
 * Desktop app only: in a plain browser the browser's own zoom already does
 * this, so the functions are no-ops there.
 */

export const ZOOM_STEPS = [0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2];
const STORAGE_KEY = "pr2.zoom";

export function loadZoom(): number {
  try {
    const v = Number(localStorage.getItem(STORAGE_KEY));
    return ZOOM_STEPS.includes(v) ? v : 1;
  } catch {
    return 1;
  }
}

export async function applyZoom(factor: number): Promise<void> {
  try {
    localStorage.setItem(STORAGE_KEY, String(factor));
  } catch {
    // Not persisted (private window, blocked storage) - still applied below.
  }
  if (!isTauri()) return;
  const { getCurrentWebview } = await import("@tauri-apps/api/webview");
  await getCurrentWebview().setZoom(factor);
}

/** The next step in `dir` from `current`, clamped to the available range. */
export function stepZoom(current: number, dir: 1 | -1): number {
  const i = ZOOM_STEPS.indexOf(current);
  const from = i >= 0 ? i : ZOOM_STEPS.indexOf(1);
  return ZOOM_STEPS[Math.min(ZOOM_STEPS.length - 1, Math.max(0, from + dir))];
}
