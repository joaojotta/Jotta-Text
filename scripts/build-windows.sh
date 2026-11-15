#!/usr/bin/env bash
# Run in an MSYS2 UCRT64 shell on Windows; produces an installer-free ZIP.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ "${MSYSTEM:-}" == UCRT64 ]] || { echo 'Run this script in an MSYS2 UCRT64 shell on Windows.' >&2; exit 1; }
for dependency in python gcc meson ninja pkg-config patch objdump rsvg-convert; do
  command -v "$dependency" >/dev/null || { printf 'Missing build prerequisite: %s\n' "$dependency" >&2;exit 1; }
done
APP_VERSION="$(tr -d '\r\n' < VERSION)"
[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid VERSION.' >&2;exit 1; }
python tools/fetch-dependencies.py --target windows "$@"
python tools/build-app-icons.py
if [[ " ${*:-} " != *" --offline "* ]]; then meson subprojects download --sourcedir vendor/lite-xl; fi
python tools/prepare-windows-source.py
setup_args=(dist/windows-build dist/windows-source --buildtype=release --wrap-mode=nodownload -Dportable=true -Duse_system_lua=false)
if [[ -f dist/windows-build/meson-private/coredata.dat ]]; then
  meson setup --reconfigure "${setup_args[@]}"
else
  meson setup "${setup_args[@]}"
fi
meson compile -C dist/windows-build
OUT="dist/JottaText-$APP_VERSION-windows-x64-portable"
rm -rf "$OUT"
mkdir -p "$OUT/user"
cp dist/windows-build/src/lite-xl.exe "$OUT/JottaText.exe"
gcc -O2 -Wall -Wextra -municode -o "$OUT/litefront-file-dialog.exe" tools/native/file-dialog-windows.c -lole32 -lshell32 -luuid
python tools/prepare-bundle.py "$OUT/data" --target windows
python tools/package-windows.py "$OUT" "$MINGW_PREFIX"
printf '\nPortable Windows build: %s.zip\nExtract the whole ZIP and run JottaText.exe.\n' "$OUT"
