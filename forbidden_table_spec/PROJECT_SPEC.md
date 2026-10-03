# Mahjong Roguelike — Project Specification v1.0-draft

> Status: Design grilling complete (Q1–Q140 locked)
> Engine target: Godot 4.x stable, exact minor version to be pinned at implementation kickoff
> Launch platform: PC first; Mouse/Keyboard + Controller/Steam Deck navigation from the start
> Genre: Single-player Roguelike deck/pool-builder where Mahjong is the construction language and combat is the output layer

---

## 1. Product Vision

### 1.1 One-sentence pitch
Build a personal Mahjong tile pool, draw and reshape hands under pressure, settle completed Mahjong structures into combat effects, and progressively bend or break table rules through Roguelike upgrades.

### 1.2 Design pillars

1. **Mahjong is the construction language; combat is the output.** The player thinks in tiles, groups, Yaku and hand structure rather than ordinary attack cards.
2. **Respect the rules first, exploit them second, break them last.** Early play teaches recognizable Mahjong grammar; mid-run builds bend probabilities and conversion; late-run Rule Breakers alter selected table laws.
3. **Partial cash-out versus long-horizon greed is the central tactical tension.** Partial Settlement gives value now; Yaku/Complete Hand rewards patience and risk.
4. **Probability should be manipulated, not eliminated.** Pool refinement improves consistency but never turns the game into a deterministic combo editor.
5. **The player should not need prior Mahjong expertise.** The game teaches only the rules it actually uses.
6. **Complexity comes from interactions, not bespoke text on every object.** Base tiles are simple; builds emerge from Yaku, Relics, Techniques, Tile Modifiers, Character identity, Contracts and Rule Breakers.
7. **Deterministic resolution after the decision.** Randomness mainly determines what opportunities appear; once a Settlement is committed, the core result is reliable.
8. **Domain truth is independent of presentation.** The game must remain testable, replayable and simulatable without Scene/UI dependencies.

### 1.3 Tone and presentation
The world is a **supernatural Mahjong table**: strong atmosphere, light narrative, rules-as-worldbuilding. Enemies, Bosses, Contracts, Relics, contamination and table phases are framed as abnormal table phenomena rather than a dialogue-heavy RPG campaign.

Visual priority:

`Readability > state clarity > tile recognition > animation feedback > decoration`

Mahjong suit/honor recognition must never be sacrificed for style.

---

## 2. Core Run Loop

A full 1.0 run targets roughly **60–90 minutes**.

High-level loop:

`Choose Character → Choose Contract → Traverse branching map → Fight / Event / Shop / Workshop / Elite → Build evolves → Act Boss → optional Final Act conditions → Run end summary`

### 2.1 Act structure

- **Act 1:** establish engine and learn the run's strategic direction.
- **Act 2:** main boss and Normal Ending.
- **Optional Act 3 / Final Table:** unlocked by run conditions for true/final ending content.
- Exact true-ending requirements remain content tuning, not a core rule dependency.

### 2.2 Branching map

Slay-the-Spire-like node graph, not an explorable dungeon.

Node families:

- Normal Battle
- Elite
- Shop
- Workshop
- Event
- Treasure / special reward
- Recovery/Rest equivalent only if it serves non-HP systems
- Boss

Map topology is visible, while distant node identities may be partially hidden. Scouting/reveal can be modified by builds and events.

### 2.3 Economy

- **Gold:** unified normal run currency shared by Shop and Workshop, forcing opportunity cost.
- **Refinement Token** (working name): rare currency for high-tier rule-breaking refinement, primarily from Elite/Boss/high-risk content.

Shop and Workshop are intentionally distinct:

- **Shop:** acquire new build pieces (Relics, Techniques, special offers).
- **Workshop:** refine owned Tile Pool (Remove, Transform, Modifier, Duplicate, special refinement).

---

## 3. Mahjong Ruleset

The project uses a curated **Mahjong Roguelike Ruleset**, not a complete traditional multiplayer ruleset.

### 3.1 Tile identity foundation

Use traditional 136-tile identities as the root vocabulary:

- Characters/Manzu
- Dots/Pinzu
- Bamboo/Souzu
- Winds
- Dragons

Default copy limit: **4 TileInstances per TileDefinition**, breakable by explicit effects.

### 3.2 Excluded multiplayer rules

Do not implement traditional multiplayer-context rules unless deliberately reinvented for this game. Examples excluded from the base game:

- Furiten
- Ron/Tsumo distinction
- seat/round wind machinery
- dealer rotation
- Riichi-stick economy
- dead-wall/Kan draw machinery

### 3.3 Base Pattern grammar

Scoring Patterns:

- **Sequence:** same suit, three consecutive ranks.
- **Triplet:** three identical TileDefinitions.
- **Quad:** four identical TileDefinitions; treated as an enhanced Scoring Pattern.

Non-settleable structural Pattern:

- **Pair:** two identical TileDefinitions.

Base Complete Hand:

- **Standard:** 4 Groups + 1 Pair, where Group = Sequence | Triplet | Quad.
- **Seven Pairs:** 7 distinct TileDefinition pairs.

A Quad can increase physical tile count beyond the normal 14-tile shape. Therefore Complete Hand evaluation is structural and must never be coded as `hand.size() == 14`.

Seven Pairs rule: four identical tiles count as one pair by default, not two; Rule Breakers may override.

### 3.4 Pattern interpretation

A TileInstance has a stable base identity but may have contextual flexible identities under explicit modifiers.

Examples:

- Adjacent-rank flexibility only for Sequence evaluation.
- Prismatic suit flexibility only for Sequence evaluation.

Identity flexibility must be evaluated through context, e.g. conceptually:

