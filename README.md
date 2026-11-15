# Jotta Text v0.5.30

Jotta Text continues JottaXL and LiteFront, carrying forward their features and settings.
See [CHANGELOG.md](CHANGELOG.md) for this cumulative release.
For the first GitHub upload, see [PUBLISHING.md](PUBLISHING.md).

A focused desktop editor for code, Markdown and web projects, built on Lite XL.
The interface adapts [Jotta Edit](https://github.com/joaojotta/jotta-edit)'s visual
design: Rubik typography, its SVG icons, charcoal/light surfaces, yellow accents,
compact file tabs, action rail, editor actions, breadcrumbs, keyboard-shortcut
welcome screen, floating command palette, and 21 built-in editor palettes with 21 matching UI color schemes.

Jotta Text ships its editor features together. There is no plugin marketplace,
plugin installer or executable user/project configuration. Internal Lua modules
remain part of the application implementation; users do not install them.
User storage holds session state and project notes. Old user plugins and
`init.lua` files are ignored, including the incompatible files that caused the
previous startup warning.

## Document outline

Choose **View → Document outline**, click the outline icon in the activity rail,
or press **Ctrl+Alt+O**. The outline replaces the file explorer in the same
resizable sidebar and works without an open folder. Use the folder icon to return
to the explorer. Its selected view, width and visibility survive a restart.

The outline follows the active document and unsaved edits, showing Markdown
headings, HTML elements (including embedded CSS), CSS/SCSS/LESS selectors,
JavaScript/TypeScript/JSX/TSX symbols, PHP classes/functions and Python definitions.
Comments, strings, Markdown front matter and code fences do not create false
entries. The current section is highlighted as the editor cursor moves.

Filter by name, click an entry to jump to its source, or use Up/Down and Enter
while the outline has focus. Ctrl+F focuses its filter; F5 or the refresh button
reloads the outline. Edits are debounced, stale results are discarded, and parsing
runs in a bundled background worker. No source file is saved or executed.
The panel limits results to 1,000 entries and excludes documents larger than 2 MiB.

## Editor and UI color schemes

**Preferences → Settings… → Themes** has separate **Editor color scheme** and
**UI color scheme** dropdowns. Both contain all 21 schemes from Jotta Edit. Focus a selector with Tab and use
the arrow keys to change it; Home/End jump to the first/last choice. Scrolling
the wheel over a closed selector changes its value without scrolling the panel.
An open dropdown keeps normal list scrolling, with Enter to choose and Escape
to dismiss. Changes remain pending until Apply.
The UI defaults to **Follow editor theme**; choose any UI scheme to combine it
with a different editor palette. Selections and custom colors persist between
launches. Theme Editor applies editor and interface overrides to their respective
schemes. Markdown previews, tabs, pickers and dialogs keep readable colors when
combining a light interface with a dark editor, or the reverse.

The imported source files, revision and field catalogue are preserved in
`profile/assets/reference/`, with attribution in `profile/assets/NOTICE.md`.

## Interface language

Choose **Preferences → Settings… → General → UI language** to switch between
**English** and **Português (Portugal)**. Choose **Apply** for an immediate change;
Cancel keeps the current language. The choice persists between launches. Menus,
settings, dialogs, About, color controls and common editing prompts are localized;
filenames, source code and internal command IDs remain unchanged.

## Open files and folders

Starting Jotta Text restores the documents left open at exit, including untitled
files and unsaved edits, without writing those edits to the source files. Tab
order, the active document, selection and manually chosen languages are retained.
Recovery snapshots are written after two seconds of idle time and at least every
15 seconds during continuous editing, protecting unsaved work after a crash.
Snapshots only update application recovery data; source files are left untouched.
Closed tabs stay closed. Open folders also reopen, retaining explorer visibility,
width, expanded directories and selection. A folder explicitly passed at launch
takes priority; missing folders are skipped. With no saved workspace, startup
shows the welcome screen without indexing the launch directory or opening an
arbitrary recent folder. Standalone files still work independently of a project. Project indexing
allows up to 50,000 entries and excludes dependency/build directories such as
`node_modules`, `vendor`, `dist`, `build` and `.flatpak-builder`.

Use **File → Open File…** (`Ctrl+O`) or **File → Open Folder…**
(`Ctrl+Shift+O`). Both use the desktop's standard system dialog, with its usual
places, navigation and filename controls. The welcome screen has the same
actions. Cancel leaves the workspace unchanged; changing folders asks about
unsaved documents.

The explorer shows the opened folder with expandable directories and file-type
icons. Click a file to open it; use the arrow keys and Enter when the explorer
has focus, or Escape to return to the editor. The tree follows file additions,
renames and deletions in the project index and respects its exclusions.

The current folder name appears at the bottom left of the status bar, including
when no document is selected. The dark/light theme button stays pinned at the
bottom right, separate from status messages and scrollable indicators.

Toggle the explorer with the folder icon in the action rail, **View → Toggle Explorer**,
`Ctrl+B` or `Ctrl+\`. The header's close button also hides it. Showing and hiding
animate over **100 ms**; drag the right divider to resize it. The explorer takes
no space until a folder is opened, so standalone files still work independently.

**Save** (`Ctrl+S`) opens the same kind of system dialog for a new file.
**Save As…** (`Ctrl+Shift+S`) always opens it, with the current filename suggested.
Saving an existing file writes directly to its current location. Cancel keeps
the document open and unchanged; the system dialog handles overwrite confirmation.

The tab bar stays visible, including with one file or the welcome screen.
Double-click empty space in the tab bar to create a new untitled file in that
editor pane. Click a tab to switch documents.

Click the language name at the right of the bottom status bar to choose a
language, **Plain Text**, or **Automatic (filename and content)**. The list is searchable. Automatic detection recognizes common HTML, CSS, PHP,
JavaScript, TypeScript, JSON, Python, Lua, shell and Markdown content in unnamed
files or files with unrecognized extensions. Explicit language choices take priority.
HTML, CSS, JSON, JavaScript, JSX, TypeScript and TSX completion also works in an
untitled tab after choosing its language. Suggestions appear while typing; use
`Ctrl+Space` to request them and Tab/Enter to accept a suggestion. Saving a new
file starts its language server automatically. Untitled completion uses an
in-memory document identity and does not save a hidden copy of your work.

In an HTML file or an untitled tab set to HTML, type `!` on a blank line and
press Tab to insert an HTML5 starter. Tab moves through the language and page
title, then places the cursor inside the body. This works immediately, even
while language servers are starting.

A manual choice applies to that document and survives editing and Save As without
changing the filename or marking the document modified. HTML is recognized for
`.html`, `.htm` and `.xhtml`, including mixed-case extensions. Untitled/plain-text
documents with an HTML doctype or opening `<html>` tag are detected automatically;
an explicit Plain Text choice always takes priority.

Warnings, errors and confirmations appear in centered modal dialogs rather than
the coloured status/nag bar. Use Enter to confirm, Escape to cancel/dismiss, and
Tab or the arrow keys to select a button. Long messages can be scrolled. Warning
and error details remain available through **Help → Application Log**.

Linux dialogs use the desktop file chooser portal. A normal GNOME or KDE desktop
provides `xdg-desktop-portal` and its desktop-specific backend. Flatpak uses the
host's chooser without needing to install a dialog utility inside the app.

Font, color scheme, language and Markdown heading pickers have a search field, a scrollable list and a
draggable scrollbar. Click to select, then **Choose** to apply, or double-click
an option. **Cancel**, the close button or Escape dismisses the picker. Scrolling
leaves the search and selection unchanged.

Use **Preferences → UI Font…** or **Code Editor Font…** to search bundled,
system and user fonts. Chosen fonts apply immediately and persist across restarts.
**Reset Fonts** restores Rubik for the interface and JetBrains Mono for code,
with both sizes set to 14. The defaults use the full Rubik and JetBrains Mono
variable fonts supplied in `fonts/`, with explicit regular/semibold UI weights. Preferences also has separate increase, decrease and
reset controls for each size. UI sizing leaves the code size unchanged, and code
sizing leaves the UI unchanged. Both persist across restarts and theme changes.
Use `Ctrl+=` / `Ctrl+-` (or Ctrl+mouse wheel) for code and `Ctrl+Alt+=` /
`Ctrl+Alt+-` for UI. `Ctrl+0` and `Ctrl+Alt+0` reset the respective sizes.

Web Preview also works with a saved standalone HTML file, serving its containing
folder so relative stylesheets, scripts and images load. HTML, CSS and JavaScript changes stream directly from open editor
buffers and refresh the browser while typing, without saving the source files.
An untitled document set to HTML can also be previewed. Selecting another HTML file and invoking preview opens that file.

## Built-in features

- File, Edit, View, Tools and Help menus; welcome shortcuts and recent workspaces.
- Dark/light interfaces with imported Rubik fonts and native SVG-derived icons.
- 21 imported palettes under **View → Syntax Theme…**, including Jotta Dark/Light,
  Monokai, One Dark, Dracula, Nord, Tokyo Night, GitHub and Sublime/VS Code variants.
  Choosing a palette also applies its workbench colors. **View → Explorer Icon
  Colors…** offers nine imported icon schemes or follows the syntax palette.
  Theme and icon choices persist across restarts.
- Compact file-type tabs, a New File button, editor actions, a document minimap
  and a 36 px action rail. The minimap hides in narrow panes and can be toggled
  from **View → Toggle Minimap**. A 6 px top inset separates it from the tabs.
  The rail toggles the file explorer and opens search, preview and formatting actions.
- Floating searchable command, file, language and theme selectors.
- Breadcrumbs, position, indentation, UTF-8 encoding, language and theme controls
  in the status bar; icon-based Markdown controls.
- Tabs, multiple cursors, split editing and project search.
- Syntax highlighting for HTML, CSS, JavaScript, TypeScript, JSX, TSX, PHP,
  Markdown, JSON, YAML and the editor's other bundled languages.
- Language completion and diagnostics for HTML, CSS, JSON, JavaScript and
  TypeScript, plus Emmet completion and snippet insertion.
- Prettier formatting, including PHP, works on untitled files and unsaved edits.
  Formatting updates the buffer in one undo step, follows its tabs/spaces setting,
  preserves edits made while it runs, and leaves disk files unchanged until Save.
  A clickable status item shows progress and cancels the current job; use
  **Tools → Cancel Formatting** or `Ctrl+Alt+Shift+X` too. Documents format
  independently, and stalled jobs time out after 30 seconds without changing them.
- Markdown toolbar with heading levels, bold, italic, underline, strikethrough,
  subscript/superscript, links, images, inline/fenced code, blockquotes, bullet,
  numbered and task lists, horizontal rules, tables and braces. Buttons wrap in
  narrow panes and show tooltips. Formatting acts on selected text or lines.
- Markdown preview alongside editing, including unsaved documents and edits.
  Choose **Markdown** in the status-bar language selector for an untitled file,
  then click Preview or press `Ctrl+Alt+M`. Preview follows the active color theme and selected UI/code fonts, updating
  immediately when either changes. Preview never saves the source.
- **HTML** exports the current Markdown buffer through the system Save dialog.
  **PDF** asks for a destination in the same system Save dialog and writes a PDF
  directly, without opening a browser. Both export the current buffer without
  saving the Markdown source. PDF output supports pagination, tables, styled
  text and local PNG/JPEG images; remote images are not downloaded.
- Local web preview with live browser updates from unsaved buffers, plus reload
  after external static-file changes.

Language clients, servers, formatter, snippets, Markdown renderer, fonts and the
Node runtime and PDF renderer are included in the application. No Node/npm installation or plugin
setup is needed on an end user's machine.

## Settings window

Open **Preferences → Settings…** or press **Ctrl+,** for the draggable, tabbed
Preferences window adapted from Jotta Edit. Its Editor, Themes, Theme Editor,
Explorer, Language Servers, Shortcuts and General sections collect font choices
and sizes, indentation, line spacing, wrapping, minimap, color schemes, custom
interface/syntax colors, explorer options, diagnostics, completion and session
preferences. The Shortcuts section is searchable.

Font and theme samples preview pending choices. Theme Editor opens the custom
color picker and stores overrides separately for each theme. **Reset section**
restores that section's defaults in the draft. **Apply** saves the changes and
updates the editor; **Cancel**, Escape and the close button discard pending
changes. Preferences persist across restarts without editing open documents.
The existing font and color selectors remain available from their menus.

## Inline color picker

CSS, HTML, JavaScript, TypeScript, JSON and PHP files show a small color square
before HEX, RGB/RGBA and HSL/HSLA values. Untitled buffers show these too. Click
the square, or use **Tools → Edit Color at Cursor…**, to open the themed Jotta
Edit-style picker. Swatches occupy visual space without inserting characters;
source positions, selections and wrapped lines keep working normally.

The draggable, scrollable picker has Original/Selected previews, editable HEX,
RGBA, HSL and approximate CMYK controls, hue/saturation/lightness/opacity sliders,
20 presets, named favorites and recent colors. Favorites and recents persist
across restarts. CMYK is converted to CSS-compatible HEX. **Apply** replaces only
the selected value as one undoable edit; **Cancel**, Escape and the close button
leave the source unchanged. Applying a color does not save the file and updates
an active Web Preview through its normal live-buffer connection.

## Images and font files

Open images through **File → Open File…**, the explorer, quick open or the
command line. PNG, JPEG, GIF, BMP, WebP, SVG, ICO and TIFF open in image tabs.
Use **Fit**, **100%**, the zoom buttons or Ctrl+mouse wheel. Drag to pan a zoomed
image; the wheel and scrollbars scroll it. Transparency appears over a themed
checkerboard. GIF animation and multipage TIFF show the first frame/page; WebP previews
currently support static files.
**Reload** refreshes a changed file; SVG tabs also offer **Source** for editing.

TTF, OTF, TTC, WOFF and WOFF2 files open in a font specimen tab. Adjust the sample
size, enter your own sample text and select a weight for variable fonts. TTC files
preview the first face. **Use for UI** and **Use for Code** apply the font to the
respective preference. Font pickers also have a **Preview** button so you can
inspect a font before applying it. Opening and adjusting previews never edits
the source file. Image/font tabs and their preview settings reopen with your session.

This adapts Jotta Edit's visual style; it does not implement that project's full
Git, remote-folder or full settings feature set. PHP highlighting and
formatting are included; PHP execution and a PHP language server are not bundled.
The static preview refuses PHP source files. Markdown rendering uses LiteMark
and does not cover every CommonMark extension; native preview has limited table,
image and inline HTML rendering. HTML/PDF output supports the toolbar's tables,
images, underline, subscript and superscript. Underline, subscript and superscript
use inline HTML tags in Markdown. Export is a lightweight renderer, not a complete
CommonMark implementation. Desktop packaging targets Linux x86_64/aarch64 and
Windows x64. A browser edition uses WebAssembly with browser-specific file and
storage adapters; see [web/README.md](web/README.md) for its current limits.
macOS packaging is not implemented.

## Optional GitHub trial

Enable **Preferences → Settings → General → GitHub trial**, choose **Apply**,
then use **Tools → GitHub (experimental)…** or **Ctrl+Alt+G**. The desktop trial
opens a simple setup screen: **sign in through your browser**, **choose a local
folder**, and **choose a GitHub repository**. Connect once, then use **Sync now**
to commit and push saved changes. The folder/repository pairing is remembered.
An empty local folder downloads the selected repository; to upload an existing
project, choose an empty GitHub repository. **New repository…** opens GitHub's
creation page. **Changes…** retains status/diffs, stage/unstage, commit, fetch
and push controls. The switch defaults to off and can be disabled at any time.

Native/AppImage and Windows builds require installed Git. Desktop packages include
GitHub CLI for browser sign-in; Flatpak also includes Git and needs no host CLI
or terminal login. Sync respects `.gitignore`, uses no force push, and stops for
unsaved documents, conflicting changes or diverged histories. Clean incoming
changes are fast-forwarded. GitHub CLI manages credentials in the system store
when available, with a private configuration-file fallback in app settings.
See [GITHUB_TRIAL.md](GITHUB_TRIAL.md) for setup, limits, tests and removal.

## Automated builds

[.github/workflows/build.yml](.github/workflows/build.yml) builds **Flatpak,
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
[web/README.md](web/README.md).

## Windows portable

Extract `JottaText-VERSION-windows-x64-portable.zip` and run **JottaText.exe**.
Keep its DLLs and `data/` directory together. The `user/` directory beside the
executable holds settings and session recovery; preserve it when upgrading.
No installer or separately installed Node is needed. To build it yourself, use
`bash scripts/build-windows.sh` from an MSYS2 UCRT64 shell as described in
[BUILD_WINDOWS.md](BUILD_WINDOWS.md).

## Run the native build

Build prerequisites: Python 3, Git, npm, Meson, Ninja, a C compiler, pkg-config,
Pillow, `rsvg-convert`, and development packages for SDL2, FreeType, HarfBuzz, PCRE2, Lua 5.4, GLib/GIO, librsvg, libwebp and libtiff.
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
# Output: dist/JottaText-0.5.30-x86_64.AppImage (on an x86_64 host)
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
./dist/JottaText-0.5.30-x86_64.AppImage
# Without FUSE:
APPIMAGE_EXTRACT_AND_RUN=1 ./dist/JottaText-0.5.30-x86_64.AppImage
```

The AppImage shares the native application's `~/.config/litefront` settings and
session. Close any running native instance before switching builds. The system
still supplies glibc, graphics drivers and desktop services. Bundling libraries
does not lower their glibc requirement: build on the oldest Linux distribution
you intend to support. This source build is not a universal Linux binary.
The v0.5.30 x86_64 artifact built on this Arch system requires **glibc 2.44 or
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
prerequisites separately as described in [BUILD_UBUNTU.md](BUILD_UBUNTU.md).

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

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Ctrl+O | System Open File dialog |
| Ctrl+Shift+O | System Open Folder dialog |
| Ctrl+N / Ctrl+S | New file / save |
| Ctrl+Shift+S | System Save As dialog |
| Ctrl+P | Quick open within the project |
| Ctrl+Shift+P | Command palette |
| Ctrl+Shift+F | Project search |
| Ctrl+Space | Language completion |
| Ctrl+Alt+O | Show document outline |
| F5 | Refresh visible document outline |
| Ctrl+Alt+Shift+F | Format document |
| Ctrl+Alt+Shift+X | Cancel formatting |
| Ctrl+Alt+M | Markdown preview |
| Ctrl+B / Ctrl+\ | Toggle file explorer (100 ms animation) |
| Ctrl+= / Ctrl+- / Ctrl+0 | Increase / decrease / reset code font size |
| Ctrl+Alt+= / Ctrl+Alt+- / Ctrl+Alt+0 | Increase / decrease / reset UI font size |
| Ctrl+Alt+P | Web preview |
| Ctrl+Alt+1 / Ctrl+Alt+2 | Dark / light theme |
| Alt+F / Alt+E / Alt+V / Alt+T / Alt+H | Application menus |

## Development checks

```bash
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

## Application icon

`icons/icon.svg` is the source of the Jotta Text app icon. The build scripts run
`tools/build-app-icons.py` to regenerate the scalable icon, desktop PNG sizes,
compiled native window icon, and welcome/menu logos. SVG filters, colors and
transparency are rasterized with librsvg, preserving the original artwork.
The Flatpak manifest and desktop entry are `flatpak/io.github.joaojotta.JottaText.json`
and `flatpak/io.github.joaojotta.JottaText.desktop`.

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
