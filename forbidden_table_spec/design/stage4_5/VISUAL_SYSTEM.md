# Visual system — proposed v1

## Direction and hierarchy

Supernatural tabletop: deep felt, ink dividers, ivory tile faces, brass selection edges. Quiet table geometry and a small seal motif can frame empty space; never texture text or tile faces. No portraits, new lore, audio assets, gameplay meter, or asset dependency is required for v1. Titles establish atmosphere through serif type; rules and controls remain plain sans serif.

Priority stays **readability > state clarity > tile recognition > animation feedback > decoration**. Within Battle: current enemy intent and critical resources → Hand and legal choices → Reserve/zone context → Techniques/Yaku/build detail → decoration. On a choice screen: name/availability → cost and consequence → selected detail → commit/back. Run-level metadata never competes with a Battle decision.

## Primitive → semantic → component tokens

| Primitive | Value | Semantic role | Component use |
| --- | --- | --- | --- |
| felt/950 | `#101D1B` | background/table | Screen shell |
| ink/900 | `#172825` | surface/panel | Panel, map canvas |
| ink/800 | `#223833` | surface/raised | Choice row, hover fill |
| ivory/100 | `#F3EBD8` | text/primary; tile/face | Labels, tile body |
| sage/200 | `#BECBC3` | text/secondary | Help, noncritical metadata |
| brass/300 | `#D8B875` | action/primary; selection | Commit button, selected edge |
| focus/200 | `#A0E7EF` | focus/ring | Focus perimeter, separate from selection |
| coral/200 | `#FFB5A4` | status/error | Error and negative consequence with text/icon |
| jade/200 | `#A9DBC1` | status/success | Accepted receipt plus label |
| edge/500 | `#6B877B` | border/control | Interactive boundaries |
| face-ink/950 | `#17221E` | text/on-tile; text/on-primary | Tile identity, brass-button label |

Figma has hidden primitive variables, semantic aliases with explicit scopes, and component aliases for Button/Tile/Panel. Repository `source/tokens.json` records the same values. Assign aliases at component boundaries; do not scatter hex literals through future Godot controls. Disabled controls use a solid raised surface and readable secondary text, plus “Unavailable” or a specific reason, rather than reducing the entire control's opacity.

Text pairs target at least 4.5:1; large text and critical control/focus boundaries target at least 3:1. These are internal design targets. `VALIDATION.md` records measured pairs, not external conformance. Do not put brass text on ivory or white text on a brass primary button. Suit colors may reinforce identity, but glyph/shape/rank/label must do the work.

## Typography

Proposed fonts: **Noto Sans Regular/SemiBold** for all gameplay text and controls; **Noto Serif Regular** for screen/outcome titles only. The current game has no bundled custom font; font-resource licensing, glyph coverage and fallback selection must be verified during approved implementation. Figma uses these exact available families, not the generic library's Inter font. CJK suit glyphs require an appropriate Noto Sans SC fallback; the mockup has readable suit abbreviations even when glyph art is unavailable.

| Role | Native 960×540 size / line | Rule |
| --- | --- | --- |
| Screen title | 26 / 34 | Serif, one or two lines if necessary |
| Outcome title | 32 / 40 | Serif; no animation required to read it |
| Section / card title | 18 / 24 | Sans SemiBold |
| Body / control | 16 / 22–24 | Sans; consequence copy wraps |
| Secondary metadata | 14 / 20 | Never the only representation of a critical rule |
| Tile rank | 24 / 28 | High contrast, fixed identity location |
| Tile suit code | 12 / 16 | Redundant with glyph; full name available in inspector |

Use tabular figures for counters and prices where supported. Do not condense text to make a choice fit. Essential button text wraps and increases height. Keep body lines near 40–65 characters; details scroll vertically without truncation. Ellipsis is permissible only for noncritical inventory names with full text available on focus and click.

## Spacing and layout

Primitive spacing: 4, 8, 12, 16, 24, 32. Native safe margin 16; panel padding 12–16; related controls gap 8; separate groups gap 16; button target minimum 44×44. Tile faces paint at 42×64; the future control should extend its hit area to 44 px within the available inter-tile gap without overlapping adjacent targets. Panel radius 8, button 6, tile 4. Active controls use an explicit 1 px edge; focus is a 3 px outer perimeter with 2 px clearance and enough surrounding room to show it fully.

At 960×540: one shell, roughly 48 px header, 32 px status, 348 px decision area and 44 px action footer. Text-heavy surfaces scroll within the decision area; the footer remains outside it. Selection screens use choice-list + inspector or three cards. Battle uses a wide tile area and a narrower action/detail area. Shop uses a 2×3 offer layout or scroll list. Summary uses compact headline stats and separate scrollable build-story groups.

At larger windows use the same content hierarchy, wider gutters and a capped readable body width; never stretch a tile to an unreadable proportion. At text expansion/125%/150% diagnostic scales, reflow comparison rows and tile trays; move secondary details to an explicit drawer with a focusable Close action. Do not scale the entire 960 image down to fit. Use row/page labels if a tile tray requires multiple rows; keep all instances reachable and show selected tiles and exact consumption in the inspector.

