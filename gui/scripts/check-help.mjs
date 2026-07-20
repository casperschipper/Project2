/**
 * Check the help content for broken cross-links and for topics the program
 * can ask for but that nobody has written yet.
 *
 * The help is the teaching material here, so a dead link is a real defect
 * rather than a cosmetic one: it is the moment a reader following an
 * explanation hits a wall. Run with `npm run check:help`.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HELP = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "help");
const SRC = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "src");

/** Every help document that exists, as a key. */
function existingKeys() {
  const keys = new Set();
  for (const folder of fs.readdirSync(HELP)) {
    const dir = path.join(HELP, folder);
    if (!fs.statSync(dir).isDirectory()) continue;
    for (const file of fs.readdirSync(dir)) {
      if (file.endsWith(".md")) keys.add(`${folder}/${file.replace(/\.md$/, "")}`);
    }
  }
  return keys;
}

/** Mirrors resolveHelpLink in the panel: bare targets are folder-relative. */
function resolveLink(currentKey, href) {
  const target = href.replace(/^\.\//, "").replace(/\.md$/, "").replace(/#.*$/, "");
  if (target.includes("/")) return target.replace(/^\//, "");
  const folder = currentKey.includes("/") ? currentKey.slice(0, currentKey.lastIndexOf("/")) : "";
  return folder ? `${folder}/${target}` : target;
}

const keys = existingKeys();
let problems = 0;

// --- broken links ----------------------------------------------------
const broken = new Map();
for (const key of keys) {
  const text = fs.readFileSync(path.join(HELP, `${key}.md`), "utf8");
  for (const match of text.matchAll(/\]\(([^)]+)\)/g)) {
    const href = match[1].trim();
    if (/^[a-z]+:/i.test(href) || href.startsWith("#")) continue;
    const target = resolveLink(key, href);
    if (!target || keys.has(target)) continue;
    if (!broken.has(target)) broken.set(target, []);
    broken.get(target).push(key);
  }
}

if (broken.size > 0) {
  problems += broken.size;
  console.log(`Broken help links (${broken.size} missing targets):`);
  for (const [target, sources] of [...broken].sort((a, b) => b[1].length - a[1].length)) {
    console.log(`  ${target}  — referenced by ${sources.length}: ${sources.slice(0, 3).join(", ")}${sources.length > 3 ? ", …" : ""}`);
  }
  console.log();
}

// --- help keys the UI can request ------------------------------------
// Scanning the source for helpKey="…" catches a field pointing at a document
// that was never written, which otherwise only shows up when a reader clicks
// that particular label.
const referenced = new Set();
function scan(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) scan(full);
    else if (/\.tsx?$/.test(entry.name)) {
      const text = fs.readFileSync(full, "utf8");
      for (const m of text.matchAll(/helpKey[=:]\s*["'`]([^"'`$]+)["'`]/g)) referenced.add(m[1]);
      for (const m of text.matchAll(/helpKey=\{`([^`$]+)`\}/g)) referenced.add(m[1]);
    }
  }
}
scan(SRC);

const missingFromUi = [...referenced].filter((k) => !keys.has(k)).sort();
if (missingFromUi.length > 0) {
  problems += missingFromUi.length;
  console.log(`Help topics the interface links to but which do not exist (${missingFromUi.length}):`);
  for (const k of missingFromUi) console.log(`  ${k}`);
  console.log();
}

// --- every diagnostic id must have an explanation --------------------
// These keys are built at runtime (`errors/${d.id}`), so scanning for literal
// helpKey strings cannot see them. They are the ones that matter most: an
// error with no explanation is exactly the moment the help is needed.
const ids = new Set();

// The GUI's own checks: diag("some-id", ...)
const validate = fs.readFileSync(path.join(SRC, "schema", "validate.ts"), "utf8");
for (const m of validate.matchAll(/\bdiag\(\s*["']([a-z0-9-]+)["']/g)) ids.add(m[1]);

// The engine's ids, from problem_id in the OCaml.
const parametersMl = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..", "..", "pr26", "lib", "parameters.ml",
);
if (fs.existsSync(parametersMl)) {
  const ml = fs.readFileSync(parametersMl, "utf8");
  const section = ml.slice(ml.indexOf("let problem_id"));
  const body = section.slice(0, section.indexOf("\n\n"));
  for (const m of body.matchAll(/->\s*"([a-z0-9-]+)"/g)) ids.add(m[1]);
}

const missingErrors = [...ids].filter((id) => !keys.has(`errors/${id}`)).sort();
if (missingErrors.length > 0) {
  problems += missingErrors.length;
  console.log(`Diagnostics with no explanation written (${missingErrors.length}):`);
  for (const id of missingErrors) console.log(`  help/errors/${id}.md`);
  console.log();
}

if (problems === 0) {
  console.log(
    `OK — ${keys.size} help documents, no broken links, ` +
      `all ${ids.size} diagnostic ids explained.`,
  );
} else {
  console.log(`${problems} problem(s) found.`);
  process.exit(1);
}
