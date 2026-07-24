use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use std::process::Command;

/// Locate a sibling directory of the GUI project (`pr26` for the engine,
/// `help` for the markdown).
///
/// In development the app runs from `gui/src-tauri`, so walking up from the
/// current directory finds them. Both are overridable by environment variable
/// so the engine can live elsewhere without rebuilding the app.
fn find_dir(env_var: &str, name: &str) -> Option<PathBuf> {
    if let Ok(p) = std::env::var(env_var) {
        let p = PathBuf::from(p);
        if p.is_dir() {
            return Some(p);
        }
    }
    let mut dir = std::env::current_dir().ok()?;
    for _ in 0..6 {
        let candidate = dir.join(name);
        if candidate.is_dir() {
            return Some(candidate);
        }
        if !dir.pop() {
            break;
        }
    }
    None
}

fn engine_dir() -> Option<PathBuf> {
    find_dir("PR2_ENGINE_DIR", "pr26")
}

fn help_dir() -> Option<PathBuf> {
    find_dir("PR2_HELP_DIR", "help")
}

/// Resolve a help key to a path, refusing anything that would escape the help
/// directory.
fn help_path(key: &str) -> Option<PathBuf> {
    if key.is_empty()
        || !key
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_' || c == '/')
    {
        return None;
    }
    let base = help_dir()?;
    let file = base.join(format!("{key}.md"));
    let canonical_base = base.canonicalize().ok()?;
    // The file may not exist yet (writing new help), so canonicalize its parent.
    let parent = file.parent()?.canonicalize().ok()?;
    if parent.starts_with(&canonical_base) {
        Some(file)
    } else {
        None
    }
}

fn engine_error(msg: impl Into<String>) -> Value {
    json!({ "ok": false, "errors": [], "warnings": [], "engineError": msg.into() })
}

/// List the `.mid` files sitting directly in `dir`, sorted, as absolute paths.
fn midi_files_in(dir: &Path) -> Vec<String> {
    let mut files: Vec<String> = std::fs::read_dir(dir)
        .into_iter()
        .flatten()
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|p| p.extension().and_then(|e| e.to_str()) == Some("mid"))
        .map(|p| p.display().to_string())
        .collect();
    files.sort();
    files
}

/// Write the formula to a directory, run the engine there with `--json`, and
/// return its parsed output.
///
/// When `out_dir` is `None` (the live, validate-as-you-type path) a scratch
/// temp directory is used and removed the instant the engine finishes, so
/// typing doesn't churn files anywhere real. When `out_dir` is `Some` (an
/// explicit Run the composer asked for) the score/entries/MIDI files are
/// written there directly and kept - the whole point of this branch. The
/// returned JSON additionally carries `midiFiles`, the list of `.mid` files
/// produced, but only in the `Some` case (the ephemeral path has nothing
/// useful to point at once the temp directory is gone).
#[tauri::command]
fn run_engine(sexp: String, out_dir: Option<String>) -> Value {
    let Some(dir) = engine_dir() else {
        return engine_error(
            "could not find the engine directory (expected a 'pr26' folder \
             beside the GUI, or set PR2_ENGINE_DIR)",
        );
    };

    let exe = dir.join("_build/default/bin/main_sexp.exe");
    if !exe.exists() {
        return engine_error(format!(
            "the engine is not built - run `dune build` in {}",
            dir.display()
        ));
    }

    // Keeps the TempDir guard alive for the ephemeral case (it deletes on
    // drop, at the end of this function) without needing one in the
    // persistent case at all.
    let _tmp_guard;
    let run_dir: PathBuf = match &out_dir {
        Some(p) => {
            let pb = PathBuf::from(p);
            if let Err(e) = std::fs::create_dir_all(&pb) {
                return engine_error(format!("could not create the output directory: {e}"));
            }
            _tmp_guard = None;
            pb
        }
        None => match tempfile::tempdir() {
            Ok(t) => {
                let p = t.path().to_path_buf();
                _tmp_guard = Some(t);
                p
            }
            Err(e) => return engine_error(format!("could not create a scratch directory: {e}")),
        },
    };

    let formula = run_dir.join("formula.sexp");
    if let Err(e) = std::fs::write(&formula, &sexp) {
        return engine_error(format!("could not write the formula: {e}"));
    }

    let output = Command::new(&exe)
        .arg(&formula)
        .arg("--json")
        .arg("--out-dir")
        .arg(&run_dir)
        .current_dir(&dir)
        .output();

    match output {
        Err(e) => engine_error(format!("could not start the engine: {e}")),
        Ok(out) => {
            let stdout = String::from_utf8_lossy(&out.stdout);
            match serde_json::from_str::<Value>(stdout.trim()) {
                Ok(mut v) => {
                    if out_dir.is_some() {
                        if let Value::Object(ref mut map) = v {
                            map.insert(
                                "midiFiles".to_string(),
                                json!(midi_files_in(&run_dir)),
                            );
                        }
                    }
                    v
                }
                Err(_) => {
                    let stderr = String::from_utf8_lossy(&out.stderr);
                    engine_error(if !stderr.trim().is_empty() {
                        stderr.to_string()
                    } else if !stdout.trim().is_empty() {
                        stdout.to_string()
                    } else {
                        "the engine produced no output".to_string()
                    })
                }
            }
        }
    }
}

/// Read one help document. Returns null when it doesn't exist yet, which the
/// UI shows as a "not written yet" placeholder rather than an error.
#[tauri::command]
fn read_help(key: String) -> Option<String> {
    std::fs::read_to_string(help_path(&key)?).ok()
}

#[tauri::command]
fn write_help(key: String, markdown: String) -> Result<(), String> {
    let path = help_path(&key).ok_or_else(|| format!("invalid help key: {key}"))?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    std::fs::write(&path, markdown).map_err(|e| e.to_string())
}

#[tauri::command]
fn read_text_file(path: String) -> Result<String, String> {
    std::fs::read_to_string(Path::new(&path)).map_err(|e| e.to_string())
}

#[tauri::command]
fn write_text_file(path: String, contents: String) -> Result<(), String> {
    std::fs::write(Path::new(&path), contents).map_err(|e| e.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            run_engine,
            read_help,
            write_help,
            read_text_file,
            write_text_file
        ])
        .run(tauri::generate_context!())
        .expect("error while running the Projekt 2 GUI");
}
