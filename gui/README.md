**Project 2 Reimplementation**  

Based on Gottfried Michael Koenig’s *Project 2*  
This version is developed by **Casper Schipper and Luc Döbereiner**

**Software development and implementation:** Casper Schipper  
**Conceptual development and project direction:** Luc Döbereiner  
**Design and development:** Casper Schipper and Luc Döbereiner

Developed with the support of the **Konrad Boehmer Foundation**.

With thanks to **Kees Tazelaar**, **Bjarni Gunnarsson** and **Darien Brito**.

Copyright © Casper Schipper

---

# Projekt 2 — GUI

A desktop interface for the Projekt 2 engine in [`../pr26`](../pr26).

The engine reads a *structure formula* as an s-expression and generates a
variant. This program is a way of writing that formula which explains itself:
every field can open its own documentation, every inconsistency is reported
where it was caused, and every error links to a page explaining why the rule
exists.

## Running it

Two ways, and they behave the same.

**In a browser** — no system dependencies beyond Node:

```sh
npm install
npm run dev          # http://localhost:5173
```

**As a desktop app** — needs the Tauri system libraries (see below):

```sh
npm run app
```

Both need the engine built first:

```sh
cd ../pr26 && dune build
```

The browser mode exists because Tauri needs webkit development headers that
are not always installed, and waiting on system packages should not block
working on the formula. A small Vite plugin (in `vite.config.ts`) provides the
same three operations the Tauri backend does — run the engine, read help, write
help — so the browser is a faithful preview rather than a mock.

### Dependencies

Building or running the desktop app (`npm run app` / `npm run app:build`)
needs, on every platform:

