import { memo, useCallback, useEffect, useMemo, useState } from "react";
import type { PlaybackData, PlaybackNote } from "../schema/types";
import { isTauri, midiPorts } from "../engine/backend";
import {
  type SoundOutput,
  loadSoundOutput,
  saveSoundOutput,
  startPlayback,
  stopPlayback,
} from "../engine/playback";

/**
 * The Output screen's playback preview: every variant with a play button,
 * its length and position, a checkbox per layer, and a minimal piano roll
 * (pitch against time, the whole variant) to click in to jump to a moment.
 *
 * Sound goes either to a MIDI output port or to a bare sine-wave synth in
 * the app itself; which one is always shown, so it's never a guess whether
 * you're hearing the real MIDI output. The choice is remembered as an app
 * preference, not stored in the project.
 */

type Playing = { variant: number; from: number; startedAt: number };

const endOf = (notes: PlaybackNote[]) => notes.reduce((m, n) => Math.max(m, n[0] + n[1]), 0);

// One shared "nothing muted", so the memoized piano roll isn't handed a new
// empty array on every frame.
const NONE_MUTED: boolean[] = [];

function formatTime(s: number): string {
  const m = Math.floor(s / 60);
  const rest = s - m * 60;
  return `${m}:${rest.toFixed(1).padStart(4, "0")}`;
}

