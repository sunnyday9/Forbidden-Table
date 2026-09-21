class_name DomainSmokeScenario
extends RefCounted

const TILE_DEFINITION_ID := "base.tile.man.5"
const TILE_INSTANCE_ID := "smoke.tile_instance.1"

func run() -> Dictionary:
	var tile_definition := {
		"content_id": TILE_DEFINITION_ID,
		"suit": "characters",
		"rank": 5,
	}
	var definition_snapshot: Dictionary = tile_definition.duplicate(true)
	var tile_instance := {
		"instance_id": TILE_INSTANCE_ID,
		"definition_id": tile_definition["content_id"],
		"zone": "hand",
	}

	var definition_is_unchanged := tile_definition == definition_snapshot
	var runtime_state_is_separate := not tile_definition.has("zone")
	var instance_has_stable_identity: bool = tile_instance["definition_id"] == TILE_DEFINITION_ID

	return {
		"passed": definition_is_unchanged and runtime_state_is_separate and instance_has_stable_identity,
		"definition_id": tile_definition["content_id"],
		"instance_id": tile_instance["instance_id"],
		"zone": tile_instance["zone"],
	}
