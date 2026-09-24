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

func to_dictionary() -> Dictionary:
	return {
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

func active_modifier(modifier_id: String):
	for effect_key in _sorted_effect_keys():
		var effect = active_effects[effect_key]
		if effect is ActiveEffectInstanceScript and effect.runtime_parameters.get("modifier_id", "") == modifier_id:
			return effect
	return null

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