export function PlaybackPanel({
  data,
  firstVariant,
}: {
  data: PlaybackData;
  /** The number the first variant is shown with (the project's start index). */
  firstVariant: number;
}) {
  const [output, setOutputState] = useState<SoundOutput>(loadSoundOutput);
  const [ports, setPorts] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [playing, setPlaying] = useState<Playing | null>(null);
  const [cursors, setCursors] = useState<Record<number, number>>({});
  const [mutedLayers, setMutedLayers] = useState<Record<number, boolean[]>>({});
  const [now, setNow] = useState(() => performance.now());

  const setOutput = (o: SoundOutput) => {
    setOutputState(o);
    saveSoundOutput(o);
  };

  const refreshPorts = useCallback(async () => {
    try {
      setPorts(await midiPorts());
    } catch (e) {
      setError(String(e));
    }
  }, []);
  useEffect(() => {
    refreshPorts();
  }, [refreshPorts]);

  const stop = useCallback(() => {
    setPlaying(null);
    stopPlayback().catch(() => {});
  }, []);

  // New notes (any edit re-runs the engine) or leaving the screen: stop, as
  // what was playing no longer matches what's shown.
  useEffect(() => stop, [data, stop]);

  // Recomputed only when the notes or the layer checkboxes change - the
  // panel itself re-renders every frame while playing.
  const variants = useMemo(
    () =>
      data.variants.map((v, i) => {
        const layerLengths = v.layers.map(endOf);
        return {
          layers: v.layers,
          layerLengths,
          length: Math.max(0, ...layerLengths),
          muted: mutedLayers[i] ?? NONE_MUTED,
        };
      }),
    [data, mutedLayers],
  );

  const position = (i: number) =>
    playing?.variant === i
      ? playing.from + Math.max(0, now - playing.startedAt) / 1000
      : Math.min(cursors[i] ?? 0, variants[i]?.length ?? 0);

  const play = async (i: number, from: number, muted?: boolean[]) => {
    const v = variants[i];
    const m = muted ?? v.muted;
    const notes = v.layers.flatMap((n, l) => (m[l] ? [] : n));
    const start = from >= v.length ? 0 : from;
    setError(null);
    try {
      await startPlayback(output, notes, start);
      setPlaying({ variant: i, from: start, startedAt: performance.now() });
    } catch (e) {
      setPlaying(null);
      setError(String(e));
    }
  };

  // Moves the playhead while playing, and stops at the end of the variant.
  useEffect(() => {
    if (!playing) return;
    let frame = 0;
    const step = () => {
      const t = performance.now();
      const length = variants[playing.variant]?.length ?? 0;
      if (playing.from + (t - playing.startedAt) / 1000 >= length) {
        setCursors((c) => ({ ...c, [playing.variant]: 0 }));
        stop();
        return;
      }
      setNow(t);
      frame = requestAnimationFrame(step);
    };
    frame = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frame);
  }, [playing, variants, stop]);

  const toggle = (i: number) => {
    if (playing?.variant === i) {
      setCursors((c) => ({ ...c, [i]: position(i) }));
      stop();
    } else {
      play(i, position(i));
    }
  };

  const seek = (i: number, t: number) => {
    setCursors((c) => ({ ...c, [i]: t }));
    if (playing?.variant === i) play(i, t);
  };

  const toggleLayer = (i: number, layer: number) => {
    const next = [...variants[i].muted];
    next[layer] = !next[layer];
    setMutedLayers((m) => ({ ...m, [i]: next }));
    if (playing?.variant === i) play(i, position(i), next);
  };

  const switchOutput = (o: SoundOutput) => {
    if (playing) stop();
    setOutput(o);
  };

  const midiPort = output.kind === "midi" ? output.port : "";
  const outputLabel =
    output.kind === "sine" ? "Sine preview (built in)" : `MIDI → ${output.port || "no port chosen"}`;

  return (
    <div className="playback">
      <div className="field__row playback__output">
        <span className="faint">Sound</span>
        <div className="kind-switch" role="radiogroup">
          <button
            type="button"
            className={`kind-switch__option${output.kind === "sine" ? " kind-switch__option--active" : ""}`}
            aria-pressed={output.kind === "sine"}
            onClick={() => switchOutput({ kind: "sine" })}
          >
            Sine (built in)
          </button>
          <button
            type="button"
            className={`kind-switch__option${output.kind === "midi" ? " kind-switch__option--active" : ""}`}
            aria-pressed={output.kind === "midi"}
            disabled={!isTauri()}
            title={isTauri() ? undefined : "MIDI output needs the desktop app"}
            onClick={() => {
              refreshPorts();
              switchOutput({ kind: "midi", port: midiPort || ports[0] || "" });
            }}
          >
            MIDI port
          </button>
        </div>
        {output.kind === "midi" && (
          <>
            <select
              value={midiPort}
              onChange={(e) => switchOutput({ kind: "midi", port: e.target.value })}
            >
              {!midiPort && <option value="">Choose a port…</option>}
              {midiPort && !ports.includes(midiPort) && (
                <option value={midiPort}>{midiPort} (not available)</option>
              )}
              {ports.map((p) => (
                <option key={p} value={p}>
                  {p}
                </option>
              ))}
            </select>
            <button type="button" className="btn btn--ghost btn--small" onClick={refreshPorts}>
              Refresh
            </button>
            {ports.length === 0 && (
              <span className="faint">
                No MIDI ports found - start a synth or DAW, or enable the IAC Driver (macOS).
              </span>
            )}
          </>
        )}
      </div>

      {error && <div className="diagnostic diagnostic--error playback__error">{error}</div>}

      {variants.map((v, i) => {
        const isPlaying = playing?.variant === i;
        const pos = position(i);
        return (
          <div key={i} className={`playback__variant${isPlaying ? " playback__variant--playing" : ""}`}>
            <div className="field__row playback__head">
              <button
                type="button"
                className={`btn btn--small ${isPlaying ? "btn--primary" : "btn--ghost"} playback__play`}
                aria-label={isPlaying ? "Stop" : "Play"}
                disabled={output.kind === "midi" && !midiPort}
                onClick={() => toggle(i)}
              >
                {isPlaying ? "■" : "▶"}
              </button>
              <span className="playback__title">Variant {i + firstVariant}</span>
              <span className="playback__time">
                {formatTime(pos)} / {formatTime(v.length)}
              </span>
              {isPlaying && <span className="playback__badge">{outputLabel}</span>}
              {v.layers.length > 1 && (
                <span className="playback__layers">
                  {v.layers.map((_, l) => (
                    <label key={l} className={`playback__layer playback__layer--${l % 4}`}>
                      <input
                        type="checkbox"
                        checked={!v.muted[l]}
                        onChange={() => toggleLayer(i, l)}
                      />
                      Layer {l + 1} <span className="faint">({formatTime(v.layerLengths[l])})</span>
                    </label>
                  ))}
                </span>
              )}
            </div>
            <div
              className="piano-roll"
              onClick={(e) => {
                const r = e.currentTarget.getBoundingClientRect();
                seek(i, Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * v.length);
              }}
            >
              <PianoRoll layers={v.layers} muted={v.muted} length={v.length} />
              {v.length > 0 && (
                <div className="piano-roll__playhead" style={{ left: `${(pos / v.length) * 100}%` }} />
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}

/**
 * Pitch against time as filled bars - no dynamics - for the whole variant,
 * every layer in its own colour (faded when unchecked). Memoized: only the
 * playhead moves during playback, not these.
 */
const PianoRoll = memo(function PianoRoll({
  layers,
  muted,
  length,
}: {
  layers: PlaybackNote[][];
  muted: boolean[];
  length: number;
}) {
  let low = Infinity;
  let high = -Infinity;
  for (const notes of layers) {
    for (const n of notes) {
      low = Math.min(low, n[2]);
      high = Math.max(high, n[2]);
    }
  }
  if (low > high || length <= 0) return <div className="piano-roll__empty">No notes</div>;
  const rows = high - low + 1;
  // viewBox: 1000 wide for the whole length, one unit high per semitone;
  // stretched to the box, so short notes get a minimum width to stay visible.
  return (
    <svg className="piano-roll__svg" viewBox={`0 0 1000 ${rows}`} preserveAspectRatio="none">
      {layers.map((notes, l) => (
        <g
          key={l}
          className={`piano-roll__layer piano-roll__layer--${l % 4}${muted[l] ? " piano-roll__layer--muted" : ""}`}
        >
          {notes.map(([t, d, key], k) => (
            <rect
              key={k}
              x={(t / length) * 1000}
              y={high - key}
              width={Math.max((d / length) * 1000, 1.5)}
              height={1}
            />
          ))}
        </g>
      ))}
    </svg>
  );
});
