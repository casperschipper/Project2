#!/bin/sh
# Build the OCaml engine and copy it to where Tauri expects its sidecar:
# src-tauri/binaries/pr2-engine-<target triple>. Tauri bundles it next to the
# app executable (without the suffix), where lib.rs looks for it.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
engine="$here/../pr26"

command -v opam >/dev/null 2>&1 && eval "$(opam env)"
(cd "$engine" && dune build --profile release bin/main_sexp.exe)

triple=${TAURI_ENV_TARGET_TRIPLE:-$(rustc -vV | sed -n 's/^host: //p')}
mkdir -p "$here/src-tauri/binaries"
install -m 755 "$engine/_build/default/bin/main_sexp.exe" \
  "$here/src-tauri/binaries/pr2-engine-$triple"
echo "engine -> src-tauri/binaries/pr2-engine-$triple"
