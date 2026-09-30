# Design authoring sources

These files are review artifacts. None are imported by Godot or execute game commands.

- `build_mockup_data.py`: generates the 36 illustrative screen trees, manifest, token palette and embedded viewer data. Rerun with `python3 source/build_mockup_data.py` after fixture edits. Fixture values are not balance changes or real-play evidence.
- `review.js` / `review.css`: browser drawings and limited local selection; no gameplay, save, unlock, score evaluator or command simulation. `gallery.html` works directly as a file, or through a local HTTP server. Scroll details to see complete long text.
- `capture_mockups.py`: captures and measures drawings through a Playwright CLI session already opened on the gallery. Usage: `python3 source/capture_mockups.py /path/to/playwright_cli.sh ft-design`. Requires Node/npx, Playwright Chromium and the CLI; the skill wrapper may need CRLF normalization on WSL. Install dependencies outside this repository. Automation captures go directly to the requested design-package paths.
- `make_contact_sheets.py`: composes capture indexes; requires Pillow. Run with an available Python runtime containing Pillow.
- `figma_foundations.js`: self-contained native Figma token/component construction from an empty draft. Substitute `__PALETTE__` with `tokens.json`. Load the Figma use/library skills before executing through MCP. Existing foundations must be inspected and reused; do not rerun this script over them.
- `figma_screens.js`: editable screen construction. Substitute `__LEDGER__`, a subset for `__SCREENS__`, and one `__PAGE__` ID. Keep calls within the MCP code-size limit. Inspect the destination before writing; the script refuses duplicate screen names. IDs/styles/variables must belong to that file.
- `figma_layout_fix.js`: targeted existing-frame corrections, one destination page per call. Use the destination's inspected ledger. Button text uses Fill width in its auto-layout instance; explicit width edits alone did not survive the first authoring export. Screenshot and inspect after writing.
- `figma_ledger.json`: actual IDs returned for the original Figma draft. A duplicate file must be inspected before its IDs or style references are substituted. The original draft is not automatically the user's Education copy.
- `fonts/`: licensed design-preview fonts; see its README and OFL license. They are not runtime assets or a complete localization fallback.

To review through HTTP, from the working repository root run:

```sh
python3 -m http.server 8845 --bind 127.0.0.1
```

Then open `http://127.0.0.1:8845/forbidden_table_spec/design/stage4_5/gallery.html`. Keyboard/controller hints inside drawings describe proposed game interaction; the viewer itself does not implement controller or modal behavior.
