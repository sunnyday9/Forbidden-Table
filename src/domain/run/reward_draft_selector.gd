class_name RewardDraftSelector
extends RefCounted

const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const AlphaContractEffectsScript = preload("res://src/domain/run/alpha_contract_effects.gd")
const RewardDraftScript = preload("res://src/domain/run/reward_draft.gd")
const RewardOptionScript = preload("res://src/domain/run/reward_option.gd")
const RewardPoolDefinitionScript = preload("res://src/content/definitions/reward_pool_definition.gd")
const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const RuleBreakerDefinitionScript = preload("res://src/content/definitions/rule_breaker_definition.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")

const NORMAL := "NORMAL"
const BOSS_RULE_BREAKER := RewardDraftScript.BOSS_RULE_BREAKER
const ELITE_BUILD := RewardDraftScript.ELITE_BUILD

func create_elite_build_draft(
	run_state,
	content_registry,
	reward_rng,
	encounter_id: String,
	draft_index: int,
	pool_id: String,
	configured_skip_gold: int = 10,
	configured_skip_tokens: int = 0,
) -> RewardDraftScript:
	var pool = content_registry.resolve(pool_id) if content_registry != null else null
	if not pool is RewardPoolDefinitionScript:
		return null
	var owned_relics: Dictionary = {}
	var owned_techniques: Dictionary = {}
	if run_state != null and run_state.build_ownership != null:
		for content_id in run_state.build_ownership.owned_relic_ids:
			owned_relics[str(content_id)] = true
		for content_id in run_state.build_ownership.run_technique_ids:
			owned_techniques[str(content_id)] = true
	var relic_candidates: Array = []
	var technique_candidates: Array = []
	var current_act := maxi(1, int(run_state.act_index)) if run_state != null else 1
	for entry in pool.entries:
		if not entry is Dictionary:
			continue
		var content_id := str(entry.get("content_id", ""))
		var weight := int(entry.get("weight", 0))
		if content_id.is_empty() or weight <= 0:
			continue
		var definition = content_registry.resolve(content_id)
		if definition is RelicDefinitionScript and definition.available_from_act <= current_act and not owned_relics.has(content_id):
			relic_candidates.append({"definition": definition, "weight": weight, "kind": RewardOptionScript.RELIC})
		elif definition is TechniqueDefinitionScript and definition.technique_kind != TechniqueDefinitionScript.CORE and not owned_techniques.has(content_id):
			technique_candidates.append({"definition": definition, "weight": weight, "kind": RewardOptionScript.RUN_TECHNIQUE})
	relic_candidates.sort_custom(_candidate_order)
	technique_candidates.sort_custom(_candidate_order)
	if relic_candidates.is_empty() or technique_candidates.is_empty() or relic_candidates.size() + technique_candidates.size() < 3:
		return null
	var selected_candidates: Array = [
		_take_weighted_candidate(relic_candidates, reward_rng),
		_take_weighted_candidate(technique_candidates, reward_rng),
	]
	var remaining_candidates: Array = []
	remaining_candidates.append_array(relic_candidates)
	remaining_candidates.append_array(technique_candidates)
	remaining_candidates.sort_custom(_candidate_order)
	selected_candidates.append(_take_weighted_candidate(remaining_candidates, reward_rng))
	if selected_candidates.has(null):
		return null
	var draft_id := "reward.elite.%s.%d" % [encounter_id, draft_index]
	var options: Array = []
	for candidate in selected_candidates:
		var definition = candidate.definition
		options.append(RewardOptionScript.new(
			"%s.option.%d" % [draft_id, options.size()],
			str(candidate.kind),
			definition.content_id,
		))
	options.append(RewardOptionScript.new(
		"%s.option.%d" % [draft_id, options.size()],
		RewardOptionScript.SKIP,
		RewardOptionScript.SKIP_CONTENT_ID,
		"",
		"",
		"",
		RewardOptionScript.NEUTRAL,
		configured_skip_gold,
		maxi(0, configured_skip_tokens),
	))
	var pivot_candidate := _elite_pivot_candidate(run_state, content_registry, reward_rng)
	if not pivot_candidate.is_empty():
		var pivot_tile = pivot_candidate.definition
		options.append(RewardOptionScript.new(
			"%s.option.%d" % [draft_id, options.size()],
			RewardOptionScript.ADD_TILE,
			pivot_tile.content_id,
			pivot_tile.content_id,
			"",
			"",
			RewardOptionScript.PIVOT,
			0,
			0,
			{"special_pivot": true, "pivot_kind": str(pivot_candidate.pivot_kind)},
		))
	var reward_rng_state: Dictionary = reward_rng.snapshot() if reward_rng != null and reward_rng.has_method("snapshot") else {}
	return RewardDraftScript.new(draft_id, ELITE_BUILD, encounter_id, "ELITE", options, reward_rng_state)

