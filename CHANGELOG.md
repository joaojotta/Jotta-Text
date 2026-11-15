# Changelog

## Jotta Text v0.6.1 — 2026-11-15

- Web: report startup problems on the page instead of staying on "Loading Jotta
  Text…" with every button disabled, for example when only `index.html` was
  extracted from the ZIP or a script cannot load. If browser storage does not
  answer within 10 seconds, start without it and say so.
- Web: test the compiled editor in Firefox as well as Chromium.
- AppImage and Flatpak checksum files name only the package, so
  `sha256sum -c` works wherever the download is saved. The Flatpak bundle is
  now named `JottaText-<version>-x86_64.flatpak`.
- GitHub Actions publishes the release with all packages when a `v*` tag is
  built successfully, and checks Python and shell code with ruff and
  shellcheck.
- Run the native file dialog test (renamed `tests/test-portal.py`) in CI; fix
  unused imports and variables found by ruff.

## Jotta Text v0.6.0 — 2026-11-15

No visible or behavioural changes to the editor; this release fixes the Windows
build and tidies the build tooling.

- Read and write bundled sources as UTF-8 on Windows. The portable build stopped
  while preparing application data because Python used the cp1252 locale.
- Make every upstream patch in `tools/prepare-bundle.py` fail loudly when its
  anchor is missing, group patches per file and read the engine version from
  the pinned Lite XL source. Remove one patch that never applied.
- Stop the build when a bundled source checkout under `vendor/litefront` has
  local edits, so packages always match what GitHub builds.
- Share version, prerequisite, offline and Meson setup handling between build
  scripts in `scripts/lib.sh`; every package now requires MAJOR.MINOR.PATCH.
- Keep Python, Node and pip pins in one place in the GitHub workflow.
- Add `.editorconfig`; remove redundant Lua `require` calls and split an
  overlong recovery fingerprint expression.

## Jotta Text v0.5.33 — 2026-11-15

- Apply the minimap top inset, Markdown preview for any Markdown-syntax buffer
  (without forcing a save) and LSP hover suppression over inline colours during
  bundling. These changes previously existed only in local vendor checkouts, so
  GitHub-built packages lacked them and the AppImage visuals test failed.
- Download Windows Meson subprojects serially; MSYS2 Meson aborted parallel
  downloads with "Resource deadlock avoided".
- Mark every build script executable.

## Jotta Text v0.5.32 — 2026-11-15

- Invoke npm's JavaScript entry point through Node so the Windows/MSYS2 bootstrap
  does not try to execute a shell shim. Send the Windows Lua patch as LF bytes.
- Upgrade official GitHub actions to releases using Node 24 and add npm bootstrap
  checks, including real installations in paths containing spaces/shell characters.
- Preserve AppImage startup stdout, stderr and recovery errors, avoid pipe stalls,
  allow cold extraction time, and upload diagnostic artifacts on a failed build.
- Keep scheduled editor tasks running without window focus; this fixes the Ubuntu
  AppImage recovery check and background recovery/language-server stalls.

## Jotta Text v0.5.31 — 2026-11-15

- Fix GitHub builds: use the pinned Lua runtime for native/AppImage builds,
  normalize engine patches and fetched sources to LF on Windows, and check
  required source files before starting platform jobs. Remove the accidental
  nested clone from tracking while preserving its local files.
- Restore every cursor and selection direction, the primary cursor, and both
  scroll positions for saved and untitled documents. Include viewport/cursor
  changes in periodic recovery and retain compatibility with earlier snapshots.
- Accept completion with Tab, Enter and keypad Enter while preserving normal
  indentation, newlines, HTML starter expansion and snippet navigation.
- Keep hyphenated CSS properties/values and HTML attributes together when matching
  suggestions, including CSS in style blocks and inline style attributes. Enable
  embedded HTML language services explicitly and ignore completions from inactive
  documents. Preserve JavaScript subtraction boundaries inside script blocks.
- Test actual editor restarts and real bundled language servers on native Linux
  and Flatpak; add both regressions to the GitHub build workflow.

## Jotta Text v0.5.30 — 2026-11-15

- Replace terminal-only GitHub setup with browser sign-in, a local folder chooser
  and a repository picker. Remember the pairing and supply missing commit author
  details from the account without changing global Git configuration.
- Bundle checksum-pinned GitHub CLI on desktop builds so Flatpak authentication
  works within its existing sandbox. Keep credential handling outside the UI;
  show/copy only the one-time browser code and support cancellation/sign-out.
- Add Sync now for saved files: respect .gitignore, commit and push without force,
  download clean fast-forward updates, and stop on unsaved work or divergent
  histories. Preserve the detailed Changes view for reviewing individual files.
