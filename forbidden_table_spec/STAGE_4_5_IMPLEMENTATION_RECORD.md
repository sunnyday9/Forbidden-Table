# Stage 4.5 implementation record

## Approved design and scope

On 2026-10-01 the maintainer approved the current V2.2 design and requested implementation with module-specific **GPT-6 Luna subagents at max reasoning effort**:

> The current UI/UX design looks ok, please start working on the implementation of them. You should work as an orchestration agent, using subagent to implement different modules, the subagent should use GPT6 luna with max reasoning effort

Approved reference: design package commit `91a1013`, the English/Simplified Chinese V2.2 review, and Figma Education copy `xXzt7gEelGQh37Ak51ogGa`. Live Figma implementation context was retrieved for Chinese Character `2044:2`, Battle `2044:258`, and language settings `2045:579`, with screenshots and component guidance. Other phase references are the corresponding approved editable frames and checked-in fixtures. Actual gameplay values must replace illustrative fixtures.

Implementation branch: `codex/stage4-5-uiux-design`, descended from Stage 4 PASS `0f565b9`, with the spec selectively carried from `9003451`. Unrelated local files, graphify output and caches remain untouched. No push is authorized.

## Current project location

On 2026-10-02 the maintainer required all project work and artifacts to stay under `F:\Forbidden Table`. The implementation worktree was initially relocated to `F:\Forbidden Table\.codex-worktrees\stage4-5-uiux-design`, with its original `05219b3` implementation content verified and preserved. The old C-drive task directory and four task-owned visualization captures were relocated; existing project-specific Windows user data was preserved under the F-drive worktree's ignored `.cache/windows/` folder. The main research checkout and unrelated artifacts were preserved.

The maintainer subsequently requested the implemented UI directly in the root project. The primary working checkout is now `F:\Forbidden Table` on `codex/stage4-5-primary-project`, based on `412b065`; its `project.godot` uses the current Stage 4.5 screens, assets and EN/SC localization. Existing local configuration edits and unrelated files were preserved, and the 49 project-specific user-data files were copied and byte-verified into the root project’s `.cache/windows/` folder.

Use `F:\Forbidden Table\PLAY_FORBIDDEN_TABLE.cmd` to play or `F:\Forbidden Table\EDIT_FORBIDDEN_TABLE.cmd` and F5 to run from the editor. These launchers keep Godot data/cache/temp/logs under F using process-local environment variables. Future project docs/code/evidence/exports must be written under the F-drive project folder. Historical source logs retain their original paths as provenance. No release or issue closure is authorized by the relocation.

Native Windows Godot 4.7.2 validation passed after relocation: the actual play launcher completed a headless editor import with exit 0, and a separate storage probe verified F-drive data/config/cache/user-data/temp paths and successfully wrote and removed a user-data probe file. Both logs contain no script or load errors. The full suite and human playtest were not rerun for this storage-only change. Local logs remain under `.cache/`.

Root-project promotion validation also passed with native Windows Godot 4.7.2: clean final import, normal main-scene headless startup, F-only storage/write probe, and `--stage45-ui --stage4-accessibility --run-scene` (five UI modules, zero failures). The initial import generated missing locale resources; the final import and validation logs contain no script, parse or load errors. All 411 non-configuration files in the tested source manifest match the root checkout; `project.godot` differs only by preserved preexisting editor comments/property order. Local evidence is under `.cache/main-project-verification/`. Physical-device/human playtesting and the full suite were not repeated.

## Module ownership and integration contract

The parent orchestrates scope, interfaces, integration, review and evidence. Workers share the isolated worktree, edit only their assigned files, and do not stage, commit, push, alter Domain/content rules or write to the issue tracker. Dependent scene modules use the shared UI interfaces after foundation delivery; localization and preference work can proceed independently.

| Module | Ownership |
|---|---|
| UI foundation | `src/presentation/ui/forbidden_theme.gd`, `tile_face_button.gd`, `table_backdrop.gd`, `motion_feedback.gd`; runtime art/tile/English font assets; focused foundation tests |
| Bilingual preferences | `src/presentation/localization/`, `localization/`, locale validation, `project.godot`, SC font assets, focused bilingual tests; standalone settings/help overlay under `src/presentation/ui/preferences_overlay.gd` |
| Run journey | `scenes/run/run_scene.gd`, `run_scene.tscn`, `src/presentation/ui/run_journey_view.gd`, `run_map_view.gd`, `run_summary_view.gd`; Character/Contract/maps/Events/rewards/Shop/Workshop/summary/recovery and focused Run UI tests |
| Battle and feedback | `src/presentation/ui/battle_view.gd`, standalone `scenes/battle/`; hand/Reserve/Pattern/Complete Hand/tile detail, ordered feedback and focused Battle UI tests |

### Shared APIs

