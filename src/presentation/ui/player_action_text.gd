class_name PlayerActionText
extends RefCounted

const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

static func definition_effect_lines(registry, content_id: String) -> Array[String]:
	var lines: Array[String] = []
	if registry == null:
		return lines
	var definition = registry.resolve(content_id)
	if definition == null or not definition.get("effects") is Array:
		return lines
	for effect in definition.get("effects"):
		if effect == null or not effect.get("operations") is Array:
			continue
		for operation in effect.get("operations"):
			var summary := _effect_operation_summary(operation, content_id)
			if not summary.is_empty():
				var definition_type := str(definition.definition_type_name())
				if definition_type == "TileModifierDefinition":
					summary = LocalizationCatalogScript.format("UI_PLAYER_EFFECT_TILE_SETTLED", [summary])
				elif definition_type in ["RelicDefinition", "RuleBreakerDefinition"]:
					summary = LocalizationCatalogScript.format("UI_PLAYER_EFFECT_BATTLE_START", [summary])
				if not lines.has(summary):
					lines.append(summary)
	return lines


static func _effect_operation_summary(operation, content_id: String) -> String:
	if operation == null or not operation.has_method("to_dictionary"):
		return ""
	var details: Dictionary = operation.to_dictionary()
	var operation_id := str(details.get("operation_id", operation.get("operation_id")))
	var amount := int(details.get("amount", 1))
	match operation_id:
		"GainTP":
			return _amount_change(LocalizationCatalogScript.word_text("TP"), amount)
		"GainStability":
			return _amount_change(LocalizationCatalogScript.word_text("STABILITY"), amount)
		"GainPressure":
			return _amount_change(LocalizationCatalogScript.word_text("PRESSURE"), amount)
		"DealDamage":
			return _amount_change(LocalizationCatalogScript.word_text("DAMAGE"), amount)
		"ModifyReserveCapacity":
			return _amount_change(LocalizationCatalogScript.word_text("RESERVE_CAPACITY"), amount)
		"ModifySettlementCapacity":
			return _amount_change(LocalizationCatalogScript.word_text("SETTLEMENT_CAPACITY"), amount)
		"ModifyDrawCapacity":
			return _amount_change(LocalizationCatalogScript.word_text("DRAW_CAPACITY"), amount)
		"ModifyRunCurrency":
			var currency := str(details.get("currency", "GOLD"))
			return _amount_change(LocalizationCatalogScript.word_text("REFINEMENT_TOKENS" if currency == "REFINEMENT_TOKENS" else "GOLD"), amount)
		"ModifyRefinementTokens":
			return _amount_change(LocalizationCatalogScript.word_text("REFINEMENT_TOKENS"), amount)
		"DrawTile":
			return LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_DRAW_TILE")
		"PurgeContamination":
			return LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_PURGE_CONTAMINATION")
		"ApplyRunModifier":
			var parameters: Dictionary = details.get("parameters", {}) if details.get("parameters", {}) is Dictionary else {}
			var discount := int(parameters.get("workshop_price_discount", 0))
			if discount > 0:
				return LocalizationCatalogScript.format("UI_RUN_REWARD_EFFECT_WORKSHOP_DISCOUNT", [discount])
			return LocalizationCatalogScript.format("UI_RUN_REWARD_EFFECT_RUN_MODIFIER", [LocalizationCatalogScript.content_text(content_id)])
	return ""


static func _amount_change(label: String, amount: int) -> String:
	var signed_amount := ("+" if amount > 0 else "−" if amount < 0 else "") + str(absi(amount))
	return LocalizationCatalogScript.format("UI_RUN_REWARD_CHANGE_AMOUNT", [label, signed_amount])


static func settlement_text(battle, action: Dictionary) -> String:
	if battle == null:
		return ""
	var preview: Dictionary = battle.preview_settlement(str(action.get("target_id", "")), str(action.get("kind", "")) == "COMPLETE_HAND")
	if preview.is_empty():
		return ""
	var text := LocalizationCatalogScript.format("UI_PLAYER_SETTLEMENT_PREVIEW", [preview.consumed, preview.replacement_draws, preview.score, preview.damage, preview.stability])
	if int(preview.replacement_requested) > int(preview.replacement_draws):
		text += "\n" + LocalizationCatalogScript.text("UI_PLAYER_WALL_SHORTFALL")
	if bool(preview.recovery):
		text += "\n" + LocalizationCatalogScript.text("UI_PLAYER_RECOVERY_PREVIEW")
	return text + "\n" + LocalizationCatalogScript.text("UI_PLAYER_TRIGGERED_EFFECTS")

static func lethal_intent_amount(battle) -> int:
	if battle == null or battle.combat_state == null:
		return 0
	var combat = battle.combat_state
	var intent = combat.current_intent
	if intent != null and str(intent.action_type) == "PRESSURE" and combat.pressure + intent.pressure_amount >= combat.pressure_limit:
		return int(intent.pressure_amount)
	return 0

static func defeat_cause_text(details: Dictionary) -> String:
	var battle: Dictionary = details.get("defeat_context", {})
	if battle.is_empty():
		return LocalizationCatalogScript.text("UI_PLAYER_DEFEAT_GENERIC") if str(details.get("reason", "")) == "BATTLE_DEFEAT" else ""
	return LocalizationCatalogScript.format("UI_PLAYER_DEFEAT_CAUSE", [int(battle.get("pressure", 0)), int(battle.get("pressure_limit", 0)), int(battle.get("enemy_hp", 0))])

static func defeat_text(details: Dictionary) -> String:
	var cause := defeat_cause_text(details)
	return cause + "\n" + LocalizationCatalogScript.text("UI_PLAYER_DEFEAT_LESSON") if not cause.is_empty() else ""

static func shop_offer_effect_lines(registry, details: Dictionary) -> Array[String]:
	if str(details.get("kind", "")) == "SPECIAL":
		match str(details.get("metadata", {}).get("special_action", "")):
			"REFINEMENT_TOKEN": return [_amount_change(LocalizationCatalogScript.word_text("REFINEMENT_TOKENS"), 1)]
			"GOLD_CACHE": return [_amount_change(LocalizationCatalogScript.word_text("GOLD"), 3)]
			_: return [LocalizationCatalogScript.text("UI_PLAYER_SHOP_UNAVAILABLE")]
	var content_id := str(details.get("content_id", ""))
	var lines := definition_effect_lines(registry, content_id)
	var definition = registry.resolve(content_id) if registry != null else null
	if definition != null and definition.definition_type_name() == "TechniqueDefinition":
		var timing := LocalizationCatalogScript.text("UI_PLAYER_SKILL_USE")
		if str(definition.technique_kind) == "REACTION":
			timing = LocalizationCatalogScript.text("UI_PLAYER_REACTION_CONTAMINATION" if str(definition.reaction_trigger_id) == "ENEMY_CONTAMINATION_ADDED" else "UI_PLAYER_REACTION_STABILITY")
		elif str(definition.technique_kind) == "SETTLEMENT":
			timing = LocalizationCatalogScript.text("UI_PLAYER_SKILL_SETTLEMENT")
		lines.push_front(LocalizationCatalogScript.format("UI_PLAYER_SKILL_COST", [int(definition.tp_cost), timing]))
	return lines

static func shop_offer_has_effect(details: Dictionary) -> bool:
	return str(details.get("kind", "")) != "SPECIAL" or str(details.get("metadata", {}).get("special_action", "")) in ["REFINEMENT_TOKEN", "GOLD_CACHE"]
