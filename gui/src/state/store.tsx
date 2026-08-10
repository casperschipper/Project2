import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { defaultProject, derivePerformanceList } from "../schema/defaults";
import { toSexp } from "../schema/sexp";
import { validateProject } from "../schema/validate";
import type { Diagnostic, EngineResult, Project } from "../schema/types";
import { runEngine } from "../engine/backend";
import type { ScreenId } from "../engine/diagnostics";

type HelpTarget = { key: string; title: string } | null;

type Store = {
  project: Project;
  update: (mutate: (draft: Project) => void) => void;
  replaceProject: (p: Project) => void;

  sexp: string;

  /** Checks the GUI performs itself, available immediately on every edit. */
  guiDiagnostics: Diagnostic[];
  /** Everything to display: GUI checks plus whatever the engine reported. */
  diagnostics: Diagnostic[];

  engineResult: EngineResult | null;
  running: boolean;
  /** True from the moment an edit changes what should be rendered until the
   * debounced live run actually starts (or [forceRender] is called) - i.e.
   * the displayed output no longer matches the current formula, but nothing
   * is in flight yet either. */
  pending: boolean;
  /** True when GUI errors are blocking the engine run. */
  blocked: boolean;
  /** Skips the rest of the debounce wait and renders immediately. */
  forceRender: () => void;

  screen: ScreenId;
  setScreen: (s: ScreenId) => void;

  help: HelpTarget;
  openHelp: (key: string, title: string) => void;
  closeHelp: () => void;

  dirty: boolean;
  markSaved: () => void;

  /** Whether the engine's `--debug` event log is requested on each run - see
   * the Output screen's toggle. Off by default: it's meant for a future
   * visualisation tool, not day-to-day composing, and skipping it keeps
   * every live-as-you-type run cheaper. */
  debugEnabled: boolean;
  setDebugEnabled: (v: boolean) => void;
};

const StoreContext = createContext<Store | null>(null);

export function useStore(): Store {
  const store = useContext(StoreContext);
  if (!store) throw new Error("useStore must be used inside <StoreProvider>");
  return store;
}

/**
 * Applying an update.
 *
 * The project is plain JSON data, so a structural clone is the simplest
 * correct way to get immutable updates without an extra dependency, and at
 * this size the cost is irrelevant. The performance list is recomputed on
 * every change because it is derived from the instruments and must never be
 * able to disagree with them.
 */
