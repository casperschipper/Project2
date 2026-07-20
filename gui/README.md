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

### Tauri system dependencies

On Debian/Ubuntu:

```sh
sudo apt install libwebkit2gtk-4.1-dev libsoup-3.0-dev \
  build-essential curl wget file libxdo-dev libssl-dev \
  libayatana-appindicator3-dev librsvg2-dev
```

The runtime library alone is not enough; the `-dev` packages are what the
Rust build links against.

### Node version

Node 18 works but is at its limit — some tooling now requires Node 20+. If you
hit engine-compatibility warnings from npm, upgrading Node is the fix.

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
- Pitch, register and harmony are not yet implemented in the engine, so the
  compass and octave-division fields are accepted and validated but do not
  affect the result.
