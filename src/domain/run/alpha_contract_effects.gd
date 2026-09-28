class_name AlphaContractEffects
extends RefCounted

const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")

static func initial_pressure_per_battle(content_registry, contract_id: String) -> int:
	var contract = _definition(content_registry, contract_id)
	return maxi(0, int(contract.risk.get("initial_pressure_per_battle", 0))) if contract != null else 0

static func starting_tp_per_battle(content_registry, contract_id: String) -> int:
	var contract = _definition(content_registry, contract_id)
	return maxi(0, int(contract.reward.get("starting_tp_per_battle", 0))) if contract != null else 0

static func refinement_tokens_on_contract_selection(content_registry, contract_id: String) -> int:
	var contract = _definition(content_registry, contract_id)
	return maxi(0, int(contract.reward.get("refinement_tokens_on_contract_selection", 0))) if contract != null else 0

static func elite_skip_gold(configured_gold: int, content_registry, contract_id: String) -> int:
	var contract = _definition(content_registry, contract_id)
	var penalty := int(contract.risk.get("elite_skip_gold_penalty", 0)) if contract != null else 0
	return maxi(0, configured_gold - maxi(0, penalty))

static func refinement_tokens_on_elite_skip(content_registry, contract_id: String) -> int:
	var contract = _definition(content_registry, contract_id)
	return maxi(0, int(contract.reward.get("refinement_tokens_on_elite_skip", 0))) if contract != null else 0

static func workshop_refinement_gold_surcharge(content_registry, contract_id: String) -> int:
	var contract = _definition(content_registry, contract_id)
	return maxi(0, int(contract.risk.get("workshop_refinement_gold_surcharge", 0))) if contract != null else 0

static func normal_reward_add_tile_suit(content_registry, contract_id: String) -> String:
	var contract = _definition(content_registry, contract_id)
	if contract == null or int(contract.risk.get("normal_reward_off_suit_choice_cap", -1)) != 0:
		return ""
	return str(contract.reward.get("reward_tile_suit_bias", ""))

static func preferred_tile_ids(content_registry, contract_id: String) -> Array[String]:
	var contract = _definition(content_registry, contract_id)
	if contract == null:
		return []
	var result: Array[String] = []
	var preferred: Variant = contract.build_bias.get("preferred_tile_ids", [])
	if preferred is Array:
		for tile_id in preferred:
			if not str(tile_id).is_empty():
				result.append(str(tile_id))
	return result

static func extra_modified_tile_choice(content_registry, contract_id: String) -> bool:
	var contract = _definition(content_registry, contract_id)
	return bool(contract.reward.get("extra_modified_tile_choice", false)) if contract != null else false

static func yaku_hint(content_registry, contract_id: String) -> String:
	var contract = _definition(content_registry, contract_id)
	return str(contract.reward.get("yaku_signal", "")) if contract != null else ""

static func _definition(content_registry, contract_id: String):
	if content_registry == null or not AlphaScaleCatalogScript.CONTRACT_IDS.has(contract_id):
		return null
	var definition = content_registry.resolve(contract_id)
	return definition if definition is ContractDefinitionScript else null
