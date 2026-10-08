# RC6 starting tiles and Hand rules

Owner direction, 2026-10-07. These rules supersede earlier starter-size discussion and the 14-tile starter fixture. The remaining combat and Character mechanics are unchanged.

| Basic Character | Starting Run pool | Player choice |
|---|---|---|
| Sequence / 顺子师 | **68**: two of each of all 34 numbered and honor types | Select Character directly |
| Triple/Reserve / 藏牌师 | **72**: four of every rank in two numbered suits, no honors | Choose the one numbered suit to remove: Characters/万, Dots/筒, or Bamboo/条 |

The sequence pool replaces its old pool completely. The Reserve pool starts from the standard 136-tile composition and excludes one full numbered suit and all seven honor types. Every physical copy is a distinct Run-owned TileInstance. Existing Character techniques, passives, relics, and the locked third Character's pool retain their own behavior.

Every **fresh battle starts with 11 tiles in Hand**, dealt deterministically from the shuffled wall before the player's first action. The opening deal spends no normal Draw Action and triggers no normal-draw Pressure, Fatigue, or enemy turn. Tiny test-only pools may deal fewer if fewer tiles exist.

Battle-entry Effect draws count toward these 11 tiles, and the opening deal fills the remainder. Automatic entry Effects that would overfill the opening hand are skipped whole, while other legal entry Effects still run. This keeps the Sequence starter relic from producing a twelfth opening tile. Oversized saved Hands are rejected with `HAND_LIMIT_EXCEEDED`; their files and tiles are not rewritten or discarded.

The isolated Guided Sample uses authored wall prefixes drawn from the selected Character's actual pool, keeping its full composition and copy counts. Its opening 11 plus three draws demonstrate a Complete Hand within the 14-tile cap. Ordinary campaign encounters retain their shuffled wall order; the sample is instruction rather than balance evidence.

**Hand never exceeds 14 physical tiles.** Reserve is separate. Draws, effects, techniques, recovery, and zone transfers must enforce the same limit. A rejected draw or transfer must not lose tiles or spend a normal draw budget. Count-neutral swaps remain legal. Complete Hand interpretation remains structural; the current Hand limit prevents building an interpretation that requires more than 14 physical tiles.

Continue restores a saved battle's actual tiles and RNG; it does not redeal or reconstruct an old Run's pool. A saved Run at a nonbattle checkpoint keeps its pool and uses the new opening deal when entering its next fresh battle. The selected excluded suit is saved for new Reserve Runs; older saves have no such field and retain their original tiles. Legacy programmatic Reserve selection without a suit defaults to removing Characters; the player UI always asks for a suit.

RC6 changes deterministic gameplay rules. New replays use the mechanical identity `game.rules.rc6.v1`, separately from the existing save-envelope identity `game.phase2.v1`. Older replay records remain immutable and are reported unavailable before execution under the new rules. Old fixture hashes are retained as historical evidence; they do not establish unchanged battle outcomes after this rule change. Public 1.0.0 compatibility remains unapproved.

See [Project Specification](PROJECT_SPEC.md) §4 for the current rules and [Windows candidate notes](../docs/release/WINDOWS_RELEASE_NOTES.txt) for player-facing changes.
