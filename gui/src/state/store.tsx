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
  /** True when GUI errors are blocking the engine run. */
  blocked: boolean;
  run: () => void;

  screen: ScreenId;
  setScreen: (s: ScreenId) => void;

  help: HelpTarget;
  openHelp: (key: string, title: string) => void;
  closeHelp: () => void;

  dirty: boolean;
  markSaved: () => void;
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

  const run = useCallback(() => {
    if (blocked) {
      setEngineResult(null);
      return;
    }
    const token = ++runToken.current;
    setRunning(true);
    runEngine(sexp)
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
  }, [sexp, blocked]);

  // Validate continuously in the background. The engine is fast and cheap, so
  // the composer sees consequences as they type rather than on demand; the
  // explicit Run button remains for when they want to force it.
  useEffect(() => {
    if (blocked) {
      setEngineResult(null);
      return;
    }
    const timer = setTimeout(run, 400);
    return () => clearTimeout(timer);
  }, [run, blocked]);

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
      blocked,
      run,
      screen,
      setScreen,
      help,
      openHelp,
      closeHelp,
      dirty,
      markSaved,
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
      blocked,
      run,
      screen,
      help,
      openHelp,
      closeHelp,
      dirty,
      markSaved,
    ],
  );

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}
