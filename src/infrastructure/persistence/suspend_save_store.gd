class_name SuspendSaveStore
extends RefCounted

const SuspendSnapshotScript = preload("res://src/infrastructure/persistence/suspend_snapshot.gd")

var file_path: String
var _validated_run_id := ""

func _init(initial_file_path: String = "user://alpha_suspend.json") -> void:
	file_path = initial_file_path

func read_source() -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var temporary_path := "%s.tmp" % absolute_path
	var backup_path := "%s.bak" % absolute_path
	var source_path := absolute_path
	var source_role := "MAIN"
	if FileAccess.file_exists(absolute_path):
		if FileAccess.file_exists(temporary_path):
			# Both files can represent different accepted checkpoints. Do not guess
			# which one is newer or delete the temp before semantic validation.
			return {
				"accepted": false,
				"exists": true,
				"preserve_required": true,
				"code": "SUSPEND_COMMIT_INTERRUPTED",
				"path": file_path,
			}
	elif FileAccess.file_exists(temporary_path):
		# A temp without a primary is only a candidate. The caller validates it
		# with SaveMapper before finalize_load promotes it over any old backup.
		source_path = temporary_path
		source_role = "TEMP"
	elif FileAccess.file_exists(backup_path):
		return {
			"accepted": false,
			"exists": true,
			"preserve_required": true,
			"code": "SUSPEND_COMMIT_INTERRUPTED",
			"path": file_path,
		}
	else:
		return {"accepted": true, "exists": false, "path": file_path}
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {"accepted": false, "exists": true, "preserve_required": true, "code": "SUSPEND_READ_FAILED", "error": FileAccess.get_open_error(), "path": file_path}
	var contents := file.get_as_text()
	file.close()
	return {
		"accepted": true,
		"exists": true,
		"contents": contents,
		"path": file_path,
		"source_role": source_role,
		"has_interrupted_commit": FileAccess.file_exists(temporary_path) or FileAccess.file_exists(backup_path),
	}

func finalize_load(source: Dictionary, run_id: String) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var temporary_path := "%s.tmp" % absolute_path
	var backup_path := "%s.bak" % absolute_path
	if str(source.get("source_role", "MAIN")) == "TEMP":
		var promote_error := DirAccess.rename_absolute(temporary_path, absolute_path)
		var used_backup := false
		if promote_error != OK and FileAccess.file_exists(absolute_path):
			# Keep the prior recovery data until the candidate has passed semantic
			# validation (this method is called only after SaveMapper accepts it).
			if FileAccess.file_exists(backup_path):
				return {"accepted": false, "code": "SUSPEND_RECOVERY_BACKUP_EXISTS", "path": file_path}
			var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
			if backup_error != OK:
				return {"accepted": false, "code": "SUSPEND_RECOVERY_BACKUP_FAILED", "error": backup_error, "path": file_path}
			used_backup = true
			promote_error = DirAccess.rename_absolute(temporary_path, absolute_path)
		if promote_error != OK:
			if used_backup:
				DirAccess.rename_absolute(backup_path, absolute_path)
			return {"accepted": false, "code": "SUSPEND_RECOVERY_PROMOTE_FAILED", "error": promote_error, "path": file_path}
	var cleanup_warnings := PackedStringArray()
	for stale_path in [temporary_path, backup_path]:
		if FileAccess.file_exists(stale_path):
			var cleanup_error := DirAccess.remove_absolute(stale_path)
			if cleanup_error != OK and FileAccess.file_exists(stale_path):
				cleanup_warnings.append(stale_path)
	_validated_run_id = run_id
	var result := {"accepted": true, "path": file_path}
	if not cleanup_warnings.is_empty():
		result["cleanup_warning"] = "SUSPEND_RECOVERY_CLEANUP_FAILED"
		result["remaining_paths"] = Array(cleanup_warnings)
	return result

func _source_exists() -> bool:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	return FileAccess.file_exists(absolute_path) or FileAccess.file_exists("%s.tmp" % absolute_path) or FileAccess.file_exists("%s.bak" % absolute_path)

