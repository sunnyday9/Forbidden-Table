class_name SuspendSnapshot
extends "res://src/infrastructure/persistence/snapshot_dto.gd"

const SAVE_KIND := "SUSPEND"
const SnapshotDtoScript = preload("res://src/infrastructure/persistence/snapshot_dto.gd")
const SuspendSnapshotScript = preload("res://src/infrastructure/persistence/suspend_snapshot.gd")

func _init(
	content_version: String = "",
	run_id: String = "",
	run_seed: int = 0,
	run_state: Dictionary = {},
	rng_state: Dictionary = {},
	checkpoint_metadata: Dictionary = {},
) -> void:
	super(SAVE_KIND, content_version, run_id, run_seed, run_state, rng_state, checkpoint_metadata)

static func from_dictionary(data: Dictionary):
	var snapshot = SuspendSnapshotScript.new(
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
