#!/usr/bin/env bash
# Build a complete AppImage without installing the application or host packages.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/lib.sh
OFFLINE=false
NO_BUILD=false
for argument in "$@"; do
  case "$argument" in
    --offline) OFFLINE=true ;;
    --no-build) NO_BUILD=true ;;
    -h|--help)
      printf 'Usage: bash scripts/build-appimage.sh [--offline] [--no-build]\n\n'
      printf 'Builds native Jotta Text and bundles its libraries and tools into dist/JottaText-VERSION-ARCH.AppImage.\n'
      printf '  --offline   Use cached editor dependencies and verified AppImage tools only.\n'
      printf '  --no-build  Package an already-built dist/native with a matching VERSION.\n'
      exit 0 ;;
    *) die "Unknown option: $argument" ;;
  esac
done
read_app_version
APP_ARCH="$(uname -m)"
case "$APP_ARCH" in x86_64|aarch64) ;; *) die "Unsupported AppImage architecture: $APP_ARCH" ;; esac
require_commands '' python3 ldd
BUILD_ARGS=()
if "$OFFLINE"; then BUILD_ARGS+=(--offline); fi
python3 tools/fetch-appimage-tools.py --arch "$APP_ARCH" "${BUILD_ARGS[@]}"
if ! "$NO_BUILD"; then bash scripts/build-native.sh "${BUILD_ARGS[@]}"; fi
BUILT_VERSION="$(tr -d '\r\n' < dist/native/share/lite-xl/litefront/VERSION)"
[[ "$BUILT_VERSION" == "$APP_VERSION" ]] || die "Refusing to package stale native data: expected $APP_VERSION, found $BUILT_VERSION. Run without --no-build."
for file in bin/lite-xl bin/jotta-text bin/litefront-file-dialog share/lite-xl/litefront/node/node; do
  [[ -x "dist/native/$file" ]] || die "Missing native executable: $file. Run without --no-build."
done
APPDIR="$ROOT/dist/JottaText.AppDir"
TOOLS="$ROOT/vendor/appimage-tools/$APP_ARCH"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr"
cp -a dist/native/. "$APPDIR/usr/"
install -m755 scripts/appimage-launcher "$APPDIR/AppRun"
# SDL2 compatibility builds load SDL3 via dlopen, outside the ELF dependency tree.
EXTRA_LIBS=()
python3 tools/appimage-extra-libs.py "$APPDIR/usr/bin/lite-xl" \
  "$APPDIR/usr/bin/litefront-file-dialog" "$APPDIR/usr/share/lite-xl/litefront/node/node" \
  > "$ROOT/dist/appimage-extra-libs.txt"
while IFS= read -r library; do EXTRA_LIBS+=(--library "$library"); done < "$ROOT/dist/appimage-extra-libs.txt"
NO_STRIP=1 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOLS/linuxdeploy.AppImage" --verbosity=2 \
  --appdir "$APPDIR" --deploy-deps-only "$APPDIR/usr" \
  --deploy-deps-only "$APPDIR/usr/share/lite-xl/litefront/node/node" \
  --desktop-file "$APPDIR/usr/share/applications/io.github.joaojotta.JottaText.desktop" \
  --icon-file "$APPDIR/usr/share/icons/hicolor/256x256/apps/io.github.joaojotta.JottaText.png" \
  --custom-apprun "$ROOT/scripts/appimage-launcher" "${EXTRA_LIBS[@]}"
# A raster root icon also works with older desktop integration tools.
install -m644 "$APPDIR/usr/share/icons/hicolor/256x256/apps/io.github.joaojotta.JottaText.png" \
  "$APPDIR/io.github.joaojotta.JottaText.png"
ln -sfn io.github.joaojotta.JottaText.png "$APPDIR/.DirIcon"
# Recheck the version after deployment and give the image an explicit, stable name.
[[ "$(tr -d '\r\n' < "$APPDIR/usr/share/lite-xl/litefront/VERSION")" == "$APP_VERSION" ]] \
  || die 'AppDir version changed during deployment.'
OUTPUT="$ROOT/dist/JottaText-$APP_VERSION-$APP_ARCH.AppImage"
rm -f "$OUTPUT.tmp"
ARCH="$APP_ARCH" VERSION="$APP_VERSION" APPIMAGE_EXTRACT_AND_RUN=1 \
  "$TOOLS/appimagetool.AppImage" --no-appstream --runtime-file "$TOOLS/runtime" \
  --mksquashfs-opt -processors --mksquashfs-opt 2 "$APPDIR" "$OUTPUT.tmp"
chmod 755 "$OUTPUT.tmp"
mv -f "$OUTPUT.tmp" "$OUTPUT"
# Name only the file, so the checksum verifies wherever the download is saved.
(cd "$(dirname "$OUTPUT")" && sha256sum "$(basename "$OUTPUT")" > "$OUTPUT.sha256")
printf '\nJotta Text v%s AppImage built: %s\n' "$APP_VERSION" "$OUTPUT"
printf 'Run: %s\n' "./${OUTPUT#"$ROOT/"}"
printf 'The application has not been installed.\n'
