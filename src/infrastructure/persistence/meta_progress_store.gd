class_name MetaProgressStore
extends RefCounted

const CURRENT_SCHEMA_VERSION := 2
const CONTENT_VERSION := "alpha.meta.v1"
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")
const MetaProgressSnapshotScript = preload("res://src/infrastructure/persistence/meta_progress_snapshot.gd")
const MigrationPipelineScript = preload("res://src/infrastructure/persistence/migration_pipeline.gd")
const JsonIntegerCodecScript = preload("res://src/infrastructure/serialization/json_integer_codec.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")

var file_path: String

func _init(initial_file_path: String = "user://alpha_meta_progress.json") -> void:
	file_path = initial_file_path

func load_profile() -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"accepted": true, "state": MetaProgressStateScript.new(), "migrated": false, "created_default": true}
	var loaded := _read_profile()
	if loaded.get("accepted", false):
		return loaded
	var preservation := preserve_rejected_source()
	loaded["rejected_source_preserved"] = bool(preservation.get("accepted", false))
	loaded["preserved_path"] = str(preservation.get("path", ""))
	if not preservation.get("accepted", false):
		loaded["preservation_error"] = str(preservation.get("code", "META_PROGRESS_PRESERVE_FAILED"))
	return loaded

func _read_profile() -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"accepted": false, "code": "META_PROGRESS_READ_FAILED", "error": FileAccess.get_open_error()}
	var parsed := JsonIntegerCodecScript.parse(file.get_as_text())
	if not parsed.accepted or not parsed.data is Dictionary:
		return {"accepted": false, "code": str(parsed.get("code", "META_PROGRESS_PARSE_FAILED"))}
	var original_schema := int(parsed.data.get("schema_version", -1))
	var migration: Dictionary = _migration_pipeline().migrate(parsed.data)
	if not migration.accepted:
		return migration
	var data: Dictionary = migration.data
	var header_validation: Dictionary = _validate_header(data)
	if not header_validation.accepted:
		return header_validation
	var state_result: Dictionary = MetaProgressStateScript.from_dictionary(data.get("authoritative_state", {}))
	if not state_result.accepted:
		return state_result
	return {
		"accepted": true,
		"state": state_result.state,
		"migrated": original_schema != CURRENT_SCHEMA_VERSION,
		"created_default": false,
	}

func preserve_rejected_source() -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"accepted": false, "code": "REJECTED_SOURCE_MISSING"}
	var source_path := ProjectSettings.globalize_path(file_path)
	var preserved_path := "%s.rejected" % source_path
	var suffix := 1
	while FileAccess.file_exists(preserved_path):
		preserved_path = "%s.rejected.%d" % [source_path, suffix]
		suffix += 1
	var source := FileAccess.open(file_path, FileAccess.READ)
	if source == null:
		return {"accepted": false, "code": "META_PROGRESS_PRESERVE_READ_FAILED", "error": FileAccess.get_open_error()}
	var contents := source.get_buffer(source.get_length())
	source.close()
	var preserved := FileAccess.open(preserved_path, FileAccess.WRITE)
	if preserved == null:
		return {"accepted": false, "code": "META_PROGRESS_PRESERVE_WRITE_FAILED", "error": FileAccess.get_open_error()}
	preserved.store_buffer(contents)
	preserved.flush()
	preserved.close()
	var copy := FileAccess.open(preserved_path, FileAccess.READ)
	if copy == null or copy.get_length() != contents.size():
		if copy != null:
			copy.close()
		DirAccess.remove_absolute(preserved_path)
		return {"accepted": false, "code": "META_PROGRESS_PRESERVE_VERIFY_FAILED"}
	var preserved_contents := copy.get_buffer(copy.get_length())
	copy.close()
	if preserved_contents != contents:
		DirAccess.remove_absolute(preserved_path)
		return {"accepted": false, "code": "META_PROGRESS_PRESERVE_VERIFY_FAILED"}
	return {"accepted": true, "path": preserved_path}

