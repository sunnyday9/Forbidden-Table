class_name RewardPoolDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var entries: Array
@export var pool_kind: String

const REWARD := "REWARD"
const SHOP := "SHOP"
const WORKSHOP := "WORKSHOP"
const VALID_POOL_KINDS := [REWARD, SHOP, WORKSHOP]

func _init(definition_id: String = "", pool_entries: Array = [], references: Array[String] = [], kind: String = REWARD) -> void:
	var entry_references := references.duplicate()
	entries = pool_entries.duplicate(true)
	pool_kind = kind
	for entry in entries:
		if entry is Dictionary and entry.has("content_id"):
			entry_references.append(str(entry["content_id"]))
	super(definition_id, entry_references)

func definition_type_name() -> String:
	return "RewardPoolDefinition"

func expected_id_families() -> Array[String]:
	return ["reward_pool", "shop_pool", "workshop_pool"]

func validate():
	var report = super.validate()
	if entries.is_empty():
		report.add_issue(_issue("missing_reward_entries", "RewardPoolDefinition must declare at least one weighted entry."))
	if not VALID_POOL_KINDS.has(pool_kind):
		report.add_issue(_issue("invalid_pool_kind", "Content pools must declare a supported pool kind."))
	var family: String = content_id.get_slice(".", 1)
	var expected_family: String = {
		REWARD: "reward_pool",
		SHOP: "shop_pool",
		WORKSHOP: "workshop_pool",
	}.get(pool_kind, "")
	if not expected_family.is_empty() and family != expected_family:
		report.add_issue(_issue("invalid_pool_family", "Pool ID family must match its declared pool kind."))
	var entry_ids: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary or str(entry.get("content_id", "")).is_empty() or int(entry.get("weight", 0)) <= 0:
			report.add_issue(_issue("invalid_reward_entry", "RewardPoolDefinition entries require a content ID and positive weight."))
			continue
		var entry_id := str(entry["content_id"])
		if entry_ids.has(entry_id):
			report.add_issue(_issue("duplicate_pool_entry", "Content pool membership IDs must be unique.", entry_id))
		entry_ids[entry_id] = true
	return report

func entry_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		if entry is Dictionary and not str(entry.get("content_id", "")).is_empty():
			ids.append(str(entry["content_id"]))
	ids.sort()
	return ids
