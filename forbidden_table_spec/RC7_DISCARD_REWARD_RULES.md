# RC7 discard and reward rules

Implements the owner-approved follow-up to RC6. Application version: `1.0.0-rc.7`; replay rules identity: `game.rules.rc7.v1`.

## Starting rules retained

Sequence has 68 physical tiles, two of each of the 34 types. Triple/Reserve removes the player's chosen numbered suit and all honors from the standard set, leaving 72 physical tiles. Every fresh battle starts with 11 Hand tiles; Hand never exceeds 14. Continue restores the existing pool, Hand, resources, and RNG without redealing.

## Battle discard

Discard moves a physical tile from Hand to the battle Discard zone; it does not permanently remove a Run-owned tile from the pool. A normal draw permits one discard, separately from the one Reserve/store/swap operation per draw. A full 14-tile Hand can discard before drawing, including at turn start. The exception releases capacity once; it cannot discard the rest of the Hand for free. Discard does not replenish normal draw budget, grant TP, resolve enemy intent, or silently select a tile. A legal completed Hand may still be settled at 14.

Optional discard advice considers only visible Hand tiles and legal scoring groups. Sequence favors useful numbered connections; Triple/Reserve protects pairs and triplet prospects. The player chooses whether and what to discard. Simulation uses the same scorer with separately versioned policy provenance; small simulation samples are diagnostic evidence, not a balance approval.

## Rewards

Ordinary Triple/Reserve tile acquisition stays within the two retained suits. Removed-suit tiles and honors require a clearly labeled **special pivot reward**. A generic `PIVOT` context bias does not authorize such an acquisition. Generation and command acceptance enforce this boundary. Existing fixed-target drafts remain compatible with their original semantics; newly generated drafts follow RC7.

Normal refinement rewards let the player choose an owned eligible tile type. One selection upgrades up to two physical copies, sorted deterministically by instance ID, subject to existing modifier limits. The picker lists actual eligible copies and quantity; a type choice executes directly without a second confirmation. If one copy qualifies, only that copy is improved. Pool size remains unchanged. Fixed-target legacy refinement rewards still affect their specified single instance.

Fresh Triple/Reserve already has four copies of each retained type, so normal offers provide two distinct eligible refinements and the existing resource option instead of forcing excluded tile additions. Sequence additions and reward weighting use actual pool composition and build permissions. Equal suit counts do not invent a dominant suit through a lexical tie-break. The ordinary four-copy limit remains in force.

Elite drafts retain their three build choices and resource option. When an excluded tile is eligible, a fifth, explicitly marked special pivot may be offered. The offer explains that it changes the starting profile. No extra confirmation is added.

## Workshop

`REMOVE_PAIR` permanently removes two owned physical copies of the selected type, with the selected copy and a deterministic eligible second copy. The preview shows both physical copies and modifiers, the exact price, and pool size before/after. Both copies and attached persistent modifiers are removed atomically; insufficient funds, fewer than two copies, or a resulting pool below 14 rejects the action without charging. Price is twice the effective single-removal price, including applicable discounts. The existing single-copy removal service remains available under its original behavior.

Successful refinements and removals show a passive visual receipt. Pool removal is distinct from battle discard. A batch transformation service is deferred; the implemented batch service is removal.

## Starter relic and compatibility

`base.relic.open_hand`, displayed as **Reserve preparation / 备牌准备**, now grants +1 Reserve capacity at battle entry. It no longer consumes wall tiles merely to produce the fixed 11-tile opening Hand. It does not auto-store a tile or increase Hand size. Other draw effects retain their existing rules. An already saved battle restores its serialized current capacity; future battle entries apply the new relic effect.

The save envelope identity remains `game.phase2.v1`; new optional state fields preserve legacy serialization when absent. Reward target type is serialized in new commands only when present. Old replay records are immutable and unavailable under the changed RC7 mechanics. Historical replay hashes and corpus results are not regenerated or described as current-rule certification.

## Verification boundary

Regression gates exercise authoritative commands, reward target UI, Workshop receipts, save/restore and replay, plus window-size and language/scale layouts. Packaged validation mounts the exported PCK from an isolated extracted directory. Headless layout checks do not establish native GM116 play quality, Windows 10 behavior, or complete two-Act balance. Those remain separate release checks.