`get_valid_identities(tile, evaluation_context)`

Patterns are not permanently locked while drawing. They lock only when Settled, used by an explicit Technique, or committed in a Complete Hand interpretation.

If multiple legal interpretations exist:

- auto-resolve when strategically equivalent;
- ask the player only when Score, Yaku, consumed TileInstances, triggers or downstream state differs;
- offer a recommendation but preserve player agency.

Domain concepts:

`PatternCandidate → PatternSelection → SettledPattern`

---

## 4. Tile Pool, Zones and Tile Lifetimes

### 4.1 Personal Tile Pool

The run uses a **personal Tile Pool**, not a full shared 136-tile wall. It is the player's buildable probability space.

Early starter size around 50–60 was discussed but is **not locked**. Balance testing will decide initial sizes.

Run-level pool has:

- configurable `MinimumPoolSize`; initial balance target roughly 36–40;
- no practical normal hard maximum; oversized pools naturally dilute consistency;
- default 4-copy limit per TileDefinition.

### 4.2 Battle zones

Core zones:

- Draw Wall
- Hand
- Reserve
- Discard
- Exhaust
- Purged (logical removed-from-battle result; may not need a visible pile)

### 4.3 Zone semantics

- **Discard:** remains in normal battle circulation.
- **Exhaust:** leaves circulation for this battle, but remains part of CombatState and may be recovered by explicit effects.
- **Purge:** leaves the current battle completely and is not recoverable by ordinary Exhaust recovery.
- **Remove:** permanent Run-level deletion from Tile Pool.

Run-owned tiles Purged during battle still exist in RunState and return in the next battle. Battle-only contamination Purged during battle is fully gone for that battle.

### 4.4 Battle Active Floor

Battle Exhaust/Purge may reduce active tile count below run-level `MinimumPoolSize`, but normal effects are constrained by a separate `BattleActiveFloor`, derived approximately from Normal Hand Baseline + safety buffer.

Only explicit high-permission Rule Breakers may violate this safety floor.

---

## 5. Draw, Turn and Settlement State Machine

### 5.1 Draw Actions

Default concept: roughly 3 Draw Actions per turn, balance-tunable.

A normal Draw Action must draw 1 from Draw Wall unless an explicit effect converts/replaces the action.

Normal Draw Action structure:

1. Draw
2. Manipulation
3. Settlement Checkpoint
4. Optional Settlement Window
5. Hand Normalization
6. Draw Action End

During Manipulation, the player may normally perform at most one Reserve operation per Draw Action.

The player can End Turn early. Unused Draw Actions vanish by default and provide no free compensation unless a build explicitly reads them.

### 5.2 Draw Sources

Use explicit `DrawSource` values so trigger semantics remain stable:

- `NORMAL_ACTION`
- `SETTLEMENT_REPLACEMENT`
- `COMPLETE_HAND_REBUILD`
- `TECHNIQUE`
- `EFFECT`

Replacement/Rebuild draws do not automatically trigger every normal-draw effect.

### 5.3 Draw Wall exhaustion and Fatigue

When Draw Wall is empty, reshuffle Discard and increase **Fatigue** by 1.

Fatigue is battle-duration escalation, primarily increasing later Pressure generation. Exact formulas remain tunable.

If Draw Wall + Discard cannot satisfy a draw request, enter **Starvation** rather than immediate defeat.

`DrawResult { requested, drawn, shortfall }`

Starvation causes draw shortfall plus rapidly escalating Pressure consequences, but the player may still act with existing Hand, Techniques or Settlement to recover.

### 5.4 Settlement Checkpoints and Windows

Settlement is player-triggered, not forced every turn.

At a Settlement Checkpoint, the player may open one Settlement Window.

A Settlement Window resolves one Pattern at a time:

`Select → Resolve → Triggers → Replacement Draw → Re-evaluate → next selection`

The full Window shares one Settlement Capacity budget.

Replacement Draw can create additional Patterns and continue the chain, but does not refresh capacity.

### 5.5 Settlement Capacity

Settlement Capacity = maximum number of Scoring Patterns that may be settled in one Settlement Window.

Baseline concept around 2, but numeric tuning remains open.

The same TileInstance cannot normally belong to multiple settled groups in one window unless an explicit Rule Breaker permits it.

---

## 6. Partial Settlement and Complete Hand

### 6.1 Partial Settlement

Consumes selected completed Scoring Patterns and converts them into Mahjong Score, then Combat Output.

Settled tiles normally go to Discard, but effects may override destination to Exhaust, Draw Wall top/bottom, etc.

After consumption, **Replacement Draws** restore Hand toward the normal baseline without spending Draw Actions.

### 6.2 Complete Hand Settlement

A Complete Hand is a climactic whole-hand settlement:

- detects valid structural interpretation;
- resolves compatible Hand Yaku;
- creates a large score/payoff;
- provides a strong Stability component;
- performs a special hand rebuild;
- enters Recovery state.

It is powerful but not mandatory for every build.

### 6.3 Complete Hand rebuild and Recovery

After Complete Hand:

- Reserve persists.
- Settled Hand tiles follow normal destination policy (base Discard).
- Rebuild draws to a **Recovery Baseline**, conceptually around 9–11 if normal baseline is ~13, but exact values remain tunable.
- Reserve receives limited recovery/repair.
- Exhaust is not automatically recovered.

Recovery ends only when:

1. at least one Recovery Turn has elapsed (default tunable), and
2. Hand has returned to the Normal Hand Baseline.

During Recovery, normal Draw, Reserve use, Techniques, Partial Settlement, Local Yaku and combat conversion remain legal. Only another Complete Hand Settlement is locked.

---

## 7. Reserve and Integrity

### 7.1 Reserve purpose

