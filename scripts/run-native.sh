#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -x "$ROOT/dist/native/bin/jotta-text" ]]; then
  bash "$ROOT/scripts/build-native.sh"
fi
exec "$ROOT/dist/native/bin/jotta-text" "$@"
