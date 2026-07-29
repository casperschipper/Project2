import type { EngineResult } from "../schema/types";

/**
 * The backend interface.
 *
 * Two implementations exist: Tauri commands when running as the desktop app,
 * and HTTP routes served by the Vite dev server when running in a plain
 * browser (see vite.config.ts). Keeping both behind one interface means the
 * UI never branches on its environment, and the browser is a faithful preview
 * of the app - useful because Tauri needs system webkit headers that aren't
 * always installed.
 */

export const isTauri = (): boolean =>
  typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;

async function invoke<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
  const { invoke } = await import("@tauri-apps/api/core");
  return invoke<T>(cmd, args);
}

/**
 * Runs the engine. When `outDir` is given, the score/entries/MIDI files are
 * written there and kept (the result's `midiFiles` lists what was produced);
 * when omitted, output goes to a scratch directory that's discarded the
 * instant the engine finishes - used for live validate-as-you-type, so
 * typing never churns real files.
 */
export async function runEngine(sexp: string, outDir?: string): Promise<EngineResult> {
  if (isTauri()) return invoke<EngineResult>("run_engine", { sexp, outDir });

  const res = await fetch("/api/run", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sexp, outDir }),
  });
  return res.json();
}

/**
 * Lets the composer pick a folder for persisted Run output. Only meaningful
 * in the desktop app - a browser can't hand back a real filesystem path from
 * a folder picker, so this always returns null when running as a plain
 * dev-server preview.
 */
export async function chooseOutputDir(): Promise<string | null> {
  if (!isTauri()) {
    window.alert(
      "Choosing a persistent output folder needs the desktop app - run `npm run app` " +
        "(or a built binary) rather than the plain browser preview.",
    );
    return null;
  }
  const { open } = await import("@tauri-apps/plugin-dialog");
  const path = await open({ directory: true, multiple: false });
  return typeof path === "string" ? path : null;
}

/** Returns null when the document hasn't been written yet. */
export async function readHelp(key: string): Promise<string | null> {
  if (isTauri()) return invoke<string | null>("read_help", { key });

  const res = await fetch(`/api/help?key=${encodeURIComponent(key)}`);
  if (!res.ok) return null;
  const { markdown } = await res.json();
  return markdown;
}

export async function writeHelp(key: string, markdown: string): Promise<void> {
  if (isTauri()) {
    await invoke("write_help", { key, markdown });
    return;
  }
  await fetch(`/api/help?key=${encodeURIComponent(key)}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ markdown }),
  });
}

// ---------------------------------------------------------------------
// Project files
//
// In the app these use native dialogs. In the browser there is no
// filesystem, so saving downloads a file and opening uses a file picker -
// enough to keep working, without pretending to be the real thing.
// ---------------------------------------------------------------------

export async function saveProjectFile(contents: string, suggestedName: string): Promise<string | null> {
  if (isTauri()) {
    const { save } = await import("@tauri-apps/plugin-dialog");
    const path = await save({
      defaultPath: suggestedName,
      filters: [
        { name: "Projekt 2 project", extensions: ["pr2proj"] },
        { name: "Structure formula", extensions: ["sexp"] },
      ],
    });
    if (!path) return null;
    await invoke("write_text_file", { path, contents });
    return path;
  }

  const blob = new Blob([contents], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = suggestedName;
  a.click();
  URL.revokeObjectURL(url);
  return suggestedName;
}

/**
 * Writes straight to an already-known path - no dialog. This is what makes
 * "Save" (as opposed to "Save As") silent after the first save: once a path
 * exists, subsequent saves reuse it instead of asking again.
 */
export async function writeProjectFile(path: string, contents: string): Promise<void> {
  if (isTauri()) {
    await invoke("write_text_file", { path, contents });
    return;
  }

  // The browser has no real filesystem to write back into - fall back to
  // the same download behaviour as a fresh save.
  const blob = new Blob([contents], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = path.split("/").pop() ?? path;
  a.click();
  URL.revokeObjectURL(url);
}

export async function openProjectFile(): Promise<{ path: string; contents: string } | null> {
  if (isTauri()) {
    const { open } = await import("@tauri-apps/plugin-dialog");
    const path = await open({
      multiple: false,
      filters: [{ name: "Projekt 2 project", extensions: ["pr2proj"] }],
    });
    if (typeof path !== "string") return null;
    const contents = await invoke<string>("read_text_file", { path });
    return { path, contents };
  }

  return new Promise((resolve) => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = ".pr2proj,.json";
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) return resolve(null);
      resolve({ path: file.name, contents: await file.text() });
    };
    input.click();
  });
}
