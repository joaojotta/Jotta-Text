#!/usr/bin/env bash
# Compile the existing Lite XL/Jotta Text editor for the browser using Emscripten.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/lib.sh
require_commands 'Activate the Emscripten SDK first; see web/README.md.' emcc emar meson ninja python3
for argument in "$@"; do
  case "$argument" in
    --offline) export EM_FROZEN_CACHE=1 ;;
    *) die "Unknown option: $argument" ;;
  esac
done
python3 tools/fetch-dependencies.py --target web "$@"
python3 tools/build-app-icons.py
if ! is_offline "$@"; then download_meson_subprojects; fi
python3 tools/prepare-bundle.py dist/web-data/data --target web
python3 tools/prepare-web.py
python3 tools/configure-web.py
meson_setup dist/web-build vendor/lite-xl --cross-file dist/web-cross.ini --buildtype=release --wrap-mode=nodownload \
  -Dportable=true -Duse_system_lua=false -Ddirmonitor_backend=dummy -Dpcre2:jit=disabled
# Lua/assets are preloaded at link time. Recreate them even when C is unchanged.
rm -f dist/web-build/src/lite-xl.js dist/web-build/src/lite-xl.wasm dist/web-build/src/lite-xl.data
meson compile -C dist/web-build
python3 tools/package-web.py
printf '\nServe the browser build: python3 -m http.server 8080 --directory dist/web\n'
