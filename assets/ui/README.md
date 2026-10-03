# UI asset attribution

These runtime copies support the approved Stage 4.5 V2.2 presentation. Their source review package remains under `forbidden_table_spec/design/stage4_5/`.

## Generated artwork

- `art/haunted-salon.png` and `art/character-triptych.png` were generated with the built-in image-generation tool on 2026-10-01 and uploaded to the approved V2.2 Figma copy. No external reference artwork or paid image service was used. The Character portraits depict cosmetic concepts for existing Characters; they add no rules, lore, unlocks, or rewards.

## Mahjong faces

- `tiles/chinese-tiles/` contains the 34 unmodified PNG faces from [zddd312/mahjong-tiles](https://github.com/zddd312/mahjong-tiles), pinned to commit [`7629eeeba620ba9f0a98907bc40c0776523af989`](https://github.com/zddd312/mahjong-tiles/tree/7629eeeba620ba9f0a98907bc40c0776523af989).
- The upstream M+ font license is copied as `tiles/chinese-tiles/LICENSE`. The source, contributor attribution, identity mapping, and per-file SHA-256 values are recorded in the adjacent `README.md` and `manifest.json`.
- Faces are displayed with contain scaling. The runtime copy preserves the original files, including the 271-pixel-wide `3p.png` and `3s.png` variants.

## English fonts

- `fonts/NotoSans-Regular.ttf`, `fonts/NotoSans-SemiBold.ttf`, and `fonts/NotoSerif-Regular.ttf` come from the official `notofonts/noto-fonts` repository's `hinted/ttf/` files, copied from the approved V2 package on 2026-10-01.
- The SIL Open Font License is copied as `fonts/OFL.txt`. Preserve the font copyright and license when redistributing these assets.

## Simplified Chinese fonts

- `fonts/NotoSansSC-Regular.otf`, `fonts/NotoSansSC-Medium.otf`, and `fonts/NotoSerifSC-Regular.otf` are unmodified SC fonts from `notofonts/noto-cjk`, pinned to commit `f8d157532fbfaeda587e826d4cd5b21a49186f7c`.
- Source paths and original licenses are documented in [the bilingual font provenance](../../forbidden_table_spec/design/stage4_5/v2/bilingual/fonts/README.md). The Sans and Serif licenses are retained here as `fonts/OFL-Sans.txt` and `fonts/OFL-Serif.txt`.
- These full SC files provide body, controls, headings, punctuation and dynamic content coverage in the actual game. The bilingual design package's earlier statement that no runtime import was included applies to the design session only.
