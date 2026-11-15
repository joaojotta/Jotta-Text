#!/bin/sh
# The renamed Flatpak has a new sandbox. Copy earlier settings only on first run.
set -eu
target="${1:?Expected the settings directory}"
legacy="$HOME/.var/app/dev.jottaxl.JottaXL/config/litefront"
if [ -e "$target" ] || [ ! -d "$legacy" ]; then
  exit 0
fi
mkdir -p "$(dirname -- "$target")"
staging="$(mktemp -d "$(dirname -- "$target")/.jotta-text-migrate.XXXXXX")"
trap 'rm -rf -- "$staging"' EXIT HUP INT TERM
cp -a "$legacy/." "$staging/"
# Never replace a destination created by another instance during the copy.
mv -T --no-clobber -- "$staging" "$target"
