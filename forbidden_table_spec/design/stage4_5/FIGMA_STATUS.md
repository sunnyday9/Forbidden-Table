# Figma mirror status — 2026-10-01

[Original Figma working draft](https://www.figma.com/design/b9jqsE96RdbRCwHvUB9zsd) — created via Figma MCP on 2026-09-30. **It is not yet the corrected review mirror.**

Created native, editable layers: 36 screen frames, 7 ActionButton variants, 16 TileFace variants, 34 scoped variables in 3 collections, 8 shared Noto text styles, and a visual-direction board. Three pages hold components, the full Run journey, and interaction/end/stress states. `source/figma_ledger.json` records actual returned IDs.

The initial exports revealed main rows occupying near-zero height and narrow button text. The Starter quota initially blocked correction. After the user reconnected an Education account, `whoami` reported `tier=student`; read and edit calls succeeded. Main-row height corrections were applied to both screen pages. A subsequent export and property read showed that explicit label width edits had not survived: many labels remained 50 px wide. The prepared correction now uses **Fill width in auto-layout**, with a minimum-height button that grows for wrapped text. This needs a new canvas export and inspection.

The user has copied the draft into the Education account and authorized edits to that copy. **Its exact URL is still required.** Do not infer a copied file's key from the original. Inspect the copy's node, style and variable IDs before updating the ledger or writing to it. The service provides no exact remaining-call counter; the [published Education allowance](https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/) is up to 200/day, 10/minute.

The local review contains further refinements: contrast-corrected edges, matching tile identities on choice cards, explicit selected cards, consistent brass commit actions, one focus target on ordinary surfaces, duplicate-instance target marking, 13-tile incomplete Battle examples, a separate consumed-group receipt, summary stat cards, and corrected enlarged-text footers. These are saved locally; they are **not claimed synced to Figma**.

Review the corrected [repository gallery](gallery.html) and [PNG overview](mockups/overview.png). All 36 final baseline PNGs are browser renders of design fixtures, not Figma exports or Godot evidence. The initial broken exports were replaced in the review package. `source/figma_screens.js` and `source/figma_layout_fix.js` preserve the proposed native authoring constraints for the next sync.

Once the copied-file URL arrives: inspect that file, reuse its editable foundations, apply the corrections and fixture refinements, visually verify core frames, then update this status and the ledger. Game UI implementation still requires explicit maintainer approval of the mockups. #98 remains open and no Stage 4.5 PASS is claimed.
