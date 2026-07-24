import React from "react";
import { useStore } from "../state/store";
import { Field, Section } from "../components/Field";
import { TableEditor } from "../components/TableEditor";
import { TokenListEditor } from "../components/ListEditors";
import { EnsembleEditor, PrincipleEditor } from "../components/PrincipleEditor";
import { parseTimeValue } from "../schema/validate";
import type { Ensemble, NoteMode, Principle, Project, Table } from "../schema/types";

/**
 * The four parameter screens - entry delay, duration, dynamics, performance -
 * are the same shape, because in Project Two every parameter follows the same
 * chain: a LIST of values, a TABLE grouping indices into that list, an
 * ENSEMBLE principle choosing which group is active, and an ORDER principle
 * drawing from within it. Presenting them identically is deliberate: once the
 * chain is understood on one parameter it is understood on all of them.
 */

export type ParameterConfig = {
  paramId: "entrydelay" | "duration" | "dynamics" | "performance";
  title: string;
  intro: string;
  /** Singular noun for one element, used in tooltips. */
  valueLabel: string;
  listHelpKey: string;
  listLabel: string;
  listHint: React.ReactNode;
  /** Derived lists (performance) are shown but not edited. */
  listReadOnly?: boolean;
  numeric?: boolean;
  /** Example text for the list's bulk-entry box, e.g. "0.1 0.2 1/4 0.5". */
  bulkPlaceholder?: string;
  /** Present for parameters that choose per chord or per note. */
  mode?: {
    get: (p: Project) => NoteMode;
    set: (p: Project, v: NoteMode) => void;
    helpKey: string;
    label: string;
  };
  get: {
    list: (p: Project) => string[];
    table: (p: Project) => Table;
    ensemble: (p: Project) => Ensemble;
    principle: (p: Project) => Principle;
  };
  set: {
    list: (p: Project, v: string[]) => void;
    table: (p: Project, v: Table) => void;
    ensemble: (p: Project, v: Ensemble) => void;
    principle: (p: Project, v: Principle) => void;
  };
};

export function ParameterScreen({ config }: { config: ParameterConfig }) {
  const { project, update } = useStore();
  const { paramId } = config;

  const list = config.get.list(project);
  const table = config.get.table(project);

  return (
    <div className="screen">
      <h1 className="screen__title">{config.title}</h1>
      <p className="screen__intro">{config.intro}</p>

      <Section title="List — the supply of values">
        <Field
          label={config.listLabel}
          helpKey={config.listHelpKey}
          path={`${paramId}.list`}
          hint={config.listHint}
        >
          <TokenListEditor
            values={list}
            readOnly={config.listReadOnly}
            onChange={(v) => update((p) => config.set.list(p, v))}
            placeholder={config.numeric ? "0.25" : "name"}
            bulkPlaceholder={config.bulkPlaceholder}
            invalid={
              config.numeric
                ? (value) => parseTimeValue(value) === null || (parseTimeValue(value) ?? 0) < 0
                : undefined
            }
          />
        </Field>
      </Section>

      <Section title="Table — groups of indices into the list">
        <Field
          label="Table"
          helpKey={`fields/${paramId}-table`}
          path={`${paramId}.table`}
          hint="Each row is a group. The numbers are positions in the list above, not values."
        >
          <TableEditor
            table={table}
            onChange={(v) => update((p) => config.set.table(p, v))}
            values={list}
            path={`${paramId}.table`}
            valueLabel={config.valueLabel}
            readOnlyRowLabels={project.instrumentGroupNames}
          />
        </Field>
      </Section>

      <Section title="Ensemble — which group is active">
        <Field
          label="Ensemble principle"
          helpKey={`fields/${paramId}-ensemble`}
          path={`${paramId}.combination`}
          hint="How a group is chosen from the table for each layer."
        >
          <EnsembleEditor
            ensemble={config.get.ensemble(project)}
            onChange={(v) => update((p) => config.set.ensemble(p, v))}
            groupCount={table.length}
          />
        </Field>
      </Section>

      <Section title="Order — how values are drawn from the group">
        <Field
          label="Order principle"
          helpKey={`fields/${paramId}-order`}
          path={`${paramId}.principle`}
          hint="How successive values are selected from within the active group."
        >
          <PrincipleEditor
            principle={config.get.principle(project)}
            onChange={(v) => update((p) => config.set.principle(p, v))}
            values={list}
            valueLabel={config.valueLabel}
          />
        </Field>

        {config.mode && (
          <Field
            label={config.mode.label}
            helpKey={config.mode.helpKey}
            path={`${paramId}.mode`}
            hint="Whether one value covers a whole chord, or each note gets its own."
          >
            <select
              style={{ width: 340 }}
              value={config.mode.get(project)}
              onChange={(e) =>
                update((p) => config.mode!.set(p, e.target.value as NoteMode))
              }
            >
              <option value="per-chord">Per chord — one value shared by every note</option>
              <option value="per-note">Per note — drawn again for each note</option>
            </select>
          </Field>
        )}
      </Section>
    </div>
  );
}

