/**
 * Round-trip check: emit the default project and confirm the engine both
 * parses it and generates a score. Run with `npm run check:emitter`.
 *
 * This guards the sexp grammar's sharp edges (the sequence inline-vs-wrapped
 * asymmetry, the double-nested list fields) which are easy to get subtly
 * wrong and produce a confusing parse error much later.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { defaultProject } from "../src/schema/defaults";
import { toSexp } from "../src/schema/sexp";
import { validateProject } from "../src/schema/validate";

// Resolved from the working directory (npm scripts run in the package root)
// so this still works when the script is bundled and run from elsewhere.
const ENGINE_DIR = process.env.PR2_ENGINE_DIR ?? path.resolve(process.cwd(), "..", "pr26");
const EXE = path.join(ENGINE_DIR, "_build/default/bin/main_sexp.exe");

const project = defaultProject();
const sexp = toSexp(project);

const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pr2-check-"));
const formula = path.join(dir, "formula.sexp");
fs.writeFileSync(formula, sexp);

const res = spawnSync(EXE, [formula, "--json", "--out-dir", dir], {
  cwd: ENGINE_DIR,
  encoding: "utf8",
});

let failed = false;

try {
  const out = JSON.parse(res.stdout.trim());
  console.log(`engine ok: ${out.ok}`);
  for (const d of [...out.errors, ...out.warnings]) {
    console.log(`  ${d.severity}: [${d.path}] ${d.message}`);
  }
  if (!out.ok) failed = true;
  if (out.score) console.log(`score generated: ${out.score.split("\n").length} lines`);
} catch {
  console.error("engine output was not JSON:");
  console.error(res.stdout.slice(0, 500));
  console.error(res.stderr.slice(0, 500));
  failed = true;
}

// The GUI's own checks should agree with the engine on a known-good formula.
const own = validateProject(project);
if (own.length > 0) {
  console.log("gui-side diagnostics on the default project:");
  for (const d of own) console.log(`  ${d.severity}: [${d.path}] ${d.message}`);
  if (own.some((d) => d.severity === "error")) failed = true;
}

fs.rmSync(dir, { recursive: true, force: true });

if (failed) {
  console.error("\nFAILED - emitted sexp was rejected. Emitted formula was:\n");
  console.error(sexp);
  process.exit(1);
}
console.log("\nOK - emitter round-trips through the engine.");
