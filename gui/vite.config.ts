import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const ENGINE_DIR = path.resolve(here, "..", "pr26");
const ENGINE_EXE = path.join(ENGINE_DIR, "_build", "default", "bin", "main_sexp.exe");
const HELP_DIR = path.resolve(here, "help");

/**
 * Dev-server backend.
 *
 * Tauri needs webkit2gtk dev headers to compile, which aren't always present,
 * and waiting on system packages shouldn't block working on the UI. So the
 * frontend talks to a backend *interface* (see src/engine/backend.ts) with two
 * implementations: Tauri commands when running in the app, and these HTTP
 * routes when running in a plain browser via `npm run dev`. Behaviour is
 * intentionally identical so the browser is a faithful preview.
 */
function backendPlugin(): Plugin {
  return {
    name: "pr2-dev-backend",
    configureServer(server) {
      const readBody = (req: any) =>
        new Promise<string>((resolve, reject) => {
          let data = "";
          req.on("data", (c: Buffer) => (data += c));
          req.on("end", () => resolve(data));
          req.on("error", reject);
        });

      const json = (res: any, status: number, payload: unknown) => {
        res.statusCode = status;
        res.setHeader("Content-Type", "application/json");
        res.end(JSON.stringify(payload));
      };

      server.middlewares.use(async (req, res, next) => {
        const url = new URL(req.url ?? "/", "http://localhost");

        // --- run the engine on a formula -----------------------------------
        if (url.pathname === "/api/run" && req.method === "POST") {
          try {
            const { sexp } = JSON.parse(await readBody(req));
            json(res, 200, await runEngine(sexp));
          } catch (err) {
            json(res, 500, { ok: false, engineError: String(err), errors: [], warnings: [] });
          }
          return;
        }

        // --- help markdown --------------------------------------------------
        // Read from disk on every request (never bundled in dev) so editing a
        // .md file in your editor shows up on the next open of the panel.
        if (url.pathname === "/api/help" && req.method === "GET") {
          const key = url.searchParams.get("key") ?? "";
          json(res, 200, { key, markdown: await readHelp(key) });
          return;
        }

        if (url.pathname === "/api/help" && req.method === "PUT") {
          const key = url.searchParams.get("key") ?? "";
          try {
            const { markdown } = JSON.parse(await readBody(req));
            const file = helpPath(key);
            if (!file) return json(res, 400, { error: "bad help key" });
            await fs.mkdir(path.dirname(file), { recursive: true });
            await fs.writeFile(file, markdown, "utf8");
            json(res, 200, { ok: true });
          } catch (err) {
            json(res, 500, { error: String(err) });
          }
          return;
        }

        next();
      });
    },
  };
}

/** Guard against `..` escaping the help directory. */
function helpPath(key: string): string | null {
  if (!/^[a-z0-9/_-]+$/i.test(key)) return null;
  const file = path.resolve(HELP_DIR, `${key}.md`);
  return file.startsWith(HELP_DIR + path.sep) ? file : null;
}

async function readHelp(key: string): Promise<string | null> {
  const file = helpPath(key);
  if (!file) return null;
  try {
    return await fs.readFile(file, "utf8");
  } catch {
    return null;
  }
}

async function runEngine(sexp: string) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "pr2-run-"));
  const formula = path.join(dir, "formula.sexp");
  await fs.writeFile(formula, sexp, "utf8");

  const useExe = existsSync(ENGINE_EXE);
  const cmd = useExe ? ENGINE_EXE : "dune";
  const args = useExe
    ? [formula, "--json", "--out-dir", dir]
    : ["exec", "bin/main_sexp.exe", "--", formula, "--json", "--out-dir", dir];

  return new Promise((resolve) => {
    const child = spawn(cmd, args, { cwd: ENGINE_DIR });
    let out = "";
    let err = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    child.on("error", (e) =>
      resolve({ ok: false, errors: [], warnings: [], engineError: String(e) }),
    );
    child.on("close", () => {
      fs.rm(dir, { recursive: true, force: true }).catch(() => {});
      try {
        resolve(JSON.parse(out));
      } catch {
        resolve({
          ok: false,
          errors: [],
          warnings: [],
          engineError: err || out || "engine produced no output",
        });
      }
    });
  });
}

export default defineConfig({
  plugins: [react(), backendPlugin()],
  clearScreen: false,
  server: { port: 5173, strictPort: true },
  build: { target: "es2021", sourcemap: true },
});
