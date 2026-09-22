class_name RewardPoolDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var entries: Array

func _init(definition_id: String = "", pool_entries: Array = [], references: Array[String] = []) -> void:
	var entry_references := references.duplicate()
	entries = pool_entries.duplicate(true)
	for entry in entries:
		if entry is Dictionary and entry.has("content_id"):
			entry_references.append(str(entry["content_id"]))
	super(definition_id, entry_references)

func definition_type_name() -> String:
	return "RewardPoolDefinition"

func expected_id_families() -> Array[String]:
	return ["reward_pool"]

func validate():
	var report = super.validate()
	if entries.is_empty():
		report.add_issue(_issue("missing_reward_entries", "RewardPoolDefinition must declare at least one weighted entry."))
	for entry in entries:
		if not entry is Dictionary or str(entry.get("content_id", "")).is_empty() or int(entry.get("weight", 0)) <= 0:
			report.add_issue(_issue("invalid_reward_entry", "RewardPoolDefinition entries require a content ID and positive weight."))
	return report
