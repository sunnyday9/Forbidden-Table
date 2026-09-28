class_name MetaProgressSnapshot
extends "res://src/infrastructure/persistence/snapshot_dto.gd"

const SAVE_KIND := "META_PROGRESS"
const CURRENT_SCHEMA_VERSION := 2
const SnapshotDtoScript = preload("res://src/infrastructure/persistence/snapshot_dto.gd")
const MetaProgressSnapshotScript = preload("res://src/infrastructure/persistence/meta_progress_snapshot.gd")

func _init(game_version: String = SnapshotDtoScript.GAME_VERSION, content_version: String = "", meta_state: Dictionary = {}) -> void:
	super(SAVE_KIND, content_version, "", 0, meta_state, {}, {"stable_boundary": "META_PROGRESS"}, game_version)
	schema_version = CURRENT_SCHEMA_VERSION

static func from_dictionary(data: Dictionary):
	var snapshot = MetaProgressSnapshotScript.new(
		str(data.get("game_version", SnapshotDtoScript.GAME_VERSION)),
		str(data.get("content_version", "")),
		(data.get("authoritative_state", data.get("run_state", {})) as Dictionary),
	)
	snapshot.schema_version = int(data.get("schema_version", CURRENT_SCHEMA_VERSION))
	snapshot.run_id = str(data.get("run_id", ""))
	snapshot.run_seed = int(data.get("run_seed", 0))
	snapshot.rng_state = (data.get("rng_state", {}) as Dictionary).duplicate(true)
	snapshot.checkpoint_metadata = (data.get("checkpoint_metadata", {}) as Dictionary).duplicate(true)
	return snapshot