Reserve holds non-immediate assets for long-horizon planning. It is not free extra Hand.

Base capacity: **3**, modifiable by builds.

Formal Yaku Progress and Complete Hand evaluation use Hand only by default. Reserve can contribute to **Potential Yaku Progress** in UI, while rare Rule Breakers may allow limited official participation.

### 7.2 Reserve operations

Base Reserve operation is part of a normal Draw Action's manipulation step.

Supported base operations:

- normal discard
- store Hand tile into Reserve
- atomic swap between Hand and Reserve

Base Swap is strict atomic `Hand Tile A ↔ Reserve Tile B`.

The swapped-in tile becomes immediately usable and may settle during the same Draw Action.

### 7.3 Integrity

TileInstances that enter Reserve have battle-runtime **Integrity**.

Integrity loss sources:

- natural time decay;
- active Reserve manipulation wear;
- enemy Integrity damage.

Natural decay happens once per full Turn Cycle after Enemy Main Intent, during End-of-Turn Resolution.

Break policy:

- Natural Decay to 0 → Discard.
- Active player Reserve use causing 0 → Exhaust.
- Normal enemy Integrity damage causing 0 → Discard.
- Elite/Boss effects may explicitly set `BreakPolicy = EXHAUST`.

`IntegrityLoss { amount, cause, break_policy }`

Integrity is TileInstance battle-runtime state. Leaving and re-entering Reserve in the same battle does not automatically refresh it. First Reserve entry initializes it; explicit repair effects may restore it.

Battle end resets Integrity runtime state unless a rare Run-level effect explicitly creates persistent damage.

---

## 8. Yaku and Build Objectives

### 8.1 Yaku philosophy

Yaku are **Build Objectives + Rule Modifiers**, not only score multipliers.

Use a curated catalog rather than a complete traditional ruleset.

1.0 target: roughly **24 Yaku** (20–28 acceptable budget).

Suggested families:

- Structural: ~8
- Suit/Honor: ~6
- Special Complete Hand: ~4–5
- Roguelike-original structural Yaku: ~5–6

Original Yaku must still care about Mahjong structure rather than arbitrary actions like “used 3 Techniques.”

### 8.2 Scope

`YakuDefinition.scope`:

- `LOCAL_SETTLEMENT`
- `COMPLETE_HAND`
- `BOTH`

Local Yaku can boost current Partial Settlement. Hand Yaku formally pay on Complete Hand.

### 8.3 Yaku Progress

Yaku Progress is current-state, real-time closeness, not historical memory.

Partial Settlement may lower it because tiles are consumed.

Each Yaku defines its own structured progress model rather than a universal fake percentage.

`YakuProgressResult` may expose:

- stage
- normalized internal score (optional)
- satisfied conditions
- missing conditions
- blockers
- Reserve potential
- display tokens

UI shows discrete stage/gaps rather than misleading universal percentages.

### 8.4 Yaku Momentum

Separate optional historical resource: **Yaku Momentum**.

Builds may generate Momentum from aligned actions and spend it later. It is explicitly distinct from Yaku Progress.

---

## 9. Mahjong Score

### 9.1 Scoring separation

Tiles and structures produce **Mahjong Score**. Mahjong Score is then converted to combat effects.

`Tiles → Patterns → Yaku / Score Contributions → Final Mahjong Score → Combat Conversion`

Mahjong Score is a build-performance/fantasy layer; combat values are the balance layer.

### 9.2 Unified resolver

All scoring goes through `MahjongScoreResolver`.

Stable pipeline:

`Base Contributions → Flat Additions → Additive % → Multipliers → Overrides/Caps/Floors → Final Rounding`

`MahjongScoreResult` preserves full breakdown:

- contributions
- flat bonuses
- additive modifiers
- multiplicative modifiers
- pre-cap value
- final value
- applied special rules

`ScoreContribution` includes:

- source_id
- amount
- tags
- metadata/conversion modifiers

Example tags:

- SEQUENCE
- TRIPLET
- QUAD
- LOCAL_YAKU
- COMPLETE_YAKU
- HONOR
- SUIT
- SEVEN_PAIRS

Ordinary content should prefer flat/additive/contribution/conversion modifiers. Independent multipliers should be rarer and mostly reserved for high-tier Yaku, Rare effects, Complete Hand and Rule Breakers.

### 9.3 Score growth policy

Mahjong Score may grow dramatically and has no ordinary gameplay hard cap.

Do not suppress visible “big hand” scores merely to protect combat balance.

A very high technical ceiling may exist only for overflow/bug safety.

---

## 10. Combat Model

### 10.1 No player HP

The player has no conventional HP bar.

Failure meter: **Pressure**.

Pressure resets each battle. If effective Pressure reaches/exceeds Pressure Limit after resolution and state-based checks, the battle is lost.

Long-term Run attrition is therefore expressed through build/economy/map choices rather than HP loss.

### 10.2 Pressure timing

If Pressure reaches the Limit during an atomic effect chain:

- mark `pending_defeat`;
- finish the current Resolution Queue;
- then run State-Based Checks;
- do not grant new free player choices after lethal threshold except already-defined legal Reaction Windows.

Pressure Limit is stable by default. High-visibility Elite/Boss/Curse/Contract/Rule Breaker effects may modify it explicitly.

Lowering the Limit below current Pressure enters the same pending-defeat logic.

### 10.3 Enemy HP and pending death

Enemy HP remains the enemy failure axis.

When enemy HP reaches 0:

- mark `pending_death`;
- finish the current Resolution Queue;
- run State-Based Checks.

Boss phase HP reaching 0 transitions phase if phases remain; only final phase produces Victory.

