# Building and developing Jotta Text

[← Back to the README](../README.md)

Build outputs live in `dist/`. Commands below run from the project directory.
See [Linux prerequisites](../BUILD_UBUNTU.md),
[Windows prerequisites](../BUILD_WINDOWS.md), and the
[web build guide](../web/README.md) for platform setup.

## Automated builds

[.github/workflows/build.yml](../.github/workflows/build.yml) builds **Flatpak,
AppImage, Windows portable and Web** on pushes, pull requests and manual runs.
In GitHub, choose **Actions → Build Jotta Text → Run workflow**. Download the four
packages and their checksums from the completed run's **Artifacts** section.
Tags beginning with `v` must match `VERSION`; CI does not create releases or
publish a website. The Linux/Windows jobs currently build x86_64 only.

The browser job compiles the actual Lite XL engine with Emscripten and tests it
in Chromium. Windows builds on a Windows runner and tests the extracted ZIP
without MSYS2 on its runtime PATH. AppImage builds on Ubuntu 22.04 to keep an
older glibc baseline; Flatpak uses Freedesktop 25.08. Uploads require successful
builds and checks, and the workflow needs no custom secrets.

## Run the native build

Build prerequisites: Python 3, Git, npm, Meson, Ninja, a C compiler, pkg-config,
Pillow, `rsvg-convert`, and development packages for SDL2, FreeType, HarfBuzz, PCRE2, GLib/GIO, librsvg, libwebp and libtiff.
The build includes the pinned Lua runtime instead of the distribution Lua library.
Internet access is needed once to fetch pinned build dependencies.

```bash
bash scripts/build-native.sh
bash scripts/run-native.sh
```

The finished application is `dist/native/bin/jotta-text`.
The old `jottaxl` and `litefront` launchers remain aliases. Existing settings are retained in
`~/.config/litefront`; the Flatpak now uses the `io.github.joaojotta.JottaText` application ID.
It installs separately from the earlier Flatpaks. On first launch, it copies the
previous JottaXL sandbox's settings, open folders and document recovery into its
own settings directory, if that directory does not yet exist. The original data
is retained. Portable Windows keeps `user/`; browser storage keeps the same
workspace when served from the same origin. It uses its own bundled
features; it does not depend on another installed Lite XL profile. With all
sources cached, `bash scripts/build-native.sh --offline` avoids dependency downloads.
`setup-profile.sh` is a compatibility entry point for the Flatpak builder;
it does not install the application or modify an existing profile.

## Build an AppImage

Use the native build prerequisites listed above, plus `ldd` and `sha256sum`:

```bash
bash scripts/build-appimage.sh
# Output: dist/JottaText-0.5.32-x86_64.AppImage (on an x86_64 host)
```

The script builds the editor and packages its native libraries, fonts, Node and
built-in tools. It downloads checksum-verified linuxdeploy, appimagetool and
AppImage runtime releases into `vendor/appimage-tools/` on the first run. With
all dependencies cached, use `bash scripts/build-appimage.sh --offline`.
Add `--no-build` to package an existing native build with a matching version.
Nothing is installed; the executable and its SHA-256 checksum are written to
`dist/`. Builds use the host architecture: x86_64 or aarch64.

Run the resulting file directly:

```bash
./dist/JottaText-0.5.32-x86_64.AppImage
# Without FUSE:
APPIMAGE_EXTRACT_AND_RUN=1 ./dist/JottaText-0.5.32-x86_64.AppImage
```

The AppImage shares the native application's `~/.config/litefront` settings and
session. Close any running native instance before switching builds. The system
still supplies glibc, graphics drivers and desktop services. Bundling libraries
does not lower their glibc requirement: build on the oldest Linux distribution
you intend to support. This source build is not a universal Linux binary.
The v0.5.32 x86_64 artifact built on this Arch system requires **glibc 2.43 or
newer**. Its packaging and editor smoke checks passed on this host; other
distributions and aarch64 have not been tested.

After building, verify the actual image with `python3 tests/test-appimage.py`
(requires `readelf` from binutils). This checks its checksum, startup without
FUSE, document recovery, relocation to a path containing spaces, bundled library
resolution, fonts, Node, formatting, Markdown and the editor smoke harness. It
uses temporary settings and does not change your normal session.

## Build the Flatpak

Install Flatpak, Flatpak Builder, Git, Meson, Python 3 and npm on the build machine:

```bash
bash scripts/build-flatpak.sh
# Output: dist/JottaText.flatpak
```

The script produces `dist/JottaText.flatpak` and its SHA-256 checksum. It does
not install the application, SDK or runtime, or add Flatpak remotes. Install build
prerequisites separately as described in [BUILD_UBUNTU.md](../BUILD_UBUNTU.md).

Install a newly built bundle, or update an existing installation:

```bash
flatpak install --user --or-update ./dist/JottaText.flatpak
```

