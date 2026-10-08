# Forbidden Table

Shared vocabulary for the game's domain. Product rules and implementation requirements remain in the specification.

## Language

**Run**:
A single attempt through the game's Act sequence, carrying Run-level state such as Character, Contract, build, and resources until a Run ending.
_Avoid_: Act (as a synonym for Run)

**Act**:
A chapter within a Run with its own map/path, encounters, and Boss. Transitioning Acts does not start a new Run.
_Avoid_: Run (as a synonym for Act)

**Discard**:
A battle action that moves a tile out of Hand into Discard. A discarded Run-owned tile remains part of the Run's Tile Pool.
_Avoid_: Remove (as a synonym for Discard)

**Pool removal**:
A permanent removal of a physical Run-owned tile from the Tile Pool, changing the tiles available in later battles of the same Run.
_Avoid_: Discard (as a synonym for Pool removal)

**Pivot reward**:
A special reward that explicitly offers a change beyond the current build direction, including tile types outside the Character's chosen starting profile.
_Avoid_: ordinary reward (when describing an explicit change of direction)
