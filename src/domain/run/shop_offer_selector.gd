class_name ShopOfferSelector
extends RefCounted

const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const ShopOfferScript = preload("res://src/domain/run/shop_offer.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")

const SPECIAL_OFFER_IDS := [
	"base.special.refinement_token",
	"base.special.gold_cache",
	"base.special.workshop_coupon",
	"base.special.copy_license",
	"base.special.ritual_salve",
]

func create_offers(
	run_state,
	content_registry,
	shop_rng,
	entry_id: String,
	generation: int,
	slot_indices: Array,
	excluded_content_ids: Dictionary,
	economy,
) -> Array:
	var candidates := _candidates(run_state, content_registry, excluded_content_ids, economy)
	var offers: Array = []
	for slot_index in slot_indices:
		if candidates.is_empty():
			break
		var required_kind := ""
		if offers.size() < 3:
			required_kind = [ShopOfferScript.RELIC, ShopOfferScript.TECHNIQUE, ShopOfferScript.SPECIAL][offers.size()]
		var candidate_index: int = _candidate_index(candidates, required_kind, shop_rng)
		var candidate: Dictionary = candidates[candidate_index]
		candidates.remove_at(candidate_index)
		offers.append(ShopOfferScript.new(
			"%s.g%d.slot.%d" % [entry_id, generation, int(slot_index)],
			int(slot_index),
			str(candidate["kind"]),
			str(candidate["content_id"]),
			int(candidate["price"]),
			candidate.get("metadata", {}),
		))
	return offers

func _candidate_index(candidates: Array, required_kind: String, shop_rng) -> int:
	var matching_indices: Array = []
	for index in range(candidates.size()):
		if required_kind.is_empty() or candidates[index]["kind"] == required_kind:
			matching_indices.append(index)
	if matching_indices.is_empty():
		for index in range(candidates.size()):
			matching_indices.append(index)
	var selected_index: int = shop_rng.next_int(0, matching_indices.size() - 1) if shop_rng != null else 0
	return matching_indices[selected_index]

func _candidates(run_state, content_registry, excluded_content_ids: Dictionary, economy) -> Array:
	var candidates: Array = []
	for definition in content_registry.enumerate():
		if definition is RelicDefinitionScript:
			if run_state.build_ownership.owned_relic_ids.has(definition.content_id) or excluded_content_ids.has(definition.content_id):
				continue
			candidates.append({
				"kind": ShopOfferScript.RELIC,
				"content_id": definition.content_id,
				"price": economy.shop_relic_price,
				"metadata": {},
			})
		elif definition is TechniqueDefinitionScript and definition.technique_kind != TechniqueDefinitionScript.CORE:
			if run_state.build_ownership.run_technique_ids.has(definition.content_id) or excluded_content_ids.has(definition.content_id):
				continue
			candidates.append({
				"kind": ShopOfferScript.TECHNIQUE,
				"content_id": definition.content_id,
				"price": economy.shop_technique_price,
				"metadata": {},
			})
	for special_id in SPECIAL_OFFER_IDS:
		if run_state.build_ownership.owned_special_offer_ids.has(special_id) or excluded_content_ids.has(special_id):
			continue
		candidates.append({
			"kind": ShopOfferScript.SPECIAL,
			"content_id": special_id,
			"price": _special_price(special_id, economy),
			"metadata": {"special_action": _special_action(special_id)},
		})
	candidates.sort_custom(func(left, right): return left["content_id"] < right["content_id"])
	return candidates

func _special_price(special_id: String, economy) -> int:
	return int(economy.shop_special_prices.get(special_id, economy.shop_special_price))

func _special_action(special_id: String) -> String:
	match special_id:
		"base.special.refinement_token":
			return "REFINEMENT_TOKEN"
		"base.special.gold_cache":
			return "GOLD_CACHE"
		"base.special.workshop_coupon":
			return "WORKSHOP_COUPON"
		"base.special.copy_license":
			return "COPY_LICENSE"
		_:
			return "RITUAL_SALVE"