// ---------------------------------------------------------------------
// The four configurations.
// ---------------------------------------------------------------------

export const ENTRYDELAY: ParameterConfig = {
  paramId: "entrydelay",
  title: "Entry delay",
  intro:
    "The time between one entry and the next. Entry delays determine the rhythm of the piece at the level of events rather than notes.",
  valueLabel: "entry delay",
  listLabel: "Entry delays",
  listHelpKey: "fields/entrydelay-list",
  listHint: "Seconds. Decimals (0.25) and fractions (1/4) are both accepted.",
  numeric: true,
  bulkPlaceholder: "0.1 0.2 1/4 0.5",
  get: {
    list: (p) => p.entrydelays,
    table: (p) => p.entrydelayTable,
    ensemble: (p) => p.entrydelayEnsemble,
    principle: (p) => p.entrydelayPrinciple,
  },
  set: {
    list: (p, v) => (p.entrydelays = v),
    table: (p, v) => (p.entrydelayTable = v),
    ensemble: (p, v) => (p.entrydelayEnsemble = v),
    principle: (p, v) => (p.entrydelayPrinciple = v),
  },
};

export const DURATION: ParameterConfig = {
  paramId: "duration",
  title: "Duration",
  intro:
    "How long each note sounds. How duration relates to entry delay — whether it is independent, equal, or constrained to be shorter — is set on the Structure screen.",
  valueLabel: "duration",
  listLabel: "Durations",
  listHelpKey: "fields/duration-list",
  listHint: "Seconds. Decimals (0.25) and fractions (1/4) are both accepted.",
  numeric: true,
  bulkPlaceholder: "0.5 1.0 2.5",
  get: {
    list: (p) => p.durations,
    table: (p) => p.durationTable,
    ensemble: (p) => p.durationEnsemble,
    principle: (p) => p.durationPrinciple,
  },
  set: {
    list: (p, v) => (p.durations = v),
    table: (p, v) => (p.durationTable = v),
    ensemble: (p, v) => (p.durationEnsemble = v),
    principle: (p, v) => (p.durationPrinciple = v),
  },
};

export const DYNAMICS: ParameterConfig = {
  paramId: "dynamics",
  title: "Dynamics",
  intro:
    "The master list of dynamic markings. Each instrument declares which of these it can actually play, and the engine will only assign a dynamic an instrument can produce.",
  valueLabel: "dynamic",
  listLabel: "Dynamics",
  listHelpKey: "fields/dynamics-list",
  listHint: "Any names you like — ppp, pp, p, mf, f, ff, fff by convention.",
  bulkPlaceholder: "ppp mf ff",
  mode: {
    get: (p) => p.dynamicsMode,
    set: (p, v) => (p.dynamicsMode = v),
    helpKey: "fields/dynamics-mode",
    label: "Chord or note",
  },
  get: {
    list: (p) => p.dynamics,
    table: (p) => p.dynamicsTable,
    ensemble: (p) => p.dynamicsEnsemble,
    principle: (p) => p.dynamicsPrinciple,
  },
  set: {
    list: (p, v) => (p.dynamics = v),
    table: (p, v) => (p.dynamicsTable = v),
    ensemble: (p, v) => (p.dynamicsEnsemble = v),
    principle: (p, v) => (p.dynamicsPrinciple = v),
  },
};

export const PERFORMANCE: ParameterConfig = {
  paramId: "performance",
  title: "Performance",
  intro:
    "Modes of performance — how a note is produced. This list is assembled automatically from your instrument definitions so the two can never contradict each other; arrange the modes into groups in the table below.",
  valueLabel: "mode",
  listLabel: "Performance modes",
  listHelpKey: "fields/performance-list",
  listReadOnly: true,
  listHint: "Derived from the instruments. Add a mode to an instrument and it appears here.",
  mode: {
    get: (p) => p.performanceMode,
    set: (p, v) => (p.performanceMode = v),
    helpKey: "fields/performance-mode",
    label: "Chord or note",
  },
  get: {
    list: (p) => p.performance,
    table: (p) => p.performanceTable,
    ensemble: (p) => p.performanceEnsemble,
    principle: (p) => p.performancePrinciple,
  },
  set: {
    list: () => {},
    table: (p, v) => (p.performanceTable = v),
    ensemble: (p, v) => (p.performanceEnsemble = v),
    principle: (p, v) => (p.performancePrinciple = v),
  },
};
