import React from "react";
import { useStore } from "../state/store";
import { diagnosticsFor, dedupeForDisplay } from "../engine/diagnostics";
import type { Diagnostic } from "../schema/types";

/**
 * A labelled field.
 *
 * Two things every field does, which is why they go through one component:
 *
 *  - The label itself opens the help panel. Making the label the affordance
 *    (rather than only a small icon) means the explanation is always one
 *    obvious click away, which is the point of the help system here.
 *  - It shows the diagnostics that belong to its path. A field claims any
 *    diagnostic at or beneath its path, so a table shows its cells' errors
 *    while each cell also marks itself.
 */
export function Field({
  label,
  helpKey,
  path,
  hint,
  children,
  showDiagnostics = true,
}: {
  label: string;
  helpKey: string;
  /** Diagnostic path this field owns. Omit for fields with no checks. */
  path?: string;
  hint?: React.ReactNode;
  children: React.ReactNode;
  showDiagnostics?: boolean;
}) {
  const { openHelp, diagnostics } = useStore();
  const mine = path ? dedupeForDisplay(diagnosticsFor(diagnostics, path)) : [];

  return (
    <div className="field">
      <div className="field__header">
        <button
          type="button"
          className="field__label"
          onClick={() => openHelp(helpKey, label)}
          title={`What is "${label}"?`}
        >
          {label}
        </button>
        <button
          type="button"
          className="field__help"
          onClick={() => openHelp(helpKey, label)}
          aria-label={`Help for ${label}`}
          title={`What is "${label}"?`}
        >
          ?
        </button>
      </div>
      {children}
      {hint && <div className="field__hint">{hint}</div>}
      {showDiagnostics && mine.length > 0 && <DiagnosticList diagnostics={mine} />}
    </div>
  );
}

/**
 * Diagnostics are clickable: they open the explanation for that specific
 * error id. An error message tells you what went wrong; the linked document
 * explains why the rule exists, which is the part worth learning.
 */
export function DiagnosticList({ diagnostics }: { diagnostics: Diagnostic[] }) {
  const { openHelp } = useStore();
  if (diagnostics.length === 0) return null;

  return (
    <div className="diagnostics">
      {diagnostics.map((d, i) => (
        <button
          key={`${d.id}-${d.path}-${i}`}
          type="button"
          className={`diagnostic diagnostic--${d.severity}`}
          onClick={() => openHelp(`errors/${d.id}`, d.message)}
          title="Read more about this"
        >
          <span className="diagnostic__icon">{d.severity === "error" ? "!" : "*"}</span>
          <span className="diagnostic__body">
            <span className="diagnostic__message">{d.message}</span>
            <div className="diagnostic__more">What does this mean?</div>
          </span>
        </button>
      ))}
    </div>
  );
}

/** A labelled section heading within a screen. */
export function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="section">
      <h2 className="section__title">{title}</h2>
      {children}
    </section>
  );
}
