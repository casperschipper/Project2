#!/bin/sh
# Build the OCaml engine and copy it to where Tauri expects its sidecar:
# src-tauri/binaries/pr2-engine-<target triple>. Tauri bundles it next to the
# app executable (without the suffix), where lib.rs looks for it.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
engine="$here/../pr26"

command -v opam >/dev/null 2>&1 && eval "$(opam env)"

# On macOS, link the engine for the oldest macOS the app supports, not for
# the macOS doing the build - otherwise on an older Mac the app opens but the
# engine won't start. The linker warns that the OCaml libraries were built
# for a newer macOS; that's expected. Dune doesn't notice this setting, so an
# engine still linked for another version is removed and relinked.
macos_min() {
  otool -l "$1" | awk '/LC_BUILD_VERSION/ { f = 1 } f && /minos/ { print $2; exit }'
}
built="$engine/_build/default/bin/main_sexp.exe"
if [ "$(uname -s)" = Darwin ]; then
  export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
fi
(cd "$engine" && dune build --profile release bin/main_sexp.exe)
if [ "$(uname -s)" = Darwin ] && [ "$(macos_min "$built")" != "$MACOSX_DEPLOYMENT_TARGET" ]; then
  rm -f "$built"
  (cd "$engine" && dune build --profile release bin/main_sexp.exe)
fi

triple=${TAURI_ENV_TARGET_TRIPLE:-$(rustc -vV | sed -n 's/^host: //p')}
mkdir -p "$here/src-tauri/binaries"
install -m 755 "$built" \
  "$here/src-tauri/binaries/pr2-engine-$triple"
echo "engine -> src-tauri/binaries/pr2-engine-$triple"
