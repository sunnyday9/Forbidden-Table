# Interaction rules and verification plan

**Proposed design, not implemented evidence.** Existing Stage 4 tests remain historical PASS evidence at their recorded snapshots. New mockup checks validate drawings and package completeness only.

## Input and focus

Mouse: hover may preview context, click selects/opens details, explicit commit submits. Hover is never required. Keep pointer position from forcing keyboard/controller focus to jump; a last-input modality change may update glyph hints without clearing the selected choice.

Keyboard: Tab/Shift-Tab changes focus groups and includes the detail scroll, help and footer; arrows move within a choice/tile grid; Enter/Space activates; Esc backs out one local level. Controller: D-pad moves within a group, shoulders switch groups, A selects/accepts and B backs/cancels. These preserve current supported mappings; no new dedicated shortcut or drag requirement. Inspector access has a visible Details control when automatic focus-following detail is insufficient. Disabled controls are skipped in the commit focus loop; their container remains inspectable so requirements are discoverable.

Focus is an outer cyan perimeter. Selection is brass plus an explicit Selected mark. Both coexist without implying confirmation. Focus movement never changes Domain state. Initial focus lands on the first legal non-destructive action; critical confirmation defaults to Cancel. After an overlay closes, restore its originating stable action/instance ID if still valid, otherwise the nearest legal action. If an action disappears, choose a stable neighbor and update the detail surface; never leave invisible or offscreen focus. Scroll to reveal the complete control and focus ring.

Mockups show state specimens. Static Figma screenshots cannot demonstrate real controller reachability, focus trapping, save persistence or command correctness; those remain implementation checks.

## Local steps, Back, and commit

| Surface | Selection/accept | Back/cancel |
| --- | --- | --- |
| Character / Contract | Inspect selected entry; explicit Choose uses existing command | Close detail / clear pending local choice. No reversal of an accepted Character/Contract command |
| Map | Focus/inspect only a reachable known node; commit Enter | Close detail; remain on current map; never move to prior node or reveal hidden payload |
| Battle tiles | Select exact instance; eligible Reserve/Discard action or explicit Hand + Reserve swap targets | Clear pending local tile operation; remain in Battle |
| Pattern / Complete Hand | Inspect exact candidate/interpretation, then settle using current command | Return to Battle choice without consumption or evaluator mutation |
| Event / reward | Inspect actual option and confirm; preserve existing skip/leave rules | Close detail; no invented reward skip or Event exit. An Event's authored Leave option is a real command |
| Shop | Inspect offer; local purchase confirmation then current Buy command; Refresh stays distinct | Cancel purchase; leave Shop through existing Exit command |
| Workshop | Service → exact target → legal result → local confirmation; existing services without value step go target → confirmation | Confirmation → value/target → service list → existing ExitWorkshop; no Domain undo |
| Help / Settings | Presentation-only overlay. Mode chooses Normal/Fast/Instant via existing API | Close and restore original focus |
| Tutorial | Existing step prompts; enabled, disabled, reset and complete states | Close help without advancing tutorial. Reset confirm if progress would be discarded; reset unavailable before progress |
| Act boundary | Receipt displays accepted transition | Dismiss receipt; current Act map remains authoritative |
| Summary / Complete | Finish Run acknowledges; New Run then starts fresh | Inspect/close detail only; no restart, revive or replay command added |
| Startup Resume / New Run | Existing compatible-save choice; confirm leaving saved Run | Confirmation returns to Resume; recovery failure enables only currently safe actions |

Presentation selection/confirmation is an interaction change requiring the approval sought here. It does not change legal actions, costs, rule resolution, accepted Run phases or persistence contracts. Double accepts must submit once, revalidate against the latest descriptor/snapshot, and use actual accepted/rejected results. Do not show optimistic currency, consumed tiles or unlocks before acceptance.

## Context detail coverage

Every known tile exposes full localized definition, exact instance label, zone, Modifier/contamination and interpretation context. Pattern detail exposes type and consumed instances. Yaku detail distinguishes Local/Hand and formal/potential progress. Technique detail shows owned source, timing and TP cost; unsupported timing says why. Contract shows current generated Risk/Reward/Build bias/Yaku signal. Relics/Rule Breakers/rewards/Shop show mechanical fields or typed effects that the current definition can safely describe; do not invent flavor text, forecast output or add a prose schema.