func save_profile(state) -> Dictionary:
	if state == null or state is not MetaProgressStateScript:
		return {"accepted": false, "code": "INVALID_META_PROGRESS_STATE"}
	if state.is_test_profile():
		return {"accepted": false, "code": "TEST_PROFILE_CANNOT_BE_PERSISTED"}
	var validated: Dictionary = MetaProgressStateScript.from_dictionary(state.to_dictionary())
	if not validated.accepted:
		return validated
	var snapshot := MetaProgressSnapshotScript.new(
		"game.phase2.v1",
		CONTENT_VERSION,
		state.to_dictionary(),
	)
	var target_path := ProjectSettings.globalize_path(file_path)
	var temporary_path := "%s.tmp" % target_path
	var backup_path := "%s.bak" % target_path
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"accepted": false, "code": "META_PROGRESS_WRITE_FAILED", "error": FileAccess.get_open_error()}
	file.store_string(snapshot.serialize())
	file.flush()
	file.close()
	var has_previous := FileAccess.file_exists(target_path)
	if has_previous:
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		var backup_error := DirAccess.rename_absolute(target_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_path)
			return {"accepted": false, "code": "META_PROGRESS_BACKUP_FAILED", "error": backup_error}
	var rename_error := DirAccess.rename_absolute(temporary_path, target_path)
	if rename_error != OK:
		if has_previous:
			DirAccess.rename_absolute(backup_path, target_path)
		DirAccess.remove_absolute(temporary_path)
		return {"accepted": false, "code": "META_PROGRESS_COMMIT_FAILED", "error": rename_error}
	if has_previous:
		DirAccess.remove_absolute(backup_path)
	return {"accepted": true, "snapshot": snapshot}

func _migration_pipeline():
	var pipeline = MigrationPipelineScript.new(CURRENT_SCHEMA_VERSION)
	pipeline.register_migration(1, Callable(self, "_migrate_v1_to_v2"))
	return pipeline

func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var legacy_state: Variant = migrated.get("authoritative_state", migrated.get("run_state", {}))
	if not legacy_state is Dictionary:
		return {"accepted": false, "code": "INVALID_META_PROGRESS_STATE"}
	var state := MetaProgressStateScript.new()
	if legacy_state.has("unlocked") and not legacy_state.has("unlocked_character_ids"):
		var legacy_unlocked: Variant = legacy_state.get("unlocked", [])
		if not legacy_unlocked is Array:
			return {"accepted": false, "code": "INVALID_LEGACY_META_UNLOCKS"}
		for identifier_value in legacy_unlocked:
			var identifier := str(identifier_value)
			if Phase2CatalogScript.CHARACTER_IDS.has(identifier) or AlphaScaleCatalogScript.all_character_ids().has(identifier):
				if not state.discovered_character_ids.has(identifier):
					state.discovered_character_ids.append(identifier)
				if not state.unlocked_character_ids.has(identifier):
					state.unlocked_character_ids.append(identifier)
			elif Phase2CatalogScript.CONTRACT_IDS.has(identifier) or AlphaScaleCatalogScript.all_contract_ids().has(identifier):
				if not state.discovered_contract_ids.has(identifier):
					state.discovered_contract_ids.append(identifier)
				if not state.unlocked_contract_ids.has(identifier):
					state.unlocked_contract_ids.append(identifier)
			else:
				return {"accepted": false, "code": "INVALID_LEGACY_META_CONTENT_ID", "content_id": identifier}
	migrated["schema_version"] = CURRENT_SCHEMA_VERSION
	migrated["save_kind"] = MetaProgressSnapshotScript.SAVE_KIND
	migrated["content_version"] = CONTENT_VERSION
	migrated["authoritative_state"] = state.to_dictionary()
	migrated["run_state"] = state.to_dictionary()
	return migrated

func _validate_header(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", -1)) != CURRENT_SCHEMA_VERSION:
		return {"accepted": false, "code": "UNSUPPORTED_SCHEMA_VERSION"}
	if str(data.get("save_kind", "")) != MetaProgressSnapshotScript.SAVE_KIND:
		return {"accepted": false, "code": "INVALID_SAVE_KIND"}
	if str(data.get("game_version", "")) != "game.phase2.v1":
		return {"accepted": false, "code": "UNSUPPORTED_GAME_VERSION"}
	if str(data.get("content_version", "")) != CONTENT_VERSION:
		return {"accepted": false, "code": "UNSUPPORTED_CONTENT_VERSION"}
	if not data.get("authoritative_state", {}) is Dictionary:
		return {"accepted": false, "code": "INVALID_META_PROGRESS_STATE"}
	return {"accepted": true}
