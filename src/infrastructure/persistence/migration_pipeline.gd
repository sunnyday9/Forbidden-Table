class_name MigrationPipeline
extends RefCounted

var current_schema_version: int
var _migrations: Dictionary

func _init(initial_current_schema_version: int = 1) -> void:
	current_schema_version = initial_current_schema_version
	_migrations = {}

func register_migration(from_version: int, migration: Callable) -> void:
	_migrations[from_version] = migration
	current_schema_version = maxi(current_schema_version, from_version + 1)

func migrate(parsed_data: Dictionary) -> Dictionary:
	var data := parsed_data.duplicate(true)
	var version := int(data.get("schema_version", -1))
	if version < 1 or version > current_schema_version:
		return _rejected("UNSUPPORTED_SCHEMA_VERSION", {"schema_version": version})
	while version < current_schema_version:
		if not _migrations.has(version):
			return _rejected("MISSING_SCHEMA_MIGRATION", {"from_version": version, "to_version": version + 1})
		var migrated = _migrations[version].call(data)
		if not migrated is Dictionary:
			return _rejected("INVALID_SCHEMA_MIGRATION", {"from_version": version})
		data = migrated
		var next_version := int(data.get("schema_version", -1))
		if next_version != version + 1:
			return _rejected("NON_SEQUENTIAL_SCHEMA_MIGRATION", {"from_version": version, "actual_version": next_version})
		version = next_version
	return {"accepted": true, "data": data}

func _rejected(code: String, details: Dictionary) -> Dictionary:
	return {"accepted": false, "code": code, "details": details.duplicate(true)}
