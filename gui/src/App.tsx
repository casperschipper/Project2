import { useCallback, useEffect, useRef, useState } from "react";
import { useStore } from "./state/store";
import { SCREENS, countsByScreen, type ScreenId } from "./engine/diagnostics";
import { HelpPanel } from "./help/HelpPanel";
import { StructureScreen } from "./screens/StructureScreen";
import { InstrumentsScreen } from "./screens/InstrumentsScreen";
import { RegisterScreen } from "./screens/RegisterScreen";
import { HarmonyScreen } from "./screens/HarmonyScreen";
import { OutputScreen } from "./screens/OutputScreen";
import {
  ParameterScreen,
  ENTRYDELAY,
  DURATION,
  DYNAMICS,
  PERFORMANCE,
} from "./screens/ParameterScreen";
import { isTauri, openProjectFile, saveProjectFile, writeProjectFile } from "./engine/backend";
import { defaultProject } from "./schema/defaults";
import type { Project } from "./schema/types";

export function App() {
  const {
    screen,
    setScreen,
    diagnostics,
    help,
    openHelp,
    closeHelp,
    run,
    running,
    blocked,
    engineResult,
    project,
    replaceProject,
    sexp,
    dirty,
    markSaved,
  } = useStore();

  // The full path, not just the display name - what makes a plain "Save"
  // silent (write straight back here) rather than always asking "Save As"
  // would.
  const [filePath, setFilePath] = useState<string | null>(null);
  const fileName = filePath?.split("/").pop() ?? null;
  const counts = countsByScreen(diagnostics);

  const totalErrors = diagnostics.filter((d) => d.severity === "error").length;
  const totalWarnings = diagnostics.filter((d) => d.severity === "warning").length;

  /** Always asks where to save, even if the project already has a path. */
  const saveAs = useCallback(async (): Promise<string | null> => {
    const name = fileName ?? "formula.pr2proj";
    const saved = await saveProjectFile(JSON.stringify(project, null, 2), name);
    if (saved) {
      setFilePath(saved);
      markSaved();
    }
    return saved;
  }, [fileName, project, markSaved]);

  /** Writes straight back to the known path; asks only the first time. */
  const save = useCallback(async (): Promise<string | null> => {
    if (!filePath) return saveAs();
    await writeProjectFile(filePath, JSON.stringify(project, null, 2));
    markSaved();
    return filePath;
  }, [filePath, project, markSaved, saveAs]);

  const open = async () => {
    const file = await openProjectFile();
    if (!file) return;
    try {
      const parsed = JSON.parse(file.contents) as Project;
      replaceProject({ ...defaultProject(), ...parsed });
      setFilePath(file.path);
    } catch {
      // A malformed project file is the one thing here with nowhere sensible
      // to report to, since the whole editor state depends on it loading.
      alert("That file could not be read as a Projekt 2 project.");
    }
  };

  const exportSexp = () =>
    saveProjectFile(sexp, (fileName?.replace(/\.pr2proj$/, "") ?? "formula") + ".sexp");

  // Cmd+S (or Ctrl+S) saves without reaching for the mouse, exactly like
  // `save` above: silent once a path is known, a dialog only the first time.
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "s") {
        e.preventDefault();
        save();
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [save]);

  // `save`/`dirty` are read from inside a listener that's registered once
  // (below) - refs keep it reading the current values rather than whatever
  // was true at registration time.
  const saveRef = useRef(save);
  saveRef.current = save;
  const dirtyRef = useRef(dirty);
  dirtyRef.current = dirty;

  // Closing the window with unsaved changes asks first, exactly like any
  // desktop app's Save/Don't Save/Cancel prompt. Browser preview mode (no
  // Tauri window to intercept) falls back to the browser's own "leave site"
  // confirmation instead.
  useEffect(() => {
    if (!isTauri()) {
      const handler = (e: BeforeUnloadEvent) => {
        if (!dirtyRef.current) return;
        e.preventDefault();
        e.returnValue = "";
      };
      window.addEventListener("beforeunload", handler);
      return () => window.removeEventListener("beforeunload", handler);
    }

    let unlisten: (() => void) | undefined;
    let cancelled = false;
    (async () => {
      const [{ getCurrentWindow }, { message }] = await Promise.all([
        import("@tauri-apps/api/window"),
        import("@tauri-apps/plugin-dialog"),
      ]);
      if (cancelled) return;
      unlisten = await getCurrentWindow().onCloseRequested(async (event) => {
        if (!dirtyRef.current) return;
        const choice = await message("You have unsaved changes. Save them before closing?", {
          title: "Unsaved changes",
          kind: "warning",
          buttons: { yes: "Save", no: "Don't Save", cancel: "Cancel" },
        });
        if (choice === "Cancel") {
          event.preventDefault();
          return;
        }
        if (choice === "Yes") {
          const saved = await saveRef.current();
          if (!saved) event.preventDefault(); // the save dialog was cancelled - stay open
        }
        // choice === "No": don't prevent it, the window closes right after.
      });
    })();
    return () => {
      cancelled = true;
      unlisten?.();
    };
  }, []);

  return (
    <div className="app">
      <header className="topbar">
        <div className="topbar__title">
          Projekt 2
          {fileName && (
            <span className="topbar__file">
              {fileName}
              {dirty ? " ·" : ""}
            </span>
          )}
        </div>

        <RunStatus
          running={running}
          blocked={blocked}
          errors={totalErrors}
          warnings={totalWarnings}
          ok={engineResult?.ok ?? false}
        />

        <button type="button" className="btn btn--ghost btn--small" onClick={open}>
          Open
        </button>
        <button
          type="button"
          className="btn btn--ghost btn--small"
          onClick={save}
          title={filePath ? `Save to ${filePath}` : "Save (choose a location)"}
        >
          Save
        </button>
        <button
          type="button"
          className="btn btn--ghost btn--small"
          onClick={saveAs}
          title="Save to a new location"
        >
          Save As…
        </button>
        <button type="button" className="btn btn--ghost btn--small" onClick={exportSexp}>
          Export formula
        </button>
        <button
          type="button"
          className="btn btn--primary"
          onClick={run}
          disabled={running || blocked}
          title={blocked ? "Resolve the errors first" : "Run the engine now"}
        >
          {running ? "Running…" : "Run"}
        </button>
        <button
          type="button"
          className="btn btn--ghost btn--small"
          onClick={() =>
            help
              ? closeHelp()
              : openHelp("concepts/list-table-ensemble-order", "Getting started")
          }
          title={help ? "Close help" : "Open help"}
        >
          ?
        </button>
      </header>

      <div className={`body${help ? " body--help-open" : ""}`}>
        <nav className="nav">
          <div className="nav__group-label">Formula</div>
          {SCREENS.filter((s) => s.id !== "output").map((s) => (
            <NavItem
              key={s.id}
              id={s.id}
              label={s.label}
              active={screen === s.id}
              errors={counts[s.id].errors}
              warnings={counts[s.id].warnings}
              onSelect={setScreen}
            />
          ))}

          <div className="nav__group-label">Result</div>
          <NavItem
            id="output"
            label="Output"
            active={screen === "output"}
            errors={0}
            warnings={0}
            onSelect={setScreen}
          />
        </nav>

        <main className="main">
          {screen === "structure" && <StructureScreen />}
          {screen === "instruments" && <InstrumentsScreen />}
          {screen === "entrydelay" && <ParameterScreen config={ENTRYDELAY} />}
          {screen === "duration" && <ParameterScreen config={DURATION} />}
          {screen === "dynamics" && <ParameterScreen config={DYNAMICS} />}
          {screen === "performance" && <ParameterScreen config={PERFORMANCE} />}
          {screen === "register" && <RegisterScreen />}
          {screen === "harmony" && <HarmonyScreen />}
          {screen === "output" && <OutputScreen />}
        </main>

        {help && <HelpPanel />}
      </div>
    </div>
  );
}

