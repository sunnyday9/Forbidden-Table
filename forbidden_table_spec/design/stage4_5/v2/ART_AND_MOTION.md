# V2 art, component, and motion rules

## Visual direction

Design the space as a haunted Mahjong salon. Rain and cool window light establish depth; crimson lanterns and restrained brass give the table warmth. The room recedes behind the decision surfaces. Avoid moving wallpaper behind body copy, ornate type for mechanics, screen shake, and decorative effects competing with enemy intent.

The generated salon and portrait triptych are new cosmetic concepts. They add no characters, lore, unlock conditions, rewards, or gameplay systems. Both Act maps use the same proposed room backdrop; node topology and encounter knowledge remain unchanged. Art should eventually be reviewed separately for final Character appearance and game-specific asset preparation.

## Materials and hierarchy

| Surface | Purpose | Treatment |
| --- | --- | --- |
| Room | Atmosphere and spatial context | Painted background, dark top/bottom vignette; static by default except optional light glow |
| Lacquer | Choices and contextual details | Deep jade, warm 1 px outline, modest inner light, corner carving |
| Table | Hand and visible zones | Translucent jade felt under well-contained content |
| Enemy banner | Enemy identity and intent | Dark vermilion accent; HP and resolution timing remain ordinary text |
| Paper | Contracts, Events, help, recovery | Dark warm paper with very subtle grain; no texture-dependent information |
| Shop / Workshop | Compare offers / inspect a change | Wood or jade material; price and before/after remain explicit |
| Chronicle | End-state Build Story | Warm brass framing; recorded results distinguish missing older fields |
| Reward | Compare existing offers | Large tile face or decorative seal with a visible type label |

All functional text sits on a controlled dark surface or protective scrim. Use the corner carving only at the panel edge. Never let it overlap a glyph or a focus ring. Tile and button shadows describe depth, without implying a new mechanical tier or rarity.

## Typography and layout

Retain Noto Sans for mechanics and Noto Serif for short screen titles/Character names. The preview uses the licensed local fonts in the parent package. Title 32/40, Character name 24/30, body 16/24, compact secondary copy 14/20. Keep suit/rank labels in plain type. Font sizes below body scale are for secondary labels only.

The 960×540 composition uses 16 px outside space, 8 px component gaps, a 60 px title rail, a 20 px Run rail, then a purpose-specific decision surface. The main commit rail stays at y=468..512. Panels are arranged around the actual decision: portraits, map plus inspector, Hand plus choices, offers plus comparison, or before/after plus confirmation.

Body panels may scroll independently. Keep critical Battle resources, intent, the visible Hand, Back/Cancel, and the main action outside secondary scrolling. Never hide duplicate TileInstances behind a single tile face.

Hand faces are 42×64 in the baseline fixture; reward faces are 63×96. At implementation, extend each small face's hit region to at least 44 px wide inside the existing gap, without overlapping adjacent targets. The rank, suit glyph, and suit abbreviation remain separate. Pattern grouping and selected instances stay explicit. A Pair remains visible in Complete Hand grouping and is not presented as an independently settleable Pattern.

At larger windows, center the baseline table composition with additional surrounding space. At increased text scales, let detail sheets wrap and scroll while the action rail remains reachable. The existing 125%/150% specimens are enlarged-text recovery sheets, not a complete responsive redesign of every screen. Preserve pseudo-localized placeholders and the full longest recovery message.

## Color and reusable components

Primitive, semantic, and component tokens are scoped to V2 in Figma, so V1 remains reviewable. There are 33 color variables across three collections. [tokens.json](source/tokens.json) contains the review palette.

| Semantic token | Color | Usage |
| --- | --- | --- |
| Text / secondary | #FFF1D5 / #D3D4B9 | Functional copy on controlled dark surfaces |
| Lacquer / raised | #112820 / #243B30 | Panels and selectable controls |
| Brass | #E7B65A | Selection, commit fill, restrained decoration |
| Focus | #97EEDF | Independent 3 px navigation perimeter |
| Error / success | #FFB09B / #ADE1BC | Accompany explicit result/reason text |
| Table / paper | #0E1916 / #292218 | Dark space and warm document surfaces |

Reuse the existing seven-state Button and sixteen-variant Tile families in the supplied Figma copy. V2 instances apply the scoped palette and material treatment. This is a review library, not a new production Godot Theme.

Buttons use a minimum 44 px height, ordinary localized labels, and generous space around the hit region. Brass fills identify the main commit; green controls inspect or choose. Disabled controls retain readable text, a dashed edge, and a nearby reason. Focus does not imply selection; selected + focused displays both.

Tiles retain rank/suit/Honor identity, instance details, and existing marks. A cyan ring shows navigation; brass marks selection. Inspection is available through click, accept, and an explicit control. Do not require hover or dragging. Decorative reward seals convey atmosphere only; visible names and descriptions convey mechanics.

Reuse a Screen shell, Title rail, Run rail, Commit rail, Material panel, Character card, Intent banner, Resource row, Hand tray, Zone well, Pattern group, Map node, Offer card, Detail sheet, Before/after tile pair, Confirmation sheet, Ordered receipt, and Summary section. Supply explicit empty/error/disabled contents rather than hiding these components.

The full [input and state guidance](../INTERACTION_AND_VALIDATION.md) remains applicable: preserve mouse, keyboard and controller paths; restore origin focus after closing detail/confirmation; cancel back through Workshop steps without committing; disable unsafe actions based on authoritative state; preserve the difference between a rejected command and an accepted command whose save failed.

## Motion choreography

Effects emphasize an already-accepted result. They never call Domain commands, delay the authoritative transition, alter a score, or infer a damage preview. Readable persistent receipts exist before cosmetic playback. Fast and Instant preserve the same ordered result.

| Study | Normal | Fast | Instant / Reduced |
| --- | --- | --- | --- |
| Tile arrival | 600 ms ease out, move from the Draw side into its final rack slot | 240 ms | Static final face |
| Settlement | 360 ms group lift; 210 ms stamp entry; three ordered emphasis beats at 390 ms intervals | Proportionally shortened | Full ordered receipt immediately |
| Reward reveal | 420 ms card rise, 90 ms stagger | 168 ms rise, 36 ms stagger | All offers immediately visible |
| Workshop | 600 ms before/after lift and fade | 240 ms | Both faces and the result text immediately visible |
| Hover / press | 140 / 120 ms, 4 px tile lift / 1 px press | Same small response target | No displacement or transition |
| Lantern glow | Optional 5 s gentle light breathing | Same ambient option | Off |

Use at most one or two major moving elements for information emphasis. The three reward cards form one short reveal sequence. Avoid looping tile motion, camera movement, rapid flashing, mandatory pans, and bounce on every action.

Stop, Escape, changing screens, changing presentation speed, or selecting Reduced motion cancels playback and restores the static composition. Late callbacks must not write to another screen. Motion does not capture or remove keyboard/controller focus. Implementation must preserve focus while consuming the ordered Domain result once.

The interactive browser demo uses Web Animations plus cancellable presentation timers. It is a design demonstration with fixed illustrative values. Native Figma keyframes provide a separate authoring study; its export verification status is recorded in [VALIDATION.md](VALIDATION.md). No renderer should be mistaken for a tested Godot implementation.

UI/UX Max Pro informed the style, contrast, focus, material, and reduced-motion decisions. Its generic web/dashboard conventions were adapted to the game's existing viewport, Domain phases, and explicit Instant mode.
