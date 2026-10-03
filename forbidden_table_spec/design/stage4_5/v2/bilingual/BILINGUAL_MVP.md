# Bilingual MVP requirement and implementation gate

The user requested English and Chinese support for the first actual MVP release on 2026-10-01. The design assumption is **English (`en`) and Simplified Chinese (`zh_CN`)**. Traditional Chinese is outside this request; standard traditional Mahjong face glyphs are shared visual assets, not a third language.

This requirement expands presentation/localization scope. It preserves rules, Domain state, content budgets and Stage 5 **1.0 Release Candidate**. It does not authorize publication or cancel the instruction to obtain mockup approval before game UI implementation.

Design-baseline evidence (before implementation): `project.godot` registers only `res://localization/en.en.translation`; fallback is `en`. `localization/en.csv` contains 962 keys. The [inventory](source/runtime-key-inventory.csv) includes every key and records a source SHA-256 in [coverage](source/coverage.json). 79 exact English strings match proposed Chinese design copy; these still require contextual review. The other keys require translation after approval. No runtime resource or configuration was changed in this design session.

Implementation was approved on 2026-10-01. The table below records fresh automated runtime results; full commands, evidence and remaining review gates are in [the implementation record](../../../../STAGE_4_5_IMPLEMENTATION_RECORD.md). Implementation approval is not Stage 4.5 PASS or MVP release authorization.

## Language selection and fallback

- Use language autonyms **English / 简体中文**, always rendered with CJK coverage, without national flags. Expose the preference before starting a Run and through Help / Settings during a Run, after a Run, and during recovery.
- First launch uses the system language when it maps to a supported locale; otherwise English. A saved explicit preference takes precedence. Map supported Chinese language variants to Simplified Chinese only under a documented policy; never advertise Traditional Chinese support.
- Settings offers a selected language and a separately focused language. Choose using mouse, keyboard or controller, then **Apply language / 应用语言**. Back/Cancel dismisses an unconfirmed selection and restores the previous language and focus target.
- Applying changes text and locale-aware formatting at the same decision point, preserving tile instance selection, open detail, scroll position, focus destination and Run state. Persist the preference as presentation/profile configuration, not a gameplay command or new Run snapshot schema.
- Re-render visible labels, help, tooltips, disabled reasons, pending choices, receipts, errors and summaries. Keep an existing receipt in its original order; cancel purely cosmetic playback if needed and display the final text immediately. Never rerun accepted commands to translate their results.
- Missing translations fall back to the keyed English source and are diagnosable during development. An unsupported preference or corrupt preference file falls back safely. The release gate requires complete supported-locale coverage; fallback is recovery behavior, not permission to ship untranslated required copy.
- If preference persistence fails, preserve the active language for the current session, show a localized recoverable message, and allow retry or dismissal. Preserve the user's Run and save sources.

## Fonts and text contracts

Use full CJK font coverage for runtime Chinese, with locale typography roles matching the [Chinese design](README.md). The supplied offline SC fonts use the SIL Open Font License; see [provenance](fonts/README.md). A production subsetting strategy must retain all translated and dynamic characters, punctuation, symbols, Latin error codes, variable values and safe fallback fonts. Do not ship the earlier tile-only font as a general Chinese font.

Keep existing stable keys and Domain/content IDs. Add localizable preference/error labels at the existing localization seams after approval. Translate **all** player-facing UI, enemy intent, events, options, Contracts, Characters, Relics, Techniques, Rule Breakers, Modifiers, contamination, Yaku, tile names, help, tutorial, Shop, Workshop, saves and end states. Do not translate debug IDs, paths or placeholders. Keep `%s`/`%d`/`%f`/`%i`, order, escaping and literal `%%` compatible with existing formatting; use the English source validator's actual format contract.

## Required evidence before bilingual MVP release

| Gate | Acceptance evidence | Current status |
|---|---|---|
| Design approval | Maintainer explicitly approves V2.2 art, Chinese terms and language states, or specifies revisions. | Approved 2026-10-01; implemented-screen review pending |
| Catalog coverage | Every current runtime key has reviewed `en` and `zh_CN` values; no empty required translations, orphan keys or incompatible placeholders. Check newly added keys too. | Automated PASS: 1,106 keys per locale; placeholders/coverage clean. Maintainer wording review remains part of screen review. |
| Runtime setup | Godot imports/registers both catalogs, uses the intended fallback, and persists/loads a supported language preference. Fonts render all required glyphs without tofu. | PASS: resource import, saved/fallback locale and glyph coverage regressions. |
| Full journey | Fresh equivalent two-Act runs in both locales cover all critical screens, content rosters, recovery, rejected commands, victory/defeat and historical summaries. Numerical values, legality and identities match. | PASS: scripted/rendered two-Act critical journey and cross-locale checkpoint/replay/outcome comparisons; participant testing not performed. |
| Language switch | New Run, map, pending Pattern, duplicate Workshop target, event, confirmation, resolved receipt, summary and recovery retain state and meaningful focus; Cancel does not apply. Restart restores the preference; simulated persistence failure is recoverable. | PASS: pending selection/confirmation, receipt, summary/recovery and saved/cancelled preference regressions. |
| Input and layout | Mouse, keyboard and controller reach every action in both locales; focus/back/cancel remain correct. Verify the actual supported scales/viewports, longest localized strings and +30% pseudo-localization. | PASS: scripted keyboard/controller, actual mouse checks and 27-cell rendered layout matrix. Physical-device checks not performed. |
| Feedback | Normal/Fast/Instant and reduced motion retain the same ordered localized feedback; interruption and switching never duplicate commands or block critical input. | PASS: 57 critical cue states plus live tween, interruption/cancellation and single-command regressions. |
| Regression and release | Required focused/full gates pass with versioned before/after game captures; defects have dispositions. #98 and Stage 5 follow their existing review gates. | Automated focused/full gates and captures PASS; #98 implemented-screen review and Stage 5 release gate remain pending. |

The design-session browser/Figma evidence validates the design drawings and viewer, not these runtime acceptance gates. Runtime English/Simplified Chinese support now has automated and rendered evidence. Bilingual MVP publication still requires the existing implemented-screen and release decisions; no release is authorized by these checks.
