class_name EventDefinition
extends "res://src/content/definitions/content_definition.gd"

const PHASE_2_EVENT_IDS := [
	"base.event.tile_surgery",
	"base.event.risk_bargain",
	"base.event.gold_exchange",
	"base.event.map_reveal",
	"base.event.contract_clause",
	"base.event.rule_memory",
]

const PHASE_2_EVENT_CONTRACTS := {
	"base.event.tile_surgery": {"minimum_choice_count": 2, "systemic_trade": true, "tradeoff_family": "REFINEMENT", "required_behavior": "refinement trade"},
	"base.event.risk_bargain": {"minimum_choice_count": 2, "systemic_trade": true, "tradeoff_family": "RISK_REWARD", "required_behavior": "immediate risk for a stronger future reward"},
	"base.event.gold_exchange": {"minimum_choice_count": 2, "systemic_trade": true, "tradeoff_family": "ECONOMY", "required_behavior": "Gold or resource opportunity cost"},
	"base.event.map_reveal": {"minimum_choice_count": 2, "systemic_trade": true, "tradeoff_family": "INFORMATION", "required_behavior": "deterministic information gain"},
	"base.event.contract_clause": {"minimum_choice_count": 2, "systemic_trade": true, "tradeoff_family": "CONTRACT", "required_behavior": "temporary or run-scoped modifier"},
	"base.event.rule_memory": {"minimum_choice_count": 2, "systemic_trade": true, "tradeoff_family": "RULE_MEMORY", "required_behavior": "rare rule or Yaku-oriented choice"},
}

@export var choices: Array

func _init(definition_id: String = "", event_choices: Array = [], references: Array[String] = []) -> void:
	var choice_references := references.duplicate()
	choices = event_choices.duplicate(true)
	for choice in choices:
		if choice is Dictionary and choice.has("content_id"):
			choice_references.append(str(choice["content_id"]))
	super(definition_id, choice_references)

func definition_type_name() -> String:
	return "EventDefinition"

func expected_id_families() -> Array[String]:
	return ["event"]

func choice_by_id(choice_id: String):
	for choice in choices:
		if choice is Dictionary and str(choice.get("choice_id", "")) == choice_id:
			return choice
	return null

func legal_choice_ids() -> Array[String]:
	var ids: Array[String] = []
	for choice in choices:
		if choice is Dictionary:
			var choice_id := str(choice.get("choice_id", ""))
			if not choice_id.is_empty():
				ids.append(choice_id)
	return ids

static func phase_2_content_contracts() -> Array[Dictionary]:
	var contracts: Array[Dictionary] = []
	for event_id in PHASE_2_EVENT_IDS:
		var contract: Dictionary = PHASE_2_EVENT_CONTRACTS[event_id].duplicate(true)
		contract["event_id"] = event_id
		contracts.append(contract)
	return contracts

func validate():
	var report = super.validate()
	var has_explicit_leave := false
	var choice_ids: Dictionary = {}
	for choice in choices:
		if not choice is Dictionary or str(choice.get("choice_id", "")).is_empty():
			report.add_issue(_issue("invalid_event_choice", "EventDefinition choices require stable choice IDs."))
			continue
		var choice_id := str(choice["choice_id"])
		if choice_id.to_lower() in ["skip", "leave"] or bool(choice.get("is_skip", false)):
			has_explicit_leave = true
		if choice_ids.has(choice_id):
			report.add_issue(_issue("duplicate_event_choice", "EventDefinition choice IDs must be unique.", choice_id))
		choice_ids[choice_id] = true
		var choice_effects = choice.get("effects", [])
		if not choice_effects is Array:
			report.add_issue(_issue("invalid_event_effects", "EventDefinition choice effects must be an Array.", choice_id))
		var alternatives = choice.get("alternatives", [])
		if not alternatives is Array:
			report.add_issue(_issue("invalid_event_alternatives", "EventDefinition choice alternatives must be an Array.", choice_id))
			continue
		var alternative_ids: Dictionary = {}
		for alternative in alternatives:
			if not alternative is Dictionary or str(alternative.get("alternative_id", "")).is_empty() or int(alternative.get("weight", 0)) <= 0:
				report.add_issue(_issue("invalid_event_alternative", "EventDefinition alternatives require a stable ID and positive weight.", choice_id))
				continue
			var alternative_id := str(alternative["alternative_id"])
			if alternative_ids.has(alternative_id):
				report.add_issue(_issue("duplicate_event_alternative", "EventDefinition alternative IDs must be unique within a choice.", alternative_id))
			alternative_ids[alternative_id] = true
			if not alternative.get("effects", []) is Array:
				report.add_issue(_issue("invalid_event_effects", "EventDefinition alternative effects must be an Array.", alternative_id))
	if choices.size() < 2 and not has_explicit_leave:
		report.add_issue(_issue("insufficient_event_choices", "EventDefinition must declare at least two legal choices or an explicit Skip/Leave choice."))
	return report
