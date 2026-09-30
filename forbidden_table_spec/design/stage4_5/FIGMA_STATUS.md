# Figma review mirror — 2026-10-01

[Editable Education copy](https://www.figma.com/design/xXzt7gEelGQh37Ak51ogGa) — **Proposed v1; maintainer approval pending.** The user supplied this copied file and authorized direct edits. Its three pages and all 36 destination frame IDs were inspected before writing. The copy preserved node IDs but changed text-style IDs; the ledger now contains the copy's actual references. The original draft is retained separately and was not edited during this sync.

All 36 screen/state frames now mirror the refined fixture content. Existing root IDs and frame links were preserved while replacing their own drawing contents. The shared library contains 7 ActionButton variants, 16 TileFace variants, 34 scoped variables in 3 collections, 8 Noto text styles, and a visual-direction board. Three additional editable review indexes show the complete journey in groups of 12.

The refinement includes full-width, wrapping button labels with a 44 px minimum height; contrast-corrected edges; explicit selected cards; brass commit actions; one focus target on ordinary surfaces; a marked exact Workshop duplicate; matching choice-card tile identities; 13-tile incomplete Battle examples; a separate consumed-group receipt; and Summary stat cards. Focus uses native cyan perimeter geometry outside the brass selected edge. Zero-blur shadow exports did not reliably show focus, so the native geometry supplies it directly. Bamboo faces use two plain stems with redundant rank and BAM labels in both viewers.

## Verified artifacts

- Native structural measurements for all 36 frames: 960×540, footer bottom y=512, every button at least 44 px high, and no measured button-label overflow. See [figma_checks.json](source/figma_checks.json).
- Six full-size native exports visually inspected: [Character](mockups/figma/character.png), [Act 1 map](mockups/figma/map-act-1.png), [Battle](mockups/figma/battle.png), [Pattern](mockups/figma/pattern.png), [Workshop target](mockups/figma/workshop.png), and [Run Summary](mockups/figma/summary-victory.png).
- Three native indexes visually inspected: [01–12](mockups/figma/index-01-12.png), [13–24](mockups/figma/index-13-24.png), [25–36](mockups/figma/index-25-36.png). The second index was exported in isolation to exclude floating sibling content from the preview.
- The separate browser gallery contains 36 full-size drawings, 125%/150% text specimens and three larger-window composition specimens. These are browser renders, not Figma exports or Godot captures.

The Figma mirror is editable design artwork. It does not execute game commands, demonstrate controller routing, implement animations, or certify every viewport/text-scale combination. Long contextual scrolling and modal behavior remain documented implementation requirements; static Figma frames show their composition.

## Account usage

The reconnected account reported `tier=student`, and read/edit/export calls succeeded against the supplied copy. The service provides no exact used/remaining-call counter. The [published Education allowance](https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/) is up to 200 calls/day and 10/minute; this is a published allowance, not a measured remaining quota. No plan, account role or purchase was changed.

No game UI implementation or mockup approval is claimed. #98 remains open. Stage 5 remains **1.0 Release Candidate**.
