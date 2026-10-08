extends SceneTree

const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const MetaProgressSnapshotScript = preload("res://src/infrastructure/persistence/meta_progress_snapshot.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")
const SnapshotDtoScript = preload("res://src/infrastructure/persistence/snapshot_dto.gd")

func _init() -> void:
	call_deferred("_emit_release_metadata")

func _emit_release_metadata() -> void:
	var registry = ContentRegistryScript.new()
	var reports: Array = [
		Phase2CatalogScript.register_all(registry),
		AlphaActTwoCatalogScript.register_all(registry),
		AlphaScaleCatalogScript.register_all(registry),
	]
	for report in reports:
		if report == null or not report.is_valid():
			push_error("Cannot emit release metadata for an invalid content catalog.")
			quit(1)
			return

	var metadata := {
		"application_version": str(ProjectSettings.get_setting("application/config/version", "unknown")),
		"content_version": registry.content_version(),
		"game_version": SnapshotDtoScript.GAME_VERSION,
		"replay_game_version": ReplayRecordScript.GAME_VERSION,
		"save_schema_versions": {
			"suspend_snapshot": SnapshotDtoScript.SCHEMA_VERSION,
			"meta_progress": MetaProgressSnapshotScript.CURRENT_SCHEMA_VERSION,
		},
		"replay_schema_version": ReplayRecordScript.SCHEMA_VERSION,
	}
	print("RELEASE_METADATA_JSON:" + JSON.stringify(metadata))
	quit(0)