Rebuild the Flatpak after source changes; rebuilding the native app leaves the
Flatpak bundle unchanged. Reinstalling the same bundle contains the same code.
Close Jotta Text and reopen it after updating. The build prints the packaged version
and checks it against `VERSION` before producing the bundle.

The build fetches pinned feature sources and Node packages on the host, stages
all application data, then compiles offline inside the SDK. All editor features
are included in the resulting bundle.

## Windows portable

Extract `JottaText-VERSION-windows-x64-portable.zip` and run **JottaText.exe**.
Keep its DLLs and `data/` directory together. The `user/` directory beside the
executable holds settings and session recovery; preserve it when upgrading.
No installer or separately installed Node is needed. To build it yourself, use
`bash scripts/build-windows.sh` from an MSYS2 UCRT64 shell as described in
[BUILD_WINDOWS.md](../BUILD_WINDOWS.md).

## Browser edition

```bash
# With Emscripten 4.0.23 activated:
bash scripts/build-web.sh
python3 -m http.server 8080 --directory dist/web
```

Open **http://localhost:8080**. Files, folders, settings and unsaved buffers stay
in the browser's IndexedDB workspace. Save downloads a copy to your device; HTML
preview follows unsaved edits in a sandboxed iframe. Themes, the native Markdown
preview, settings, formatting and outlines work locally. Desktop language servers
are not included. Build/setup instructions and storage limits are in
[web/README.md](../web/README.md).

## Development checks

```bash
python3 tools/check-source.py
python3 tests/test-engine-patch.py
python3 tests/test-flatpak-migration.py
python3 tests/run-smoke.py
python3 tests/test-startup.py
python3 tests/test-session.py
python3 tests/test-workspace-session.py
python3 tests/test-media.py
python3 tests/test-color-picker.py
python3 tests/test-settings.py
python3 tests/test-chrome.py
python3 tests/test-outline.py
python3 tests/test-selectors.py
python3 tests/test-themes.py
python3 tests/test-editing.py
python3 tests/test-language.py
python3 tests/test-recovery.py
python3 tests/test-rounded.py
python3 tests/test-live-preview.py
python3 tests/test-pdf.py  # requires pdfinfo and pdftotext (Poppler)
python3 tests/test-completion.py
cc -Wall -Wextra -Werror tools/native/file-dialog.c -o /tmp/litefront-file-dialog $(pkg-config --cflags --libs gio-2.0)
dbus-run-session -- python3 tests/test_portal.py /tmp/litefront-file-dialog
vendor/litefront/node/node --test --test-isolation=none tests/test-preview.mjs
vendor/litefront/node/node --test --test-isolation=none tests/test-outline.mjs
```

The smoke test runs the actual native editor with a dummy SDL display and an
isolated profile. It checks bundled features, old plugin/config isolation, menus,
themes, formatting, preservation of newer edits and Markdown preview. The portal
tests use a mock desktop service; they do not open windows on your desktop.

## Engine source changes

The build fetches Lite XL v2.1.7 at the revision recorded in
`tools/lite-xl-files.json` and applies `tools/lite-xl.patch`. This preserves the
custom renderer, image support and engine fixes on fresh CI checkouts, without
depending on uncommitted changes inside a nested Git repository. Downloaded
sources and generated artifacts are ignored by the project `.gitignore`.

After intentionally editing files inside `vendor/lite-xl`, run
`python3 tools/refresh-lite-xl-patch.py` and commit the updated patch/manifest
alongside the application changes. Builds verify hashes and stop if local engine
edits have not been recorded; they do not overwrite those edits.

## Application icon

`icons/icon.svg` is the source of the Jotta Text app icon. The build scripts run
`tools/build-app-icons.py` to regenerate the scalable icon, desktop PNG sizes,
compiled native window icon, and welcome/menu logos. SVG filters, colors and
transparency are rasterized with librsvg, preserving the original artwork.
The Flatpak manifest and desktop entry are `flatpak/io.github.joaojotta.JottaText.json`
and `flatpak/io.github.joaojotta.JottaText.desktop`.

## Third-party code

Lite XL, Lite XL LSP, Widgets, LiteMark, language definitions and snippet support
retain their upstream licenses, copied into the application bundle. Node's
license and npm package licenses also ship with their code. Source revisions and
Node archive checksums are recorded in `tools/dependencies.lock.json`; npm
versions and integrity hashes are in `vendor/litefront/tooling/package-lock.json`.
Downloads are a build-time step only.

Imported visual sources and licenses are preserved in `profile/assets/NOTICE.md`
and `profile/assets/licenses/`, and copied into every application bundle. Original
Jotta Edit SVG sources ship alongside their derived native icon font. Rubik uses
the SIL Open Font License. `tools/build-visual-assets.py` can regenerate the font
with fontTools; asset generation is not required to build or run the application.

Lua's MIT notice is preserved in `tools/lua-LICENSE.txt` and included in bundles.
GitHub CLI archives are pinned in `tools/github-cli.lock.json`; see the
[GitHub integration guide](../GITHUB_TRIAL.md) for authentication and testing.
