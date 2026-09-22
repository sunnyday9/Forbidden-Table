class_name YakuDefinition
extends "res://src/content/definitions/content_definition.gd"

const LOCAL_SETTLEMENT := "LOCAL_SETTLEMENT"
const COMPLETE_HAND := "COMPLETE_HAND"
const BOTH := "BOTH"

const STRUCTURAL := "STRUCTURAL"
const SUIT_HONOR := "SUIT_HONOR"
const COMPLETE_HAND_FAMILY := "COMPLETE_HAND"
const ROGUELIKE_STRUCTURAL := "ROGUELIKE_STRUCTURAL"

const PATTERN_COUNT := "PATTERN_COUNT"
const TILE_CONDITION := "TILE_CONDITION"
const SUIT_CONCENTRATION := "SUIT_CONCENTRATION"
const COMPLETE_HAND_MODEL := "COMPLETE_HAND"
const GROUP_SHAPE := "GROUP_SHAPE"

const VALID_SCOPES := [LOCAL_SETTLEMENT, COMPLETE_HAND, BOTH]
const VALID_FAMILIES := [STRUCTURAL, SUIT_HONOR, COMPLETE_HAND_FAMILY, ROGUELIKE_STRUCTURAL]
const VALID_PROGRESS_MODELS := [PATTERN_COUNT, TILE_CONDITION, SUIT_CONCENTRATION, COMPLETE_HAND_MODEL, GROUP_SHAPE]

@export var display_name: String
@export var scope: String
@export var family: String
@export var progress_model: String
@export var progress_config: Dictionary
@export var local_score: Dictionary
@export var complete_score: Dictionary

func _init(
	definition_id: String = "",
	definition_name: String = "",
	definition_scope: String = BOTH,
	definition_family: String = STRUCTURAL,
	definition_progress_model: String = PATTERN_COUNT,
	definition_progress_config: Dictionary = {},
	definition_local_score: Dictionary = {},
	definition_complete_score: Dictionary = {},
) -> void:
	super(definition_id)
	display_name = definition_name
	scope = definition_scope
	family = definition_family
	progress_model = definition_progress_model
	progress_config = definition_progress_config.duplicate(true)
	local_score = definition_local_score.duplicate(true)
	complete_score = definition_complete_score.duplicate(true)

func validate():
	var report = super.validate()
	if not VALID_SCOPES.has(scope):
		report.add_issue(_issue("invalid_yaku_scope", "YakuDefinition must declare a supported scope."))
	if not VALID_FAMILIES.has(family):
		report.add_issue(_issue("invalid_yaku_family", "YakuDefinition must declare a supported family."))
	if not VALID_PROGRESS_MODELS.has(progress_model):
		report.add_issue(_issue("invalid_yaku_progress_model", "YakuDefinition must declare a supported progress model."))
	if display_name.is_empty():
		report.add_issue(_issue("missing_yaku_name", "YakuDefinition must declare a display name."))
	return report

func _issue(code: String, message: String):
	const ContentValidationIssueScript = preload("res://src/content/validation/content_validation_issue.gd")
	return ContentValidationIssueScript.new(code, content_id, message)
