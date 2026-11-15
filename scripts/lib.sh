#!/usr/bin/env bash
# Shared helpers for the build scripts. Source this after changing to the project root.

# Print a message to stderr and stop the build.
die() {
  printf '%s\n' "$*" >&2
  exit 1
}

# Stop unless every named command is available. The first argument is a hint
# appended to the error message.
require_commands() {
  local hint="$1" dependency
  shift
  for dependency in "$@"; do
    command -v "$dependency" >/dev/null || die "Missing build prerequisite: $dependency.${hint:+ $hint}"
  done
}

# Set APP_VERSION from VERSION; every package requires MAJOR.MINOR.PATCH.
read_app_version() {
  APP_VERSION="$(tr -d '\r\n' < VERSION)"
  [[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid VERSION: '$APP_VERSION' (expected MAJOR.MINOR.PATCH)."
}

# True when --offline is among the given arguments.
is_offline() {
  local argument
  for argument in "$@"; do
    [[ "$argument" == --offline ]] && return 0
  done
  return 1
}

# Download Lite XL's Meson wraps on the host. Extra arguments go to meson.
download_meson_subprojects() {
  meson subprojects download "$@" --sourcedir vendor/lite-xl
}

# Configure a Meson build directory, reconfiguring one that already exists.
# Usage: meson_setup BUILD_DIR SOURCE_DIR [options...]
meson_setup() {
  if [[ -f "$1/meson-private/coredata.dat" ]]; then
    meson setup --reconfigure "$@"
  else
    meson setup "$@"
  fi
}