- Test login progress, repository selection, connection recovery, first uploads,
  empty-folder downloads and conflict handling with isolated fixtures/local Git
  remotes. Preserve the existing optional trial switch and Portuguese UI.

## Jotta Text v0.5.29 — 2026-11-15

- Rename the application to Jotta Text across the interface, translations,
  desktop integration, Windows portable, browser edition and build workflows.
- Use JottaText package filenames, the jotta-text launcher and the application
  ID io.github.joaojotta.JottaText. Keep the earlier Linux launcher aliases.
- Preserve native settings and portable/browser recovery; copy previous Flatpak
  settings into the new sandbox on first launch without overwriting new data.
- Add a clean source archive and GitHub publishing instructions, excluding
  downloaded dependencies, generated builds and local configuration.

## JottaXL v0.5.28 — 2026-11-15

- Add an optional desktop GitHub trial, disabled by default in General settings,
  with an isolated background Git worker and a removable UI module.
- Support GitHub clone, branch/status, working and staged diff snapshots,
  stage/unstage, staged-only commit, fetch and non-forced push to origin, plus
  repository/issues/pull-request browser links. Preserve unsaved editor buffers.
- Reuse installed Git and its credentials on native/Windows builds; bundle SDK
  Git tools for Flatpak without adding host-execution permission. Preserve Git
  signing/hooks, reject stale commit snapshots and allow process cancellation.
- Localize the trial UI in Portuguese (Portugal). Test real editor interaction,
  local bare remotes, linked worktrees, rejected pushes and public HTTPS clones.
  Keep the browser edition's Git integration disabled.

## JottaXL v0.5.27 — 2026-11-15

- Add GitHub Actions builds and artifact uploads for Flatpak, AppImage, Windows
  portable and the browser edition, with version/tag validation and package tests.
- Add a Lite XL WebAssembly edition using the shared JottaXL UI, themes,
  Portuguese translation, font controls, settings and Markdown authoring tools.
- Import files/folders into browser storage, recover open and unsaved documents
  through IndexedDB, download edited copies, and preview HTML in a sandbox with
  live unsaved updates. Format and outline documents in a local browser worker.
- Add Windows portable packaging with bundled DLLs, Node, native file/folder/save
  dialogs, UTF-8 paths and atomic replacement of session snapshots. Keep settings
  and recovery beside the executable in user/; use explicit tool entry points.
- Preserve engine changes as a verified patch against pinned upstream sources so
  fresh CI checkouts include the custom renderer and UI. Test the compiled
  browser in Chromium and the portable Windows package under Wine.

## JottaXL v0.5.26 — 2026-11-15

- Add an AppImage packaging command with checksum-verified build
  tools, offline caching, versioned output and a SHA-256 checksum file.
- Bundle native libraries, SDL compatibility runtimes, fonts, Node and built-in
  editor tools; support launching without FUSE through extraction mode.
- Reconfigure existing native build directories when rebuilding the application.

## JottaXL v0.5.25 — 2026-11-15

- Halve the document outline nesting indentation from 12 to 6 logical pixels
  per level, giving nested entry names more room.

## JottaXL v0.5.24 — 2026-11-14

- Add a Jotta Edit-style document outline in the resizable sidebar, accessible
  from the activity rail, View menu or Ctrl+Alt+O, including standalone buffers.
- Show headings, HTML elements/embedded CSS, stylesheet selectors, script symbols,
  PHP declarations and Python definitions, using the existing bundled parsers.
- Add filtering, clickable source navigation, keyboard controls, active-section
  highlighting, refresh and live unsaved updates with stale-result protection.
- Parse in a bounded background worker (2 MiB / 1,000 entries), stop the worker
  when hidden, retain the selected sidebar across restarts, and localize the UI
  in Portuguese (Portugal). Preserve reference sources, licenses and icon assets.

## JottaXL v0.5.23 — 2026-11-14

- Keep only the logo at the top left and move the application menus next to it,
  removing the space previously reserved for the JottaXL text label.

## JottaXL v0.5.22 — 2026-11-14

- Move the current workspace name from the top menu bar to a dedicated bottom
  status item, available without an active document; avoid repeating it in the
  file breadcrumb and shorten long names to fit.
- Move the sidebar dark/light button to a reserved bottom-right status slot.
  Keep it visible and clickable during status messages and in narrow windows,
  without opening the log or moving it with scrollable status indicators.

## JottaXL v0.5.21 — 2026-11-14