func _take_weighted_candidate(candidates: Array, reward_rng) -> Dictionary:
	if candidates.is_empty():
		return {}
	var total_weight := 0
	for candidate in candidates:
		total_weight += int(candidate.weight)
	var roll: int = reward_rng.next_int(1, total_weight) if reward_rng != null else 1
	var cumulative_weight := 0
	for index in candidates.size():
		cumulative_weight += int(candidates[index].weight)
		if roll <= cumulative_weight:
			return candidates.pop_at(index)
	return {}

func _candidate_order(left: Dictionary, right: Dictionary) -> bool:
	return left.definition.content_id < right.definition.content_id

func create_boss_rule_breaker_draft(
	run_state,
	content_registry,
	reward_rng,
	encounter_id: String,
	draft_index: int,
	pool_id: String,
) -> RewardDraftScript:
	var pool = content_registry.resolve(pool_id) if content_registry != null else null
	if not pool is RewardPoolDefinitionScript:
		return null
	var owned_ids: Dictionary = {}
	if run_state != null and run_state.build_ownership != null:
		for identifier in run_state.build_ownership.acquired_rule_breaker_ids:
			owned_ids[str(identifier)] = true
	var candidates: Array = []
	for entry in pool.entries:
		if not entry is Dictionary:
			continue
		var content_id := str(entry.get("content_id", ""))
		var definition = content_registry.resolve(content_id)
		var weight := int(entry.get("weight", 0))
		if content_id.is_empty() or weight <= 0 or owned_ids.has(content_id) or not definition is RuleBreakerDefinitionScript:
			continue
		candidates.append({"definition": definition, "weight": weight})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return left.definition.content_id < right.definition.content_id
	)
	if candidates.size() < 3:
		return null

	var draft_id := "reward.boss.%s.%d" % [encounter_id, draft_index]
	var options: Array = []
	while options.size() < 3 and not candidates.is_empty():
		var total_weight := 0
		for candidate in candidates:
			total_weight += int(candidate.weight)
		var roll: int = reward_rng.next_int(1, total_weight) if reward_rng != null else 1
		var selected_index := -1
		var cumulative_weight := 0
		for index in candidates.size():
			cumulative_weight += int(candidates[index].weight)
			if roll <= cumulative_weight:
				selected_index = index
				break
		if selected_index < 0:
			return null
		var selected: Dictionary = candidates.pop_at(selected_index)
		var definition = selected.definition
		var option_index := options.size()
		options.append(RewardOptionScript.new(
			"%s.option.%d" % [draft_id, option_index],
			RewardOptionScript.RULE_BREAKER,
			definition.content_id,
			"",
			"",
			"",
			RewardOptionScript.NEUTRAL,
			0,
			0,
			{"rule_key": definition.rule_key, "permission_level": definition.permission_level},
		))
	if options.size() != 3:
		return null
	var reward_rng_state: Dictionary = reward_rng.snapshot() if reward_rng != null and reward_rng.has_method("snapshot") else {}
	return RewardDraftScript.new(
		draft_id,
		RewardDraftScript.BOSS_RULE_BREAKER,
		encounter_id,
		"BOSS",
		options,
		reward_rng_state,
	)

