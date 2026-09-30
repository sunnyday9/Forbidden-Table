# Stage 4 Pre-release Accessibility Checklist (#92)

**Recorded:** 2026-09-30

**Scope:** Current Stage 4 Run presentation screens and critical states in `RunScene`. This checklist does not add a general accessibility framework or language-localization system.

**Specification basis:** `PROJECT_SPEC.md` §§19.1–19.3: embedded tutorial may be reset or disabled; support keyboard and controller focus navigation; critical actions must not require dragging.

**Conformance:** No external accessibility standard was selected for this task. No WCAG or other conformance claim is made.

## Build and test context

| Item | Recorded value |
| --- | --- |
| Godot | 4.7.2-stable (official), `ed1daf0bf` |
| Project build version | `stage3-alpha-playable-1` |
| Content version | `content.bundle.v1.alpha.act_two@v5+alpha.scale@v12+phase2@v4` |
| Supported viewport checked | 960 × 540 (`project.godot`) |
| User-selectable UI scale | None found in project settings or presentation controls; no additional scale sizes are claimed as tested |
| Platform evidence | Local Linux Godot run, display-backed viewport capture; no physical-device test |

Commands run from the project root:

```sh
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --stage4-accessibility
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh
DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 ./.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path "$PWD" --script res://tests/stage4_accessibility_capture_probe.gd
```

The focused accessibility command passed. Its report recorded 12 required phases, 19 scripted critical-state buckets, 90 keyboard accepts, 90 controller accepts, and 57 visible-cue comparisons across Normal/Fast/Instant presentation modes. The display-backed capture probe saved 18 960 × 540 PNGs and finished with `layout_failures=0 flow_failures=0`. The full test suite passed with no Godot runtime, script, parse, or load errors.

The capture probe waits for process and post-draw frames, then performs the text-bounds audit and saves the viewport image. It also records settled geometry for the long Run Tile Pool label. In Act 2 Map, Elite Reward, and Boss Reward, the four-line label measured 23 px per line, 92 px required height, 101 px allocated height, 101 px minimum height, and 96 px custom minimum height. This confirms that the full label remains laid out inside its vertically scrollable overview; a scroll viewport showing only part of that full label is expected while the overview is scrolled.

## Checklist results

| Acceptance check | Evidence and result |
| --- | --- |
| Visible focus on required phases and action states | **PASS (scripted).** The test audits the visible GUI focus owner and verifies that presentation action focus matches a visible focused button. Run Summary focuses `Finish Run`; Run Complete focuses `New Run`. Screenshots include visible focus outlines on selected actions and New Run. |
| Keyboard reachability | **PASS (scripted).** Keyboard Tab/arrows/Enter/Esc navigate and operate actions through the real RunScene flow. The overview scroll can be entered and left with Tab; Up/Down scrolls while it owns focus. Scroll up/down buttons are separately focusable and labeled. |
| Controller reachability | **PASS (scripted).** D-pad, A/B, and shoulder navigation operate the same screen flow; the overview scroll is reachable with shoulders and scrolls with D-pad Up/Down. No critical tested action requires drag input. This is virtual controller-input evidence, not hardware testing. |
| Critical information not conveyed by color alone | **PASS (scripted).** Battle cues are visible text (`Enemy HP`, `Enemy intent`, `Pressure`, `TP`, `Stability`, `Patterns available`, `Hand`, and `Reserve`). Tutorial guidance, phase names, action names, selected action details, and tutorial toggle/reset states also have text labels. The required Battle cue text is compared across all three presentation modes. |
| Readable, unclipped text at the supported viewport | **PASS (scripted/rendered).** The bounds audit checks visible label/button rectangles, button minimum size, wrapped-label line height against allocated height, and horizontal overflow in `RunOverviewScroll` and `AvailableActionsScroll`. The local viewport is 960 × 540. Text longer than the panel is vertically scrollable; it is not truncated within its Label. There is no project UI-scale control, so no other scale is claimed. |
| Tutorial reset and disable | **PASS (scripted).** Reset starts disabled before progress, becomes available after tutorial progress, returns the tutorial to its first step, and restores its prompt. Disable and re-enable states are recorded. The capture set includes enabled, disabled, and reset Battle states. |
| Critical cues in Normal, Fast, and Instant | **PASS (scripted).** All currently visible critical screen text is compared for equality across the three presentation modes in 57 audited cue states. |
| External accessibility conformance | **NOT CLAIMED.** No external standard was selected and this work is not a conformance audit. |

### Scripted screen and critical-state coverage

The focused report recorded these 12 phases: Character Select, Contract Select, Map Choice, Battle, Reward Choice, Elite Reward, Boss Reward, Shop, Workshop, Event, Run Summary, and Run Complete.

It also recorded these 19 distinct screen/action buckets: `character_select`, `contract_select`, `map_choice_act_1`, `map_choice_act_2`, `battle_draw_end_turn_tutorial_on`, `battle_partial_settlement_tutorial_on`, `battle_technique_tutorial_on`, `battle_technique_tutorial_off`, `battle_complete_hand_tutorial_on`, `reward_choice`, `elite_reward`, `boss_reward`, `event`, `shop`, `workshop_service_choices`, `workshop_target_choice`, `workshop_value_choice`, `run_summary`, and `run_complete`.

