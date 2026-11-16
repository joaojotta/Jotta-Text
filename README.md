<p align="center">
  <img src="profile/assets/app-icons/jotta-text-256.png" alt="Jotta Text icon" width="112" height="112">
</p>

<h1 align="center">Jotta Text</h1>

<p align="center">
  A focused editor for code, Markdown and web projects.<br>
  Linux · Windows · Web
</p>

<p align="center">
  <a href="https://github.com/joaojotta/Jotta-Text/actions/workflows/build.yml">
    <img src="https://github.com/joaojotta/Jotta-Text/actions/workflows/build.yml/badge.svg" alt="Build status">
  </a>
</p>

<p align="center">
  <a href="#get-jotta-text">Get Jotta Text</a> ·
  <a href="docs/USER_GUIDE.md">User guide</a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="CHANGELOG.md">Changelog</a>
</p>

---

Jotta Text brings code editing, Markdown authoring and live web previews into
one app. Desktop builds include the formatter, language servers, fonts and
runtimes, so you can start editing without setting up plugins or Node.

Built on [Lite XL](https://github.com/lite-xl/lite-xl), with an interface inspired
by [Jotta Edit](https://github.com/joaojotta/jotta-edit).

## Features

| Feature                | What you get                                                                                                               |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Code editing**       | Syntax highlighting, language detection, diagnostics, Emmet, snippets, and Tab/Enter completion—including CSS inside HTML. |
| **Markdown**           | Formatting toolbar, theme-aware preview, and desktop HTML/PDF export through a Save dialog.                                |
| **Live web preview**   | Browser updates as you edit HTML, CSS and JavaScript, including unsaved changes.                                           |
| **Workspace recovery** | Open files and folders, unsaved documents, cursors, selections and scroll positions restored on restart.                   |
| **Appearance**         | 21 editor palettes and matching UI schemes, a theme editor, Rubik UI and JetBrains Mono code fonts.                        |
| **Visual tools**       | Document outline, resizable explorer, minimap, inline color picker, image viewer and font previews.                        |

The interface is available in **English** and **Português (Portugal)**.
Find the full controls and supported formats in the [user guide](docs/USER_GUIDE.md).
The browser edition has its own [capabilities and limits](web/README.md).

## Get Jotta Text

Download packages and SHA-256 checksums from a successful
[**Build Jotta Text** run](https://github.com/joaojotta/Jotta-Text/actions/workflows/build.yml)
under **Artifacts**. Extract the downloaded artifact ZIP to find the package.
See [VERSION](VERSION) for the current version and [CHANGELOG.md](CHANGELOG.md)
for release notes.

| Edition                 | Package                                        | How to open it                                                  |
| ----------------------- | ---------------------------------------------- | --------------------------------------------------------------- |
| **Linux · Flatpak**     | `JottaText-<version>-x86_64.flatpak`           | Install or update with the command below.                       |
| **Linux · AppImage**    | `JottaText-<version>-x86_64.AppImage`          | Mark the file executable, then open it.                         |
| **Windows · Installer** | `JottaText-<version>-windows-x64-setup.exe`    | Run it; no administrator access is needed.                      |
| **Windows · Portable**  | `JottaText-<version>-windows-x64-portable.zip` | Extract the whole ZIP and run `JottaText.exe`.                  |
| **Web**                 | `JottaText-<version>-web.zip`                  | Extract and serve over HTTP/HTTPS. [Web guide →](web/README.md) |

From the folder containing the downloaded Flatpak bundle:

```bash
flatpak install --user --or-update ./JottaText-*-x86_64.flatpak
```

For a local build, the bundle is in `dist/`. Close and reopen the app after
updating. To upgrade the Windows installer, run the newer installer; it keeps
your settings. For the portable ZIP, preserve the `user/` folder.
[Settings and recovery locations →](docs/USER_GUIDE.md#settings-and-recovery-storage)

Automated desktop builds target x86_64. Local Linux builds also support aarch64.
AppImage compatibility depends on the build machine;
[requirements and FUSE-free startup](docs/DEVELOPMENT.md#build-an-appimage) are
covered in the development guide.

## Getting started

Open a folder with **Ctrl+Shift+O**, or a standalone file with **Ctrl+O**.
Language detection works with saved and untitled documents; click the language
in the status bar to choose one manually.

Use **Ctrl+,** to open Settings for fonts, themes, indentation, language and
editor behavior. Preview and apply changes from the same window.

| Action                      | Shortcut           |
| --------------------------- | ------------------ |
| Command palette             | `Ctrl+Shift+P`     |
| Format the current document | `Ctrl+Alt+Shift+F` |
| Request completion          | `Ctrl+Space`       |
| Accept a suggestion         | `Tab` / `Enter`    |
| Markdown preview            | `Ctrl+Alt+M`       |
| Live web preview            | `Ctrl+Alt+P`       |
| Document outline            | `Ctrl+Alt+O`       |
| Toggle explorer             | `Ctrl+B`           |

[All shortcuts and editing controls →](docs/USER_GUIDE.md#shortcuts)

## GitHub, in three steps

Enable **Preferences → Settings → General → GitHub trial**, then open
**Tools → GitHub (experimental)…** or press **Ctrl+Alt+G**.

1. **Sign in** through your browser using the one-time code.
2. **Choose a local folder** to connect.
3. **Choose a GitHub repository** you can write to.

Click **Connect folder**, then **Sync now**. The app remembers the pairing.
For an existing project's first upload, choose an empty GitHub repository;
an empty local folder can instead download an existing repository.

Sync commits and pushes saved changes while respecting `.gitignore`.
Save open documents first. Use **Changes…** to review diffs and stage files
individually. Conflicting or diverged histories stop for review.

Flatpak includes Git and the browser-login helper. Native Linux/AppImage and
Windows builds use installed Git. This integration remains an optional trial.
[Setup, authentication and limits →](GITHUB_TRIAL.md)

## Build from source

Install the platform prerequisites, then run the appropriate command from the
project directory. The first build downloads pinned dependencies; use
`--offline` on later builds once the caches are populated.

| Target           | Command                          | Setup guide                                 |
| ---------------- | -------------------------------- | ------------------------------------------- |
| Native Linux     | `bash scripts/build-native.sh`   | [Linux](BUILD_UBUNTU.md#native-application) |
| AppImage         | `bash scripts/build-appimage.sh` | [AppImage](BUILD_UBUNTU.md#appimage)        |
| Flatpak          | `bash scripts/build-flatpak.sh`  | [Flatpak](BUILD_UBUNTU.md#flatpak)          |
| Windows          | `bash scripts/build-windows.sh`  | [MSYS2 UCRT64](BUILD_WINDOWS.md)            |
| Web              | `bash scripts/build-web.sh`      | [Emscripten](web/README.md#build-and-run)   |

Run a native build with `bash scripts/run-native.sh`. Build outputs and checksums
are written to `dist/`.

[Build details and engine patches →](docs/DEVELOPMENT.md) ·
[Publishing the project on GitHub →](PUBLISHING.md)

## Development

After a native build, check the source layout and run the editor smoke test:

```bash
python3 tools/check-source.py
python3 tests/run-smoke.py
```

The [development guide](docs/DEVELOPMENT.md#development-checks) covers the full
check suite, offline builds, engine patches and packaging. GitHub Actions builds
and tests Flatpak, AppImage, the Windows installer and portable ZIP, and Web on
pushes and pull requests.

For bug reports, use [Issues](https://github.com/joaojotta/Jotta-Text/issues) and
include your app version, operating system and steps to reproduce the problem.

## Credits and licenses

Jotta Text builds on **Lite XL** and adapts themes and visual assets from
**Jotta Edit**. The interface uses **Rubik**, and the code editor defaults to
**JetBrains Mono**.

Third-party code and assets retain their upstream licenses. Notices are included
in application bundles; see the [asset notices](profile/assets/NOTICE.md),
[asset licenses](profile/assets/licenses/), and
[dependency credits](docs/DEVELOPMENT.md#third-party-code).

Jotta Text continues JottaXL and LiteFront, retaining their features and settings.
