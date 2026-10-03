# Stage 4.5 — UI/UX Design and Implementation

**Status:** Added by maintainer direction on 2026-09-30. Roadmap and execution map: [#98](https://github.com/sunnyday9/Forbidden-Table/issues/98). Stage 4.5 follows a recorded Stage 4 Beta PASS and precedes the existing Stage 5 — 1.0 Release Candidate.

## 1. Purpose

Stage 4's accepted gates establish content completeness, required Run flows, baseline accessibility, localization readiness, and presentation feedback. They do not define a cohesive production visual language or a designed layout system for the game. The available Stage 4 captures show functional text panels and buttons; this stage turns that interface into a coherent, readable presentation for the supernatural Mahjong-table setting.

Keep the product's visual priority from the [Project Specification](PROJECT_SPEC.md):

`Readability > state clarity > tile recognition > animation feedback > decoration`

Stage 4.5 is a presentation and interaction stage. Game rules, authoritative Run state, content budgets, and the existing Stage 5 name remain unchanged.

## 2. Stage boundary

- **Entry:** Stage 4 map [#72](https://github.com/sunnyday9/Forbidden-Table/issues/72) records Beta PASS. Stage 4.5 must not substitute visual polish for any open Stage 4 evidence requirement.
- **Work:** inventory and design the full player-facing journey, approve mockups and visual rules, implement the approved design, and verify the result.
- **Exit:** the maintainer reviews the implemented screen evidence, all P0/P1 defects are resolved, and every P2 has an owner and explicit disposition.
- **Next:** Stage 5 remains the 1.0 Release Candidate stage.

## 3. Design package

Before implementation, produce a reviewable package containing:

- A screen inventory and flow map for starting a Run, selecting a Character and Contract, traversing both Act maps, battle and Settlement, Events, rewards, Shop, Workshop, Act transitions, tutorial/help/settings, and Run Summary/end states.
- Mockups for each core screen and its important states: selected, focused, disabled, empty, confirmation, error, and contextual explanation where applicable.
- A visual system covering the tabletop direction, information hierarchy, typography, spacing, color roles, tile and Pattern presentation, panels, buttons, icons, feedback, and motion. Define primitive, semantic, and component-level rules and map them to Godot's existing Theme/resource seams.
- Interaction notes for mouse, keyboard, and controller, including visible focus, selection, back/cancel, and clear feedback for critical actions.
- A supported viewport and UI-scale matrix, plus representative longest-string cases for localization expansion.

The maintainer approves the visual direction and mockups before implementation begins. Feedback is recorded in #98.

## 4. Implementation constraints

- Implement the approved UI in the existing presentation layer. User input continues to issue validated commands; Domain state and rule resolution remain authoritative and independent of scenes, UI, and animation timing.
- Keep tiles, Patterns, enemy intent, resources, and critical choices legible. Color may reinforce critical status but must not carry its meaning alone.
- Keep all critical actions reachable through supported keyboard, mouse, and controller input. No critical action may be drag-only; focus and back/cancel behavior must be visible and consistent.
- Respect Normal, Fast, and Instant presentation modes. Required Complete Hand, Boss-transition, victory, and action feedback remains perceivable, while animations never delay state changes or critical input feedback.
- Use existing localization seams. Longer localized or pseudo-localized text must not clip or obscure tiles or decisions at supported scales.
- Reuse existing game content, audio, and core systems. A proposed new system requires a separate evidence-backed scope decision.

## 5. Verification and exit evidence

- The final screen matrix covers every core flow and important state in §3, with build/content identifiers and reproducible capture instructions.
- Supported viewport and UI-scale checks show no clipped critical text, obscured tiles, overlap, broken navigation, or undocumented placeholder presentation on required paths.
- Scripted input checks cover critical mouse, keyboard, and controller actions, including focus and back/cancel.
- Regression checks cover visible focus, non-color-only status, localization expansion, and Normal/Fast/Instant feedback. Domain state resolution remains independent of presentation completion.
- The full automated suite and affected UI/input/accessibility checks pass. No P0/P1 remains; each remaining P2 has a named owner and fix, defer, or accepted-risk disposition.
- The maintainer records Stage 4.5 PASS/FAIL, approved design artifacts, final screen evidence, exact verification commands, and limitations in the issue map.

This stage does not require a participant study before the first actual MVP release. Preserve the existing native-device measurement waiver and do not claim external accessibility-standard conformance without selecting and testing a standard.

## 6. Out of scope

- Changing the Stage 4 Beta scope or accepting incomplete Stage 4 exit evidence.
- Changing Mahjong rules, combat behavior, content budgets, Run structure, or persistence contracts.
- Adding a new major gameplay system or conducting a pre-release participant study.
- Renumbering or redefining Stage 5 — 1.0 Release Candidate.
