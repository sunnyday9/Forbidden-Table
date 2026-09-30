# Design validation — 2026-10-01

**Proposed v1; approval pending.** These checks concern design artifacts. They are not a Stage 4.5 PASS, a fresh Run playthrough, or evidence of implemented Godot accessibility.

## Current artifact checks

- 36 baseline screen/state PNGs at 960×540, matching `screen_manifest.json`.
- 2 expanded-text sheet PNGs at 125% and 150%; both remain 960×540. Their footer ends at y=524, inside the 16 px bottom margin.
- 3 window-composition PNGs at 1280×720, 1280×800 and 1920×1080. These center the native composition; they do not demonstrate every proposed responsive/text-scale matrix cell.
- 3 contact sheets and a six-screen overview. Each source capture is independently available at native size.
- Playwright Chromium checks report no button-label clipping or horizontal panel overflow on all 36 baseline drawings. Baseline footers end at y=512. Map contextual detail has intentional independent vertical scrolling; all important actions remain visible.
- All four gallery font faces loaded. A real keyboard Tab moved to a tile with a solid 3 px outline. This checks the review viewer, not Godot/controller reachability or overlay focus restoration.
- Normal/Fast/Instant viewer selections preserve identical ordered Complete Hand → Boss phase → victory text. The viewer does not simulate real animation durations or Domain event delivery.

Raw measurements: [layout_checks.json](source/layout_checks.json). Artifact integrity and dimensions: [package_checks.json](source/package_checks.json), [artifact hashes](source/artifacts.sha256).

The browser review caught and corrected horizontal border/padding overflow, duplicate focus specimens on ordinary screens, a footer obscured by enlarged text, a selected Workshop target without a corresponding face mark, and control-border contrast below the design target. The three initial broken Figma PNGs were replaced by corrected browser renders; no broken authoring capture is presented as a final mockup.

## Measured palette pairs

Ratios use sRGB relative luminance. Text target ≥4.5:1; control boundary/focus target ≥3:1. These are internal targets, not a conformance certification.

| Foreground / background | Ratio |
| --- | ---: |
| Primary text / table | 14.57:1 |
| Primary text / panel | 12.94:1 |
| Primary text / raised control | 10.52:1 |
| Secondary text / panel | 9.16:1 |
| Secondary text / raised control | 7.45:1 |
| Ink / ivory tile | 13.77:1 |
| Ink / brass commit | 8.59:1 |
| Cyan focus / raised control | 9.02:1 |
| Brass selection / panel | 8.07:1 |
| Coral error / panel | 9.07:1 |
| Jade success / panel | 9.94:1 |
| Revised edge `#6B877B` / raised control | 3.20:1 |

Ivory/brass and ivory/cyan are not text combinations. Tile focus is outside the ivory face against the dark table; selected identity remains visible, and explicit selection labels accompany the outline. Unavailable controls retain readable text and a dashed edge/reason.

## Figma and approval

The Education reconnection was verified with `whoami` (`tier=student`) and successful read/edit calls. The service does not expose an exact remaining-call counter. [Published Education limits](https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/) are up to 200/day, 10/minute.

The supplied [Education copy](https://www.figma.com/design/xXzt7gEelGQh37Ak51ogGa) was inspected and refined directly. All 36 root frame IDs were preserved. Native measurements show 960×540 bounds, footer bottom y=512, a 44 px minimum button height, and no measured button-label overflow. Six native core exports and three native indexes covering all 36 frames were visually inspected. Focus is native outline geometry independent of selection. [Native measurements](source/figma_checks.json) and [saved Figma exports](mockups/figma/) supplement the browser checks above.

These checks verify design drawings. Figma does not demonstrate controller navigation, command execution, scroll restoration, animations, or full enlarged-text/viewports behavior. The browser enlarged-text and window specimens remain separate design targets.

## Not newly verified

No runtime `.gd`, `.tscn`, `.tres`, localization catalog or project configuration changed. Existing game gates were not rerun for this design-only package. Physical-controller/device behavior, full pseudo-localization corpus, actual save recovery, current command legality and implemented animation timing remain the approved-implementation checks listed in [the interaction plan](INTERACTION_AND_VALIDATION.md). Stage 4 PASS remains historical evidence at its recorded commit. #98 remains open; Stage 5 remains **1.0 Release Candidate**.
