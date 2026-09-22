class_name RunBuildState
extends RefCounted

var owned_relic_ids: Array[String]
var run_technique_ids: Array[String]
var character_core_technique_id: String
var persistent_tile_modifier_state: Dictionary
var acquired_rule_breaker_ids: Array[String]
var yaku_build_milestones: Dictionary

func _init() -> void:
	owned_relic_ids = []
	run_technique_ids = []
	character_core_technique_id = ""
	persistent_tile_modifier_state = {}
	acquired_rule_breaker_ids = []
	yaku_build_milestones = {}

func to_dictionary() -> Dictionary:
	return {
		"owned_relic_ids": owned_relic_ids.duplicate(),
		"run_technique_ids": run_technique_ids.duplicate(),
		"character_core_technique_id": character_core_technique_id,
		"persistent_tile_modifier_state": persistent_tile_modifier_state.duplicate(true),
		"acquired_rule_breaker_ids": acquired_rule_breaker_ids.duplicate(),
		"yaku_build_milestones": yaku_build_milestones.duplicate(true),
	}
