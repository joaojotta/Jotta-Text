#!/usr/bin/env bash
# Run in an MSYS2 UCRT64 shell on Windows; produces an installer-free ZIP.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/lib.sh
[[ "${MSYSTEM:-}" == UCRT64 ]] || die 'Run this script in an MSYS2 UCRT64 shell on Windows.'
require_commands '' python gcc meson ninja pkg-config patch objdump rsvg-convert
read_app_version
python tools/fetch-dependencies.py --target windows "$@"
python tools/build-app-icons.py
if ! is_offline "$@"; then
  # Serial downloads: MSYS2 meson aborts parallel fetches with EDEADLK (msvcrt lock timeout).
  download_meson_subprojects --num-processes 1
fi
python tools/prepare-windows-source.py
meson_setup dist/windows-build dist/windows-source --buildtype=release --wrap-mode=nodownload \
  -Dportable=true -Duse_system_lua=false
meson compile -C dist/windows-build
OUT="dist/JottaText-$APP_VERSION-windows-x64-portable"
rm -rf "$OUT"
mkdir -p "$OUT/user"
cp dist/windows-build/src/lite-xl.exe "$OUT/JottaText.exe"
gcc -O2 -Wall -Wextra -municode -o "$OUT/litefront-file-dialog.exe" tools/native/file-dialog-windows.c -lole32 -lshell32 -luuid
python tools/prepare-bundle.py "$OUT/data" --target windows
python tools/package-windows.py "$OUT" "$MINGW_PREFIX"
printf '\nPortable Windows build: %s.zip\nExtract the whole ZIP and run JottaText.exe.\n' "$OUT"
