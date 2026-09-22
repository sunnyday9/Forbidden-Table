class_name RewardOption
extends RefCounted

const ADD_TILE := "ADD_TILE"
const MODIFIED_TILE := "MODIFIED_TILE"
const SKIP := "SKIP"

const SYNERGY := "SYNERGY"
const NEUTRAL := "NEUTRAL"
const PIVOT := "PIVOT"

const SKIP_CONTENT_ID := "base.reward.skip"

var option_id: String
var kind: String
var content_id: String
var tile_id: String
var modifier_id: String
var target_instance_id: String
var context_bias: String
var gold_delta: int
var refinement_token_delta: int
var metadata: Dictionary

var option_kind: String:
	get:
		return kind

var bias: String:
	get:
		return context_bias

func _init(
	initial_option_id: String,
	initial_kind: String,
	initial_content_id: String = "",
	initial_tile_id: String = "",
	initial_modifier_id: String = "",
	initial_target_instance_id: String = "",
	initial_context_bias: String = NEUTRAL,
	initial_gold_delta: int = 0,
	initial_refinement_token_delta: int = 0,
	initial_metadata: Dictionary = {},
) -> void:
	option_id = initial_option_id
	kind = initial_kind
	content_id = initial_content_id
	tile_id = initial_tile_id
	modifier_id = initial_modifier_id
	target_instance_id = initial_target_instance_id
	context_bias = initial_context_bias
	gold_delta = initial_gold_delta
	refinement_token_delta = initial_refinement_token_delta
	metadata = initial_metadata.duplicate(true)

func is_skip() -> bool:
	return kind == SKIP

func is_acquisition() -> bool:
	return kind in [ADD_TILE, MODIFIED_TILE]

func to_dictionary() -> Dictionary:
	return {
		"option_id": option_id,
		"kind": kind,
		"content_id": content_id,
		"tile_id": tile_id,
		"modifier_id": modifier_id,
		"target_instance_id": target_instance_id,
		"context_bias": context_bias,
		"gold_delta": gold_delta,
		"refinement_token_delta": refinement_token_delta,
		"metadata": metadata.duplicate(true),
	}
