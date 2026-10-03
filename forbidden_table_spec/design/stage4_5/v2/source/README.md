# V2 design source and verification

This directory authors design fixtures and the browser/Figma review. It does not load or modify the game runtime.

- build_v2.py copies the V1 semantic fixtures and applies proposed artwork/layout treatments; regenerates screens.json, tokens.json, screen_manifest.json and review_data.js.
- review.js / review.css render the review and four cancellable motion studies. The parent package supplies local preview fonts and baseline CSS.
- figma_v2_screens.js is the native screen-authoring template. Supply __LEDGER__, __SCREENS__, __PAGE__, __PALETTE__, and __UPDATE__ through the Figma MCP authoring workflow. Existing roots can be preserved during a revision; do not run a creation batch blindly against populated frames.
- figma_motion.js records the repair/authoring operation for the existing motion-study node IDs. It is provenance, not an idempotent sync command; replaying it would add a wrapper again.
- art_prompts.json records both final generated artwork prompts. Artwork originals are in ../assets/.
- fetch_chinese_tiles.py saves 34 unmodified, commit-pinned Chinese tile PNGs plus their license and identity/hash manifest. Flowers and alternate tile types are excluded.
- figma_chinese_faces.js updates the existing V2 instances in place; supply __ROOTS__ and __IMAGES__ from the ledger. It preserves component/state identity and hides the legacy text-face layers. tile-atlas.html displays the same full 34-face registry.
- figma_ledger.json records the actual supplied copy, V2 page, 36 roots, indexes, scoped variables, uploaded artwork hashes, and motion study.
- capture_mockups.py verifies/captures the browser compositions. capture_motion.py checks four studies in three modes, reduced motion, Escape cancellation, screen interruption, and deterministic browser draw phases.
- make_contact_sheets.py composes existing screenshots into review indexes; it does not alter source artwork.

Reproduction requires a served worktree root, a configured Playwright CLI wrapper/session, and Python (Pillow for screenshot composition). The browser gallery itself needs no build step. Figma mutations must go through the Figma MCP skills and current-node/font checks.

Recorded layout and motion checks validate design fixtures only. Domain rules, saves, game input routing, Godot performance, and runtime localization require implementation-stage validation.
