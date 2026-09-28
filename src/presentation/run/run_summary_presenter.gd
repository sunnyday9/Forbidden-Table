class_name RunSummaryPresenter
extends RefCounted

static func summary_details(run_state, current_unix_seconds: int = -1) -> Dictionary:
	if run_state == null or run_state.terminal_summary == null:
		return {}
	var details: Dictionary = run_state.terminal_summary.summary_data.duplicate(true)
	if not details.has("final_tile_pool") and run_state.tile_pool != null:
		details["final_tile_pool"] = run_state.tile_pool.to_dictionary().get("tile_instances", [])
	if not details.has("relics") and run_state.build_ownership != null:
		details["relics"] = run_state.build_ownership.owned_relic_ids.duplicate()
	if not details.has("techniques") and run_state.build_ownership != null:
		var technique_ids: Array[String] = []
		if not run_state.build_ownership.character_core_technique_id.is_empty():
			technique_ids.append(run_state.build_ownership.character_core_technique_id)
		for technique_id in run_state.build_ownership.run_technique_ids:
			if not technique_ids.has(technique_id):
				technique_ids.append(technique_id)
		details["techniques"] = technique_ids
	if not details.has("rule_breakers") and run_state.build_ownership != null:
		details["rule_breakers"] = run_state.build_ownership.acquired_rule_breaker_ids.duplicate()
	var started_at := int(run_state.run_started_at_unix_seconds)
	if started_at <= 0:
		details["duration_seconds"] = -1
	else:
		var now := current_unix_seconds if current_unix_seconds >= 0 else int(Time.get_unix_time_from_system())
		details["duration_seconds"] = maxi(0, now - started_at)
	return details

static func format(run_state, current_unix_seconds: int = -1) -> String:
	var details := summary_details(run_state, current_unix_seconds)
	if details.is_empty():
		return "Run Summary\nNo terminal Run data is available."
	var act_progress: Dictionary = details.get("act_progress", {})
	var bosses: Array = act_progress.get("bosses_defeated", [])
	var boss_labels: Array[String] = []
	for boss in bosses:
		if boss is Dictionary:
			boss_labels.append("Act %d: %s" % [int(boss.get("act_index", 0)), _pretty_id(str(boss.get("encounter_id", "")))])
	var duration_seconds := int(details.get("duration_seconds", -1))
	var duration_text := _format_duration(duration_seconds) if duration_seconds >= 0 else "Not tracked for this Run"
	var act_progress_text := "Act %d of %d; %s" % [int(act_progress.get("act_index", 0)), int(act_progress.get("act_count", 0)), _list_or_none(boss_labels)]
	if not details.has("act_progress"):
		act_progress_text = "Act %d of %d; Boss progress not tracked for this Run" % [int(run_state.act_index), int(run_state.act_count)]
	var lines := [
		"Build Story",
		"Result: %s%s" % [_pretty_id(str(details.get("outcome", ""))), _reason_suffix(str(details.get("reason", "")))],
		"Character / Contract: %s / %s" % [_pretty_id(str(details.get("character_id", ""))), _pretty_id(str(details.get("contract_id", "")))],
		"Acts / Bosses: %s" % act_progress_text,
		"Final Tile Pool: %s" % _tile_pool_text(details.get("final_tile_pool", [])),
		"Core Yaku: %s" % _summary_counts_text(details, "core_yaku"),
		"Relics: %s" % _summary_list_text(details, "relics"),
		"Techniques: %s" % _summary_list_text(details, "techniques"),
		"Rule Breakers: %s" % _summary_list_text(details, "rule_breakers"),
		"Common Patterns: %s" % _summary_counts_text(details, "common_patterns"),
		"Complete Hands: %s" % _summary_number_text(details, "complete_hand_count"),
		"Maximum Mahjong Score: %s" % _summary_number_text(details, "maximum_mahjong_score"),
		"Milestones: %s" % _summary_list_text(details, "milestones"),
		"Seed: %d" % int(details.get("seed", run_state.seed)),
		"Duration: %s" % duration_text,
	]
	return "\n".join(lines)

static func _tile_pool_text(records: Variant) -> String:
	if not records is Array or records.is_empty():
		return "None recorded"
	var counts: Dictionary = {}
	for record in records:
		if record is Dictionary:
			var tile_id := str(record.get("definition_id", ""))
			if not tile_id.is_empty():
				counts[tile_id] = int(counts.get(tile_id, 0)) + 1
	return _counts_text(counts)

static func _counts_text(counts: Variant) -> String:
	if not counts is Dictionary or counts.is_empty():
		return "None recorded"
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b):
		var count_a := int(counts[a])
		var count_b := int(counts[b])
		return count_a > count_b if count_a != count_b else str(a) < str(b)
	)
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s ×%d" % [_pretty_id(str(key)), int(counts[key])])
	return ", ".join(parts)

static func _summary_counts_text(details: Dictionary, key: String) -> String:
	return _counts_text(details.get(key, {})) if details.has(key) else "Not tracked for this Run"

static func _summary_list_text(details: Dictionary, key: String) -> String:
	return _list_or_none(_pretty_ids(details.get(key, []))) if details.has(key) else "Not tracked for this Run"

static func _summary_number_text(details: Dictionary, key: String) -> String:
	return str(int(details[key])) if details.has(key) else "Not tracked for this Run"

static func _pretty_ids(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			result.append(_pretty_id(str(value)))
	return result

static func _pretty_id(identifier: String) -> String:
	if identifier.is_empty():
		return "Not recorded"
	var parts := identifier.split(".")
	if parts.size() >= 4 and parts[1] == "tile":
		if parts[2] == "honors":
			return parts[3].replace("_", " ").capitalize()
		return "%s %s" % [parts[2].replace("_", " ").capitalize(), parts[3]]
	return identifier.get_slice(".", identifier.get_slice_count(".") - 1).replace("_", " ").capitalize()

static func _list_or_none(values: Array) -> String:
	return ", ".join(values) if not values.is_empty() else "None recorded"

static func _reason_suffix(reason: String) -> String:
	return " (%s)" % _pretty_id(reason) if not reason.is_empty() else ""

static func _format_duration(total_seconds: int) -> String:
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	var seconds := total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]
