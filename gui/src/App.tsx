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
  REST,
} from "./screens/ParameterScreen";
import {
  chooseOutputDir,
  dirExists,
  isTauri,
  openProjectFile,
  saveProjectFile,
  writeProjectFile,
} from "./engine/backend";
import { defaultProject } from "./schema/defaults";
import type { Project } from "./schema/types";
import { shadowedByEquality } from "./schema/shadowed";
import { applyZoom, loadZoom, stepZoom } from "./engine/zoom";

export function App() {
  const {
    screen,
    setScreen,
    diagnostics,
    help,
    openHelp,
    closeHelp,
    running,
    pending,
    blocked,
    forceRender,
    engineResult,
    project,
    update,
    replaceProject,
    dirty,
    markSaved,
  } = useStore();

  // The full path, not just the display name - what makes a plain "Save"
  // silent (write straight back here) rather than always asking "Save As"
  // would.
  const [filePath, setFilePath] = useState<string | null>(null);
  const fileName = filePath?.split("/").pop() ?? null;
  const counts = countsByScreen(diagnostics);
  const shadow = shadowedByEquality(project);

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
      // A saved output folder only counts on the computer that has it: one
      // from elsewhere is dropped, so nothing is written until the composer
      // picks a folder here.
      if (parsed.outputDir && !(await dirExists(parsed.outputDir).catch(() => false))) {
        parsed.outputDir = null;
      }
      replaceProject({ ...defaultProject(), ...parsed });
      setFilePath(file.path);
    } catch {
      // A malformed project file is the one thing here with nowhere sensible
      // to report to, since the whole editor state depends on it loading.
      alert("That file could not be read as a Projekt 2 project.");
    }
  };

  /** The only affordance for where persisted output (score/entries/MIDI)
   * goes - once set, live background validation writes there automatically
   * on every edit, so there is no separate explicit "Run" step. */
  const setOutputDir = async () => {
    const dir = await chooseOutputDir();
    if (dir) update((p) => (p.outputDir = dir));
  };

  // Whole-window zoom: Cmd/Ctrl + and - step, Cmd/Ctrl 0 resets. Restored from
  // the last session on startup.
  const [zoom, setZoom] = useState(loadZoom);
  useEffect(() => {
    applyZoom(zoom).catch(() => {});
  }, [zoom]);
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (!(e.metaKey || e.ctrlKey) || e.altKey) return;
      if (e.key === "+" || e.key === "=") {
        e.preventDefault();
        setZoom((z) => stepZoom(z, 1));
      } else if (e.key === "-") {
        e.preventDefault();
        setZoom((z) => stepZoom(z, -1));
      } else if (e.key === "0") {
        e.preventDefault();
        setZoom(1);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, []);

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

        <SyncStatus
          running={running}
          pending={pending}
          blocked={blocked}
          hasOutputDir={Boolean(project.outputDir)}
          onForceRender={forceRender}
          onChooseOutputDir={setOutputDir}
        />

        <RunStatus
          running={running}
          blocked={blocked}
          errors={totalErrors}
          warnings={totalWarnings}
          ok={engineResult?.ok ?? false}
          hasOutputDir={Boolean(project.outputDir)}
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
        <button
          type="button"
          className="btn btn--ghost btn--small"
          onClick={setOutputDir}
          title={
            project.outputDir
              ? `Score, entries and MIDI are written to ${project.outputDir}`
              : "Choose where score, entries and MIDI files are written"
          }
        >
          {project.outputDir ? "Change output directory…" : "Set output directory…"}
        </button>
        <span className="zoom" title="Zoom the whole window (Cmd/Ctrl + and −, 0 to reset)">
          <button
            type="button"
            className="btn btn--ghost btn--small"
            onClick={() => setZoom((z) => stepZoom(z, -1))}
            aria-label="Zoom out"
          >
            −
          </button>
          <button
            type="button"
            className="btn btn--ghost btn--small zoom__value"
            onClick={() => setZoom(1)}
            aria-label="Reset zoom"
          >
            {Math.round(zoom * 100)}%
          </button>
          <button
            type="button"
            className="btn btn--ghost btn--small"
            onClick={() => setZoom((z) => stepZoom(z, 1))}
            aria-label="Zoom in"
          >
            +
          </button>
        </span>
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
              unused={
                (s.id === "entrydelay" && shadow?.ignored === "Ent") ||
                (s.id === "duration" && shadow?.ignored === "Dur")
              }
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
          {screen === "rest" && <ParameterScreen config={REST} />}
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
  unused = false,
  onSelect,
}: {
  id: ScreenId;
  label: string;
  active: boolean;
  errors: number;
  warnings: number;
  /** Not an error: the screen's values currently take no part (kept, not lost). */
  unused?: boolean;
  onSelect: (id: ScreenId) => void;
}) {
  return (
    <button
      type="button"
      className={`nav__item${active ? " nav__item--active" : ""}`}
      onClick={() => onSelect(id)}
    >
      <span className="nav__label">{label}</span>
      {unused && (
        <span
          className="nav__tag"
          title="Not used at the moment - it copies the other one (duration = entry delay). Your values are kept."
        >
          unused
        </span>
      )}
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

/**
 * Whether what's on screen still matches the current formula: green once a
 * live run has actually reflected the latest edit, red while an edit is
 * sitting in the debounce wait (see `state/store.tsx`'s `pending`), orange
 * while a run is actively in flight. Deliberately separate from `RunStatus`
 * below - that one reports the *content* of the last completed run (errors,
 * warnings), this one reports the *freshness* of that content, which can
 * disagree with it (recent edits can leave stale errors on screen for up to
 * the debounce wait). Never green before an output folder is chosen: the
 * formula is checked then, but nothing is written anywhere yet.
 */
function SyncStatus({
  running,
  pending,
  blocked,
  hasOutputDir,
  onForceRender,
  onChooseOutputDir,
}: {
  running: boolean;
  pending: boolean;
  blocked: boolean;
  hasOutputDir: boolean;
  onForceRender: () => void;
  onChooseOutputDir: () => void;
}) {
  // Checked before [pending]: while blocked, nothing is scheduled to render
  // at all (the debounce effect skips scheduling one), regardless of
  // whatever [pending] happens to hold - and forcing can't help here either,
  // since `runLive` itself refuses to run while blocked.
  if (blocked) {
    return (
      <div className="status" title="Fix the errors below to render">
        <span className="status__dot status__dot--error" />
        Blocked
      </div>
    );
  }

  if (running) {
    return (
      <div className="status" title="Rendering the current formula">
        <span className="status__dot status__dot--computing" />
        Rendering…
      </div>
    );
  }

  if (pending) {
    return (
      <button
        type="button"
        className="btn btn--ghost btn--small status"
        onClick={onForceRender}
        title="Edits are waiting to render (up to 750ms) - click to render now"
      >
        <span className="status__dot status__dot--error" />
        Render now
      </button>
    );
  }

  if (!hasOutputDir) {
    return (
      <button
        type="button"
        className="btn btn--ghost btn--small status"
        onClick={onChooseOutputDir}
        title="The formula is checked, but nothing is written until you choose an output folder"
      >
        <span className="status__dot status__dot--warning" />
        No output folder
      </button>
    );
  }

  return (
    <div className="status" title="Output matches the current formula">
      <span className="status__dot status__dot--ok" />
      Rendered
    </div>
  );
}

function RunStatus({
  running,
  blocked,
  errors,
  warnings,
  ok,
  hasOutputDir,
}: {
  running: boolean;
  blocked: boolean;
  errors: number;
  warnings: number;
  ok: boolean;
  hasOutputDir: boolean;
}) {
  const [dot, text] = (() => {
    if (running) return ["running", "Running"];
    if (errors > 0)
      return ["error", `${errors} error${errors === 1 ? "" : "s"}`];
    if (blocked) return ["error", "Not run"];
    if (warnings > 0)
      return ["warning", `${warnings} warning${warnings === 1 ? "" : "s"}`];
    // Without an output folder the run was only a check: nothing was kept.
    if (ok) return hasOutputDir ? ["ok", "Score generated"] : ["", "No errors"];
    return ["", "Idle"];
  })();

  return (
    <div className="status">
      <span className={`status__dot${dot ? ` status__dot--${dot}` : ""}`} />
      {text}
    </div>
  );
}
