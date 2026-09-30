class_name RunSummaryPresenter
extends RefCounted
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

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
		return LocalizationCatalogScript.text("UI_RUN_SUMMARY_0001")
	var act_progress: Dictionary = details.get("act_progress", {})
	var bosses: Array = act_progress.get("bosses_defeated", [])
	var boss_labels: Array[String] = []
	for boss in bosses:
		if boss is Dictionary:
			boss_labels.append(LocalizationCatalogScript.template("UI_RUN_SUMMARY_0002") % [int(boss.get("act_index", 0)), _pretty_id(str(boss.get("encounter_id", "")))])
	var duration_seconds := int(details.get("duration_seconds", -1))
	var duration_text := _format_duration(duration_seconds) if duration_seconds >= 0 else LocalizationCatalogScript.text("UI_RUN_SUMMARY_0003")
	var act_progress_text := LocalizationCatalogScript.template("UI_RUN_SUMMARY_0004") % [int(act_progress.get("act_index", 0)), int(act_progress.get("act_count", 0)), _list_or_none(boss_labels)]
	if not details.has("act_progress"):
		act_progress_text = LocalizationCatalogScript.template("UI_RUN_SUMMARY_0005") % [int(run_state.act_index), int(run_state.act_count)]
	var lines := [
		LocalizationCatalogScript.text("UI_RUN_SUMMARY_0006"),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0007") % [_pretty_id(str(details.get("outcome", ""))), _reason_suffix(str(details.get("reason", "")))],
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0008") % [_pretty_id(str(details.get("character_id", ""))), _pretty_id(str(details.get("contract_id", "")))],
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0009") % act_progress_text,
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0010") % _tile_pool_text(details.get("final_tile_pool", [])),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0011") % _summary_counts_text(details, "core_yaku"),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0012") % _summary_list_text(details, "relics"),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0013") % _summary_list_text(details, "techniques"),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0014") % _summary_list_text(details, "rule_breakers"),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0015") % _summary_counts_text(details, "common_patterns"),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0016") % _summary_number_text(details, "complete_hand_count"),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0017") % _summary_number_text(details, "maximum_mahjong_score"),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0018") % _summary_list_text(details, "milestones"),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0019") % int(details.get("seed", run_state.seed)),
		LocalizationCatalogScript.template("UI_RUN_SUMMARY_0020") % duration_text,
	]
	return "\n".join(lines)

static func _tile_pool_text(records: Variant) -> String:
	if not records is Array or records.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_SUMMARY_0021")
	var counts: Dictionary = {}
	for record in records:
		if record is Dictionary:
			var tile_id := str(record.get("definition_id", ""))
			if not tile_id.is_empty():
				counts[tile_id] = int(counts.get(tile_id, 0)) + 1
	return _counts_text(counts)

static func _counts_text(counts: Variant) -> String:
	if not counts is Dictionary or counts.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_SUMMARY_0022")
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b):
		var count_a := int(counts[a])
		var count_b := int(counts[b])
		return count_a > count_b if count_a != count_b else str(a) < str(b)
	)
	var parts: Array[String] = []
	for key in keys:
		parts.append(LocalizationCatalogScript.template("UI_RUN_SUMMARY_0023") % [_pretty_id(str(key)), int(counts[key])])
	return ", ".join(parts)

static func _summary_counts_text(details: Dictionary, key: String) -> String:
	return _counts_text(details.get(key, {})) if details.has(key) else LocalizationCatalogScript.text("UI_RUN_SUMMARY_0024")

static func _summary_list_text(details: Dictionary, key: String) -> String:
	return _list_or_none(_pretty_ids(details.get(key, []))) if details.has(key) else LocalizationCatalogScript.text("UI_RUN_SUMMARY_0025")

static func _summary_number_text(details: Dictionary, key: String) -> String:
	return str(int(details[key])) if details.has(key) else LocalizationCatalogScript.text("UI_RUN_SUMMARY_0026")

static func _pretty_ids(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			result.append(_pretty_id(str(value)))
	return result

static func _pretty_id(identifier: String) -> String:
	if identifier.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_SUMMARY_0027")
	if "." in identifier:
		return LocalizationCatalogScript.content_text(identifier)
	return LocalizationCatalogScript.word_text(identifier)

static func _list_or_none(values: Array) -> String:
	return ", ".join(values) if not values.is_empty() else LocalizationCatalogScript.text("UI_RUN_SUMMARY_0029")

static func _reason_suffix(reason: String) -> String:
	return LocalizationCatalogScript.template("UI_RUN_SUMMARY_0030") % _pretty_id(reason) if not reason.is_empty() else ""

static func _format_duration(total_seconds: int) -> String:
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	var seconds := total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]
