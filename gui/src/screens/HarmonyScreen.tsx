import { useStore } from "../state/store";
import { Field, Section } from "../components/Field";
import { TokenListEditor } from "../components/ListEditors";
import type { NoteMode, Transposition } from "../schema/types";

/**
 * HARMONY (EMR-3 8.2): ROW only (CHORD and INTERVAL are out of scope - see
 * harmony.md). ROW decides the relative pitch, as a fixed sequence that
 * transposes once it has been used up in full; it never decides *which*
 * octave that relative pitch lands in - that is REGISTER's job, on its own
 * screen. Their relative order in the Structure screen's hierarchy decides
 * which one constrains the other for a given note.
 */
export function HarmonyScreen() {
  const { project, update } = useStore();

  return (
    <div className="screen">
      <h1 className="screen__title">Harmony</h1>
      <p className="screen__intro">
        The relative pitch a tone takes - a fixed row that gets used up in order and then
        transposed as a whole, over and over. 0 marks a percussion event directly in the row.
        See the Register screen for how a relative pitch is placed into an actual octave.
      </p>

      <Section title="Row">
        <Field
          label="Row"
          helpKey="fields/harmony-row"
          path="harmony.row"
          hint={`Relative pitches 1..${project.octaveDivision}, or 'p' for an explicit percussion event. Drag the grip to reorder.`}
        >
          <TokenListEditor
            values={project.row}
            onChange={(v) => update((p) => (p.row = v))}
            placeholder="p"
            bulkPlaceholder="1 2 3 p 5 7 9 11 12"
            invalid={(v) => {
              if (v === "p") return false;
              const n = Number(v);
              return !Number.isInteger(n) || n < 1 || n > project.octaveDivision;
            }}
          />
        </Field>
      </Section>

      <Section title="Transposition and mode">
        <Field
          label="Transposition"
          helpKey="fields/harmony-transposition"
          path="harmony.transposition"
          hint="How the row is transposed each time it has been used up in full."
        >
          <select
            style={{ width: 340 }}
            value={project.transposition}
            onChange={(e) =>
              update((p) => (p.transposition = e.target.value as Transposition))
            }
          >
            <option value="none">None — the row repeats unchanged</option>
            <option value="alea">Alea — a random interval each pass</option>
            <option value="series">Series — each interval once before repeating</option>
            <option value="chromatic">Chromatic — an ascending sequence of intervals</option>
            <option value="serial">Serial — the row itself reused as transposition intervals</option>
          </select>
        </Field>

        <Field
          label="Chord or note"
          helpKey="fields/harmony-mode"
          path="harmony.mode"
          hint="Whether one relative pitch covers a whole chord, or each note gets its own."
        >
          <select
            style={{ width: 340 }}
            value={project.harmonyMode}
            onChange={(e) => update((p) => (p.harmonyMode = e.target.value as NoteMode))}
          >
            <option value="per-chord">Per chord — one value shared by every note</option>
            <option value="per-note">Per note — drawn again for each note</option>
          </select>
        </Field>
      </Section>
    </div>
  );
}
