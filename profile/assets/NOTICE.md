# Visual asset sources

Jotta Edit UI icons are adapted from https://github.com/joaojotta/jotta-edit
at commit 0434f663203e4385269d7abfa3aebd5687fc47cd. Their original SVG sources are included in jotta-icons/
and the upstream GPL-2.0-or-later license is in licenses/. The generated icon font
is an adaptation of those SVGs. Jotta Text retains its own name and logo.

The legacy subset Rubik fonts come from @fontsource/rubik 5.3.0
and are distributed under the included SIL Open Font License.
The default full Rubik and JetBrains Mono variable families are supplied by the
project in fonts/ and bundled under assets/fonts/supplied/, including their
upright and italic files.

Interface dimensions and the Jotta Dark/Light syntax palettes are adapted from
the same reference project's src/style.css and src/syntax-themes.js.
All 21 syntax palettes, all 21 corresponding UI schemes and nine explorer icon
color schemes are imported from that revision. The default Jotta UI schemes
copy the root variables from `src/style.css`; the other UI schemes use the
reference project's `deriveInterfaceColoursFromPalette` function. Editor and UI
schemes can be selected independently. An imported field catalogue is retained
in `reference/Jotta-Edit-theme-catalog.json`. Original JavaScript is preserved in
reference/. Regenerate the Lua data with `node tools/import-jotta-themes.mjs
/path/to/jotta-edit`. Icon legibility colors use upstream's contrast adjustment.

The original SVGs, palette data, this adaptation's Lua source, and the font
generation script are included in the source tree. Original upstream copyright
and third-party notices accompany the imported assets.

Markdown toolbar icons prefixed `md-` are derived from the user-supplied SVGs in
`icons/ui-icons/`. The asset generator copies the selected originals into
`jotta-icons/` before rebuilding the native icon font. Other UI icons retain
their existing sources.

Explorer icons prefixed `file-` are derived from the user-supplied SVGs in
`icons/file-icons/`. The asset generator includes these originals in the bundled
icon sources and converts their paths, nested transforms and presentation styles
into the native icon font.

The inline color decorations and native color editor adapt Jotta Edit's
`src/color-utils.js`, `src/color-picker.js`, `src/color-picker.css` and
`src/colour-library.js` at the same revision. Original files are retained in
reference/ and their GPL-2.0-or-later license is included under licenses/.

The Preferences window adapts Jotta Edit's `src/settings-tabs.js` and
`index.html` Preferences markup at the same revision. Their original sources
are retained in reference/ under the existing GPL-2.0-or-later attribution.

The native document outline adapts Jotta Edit's `src/document-outline.js` and
`src/document-outline-panel.js` at commit
0434f663203e4385269d7abfa3aebd5687fc47cd. Their source files are retained in
reference/ under the included GPL-2.0-or-later license. The outline and refresh
icons are copied from the same project's `public/ui-icons/` into jotta-icons/
and included in the generated native icon font. Jotta Text uses its already-bundled
Prettier Markdown parser, TypeScript parser, HTML/CSS language services and PHP
parser to analyze buffers without saving or executing their contents.