/**
 * A red mark on a screen means that screen contains something inconsistent -
 * including inconsistencies caused by an edit made on a different screen,
 * which is the case worth surfacing. Warnings are shown the same way in
 * amber, since they are worth noticing without blocking.
 */
function NavItem({
  id,
  label,
  active,
  errors,
  warnings,
  onSelect,
}: {
  id: ScreenId;
  label: string;
  active: boolean;
  errors: number;
  warnings: number;
  onSelect: (id: ScreenId) => void;
}) {
  return (
    <button
      type="button"
      className={`nav__item${active ? " nav__item--active" : ""}`}
      onClick={() => onSelect(id)}
    >
      <span className="nav__label">{label}</span>
      {errors > 0 && (
        <span className="badge badge--error" title={`${errors} error${errors === 1 ? "" : "s"}`}>
          {errors}
        </span>
      )}
      {errors === 0 && warnings > 0 && (
        <span
          className="badge badge--warning"
          title={`${warnings} warning${warnings === 1 ? "" : "s"}`}
        >
          {warnings}
        </span>
      )}
    </button>
  );
}

function RunStatus({
  running,
  blocked,
  errors,
  warnings,
  ok,
}: {
  running: boolean;
  blocked: boolean;
  errors: number;
  warnings: number;
  ok: boolean;
}) {
  const [dot, text] = (() => {
    if (running) return ["running", "Running"];
    if (errors > 0)
      return ["error", `${errors} error${errors === 1 ? "" : "s"}`];
    if (blocked) return ["error", "Not run"];
    if (warnings > 0)
      return ["warning", `${warnings} warning${warnings === 1 ? "" : "s"}`];
    if (ok) return ["ok", "Score generated"];
    return ["", "Idle"];
  })();

  return (
    <div className="status">
      <span className={`status__dot${dot ? ` status__dot--${dot}` : ""}`} />
      {text}
    </div>
  );
}
