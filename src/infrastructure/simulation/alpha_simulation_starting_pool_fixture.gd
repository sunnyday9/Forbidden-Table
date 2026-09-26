class_name AlphaSimulationStartingPoolFixture
extends RefCounted

const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const RunStartingPoolFactoryScript = preload("res://src/domain/run/run_starting_pool_factory.gd")

const FIXTURE_ID := "phase2.character_biased_complete_hand.v1"
const TILE_COUNT := 14

static func tile_definition_ids(character_tile_bias_ids: Array) -> Array[String]:
	return RunStartingPoolFactoryScript.tile_definition_ids(character_tile_bias_ids)

static func create(character_id: String, character_tile_bias_ids: Array) -> Array:
	return RunStartingPoolFactoryScript.create(character_id, character_tile_bias_ids)

static func hash(character_id: String, character_tile_bias_ids: Array) -> String:
	return DeterministicSerializerScript.hash({
		"fixture_id": FIXTURE_ID,
		"character_id": character_id,
		"tile_definition_ids": tile_definition_ids(character_tile_bias_ids),
	})
