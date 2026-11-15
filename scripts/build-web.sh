#!/usr/bin/env bash
# Compile the existing Lite XL/Jotta Text editor for the browser using Emscripten.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for dependency in emcc emar meson ninja python3; do
  command -v "$dependency" >/dev/null || { printf 'Missing prerequisite: %s. Activate the Emscripten SDK first; see web/README.md.\n' "$dependency" >&2;exit 1; }
done
for argument in "$@"; do
  case "$argument" in
    --offline) export EM_FROZEN_CACHE=1 ;;
    *) printf 'Unknown option: %s\n' "$argument" >&2;exit 1 ;;
  esac
done
python3 tools/fetch-dependencies.py --target web "$@"
python3 tools/build-app-icons.py
if [[ " ${*:-} " != *" --offline "* ]]; then meson subprojects download --sourcedir vendor/lite-xl; fi
python3 tools/prepare-bundle.py dist/web-data/data --target web
python3 tools/prepare-web.py
python3 tools/configure-web.py
setup_args=(dist/web-build vendor/lite-xl --cross-file dist/web-cross.ini --buildtype=release --wrap-mode=nodownload
  -Dportable=true -Duse_system_lua=false -Ddirmonitor_backend=dummy -Dpcre2:jit=disabled)
if [[ -f dist/web-build/meson-private/coredata.dat ]]; then
  meson setup --reconfigure "${setup_args[@]}"
else
  meson setup "${setup_args[@]}"
fi
# Lua/assets are preloaded at link time. Recreate them even when C is unchanged.
rm -f dist/web-build/src/lite-xl.js dist/web-build/src/lite-xl.wasm dist/web-build/src/lite-xl.data
meson compile -C dist/web-build
python3 tools/package-web.py
printf '\nServe the browser build: python3 -m http.server 8080 --directory dist/web\n'
