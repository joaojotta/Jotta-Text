# Build the Windows installer and portable ZIP

Use Windows 10/11 x64 and an [MSYS2 UCRT64](https://www.msys2.org/) shell. Install
build prerequisites once in that shell:

```bash
pacman -Syu
pacman -S --needed git patch \
  mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-meson \
  mingw-w64-ucrt-x86_64-ninja mingw-w64-ucrt-x86_64-pkgconf \
  mingw-w64-ucrt-x86_64-python mingw-w64-ucrt-x86_64-python-pillow \
  mingw-w64-ucrt-x86_64-nodejs mingw-w64-ucrt-x86_64-SDL2 \
  mingw-w64-ucrt-x86_64-freetype mingw-w64-ucrt-x86_64-harfbuzz \
  mingw-w64-ucrt-x86_64-pcre2 mingw-w64-ucrt-x86_64-librsvg \
  mingw-w64-ucrt-x86_64-libwebp mingw-w64-ucrt-x86_64-libtiff \
  mingw-w64-ucrt-x86_64-nsis
```

Build from the project directory:

```bash
bash scripts/build-windows.sh
python tests/test-windows.py
```

Output, each with its SHA-256 checksum:

- `dist/JottaText-0.7.0-windows-x64-setup.exe`, the installer
- `dist/JottaText-0.7.0-windows-x64-portable.zip`, the portable ZIP

The build script installs nothing. Source and npm dependencies are pinned; the
build uses the installed UCRT64 library versions and collects their imported
DLLs and notices. Later builds can use `--offline` after all source, Meson and
Node caches are present.

## Installer

The installer is per-user and needs no administrator access. It installs to
`%LOCALAPPDATA%\Programs\Jotta Text` by default, adds a Start menu shortcut
(and, if selected, a desktop shortcut) and an entry in **Settings → Apps**.
Settings and unsaved recovery are kept in `%APPDATA%\JottaText`. Running a newer
installer removes the previous version's files first and keeps settings. The
uninstaller removes only the files it installed; it deletes settings only when
you select that option. Silent use: `setup.exe /S`, optionally with
`/D=C:\path\to\folder` as the last argument, unquoted even if the path has
spaces; uninstall with `Uninstall.exe /S`.

The installer is not code-signed, so Windows SmartScreen shows a warning on
first run (**More info → Run anyway**).

## Portable ZIP

Extract the entire ZIP to a writable directory and run **JottaText.exe**. Keep the
DLLs, `data/` and `user/` beside it. Node, formatter, language servers, fonts and
editor tools are bundled. File/folder/save dialogs use Windows Common Item
Dialogs and return Unicode paths. No installer or administrator access is needed.

Settings, remembered folders and unsaved recovery are kept in `user/`. Preserve
that folder when upgrading, and keep source projects in their own directories.
The portable copy does not modify file associations or write registry entries.

## Tests

The test extracts the ZIP to a temporary directory containing spaces and Unicode,
removes MSYS2 from the runtime PATH, starts bundled Node and the editor, checks
unsaved formatting and restarts to verify snapshot replacement and recovery. It
then installs silently to a Unicode path, checks that the installed files match
the ZIP and that settings go to `%APPDATA%\JottaText`, upgrades in place, checks
that unsaved documents survive the upgrade, and uninstalls. Pass `--portable-only`
to skip the installer.
The local cross-built package was tested under Wine; GitHub Actions builds and
tests on a Windows runner. Native chooser appearance still needs a manual check.

The optional GitHub trial additionally requires Git for Windows in PATH.
Browser sign-in uses the bundled GitHub CLI. The trial is disabled by default;
see [GITHUB_TRIAL.md](GITHUB_TRIAL.md).
