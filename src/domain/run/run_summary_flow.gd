class_name RunSummaryFlow
extends RefCounted

const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const LifecycleResolverScript = preload("res://src/domain/effects/lifecycle_resolver.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")

const DETAIL_KEYS := ["act_index", "encounter_id", "gold", "reward_option_id", "rule_breaker_id", "defeat_context"]

var state
var content_registry

func _init(initial_state, initial_content_registry) -> void:
	state = initial_state
	content_registry = initial_content_registry

func bind_state(authoritative_state) -> void:
	state = authoritative_state

func enter(outcome: String, reason: String = "", summary_data: Dictionary = {}) -> Array:
	if state.phase == RunPhaseScript.RUN_SUMMARY or state.phase == RunPhaseScript.RUN_COMPLETE:
		return []
	if outcome.is_empty() or outcome == "ONGOING":
		return []
	var previous_phase: String = state.phase
	state.terminal_summary.outcome = outcome
	state.terminal_summary.reason = reason
	var complete_summary_data := _build_run_summary_data(outcome, reason)
	for key in summary_data:
		if complete_summary_data.has(key) or key not in DETAIL_KEYS:
			continue
		complete_summary_data[key] = summary_data[key].duplicate(true) if summary_data[key] is Dictionary or summary_data[key] is Array else summary_data[key]
	state.terminal_summary.summary_data = complete_summary_data
	var event_summary_data := complete_summary_data.duplicate(true)
	event_summary_data.erase("defeat_context")
	state.phase = RunPhaseScript.RUN_SUMMARY
	var lifecycle := LifecycleResolverScript.new()
	var events := lifecycle.advance(state, LifecycleResolverScript.ACT)
	events.append_array(lifecycle.advance(state, LifecycleResolverScript.RUN))
	events.append_array([
		DomainEventScript.new(DomainEventScript.RUN_SUMMARY_REACHED, {
			"run_id": state.run_id,
			"outcome": outcome,
			"reason": reason,
			"summary_data": event_summary_data,
		}),
		_run_phase_event(previous_phase, state.phase),
	])
	return events

func record_metrics(command_data: Dictionary, events: Array) -> void:
	var score_data: Variant = command_data.get("score", {})
	if score_data is Dictionary and not score_data.is_empty():
		state.maximum_mahjong_score = maxi(state.maximum_mahjong_score, int(score_data.get("total", score_data.get("final_value", 0))))
		var contributions: Variant = score_data.get("contributions", [])
		if contributions is Array:
			for contribution in contributions:
				if not contribution is Dictionary:
					continue
				var source_id := str(contribution.get("source_id", ""))
				var definition = content_registry.resolve(source_id) if not source_id.is_empty() else null
				var yaku_id := source_id
				if definition == null and source_id.ends_with(".complete"):
					yaku_id = source_id.substr(0, source_id.length() - ".complete".length())
					definition = content_registry.resolve(yaku_id)
				if definition != null and definition.definition_type_name() == "YakuDefinition":
					_increment_summary_count(state.yaku_counts, definition.content_id)
	for event in events:
		if event == null:
			continue
		if event.event_type == DomainEventScript.PATTERN_SETTLED:
			var pattern_type := str(event.data.get("pattern_type", ""))
			if not pattern_type.is_empty():
				_increment_summary_count(state.pattern_counts, pattern_type)
		elif event.event_type == DomainEventScript.COMPLETE_HAND_SETTLED:
			state.complete_hand_count += 1
			var hand_score := int(event.data.get("score", 0))
			state.maximum_mahjong_score = maxi(state.maximum_mahjong_score, hand_score)
			var pattern_types: Variant = event.data.get("pattern_types", [])
			if pattern_types is Array:
				for pattern_type_value in pattern_types:
					_increment_summary_count(state.pattern_counts, str(pattern_type_value))
			if state.complete_hand_count == 1:
				_record_run_milestone("first_complete_hand")

func validate_acknowledge() -> RefCounted:
	if state.phase != RunPhaseScript.RUN_SUMMARY:
		return CommandValidationScript.new(false, "INVALID_PHASE", "The command is only legal during %s." % RunPhaseScript.RUN_SUMMARY, {
			"expected_phase": RunPhaseScript.RUN_SUMMARY,
			"actual_phase": state.phase,
		})
	return CommandValidationScript.new(true)

func execute_acknowledge() -> Dictionary:
	var previous_phase: String = state.phase
	state.phase = RunPhaseScript.RUN_COMPLETE
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": [
			DomainEventScript.new(DomainEventScript.RUN_COMPLETED, {
				"run_id": state.run_id,
				"outcome": state.terminal_summary.outcome,
			}),
			_run_phase_event(previous_phase, state.phase),
		],
		"data": {"outcome": state.terminal_summary.outcome, "phase": state.phase},
	}

func _increment_summary_count(counts: Dictionary, key: String) -> void:
	if key.is_empty():
		return
	counts[key] = int(counts.get(key, 0)) + 1

func _record_run_milestone(milestone_id: String) -> void:
	if not milestone_id.is_empty() and not state.milestones.has(milestone_id):
		state.milestones.append(milestone_id)

func _build_run_summary_data(outcome: String, reason: String) -> Dictionary:
	var technique_ids: Array[String] = []
	if not state.build_ownership.character_core_technique_id.is_empty():
		technique_ids.append(state.build_ownership.character_core_technique_id)
	for technique_id in state.build_ownership.run_technique_ids:
		if not technique_ids.has(technique_id):
			technique_ids.append(technique_id)
	var final_tile_pool: Array = state.tile_pool.to_dictionary().get("tile_instances", [])
	var final_build := {
		"tile_pool": final_tile_pool.duplicate(true),
		"core_yaku": state.yaku_counts.duplicate(true),
		"relics": state.build_ownership.owned_relic_ids.duplicate(),
		"techniques": technique_ids.duplicate(),
		"rule_breakers": state.build_ownership.acquired_rule_breaker_ids.duplicate(),
	}
	return {
		"outcome": outcome,
		"reason": reason,
		"character_id": state.character_id,
		"contract_id": state.contract_id,
		"act_progress": {
			"act_index": state.act_index,
			"act_count": state.act_count,
			"bosses_defeated": state.boss_progress.duplicate(true),
		},
		"final_tile_pool": final_tile_pool.duplicate(true),
		"core_yaku": state.yaku_counts.duplicate(true),
		"relics": state.build_ownership.owned_relic_ids.duplicate(),
		"techniques": technique_ids,
		"rule_breakers": state.build_ownership.acquired_rule_breaker_ids.duplicate(),
		"common_patterns": state.pattern_counts.duplicate(true),
		"complete_hand_count": state.complete_hand_count,
		"maximum_mahjong_score": state.maximum_mahjong_score,
		"milestones": state.milestones.duplicate(),
		"seed": state.seed,
		"final_build": final_build,
	}

func _run_phase_event(previous_phase: String, next_phase: String):
	return DomainEventScript.new(DomainEventScript.RUN_PHASE_CHANGED, {
		"run_id": state.run_id,
		"from_phase": previous_phase,
		"to_phase": next_phase,
	})
