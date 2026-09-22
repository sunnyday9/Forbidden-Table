class_name RunRecord
extends "res://src/infrastructure/persistence/snapshot_dto.gd"

const SAVE_KIND := "RUN_RECORD"
const SnapshotDtoScript = preload("res://src/infrastructure/persistence/snapshot_dto.gd")
const RunRecordScript = preload("res://src/infrastructure/persistence/run_record.gd")

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
	var record = RunRecordScript.new(
		str(data.get("content_version", "")),
		str(data.get("run_id", "")),
		int(data.get("run_seed", 0)),
		(data.get("authoritative_state", data.get("run_state", {})) as Dictionary),
		(data.get("rng_state", {}) as Dictionary),
		(data.get("checkpoint_metadata", {}) as Dictionary),
	)
	record.schema_version = int(data.get("schema_version", SnapshotDtoScript.SCHEMA_VERSION))
	record.game_version = str(data.get("game_version", SnapshotDtoScript.GAME_VERSION))
	return record
