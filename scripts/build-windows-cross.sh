#!/usr/bin/env bash
# Build the Windows installer and portable ZIP on Linux x86_64, without Windows.
# Mirrors scripts/build-windows.sh with llvm-mingw and MSYS2's UCRT64 libraries
# (pinned in tools/windows-cross.lock.json); NSIS runs under Wine unless a native
# makensis is installed. Pass --offline once every download is cached.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/lib.sh
[[ "$(uname -s)-$(uname -m)" == Linux-x86_64 ]] || die 'The Windows cross-build needs Linux x86_64.'
require_commands 'See BUILD_WINDOWS.md.' python3 git npm meson ninja pkg-config patch objdump rsvg-convert
read_app_version
python3 tools/fetch-windows-cross.py "$@"
python3 tools/fetch-dependencies.py --target windows "$@"
python3 tools/build-app-icons.py
if ! is_offline "$@"; then download_meson_subprojects; fi
python3 tools/prepare-windows-source.py
meson_setup dist/windows-cross-build dist/windows-source --cross-file dist/windows-cross.ini \
  --buildtype=release --wrap-mode=nodownload -Dportable=true -Duse_system_lua=false
meson compile -C dist/windows-cross-build
OUT="dist/JottaText-$APP_VERSION-windows-x64-portable"
rm -rf "$OUT"
mkdir -p "$OUT/user"
cp dist/windows-cross-build/src/lite-xl.exe "$OUT/JottaText.exe"
vendor/windows/toolchain/bin/x86_64-w64-mingw32-clang -O2 -Wall -Wextra -municode \
  -o "$OUT/litefront-file-dialog.exe" tools/native/file-dialog-windows.c -lole32 -lshell32 -luuid
python3 tools/prepare-bundle.py "$OUT/data" --target windows
python3 tools/package-windows.py "$OUT" vendor/windows/sysroot/ucrt64
if [[ -z "${MAKENSIS:-}" ]] && ! command -v makensis >/dev/null; then
  require_commands 'Install Wine, or a native makensis, to build the installer.' wine
  # A private Wine prefix keeps ~/.wine untouched.
  export WINEPREFIX="${WINEPREFIX:-$ROOT/dist/wine-nsis}" WINEDEBUG="${WINEDEBUG:--all}"
  export MAKENSIS="wine '$ROOT/vendor/windows/nsis/makensis.exe'"
fi
python3 tools/package-windows-installer.py "$OUT"
printf '\nWindows installer: dist/JottaText-%s-windows-x64-setup.exe\n' "$APP_VERSION"
printf 'Portable Windows build: %s.zip\n' "$OUT"
