class_name BattleSnapshot
extends "res://src/infrastructure/persistence/snapshot_dto.gd"

const SAVE_KIND := "BATTLE"
const SnapshotDtoScript = preload("res://src/infrastructure/persistence/snapshot_dto.gd")
const BattleSnapshotScript = preload("res://src/infrastructure/persistence/battle_snapshot.gd")

func _init(content_version: String = "", run_id: String = "", run_seed: int = 0, battle_state: Dictionary = {}, rng_state: Dictionary = {}, checkpoint_metadata: Dictionary = {}) -> void:
	super(SAVE_KIND, content_version, run_id, run_seed, battle_state, rng_state, checkpoint_metadata)

static func from_dictionary(data: Dictionary):
	var snapshot = BattleSnapshotScript.new(
		str(data.get("content_version", "")),
		str(data.get("run_id", "")),
		int(data.get("run_seed", 0)),
		(data.get("authoritative_state", data.get("run_state", {})) as Dictionary),
		(data.get("rng_state", {}) as Dictionary),
		(data.get("checkpoint_metadata", {}) as Dictionary),
	)
	snapshot.schema_version = int(data.get("schema_version", SnapshotDtoScript.SCHEMA_VERSION))
	snapshot.game_version = str(data.get("game_version", SnapshotDtoScript.GAME_VERSION))
	return snapshot
