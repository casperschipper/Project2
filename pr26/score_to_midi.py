#!/usr/bin/env python3
"""Convert a .projekt2 score file to a MIDI file.

Usage:
    python score_to_midi.py [score.projekt2]   # output: score.mid

midiutil is vendored in vendor/. To update it:
    pip install midiutil --target vendor/
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "vendor"))
from midiutil import MIDIFile

# TEMPO = 60 BPM means 1 beat == 1 second, so score times map directly to beats.
TEMPO = 60
MIDDLE_C = 60

# Channel 9 is the GM percussion channel; all others are melodic.
INSTRUMENTS = {
    "piano":    {"channel": 0, "program": 0,   "note": MIDDLE_C, "duration": 1.5},
    "guitar":   {"channel": 1, "program": 25,  "note": MIDDLE_C, "duration": 1.2},
    "marimba":  {"channel": 2, "program": 12,  "note": MIDDLE_C, "duration": 0.6},
    "basedrum": {"channel": 9, "program": None, "note": 36,       "duration": 0.15},
}


def parse_score(path: Path):
    events = []
    with open(path) as f:
        for lineno, line in enumerate(f, 1):
            parts = line.split()
            if not parts:
                continue
            if len(parts) < 3:
                print(f"  line {lineno}: skipping malformed line: {line.rstrip()}")
                continue
            events.append((float(parts[0]), parts[1], int(parts[2])))
    return events


def write_midi(events, output_path: Path):
    midi = MIDIFile(1)
    track = 0
    midi.addTempo(track, 0, TEMPO)

    for name, info in INSTRUMENTS.items():
        if info["program"] is not None:
            midi.addProgramChange(track, info["channel"], 0, info["program"])

    skipped = 0
    for time, instrument, voices in events:
        info = INSTRUMENTS.get(instrument)
        if info is None:
            print(f"  warning: unknown instrument '{instrument}', skipping")
            skipped += 1
            continue
        # Scale velocity with voice count; cap at 120 to leave headroom.
        velocity = min(120, 50 + voices * 10)
        midi.addNote(track, info["channel"], info["note"], time, info["duration"], velocity)

    with open(output_path, "wb") as f:
        midi.writeFile(f)

    written = len(events) - skipped
    print(f"Wrote {written} notes to {output_path}")


def main():
    input_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("score.projekt2")
    if not input_path.exists():
        sys.exit(f"File not found: {input_path}")

    output_path = input_path.with_suffix(".mid")
    events = parse_score(input_path)
    print(f"Read {len(events)} events from {input_path}")
    write_midi(events, output_path)


if __name__ == "__main__":
    main()
