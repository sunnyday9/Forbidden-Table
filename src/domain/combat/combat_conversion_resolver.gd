class_name CombatConversionResolver
extends RefCounted

const CombatConversionProfileScript = preload("res://src/domain/combat/combat_conversion_profile.gd")
const CombatConversionResultScript = preload("res://src/domain/combat/combat_conversion_result.gd")
const CombatConversionContributionScript = preload("res://src/domain/combat/combat_conversion_contribution.gd")
const ScoreContributionScript = preload("res://src/domain/mahjong/scoring/score_contribution.gd")

func resolve(score_result, profile, state: Dictionary = {}):
	if not profile is CombatConversionProfileScript:
		profile = CombatConversionProfileScript.new()
	var score_total := 0
	if score_result != null and "total" in score_result:
		score_total = int(score_result.total)
	var conversion_contributions: Array = []
	var contribution_total := 0
	var damage_score_share := 0.0
	var stability_score_share := 0.0
	if score_result != null and "contributions" in score_result:
		for contribution in score_result.contributions:
			if not contribution is ScoreContributionScript:
				continue
			var amount := int(contribution.amount)
			var contribution_damage_share = profile.damage_score_share(float(amount), contribution.tags, contribution.conversion_modifiers)
			var contribution_stability_share = profile.stability_score_share(float(amount), contribution.tags, contribution.conversion_modifiers)
			conversion_contributions.append(CombatConversionContributionScript.new(
				contribution.source_id,
				amount,
				contribution.tags,
				contribution.metadata,
				contribution.conversion_modifiers,
				contribution_damage_share,
				contribution_stability_share,
			))
			contribution_total += amount
			damage_score_share += contribution_damage_share
			stability_score_share += contribution_stability_share
	var unattributed_amount := score_total - contribution_total
	if unattributed_amount != 0:
		var unattributed_damage_share = profile.damage_score_share(float(unattributed_amount), [], {})
		var unattributed_stability_share = profile.stability_score_share(float(unattributed_amount), [], {})
		conversion_contributions.append(CombatConversionContributionScript.new(
			"mahjong_score.unattributed",
			unattributed_amount,
			[],
			{},
			{},
			unattributed_damage_share,
			unattributed_stability_share,
		))
		damage_score_share += unattributed_damage_share
		stability_score_share += unattributed_stability_share
	var damage = profile.damage_curve.resolve(damage_score_share, state)
	var stability = profile.stability_curve.resolve(stability_score_share, state)
	return CombatConversionResultScript.new(
		score_total,
		damage,
		stability,
		profile.profile_id,
		conversion_contributions,
		damage_score_share,
		stability_score_share,
		profile.to_dictionary(),
	)