func _elite_pivot_candidate(run_state, content_registry, reward_rng) -> Dictionary:
	if run_state == null or str(run_state.character_id) != "base.character.reserve" or str(run_state.excluded_suit).is_empty():
		return {}
	var owned_counts: Dictionary = {}
	if run_state.tile_pool != null:
		for instance in run_state.tile_pool.tile_instances:
			owned_counts[str(instance.definition_id)] = int(owned_counts.get(str(instance.definition_id), 0)) + 1
	var restricted_suit := str(AlphaContractEffectsScript.normal_reward_add_tile_suit(content_registry, run_state.contract_id))
	var candidates: Array = []
	for tile_definition in _tile_definitions(content_registry):
		if tile_definition.suit != str(run_state.excluded_suit) and tile_definition.suit != "honors":
			continue
		if not restricted_suit.is_empty() and tile_definition.suit != restricted_suit:
			continue
		if int(owned_counts.get(tile_definition.content_id, 0)) >= RunEconomyScript.DEFAULT_TILE_COPY_LIMIT:
			continue
		candidates.append({"definition": tile_definition, "pivot_kind": "EXCLUDED_SUIT" if tile_definition.suit == str(run_state.excluded_suit) else "HONORS"})
	return _pick_from(candidates, reward_rng)

func create_normal_draft(
	run_state,
	content_registry,
	reward_rng,
	encounter_id: String,
	draft_index: int,
	configured_skip_gold: int = 5,
	configured_tile_copy_limit: int = RunEconomyScript.DEFAULT_TILE_COPY_LIMIT,
) -> RewardDraftScript:
	var tile_definitions: Array = _tile_definitions(content_registry)
	var modifier_definitions: Array = _modifier_definitions(content_registry)
	var context := _context(run_state, content_registry)
	var owned_tile_counts: Dictionary = {}
	if run_state != null and run_state.tile_pool != null:
		for tile_instance in run_state.tile_pool.tile_instances:
			var definition_id := str(tile_instance.definition_id)
			owned_tile_counts[definition_id] = int(owned_tile_counts.get(definition_id, 0)) + 1
	var candidates: Array = []
	var preferred_add_tile_suit := str(context.get("normal_reward_add_tile_suit", ""))
	var reserve_excluded_suit := str(run_state.excluded_suit) if run_state != null and str(run_state.character_id) == "base.character.reserve" else ""
	for tile_definition in tile_definitions:
		if int(owned_tile_counts.get(tile_definition.content_id, 0)) >= configured_tile_copy_limit:
			continue
		if not reserve_excluded_suit.is_empty() and (tile_definition.suit == reserve_excluded_suit or tile_definition.suit == "honors"):
			continue
		if not preferred_add_tile_suit.is_empty() and tile_definition.suit != preferred_add_tile_suit:
			continue
		candidates.append({
			"definition": tile_definition,
			"bias": _tile_bias(tile_definition, context),
			"contract_preferred": bool(context.get("contract_preferred_tile_ids", {}).has(tile_definition.content_id)),
		})

	var selected_content_ids: Dictionary = {}
	var acquisition_options: Array = []
	var selected_modifier_ids: Dictionary = {}
	var first_candidate = _pick_contract_preferred(candidates, selected_content_ids, reward_rng)
	if first_candidate.is_empty():
		first_candidate = _pick_by_bias(candidates, RewardOptionScript.SYNERGY, selected_content_ids, reward_rng)
	if first_candidate.is_empty():
		first_candidate = _pick_by_bias(candidates, RewardOptionScript.NEUTRAL, selected_content_ids, reward_rng)
	if first_candidate.is_empty():
		first_candidate = _pick_by_bias(candidates, RewardOptionScript.PIVOT, selected_content_ids, reward_rng)
	if first_candidate.is_empty() and not candidates.is_empty():
		first_candidate = _pick_any(candidates, selected_content_ids, reward_rng)
	if not first_candidate.is_empty():
		selected_content_ids[first_candidate.definition.content_id] = true
		acquisition_options.append({"type": "ADD_TILE", "candidate": first_candidate})

	var modifier_candidates := _targeted_modifier_candidates(run_state, content_registry, modifier_definitions)
	var modified_option := _pick_modifier_candidate(modifier_candidates, selected_modifier_ids, reward_rng)
	if not modified_option.is_empty():
		selected_modifier_ids[str(modified_option.modifier_id)] = true
		acquisition_options.append({"type": "MODIFIED_TILE", "candidate": modified_option})

	if acquisition_options.size() < 2:
		var second_candidate = _pick_contract_preferred(candidates, selected_content_ids, reward_rng)
		if second_candidate.is_empty():
			second_candidate = _pick_by_bias(candidates, RewardOptionScript.NEUTRAL, selected_content_ids, reward_rng)
		if second_candidate.is_empty():
			second_candidate = _pick_by_bias(candidates, RewardOptionScript.PIVOT, selected_content_ids, reward_rng)
		if second_candidate.is_empty():
			second_candidate = _pick_by_bias(candidates, RewardOptionScript.SYNERGY, selected_content_ids, reward_rng)
		if second_candidate.is_empty() and not candidates.is_empty():
			second_candidate = _pick_any(candidates, selected_content_ids, reward_rng)
		if not second_candidate.is_empty():
			selected_content_ids[second_candidate.definition.content_id] = true
			acquisition_options.append({"type": "ADD_TILE", "candidate": second_candidate})
	if acquisition_options.size() < 2:
		var second_modifier := _pick_modifier_candidate(modifier_candidates, selected_modifier_ids, reward_rng)
		if not second_modifier.is_empty():
			selected_modifier_ids[str(second_modifier.modifier_id)] = true
			acquisition_options.append({"type": "MODIFIED_TILE", "candidate": second_modifier})
	var extra_modified_candidate: Dictionary = {}
	if bool(context.get("extra_modified_tile_choice", false)) and not modified_option.is_empty():
		extra_modified_candidate = _pick_modifier_candidate(modifier_candidates, selected_modifier_ids, reward_rng)
		if not extra_modified_candidate.is_empty():
			selected_modifier_ids[str(extra_modified_candidate.modifier_id)] = true

	var draft_id := "reward.normal.%s.%d" % [encounter_id, draft_index]
	var options: Array = []
	for acquisition in acquisition_options:
		var option_id := "%s.option.%d" % [draft_id, options.size()]
		if acquisition.type == "MODIFIED_TILE":
			var modified: Dictionary = acquisition.candidate
			options.append(RewardOptionScript.new(
				option_id,
				RewardOptionScript.MODIFIED_TILE,
				modified.modifier_id,
				"",
				modified.modifier_id,
				"",
				modified.bias,
				0,
				0,
				{"target_mode": "CHOOSE_TYPE", "target_limit": 2},
			))
		else:
			var candidate: Dictionary = acquisition.candidate
			options.append(RewardOptionScript.new(
				option_id,
				RewardOptionScript.ADD_TILE,
				candidate.definition.content_id,
				candidate.definition.content_id,
				"",
				"",
				candidate.bias,
			))

	if not extra_modified_candidate.is_empty():
		options.append(RewardOptionScript.new(
			"%s.option.%d" % [draft_id, options.size()],
			RewardOptionScript.MODIFIED_TILE,
			extra_modified_candidate.modifier_id,
			"",
			extra_modified_candidate.modifier_id,
			"",
			extra_modified_candidate.bias,
			0,
			0,
			{"target_mode": "CHOOSE_TYPE", "target_limit": 2},
		))

	options.append(RewardOptionScript.new(
		"%s.option.%d" % [draft_id, options.size()],
		RewardOptionScript.SKIP,
		RewardOptionScript.SKIP_CONTENT_ID,
		"",
		"",
		"",
		RewardOptionScript.NEUTRAL,
		configured_skip_gold,
	))

	var reward_rng_state: Dictionary = reward_rng.snapshot() if reward_rng != null and reward_rng.has_method("snapshot") else {}
	return RewardDraftScript.new(draft_id, NORMAL, encounter_id, NORMAL, options, reward_rng_state)

