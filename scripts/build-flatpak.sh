#!/usr/bin/env bash
# Build a distributable Flatpak bundle without installing the application.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/lib.sh
read_app_version
require_commands 'See BUILD_UBUNTU.md.' flatpak flatpak-builder git meson python3
# Build prerequisites must already be installed. Never change Flatpak installations here.
for dependency in org.freedesktop.Platform//25.08 org.freedesktop.Sdk//25.08; do
  flatpak info "$dependency" >/dev/null 2>&1 || die "Missing build prerequisite: $dependency. See BUILD_UBUNTU.md."
done
mkdir -p vendor dist
python3 tools/fetch-dependencies.py "$@"
python3 tools/build-app-icons.py
# Stage only application sources and generated assets.
rm -rf dist/jotta-text-stage
mkdir -p dist/jotta-text-stage
cp -a profile scripts flatpak tools icons VERSION CHANGELOG.md dist/jotta-text-stage/
python3 tools/prepare-bundle.py dist/jotta-text-stage/app-data
# Flatpak builds intentionally run without network access. Lite XL's Meson
# wraps would otherwise try to download Lua/SDL2/PCRE2/FreeType *inside* the
# build sandbox and fail with a DNS/connection error. Download them on the host
# first; Meson will reuse these subprojects during Flatpak compilation.
if is_offline "$@"; then
  printf '\nUsing cached Lite XL Meson dependencies (offline).\n'
else
  printf '\nFetching Lite XL Meson dependencies on the host...\n'
  download_meson_subprojects
fi
flatpak-builder --subject="Jotta Text v$APP_VERSION" --user --force-clean --disable-download --disable-rofiles-fuse --repo=dist/flatpak-repo \
  dist/build flatpak/io.github.joaojotta.JottaText.json
BUILT_VERSION="$(tr -d '\r\n' < dist/build/files/share/lite-xl/litefront/VERSION)"
[[ "$BUILT_VERSION" == "$APP_VERSION" ]] || die "Refusing to bundle stale application: expected $APP_VERSION, built $BUILT_VERSION."
rm -f dist/JottaText.flatpak.tmp
flatpak build-bundle dist/flatpak-repo dist/JottaText.flatpak.tmp io.github.joaojotta.JottaText master
mv -f dist/JottaText.flatpak.tmp dist/JottaText.flatpak
sha256sum dist/JottaText.flatpak > dist/JottaText.flatpak.sha256
printf '\nJotta Text v%s Flatpak built: %s/dist/JottaText.flatpak\n' "$APP_VERSION" "$ROOT"
printf 'The application has not been installed.\n'
printf 'All editor features are bundled. No plugin setup is required.\n'
printf 'Install or update: flatpak install --user --or-update ./dist/JottaText.flatpak\n'
