# Build Jotta Text v0.5 on Ubuntu

Build tools are needed on the developer's machine. The resulting application
bundles its editor features, formatter, language servers and Node runtime.
Users do not install plugins or run a profile setup after installation.

## Native application

```bash
sudo apt update
sudo apt install -y build-essential pkg-config git python3 python3-pil librsvg2-bin nodejs npm meson ninja-build \
  libsdl2-dev libfreetype6-dev libharfbuzz-dev libpcre2-dev libglib2.0-dev librsvg2-dev libwebp-dev libtiff-dev
bash scripts/build-native.sh
bash scripts/run-native.sh
```

The native launcher is `dist/native/bin/jotta-text` (`jottaxl` and `litefront` remain aliases). Keep the `dist/native`
directory together. The first build downloads pinned source dependencies and a
checksum-verified Node runtime. Subsequent builds can use
`bash scripts/build-native.sh --offline` with the populated dependency cache.

Lua is built from the pinned Meson source dependency and linked into the editor.
The build does not depend on a distribution Lua library exporting every symbol
needed by the editor's native API.

The desktop must provide `xdg-desktop-portal` and a backend appropriate to the
desktop, such as `xdg-desktop-portal-gnome`, `xdg-desktop-portal-kde` or
`xdg-desktop-portal-gtk`, for native file and folder dialogs.

## AppImage

With the native prerequisites above installed:

```bash
bash scripts/build-appimage.sh
# Output: dist/JottaText-0.7.1-x86_64.AppImage (or aarch64 on that architecture)
python3 tests/test-appimage.py
```

The first build downloads checksum-verified packaging tools. Later builds can
use `bash scripts/build-appimage.sh --offline`. The script does not install any
packages or the application. Run the output directly, or prefix it with
`APPIMAGE_EXTRACT_AND_RUN=1` on systems without FUSE. Build on the oldest
distribution you intend to support: the AppImage inherits the glibc requirements
of the build machine's native libraries.

## Flatpak

Prepare the build tools and SDK/runtime separately (one-time setup):

```bash
sudo apt install -y flatpak flatpak-builder git meson python3 python3-pil librsvg2-bin nodejs npm
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.freedesktop.Platform//25.08 org.freedesktop.Sdk//25.08
```

Build the distributable bundle:

```bash
bash scripts/build-flatpak.sh
# Output: dist/JottaText-0.7.1-x86_64.flatpak
# Checksum: dist/JottaText-0.7.1-x86_64.flatpak.sha256
```

The script checks that the Freedesktop 25.08 SDK/runtime are already available,
downloads source and build dependencies on the host, compiles the application,
and exports the `.flatpak` bundle. It never installs the application or build
prerequisites, and never changes Flatpak remotes. A missing SDK/runtime stops
the build with a message pointing to these prerequisites. Downloads are disabled
inside the compilation sandbox.

Install a newly built bundle, or update an existing installation:

```bash
flatpak install --user --or-update ./dist/JottaText-0.7.1-x86_64.flatpak
```

Rebuild the Flatpak after source changes; rebuilding the native app leaves the
Flatpak bundle unchanged. Reinstalling the same bundle contains the same code.
Close Jotta Text and reopen it after updating. The build prints the packaged version
and checks it against `VERSION` before producing the bundle.

All features are placed under `/app/share/lite-xl`, with the dialog helper in
`/app/bin`. The application does not load user plugins, native modules or Lua
configuration from `~/.var/app/io.github.joaojotta.JottaText/config/litefront`. Existing
files there may be kept; they are ignored. Session files and notes remain stored
in that directory. No host-spawn permission or host Node installation is needed.

The new application ID installs alongside JottaXL. On first launch, if the new
settings directory is absent, the launcher copies
`~/.var/app/dev.jottaxl.JottaXL/config/litefront` into the new sandbox, preserving
settings, folders and document recovery. Existing new settings take priority;
the old sandbox is never removed or modified.

The app retains home-directory access for source projects and network access for
the local browser preview. Run build scripts without `sudo`.

## Verification

Run the [development checks](docs/DEVELOPMENT.md#development-checks) after a native build. The automated checks cover
startup, themes/menus, the bundled formatter and Markdown renderer, system-dialog
responses, and the localhost preview. A manual desktop pass is still useful for
checking appearance and the host's actual GNOME/KDE chooser.