- `ForbiddenTheme.create_theme(locale="en", ui_scale=1.0) -> Theme`; `style_panel(panel, surface="lacquer", selected=false)`; `style_button(button, primary=false, selected=false)`; `title(label, locale="en")`; `tile_texture(definition_id) -> Texture2D`. Match approved palette and Noto Sans/Serif roles; SC families for Chinese.
- `TileFaceButton.configure(tile: Dictionary, selected=false, large=false)` and `set_selected(bool)`. Dictionary includes stable `definition_id`, exact `instance_id`, optional `copy_label`/annotations. Preserve standard PNG face without cropping and a minimum 44px hit width. No Domain command on focus or inspection.
- `TableBackdrop` is a non-interactive cosmetic Control using the approved salon with a readability scrim. Optional ambient glow respects reduced/Instant modes.
- `MotionFeedback` accepts existing presentation mode and reduced-motion preference, cancels safely, and animates an already-final visible state; it never submits commands or delays authority.
- `PresentationPreferences` (Node, autoload `PresentationPrefs`) exposes `locale`, `presentation_mode` (`NORMAL/FAST/INSTANT`), `reduced_motion`, `ambient_glow`, `ui_scale`; `apply_preferences(Dictionary) -> Dictionary`, `preferences_changed` signal, and a testable configuration path. Preferences remain outside Run snapshots and Domain commands. System language first launch, explicit saved preference thereafter; English fallback.
- `PreferencesOverlay` is a standalone modal Control. `open(preferences, origin_focus: Control=null, tutorial_progress=null)`; `close()`; `closed` and `preferences_applied` signals. It provides localized help/settings, pending versus applied language, mode/reduced/ambient/scale controls, tutorial toggle/reset when applicable, and returns focus on cancel/close.
- `BattleView.configure(controller, action_label: Callable, tooltip: Callable, details: Callable)`; `render()`; `cancel() -> bool`; `action_requested(action_id: String)` and `focus_requested(action_id: String)` signals. It consumes existing valid descriptors and current state. Partial/Complete Hand and tile details are presentation choices; only explicit commit requests submit an existing action.

Run scene integrates the approved composition and all phases, preserving public methods and node names relied on by existing tests where meaningful. Mouse/keyboard/controller, visible independent focus/selection, back/cancel, confirmation and failure handling must remain correct. New copy uses stable localization keys, with both locales provided by the bilingual owner.

## Implemented behavior

The presentation uses the approved haunted salon background, distinct Character portrait crops, lacquer/jade/brass surfaces, Noto body/heading families, and the 34 standard Chinese tile faces. Character, Contract, both Act maps, Events, all reward classes, Shop, Workshop, Battle, tutorial/help/settings, summary and save/profile recovery use the existing Run controller. Focus previews detail, selection is local presentation state, and the separate commit action dispatches the existing command. Purchases, Workshop services and replacing a suspended Run retain explicit confirmation and cancel paths.

English and Simplified Chinese are selectable in Settings with saved presentation preferences; first launch uses a supported system language or English fallback. Presentation mode, text scale, reduced motion, ambient glow and tutorial preferences stay outside authoritative snapshots. Catalog labels that enter state/replay retain canonical English source values, while the UI translates at presentation seams. Cross-locale continuation checks compare checkpoints, replay and later command outcomes.

Battle displays typed enemy Intent, recognizable tile faces with a separate status strip, bounded table/choice/inspection scrolling and a pinned commit rail. Normal/Fast cosmetic draw feedback starts after the authoritative change; Instant/reduced motion cancels it without changing command timing. Ordered Settlement, Boss-phase and Victory receipts survive phase changes. Warnings remain visible alongside terminal receipts. Recovery paths and codes are in expandable technical Details; the guidance and disclosure relocalize without reloading or rewriting saves.

## Verification and exit

Implementation is complete for maintainer review. Fresh Godot 4.7.2 Linux import, default full suite, focused Stage 4.5/Run/accessibility checks, bilingual catalog audit and 17 Python regressions passed without script/load/assertion/teardown errors. The rendered matrix passed all 27 cells and 38 states per cell: 1,026 frames, zero layout or flow failures. The review package retains 221 PNGs, full manifests/logs and hashes for 412 source/asset files. Text line-ending normalization for Git is accounted for by the LF-normalized source hashes.

Review [the implemented-screen gallery](evidence/stage4_5/gallery.html) and [the evidence/reproduction report](evidence/stage4_5/README.md). All critical actions were exercised by scripted keyboard/controller paths; actual mouse selection, Draw and a live cosmetic tween were checked. Normal/Fast/Instant retain 57 critical cue states; locale/scale changes preserve command/checkpoint/replay boundaries. This evidence does not repeat the separate Stage 4 1,000-run corpus, establish native PC/Steam Deck performance, measure physical-controller behavior, or evaluate participant comprehension.

The parent inspected the integration diff and a GPT-6 Luna/max review worker reported presentation defects that were fixed and regressed. The Run journey worker's final optional recheck was interrupted by account quota; parent focused/default and graphical checks provide the recorded acceptance evidence. No issue comments, closure, push or release occurred.

Design approval permits implementation; it does not establish implementation PASS, authorize release or close #98. Issue #98 remains open for the maintainer's implemented-screen review. Stage 5 remains **1.0 Release Candidate**.