func build_normal_draft(
	run_state,
	content_registry,
	reward_rng,
	encounter_id: String,
	draft_index: int,
	configured_skip_gold: int = 5,
	configured_tile_copy_limit: int = RunEconomyScript.DEFAULT_TILE_COPY_LIMIT,
) -> RewardDraftScript:
	return create_normal_draft(run_state, content_registry, reward_rng, encounter_id, draft_index, configured_skip_gold, configured_tile_copy_limit)

func _tile_definitions(content_registry) -> Array:
	var definitions: Array = []
	for definition in content_registry.enumerate():
		if definition is TileDefinitionScript:
			definitions.append(definition)
	definitions.sort_custom(func(left, right): return left.content_id < right.content_id)
	return definitions

func _modifier_definitions(content_registry) -> Array:
	var definitions: Array = []
	for definition in content_registry.enumerate():
		if definition is TileModifierDefinitionScript:
			definitions.append(definition)
	definitions.sort_custom(func(left, right): return left.content_id < right.content_id)
	return definitions

func _context(run_state, content_registry) -> Dictionary:
	var preferred_tile_ids: Dictionary = {}
	var contract_preferred_tile_ids: Dictionary = {}
	var contract = content_registry.resolve(run_state.contract_id) if content_registry != null else null
	if contract is ContractDefinitionScript:
		_add_build_bias_ids(preferred_tile_ids, contract.build_bias)
	for tile_id in AlphaContractEffectsScript.preferred_tile_ids(content_registry, run_state.contract_id):
		preferred_tile_ids[tile_id] = true
		contract_preferred_tile_ids[tile_id] = true
	if run_state.build_ownership != null:
		for milestone_id in run_state.build_ownership.yaku_build_milestones.keys():
			preferred_tile_ids[str(milestone_id)] = true

	var suit_counts: Dictionary = {}
	var tile_pool = run_state.tile_pool.tile_instances if run_state.tile_pool != null else []
	for tile_instance in tile_pool:
		var tile_definition = content_registry.resolve(tile_instance.definition_id) if content_registry != null else null
		if tile_definition is TileDefinitionScript:
			suit_counts[tile_definition.suit] = int(suit_counts.get(tile_definition.suit, 0)) + 1
	var dominant_count := 0
	var dominant_suits: Array[String] = []
	for suit in suit_counts.keys():
		var count: int = int(suit_counts[suit])
		if count > dominant_count:
			dominant_count = count
			dominant_suits = [str(suit)]
		elif count == dominant_count:
			dominant_suits.append(str(suit))
	var dominant_suit := str(dominant_suits[0]) if dominant_suits.size() == 1 else ""
	return {
		"preferred_tile_ids": preferred_tile_ids,
		"contract_preferred_tile_ids": contract_preferred_tile_ids,
		"dominant_suit": dominant_suit,
		"normal_reward_add_tile_suit": AlphaContractEffectsScript.normal_reward_add_tile_suit(content_registry, run_state.contract_id),
		"extra_modified_tile_choice": AlphaContractEffectsScript.extra_modified_tile_choice(content_registry, run_state.contract_id),
	}