Map detail exposes player-visible payload only. Workshop shows exact before/after, service availability and price. Summary shows recorded values, “none recorded” for a recorded empty value, and “not tracked” for an absent historical field. Save errors distinguish rejection, preservation failure, and accepted-action/save-write-warning; an accepted command must not be described as rolled back because saving failed. Technical error code/path belongs in an expandable Details block, preserving the existing recovery instructions.

## Tutorial and help states

Five current tutorial steps remain: Draw/Pattern/Partial Settlement; TP/Core Technique; Reserve/Integrity; Yaku/Complete Hand; contamination/intent. Each callout sits beside its relevant choice or resource, not over tile identity. Tutorial enabled, disabled, reset-before-progress, reset-after-progress, reset confirmation and completed states reuse the same components. Off/complete states leave Help reachable. The gallery's tutorial/reset-disabled and settings examples demonstrate the visual rules; additional repeated step content must use the same layout and actual localized prompts.

## Viewport and text-scale matrix

| Viewport / text scale | Current evidence | Proposed review/implementation check |
| --- | --- | --- |
| 960×540 / 100% | Only supported/default baseline recorded by Stage 4 | All core mockups; all actions reachable, no obscured tiles/intent/footer |
| 960×540 / 125% | Not implemented or Stage 4 tested | Expanded-text drawer; wrap controls/trays; never shrink text to fit |
| 960×540 / 150% | Not implemented or Stage 4 tested | Full-width detail sheet; scroll long context; pin footer and critical Battle strip |
| 1280×720 / 100% and 125% | Proposed window target | Same flow and focus groups, proportionate gaps, no rule or known-information change |
| 1280×800 / 100% and 125% | Proposed 16:10 layout target | Additional vertical space; no hardware/performance claim |
| 1920×1080 / 100% and 150% | Proposed window target | Cap body line length; enlarged tiles and controls without excessive stretch |

No mobile/touch architecture target is added. Window and text-scale targets require explicit approval and Godot implementation verification. Scale specimens describe reflow, not a current settings capability.

Required long strings: `UI_RUN_SCENE_0012` interrupted-save explanation; `UI_RUN_CONTROLLER_0001` accepted-action/save-write failure; `UI_RUN_SCENE_0146` full Contract summary; long Run Tile Pool inventories; Workshop target/result labels; Complete Hand interpretations with Quads; final Build Story milestones. Use existing Godot 30% pseudo-expansion (historical observed 186→301 and 175→268 for the first two). Preserve interpolation placeholders, never convert paths or IDs into forced nonbreaking lines. Wrap strings and grow content before using vertical scrolling. Test no clipping, obscured focus, overlapping buttons, missing selected instances or horizontal action scrolling.

## Feedback matrix

Normal, Fast and Instant use the same authoritative snapshot and visible cue text. Complete Hand, Boss-phase and victory cues survive all modes in Domain event order. Feedback persists until readable/dismissed; no animation duration determines save, command acceptance or input availability. Error retains context. Empty state says what is absent and the currently legal next action; do not suggest Draw/Refresh if current validation forbids it. Critical feedback remains textual without audio.

## Checks after implementation approval

Capture from the actual Godot build using an adapted `tests/stage4_accessibility_capture_probe.gd` and version the exact source/content/build/engine identifiers. Existing suites and commands are the starting gate, not newly passed evidence:

```sh
GODOT_BIN="/absolute/path/to/Godot_4.7.2" bash scripts/test.sh --presentation
GODOT_BIN="/absolute/path/to/Godot_4.7.2" bash scripts/test.sh --stage4-accessibility
GODOT_BIN="/absolute/path/to/Godot_4.7.2" bash scripts/test.sh --stage4-localization
python3 tests/localization_audit_test.py
python3 scripts/validate_localization.py
GODOT_BIN="/absolute/path/to/Godot_4.7.2" bash scripts/test.sh
```

In the approved implementation, add meaningful checks for local selection versus commit, modal Cancel/focus restoration, legal descriptor mapping, insufficient resources, rejected commands, empty states, layout reflow and exact cue ordering. Script critical mouse/keyboard/virtual-controller journeys, capture each supported layout and pseudo case, scan logs for script/parse/load/runtime errors, and compare Domain checkpoints across modes. Physical-device tests remain unclaimed unless actually run.

Maintainer reviews implemented before/after evidence and findings; no P0/P1 remains, every P2 gets owner and explicit disposition. Native-device measurements remain waived; participant testing remains deferred. Do not claim external accessibility-standard conformance. #98 stays open until its implemented exit gate is satisfied.
