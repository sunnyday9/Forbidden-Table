class_name RewardDraftSelector
extends RefCounted

const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const RewardDraftScript = preload("res://src/domain/run/reward_draft.gd")
const RewardOptionScript = preload("res://src/domain/run/reward_option.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")

const NORMAL := "NORMAL"

func create_normal_draft(
	run_state,
	content_registry,
	reward_rng,
	encounter_id: String,
	draft_index: int,
	configured_skip_gold: int = 5,
) -> RewardDraftScript:
	var tile_definitions: Array = _tile_definitions(content_registry)
	var modifier_definitions: Array = _modifier_definitions(content_registry)
	var context := _context(run_state, content_registry)
	var candidates: Array = []
	for tile_definition in tile_definitions:
		candidates.append({
			"definition": tile_definition,
			"bias": _tile_bias(tile_definition, context),
		})

	var selected_content_ids: Dictionary = {}
	var acquisition_options: Array = []
	var first_candidate = _pick_by_bias(candidates, RewardOptionScript.SYNERGY, selected_content_ids, reward_rng)
	if first_candidate.is_empty():
		first_candidate = _pick_by_bias(candidates, RewardOptionScript.NEUTRAL, selected_content_ids, reward_rng)
	if first_candidate.is_empty():
		first_candidate = _pick_by_bias(candidates, RewardOptionScript.PIVOT, selected_content_ids, reward_rng)
	if first_candidate.is_empty() and not candidates.is_empty():
		first_candidate = _pick_any(candidates, selected_content_ids, reward_rng)
	if not first_candidate.is_empty():
		selected_content_ids[first_candidate.definition.content_id] = true
		acquisition_options.append({"type": "ADD_TILE", "candidate": first_candidate})

	var modified_option := _modified_candidate(run_state, content_registry, modifier_definitions, context, reward_rng)
	if not modified_option.is_empty():
		acquisition_options.append({"type": "MODIFIED_TILE", "candidate": modified_option})

	if acquisition_options.size() < 2:
		var second_candidate = _pick_by_bias(candidates, RewardOptionScript.NEUTRAL, selected_content_ids, reward_rng)
		if second_candidate.is_empty():
			second_candidate = _pick_by_bias(candidates, RewardOptionScript.PIVOT, selected_content_ids, reward_rng)
		if second_candidate.is_empty():
			second_candidate = _pick_by_bias(candidates, RewardOptionScript.SYNERGY, selected_content_ids, reward_rng)
		if second_candidate.is_empty() and not candidates.is_empty():
			second_candidate = _pick_any(candidates, selected_content_ids, reward_rng)
		if not second_candidate.is_empty():
			selected_content_ids[second_candidate.definition.content_id] = true
			acquisition_options.append({"type": "ADD_TILE", "candidate": second_candidate})

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
				modified.tile_id,
				modified.modifier_id,
				modified.target_instance_id,
				modified.bias,
				0,
				0,
				{"target_definition_id": modified.tile_id},
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

	while options.size() < 2 and not options.is_empty():
		var duplicate_source = options[0]
		options.append(RewardOptionScript.new(
			"%s.option.%d" % [draft_id, options.size()],
			duplicate_source.kind,
			duplicate_source.content_id,
			duplicate_source.tile_id,
			duplicate_source.modifier_id,
			duplicate_source.target_instance_id,
			duplicate_source.context_bias,
			duplicate_source.gold_delta,
			duplicate_source.refinement_token_delta,
			duplicate_source.metadata,
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

	while options.size() < 3:
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
) -> RewardDraftScript:
	return create_normal_draft(run_state, content_registry, reward_rng, encounter_id, draft_index, configured_skip_gold)

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
	var character = content_registry.resolve(run_state.character_id) if content_registry != null else null
	if character is CharacterDefinitionScript:
		for tile_id in character.starting_tile_pool_bias:
			preferred_tile_ids[tile_id] = true
	var contract = content_registry.resolve(run_state.contract_id) if content_registry != null else null
	if contract is ContractDefinitionScript:
		_add_build_bias_ids(preferred_tile_ids, contract.build_bias)
	if run_state.build_ownership != null:
		for milestone_id in run_state.build_ownership.yaku_build_milestones.keys():
			preferred_tile_ids[str(milestone_id)] = true

	var suit_counts: Dictionary = {}
	var tile_pool = run_state.tile_pool.tile_instances if run_state.tile_pool != null else []
	for tile_instance in tile_pool:
		var tile_definition = content_registry.resolve(tile_instance.definition_id) if content_registry != null else null
		if tile_definition is TileDefinitionScript:
			suit_counts[tile_definition.suit] = int(suit_counts.get(tile_definition.suit, 0)) + 1
	var dominant_suit := ""
	var dominant_count := 0
	for suit in suit_counts.keys():
		var count: int = int(suit_counts[suit])
		if count > dominant_count or (count == dominant_count and (dominant_suit.is_empty() or str(suit) < dominant_suit)):
			dominant_suit = str(suit)
			dominant_count = count
	return {"preferred_tile_ids": preferred_tile_ids, "dominant_suit": dominant_suit}

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

func _pick_from(candidates: Array, reward_rng) -> Dictionary:
	if candidates.is_empty():
		return {}
	var index: int = reward_rng.next_int(0, candidates.size() - 1) if reward_rng != null else 0
	return candidates[index]