If pending Victory and pending Defeat are both created in one queue, compare causal `terminal_sequence_index`; earlier terminal condition wins. Exact same atomic-effect tie → **Defeat wins**.

### 10.4 Damage and Stability

Combat conversion produces channels, primarily:

- **Damage:** progresses enemy defeat.
- **Stability:** directly reduces existing Pressure, minimum 0.

Future Pressure prevention uses a separate temporary Guard/Protection effect rather than a permanent second defensive bar.

Overstability is normally lost, but special builds may convert it into Damage, Guard, Momentum, etc.

---

## 11. Combat Conversion

### 11.1 Build-driven profile

The player does not manually allocate score every Settlement.

A resolved `CombatConversionProfile` is built from explicit priority layers such as:

`Base → Character → Contract → Relic/Technique/Yaku → temporary effects → Rule Breaker`

Score contributions retain tags so different sources can convert differently where required.

### 11.2 Separate channel curves

Damage and Stability share one Combat Conversion framework and the same Mahjong Score, but use different conversion curves.

- Damage retains a longer growth range.
- Stability enters diminishing returns earlier due to the smaller Pressure scale.

Conceptual form:

`Damage = DamageCurve(score_share)`

`Stability = StabilityCurve(score_share)`

Exact formulas remain tuning work.

### 11.3 Deterministic result policy

Core Combat Conversion is deterministic.

No default ±10% damage roll or generic critical chance.

Only effects explicitly labeled random may use gameplay RNG, and Preview must expose known uncertainty ranges/outcomes.

Randomness happens primarily in opportunity generation, not in the value of a settled decision.

---

## 12. Techniques and TP

### 12.1 TP

Technique Points are separate from Draw Actions.

- small baseline income per turn;
- Mahjong Milestones can generate additional TP;
- ordinary Partial Settlement does not automatically refund TP;
- partial carry across turns with a soft cap/decay and hard cap;
- cleared at Battle End.

Exact values remain tunable.

Milestone examples:

- first Sequence/Triplet/Quad
- Yaku Progress threshold
- first Complete Hand

### 12.2 Technique loadout

- 1 fixed Character Core Technique
- approximately 2 replaceable Run Technique slots conceptually

Technique usage types:

- `ACTIVE`
- `SETTLEMENT`
- `REACTION`

Core Technique is Character-specific and normally cannot be replaced.

Techniques manipulate Mahjong/table state rather than becoming a second direct-damage card deck.

### 12.3 Reactions

No free universal interrupt system.

Rare `REACTION` Techniques define explicit trigger and response windows. Reaction repetition must be finite (TP and, for strong effects, charges such as 1/Battle).

---

## 13. Enemies, Intent and Bosses

### 13.1 Encounter shape

Default battle: one primary enemy.

Elite/Boss/special encounters may use Support Entities or multiple targets. Architecture uses `CombatEntity[]` but multi-target combat is not the default baseline.

### 13.2 Intent timing

Enemy normally performs **one Main Intent per Turn**, after all player Draw Actions and End Turn.

Enemies may also own action-sensitive Countdown/Triggers during the player's turn.

Three time scales:

- Action-level triggers
- Turn-level Main Intent
- Battle-level Pressure/Fatigue escalation

More Draw Actions must not grant the enemy extra turns.

### 13.3 Intent model

Enemy behavior is a learnable, data-driven `Intent State Machine / Intent Graph`.

Transition types:

- `FIXED`
- `CONDITIONAL`
- `WEIGHTED`

Large structure should be learnable; local weighted variation is allowed.

Enemy AI may read public Battle State but must not cheat by inspecting hidden Draw Wall order or future rewards.

Intent visibility:

- normal enemies: generally fully visible next Intent;
- specialized enemies: category or partially obscured information;
- Boss/status effects: may hide/fuzz Intents as explicit mechanics.

### 13.4 Enemy design grammar

Normal enemy: one clear Mahjong-interference identity + a small 2–4 step intent pattern.

Elite: ~2 interacting mechanisms.

Boss: multi-phase Table Rules.

Potential interference mechanisms:

- Pressure ramp
- Reserve Integrity attack
- Discard pollution
- Draw Action suppression
- TP tax
- Settlement punishment
- Complete Hand punishment
- Fatigue acceleration
- Yaku disruption
- information hiding
- Tile Seal
- conversion distortion

### 13.5 Boss phases

Boss = multi-stage **Table Phases**, each modifying a limited subset of table rules.

Phase transitions preserve:

- Hand
- Reserve
- tile runtime state
- Fatigue
- limited TP according to rules

They partially relieve Pressure and reset phase-specific Intent/short-term state.

This remains one continuous battle rather than separate encounters.

---

## 14. Contamination

### 14.1 Battle-only contamination

Enemies may inject **Battle-only Contamination Tiles** into Draw Wall/Hand/Discard/etc.

These are real tiles in battle circulation and can affect draw probability, hand space, reshuffle and Fatigue.

They are not permanent Run Pool changes by default and do not count toward Run-level copy limit.

Normal enemies must not silently inflict permanent deck/pool pollution.

Permanent Curse Tiles are reserved for explicit high-risk Event/Contract/Boss consequences.

### 14.2 Build interaction

Base Contamination is negative and does not participate in normal Pattern/Complete Hand evaluation.

A limited number of Relics/Techniques/Yaku/Rule Breakers may explicitly:

- reward cleaning;
- tolerate contamination;
- convert contamination into value;
- grant constrained identity participation.

Do not create a second full “contamination Mahjong” ruleset.

### 14.3 Cleanse, Exhaust and Purge

