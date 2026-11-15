#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 tools/fetch-dependencies.py "$@"
python3 tools/build-app-icons.py
if [[ " ${*:-} " != *" --offline "* ]]; then meson subprojects download --sourcedir vendor/lite-xl; fi
mkdir -p dist/native/bin
# Use the pinned Lua runtime: distribution builds can omit symbols exported by
# Lite XL's native API even when their reported Lua version matches.
setup_args=(dist/native-build vendor/lite-xl --buildtype=release --wrap-mode=nodownload -Dportable=false -Duse_system_lua=false --prefix="$ROOT/dist/native")
if [[ -f dist/native-build/meson-private/coredata.dat ]]; then
  meson setup --reconfigure "${setup_args[@]}"
else
  meson setup "${setup_args[@]}"
fi
meson compile -C dist/native-build
meson install -C dist/native-build
python3 tools/prepare-bundle.py dist/native/share/lite-xl
cc -O2 -Wall -Wextra -o dist/native/bin/litefront-file-dialog tools/native/file-dialog.c $(pkg-config --cflags --libs gio-2.0)
install -m755 scripts/native-launcher dist/native/bin/jotta-text
ln -sf jotta-text dist/native/bin/litefront
ln -sf jotta-text dist/native/bin/jottaxl
printf '\nReady: %s/dist/native/bin/jotta-text\n' "$ROOT"
# Native distribution desktop assets use the same Jotta Text identity as Flatpak.
install -Dm644 flatpak/io.github.joaojotta.JottaText.desktop dist/native/share/applications/io.github.joaojotta.JottaText.desktop
install -Dm644 flatpak/io.github.joaojotta.JottaText.svg dist/native/share/icons/hicolor/scalable/apps/io.github.joaojotta.JottaText.svg
for size in 32 48 64 128 256 512; do
  install -Dm644 "profile/assets/app-icons/jotta-text-$size.png" "dist/native/share/icons/hicolor/${size}x${size}/apps/io.github.joaojotta.JottaText.png"
done
rm -f dist/native/share/applications/org.lite_xl.lite_xl.desktop
rm -f dist/native/share/applications/dev.jottaxl.JottaXL.desktop
rm -f dist/native/share/metainfo/org.lite_xl.lite_xl.appdata.xml