* **Node.js** — see [Node version](#node-version) below.
* **Rust**, via [rustup](https://rustup.rs) — the Cargo project pins
  `rust-version = "1.77"` as its floor; rustup's `stable` channel is fine.
* **The Tauri CLI** — already a `devDependency` (`@tauri-apps/cli`), installed
  by `npm install`; no separate global install needed.
* The OCaml engine, built once per `../pr26/README.md` — the GUI shells out to
  it at run time rather than linking it in.

Browser mode (`npm run dev`) only needs Node and the built engine - none of
the platform-specific WebView tooling below.

### Tauri system dependencies

Tauri wraps the OS's own WebView, so each platform needs that WebView's
development headers (to link against) and, on desktop, a C/C++ toolchain for
Rust to call into it.

**macOS** — Xcode's command-line tools (WebKit itself is a system framework,
no separate package needed):

```sh
xcode-select --install
```

**Windows** —

1. **Microsoft C++ Build Tools**: install [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
   with the "Desktop development with C++" workload (this is what Rust's MSVC
   linker needs).
2. **Rust**: [rustup](https://rustup.rs) defaults to the `-msvc` toolchain on
   Windows, which is the one to use.
3. **WebView2 Runtime**: preinstalled on current Windows 10 (1803+) and
   Windows 11. Only missing on older builds or Windows Server, in which case
   grab the [Evergreen Bootstrapper](https://developer.microsoft.com/microsoft-edge/webview2/) from Microsoft.

**Linux** — package names vary by distribution; Tauri v2 needs
`webkit2gtk-4.1`, an app-indicator library, `librsvg`, and the usual C
toolchain/`openssl`/`curl`/`wget`/`file`; the MIDI preview needs ALSA's
development files. Debian/Ubuntu:

```sh
sudo apt install libwebkit2gtk-4.1-dev libsoup-3.0-dev \
  build-essential curl wget file libxdo-dev libssl-dev \
  libayatana-appindicator3-dev librsvg2-dev libasound2-dev
```

Fedora:

```sh
sudo dnf install webkit2gtk4.1-devel openssl-devel curl wget file \
  libappindicator-gtk3-devel librsvg2-devel alsa-lib-devel
```

Arch:

```sh
sudo pacman -S --needed webkit2gtk-4.1 base-devel curl wget file openssl \
  appmenu-gtk-module gtk3 libappindicator-gtk3 librsvg alsa-lib
```

The runtime library alone is not enough on any distro; the `-dev`/`-devel`
packages are what the Rust build links against. If a package name has moved
on your distro's current release, check
[Tauri's own prerequisites page](https://v2.tauri.app/start/prerequisites/)
for the up-to-date list.

### Node version

Node 18 works but is at its limit — some tooling now requires Node 20+. If you
hit engine-compatibility warnings from npm, upgrading Node is the fix.

## Building a distributable app

```sh
npm install
npm run app:build        # builds the engine, then `tauri build`
```

`npm run app:build` (and `npm run app`) first runs `scripts/prepare-engine.sh`,
which builds the engine with dune and copies it to
`src-tauri/binaries/pr2-engine-<target triple>`. Tauri ships it as a
[sidecar](https://v2.tauri.app/develop/sidecar/) next to the app's executable,
and ships `help/` as a bundle resource, so the result is self-contained: no
`pr26` checkout or OCaml toolchain is needed to run it. On macOS the engine is
linked to run on macOS 11 and later (`MACOSX_DEPLOYMENT_TARGET`), not only on
the macOS it was built on; the linker's warnings that the OCaml libraries
were built for a newer macOS are expected.

On Linux this produces, in `src-tauri/target/release/bundle/`:

* `appimage/Projekt 2_<version>_amd64.AppImage` — a single portable file:
  `chmod +x` it and run it.
* `deb/Projekt 2_<version>_amd64.deb` — for installing on Debian/Ubuntu.

An AppImage runs on distributions whose glibc is at least as new as the build
machine's, so build on the oldest distribution you want to support.

On macOS, build with `npm run app:build:mac` instead: the `targets` list in
`tauri.conf.json` names only the Linux formats, so this passes
`--bundles app,dmg`. It produces, in `src-tauri/target/release/bundle/`:

* `macos/Projekt 2.app` — the app itself, engine and help inside.
* `dmg/Projekt 2_<version>_aarch64.dmg` — the disk image to hand out.

That build is ad-hoc signed (`signingIdentity: "-"`), not notarized, so on
another Mac Gatekeeper blocks the first launch. Fine for testing; for a release
use `npm run app:release:mac`, which does the same build signed with the
Developer ID certificate and notarized by Apple (this takes a few minutes
longer). It needs the certificate and an app-specific password in the login
keychain; see the comment in `scripts/release-mac.sh`. Check the result with
`spctl -a -vv "src-tauri/target/release/bundle/macos/Projekt 2.app"`, which
should say `source=Notarized Developer ID`.

The CI workflow leaves macOS out by default (it costs ten times the Actions
minutes), so for a release build it locally from a clean, committed checkout
and add the `.dmg` to the draft release with
`gh release upload <tag> src-tauri/target/release/bundle/dmg/*.dmg`.

How the app finds the engine and help (`engine_exe`/`help_dir` in
`src-tauri/src/lib.rs`): `PR2_ENGINE_DIR`/`PR2_HELP_DIR` always win. After
that, development builds prefer the live `pr26` dune build and the source
`help/` folder (so engine rebuilds and help edits take effect immediately),
while release builds prefer the copies bundled with them.

Tauri builds one OS's bundles per run and does not cross-compile the OCaml
engine, so macOS and Windows builds are made on those platforms.

## How it fits together

```
src/schema/      the model: types, defaults, sexp emitter, validation
src/engine/      running the engine, routing its diagnostics to fields
src/state/       the store: project state, background validation
src/components/  field wrapper, table editor, principle editor, list editors
src/screens/     one screen per area of the formula
src/help/        the help panel
help/            the help content itself — plain markdown, edit freely
```

### The schema is one file

`src/schema/types.ts` defines the model and `src/schema/sexp.ts` writes it out.
The engine's grammar is still moving, so those two files are deliberately the
only places that know it. `src/schema/validate.ts` holds the checks the GUI
performs itself.

Three places where the model departs from the sexp on purpose:

- Time values are kept as **strings**, because the engine accepts fractions
  (`1/4`) as well as decimals and the composer's notation is meaningful.
- Table cells are always **0-based indices**, even where the engine would also
  accept names. The `start index` setting changes only what is displayed.
- `comment` and `startIndex` are **GUI-only** and never emitted, apart from the
  comment being written into the generated file as sexp comments.

### Errors are the point

The engine was extended with a `--json` flag that emits diagnostics as
structured data: a stable kebab-case id per problem, the location as path
segments, and a payload. The id is the contract — it is also the filename of
the markdown that explains it, in `help/errors/<id>.md`.

The GUI runs its own checks first and only invokes the engine once they pass.
This is not caution but precision: the GUI can point at the individual table
cell holding a bad index, whereas the engine can only fail the whole formula
for the same mistake. Running both would report it twice, less usefully. Once
the form is internally consistent, the engine's own diagnostics — the ones only
it can produce — come through.

Some inconsistencies the engine still cannot report at all (a table index past
the end of its list raises during generation rather than being validated); the
GUI catches those, and `--json` mode additionally wraps generation so a crash
becomes a diagnostic instead of killing the process.

## Editing the help

The help is plain markdown under `help/`, in three folders:

- `help/concepts/` — how Project Two works. `list-table-ensemble-order.md` is
  the central one.
- `help/fields/` — one page per input field.
- `help/errors/` — one page per error id.

Files are read from disk each time the panel opens, so editing one in your
editor shows up immediately. The panel's **Edit** button writes to the same
file if you would rather revise it in place.

Documents link to each other with ordinary markdown links whose targets are
help keys: `[the hierarchy](concepts/hierarchy)`. A bare target is resolved
relative to the current folder, so an error page can link to a sibling as just
`[unknown dynamic](unknown-dynamic)`.

## Checks

```sh
npm run check:emitter   # emitted sexp still round-trips through the engine
npm run check:help      # no broken help links, no field pointing at a missing page
npm run build           # typecheck and bundle
```

`check:emitter` is worth running after any change to the sexp grammar — it
catches the asymmetries that are easy to get wrong (a `sequence` is written
`(sequence (0 1 2))` as an order principle but `(sequence 2)` as an ensemble
selector, and several list fields are double-nested).

## Not done yet

- The output screen shows the engine's text output only. Other formats and
  ways of displaying a score are the obvious next step.