function applyUpdate(project: Project, mutate: (draft: Project) => void): Project {
  const draft = structuredClone(project);
  mutate(draft);
  draft.performance = derivePerformanceList(draft.instruments);
  return draft;
}

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [project, setProject] = useState<Project>(() =>
    applyUpdate(defaultProject(), () => {}),
  );
  const [engineResult, setEngineResult] = useState<EngineResult | null>(null);
  const [running, setRunning] = useState(false);
  const [screen, setScreen] = useState<ScreenId>("structure");
  const [help, setHelp] = useState<HelpTarget>(null);
  const [debugEnabled, setDebugEnabled] = useState(false);
  const [dirty, setDirty] = useState(false);

  const update = useCallback((mutate: (draft: Project) => void) => {
    setProject((p) => applyUpdate(p, mutate));
    setDirty(true);
  }, []);

  const replaceProject = useCallback((p: Project) => {
    setProject(applyUpdate(p, () => {}));
    setDirty(false);
  }, []);

  const sexp = useMemo(() => toSexp(project), [project]);
  const guiDiagnostics = useMemo(() => validateProject(project), [project]);

  const guiErrors = useMemo(
    () => guiDiagnostics.filter((d) => d.severity === "error"),
    [guiDiagnostics],
  );

  /**
   * The engine is only run once the GUI's own checks are clean.
   *
   * The GUI can locate a bad index at the exact cell, whereas the engine can
   * only fail the whole formula for the same mistake. Running it anyway would
   * report the same problem a second time, less precisely, and bury the useful
   * message. So obvious errors are fixed first, and the engine's own
   * diagnostics - the ones only it can produce - appear once the form is
   * internally consistent.
   */
  const blocked = guiErrors.length > 0;

  // Sequence numbers guard against a slow run overwriting a newer one.
  const runToken = useRef(0);

  const runWith = useCallback(
    (outDir: string | undefined) => {
      const token = ++runToken.current;
      setRunning(true);
      runEngine(sexp, outDir, debugEnabled)
        .then((result) => {
          if (token === runToken.current) setEngineResult(result);
        })
        .catch((err) => {
          if (token === runToken.current) {
            setEngineResult({
              ok: false,
              errors: [],
              warnings: [],
              engineError: String(err),
            });
          }
        })
        .finally(() => {
          if (token === runToken.current) setRunning(false);
        });
    },
    [sexp, debugEnabled],
  );

  // Live background validation: writes to the project's own output
  // directory once one is set (see the "set output directory" control),
  // so persisted score/entries/MIDI output stays current automatically as
  // the composer types - there is no separate explicit "Run" trigger.
  // Before an output directory is chosen, this still runs (against a
  // throwaway/ephemeral location - see runEngine/run_engine) purely for
  // live diagnostics, so typing never touches a real file until the
  // composer has actually picked one.
  const runLive = useCallback(() => {
    if (blocked) {
      setEngineResult(null);
      return;
    }
    runWith(project.outputDir ?? undefined);
  }, [blocked, project.outputDir, runWith]);

  // [pending] is the visible half of the debounce below: true the instant an
  // edit invalidates the last render, false again once a live run actually
  // starts (whether because the 750ms wait elapsed or [forceRender] skipped it).
  const [pending, setPending] = useState(false);
  const debounceTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const clearPendingTimer = useCallback(() => {
    if (debounceTimer.current !== null) {
      clearTimeout(debounceTimer.current);
      debounceTimer.current = null;
    }
  }, []);

  // Validate continuously in the background, debounced: the timer resets on
  // every edit, so it only actually fires once typing pauses for 750ms - not on
  // every keystroke, and not repeatedly while nothing is changing (each
  // effect run replaces, rather than adds to, the previous timer).
  useEffect(() => {
    if (blocked) {
      setEngineResult(null);
      setPending(false);
      return;
    }
    setPending(true);
    debounceTimer.current = setTimeout(() => {
      debounceTimer.current = null;
      setPending(false);
      runLive();
    }, 750);
    return clearPendingTimer;
  }, [runLive, blocked, clearPendingTimer]);

  const forceRender = useCallback(() => {
    clearPendingTimer();
    setPending(false);
    runLive();
  }, [clearPendingTimer, runLive]);

  const diagnostics = useMemo(() => {
    const engine = engineResult
      ? [...(engineResult.errors ?? []), ...(engineResult.warnings ?? [])]
      : [];
    return [...guiDiagnostics, ...engine];
  }, [guiDiagnostics, engineResult]);

  const openHelp = useCallback((key: string, title: string) => setHelp({ key, title }), []);
  const closeHelp = useCallback(() => setHelp(null), []);
  const markSaved = useCallback(() => setDirty(false), []);

  const value = useMemo<Store>(
    () => ({
      project,
      update,
      replaceProject,
      sexp,
      guiDiagnostics,
      diagnostics,
      engineResult,
      running,
      pending,
      blocked,
      forceRender,
      screen,
      setScreen,
      help,
      openHelp,
      closeHelp,
      dirty,
      markSaved,
      debugEnabled,
      setDebugEnabled,
    }),
    [
      project,
      update,
      replaceProject,
      sexp,
      guiDiagnostics,
      diagnostics,
      engineResult,
      running,
      pending,
      blocked,
      forceRender,
      screen,
      help,
      openHelp,
      closeHelp,
      dirty,
      markSaved,
      debugEnabled,
    ],
  );

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}
