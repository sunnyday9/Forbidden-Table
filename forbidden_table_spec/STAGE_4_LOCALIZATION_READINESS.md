# Stage 4 Localization Readiness — Issue #93

## Scope and decision

This report records the localization-readiness evidence for issue #93 against the accepted Stage 4 Beta scope, §6, and its accessibility/localization gate. English is the source locale. No translated locale or translation-quality claim is made.

The project’s existing seams are sufficient: Godot `TranslationServer`, the imported English CSV catalog, the project locale registry, and built-in pseudo-localization. The implementation adds a narrow `Localization` adapter and extraction checks; it does not propose a localization core system. The #44 evidence threshold for a new core subsystem is therefore not triggered: the existing seam supports extraction, interpolation validation, and pseudo-layout verification.

## Coverage

| Measure | Result |
| --- | ---: |
| Stable source keys referenced / resolved | 959 / 959 (100%) |
| English source entries | 959 |
| Literal UI/content keys | 469 |
| Dynamic content-ID labels | 321 |
| Dynamic word labels | 171 |
| Missing keys or unresolved references | 0 |
| Invalid format strings or interpolation arity | 0 |
| Runtime registered content IDs checked | 305 |
| Runtime dynamic words checked | 171 |

The category counts overlap and are not additive. The runtime word inventory includes identifier-derived labels, event choice and alternative IDs, and lifecycle/reason labels. Run Summary’s historical Boss ID is included because the presenter resolves it through the dynamic content-label path.

## Pseudo-localized layout pass

The runtime pass enables Godot pseudo-localization with 30% expansion, then checks representative long strings in a live 960×540 UI and observes critical layout bounds. `UI_RUN_SCENE_0012` expands from 186 to 301 characters; `UI_RUN_CONTROLLER_0001` expands from 175 to 268 characters. The pseudo pass reports `critical_layout=CHECKED`, with no missing keys or clipped critical UI. The test also checks that English behavior is restored after pseudo mode.

## Formatting and dynamic-message audit

The catalog validator checks every English format token, every literal localization call’s supplied argument count, and malformed interpolation. Runtime helpers fail on missing keys, unresolved interpolation, and invalid format tokens. The reaction-skip message previously received an internal reason code directly; it now maps `INSUFFICIENT_TP` to `WORD_INSUFFICIENT_TP` and all other internal reason codes to `WORD_UNAVAILABLE`, so internal codes are not shown as prose. Both labels are in the required dynamic-word inventory.

The presentation audit also covers dynamic values: a dotted value uses a content label only when an English source translation exists; operational IDs such as `base.reward.skip` resolve their final word through `WORD_SKIP`. Technique IDs resolve through content labels, reaction trigger IDs through the existing technique trigger keys, and pattern types through word labels. Unmapped events use the generic `UI_RUN_CONTROLLER_0074` message. Non-Contract/non-Workshop action tooltips reuse the localized action label; Workshop tooltips display localized tile and modifier labels and omit internal TileInstance IDs. Regression cases exercise arbitrary DRAW details, operational IDs, actual tile/modifier IDs, technique and reaction feedback, a `TP_CHANGED` fallback, and a settled pattern.

Character-passive feedback interpolates the display name and description resolved from `CONTENT_SCALE_0001` and `CONTENT_SCALE_0002` during catalog construction; those source keys are included in the literal-key extraction.

## Exceptions and dispositions

| Surface | Owner | Disposition |
| --- | --- | --- |
| Content-definition/schema validation diagnostics in `src/content/definitions/` | Content Engineering | Keep English as developer/content-authoring diagnostics. These block invalid content from entering a Run and are not normal gameplay UI copy. Revisit if a product requirement exposes them to players. |
| Opaque save-operation/status codes interpolated into localized suspend-failure messages | Runtime Platform | Keep the machine codes as diagnostic tokens inside localized messages so support logs remain actionable; they are not sentence copy or content labels. |
| Enemy display strings can enter checkpointed `EnemyIntent` / state hashes | Domain / Persistence | This issue verifies English-only behavior and makes no cross-locale persistence or hash-compatibility claim. Revisit before adding locale switching or translated runs that persist these values. This is a bounded follow-up risk, not a blocker for English-source readiness. |
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
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --shop-workshop
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --battle-integration
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --stage4-accessibility
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh
git diff --check
```

The Python contract tests cover missing keys, invalid interpolation, malformed unused format tokens, generated encounter variants, dynamic words, and direct UI/feedback bypasses. The focused runtime suite checks the English-only content and word inventories. The pseudo-layout report above comes from the live accessibility suite. The final results below distinguish targeted checks from the full-suite gate.

## Final verification results

- `python3 tests/localization_audit_test.py`: 11 tests passed.
- `python3 scripts/validate_localization.py`: 959/959 keys, 100%, zero unresolved references or formatting errors; 469 literal UI/content keys, 321 dynamic content-ID labels, 171 dynamic word labels, and 959 English entries.
- Godot editor import: passed.
- `./scripts/test.sh --stage4-localization`: passed; 305 registered content IDs and 171 dynamic words.
- `./scripts/test.sh --shop-workshop`: passed, including localized Workshop tile names and hidden internal IDs.
- `./scripts/test.sh --battle-integration`: passed, including reaction feedback composed from localized technique and trigger labels.
- `./scripts/test.sh --stage4-accessibility`: passed; 960×540 pseudo-layout report records the 30% expansion checks and `critical_layout=CHECKED`, with no missing-key diagnostics.
- `./scripts/test.sh`: passed on the final follow-up source; full domain, simulation, Run progression, presentation, and Intent Graph suite. `/tmp/stage4-localization-issue93-final-full.log` contains the run; the error scan found no script, parse, load, localization-key, formatting, assertion, or suite failures.
- A direct trailing-whitespace scan passed for the nine follow-up source, catalog, test, and report files.
- `git diff --check`: passed through Windows Git against the registered linked worktree; no whitespace errors were reported.