- Support arrow keys and Home/End on focused closed settings selectors, including
  editor/UI schemes, fonts, icon palettes, indentation and interface language.
- Change closed selector values with the hovered scroll wheel, accumulating
  touchpad fractions without stealing focus or scrolling the settings panel.
- Keep open dropdown list scrolling and pending Apply/Cancel behavior, and cache
  choice lists per settings window to keep font-wheel changes responsive.

## JottaXL v0.5.20 — 2026-11-14

- Reimport and verify the complete Jotta Edit v1.3.4 palette set: 21 editor
  schemes, 21 matching UI schemes and nine explorer icon palettes. Import exact
  Jotta Dark/Light UI defaults from the source CSS and retain the source catalogue.
- Add independent Editor color scheme and UI color scheme dropdowns in Themes,
  with Follow editor theme as the compatible default and persisted selections.
- Store Theme Editor overrides with the corresponding editor or UI scheme.
- Keep tabs, command inputs, font specimens, explorer selections and Markdown
  previews readable when combining different editor and UI schemes.

## JottaXL v0.5.19 — 2026-11-14

- Add English / Portuguese (Portugal) UI selection in Settings → General,
  applied live and persisted. Translate application menus, settings, dialogs,
  About, color controls, native dialog titles and common editing prompts while
  preserving filenames, document text and command identifiers.
- Preserve per-file indentation when changing unrelated settings. Only explicit
  indentation changes or section resets update open files, including reselecting
  a default that differs from the file's detected indentation.
- Improve content detection for comments, quoted markers, typed TypeScript and
  large JSON prefixes; reduce accidental CSS guesses in ordinary text.
- Write atomic recovery snapshots after two idle seconds, or every 15 seconds
  during continuous changes, without saving source files. Track changes across
  undo/redo revision reuse to retain the most recent buffer contents.
- Format documents independently, with clickable progress, cancellation via menu
  or Ctrl+Alt+Shift+X, a 30-second timeout and cleanup after process errors.

## JottaXL v0.5.18 — 2026-11-14

- Suppress language-server and status tooltips over inline color swatches and
  values, including pending hover replies. Keep swatches clickable and retain
  normal language hover information elsewhere in the editor.

## JottaXL v0.5.17 — 2026-11-14

- Apply tab/space and indentation-width preferences to open documents as well
  as defaults for new documents, without rewriting existing whitespace.
- Format untitled buffers and unsaved edits through bundled Prettier, using
  document indentation. Keep disk files unchanged, group formatting into one
  undo step, and retain newer edits made while the formatter runs.
- Detect common code languages from buffer contents when a filename provides
  no language; retain explicit language choices and known filename extensions.

## JottaXL v0.5.16 — 2026-11-14

- Redesign About with an app logo, prominent title and version badge, theme-aware
  surfaces, platform details, credits and a Copy Details action. Keep content
  scrollable on smaller windows with keyboard and mouse dismissal.

## JottaXL v0.5.15 — 2026-11-14

- Keep unavailable top-menu commands visible but dimmed, so Edit no longer
  appears empty outside an editor. Skip disabled items during menu navigation
  and prevent activation by mouse or keyboard.

## JottaXL v0.5.14 — 2026-11-14

- Enable dragging the explorer’s right divider while keeping the activity rail
  fixed, with live resizing, width limits and existing session width recovery.

## JottaXL v0.5.13 — 2026-11-14

- Animate settings switch thumbs and colors over 100ms, continuing smoothly
  from their current position when toggled again during a transition.

## JottaXL v0.5.12 — 2026-11-14

- Replace Preferences checkboxes with smooth pill switches, circular thumbs,
  distinct on/off positions and theme colors, and rounded keyboard focus rings.

## JottaXL v0.5.11 — 2026-11-14

- Use anchored dropdown menus for themes, fonts, interface mode, icon palettes
  and indentation choices in Preferences, with mouse selection, scrolling,
  draggable scrollbars, keyboard navigation and type-to-select.

## JottaXL v0.5.10 — 2026-11-14

- Render rounded UI surfaces with antialiased device-pixel coverage instead of
  stepped scanlines, including fractional positioning and HiDPI.
- Give Preferences tabs/buttons softer corners and rounded focus outlines;
  remove the square-ended focus underline from selected tabs.

## JottaXL v0.5.9 — 2026-11-14

- Add a Jotta Edit-style tabbed Preferences window (Ctrl+,), with draggable
  header, scrolling, keyboard navigation, Apply/Cancel and section defaults.
- Group editor/fonts, themes, custom theme colors, explorer, language tools,
  searchable shortcuts and session options in one persistent settings panel.
