class_name BattleContext
extends RefCounted

var encounter_id: String
var encounter_kind: String
var enemy_ids: Array[String]
var character_id: String
var contract_id: String
var character_definition
var contract_definition
var build_state: Dictionary
var contamination_config: Dictionary
var rng_streams
var content_registry
var tile_pool: Array
var persistent_state: Dictionary
var run_state

func _init(
	initial_encounter_id: String,
	initial_encounter_kind: String,
	initial_enemy_ids: Array[String],
	initial_character_id: String,
	initial_contract_id: String,
	initial_character_definition,
	initial_contract_definition,
	initial_build_state: Dictionary,
	initial_contamination_config: Dictionary,
	initial_rng_streams,
	initial_content_registry,
	initial_tile_pool: Array,
	initial_persistent_state: Dictionary,
) -> void:
	encounter_id = initial_encounter_id
	encounter_kind = initial_encounter_kind
	enemy_ids = initial_enemy_ids.duplicate()
	character_id = initial_character_id
	contract_id = initial_contract_id
	character_definition = initial_character_definition
	contract_definition = initial_contract_definition
	build_state = initial_build_state.duplicate(true)
	contamination_config = initial_contamination_config.duplicate(true)
	rng_streams = initial_rng_streams
	content_registry = initial_content_registry
	tile_pool = initial_tile_pool.duplicate(true)
	persistent_state = initial_persistent_state.duplicate(true)

func to_dictionary() -> Dictionary:
	return {
		"encounter_id": encounter_id,
		"encounter_kind": encounter_kind,
		"enemy_ids": enemy_ids.duplicate(),
		"character_id": character_id,
		"contract_id": contract_id,
		"build_state": build_state.duplicate(true),
		"contamination_config": contamination_config.duplicate(true),
		"tile_pool": tile_pool.duplicate(true),
		"persistent_state": persistent_state.duplicate(true),
	}
