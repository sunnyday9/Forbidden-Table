class_name BattleCueProjection
extends RefCounted

const Copy = preload("res://src/presentation/localization/localization.gd")

# Source order and actual amounts are retained. These records own no gameplay
# state and contain no callbacks into commands, the RNG, or the save system.
static func project(events: Array) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	var resolved: Dictionary = {}
	var applied: Dictionary = {}
	for event in events:
		if event is Dictionary:
			var data: Dictionary = event.get("data", {})
			if str(event.get("event_type", "")) == "EnemyIntentResolved":
				resolved[str(data.get("intent_id", ""))] = data
			elif str(event.get("event_type", "")) == "EnemyIntentEffectApplied":
				applied[str(data.get("intent_id", ""))] = true
	var pressure_sources: Dictionary = {}
	for event in events:
		if not event is Dictionary:
			continue
		var data: Dictionary = event.get("data", {})
		match str(event.get("event_type", "")):
			"TileDrawn":
				cues.append({"kind": "DRAW", "source": str(data.get("source", "")), "instance_id": str(data.get("instance_id", "")), "definition_id": str(data.get("definition_id", "")), "text": Copy.format("BATTLE_CUE_DRAW", [Copy.content_text(str(data.get("definition_id", "")))])})
			"TileDiscarded":
				cues.append({"kind": "DISCARD", "instance_id": str(data.get("instance_id", "")), "definition_id": str(data.get("definition_id", "")), "text": Copy.format("BATTLE_CUE_DISCARD", [Copy.content_text(str(data.get("definition_id", "")))])})
			"PatternSettled":
				cues.append({"kind": "SETTLE", "instance_ids": data.get("instance_ids", []).duplicate(), "definition_ids": data.get("definition_ids", []).duplicate(), "text": Copy.text("BATTLE_CUE_SETTLE")})
			"CompleteHandSettled":
				cues.append({"kind": "COMPLETE", "destination": str(data.get("destination", "Discard")), "instance_ids": data.get("instance_ids", []).duplicate(), "text": Copy.text("BATTLE_CUE_COMPLETE")})
			"EnemyHpChanged":
				var amount := int(data.get("amount", 0))
				if amount > 0:
					var source_id := str(data.get("source_id", ""))
					var source_name := _attack_source_name(source_id)
					var origin := "hand" if source_id.begins_with("combat_conversion.") else "player"
					cues.append({
						"kind": "ATTACK",
						"source_id": source_id,
						"source_name": source_name,
						"origin": origin,
						"amount": amount,
						"text": Copy.format("BATTLE_CUE_ATTACK", [source_name, amount]),
					})
			"PressureChanged":
				var amount := int(data.get("amount", 0))
				if amount < 0:
					cues.append({"kind": "RELIEF", "amount": -amount, "text": Copy.format("BATTLE_CUE_RELIEF", [-amount])})
				elif amount > 0:
					var source := str(data.get("source_id", ""))
					pressure_sources[source] = true
					var text := Copy.format("BATTLE_CUE_PRESSURE_GENERIC", [amount])
					if resolved.has(source):
						text = Copy.format("BATTLE_CUE_PRESSURE", [Copy.display_text(str(resolved[source].get("display_name", ""))), amount])
					cues.append({"kind": "PRESSURE" if resolved.has(source) else "STRESS", "amount": amount, "text": text})
			"EnemyIntentEffectApplied":
				var action_type := str(data.get("action_type", ""))
				if action_type not in ["WALL_TAX", "INTEGRITY", "HUNT", "CONTAMINATION", "TABLE_INTERFERENCE", "RULE_BREAKER", "AUDIT", "REWARD_TAX"]:
					continue
				var amount := int(data.get("amount", 0))
				var name := Copy.display_text(str(resolved.get(str(data.get("intent_id", "")), {}).get("display_name", "")))
				var detail := Copy.format("BATTLE_CUE_EFFECT_" + action_type, [amount])
				cues.append({"kind": "ENEMY_EFFECT", "action_type": action_type, "channel": str(data.get("channel", "")), "amount": amount, "target_instance_id": str(data.get("target_instance_id", "")), "text": Copy.format("BATTLE_CUE_INTENT_EFFECT", [name, detail]) if not name.is_empty() else detail})
			"EnemyIntentResolved":
				var id := str(data.get("intent_id", ""))
				if str(data.get("action_type", "")) == "PRESSURE" and not pressure_sources.has(id) and not applied.has(id):
					cues.append({"kind": "PRESSURE", "amount": 0, "text": Copy.format("BATTLE_CUE_INTENT_ZERO", [Copy.display_text(str(data.get("display_name", "")))])})
			"StabilityChanged":
				var amount := int(data.get("amount", 0))
				cues.append({"kind": "STABILITY", "amount": amount, "text": Copy.format("BATTLE_CUE_STABILITY", [("+" if amount >= 0 else "") + str(amount)])})
			"BossPhaseChanged":
				cues.append({"kind": "PHASE", "text": Copy.format("BATTLE_CUE_PHASE", [int(data.get("phase_index", 0)) + 1])})
			"BattleWon":
				cues.append({"kind": "VICTORY", "text": Copy.text("BATTLE_CUE_VICTORY")})
			"BattleLost":
				cues.append({"kind": "DEFEAT", "text": Copy.text("UI_BATTLE_STATE_0006")})
	return cues


static func _attack_source_name(source_id: String) -> String:
	if source_id.begins_with("combat_conversion."):
		return Copy.word_text("COMPLETE_HAND") if source_id.ends_with(".complete_hand") else Copy.word_text("PATTERN")
	if source_id.begins_with("content."):
		var content_id := source_id.trim_prefix("content.")
		if _has_translation_key("en", content_id) and _has_translation_key("zh_CN", content_id):
			return Copy.content_text(content_id)
	return Copy.text("BATTLE_CUE_SOURCE_PLAYER")


static func _has_translation_key(locale: String, key: String) -> bool:
	var translation := TranslationServer.get_translation_object(locale) as Translation
	if translation == null:
		return false
	for raw_key in translation.get_message_list():
		if str(raw_key) == key:
			return true
	return false