func write_snapshot(snapshot) -> Dictionary:
	if snapshot == null or snapshot is not SuspendSnapshotScript:
		return {"accepted": false, "code": "INVALID_SUSPEND_SNAPSHOT"}
	if str(snapshot.save_kind) != SuspendSnapshotScript.SAVE_KIND:
		return {"accepted": false, "code": "INVALID_SUSPEND_SAVE_KIND"}
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var directory_path := absolute_path.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(directory_path)
	if mkdir_error != OK and not DirAccess.dir_exists_absolute(directory_path):
		return {"accepted": false, "code": "SUSPEND_DIRECTORY_CREATE_FAILED", "error": mkdir_error}
	var temporary_path := "%s.tmp" % absolute_path
	var backup_path := "%s.bak" % absolute_path
	if _source_exists():
		if not FileAccess.file_exists(absolute_path) or _validated_run_id != str(snapshot.run_id):
			return {"accepted": false, "code": "SUSPEND_RECOVERY_REQUIRED", "path": file_path}
		if FileAccess.file_exists(temporary_path) or FileAccess.file_exists(backup_path):
			# Do not discard an interrupted checkpoint from an earlier accepted
			# action just because this process still recognizes the Run ID.
			return {"accepted": false, "code": "SUSPEND_RECOVERY_REQUIRED", "path": file_path}
	var serialized: String = snapshot.serialize()
	var temporary_file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if temporary_file == null:
		return {"accepted": false, "code": "SUSPEND_WRITE_FAILED", "error": FileAccess.get_open_error()}
	temporary_file.store_string(serialized)
	temporary_file.flush()
	var write_error := temporary_file.get_error()
	temporary_file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return {"accepted": false, "code": "SUSPEND_WRITE_FAILED", "error": write_error}
	var verify_file := FileAccess.open(temporary_path, FileAccess.READ)
	if verify_file == null:
		DirAccess.remove_absolute(temporary_path)
		return {"accepted": false, "code": "SUSPEND_VERIFY_READ_FAILED", "error": FileAccess.get_open_error()}
	var verified_bytes := verify_file.get_buffer(verify_file.get_length())
	verify_file.close()
	if verified_bytes.get_string_from_utf8() != serialized:
		DirAccess.remove_absolute(temporary_path)
		return {"accepted": false, "code": "SUSPEND_VERIFY_MISMATCH"}
	var commit_error := DirAccess.rename_absolute(temporary_path, absolute_path)
	var used_backup := false
	if commit_error != OK and FileAccess.file_exists(absolute_path):
		if FileAccess.file_exists(backup_path):
			return {"accepted": false, "code": "SUSPEND_RECOVERY_REQUIRED", "path": file_path}
		var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
		if backup_error != OK:
			return {"accepted": false, "code": "SUSPEND_RECOVERY_REQUIRED", "error": backup_error, "path": file_path}
		used_backup = true
		commit_error = DirAccess.rename_absolute(temporary_path, absolute_path)
	if commit_error != OK:
		var restore_error := OK
		if used_backup:
			restore_error = DirAccess.rename_absolute(backup_path, absolute_path)
		# Keep the temp candidate even when restore succeeds. It may contain the
		# newest accepted checkpoint; the next launch fails closed on both sources.
		return {"accepted": false, "code": "SUSPEND_RECOVERY_REQUIRED", "error": commit_error, "restore_error": restore_error, "path": file_path}
	if used_backup and FileAccess.file_exists(backup_path):
		var backup_cleanup_error := DirAccess.remove_absolute(backup_path)
		if backup_cleanup_error != OK and FileAccess.file_exists(backup_path):
			_validated_run_id = str(snapshot.run_id)
			return {"accepted": true, "path": file_path, "snapshot": snapshot, "cleanup_warning": "SUSPEND_BACKUP_CLEANUP_FAILED", "error": backup_cleanup_error}
	_validated_run_id = str(snapshot.run_id)
	return {"accepted": true, "path": file_path, "snapshot": snapshot}

func preserve_source() -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var source_paths: Array[String] = []
	for candidate in [absolute_path, "%s.tmp" % absolute_path, "%s.bak" % absolute_path]:
		if FileAccess.file_exists(candidate):
			source_paths.append(candidate)
	if source_paths.is_empty():
		return {"accepted": false, "code": "SUSPEND_SOURCE_MISSING"}
	var preserved_paths := PackedStringArray()
	var preserved_sidecar_count := 0
	for source_path in source_paths:
		var preserved_path := "%s.rejected" % absolute_path
		if source_path != absolute_path:
			preserved_sidecar_count += 1
			preserved_path = "%s.rejected.%d" % [absolute_path, preserved_sidecar_count]
		var suffix := 1
		var base_path := preserved_path
		while FileAccess.file_exists(preserved_path):
			preserved_path = "%s.%d" % [base_path, suffix]
			suffix += 1
		var source := FileAccess.open(source_path, FileAccess.READ)
		if source == null:
			return {"accepted": false, "code": "SUSPEND_PRESERVE_READ_FAILED", "error": FileAccess.get_open_error(), "path": source_path}
		var contents := source.get_buffer(source.get_length())
		source.close()
		var preserved := FileAccess.open(preserved_path, FileAccess.WRITE)
		if preserved == null:
			return {"accepted": false, "code": "SUSPEND_PRESERVE_WRITE_FAILED", "error": FileAccess.get_open_error(), "path": preserved_path}
		preserved.store_buffer(contents)
		preserved.flush()
		var preserve_error := preserved.get_error()
		preserved.close()
		if preserve_error != OK:
			return {"accepted": false, "code": "SUSPEND_PRESERVE_WRITE_FAILED", "error": preserve_error, "path": preserved_path}
		var copy := FileAccess.open(preserved_path, FileAccess.READ)
		if copy == null:
			return {"accepted": false, "code": "SUSPEND_PRESERVE_VERIFY_FAILED", "error": FileAccess.get_open_error(), "path": preserved_path}
		var preserved_contents := copy.get_buffer(copy.get_length())
		copy.close()
		if preserved_contents != contents:
			return {"accepted": false, "code": "SUSPEND_PRESERVE_VERIFY_FAILED", "path": preserved_path}
		preserved_paths.append(preserved_path)
	return {"accepted": true, "path": preserved_paths[0], "paths": Array(preserved_paths)}

func clear() -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	for path in [absolute_path, "%s.tmp" % absolute_path, "%s.bak" % absolute_path]:
		if not FileAccess.file_exists(path):
			continue
		var error := DirAccess.remove_absolute(path)
		if error != OK and FileAccess.file_exists(path):
			return {"accepted": false, "code": "SUSPEND_CLEAR_FAILED", "error": error, "path": file_path}
	_validated_run_id = ""
	return {"accepted": true, "path": file_path}
