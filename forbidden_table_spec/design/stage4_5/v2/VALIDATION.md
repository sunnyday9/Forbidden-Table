# V2.1 review evidence · 2026-10-01

**Proposed design; approval pending.** These checks concern browser/Figma design artifacts. They do not constitute a real game playthrough, controller test, Godot regression gate, or Stage 4.5 PASS.

## Complete journey

36 browser fixtures and 36 native Figma screen roots cover the full inherited Run inventory. The seven full-size native core-screen exports and three native indexes were visually inspected, including the Character portraits, Battle tray/intent, Pattern choices, both maps, rewards, Shop, Workshop, tutorial, help/settings, Summary, recovery, and component states.

The [audit/flow map](../AUDIT_AND_FLOW.md) continues to document the Stage 4 captures and authoritative journey. V2 uses the same mechanical fixtures; it revises visual surfaces, title treatment, placement, and cosmetic artwork.

## Browser layout

[layout_checks.json](source/layout_checks.json) records all 36 screens at 960×540:

- No detected button text overflow or horizontal panel overflow.
- Commit rails end at y=512, inside the baseline viewport.
- Map detail panels scroll independently, as intended.
- 125% and 150% pseudo-localized recovery sheets retain their action rail at y=524, with no button text overflow.
- 1280×720, 1280×800, and 1920×1080 captures show the centered composition; these are design targets.
- A real Tab step produces a visible solid 3 px focus ring.
- Three preview text font faces report loaded after visiting the screen set. The old Noto Tile glyph subset is unused because Chinese faces are image assets.

This is geometry/fixture evidence, not full text-scale support for every game screen. Contrast is controlled through dark material surfaces and scrims; textured compositing still needs production capture review after implementation.

## Browser motion

[motion_checks.json](source/motion_checks.json) exercises four studies in Normal/Fast/Instant, twelve cases total. Every case retains the identical ordered text: **Complete Hand settled. → Boss enters phase 2. → Victory!**

Reduced motion eliminates timed animation and ambient glow. Escape stops active motion. Switching from an active Settlement study to Character selection removes the stamp and prevents delayed callbacks from writing into the new screen. Instant also disables hover/press displacement and CSS transitions.

[interaction_checks.json](source/interaction_checks.json) records the targeted Instant hover/transition inspection and the reset caption after interrupted Settlement playback. [package_checks.json](source/package_checks.json) records artifact hashes, local-link checks, and solid-color semantic contrast samples (all sampled text/control pairs exceed 4.5:1). These samples do not substitute for a complete contrast audit over production textured composites.

The browser draw start/mid/settled phase captures are in [motion/](motion/). They show cosmetic playback over fixed illustrative state. They are not screenshots of a Domain Draw operation.

## Native Figma

V2.1 replaces the old Latin rank/suit face labels with 34 unmodified, pinned Chinese tile assets. The [source/identity/hash manifest](assets/chinese-tiles/manifest.json) covers the existing 34 Domain TileDefinition IDs. The [license and attribution](assets/chinese-tiles/README.md) are saved with the files. Flowers and alternate tile types are excluded.

[chinese_face_checks.json](source/chinese_face_checks.json) verifies 219 native Tile instances across the 36 main screens, motion study, and three indexes: every face has the correct image hash and contain scaling, and the legacy text-face layers are hidden. Focus/selection layers, instance identity, and screen roots are preserved. The separate full-34 catalog has no caption overflow.

All 36 browser captures, contact sheets, enlarged-text/window specimens, tile-bearing native core exports, three native indexes, browser motion phase captures, and native MP4/phase captures were refreshed. The Character/map/Summary native exports remain valid because their frames contain no tiles and were not changed. The browser and native tile catalogs were visually inspected at 960×540.

[figma_checks.json](source/figma_checks.json) records all 36 roots at 960×540, commit rails at y=512, minimum button height 44 px, and no detected header/button overflow. The supplied Education copy contains scoped V2 variables and reuses its native Button/Tile component families. [figma_ledger.json](source/figma_ledger.json) links every fixture to the actual Figma node.

The separate native tile-arrival study uses three transform tracks on a wrapper around the last tile: X +90→0, Y −96→0, rotation −8°→0 over 0.6 s, with a 2 s timeline. The final face remains visible. The native preview and browser study demonstrate the same intent; their easing/fade details are separately authored.

[figma-tile-arrival.mp4](motion/figma-tile-arrival.mp4) was exported at 960×540 and 10 fps; the encoded container reports 2.1 s. [native_motion_checks.json](source/native_motion_checks.json) records actual playback samples around start, 0.2 s, 0.65 s, and 1.25 s. The sampled native PNGs were visually inspected: entry at the Draw-side edge, mid-flight tile, settled White tile, and readable hold. Verification uses actual playback because the local SimpleHTTPServer does not reliably support seeking this MP4.

## Scope and unresolved approval

Original generated artwork, native editable frames, browser fixtures, motion source, capture scripts, and evidence are saved together. No signed download URLs or service credentials are retained. The prior V1 package remains available for comparison.

No game UI code or authoritative state was edited. No new gameplay, content budget, release-stage name, tracker completion, push, or mockup approval is included. Production asset approval, Godot rendering, input/controller behavior, localization, supported scaling, and runtime motion/performance remain implementation-stage checks after explicit V2 approval.