### Fresh unchanged-design baseline (2026-10-01)

A temporary detached worktree at `/tmp/forbidden-table-stage45-baseline` froze `91a1013` while implementation workers edited the isolated working branch. Godot `4.7.2.stable.official.ed1daf0bf` Linux completed the default suite with exit 0 and `PASS: full domain, simulation, Run progression, presentation, and Intent Graph test suite`. Its Stage 4 accessibility matrix covered all 12 phases, both Acts, all eight critical Battle action kinds, pseudo-localization, virtual keyboard/controller outcomes, and Normal/Fast/Instant text cues. This is a baseline result, not evidence for the later implementation.

The initial Windows Godot baseline was unsuitable for the full suite: corpus provenance tests execute Linux `which`/GNU `timeout`, producing process errors and failed corpus harness assertions. Validation therefore uses the same pinned engine's Linux binary. No product behavior was changed to accommodate this environment difference. Raw baseline logs remain local in `/tmp/ft-stage45-linux-baseline-suite.log`.

## Implementation defect dispositions

These were found during integration/source review and rendered checks. All fixes are in presentation, localization or test/evidence fixtures. Every listed regression passed the final frozen-source checks linked above; each disposition is **fixed and automated-verified**.

| Severity | Defect | Owner | Fix and regression boundary |
|---|---|---|---|
| P2 | Map labels exceeded node controls at 125/150%, especially accented pseudo text | Run journey worker | Actual Label minimum plus smart-wrap sizing; EN/CN scale regression and both Act/resumed-map graphical checks |
| P2 | Redraw restored an old Battle tile over a newer Complete Hand choice | Battle worker | Synchronous focus restore; a coalesced frame callback scrolls only the current focus owner and never grabs focus; old-tile/double-render/new-choice regression |
| P2 | New focused Battle choice remained outside the visible rebuilt list | Parent integration | Queue visibility for new action/tile focus and selection after layout; one-shot Node callback coalesces requests and disconnects safely on teardown; test and capture require focused choice to intersect its scroll viewport |
| P2 | Card selection moved focus to the commit rail | Run journey worker | Keep focus on the selected card; update the separate commit rail without grabbing focus |
| P2 | Empty-zone text collapsed to a one-pixel HFlow child | Battle worker / parent | Full-width VBox label; empty-zone and all-action width assertions |
| P2 | Draw feedback targeted a freed tile after duplicate Root renders | Battle worker / parent | Surviving final tile with weak target/cancellation; actual mouse Draw asserts authority, one command and live cosmetic tween |
| P2 | Terminal Victory receipt hid a save warning | Parent integration | Warning and ordered receipt coexist; actual two-Act terminal save-failure regression |
| P2 | Summary time changed when language/theme refreshed | Run journey worker | Presentation-only terminal anchor retained through acknowledgement; delayed Normal/Fast/Instant comparison |
| P2 | Shop/Workshop confirmation kept its previous language | Run journey worker / parent | Refresh pending confirmation from descriptors; EN↔CN preserves pending ID/checkpoint and commits once |
| P2 | Recovery messages/codes stayed in the old locale or crowded primary guidance | Run journey worker / bilingual worker / parent | Structured key/argument caching and technical Details; save/profile bytes unchanged through locale/disclosure changes |
| P2 | Profile Reset was enabled when source preservation failed | Run journey worker / parent | Disable rejected action, show localized external steps and an absolute original-file path in Details; denied-preservation fixture verifies no writes |
| P2 | Expanded profile recovery pushed the footer outside 960×540 at 150% | Parent integration | Viewport-budgeted recovery scroll with focus following; actual-scene rail bounds and graphical recovery states |
| P2 | Long header/resource copy expanded the page beyond the viewport | Parent integration | Smart-wrapped shared header and resource rail; all-phase graphical pseudo150 and locale/scale matrix |
| P2 | Already localized controls translated copy again, doubling pseudo expansion | Parent integration | Disable automatic translation at keyed presentation roots; explicit locale refresh remains authoritative for copy and graphical checks retain 30% expansion |
| P2 | Settings controls forced the dialog beyond 960px under expanded large text | Parent integration | Responsive one/two-column settings grid retains vertical scrolling and every option; graphical Settings matrix |
| P2 | Expanded suspend Details displaced startup actions at minimum viewport | Parent integration | Viewport-capped technical Details height; recovery guide remains complete and scrollable; graphical save recovery states |
| P2 | Long Summary guidance escaped the outcome card | Parent integration | Focusable vertical outcome scroll preserves complete guidance; graphical summary/end states and keyboard/controller acknowledgement |
| P2 | Settings Help did not use available width | Bilingual worker | Fill bounded help/scroll layout; EN100 and CN150 interaction/layout tests |

No known P0/P1 remains and no known P2 is deferred; all listed P2 fixes passed their automated/rendered regression boundaries. Human judgment of visual quality and implemented-screen approval remain the maintainer review boundary.
