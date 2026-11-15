#!/usr/bin/env bash
# Compatibility entry point: build the Flatpak; never install a user profile or app.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
printf 'Building the Jotta Text Flatpak bundle. No application will be installed.\n'
exec bash "$ROOT/scripts/build-flatpak.sh" "$@"