- Preview pending fonts/themes and use the custom color picker for theme colors.
- Keep open documents unchanged and fix wrapped-line color coordinate rendering.

## JottaXL v0.5.8 — 2026-11-14

- Increase the color picker’s preferred height from 748 to 840 pixels so its
  normal controls fit without scrolling on taller windows, while retaining the
  viewport limit and scrolling on smaller screens or longer color libraries.

## JottaXL v0.5.7 — 2026-11-14

- Add clickable inline color swatches before HEX, RGB/RGBA and HSL/HSLA values.
- Adapt Jotta Edit’s draggable, scrollable color editor with original/selected
  previews, HEX/RGBA/HSL/CMYK fields, sliders, presets, favorites and recents.
- Keep caret/selection coordinates and soft wrapping aligned without inserting
  source characters. Apply as a single undo step and reject stale source edits.

## JottaXL v0.5.6 — 2026-11-14

- Web Preview streams unsaved HTML, CSS, JavaScript and static text assets from
  editor buffers over a private pipe and pushes browser reload notifications.
- Preview untitled HTML without saving; clean or closed buffers fall back to disk.
- Keep source files untouched, preserve project boundaries and PHP restrictions,
  and continue detecting external saved-file changes.

## JottaXL v0.5.5 — 2026-11-14

- Restore open folders together with tabs after exiting the application.
- Remember explorer visibility, width, expanded directories, selection and scroll.
- Respect an explicitly opened folder at launch, skip missing saved folders and
  preserve standalone file locations when restoring a workspace.

## JottaXL v0.5.4 — 2026-11-14

- Image tabs for PNG, JPEG, GIF, BMP, WebP, SVG, ICO and TIFF, with fit/100%,
  zoom, pan, scrollbars and themed transparency checkerboards.
- Font specimen tabs with editable sample text, sizes, variable weights and
  actions to use the font for the UI or code editor. Font pickers include Preview.
- Route media from file dialogs, explorer, quick open and startup without reading
  binary files as text; restore media tabs and their settings across restarts.
- Keep editable SVG source accessible and preserve project-search navigation.

## JottaXL v0.5.3 — 2026-11-14

- Markdown preview follows active theme colors, surfaces, accents and dividers.
- Preview uses the selected UI/code fonts and sizes, including Rubik headings
  and true italic text by default.
- Refresh cached preview colors and typography after theme or font changes,
  including changes that leave the background unchanged.

## JottaXL v0.5.2 — 2026-11-14

- Font, color, language and Markdown heading pickers use mouse selection, Choose/Cancel buttons and a close
  button, with double-click to apply.
- Add draggable scrollbars and wheel scrolling independent of selection/search.
- Keep keyboard navigation and filtering available.

## JottaXL v0.5.1 — 2026-11-14

- Use the supplied full Rubik and JetBrains Mono variable fonts as defaults.
- Select actual Regular/Semibold variable weights; preserve weights when resizing.
- Preserve fractional font sizes and glyph positions in grayscale rendering.
- Fix first-use glyph fallback so cold and cached text measurements agree.
- Keep code text monospaced with code-font kerning disabled.

## JottaXL v0.5 — 2026-11-14

JottaXL continues LiteFront. This cumulative release retains the features and
settings developed in previous versions; the app's new release series starts at
v0.5. The underlying Lite XL engine keeps its own version number.

- Independent, persistent UI and code font sizes, with increase, decrease and
  reset controls. Rubik and JetBrains Mono remain the respective defaults.
- Menu bar above the entire workspace, unaffected by explorer show/hide or resize.
- Small top inset on the minimap, including its click and drag geometry.
- File explorer with supplied file-type icons, live updates, keyboard navigation,
  resizing and 100 ms show/hide transitions.
- Standalone HTML live preview and unsaved Markdown preview.
- Expanded Markdown toolbar, supplied icons and direct HTML/PDF export through
  the system Save dialog.
- Imported Jotta Edit workbench colors and nine explorer icon palettes, with
  persistent theme choices. OpenType kerning for UI text.
- Recovery of open saved/untitled documents and unsaved edits across restarts.
- Native file/folder/save dialogs, language selection, completion, formatting,
  syntax themes, split panes, project search and bundled language tools.

The native launcher is now `jottaxl`; `litefront` remains a compatibility alias.
Native settings retain their existing directory. The Flatpak now uses the
JottaXL application ID `dev.jottaxl.JottaXL`, installing separately from the old
LiteFront app. Its build files and staged sources use the new name.

- The app icon is generated from `icons/icon.svg` for desktop launchers, the
  compiled window icon and in-app logos. Future builds regenerate all variants.