func _add_build_bias_ids(preferred_tile_ids: Dictionary, build_bias: Dictionary) -> void:
	for key in ["tile_id", "tile_ids", "preferred_tile_ids", "tiles"]:
		var value = build_bias.get(key, null)
		if value is Array:
			for tile_id in value:
				preferred_tile_ids[str(tile_id)] = true
		elif value is String and not value.is_empty():
			preferred_tile_ids[value] = true

func _tile_bias(tile_definition, context: Dictionary) -> String:
	if context.preferred_tile_ids.has(tile_definition.content_id):
		return RewardOptionScript.SYNERGY
	if not str(context.dominant_suit).is_empty():
		return RewardOptionScript.SYNERGY if tile_definition.suit == context.dominant_suit else RewardOptionScript.PIVOT
	return RewardOptionScript.NEUTRAL

func _targeted_modifier_candidates(run_state, content_registry, modifier_definitions: Array) -> Array:
	var candidates: Array = []
	if run_state == null or run_state.tile_pool == null or run_state.tile_pool.tile_instances.is_empty():
		return candidates
	for modifier_definition in modifier_definitions:
		var has_eligible_target := false
		for tile_instance in run_state.tile_pool.tile_instances:
			if str(tile_instance.ownership_scope) != "RUN" or str(tile_instance.lifetime_scope) != "RUN":
				continue
			if not content_registry.resolve(str(tile_instance.definition_id)) is TileDefinitionScript:
				continue
			var current_modifiers: Array = run_state.build_ownership.persistent_tile_modifier_state.get(str(tile_instance.instance_id), [])
			if current_modifiers.count(modifier_definition.content_id) < modifier_definition.max_per_tile:
				has_eligible_target = true
				break
		if has_eligible_target:
			candidates.append({
				"modifier_id": modifier_definition.content_id,
				"bias": RewardOptionScript.NEUTRAL,
			})
	return candidates

