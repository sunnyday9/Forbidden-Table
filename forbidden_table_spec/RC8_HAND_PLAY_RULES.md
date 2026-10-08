# RC8 Hand play and ordering

Owner-requested follow-up to the player-experience candidate. Application version `1.0.0-rc.8+hand-play.20261008`; new replay rules identity `game.rules.rc8.v1`.

Fresh battles require playing 1–3 physical Hand tiles before End Turn. Playing moves the selected tiles to Discard; it does not draw replacements, grant TP, change the Draw budget, consume Reserve manipulation, or resolve enemy intent. Normal draws do not reset the three-tile allowance. A successful End Turn resets the allowance. An empty Hand can end the turn without playing to avoid a soft lock. Terminal battles cannot play or end a turn.

The third tile played during one turn grants +3 Gold if the three played tiles form a same-suit consecutive Sequence or three identical tile types (Triplet, including honors). Order does not matter. The three may be played together or separately. Pairs, mixed suits, non-consecutive ranks, and combinations spanning turns do not qualify. The bonus is immediate and occurs once; a fourth tile is rejected. Playing uses an atomic serializable `PlayHandTilesCommand`; the existing single-tile Discard command uses the same allowance in fresh battles.

The turn's physical IDs and tile definitions are included in checkpoints and saves, so reloading mid-turn cannot reset the quota or duplicate a paid combo. RC7 replay records remain immutable and unavailable under the changed rules. Old snapshots without turn-play fields retain their original current-battle rule and exact serialization; the next fresh battle uses RC8.

Hand sorting and manual order are presentation only. Sort groups Characters, Dots, and Bamboo by rank, then Honors in East, South, West, North, Red, Green, White order, with stable physical-ID ties. Drag tiles to insert them before or after another Hand tile; select/focus and Move left/right provides a pointer and keyboard alternative. Custom order survives draw and UI refresh within the current battle, but does not change authoritative zone order, RNG, selection, or replay commands. This pass does not persist cosmetic order across application restarts.

The Discard area shows only its label and physical tile count, including tiles discarded by settlement or expiry. It does not display previous discarded faces. A turn progress label, bonus preview, and actual Gold receipt explain the new action separately from Pattern settlement and Complete Hand.

Existing RC7 starting pools, 11-tile opening, 14-tile Hand cap, rewards, and Workshop rules remain as specified in `RC7_DISCARD_REWARD_RULES.md`. Automated rule/input/layout/save/replay and isolated exported-resource tests do not establish human play quality or natural balance.