- Generic Exhaust can target contamination; it remains recoverable from Exhaust.
- Dedicated Cleanse usually performs `Purge`, making it unavailable for the rest of the battle.
- Battle End lifecycle cleanup removes battle-only contamination without firing gameplay OnPurge/OnExhaust reward triggers.

`Purge` is a general low-level operation. Ordinary run-owned tiles may be Purged only through rare, high-impact effects and still obey `BattleActiveFloor` unless explicitly bypassed.

---

## 15. Characters, Contracts and Rule Breakers

### 15.1 Characters

1.0 target: **3 Characters**.

Planned role identities:

1. beginner/general/Sequence-oriented
2. Triplet/Partial Engine/burst
3. Reserve/Yaku planning

Character provides limited asymmetry:

- starting Tile Pool bias
- Starting Relic
- Core Technique
- Signature Passive/Rule

Characters do not rewrite base Mahjong grammar.

### 15.2 Contracts

Run start:

`Choose Character → Choose one Origin/Contract → Act 1`

1.0 target: **8 high-distinction Contracts**.

Contract = medium-strength Risk/Reward + Build Bias, typically an explicit tradeoff.

Possible axes:

- Pressure
- TP
- Reserve
- pool composition
- reward quality
- map/elite risk
- refinement economy
- information/scouting

Character = what I am good at.
Contract = risk I take.
Run Build = what I become.
Rule Breaker = rules I alter.

### 15.3 Boss Rule Breakers

Boss Rewards are high-impact Rule Breakers, usually a 3-choice draft.

Axes include:

- copy limit
- Settlement Capacity
- Reserve rules
- Complete Hand rules
- TP carry
- Yaku interaction
- Draw Actions

1.0 target: ~10–12 Rule Breakers.

---

## 16. Relics, Tile Modifiers and Content Targets

### 16.1 Relics

1.0 target ~50 normal Relics:

- ~20 Standard
- ~18 Specialized
- ~12 Rare

Relics are primarily passive. Active Relics are uncommon and should remain a small minority.

### 16.2 Tile Modifiers

1.0 target: ~12–16, center ~14.

Default maximum: **1 permanent Modifier per TileInstance**, with explicit exceptions.

Categories:

- identity/pattern
- Reserve/Integrity
- Settlement/destination
- Draw/recycling

Important distinction:

- **Transform:** changes what the tile is (`TileDefinition`).
- **Modifier:** changes how the tile participates.
- **Rule Breaker:** changes table rules.

### 16.3 Techniques

1.0 target:

- ~21 obtainable Run Techniques
- 3 Character Core Techniques

Suggested distribution:

- ACTIVE ~10
- SETTLEMENT ~6
- REACTION ~5

### 16.4 Enemies and events

1.0 target:

- ~14 Normal enemies
- ~6 Elites
- ~4 Bosses
- ~24 Events

Events mostly provide systemic trades and risk choices, not generic +Gold text.

Suggested event families:

- Tile Surgery/Refinement ~6
- Risk/Reward Bargain ~5
- Economy ~4
- Contract/Run Modifier ~3
- Info/Map ~3
- Rare Rule/Narrative ~3

---

## 17. Rewards, Shop and Workshop

### 17.1 Battle rewards

Normal Tile Reward = **Context-Biased Reward Draft**, conceptually ~3 options.

Draft should consider:

- current Tile Pool
- Yaku direction
- Relics
- copy limit

But must preserve synergy / neutral / pivot choices rather than auto-completing the build.

Skip is always available, with small compensation possible.

### 17.2 Acquisition vs refinement

Normal battles mainly provide acquisition:

- Add Tile
- Modified Tile
- Skip

Refinement primarily belongs to Workshop/special nodes:

- Remove
- Transform
- Duplicate
- Add/Replace Modifier
- break copy limit under special conditions

Removing tiles becomes increasingly costly/limited as the pool approaches its minimum.

### 17.3 Shop

Target ~5–6 offers.

- limited base refresh, conceptually ~1;
- refresh only unpurchased offers;
- purchased slots remain SOLD;
- context bias may influence offers while preserving pivot/neutral options.

### 17.4 Workshop

Stable services, no random refresh:

- Remove
- Transform
- Add/Replace Modifier
- Duplicate
- Special Refinement

Constrained by Gold, Tokens and service availability.

---

## 18. Information, Preview and UX

### 18.1 Tile information model

Base rule: **Composition Known, Order Hidden**.

The player can know their full Tile Pool and visible zones and infer remaining Draw Wall composition. Exact Draw Wall order is hidden unless revealed/scouted.

Separate:

- `ActualDrawWallState`
- `PlayerKnowledgeState`

UI may only use player knowledge.

### 18.2 Hinting

Contextual Smart Highlight:

- completed Scoring Patterns: clear highlight;
- near-complete groups: subtle;
- Yaku-relevant tiles: small cues;
- stronger highlighting in Settlement/Discard/Reserve/Yaku-specific views.

Assist levels:

- Minimal
- Standard
- Detailed

Evaluator truth and hint display must remain separate systems.

### 18.3 Action Preview

Default preview is deterministic immediate-consequence preview, not an optimal-strategy solver.

Preview should show:

- Pattern/Yaku consequences
- resource/zone changes
- predicted Mahjong Score
- converted combat output
- Integrity changes
- warnings
- known random ranges where an explicit random effect applies

Do not show “best discard win rate” by default.

Conceptual API:

`ActionPreviewService.preview(command, snapshot) → PreviewResult`

Preview simulates on a cloned/snapshot Domain State rather than mutating live state and undoing it.

---

## 19. Tutorial and Accessibility Direction

### 19.1 Progressive onboarding

Tutorial is embedded into the first real Run.

Teach in layers:

1. Draw / Sequence / Triplet / Partial Settlement / Damage
2. TP + Core Technique
3. Reserve + Integrity
4. Yaku Progress + Complete Hand
5. later Act 1: Contamination, advanced interference, Rule Breaker concepts

Tutorial uses the real CombatEngine and real rules; only content complexity and UI guidance are constrained.

Persist `TutorialProgress` separately from Assist Level.

Player may reset/disable tutorials.

### 19.2 Mahjong teaching scope

Teach only the game's rules:

- Sequence
- Triplet
- Quad
- Pair
- Complete Hand
- curated Yaku

Do not teach traditional multiplayer rules absent from the game.

### 19.3 Input baseline

PC first.

Support from the start:

- Mouse/Keyboard
- Controller / Steam Deck-style focus navigation

Critical actions must never require drag-only input. Dragging may be an optional shortcut.

Mobile/touch is not a 1.0 architecture constraint.

---

## 20. Meta Progression

Meta progression is **horizontal unlock**, not permanent generic stat inflation.

Unlockable categories:

- Characters
- Contracts
- Techniques
- Relics
- Tile Modifiers
- Events
- Bosses
- Yaku
- difficulty/mutators

Unlock conditions should teach or showcase mechanics where possible.

Track distinct states:

- discovered
- unlocked
- progress

Default Battle Defeat = Run Over, with explicit Defeat Prevention available only from rare content. Free permanent revive inflation is excluded.

---

## 21. Run End Summary and Records

Player-facing Run Summary should tell the **Build Story**:

- result
- Character + Contract
- Acts/Boss progress
- final Tile Pool
- core Yaku
- Relics
- Techniques
- Rule Breakers
- common Patterns
- Complete Hand count
- maximum Mahjong Score
- meaningful milestones
- Seed
- duration

Backend `RunRecord` keeps richer debug/replay information:

- seed

Duration is derived from the Run's recorded start time when available. A save
without a recorded start time reports duration as not tracked instead of
inventing a value. Older terminal summaries also mark absent Yaku, Pattern,
Complete Hand, maximum score, milestone, and Boss-progress data as not tracked;
the final pool and owned build are read from the saved Run state when present.
- content version
- result
- map path
- encounter history
- final build snapshot
- unlocks
- stats
- replay/debug metadata

---

## 22. Deterministic RNG

Same Run Seed + same accepted Commands + same content version should produce the same gameplay result.

Use domain-separated RNG streams such as:

- Map
- Reward
- Shop
- Event
- Combat
- DrawWall
- Enemy
- Cosmetic

Cosmetic RNG must be isolated from gameplay RNG.

Random draw/intent outcomes come from the appropriate stream, not from Command payloads.

Replay/debug systems may record observed results for verification, but authoritative replay is Command + RNG-state based.

---

## 23. Save, Suspend and Replay

### 23.1 Suspend Save

Use a single automatic **Suspend Save** for continuation, not rollback.

Only save at stable boundaries, e.g.:

- Map node
- Battle start
- Turn start
- Draw Action boundary
- after complete Settlement Window
- after full Enemy Intent resolution
- stable Shop/Workshop state
- Event choice before/after

Never save mid Effect Queue, Reaction Window, Pattern resolution or Boss transition.

Reload restores the exact RNG states so quitting cannot reroll future results.

### 23.2 Persistence schema

Runtime objects and persistence format are separate.

Use explicit DTO/Snapshot schemas with:

- `schema_version`
- `game_version`
- `content_version`
- `save_kind`
- Run/Combat snapshots
- RNG states
- checkpoint metadata

Load pipeline:

`Parse DTO → Migrate → Validate → Resolve Content IDs → Reconstruct Domain State`

Migrations advance sequentially (`v2→v3→v4`) rather than maintaining every pairwise conversion.

### 23.3 Distinct records

Keep separate models for:

- SuspendSnapshot
- RunRecord
- ReplayRecord
- MetaProgressSnapshot
- Settings

### 23.4 Replay

Replay logs accepted player Commands with stable IDs, never UI indexes.

Pattern selection records tile_instance_ids + interpretation_id.

Checkpoint state hashes should be available for deterministic divergence debugging.

---

## 24. Godot Architecture

### 24.1 Static content vs runtime state

Static editable content uses immutable/near-immutable Godot `Resource` definitions:

- TileDefinition
- YakuDefinition
- RelicDefinition
- TechniqueDefinition
- EnemyDefinition
- CharacterDefinition
- ContractDefinition
- TileModifierDefinition
- RuleBreakerDefinition
- Effect definitions

Runtime state uses plain typed runtime objects/data:

- TileInstance
- CombatState
- RunState
- EnemyRuntimeState
- ActiveEffectInstance
- RecoveryState
- PlayerKnowledgeState

Never mutate shared Definition Resources during gameplay.

### 24.2 Stable Content IDs

All content has stable namespace IDs, e.g.:

- `base.tile.man.5`
- `base.yaku.seven_pairs`
- `base.relic.quiet_table`

Runtime may cache Resource refs, but Save/Replay records stable IDs.

`ContentRegistry` resolves IDs to definitions and validates uniqueness/references at boot and in CI.

### 24.3 Domain-first CombatEngine

Authoritative rule state lives in a pure Domain layer.

Flow:

`Input → DomainCommand → Validate → CombatEngine/Resolver → State Transition → Domain Events → Presenter/UI`

Scene/UI never directly mutates Domain State.

Animation never causes game rules; game rules cause animation.

CombatEngine is an orchestrator, not a god object. It coordinates services such as:

- PatternEvaluator
- YakuEvaluator
- MahjongScoreResolver
- CombatConversionResolver
- DrawResolver
- ReserveResolver
- SettlementResolver
- EnemyIntentResolver
- EffectResolver
- TriggerResolver
- LifecycleResolver
- StateBasedCheckResolver