## Tile and Pattern language

Ivory upright faces with dark ink. Suits get different geometry: Bamboo stems, Dots pips, Characters rank plus character mark. Retain rank, redundant suit code and full localized identity in the inspector. Honors display explicit direction/dragon names in detail and a distinct face mark. No suit may be identified by hue alone. Pattern highlights outline exact instances; never replace or obscure base identity.

Tile component axes: base identity; zone; focused; selected; Pattern membership; Modifier mark; contamination status; disabled/locked reason. Apply marks as separate corner/edge layers. Focus and selection can coexist. Display current Modifier/contamination names and context in the inspector. Flexible identities are context-dependent; list base identity and current legal interpretation separately. Duplicate TileInstances have stable presentation labels (e.g. “Bamboo 2 · copy 2”) mapped to instance IDs, never use internal IDs as the primary label.

Sequence/Triplet/Quad groups use a bracket, explicit Pattern name and the exact consumed faces. Pair is structural and not independently settleable. Complete Hand shows the legal interpretation (4 Groups + Pair or Seven Pairs), Yaku and relevant current restrictions; Quads may increase physical tile count, so the layout must wrap without a 14-tile rule assumption. Hand progress is formal; Reserve progress is potential unless existing Rule Breakers say otherwise. Do not merge these labels.

No new optimal-strategy solver or Domain preview system is included. Show known current candidate metadata and authored consequences. Exact score/combat output may be displayed only when the existing resolver/preview seam actually supplies it; otherwise label it “Shown after resolution.” Do not infer damage, expose hidden order or promise deterministic random outcomes.

## Reusable components and future Godot seams

| Design component | Content/state contract | Existing seam for later implementation |
| --- | --- | --- |
| RunShell / StatusStrip | Phase, Act, Character/Contract, Gold/Refinement; optional detailed build | `RunScene._build_interface/_render` and authoritative snapshot |
| IntentPanel / ResourceChip | Known intent text, HP, Pressure, TP, Stability, Integrity when relevant | `_battle_summary`, current Battle snapshot |
| ActionButton | Label, role, enabled reason, focus, pressed; one commit per surface | Existing descriptors + `_on_action_pressed` / controller.confirm |
| ChoiceRow / ChoiceCard | Stable descriptor ID, named item, availability and details | controller.action_descriptors/details |
| TileFace / TileTray | Definition and instance IDs, known zone, state marks | `_hand_summary`, current zones, content registry |
| PatternCard / InterpretationPanel | Candidate/interpretation ID and instance membership | `_battle_actions`, Partial/Complete Hand descriptors |
| ContextInspector | Wrapped localized rule/consequence text, scroll/close | `SelectedActionDetails`, details payload |
| MapNode / MapEdge | Topology + player-visible payload + reachable action | `RunMapState` and map descriptors |
| OfferCard / WorkshopReview | Price and owned resources, exact target/result | Shop/Workshop descriptors and validations |
| TutorialCallout / HelpSheet / SettingsSheet | Existing tutorial/mode state; no Domain phase | TutorialProgress, controller.set_mode |
| ResultHeader / BuildStory | Result and real tracked/missing data | RunSummaryPresenter |
| ConfirmDialog / FeedbackReceipt | Existing command intent; rejected/accepted result | controller.submit, RunScene startup/recovery |

Later theme plan: a root Godot `Theme` resource; `StyleBoxFlat` states for Panel/Button/focus, `FontFile`/fallback resources, named font-size and spacing constants, reusable presentation controls bound to the existing descriptor IDs. Existing scene-local font overrides should converge onto the shared Theme. Both production RunScene and standalone BattleScene use shared primitives. **No `.gd`, `.tscn`, `.tres`, project setting or localization catalog is edited in this design session.**

## Feedback and motion

| Feedback | Normal | Fast | Instant |
| --- | --- | --- | --- |
| Focus/press/selection | Immediate state mark; optional 80–120 ms tint | Immediate mark; ≤60 ms tint | Immediate static mark |
| Draw/zone movement | Optional 160–220 ms travel, face readable immediately | ≤80 ms travel | Static updated zones + text receipt |
| Partial Settlement | ≤240 ms group emphasis + resolved result | ≤100 ms emphasis | Static consumed-group/result receipt |
| Complete Hand / Boss phase / victory | Ordered persistent cues, optional ≤300 ms emphasis | Same ordered cues, ≤100 ms emphasis | Same cues, no travel/fade |
| Screen/overlay change | ≤160 ms opacity only | ≤60 ms opacity | Immediate |

All durations are proposed, not measured. Input/authoritative state resolve first. Visual effects are interruptible and decorative; an old animation must never overwrite a newer snapshot. If multiple critical events occur, keep “Complete Hand settled → Boss phase → Victory” in Domain event order. Keep the receipt readable until the next explicit action or a dismissible receipt view; no timer-only message. No flashing, camera shake, forced pause or required audio. Modal confirmations are user decisions, not animation locks.
