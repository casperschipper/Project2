import { useState } from "react";
import { useStore } from "../state/store";
import { DiagnosticList, Section } from "../components/Field";
import { PlaybackPanel } from "../components/PlaybackPanel";
import { dedupeForDisplay } from "../engine/diagnostics";
import { chooseOutputDir } from "../engine/backend";

/**
 * The output screen.
 *
 * For now this shows what the engine produces as text. It is also the place
 * to see the generated structure formula itself, which is worth having
 * visible: the formula is the actual artefact the engine consumes, and being
 * able to read it makes the relationship between the forms and the file
 * concrete rather than hidden.
 */

type Tab = "score" | "entries" | "formula" | "log" | "debug";

const TABS: { id: Tab; label: string }[] = [
  { id: "score", label: "Score" },
  { id: "entries", label: "Entries" },
  { id: "formula", label: "Structure formula" },
  { id: "log", label: "Engine log" },
  { id: "debug", label: "Debug" },
];

export function OutputScreen() {
  const {
    project,
    update,
    engineResult,
    sexp,
    running,
    blocked,
    guiDiagnostics,
    debugEnabled,
    setDebugEnabled,
  } = useStore();
  const [tab, setTab] = useState<Tab>("score");
  const [variant, setVariant] = useState(0);

  const errors = guiDiagnostics.filter((d) => d.severity === "error");

  const changeOutputDir = async () => {
    const dir = await chooseOutputDir();
    if (dir) update((p) => (p.outputDir = dir));
  };

  // More than one variant reports an array instead of a flat score/entries
  // pair - clamped in case a previous run had more variants than this one.
  const variants = engineResult?.variants;
  const activeVariant = variants ? Math.min(variant, variants.length - 1) : 0;
  const variantScore = variants ? variants[activeVariant]?.score : engineResult?.score;
  const variantEntries = variants ? variants[activeVariant]?.entries : engineResult?.entries;

  const content = (): { text: string | undefined; empty: string } => {
    switch (tab) {
      case "score":
        return {
          text: variantScore,
          empty: "No score yet — the engine has not produced one for this formula.",
        };
      case "entries":
        return {
          text: variantEntries,
          empty: "No entry list yet.",
        };
      case "formula":
        return { text: sexp, empty: "" };
      case "log":
        return {
          text: engineResult?.log,
          empty: "The engine produced no log output.",
        };
      case "debug":
        return {
          text: engineResult?.debug && JSON.stringify(engineResult.debug, null, 2),
          empty: debugEnabled
            ? "No debug events yet."
            : "Turn on “Debug output” above to include this on the next run.",
        };
    }
  };

  const { text, empty } = content();

  return (
    <div className="screen" style={{ maxWidth: "none" }}>
      <h1 className="screen__title">Output</h1>
      <p className="screen__intro">
        What the engine generated from the current formula. More formats and ways of
        displaying this will follow.
      </p>

      <Section title="Playback">
        {engineResult?.playback ? (
          <PlaybackPanel data={engineResult.playback} firstVariant={project.startIndex} />
        ) : (
          <div className="empty-note">
            Nothing to play yet - the engine has not produced a score for this formula.
          </div>
        )}
      </Section>

      <div className="field" style={{ marginBottom: 20 }}>
        <div className="field__row" style={{ flexWrap: "wrap" }}>
          <span className="faint">
            Score, entries and MIDI files are written to:{" "}
            {project.outputDir ? (
              <code>{project.outputDir}</code>
            ) : (
              "not chosen yet — nothing is written to disk until you choose a folder"
            )}
          </span>
          <button type="button" className="btn btn--ghost btn--small" onClick={changeOutputDir}>
            {project.outputDir ? "Change folder…" : "Choose folder…"}
          </button>
        </div>
        {engineResult?.midiFiles && engineResult.midiFiles.length > 0 && (
          <div className="field__hint">
            Wrote {engineResult.midiFiles.length} MIDI file
            {engineResult.midiFiles.length === 1 ? "" : "s"}:{" "}
            {engineResult.midiFiles.map((f) => f.split("/").pop()).join(", ")}
          </div>
        )}
      </div>

      {blocked && (
        <div style={{ marginBottom: 20 }}>
          <div className="field__hint" style={{ marginBottom: 6 }}>
            The engine has not been run because the formula is not yet consistent. These need
            attention first:
          </div>
          <DiagnosticList diagnostics={dedupeForDisplay(errors).slice(0, 8)} />
        </div>
      )}

      {engineResult?.engineError && (
        <div style={{ marginBottom: 20 }}>
          <div className="diagnostic diagnostic--error">
            <span className="diagnostic__icon">!</span>
            <span className="diagnostic__body">
              <span className="diagnostic__message">{engineResult.engineError}</span>
            </span>
          </div>
        </div>
      )}

      {variants && variants.length > 1 && (tab === "score" || tab === "entries") && (
        <div className="kind-switch" style={{ marginBottom: 12 }} role="radiogroup">
          {variants.map((_, i) => (
            <button
              key={i}
              type="button"
              className={`kind-switch__option${i === activeVariant ? " kind-switch__option--active" : ""}`}
              onClick={() => setVariant(i)}
            >
              Variant {i + project.startIndex}
            </button>
          ))}
        </div>
      )}

      <div className="tabs">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            className={`tab${tab === t.id ? " tab--active" : ""}`}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
        <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 8 }}>
          <label
            className="faint"
            style={{ display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}
          >
            <input
              type="checkbox"
              checked={debugEnabled}
              onChange={(e) => setDebugEnabled(e.target.checked)}
            />
            Debug output
          </label>
          {text && (
            <button
              type="button"
              className="btn btn--ghost btn--small"
              onClick={() => navigator.clipboard?.writeText(text)}
            >
              Copy
            </button>
          )}
        </div>
      </div>

      {running && <div className="faint" style={{ marginBottom: 10 }}>Running…</div>}

      {text ? (
        <pre className="output">{text}</pre>
      ) : (
        <div className="output output--empty">{empty}</div>
      )}
    </div>
  );
}
