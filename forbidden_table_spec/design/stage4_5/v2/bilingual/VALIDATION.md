# Bilingual V2.2 design validation

**2026-10-01.** Evidence is for review drawings and the browser viewer. Game UI code, runtime locale registration, controller routing and bilingual MVP runtime gates have not been implemented or tested.

| Evidence | Result | Artifact |
|---|---|---|
| Full Chinese journey | 36 browser drawings, 960×540; no button/horizontal panel overflow; footer stays visible. | [Layout report](source/layout_checks.json) |
| Expansion / windows | 125% and 150% localized recovery samples pass; 1280×720, 1280×800 and 1920×1080 specimen captures exist. Larger specimens remain design targets. | [PNG directory](mockups/) |
| Figma Chinese page | 36 editable Chinese screens + 2 language settings; no reported button overflow; footer at 512. Chinese frame text uses verified SC families/styles. | [Native measurements](source/figma_checks.json) |
| Direct visual inspection | Chinese Character, native Battle and native language settings have readable text, standard tile faces and independent focus/selection. | [Native Battle](mockups/figma-battle.png), [Native Chinese settings](mockups/figma-language-zh.png) |
| Locale round trip | 中文 → English → 中文 preserves screen, mode, layout, reduced/ambient preferences and fixture tile identities/states; Workshop duplicate copy 2 retains its translated accessible label. | [Interaction report](source/interaction_checks.json) |
| Browser keyboard / English regression | Real Tab focus is 3px and visible; localized tile inspection works; 5 affected English screens have no button overflow; no page errors. | [Interaction report](source/interaction_checks.json) |
| Chinese choreography | 4 studies × 3 modes pass; ordered Chinese receipt stays present; reduced motion disables ambient and motion; Escape and cross-screen interruption cancel safely. | [Motion report](source/motion_checks.json), [Phase PNGs](motion/) |
| English choreography | Fresh 12-case regression passes after adding localized labels; existing mode values remain stable. | [English motion report](../source/motion_checks.json) |
| Mechanical fixture parity | Matching screen slugs, states, structure, tile identities and non-text values; only display text/labels differ. | [Package check](source/package_checks.json) |
| Offline Chinese fonts | All required CJK/fullwidth glyphs are present in each supplied SC font; browser font status is loaded, native family/style names verified. | [Package check](source/package_checks.json), [Font provenance](fonts/README.md) |
| Runtime key inventory | All 962 English keys included; source SHA matches; only 79 lexical matches to design copy, all requiring context review. Runtime localization remains incomplete. | [Coverage](source/coverage.json), [Inventory](source/runtime-key-inventory.csv) |

No runtime files, Domain rules, content roster, issue status or release-stage naming changed. Font coverage of the present review text does not substitute for coverage of a future complete runtime translation catalog. Native motion is the existing language-independent tile-arrival demonstration on the English V2 page; localized choreography is demonstrated and measured in the Chinese browser review.

Reproduce the review checks from the worktree root with a served gallery and an open Playwright CLI session:

```bash
python3 forbidden_table_spec/design/stage4_5/v2/source/capture_mockups.py /tmp/ft-playwright-cli.sh ft-bilingual zh_CN
python3 forbidden_table_spec/design/stage4_5/v2/source/capture_motion.py /tmp/ft-playwright-cli.sh ft-bilingual zh_CN
python3 forbidden_table_spec/design/stage4_5/v2/bilingual/source/capture_interactions.py /tmp/ft-playwright-cli.sh ft-bilingual
python3 forbidden_table_spec/design/stage4_5/v2/bilingual/source/check_bilingual.py
```

The first command captures the currently open Chinese gallery; the later commands navigate to their target pages. Run sequentially per browser session. `build_bilingual.py` regenerates design fixtures from the checked-in mapping and ledger without modifying runtime files; the English source strings and numeric fixture identities are preserved. Figma scripts are authoring provenance, not blindly replayable patch commands; inspect existing IDs and retry only after determining what changed.
