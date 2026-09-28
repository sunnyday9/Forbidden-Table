# Declarative Technique activation

Status: accepted (2026-09-26)

`PROJECT_SPEC.md` requires player state changes to use serializable Commands and names `UseTechniqueCommand`, but the Alpha branch had no such Command or effect-dispatch path: Techniques could be owned yet never used. Use one `UseTechniqueCommand` for Core and Run Techniques, validate ownership, TP, and the authored timing kind in `BattleDomain`, then resolve the existing typed Effects through `CombatResolutionQueue`; passive Run Techniques resolve at Battle setup, Settlement Techniques are available during an open Settlement Window, and Reaction Techniques respond to the displayed intent before End Turn. This adds one replay-factory case and a presentation action, uses the existing owned-ID and combat-state save fields, and keeps cost, timing, effect, replay, and save-resume checks at the Command seam instead of adding content-specific resolver branches.
