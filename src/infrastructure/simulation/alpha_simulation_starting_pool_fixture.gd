class_name AlphaSimulationStartingPoolFixture
extends RefCounted

const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const RunStartingPoolFactoryScript = preload("res://src/domain/run/run_starting_pool_factory.gd")

const FIXTURE_ID := "phase2.character_choice_starting_pool.v2"
const LEGACY_FIXTURE_ID := "phase2.character_biased_complete_hand.v1"
const TILE_COUNT := RunStartingPoolFactoryScript.SEQUENCE_TILE_COUNT
const LEGACY_TILE_COUNT := RunStartingPoolFactoryScript.LEGACY_TILE_COUNT

static func tile_definition_ids(character_id: String, character_tile_bias_ids: Array, excluded_suit: String = "") -> Array[String]:
	return RunStartingPoolFactoryScript.starting_tile_definition_ids(character_id, character_tile_bias_ids, _effective_excluded_suit(character_id, excluded_suit))

static func create(character_id: String, character_tile_bias_ids: Array, excluded_suit: String = "") -> Array:
	return RunStartingPoolFactoryScript.create_for_character(character_id, character_tile_bias_ids, _effective_excluded_suit(character_id, excluded_suit))

static func hash(character_id: String, character_tile_bias_ids: Array, excluded_suit: String = "") -> String:
	var resolved_excluded_suit := _effective_excluded_suit(character_id, excluded_suit)
	return DeterministicSerializerScript.hash({
		"fixture_id": FIXTURE_ID,
		"character_id": character_id,
		"excluded_suit": resolved_excluded_suit,
		"tile_definition_ids": tile_definition_ids(character_id, character_tile_bias_ids, resolved_excluded_suit),
	})

static func legacy_v1_tile_definition_ids(character_tile_bias_ids: Array) -> Array[String]:
	return RunStartingPoolFactoryScript.tile_definition_ids(character_tile_bias_ids)

static func legacy_v1_create(character_id: String, character_tile_bias_ids: Array) -> Array:
	return RunStartingPoolFactoryScript.create(character_id, character_tile_bias_ids)

static func legacy_v1_hash(character_id: String, character_tile_bias_ids: Array) -> String:
	return DeterministicSerializerScript.hash({
		"fixture_id": LEGACY_FIXTURE_ID,
		"character_id": character_id,
		"tile_definition_ids": legacy_v1_tile_definition_ids(character_tile_bias_ids),
	})

static func _effective_excluded_suit(character_id: String, excluded_suit: String) -> String:
	if character_id != RunStartingPoolFactoryScript.RESERVE_CHARACTER_ID:
		return ""
	return excluded_suit if not excluded_suit.is_empty() else RunStartingPoolFactoryScript.DEFAULT_RESERVE_EXCLUDED_SUIT
