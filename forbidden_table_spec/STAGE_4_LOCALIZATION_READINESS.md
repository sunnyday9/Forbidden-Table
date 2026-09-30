# Stage 4 Localization Readiness — Issue #93

## Scope and decision

This report records the localization-readiness evidence for issue #93 against the accepted Stage 4 Beta scope, §6, and its accessibility/localization gate. English is the source locale. No translated locale or translation-quality claim is made.

The project’s existing seams are sufficient: Godot `TranslationServer`, the imported English CSV catalog, the project locale registry, and built-in pseudo-localization. The implementation adds a narrow `Localization` adapter and extraction checks; it does not propose a localization core system. The #44 evidence threshold for a new core subsystem is therefore not triggered: the existing seam supports extraction, interpolation validation, and pseudo-layout verification.

## Coverage

| Measure | Result |
| --- | ---: |
| Stable source keys referenced / resolved | 954 / 954 (100%) |
| English source entries | 954 |
| Literal UI/content keys | 469 |
| Dynamic content-ID labels | 321 |
| Dynamic word labels | 166 |
| Missing keys or unresolved references | 0 |
| Invalid format strings or interpolation arity | 0 |
| Runtime registered content IDs checked | 305 |
| Runtime dynamic words checked | 166 |

The category counts overlap and are not additive. The runtime word inventory includes identifier-derived labels, event choice and alternative IDs, and lifecycle/reason labels. Run Summary’s historical Boss ID is included because the presenter resolves it through the dynamic content-label path.

## Pseudo-localized layout pass

The runtime pass enables Godot pseudo-localization with 30% expansion, then checks representative long strings in a live 960×540 UI and observes critical layout bounds. `UI_RUN_SCENE_0012` expands from 186 to 301 characters; `UI_RUN_CONTROLLER_0001` expands from 175 to 268 characters. The pseudo pass reports `critical_layout=CHECKED`, with no missing keys or clipped critical UI. The test also checks that English behavior is restored after pseudo mode.

## Formatting and dynamic-message audit

The catalog validator checks every English format token, every literal localization call’s supplied argument count, and malformed interpolation. Runtime helpers fail on missing keys, unresolved interpolation, and invalid format tokens. The reaction-skip message previously received an internal reason code directly; it now maps `INSUFFICIENT_TP` to `WORD_INSUFFICIENT_TP` and all other internal reason codes to `WORD_UNAVAILABLE`, so internal codes are not shown as prose. Both labels are in the required dynamic-word inventory.

## Exceptions and dispositions

| Surface | Owner | Disposition |
| --- | --- | --- |
| Content-definition/schema validation diagnostics in `src/content/definitions/` | Content Engineering | Keep English as developer/content-authoring diagnostics. These block invalid content from entering a Run and are not normal gameplay UI copy. Revisit if a product requirement exposes them to players. |
| Opaque save-operation/status codes interpolated into localized suspend-failure messages | Runtime Platform | Keep the machine codes as diagnostic tokens inside localized messages so support logs remain actionable; they are not sentence copy or content labels. |
| External accessibility-standard conformance | Product / Accessibility owner | No conformance claim. The project checklist is automated; physical-device and participant testing were not performed. |

No translated locale is pending under this issue. Translation quality is not assessed.

## Commands and evidence

Run from the repository root:

```sh
python3 tests/localization_audit_test.py
python3 scripts/validate_localization.py
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64"
"$GODOT_BIN" --headless --editor --path "$PWD" --import
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --stage4-localization
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --stage4-accessibility
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh
git diff --check
```

The Python contract tests cover missing keys, invalid interpolation, malformed unused format tokens, generated encounter variants, dynamic words, and direct UI/feedback bypasses. The focused runtime suite checks the English-only content and word inventories. The pseudo-layout report above comes from the live accessibility suite. Full-suite results are recorded after the final verification run.

## Final verification results

- `python3 tests/localization_audit_test.py`: 11 tests passed.
- `python3 scripts/validate_localization.py`: 954/954 keys, 100%, zero unresolved references or formatting errors.
- Godot editor import: passed.
- `./scripts/test.sh --battle-integration`: passed, including the readable `Insufficient TP` reaction-feedback regression.
- `./scripts/test.sh --stage4-localization`: passed; 305 registered content IDs and 166 dynamic words.
- `./scripts/test.sh --stage4-accessibility`: passed; pseudo-layout report records the 960×540 expanded-string checks above.
- `./scripts/test.sh`: passed; full domain, simulation, Run progression, presentation, and Intent Graph suite. No script/parse/load errors or failing assertions appeared in the log.
- `git diff --check`: passed.
