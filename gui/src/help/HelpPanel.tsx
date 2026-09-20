import React, { useCallback, useEffect, useRef, useState } from "react";
import { marked } from "marked";
import { useStore } from "../state/store";
import { readHelp, writeHelp } from "../engine/backend";

/**
 * The help panel.
 *
 * Content is plain markdown files under `help/`, read from disk on every
 * open, so editing a file in a normal editor shows up immediately without
 * restarting anything. Documents link to each other with ordinary markdown
 * links whose targets are help keys (`concepts/hierarchy`); those are
 * intercepted and navigated inside the panel, which turns the help into
 * something browsable rather than a set of isolated tooltips.
 *
 * The edit button writes back to the same file. It exists because the help
 * text is the teaching material here and is expected to be revised while
 * using the program - noticing a confusing explanation and fixing it should
 * not mean switching windows. It only appears in dev (`import.meta.env.DEV`,
 * true under `npm run dev` / `tauri dev`, false in a built app) - composers
 * running the shipped app shouldn't be able to edit the docs, only the people
 * writing them. The Tauri `write_help` command enforces this too, so it's
 * not just a hidden button.
 */
/**
 * Resolve a markdown link target to a help key.
 *
 * A target containing a slash is already a full key (`concepts/hierarchy`).
 * A bare one is relative to the folder of the document it appears in, so an
 * error page can link to a sibling error as just `unknown-dynamic` - which is
 * what writing these documents naturally produces.
 */
export function resolveHelpLink(currentKey: string, href: string): string {
  const target = href
    .replace(/^\.\//, "")
    .replace(/\.md$/, "")
    .replace(/#.*$/, "");
  if (target.includes("/")) return target.replace(/^\//, "");
  const folder = currentKey.includes("/") ? currentKey.slice(0, currentKey.lastIndexOf("/")) : "";
  return folder ? `${folder}/${target}` : target;
}

export function HelpPanel() {
  const { help, closeHelp, openHelp } = useStore();
  const [markdown, setMarkdown] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");
  const [history, setHistory] = useState<{ key: string; title: string }[]>([]);
  const contentRef = useRef<HTMLDivElement>(null);

  const key = help?.key ?? null;

  const load = useCallback(async (k: string) => {
    setLoading(true);
    const text = await readHelp(k);
    setMarkdown(text);
    setDraft(text ?? "");
    setLoading(false);
  }, []);

  useEffect(() => {
    setEditing(false);
    if (key) load(key);
    else setMarkdown(null);
  }, [key, load]);

  // Scroll back to the top when the document changes, otherwise a short
  // document opened after a long one appears blank.
  useEffect(() => {
    contentRef.current?.scrollTo({ top: 0 });
  }, [markdown]);

  if (!help) return null;

  const navigate = (nextKey: string, nextTitle: string) => {
    setHistory((h) => [...h, { key: help.key, title: help.title }]);
    openHelp(nextKey, nextTitle);
  };

  const goBack = () => {
    const previous = history[history.length - 1];
    if (!previous) return;
    setHistory((h) => h.slice(0, -1));
    openHelp(previous.key, previous.title);
  };

  /**
   * Links whose target looks like a help key stay inside the panel; anything
   * with a scheme is left alone and opens externally.
   */
  const onContentClick = (e: React.MouseEvent) => {
    const anchor = (e.target as HTMLElement).closest("a");
    if (!anchor) return;
    const href = anchor.getAttribute("href") ?? "";
    if (/^[a-z]+:/i.test(href)) return;
    e.preventDefault();
    const target = resolveHelpLink(help.key, href);
    navigate(target, anchor.textContent ?? target);
  };

  const save = async () => {
    if (!key) return;
    await writeHelp(key, draft);
    setMarkdown(draft);
    setEditing(false);
  };

  return (
    <aside className="help">
      <header className="help__header">
        {history.length > 0 && (
          <button type="button" className="btn btn--ghost btn--icon" onClick={goBack} title="Back">
            ←
          </button>
        )}
        <span className="help__title">{help.title}</span>
        {import.meta.env.DEV &&
          (editing ? (
            <>
              <button type="button" className="btn btn--small btn--primary" onClick={save}>
                Save
              </button>
              <button
                type="button"
                className="btn btn--small"
                onClick={() => {
                  setDraft(markdown ?? "");
                  setEditing(false);
                }}
              >
                Cancel
              </button>
            </>
          ) : (
            <button
              type="button"
              className="btn btn--ghost btn--small"
              onClick={() => setEditing(true)}
              title="Edit this help text"
            >
              Edit
            </button>
          ))}
        <button type="button" className="btn btn--ghost btn--icon" onClick={closeHelp} title="Close">
          ×
        </button>
      </header>

      <div className="help__content" ref={contentRef} onClick={onContentClick}>
        {loading && <div className="help__missing">Loading…</div>}

        {!loading && editing && (
          <textarea
            className="help__editor"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            spellCheck={false}
          />
        )}

        {!loading && !editing && markdown && (
          <div dangerouslySetInnerHTML={{ __html: marked.parse(markdown) as string }} />
        )}

        {!loading && !editing && !markdown && (
          <div className="help__missing">
            <p>
              No help has been written for <code>{key}</code> yet.
            </p>
            <p>
              It lives at <code>help/{key}.md</code>.{" "}
              {import.meta.env.DEV
                ? (
                  <>
                    Press <strong>Edit</strong> to write it now, or create the file in your
                    editor — it will be picked up the next time you open this panel.
                  </>
                )
                : "Create the file to add it."}
            </p>
          </div>
        )}
      </div>
    </aside>
  );
}
