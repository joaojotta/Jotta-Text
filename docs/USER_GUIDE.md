# Jotta Text user guide

[← Back to the README](../README.md)

Detailed controls, shortcuts and workspace behavior for the desktop editor.
For browser-specific file handling and limits, see the [web guide](../web/README.md).
Source paths such as `profile/` and `tools/` refer to the project directory.

Editor features ship with the application. There is no plugin marketplace or
plugin installer, and user/project Lua configuration is not executed. User
storage holds settings, recovery and project notes; legacy user plugins and
`init.lua` files are ignored.

## Open files and folders

Starting Jotta Text restores the documents left open at exit, including untitled
files and unsaved edits, without writing those edits to the source files. Tab
order, the active document, all cursors/selections and manually chosen languages
are retained. Both scroll positions are restored too, including in untitled tabs.
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
file starts its language server automatically. CSS properties and values also
complete inside HTML `<style>` blocks and inline `style` attributes, including
hyphenated names such as `background-color` and `inline-flex`. Keypad Enter also
accepts suggestions; without a popup, Tab/Enter keep their normal behavior.
Untitled completion uses an in-memory document identity and does not save a
hidden copy of your work.

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
storage adapters; see [web/README.md](../web/README.md) for its current limits.
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
See [GITHUB_TRIAL.md](../GITHUB_TRIAL.md) for setup, limits, tests and removal.

## Shortcuts

| Shortcut                              | Action                                     |
| ------------------------------------- | ------------------------------------------ |
| Ctrl+O                                | System Open File dialog                    |
| Ctrl+Shift+O                          | System Open Folder dialog                  |
| Ctrl+N / Ctrl+S                       | New file / save                            |
| Ctrl+Shift+S                          | System Save As dialog                      |
| Ctrl+P                                | Quick open within the project              |
| Ctrl+Shift+P                          | Command palette                            |
| Ctrl+Shift+F                          | Project search                             |
| Ctrl+Space                            | Language completion                        |
| Ctrl+Alt+O                            | Show document outline                      |
| F5                                    | Refresh visible document outline           |
| Ctrl+Alt+Shift+F                      | Format document                            |
| Ctrl+Alt+Shift+X                      | Cancel formatting                          |
| Ctrl+Alt+M                            | Markdown preview                           |
| Ctrl+B / Ctrl+\                       | Toggle file explorer (100 ms animation)    |
| Ctrl+= / Ctrl+- / Ctrl+0              | Increase / decrease / reset code font size |
| Ctrl+Alt+= / Ctrl+Alt+- / Ctrl+Alt+0  | Increase / decrease / reset UI font size   |
| Ctrl+Alt+P                            | Web preview                                |
| Ctrl+Alt+1 / Ctrl+Alt+2               | Dark / light theme                         |
| Alt+F / Alt+E / Alt+V / Alt+T / Alt+H | Application menus                          |

## Settings and recovery storage

| Edition                 | Default storage                                             |
| ----------------------- | ----------------------------------------------------------- |
| Native Linux / AppImage | `~/.config/litefront` (respects `XDG_CONFIG_HOME`)          |
| Flatpak                 | `~/.var/app/io.github.joaojotta.JottaText/config/litefront` |
| Windows portable        | `user/` beside `JottaText.exe`                              |
| Web                     | IndexedDB for the site's origin                             |

Jotta Text continues JottaXL and LiteFront. Native builds retain the existing
settings directory. On its first launch, the Jotta Text Flatpak copies previous
JottaXL settings and document recovery if the new settings directory is absent.
The earlier data is retained. Preserve the portable `user/` folder when upgrading;
browser recovery stays with the same site origin.