### 24.4 Command model

Every player decision that changes authoritative state is an explicit serializable Command.

Examples:

- DiscardTileCommand
- StoreTileCommand
- SwapReserveTileCommand
- UseTechniqueCommand
- SelectPatternCommand
- ConfirmSettlementCommand
- EndTurnCommand
- ChooseReactionCommand
- SelectMapNodeCommand
- ChooseRewardCommand
- BuyShopOfferCommand
- UseWorkshopServiceCommand
- ChooseEventOptionCommand

Commands encode player intent, not low-level internal steps.

Only accepted authoritative Commands enter Replay logs. Preview commands do not.

### 24.5 Effect system

Default content implementation: **Typed Declarative Effect Model**.

Structure:

`Trigger → Conditions → Targets → Effects`

Reusable typed effects include concepts like:

- GainTP
- Gain/ReducePressure
- DealDamage
- GainStability
- Draw/Discard/Move/Exhaust/Purge Tile
- Damage/Repair Integrity
- Apply/Remove Status
- Add Score Contribution
- Modify Conversion Profile
- Change Settlement/Draw/Reserve capacity
- Reveal/reorder Draw Wall subset
- Inject Contamination
- Modify Pressure Limit

Use domain-level primitives such as `AtomicReserveSwapEffect` where atomic semantics matter.

Aim for 80–90% of official content to be data-composable.

Rare `CustomEffectHandler` is an internal escape hatch. It may use only Domain APIs/context and must remain deterministic, testable and preview-aware.

### 24.6 Duration and stacking

Temporary effects use one unified `DurationSpec + StackPolicy + LifecycleResolver`.

Supported time scopes:

- ACTION
- SETTLEMENT_WINDOW
- TURN
- N_TURNS
- BOSS_PHASE
- BATTLE
- ACT
- RUN
- USES/CHARGES-based consumption

Stack policies:

- REPLACE
- REFRESH_DURATION
- ADD_STACKS
- ADD_DURATION
- INDEPENDENT_INSTANCES
- UNIQUE

Permanent Tile Modifiers are persistent object state, not fake RUN-duration statuses.

---

## 25. Presentation Architecture and Performance

### 25.1 Domain events vs presentation cues

Domain resolution never waits for animation.

Domain emits factual events; Presentation may aggregate them into cues.

Example: three TP +1 Domain Events may be rendered as one `TP +3` cue if causal clarity is preserved.

### 25.2 Presentation modes

Support:

- Normal
- Fast
- Instant/Skip

Use `PresentationPriority` concepts:

- LOW
- NORMAL
- IMPORTANT
- CINEMATIC

Complete Hand, Boss Phase Transition and final victory retain concise high-priority feedback even in fast/instant modes.

### 25.3 Performance baseline

1.0 should run stably on ordinary modern PC and Steam Deck-class hardware.

Priority:

`input responsiveness > state clarity > animation smoothness > visual effects`

Logical focus and Domain state must not wait for tile Tweens.

---

## 26. Headless Testing and Validation

All authoritative Domain rules must run without Scene/UI.

Required test layers:

1. Pattern unit tests
2. Yaku/Score golden tests
3. Combat state-transition tests
4. Effect primitive contract tests
5. deterministic replay/hash tests
6. content validation
7. save migration tests
8. seeded simulation/fuzz tests
9. Scene/UI integration tests as a separate presentation layer

Suggested invariants for fuzz/simulation:

- TileInstance never occupies two zones simultaneously.
- Pressure and numeric outputs remain finite.
- Settlement Capacity never becomes invalid.
- no infinite Effect Queue.
- no unresolved Reaction Window at stable boundary.
- tile counts/lifetimes obey conservation rules.

Domain code may depend on typed data, content definitions/interfaces and deterministic RNG abstraction. It must not depend on Node, Control, AnimationPlayer, Audio, SceneTree or View classes.

---

## 27. Internal Extensibility and Modding Boundary

1.0 does **not** promise a public Mod SDK/API.

However, the architecture must provide strong internal content extensibility.

A normal new Relic/Yaku/Technique/Enemy/Event should primarily require:

`Definition Resource + Effect/Intent configuration + content-pool registration`

without modifying core CombatEngine, DrawResolver, SettlementResolver or EffectQueue.

At Vertical Slice/Alpha, run a **No-Core-Code Content Test** by adding representative content from each major category without touching core engine code.

Stable content IDs are namespace-ready so a future public Mod API can evolve from proven internal extension points.

CustomEffectHandler remains an internal API in 1.0.

---

## 28. Milestones and Scope Gates

### Stage 0 — Technical Prototype

Goal: prove Mahjong→Combat loop.

Must validate:

- Draw → Construct → Settle → Combat Output is understandable.
- Partial Settlement has tactical value.
- Complete Hand is attractive but not mandatory.
- Pressure feels like tempo risk rather than hidden HP.
- core Domain can run headless.

Do not use more content to hide a weak core loop.

### Stage 1 — Systems Prototype

Add Reserve, Integrity, Settlement Capacity, Yaku Progress, Recovery, Fatigue, Intent, Command architecture, Effect system and deterministic RNG.

Exit gate:

- complete battles run end-to-end;
- at least three distinct build patterns are viable;
- no basic resource is redundant;
- no known infinite loop/soft-lock;
- same seed + same commands = same result;
- no Scene dependency in core rules.

### Stage 2 — Vertical Slice

A small but complete Mini-Run.

Locked target:

