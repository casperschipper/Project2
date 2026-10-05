import type { PlaybackNote } from "../schema/types";
import { midiPlay, midiStop } from "./backend";

/**
 * Playback for the Output screen's preview: the engine's notes either to a
 * MIDI output port (played by the Rust side, see `src-tauri/src/midi.rs`)
 * or to a bare sine-wave synth in the webview, for when there is no synth
 * listening on a port. Only one plays at a time.
 */

export type SoundOutput = { kind: "sine" } | { kind: "midi"; port: string };

const STORAGE_KEY = "pr2.soundOutput";

/** The output chosen last time - an application preference, not part of
 * the project. */
export function loadSoundOutput(): SoundOutput {
  try {
    const v = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "null");
    if (v?.kind === "midi" && typeof v.port === "string") return { kind: "midi", port: v.port };
  } catch {
    // Unreadable or blocked storage - fall back to the default.
  }
  return { kind: "sine" };
}

export function saveSoundOutput(output: SoundOutput): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(output));
  } catch {
    // Not persisted (private window, blocked storage) - still used this session.
  }
}

/**
 * One channel per instrument (by its index in the instrument list), so
 * layers playing together never share one. Channel 10 (index 9) is skipped:
 * General MIDI synths, like Windows' built-in one, reserve it for drums.
 */
const CHANNELS = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15];
export const channelFor = (instrument: number) => CHANNELS[instrument % CHANNELS.length];

// ---- sine synth ------------------------------------------------------

// Notes are handed to Web Audio a little ahead of time, a slice at a time,
// rather than all at once: a long variant can have thousands of notes.
const LOOKAHEAD = 0.3;
const TICK_MS = 50;
const ATTACK = 0.005;
const RELEASE = 0.03;

let audio: AudioContext | null = null;
let sine: { master: GainNode; timer: number; voices: Set<OscillatorNode> } | null = null;

async function playSine(notes: PlaybackNote[], from: number): Promise<void> {
  stopSine();
  audio ??= new AudioContext();
  if (audio.state === "suspended") await audio.resume();
  const ctx = audio;

  const master = ctx.createGain();
  master.gain.value = 0.5;
  master.connect(ctx.createDynamicsCompressor()).connect(ctx.destination);
  const voices = new Set<OscillatorNode>();

  const pending = notes.filter((n) => n[0] >= from).sort((a, b) => a[0] - b[0]);
  const t0 = ctx.currentTime + 0.05 - from;
  let next = 0;

  const schedule = ([time, duration, key, velocity]: PlaybackNote) => {
    const start = t0 + time;
    const end = start + Math.max(duration, ATTACK + RELEASE);
    const osc = ctx.createOscillator();
    osc.frequency.value = 440 * 2 ** ((key - 69) / 12);
    const env = ctx.createGain();
    const level = 0.15 * (velocity / 127);
    env.gain.setValueAtTime(0, start);
    env.gain.linearRampToValueAtTime(level, start + ATTACK);
    env.gain.setValueAtTime(level, end - RELEASE);
    env.gain.linearRampToValueAtTime(0, end);
    osc.connect(env).connect(master);
    osc.start(start);
    osc.stop(end);
    voices.add(osc);
    osc.onended = () => {
      env.disconnect();
      voices.delete(osc);
    };
  };

  const tick = () => {
    const horizon = ctx.currentTime + LOOKAHEAD;
    while (next < pending.length && t0 + pending[next][0] < horizon) {
      schedule(pending[next]);
      next += 1;
    }
  };
  tick();
  sine = { master, timer: window.setInterval(tick, TICK_MS), voices };
}

function stopSine(): void {
  if (!sine || !audio) return;
  const { master, timer, voices } = sine;
  sine = null;
  window.clearInterval(timer);
  // A short fade rather than a hard cut, which would click.
  const now = audio.currentTime;
  master.gain.setValueAtTime(master.gain.value, now);
  master.gain.linearRampToValueAtTime(0, now + 0.02);
  for (const v of voices) v.stop(now + 0.03);
  window.setTimeout(() => master.disconnect(), 100);
}

// ---- either ----------------------------------------------------------

let active: SoundOutput["kind"] | null = null;

/** Plays `notes` from `from` seconds on, replacing what was playing. */
export async function startPlayback(
  output: SoundOutput,
  notes: PlaybackNote[],
  from: number,
): Promise<void> {
  await stopPlayback();
  if (output.kind === "sine") {
    await playSine(notes, from);
  } else {
    await midiPlay(
      output.port,
      notes.map(([t, d, key, vel, instr]) => [t, d, key, vel, channelFor(instr)]),
      from,
    );
  }
  active = output.kind;
}

export async function stopPlayback(): Promise<void> {
  const was = active;
  active = null;
  if (was === "sine") stopSine();
  if (was === "midi") await midiStop();
}
