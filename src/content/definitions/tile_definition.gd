class_name TileDefinition
extends "res://src/content/definitions/content_definition.gd"

const TileValidationIssueScript = preload("res://src/content/validation/content_validation_issue.gd")

@export var suit: String
@export var rank: int

func _init(definition_id: String = "", tile_suit: String = "", tile_rank: int = 0) -> void:
	super(definition_id)
	suit = tile_suit
	rank = tile_rank

func definition_type_name() -> String:
	return "TileDefinition"

func expected_id_families() -> Array[String]:
	return ["tile"]

func validate():
	var report = super.validate()
	var valid_suits := ["characters", "bamboo", "dots", "honors"]
	if not valid_suits.has(suit):
		report.add_issue(TileValidationIssueScript.new(
			"invalid_tile_suit",
			content_id,
			"TileDefinition must use a supported suit."
		))
	elif suit == "honors" and rank != 0:
		report.add_issue(TileValidationIssueScript.new(
			"invalid_honor_rank",
			content_id,
			"Honor TileDefinitions must not have a numeric rank."
		))
	elif suit != "honors" and (rank < 1 or rank > 9):
		report.add_issue(TileValidationIssueScript.new(
			"invalid_tile_rank",
			content_id,
			"Suited TileDefinitions must have a rank from 1 through 9."
		))
	return report