- 2 Characters
- 3 Contracts
- 1 mini Act
- 4–5 Normal enemies
- 1 Elite
- 1 real multi-phase Boss
- 10–12 Yaku
- 18–24 Relics
- 8–10 Run Techniques + 2 Core Techniques
- 5–6 Tile Modifiers
- 6–8 Events
- real Map, Shop, Workshop, rewards, Run Summary, save/replay baseline

All core systems must be real architecture, not temporary fakes.

Exit gate emphasizes onboarding comprehension, multiple strategy families, meaningful rewards, encounter hierarchy, Shop/Workshop opportunity cost, Suspend/Resume and deterministic verification.

### Stage 3 — Alpha

Only after Slice proves the Run loop may large-scale content production begin.

Expand toward:

- 3 Characters
- 6→8 Contracts
- ~18 Yaku
- ~35–40 Relics
- broader Techniques/enemy roster
- 2 Acts

All 1.0 core systems should exist by Alpha exit. After this point, no major system should be required to finish the game.

### Stage 4 — Beta / Content Complete

Reach planned 1.0 content budget. Freeze unnecessary major system expansion.

Focus:

- balance
- onboarding
- UX
- controller
- accessibility
- localization readiness
- bug fixing
- performance
- presentation/audio

### Stage 4.5 — UI/UX Design and Implementation

After the Stage 4 Beta gate passes, establish and implement a cohesive production UI/UX across the full player-facing Run. Reviewable screen designs and the visual system require maintainer approval before implementation. Preserve the visual priority `Readability > state clarity > tile recognition > animation feedback > decoration`, the keyboard/mouse/controller flows, and the Domain/presentation boundary. Do not change gameplay rules or add a major system in this stage. See [Stage 4.5 UI/UX Design and Implementation](STAGE_4_5_UI_UX_SPEC.md) and its [issue map](https://github.com/sunnyday9/Forbidden-Table/issues/98).

### Stage 5 — 1.0 Release Candidate

No new systems by default.

Only bug/balance/UX/performance/compatibility/content-data fixes unless a missing element would invalidate a core design pillar.

---

## 29. 1.0 Content Budget Summary

| Category | Target |
|---|---:|
| Characters | 3 |
| Contracts | 8 |
| Yaku | ~24 |
| Normal Relics | ~50 |
| Boss Rule Breakers | ~10–12 |
| Run Techniques | ~21 |
| Core Techniques | 3 |
| Tile Modifiers | ~12–16 |
| Normal Enemies | ~14 |
| Elites | ~6 |
| Bosses | ~4 |
| Events | ~24 |
| Main Acts | 2 + optional final act |
| Run length | ~60–90 min |

All numbers are content budgets, not immutable balance constraints.

---

## 30. Non-goals / Scope Guardrails

For 1.0, avoid:

- traditional four-player Mahjong simulation;
- multiplayer networking;
- a second card/skill deck parallel to Mahjong;
- explorable dungeon movement;
- bespoke active skill per tile;
- generic RPG HP/poison/strength stack as the main combat model;
- complete Riichi rules implementation;
- full public Mod SDK;
- mobile/touch-first UX;
- default combat damage variance/critical RNG;
- giant narrative campaign with heavy cinematics;
- arbitrary new core meters unless existing systems cannot express the problem.

Any post-Vertical-Slice proposal for a new major subsystem must state the verified problem it solves, why existing systems cannot solve it, its state/UI/content/test/save costs, and whether it justifies delaying the milestone.

---

## 31. Core Acceptance Principles

The project is on the right path when:

1. A player unfamiliar with Mahjong can learn enough through play to make informed choices.
2. A Mahjong-aware player recognizes meaningful structural reasoning rather than superficial tile skinning.
3. Partial Settlement, Complete Hand and Hybrid play all have legitimate builds.
4. Character and Contract change the run without replacing the core rules.
5. Builds manipulate probabilities and conversion profiles without removing uncertainty entirely.
6. Enemy mechanics attack the Mahjong engine in understandable ways.
7. Large Mahjong Scores feel celebratory even when Combat Conversion keeps balance controlled.
8. Core outcomes are deterministic after commitment and fully replay-verifiable.
9. New ordinary content can be added without modifying core engine logic.
10. The game remains fast to operate at high mastery via animation acceleration/aggregation.

---

## 32. Open Tuning Variables (Intentionally Not Locked)

The grilling deliberately avoided freezing reversible numeric balance. The following remain data-tunable:

- starting Tile Pool size
- exact MinimumPoolSize and BattleActiveFloor
- Normal Hand Baseline / Recovery Baseline
- base Draw Actions
- Settlement Capacity base value
- TP income/caps/decay
- Reserve Integrity values/decay amounts
- Pressure Limit and encounter pressure curves
- Fatigue formulas
- Pattern base scores
- Yaku bonus values/multipliers
- Damage/Stability conversion curves
- Shop prices and refresh costs
- Workshop prices/token costs
- reward weights
- enemy HP / Intent values
- Contract numerical tradeoffs
- Complete Hand recovery values
- exact Vertical Slice run length

These should be tuned through telemetry, deterministic simulations and playtests rather than encoded as architectural constants.

---

## 33. Definition of “Architecture Complete Enough for Content Production”

Before large-scale content production, the following must all be true:

- Domain rules run headless.
- Command model covers all authoritative player decisions.
- Content definitions use stable IDs and registry validation.
- Effect primitives cover representative Relic/Technique/Enemy/Event content.
- Pattern/Yaku/Score/Conversion pipelines are stable interfaces.
- Save snapshots are explicit DTOs with versioning.
- deterministic RNG streams and replay verification work.
- Presentation is downstream of Domain Events.
- Reserve/Settlement/Complete Hand/Pressure edge cases have automated tests.
- a representative new content item from each major category can be added without editing core CombatEngine.

Only then should the project aggressively scale content quantity.
