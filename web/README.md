# Jotta Text Web

The browser edition compiles this project's patched Lite XL engine to WebAssembly.
It runs the shared Lua interface, editor, themes, settings, Portuguese translation,
font controls, resizable explorer, document outline and native Markdown preview.
The browser shell adds file imports, downloads and a sandboxed HTML live preview.
No editor service, remote language server or CDN is needed at runtime.

## Build and run

Install Python 3.11+, Git, Node/npm, Meson, Ninja, Pillow and `rsvg-convert`, then
activate **Emscripten 4.0.23**. For a workspace-local SDK on Linux:

```bash
git clone --depth 1 --branch 4.0.23 https://github.com/emscripten-core/emsdk.git vendor/emsdk
vendor/emsdk/emsdk install 4.0.23
vendor/emsdk/emsdk activate 4.0.23
source vendor/emsdk/emsdk_env.sh
bash scripts/build-web.sh
python3 -m http.server 8080 --directory dist/web
```

Open `http://localhost:8080`. The complete static site is in `dist/web`; its
versioned distribution is `dist/JottaText-0.5.33-web.zip` with a SHA-256 checksum.
Serve the entire extracted ZIP over HTTP/HTTPS, including `.wasm`, `.data`, fonts
and local worker libraries. Opening `index.html` through `file://` does not work.
Relative asset URLs support deployment under a subdirectory.

The first build downloads pinned source dependencies and Emscripten's verified
SDL2/FreeType/HarfBuzz ports. After those caches are populated,
`bash scripts/build-web.sh --offline` disables dependency downloads and freezes
the Emscripten cache. Lua/assets are repackaged on every build, even when C source
has not changed. Build scripts do not install host packages or publish a website.

## Files, recovery and previews

- **Open file** imports one or more files. **Import folder** keeps relative paths.
  Imports create browser workspace copies; original device files remain unchanged.
  Existing workspace files are not silently overwritten.
- Settings, imported folders, tab state and unsaved document text are stored in
  IndexedDB for the current site origin. Recovery snapshots sync periodically;
  wait for **Workspace saved in this browser** before closing the tab. Private
  browsing, storage restrictions or clearing site data can remove that state.
  Download important files; browser recovery is not a backup.
- **Download file**, Save and Save As write/download a copy of the current buffer.
  The browser controls the final destination and whether to show a system save
  dialog. Folders are restored from browser copies rather than retaining access
  to the original device directory.
- HTML live preview follows unsaved HTML and the open CSS/JavaScript buffers.
  Local linked stylesheets, classic scripts and images are embedded from the
  workspace. Preview scripts run in an iframe without same-origin access to the
  editor's recovery data. Module/import-map applications and projects needing a
  backend should use the desktop preview instead.
- Markdown preview uses the same Lua renderer and theme as the desktop editor.
  HTML export downloads a file. PDF export uses the browser's Print / Save as PDF
  dialog; it does not run the desktop Node PDF renderer.

Formatting uses locally bundled Prettier parsers in a background worker, including
PHP with explicit PHP 8.4 formatting rules. Outlines support Markdown, HTML,
CSS/SCSS/LESS, JavaScript/TypeScript/JSX/TSX, PHP and Python. Both jobs are bounded
to 2 MiB; outlines show at most 1,000 entries. Python outlines use a lexical mask
and indentation rather than executing Python. Stale edits cannot be overwritten
by a late formatter result.

The browser edition currently has no desktop LSP servers, Node subprocesses,
PHP execution, system font enumeration, Git integration or automatic writes to
device directories. The Language Servers settings tab is hidden. PNG/JPEG/GIF/BMP
images and bundled TTF/OTF fonts work through the WASM renderer; desktop-only
SVG/WebP/TIFF decoders are not compiled into this edition. Desktop and browser
storage are independent. Desktop feature parity is not complete.

## Verification

```bash
node --test tests/test-web.mjs
npm install --prefix dist/browser-test --no-save --ignore-scripts --no-audit --no-fund playwright@1.56.1
dist/browser-test/node_modules/.bin/playwright install chromium
node tests/test-web-browser.mjs
```

The Chromium check runs the compiled editor, imports source, formats an unsaved
buffer, reloads its IndexedDB state, types immediately after shortcuts, checks
live HTML preview, Save As downloads and dialog keyboard isolation, and opens
shared settings. Tests use temporary browser storage.
`python3 tests/test-browser-profile.py` also checks the browser Lua profile using
the native SDL dummy display.

The earlier integration notes pointed to [Lite XL Playground](https://github.com/lite-xl/playground).
This build compiles the current patched engine and shared application profile
directly. Storage uses the [Emscripten filesystem API](https://emscripten.org/docs/api_reference/Filesystem-API.html).