The Battle action audit includes Draw, Partial Settlement, Technique, End Turn, Reserve, Discard, Reserve Swap, and Complete Hand. The run-flow audit also checks Event, Shop, Workshop, map, reward, summary, and completion actions. The focused report lists the complete observed action kinds and cue count.

### Display-backed screenshot matrix

These PNGs were generated from the local 960 × 540 Godot viewport by `tests/stage4_accessibility_capture_probe.gd`. They are visual evidence for the named representative state; states not represented here were checked by the scripted screen/action matrix above.

| Captured state | Evidence |
| --- | --- |
| Character Select | [character_select.png](evidence/stage4_accessibility/character_select.png) |
| Contract Select | [contract_select.png](evidence/stage4_accessibility/contract_select.png) |
| Act 1 Map Choice | [map_choice_act_1.png](evidence/stage4_accessibility/map_choice_act_1.png) |
| Battle, tutorial enabled | [battle_tutorial_on.png](evidence/stage4_accessibility/battle_tutorial_on.png) |
| Battle, overview scrolled to Help and Tutorial | [battle_overview_scrolled.png](evidence/stage4_accessibility/battle_overview_scrolled.png) |
| Battle, tutorial disabled | [battle_tutorial_disabled.png](evidence/stage4_accessibility/battle_tutorial_disabled.png) |
| Battle, tutorial reset | [battle_tutorial_reset.png](evidence/stage4_accessibility/battle_tutorial_reset.png) |
| Reward Choice | [reward_choice.png](evidence/stage4_accessibility/reward_choice.png) |
| Act 2 Map Choice, long pool | [map_choice_act_2.png](evidence/stage4_accessibility/map_choice_act_2.png) |
| Run Summary | [run_summary.png](evidence/stage4_accessibility/run_summary.png) |
| Run Complete | [run_complete.png](evidence/stage4_accessibility/run_complete.png) |
| Event Choice | [event_choice.png](evidence/stage4_accessibility/event_choice.png) |
| Elite Reward, long pool | [elite_reward.png](evidence/stage4_accessibility/elite_reward.png) |
| Boss Reward, long pool | [boss_reward.png](evidence/stage4_accessibility/boss_reward.png) |
| Shop | [shop.png](evidence/stage4_accessibility/shop.png) |
| Workshop service choices | [workshop_service_choices.png](evidence/stage4_accessibility/workshop_service_choices.png) |
| Workshop target choice | [workshop_target_choice.png](evidence/stage4_accessibility/workshop_target_choice.png) |
| Workshop value choice | [workshop_value_choice.png](evidence/stage4_accessibility/workshop_value_choice.png) |

## Visual-inspection notes and boundary

The implementing Codex agent inspected the generated PNGs in the Codex image viewer. The root Codex agent independently inspected the repo-local captures. These are software-agent reviews of rendered images, not human participant findings or device tests. **Maintainer/user review of the attached screenshots is pending.** No participant testing, physical controller/device testing, assistive-technology testing, or usability study was performed.

The Battle scrolled capture is at the overview scroll limit so the Help and Tutorial blocks are visible. Its top edge intersects the preceding Battle summary because of that scroll position. The full wrapped label passes the post-layout line-height check and remains reachable by scrolling; this is viewport cropping at the scroll boundary, not an individual label being allocated too little height. The unscrolled Battle capture is included separately.

## Findings ledger

| Screen/state | Impact / severity | Owner | Disposition |
| --- | --- | --- | --- |
| Contract Select long action captions | Risk/reward/build information extended beyond the action panel horizontally; **moderate / P2 readability**. | RunScene presentation | **Fixed for #92:** concise focusable action names; full details remain in a wrapped selected-action block that follows keyboard/controller focus. Horizontal overflow is disabled and audited. |
| Run overview long Run Tile Pool text (Act 2 Map, Elite Reward, Boss Reward and other long-pool states) | Wrapped Label was shorter than its measured text; **moderate / P2 clipping**. | RunScene presentation | **Fixed for #92:** remeasure after container layout using deferred update and set the Label minimum height. Settled long-label checks now allocate 101 px for the 92 px text requirement; post-frame audit passes. |
| Run Complete focus | Enabled New Run action lacked a guaranteed initial visible focus; **moderate / P2 keyboard/controller discoverability**. | RunScene presentation | **Fixed for #92:** focus New Run when the control is attached to the viewport; regression asserts `NewRunButton.has_focus()`. |
| Battle feedback for phase-change event | Internal event identifier could appear as user-facing feedback; **low / P3 clarity**. | Run presentation controller | **Fixed for #92:** show `Run advanced.` and assert that text in the focused presentation test. |

No unresolved product clipping or keyboard/controller reachability exception was found by the final scripted and rendered bounds checks. The screenshot review gate remains pending for the maintainer/user.

## Final result

- **Focused scripted accessibility audit: PASS.**
- **Display-backed screenshot and layout audit: PASS**, 18 captures, zero layout/flow failures.
- **Full test suite: PASS.** The full domain, simulation, Run progression, presentation, and Intent Graph suite completed with exit status 0 and no runtime/script/parse/load errors.
- **Maintainer/user visual review:** pending.
- **Conformance claim:** none.
