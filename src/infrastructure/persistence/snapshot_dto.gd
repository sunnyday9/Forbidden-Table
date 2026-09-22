class_name SnapshotDto
extends RefCounted

const SCHEMA_VERSION := 1
const GAME_VERSION := "game.phase2.v1"
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")

var schema_version: int
var game_version: String
var content_version: String
var save_kind: String
var run_id: String
var run_seed: int
var authoritative_state: Dictionary
var rng_state: Dictionary
var checkpoint_metadata: Dictionary

func _init(
	initial_save_kind: String,
	initial_content_version: String,
	initial_run_id: String = "",
	initial_run_seed: int = 0,
	initial_authoritative_state: Dictionary = {},
	initial_rng_state: Dictionary = {},
	initial_checkpoint_metadata: Dictionary = {},
	initial_game_version: String = GAME_VERSION,
) -> void:
	schema_version = SCHEMA_VERSION
	game_version = initial_game_version
	content_version = initial_content_version
	save_kind = initial_save_kind
	run_id = initial_run_id
	run_seed = initial_run_seed
	authoritative_state = initial_authoritative_state.duplicate(true)
	rng_state = initial_rng_state.duplicate(true)
	checkpoint_metadata = initial_checkpoint_metadata.duplicate(true)

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"game_version": game_version,
		"content_version": content_version,
		"save_kind": save_kind,
		"run_id": run_id,
		"run_seed": run_seed,
		"run_state": authoritative_state.duplicate(true),
		"authoritative_state": authoritative_state.duplicate(true),
		"rng_state": rng_state.duplicate(true),
		"checkpoint_metadata": checkpoint_metadata.duplicate(true),
	}

func serialize() -> String:
	return DeterministicSerializerScript.serialize(to_dictionary())

func state_hash() -> String:
	return DeterministicSerializerScript.hash(authoritative_state)
