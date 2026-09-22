class_name ContractDefinition
extends "res://src/content/definitions/content_definition.gd"

const PRESSURE := "PRESSURE"
const POOL_BIAS := "POOL_BIAS"
const REFINEMENT_DEBT := "REFINEMENT_DEBT"
const VALID_TRADEOFF_FAMILIES := [PRESSURE, POOL_BIAS, REFINEMENT_DEBT]

@export var tradeoff_family: String
@export var risk: Dictionary
@export var reward: Dictionary
@export var build_bias: Dictionary

func _init(
	definition_id: String = "",
	contract_tradeoff_family: String = "",
	contract_risk: Dictionary = {},
	contract_reward: Dictionary = {},
	contract_build_bias: Dictionary = {},
) -> void:
	super(definition_id)
	tradeoff_family = contract_tradeoff_family
	risk = contract_risk.duplicate(true)
	reward = contract_reward.duplicate(true)
	build_bias = contract_build_bias.duplicate(true)

func definition_type_name() -> String:
	return "ContractDefinition"

func expected_id_families() -> Array[String]:
	return ["contract"]

func validate():
	var report = super.validate()
	if not VALID_TRADEOFF_FAMILIES.has(tradeoff_family):
		report.add_issue(_issue("invalid_contract_family", "ContractDefinition must declare a supported tradeoff family."))
	if risk.is_empty():
		report.add_issue(_issue("missing_contract_risk", "ContractDefinition must declare a risk tradeoff."))
	if reward.is_empty():
		report.add_issue(_issue("missing_contract_reward", "ContractDefinition must declare a reward tradeoff."))
	return report