func _pick_modifier_candidate(candidates: Array, selected_modifier_ids: Dictionary, reward_rng) -> Dictionary:
	var available: Array = []
	for candidate in candidates:
		if not selected_modifier_ids.has(str(candidate.get("modifier_id", ""))):
			available.append(candidate)
	return _pick_from(available, reward_rng)

func _modified_candidate(run_state, content_registry, modifier_definitions: Array, context: Dictionary, reward_rng) -> Dictionary:
	if modifier_definitions.is_empty() or run_state.tile_pool == null or run_state.tile_pool.tile_instances.is_empty():
		return {}
	var target_index: int = reward_rng.next_int(0, run_state.tile_pool.tile_instances.size() - 1) if reward_rng != null else 0
	var target_instance = run_state.tile_pool.tile_instances[target_index]
	var target_definition = content_registry.resolve(target_instance.definition_id)
	if not target_definition is TileDefinitionScript:
		return {}
	var modifier_index: int = reward_rng.next_int(0, modifier_definitions.size() - 1) if reward_rng != null else 0
	var modifier_definition = modifier_definitions[modifier_index]
	return {
		"tile_id": target_definition.content_id,
		"modifier_id": modifier_definition.content_id,
		"target_instance_id": target_instance.instance_id,
		"bias": _tile_bias(target_definition, context),
	}

func _pick_by_bias(candidates: Array, desired_bias: String, selected_content_ids: Dictionary, reward_rng) -> Dictionary:
	var matching: Array = []
	for candidate in candidates:
		if candidate.bias == desired_bias and not selected_content_ids.has(candidate.definition.content_id):
			matching.append(candidate)
	return _pick_from(matching, reward_rng)

func _pick_any(candidates: Array, selected_content_ids: Dictionary, reward_rng) -> Dictionary:
	var available: Array = []
	for candidate in candidates:
		if not selected_content_ids.has(candidate.definition.content_id):
			available.append(candidate)
	return _pick_from(available, reward_rng)

func _pick_contract_preferred(candidates: Array, selected_content_ids: Dictionary, reward_rng) -> Dictionary:
	var preferred: Array = []
	for candidate in candidates:
		if bool(candidate.get("contract_preferred", false)) and not selected_content_ids.has(candidate.definition.content_id):
			preferred.append(candidate)
	return _pick_from(preferred, reward_rng)

func _second_modified_candidate(run_state, content_registry, modifier_definitions: Array, context: Dictionary, first_candidate: Dictionary, reward_rng) -> Dictionary:
	if run_state == null or run_state.tile_pool == null:
		return {}
	var first_pair := "%s|%s" % [str(first_candidate.get("target_instance_id", "")), str(first_candidate.get("modifier_id", ""))]
	var candidates: Array = []
	for tile_instance in run_state.tile_pool.tile_instances:
		var target_definition = content_registry.resolve(str(tile_instance.definition_id))
		if not target_definition is TileDefinitionScript:
			continue
		var current_modifiers: Array = run_state.build_ownership.persistent_tile_modifier_state.get(str(tile_instance.instance_id), [])
		for modifier_definition in modifier_definitions:
			if current_modifiers.count(modifier_definition.content_id) >= modifier_definition.max_per_tile:
				continue
			var pair_id := "%s|%s" % [str(tile_instance.instance_id), str(modifier_definition.content_id)]
			if pair_id == first_pair:
				continue
			candidates.append({
				"tile_id": target_definition.content_id,
				"modifier_id": modifier_definition.content_id,
				"target_instance_id": tile_instance.instance_id,
				"bias": _tile_bias(target_definition, context),
				"pair_id": pair_id,
			})
	candidates.sort_custom(func(left, right): return str(left.pair_id) < str(right.pair_id))
	return _pick_from(candidates, reward_rng)

func _pick_from(candidates: Array, reward_rng) -> Dictionary:
	if candidates.is_empty():
		return {}
	var index: int = reward_rng.next_int(0, candidates.size() - 1) if reward_rng != null else 0
	return candidates[index]
