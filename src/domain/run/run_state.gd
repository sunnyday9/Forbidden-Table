class_name RunState
extends RefCounted

const RunBuildStateScript = preload("res://src/domain/run/run_build_state.gd")
const RunBattleSnapshotScript = preload("res://src/domain/run/run_battle_snapshot.gd")
const RunMapStateScript = preload("res://src/domain/run/run_map_state.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RewardDraftScript = preload("res://src/domain/run/reward_draft.gd")
const RunTerminalSummaryScript = preload("res://src/domain/run/run_terminal_summary.gd")
const RunTilePoolStateScript = preload("res://src/domain/run/run_tile_pool_state.gd")
const RunTutorialStateScript = preload("res://src/domain/run/run_tutorial_state.gd")
const ShopStateScript = preload("res://src/domain/run/shop_state.gd")
const WorkshopStateScript = preload("res://src/domain/run/workshop_state.gd")
const ActiveEffectInstanceScript = preload("res://src/domain/effects/active_effect_instance.gd")
const EventStateScript = preload("res://src/domain/run/event_state.gd")

var run_id: String
var seed: int
var content_version: String
var act_index: int
var act_count: int
var phase: String
var character_id: String
var contract_id: String
var map_state: RunMapState
var tile_pool: RunTilePoolState
var shop_state
var workshop_state
var event_state
var active_effects: Dictionary
var gold: int
var refinement_tokens: int
var reward_draft: RefCounted
var reward_draft_sequence: int
var tile_instance_sequence: int
var build_ownership: RunBuildState
var tutorial_state: RunTutorialState
var terminal_summary: RunTerminalSummary
var current_battle_snapshot: RefCounted
var run_started_at_unix_seconds: int
var pattern_counts: Dictionary
var yaku_counts: Dictionary
var complete_hand_count: int
var maximum_mahjong_score: int
var boss_progress: Array[Dictionary]
var milestones: Array[String]

func _init(
	initial_run_id: String,
	initial_seed: int,
	initial_content_version: String,
	initial_tile_pool: RunTilePoolState = null,
	initial_current_battle_snapshot: RefCounted = null,
	initial_act_count: int = 1,
) -> void:
	run_id = initial_run_id
	seed = initial_seed
	content_version = initial_content_version
	act_index = 1
	act_count = initial_act_count
	phase = RunPhaseScript.CHARACTER_SELECT
	character_id = ""
	contract_id = ""
	map_state = RunMapStateScript.new()
	tile_pool = initial_tile_pool if initial_tile_pool != null and initial_tile_pool is RunTilePoolStateScript else RunTilePoolStateScript.new()
	shop_state = ShopStateScript.new()
	workshop_state = WorkshopStateScript.new()
	event_state = EventStateScript.new()
	active_effects = {}
	gold = 0
	refinement_tokens = 0
	reward_draft = null
	reward_draft_sequence = 0
	tile_instance_sequence = 0
	build_ownership = RunBuildStateScript.new()
	tutorial_state = RunTutorialStateScript.new()
	terminal_summary = RunTerminalSummaryScript.new()
	current_battle_snapshot = initial_current_battle_snapshot if initial_current_battle_snapshot == null or initial_current_battle_snapshot is RunBattleSnapshotScript else null
	run_started_at_unix_seconds = int(Time.get_unix_time_from_system())
	pattern_counts = {}
	yaku_counts = {}
	complete_hand_count = 0
	maximum_mahjong_score = 0
	boss_progress = []
	milestones = []

func to_dictionary() -> Dictionary:
	var result := {
		"run_id": run_id,
		"seed": seed,
		"content_version": content_version,
		"act_index": act_index,
		"act_count": act_count,
		"phase": phase,
		"character_id": character_id,
		"contract_id": contract_id,
		"map_state": map_state.to_dictionary(),
		"tile_pool": tile_pool.to_dictionary(),
		"shop_state": shop_state.to_dictionary(),
		"workshop_state": workshop_state.to_dictionary(),
		"event_state": event_state.to_dictionary(),
		"active_effects": _active_effect_details(),
		"gold": gold,
		"refinement_tokens": refinement_tokens,
		"reward_draft": reward_draft.to_dictionary() if reward_draft != null and reward_draft is RewardDraftScript else {},
		"reward_draft_sequence": reward_draft_sequence,
		"tile_instance_sequence": tile_instance_sequence,
		"build_ownership": build_ownership.to_dictionary(),
		"tutorial_state": tutorial_state.to_dictionary(),
		"terminal_summary": terminal_summary.to_dictionary(),
		"current_battle_snapshot": current_battle_snapshot.to_dictionary() if current_battle_snapshot != null else {},
	}
	if run_started_at_unix_seconds > 0:
		result["run_started_at_unix_seconds"] = run_started_at_unix_seconds
	if not pattern_counts.is_empty():
		result["pattern_counts"] = pattern_counts.duplicate(true)
	if not yaku_counts.is_empty():
		result["yaku_counts"] = yaku_counts.duplicate(true)
	if complete_hand_count > 0:
		result["complete_hand_count"] = complete_hand_count
	if maximum_mahjong_score > 0:
		result["maximum_mahjong_score"] = maximum_mahjong_score
	if not boss_progress.is_empty():
		result["boss_progress"] = boss_progress.duplicate(true)
	if not milestones.is_empty():
		result["milestones"] = milestones.duplicate()
	return result

func active_modifier(modifier_id: String):
	for effect in active_modifiers():
		if str(effect.runtime_parameters.get("modifier_id", "")) == modifier_id:
			return effect
	return null

func active_modifiers() -> Array:
	var modifiers: Array = []
	for effect_key in _sorted_effect_keys():
		var effect = active_effects.get(effect_key)
		if not effect is ActiveEffectInstanceScript or not effect.is_active():
			continue
		if str(effect.runtime_parameters.get("modifier_id", "")).is_empty():
			continue
		modifiers.append(effect)
	return modifiers

func _sorted_effect_keys() -> Array:
	var keys: Array = active_effects.keys()
	keys.sort()
	return keys

func _active_effect_details() -> Array:
	var details: Array = []
	for effect_key in _sorted_effect_keys():
		var effect = active_effects[effect_key]
		if effect != null and effect.has_method("to_dictionary"):
			details.append(effect.to_dictionary())
		else:
			details.append({"instance_id": str(effect_key)})
	return details
