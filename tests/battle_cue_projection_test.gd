extends RefCounted

const LocalizationScript = preload("res://src/presentation/localization/localization.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var script := load("res://src/presentation/ui/battle_cue_projection.gd") as Script
	if script == null:
		failures.append("Battle cue projection must exist")
		return failures
	var events: Array = [
		{"event_type": "TileDrawn", "data": {"instance_id": "physical.one", "definition_id": "base.tile.characters.1"}},
		{"event_type": "EnemyHpChanged", "data": {"previous_hp": 12, "enemy_hp": 5, "amount": 7}},
		{"event_type": "PressureChanged", "data": {"previous_pressure": 4, "pressure": 2, "amount": -2}},
	]
	var cues: Array = script.project(events)
	_check(cues.size() == 3, "Draw, actual damage, and pressure relief each get one cue", failures)
	if cues.size() == 3:
		_check(cues[0].kind == "DRAW" and cues[0].instance_id == "physical.one", "Draw cue carries the physical tile identity", failures)
		_check(cues[1].kind == "ATTACK" and cues[1].amount == 7, "Attack uses actual seven HP loss", failures)
		_check(cues[2].kind == "RELIEF" and cues[2].amount == 2, "Two pressure relieved is defense feedback, never incoming damage", failures)
	var enemy_events: Array = [
		{"event_type": "PressureChanged", "data": {"source_id": "enemy.surge", "amount": 1, "previous_pressure": 9, "pressure": 10}},
		{"event_type": "EnemyIntentResolved", "data": {"intent_id": "enemy.surge", "display_name": "Pressure Surge", "action_type": "PRESSURE", "pressure_amount": 5}},
		{"event_type": "EnemyIntentEffectApplied", "data": {"intent_id": "enemy.tax", "action_type": "WALL_TAX", "requested_amount": 3, "amount": 0, "channel": "draw_capacity"}},
		{"event_type": "EnemyIntentResolved", "data": {"intent_id": "enemy.tax", "display_name": "Wall Tax", "action_type": "WALL_TAX"}},
	]
	var enemy_cues: Array = script.project(enemy_events)
	_check(enemy_cues.size() == 2, "Each resolved enemy effect has one factual cue, without duplicating the intent transition", failures)
	if enemy_cues.size() == 2:
		_check(enemy_cues[0].kind == "PRESSURE" and enemy_cues[0].amount == 1 and enemy_cues[0].text.contains("+1"), "Capped pressure uses actual +1, never the requested +5 or fictitious block", failures)
		_check(enemy_cues[1].kind == "ENEMY_EFFECT" and enemy_cues[1].amount == 0 and enemy_cues[1].text.contains("0"), "Unapplied wall tax reports zero capacity lost", failures)

	var physical_events: Array = [
		{"event_type": "PatternSettled", "data": {"instance_ids": ["one", "two", "three"], "definition_ids": ["base.tile.characters.1", "base.tile.characters.1", "base.tile.characters.1"]}},
		{"event_type": "TileDiscarded", "data": {"instance_id": "four", "definition_id": "base.tile.characters.4"}},
		{"event_type": "StabilityChanged", "data": {"amount": 2}},
		{"event_type": "BossPhaseChanged", "data": {"phase_index": 1}},
		{"event_type": "BattleWon", "data": {}},
		{"event_type": "PressureChanged", "data": {"source_id": "fatigue", "amount": 2}},
	]
	var physical_cues: Array = script.project(physical_events)
	_check(physical_cues.size() == 6, "Settlement, discard, stability, phase, victory, and self pressure each have visible feedback", failures)
	if physical_cues.size() == 6:
		_check(physical_cues[0].kind == "SETTLE" and physical_cues[0].instance_ids == ["one", "two", "three"], "Settlement preserves all physical tile identities in order", failures)
		_check(physical_cues[1].kind == "DISCARD" and physical_cues[1].instance_id == "four", "Discard flies the discarded physical tile", failures)
		_check(physical_cues[2].kind == "STABILITY" and physical_cues[2].amount == 2, "Stability gain reports a resource delta without inventing incoming block", failures)
		_check(physical_cues[3].kind == "PHASE" and physical_cues[3].text.contains("2"), "Boss phase index one displays phase two", failures)
		_check(physical_cues[4].kind == "VICTORY", "Victory follows the phase cue", failures)
		_check(physical_cues[5].kind == "STRESS", "Self pressure never animates as an enemy attack", failures)

	var origins: Array = script.project([
		{"event_type": "TileDrawn", "data": {"source": "SETTLEMENT_REPLACEMENT", "instance_id": "replacement", "definition_id": "base.tile.characters.1"}},
		{"event_type": "EnemyHpChanged", "data": {"source_id": "effect.technique", "amount": 3}},
		{"event_type": "CompleteHandSettled", "data": {"destination": "Exhaust", "instance_ids": ["one", "two"]}},
	])
	_check(origins.size() == 3, "Authored origin example produces three cues", failures)
	if origins.size() == 3:
		_check(origins[0].get("source", "") == "SETTLEMENT_REPLACEMENT", "Replacement draw retains its authored origin", failures)
		_check(origins[1].get("source_id", "") == "effect.technique", "Technique hit retains its actual effect origin", failures)
		_check(origins[2].get("destination", "") == "Exhaust", "Complete Hand retains Exhaust destination rather than inventing Discard", failures)

	TranslationServer.set_locale("en")
	var source_cues: Array = script.project([
		{"event_type": "EnemyHpChanged", "data": {"source_id": "content.alpha.technique.harbor_strike", "amount": 4}},
		{"event_type": "EnemyHpChanged", "data": {"source_id": "combat_conversion.alpha.enemy", "amount": 2}},
		{"event_type": "EnemyHpChanged", "data": {"source_id": "combat_conversion.alpha.enemy.complete_hand", "amount": 6}},
		{"event_type": "EnemyHpChanged", "data": {"source_id": "unknown.private_identifier", "amount": 1}},
	])
	var harbor_strike_name := LocalizationScript.content_text("alpha.technique.harbor_strike")
	var player_source_name := LocalizationScript.text("BATTLE_CUE_SOURCE_PLAYER")
	_check(source_cues.size() == 4, "each actual HP loss keeps one attack cue", failures)
	if source_cues.size() == 4:
		_check(source_cues[0].get("source_id", "") == "content.alpha.technique.harbor_strike", "attack cue preserves its raw domain source for presentation routing", failures)
		_check(source_cues[0].get("origin", "") == "player", "Technique damage uses the generic player-side animation origin", failures)
		_check(source_cues[0].get("source_name", "") == harbor_strike_name, "known content effect IDs resolve to their localized technique name", failures)
		_check(source_cues[0].get("text", "").contains(harbor_strike_name) and not source_cues[0].get("text", "").contains("content."), "known source is readable without exposing its raw content ID", failures)
		_check(source_cues[1].get("origin", "") == "hand" and source_cues[1].get("source_name", "") == LocalizationScript.word_text("PATTERN"), "Pattern conversion hits originate from the Hand with a localized label", failures)
		_check(source_cues[2].get("origin", "") == "hand" and source_cues[2].get("source_name", "") == LocalizationScript.word_text("COMPLETE_HAND"), "Complete Hand conversion hits originate from the Hand with a localized label", failures)
		_check(source_cues[3].get("source_name", "") == player_source_name and not source_cues[3].get("text", "").contains("private_identifier"), "unrecognized source IDs use a localized fallback instead of leaking identifiers", failures)
	_check(LocalizationScript.format("BATTLE_CUE_DRAW_GROUP", [3]) == "Drew 3 tiles", "English grouped Draw copy accepts the tile count", failures)
	_check(LocalizationScript.format("BATTLE_CUE_ATTACK_GROUP", [7, 2]) == "7 damage across 2 hits", "English grouped attack copy accepts total damage and hit count", failures)
	TranslationServer.set_locale("zh_CN")
	var chinese_cues: Array = script.project([
		{"event_type": "EnemyHpChanged", "data": {"source_id": "content.alpha.technique.harbor_strike", "amount": 4}},
		{"event_type": "EnemyHpChanged", "data": {"source_id": "unknown.private_identifier", "amount": 1}},
	])
	_check(chinese_cues[0].get("source_name", "") == LocalizationScript.content_text("alpha.technique.harbor_strike") and chinese_cues[0].get("text", "").contains("港湾打击"), "known attack sources are localized in Chinese", failures)
	_check(chinese_cues[1].get("source_name", "") == LocalizationScript.text("BATTLE_CUE_SOURCE_PLAYER") and chinese_cues[1].get("source_name", "") == "玩家攻击", "unknown source fallback is localized in Chinese", failures)
	_check(LocalizationScript.format("BATTLE_CUE_DRAW_GROUP", [3]) == "摸到 3 张牌", "Chinese grouped Draw copy accepts the tile count", failures)
	_check(LocalizationScript.format("BATTLE_CUE_ATTACK_GROUP", [7, 2]) == "造成 7 点伤害（2 次命中）", "Chinese grouped attack copy accepts total damage and hit count", failures)
	TranslationServer.set_locale("en")

	return failures

func _check(value: bool, message: String, failures: Array[String]) -> void:
	if not value:
		failures.append(message)
