class_name RunRewardFlow
extends RefCounted

const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaContractEffectsScript = preload("res://src/domain/run/alpha_contract_effects.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const RewardDraftSelectorScript = preload("res://src/domain/run/reward_draft_selector.gd")
const RewardOptionScript = preload("res://src/domain/run/reward_option.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RuleBreakerDefinitionScript = preload("res://src/content/definitions/rule_breaker_definition.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")

var state
var content_registry
var rng_streams
var economy
var reward_draft_selector
var tile_pool_editor

func _init(initial_state, initial_content_registry, initial_rng_streams, initial_economy, initial_reward_draft_selector, initial_tile_pool_editor) -> void:
	state = initial_state
	content_registry = initial_content_registry
	rng_streams = initial_rng_streams
	economy = initial_economy
	reward_draft_selector = initial_reward_draft_selector
	tile_pool_editor = initial_tile_pool_editor

func bind_state(authoritative_state) -> void:
	state = authoritative_state

func create_draft(encounter_kind: String, encounter_id: String, previous_phase: String) -> Array:
	var events: Array = []
	state.phase = _reward_phase_for_encounter(encounter_kind)
	var draft_index: int = state.reward_draft_sequence
	if encounter_kind in [EncounterDefinitionScript.NORMAL, EncounterDefinitionScript.ELITE, EncounterDefinitionScript.BOSS]:
		state.reward_draft_sequence += 1
	if encounter_kind == EncounterDefinitionScript.NORMAL:
		state.reward_draft = reward_draft_selector.create_normal_draft(
			state,
			content_registry,
			rng_streams.reward,
			encounter_id,
			draft_index,
			economy.normal_skip_gold,
			economy.tile_copy_limit,
		)
		events.append(DomainEventScript.new(DomainEventScript.REWARD_DRAFT_CREATED, {
			"run_id": state.run_id,
			"draft": state.reward_draft.to_dictionary(),
		}))
	elif encounter_kind == EncounterDefinitionScript.ELITE:
		var elite_build_pool_id := Phase2CatalogScript.REWARD_POOL_ID
		var scale_pool_id := AlphaScaleCatalogScript.ACT_ONE_BUILD_POOL_ID if state.act_index < 2 else AlphaScaleCatalogScript.ACT_TWO_BUILD_POOL_ID
		if content_registry.resolve(scale_pool_id) != null:
			elite_build_pool_id = scale_pool_id
		state.reward_draft = reward_draft_selector.create_elite_build_draft(
			state,
			content_registry,
			rng_streams.reward,
			encounter_id,
			draft_index,
			elite_build_pool_id,
			AlphaContractEffectsScript.elite_skip_gold(economy.elite_skip_gold, content_registry, state.contract_id),
			AlphaContractEffectsScript.refinement_tokens_on_elite_skip(content_registry, state.contract_id),
		)
		if state.reward_draft != null:
			events.append(DomainEventScript.new(DomainEventScript.REWARD_DRAFT_CREATED, {
				"run_id": state.run_id,
				"draft": state.reward_draft.to_dictionary(),
			}))
	elif encounter_kind == EncounterDefinitionScript.BOSS:
		var boss_reward_pool_id: String = Phase2CatalogScript.BOSS_RULE_BREAKER_POOL_ID
		if state.act_index >= 2:
			boss_reward_pool_id = AlphaActTwoCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_POOL_ID
		var scale_boss_pool_id := AlphaScaleCatalogScript.ACT_ONE_BOSS_RULE_BREAKER_POOL_ID if state.act_index < 2 else AlphaScaleCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_POOL_ID
		if content_registry.resolve(scale_boss_pool_id) != null:
			boss_reward_pool_id = scale_boss_pool_id
		state.reward_draft = reward_draft_selector.create_boss_rule_breaker_draft(
			state,
			content_registry,
			rng_streams.reward,
			encounter_id,
			draft_index,
			boss_reward_pool_id,
		)
		if state.reward_draft != null:
			events.append(DomainEventScript.new(DomainEventScript.REWARD_DRAFT_CREATED, {
				"run_id": state.run_id,
				"draft": state.reward_draft.to_dictionary(),
			}))
	events.append(_run_phase_event(previous_phase, state.phase))
	return events

func validate_choice(selected_draft_id: String, selected_option_id: String) -> RefCounted:
	if state.phase == RunPhaseScript.ELITE_REWARD:
		if state.reward_draft == null or state.reward_draft.draft_kind != RewardDraftSelectorScript.ELITE_BUILD:
			return CommandValidationScript.new(false, "NO_REWARD_DRAFT", "There is no active Elite build reward draft.")
		if selected_draft_id.is_empty() or selected_draft_id != state.reward_draft.draft_id:
			return CommandValidationScript.new(false, "INVALID_REWARD_DRAFT", "The selected Elite reward draft is not active.")
		var elite_option = state.reward_draft.option_by_id(selected_option_id)
		if elite_option == null:
			return CommandValidationScript.new(false, "INVALID_REWARD_OPTION", "The selected Elite reward option is not in the active draft.")
		if elite_option.kind == RewardOptionScript.SKIP:
			var expected_skip_gold := AlphaContractEffectsScript.elite_skip_gold(economy.elite_skip_gold, content_registry, state.contract_id)
			var expected_skip_tokens := AlphaContractEffectsScript.refinement_tokens_on_elite_skip(content_registry, state.contract_id)
			if elite_option.content_id != RewardOptionScript.SKIP_CONTENT_ID or elite_option.gold_delta != expected_skip_gold or elite_option.refinement_token_delta != expected_skip_tokens:
				return CommandValidationScript.new(false, "INVALID_REWARD_OPTION", "Elite Skip must grant only its configured Gold and Refinement Token compensation.")
			return CommandValidationScript.new(true, CommandValidationScript.VALID, "", {"draft_id": selected_draft_id, "option_id": selected_option_id})
		if elite_option.kind == RewardOptionScript.RELIC:
			var relic = content_registry.resolve(elite_option.content_id)
			if not relic is RelicDefinitionScript:
				return CommandValidationScript.new(false, "INVALID_REWARD_CONTENT", "The Elite Relic option is not a registered RelicDefinition.")
			if relic.available_from_act > state.act_index:
				return CommandValidationScript.new(false, "RELIC_NOT_AVAILABLE_IN_ACT", "The Elite Relic is not available in this Act.")
			if state.build_ownership.owned_relic_ids.has(relic.content_id):
				return CommandValidationScript.new(false, "DUPLICATE_RELIC", "The Run already owns this Relic.")
			return CommandValidationScript.new(true, CommandValidationScript.VALID, "", {"draft_id": selected_draft_id, "option_id": selected_option_id, "content_id": relic.content_id})
		if elite_option.kind == RewardOptionScript.RUN_TECHNIQUE:
			var technique = content_registry.resolve(elite_option.content_id)
			if not technique is TechniqueDefinitionScript or technique.technique_kind == TechniqueDefinitionScript.CORE:
				return CommandValidationScript.new(false, "INVALID_REWARD_CONTENT", "The Elite Technique option is not a registered Run Technique.")
			if state.build_ownership.run_technique_ids.has(technique.content_id):
				return CommandValidationScript.new(false, "DUPLICATE_RUN_TECHNIQUE", "The Run already owns this Run Technique.")
			return CommandValidationScript.new(true, CommandValidationScript.VALID, "", {"draft_id": selected_draft_id, "option_id": selected_option_id, "content_id": technique.content_id})
		return CommandValidationScript.new(false, "INVALID_REWARD_OPTION", "The selected option is not a legal Elite reward.")
	if state.phase == RunPhaseScript.BOSS_REWARD:
		if state.reward_draft == null or state.reward_draft.draft_kind != RewardDraftSelectorScript.BOSS_RULE_BREAKER:
			return CommandValidationScript.new(false, "NO_REWARD_DRAFT", "There is no active Boss Rule Breaker draft.")
		var draft_id: String = selected_draft_id if not selected_draft_id.is_empty() else state.reward_draft.draft_id
		if draft_id != state.reward_draft.draft_id:
			return CommandValidationScript.new(false, "INVALID_REWARD_DRAFT", "The selected Boss reward draft is not active.")
		var option = state.reward_draft.option_by_id(selected_option_id)
		if option == null or option.kind != RewardOptionScript.RULE_BREAKER:
			return CommandValidationScript.new(false, "INVALID_REWARD_OPTION", "The selected Rule Breaker is not in the active Boss draft.")
		var definition = content_registry.resolve(option.content_id)
		if not definition is RuleBreakerDefinitionScript:
			return CommandValidationScript.new(false, "INVALID_REWARD_CONTENT", "The selected Boss reward is not a registered RuleBreakerDefinition.")
		if state.build_ownership.acquired_rule_breaker_ids.has(definition.content_id):
			return CommandValidationScript.new(false, "DUPLICATE_RULE_BREAKER", "The Run already owns this Rule Breaker.")
		return CommandValidationScript.new(true, CommandValidationScript.VALID, "", {"draft_id": draft_id, "option_id": selected_option_id, "rule_breaker_id": definition.content_id})
	if state.phase != RunPhaseScript.REWARD_CHOICE:
		return _invalid_phase(RunPhaseScript.REWARD_CHOICE)
	if state.reward_draft == null:
		return CommandValidationScript.new(false, "NO_REWARD_DRAFT", "There is no active reward draft.")
	var draft_id: String = selected_draft_id if not selected_draft_id.is_empty() else state.reward_draft.draft_id
	if draft_id != state.reward_draft.draft_id:
		return CommandValidationScript.new(false, "INVALID_REWARD_DRAFT", "The selected reward draft is not active.")
	var option = state.reward_draft.option_by_id(selected_option_id)
	if option == null:
		return CommandValidationScript.new(false, "INVALID_REWARD_OPTION", "The selected reward option is not in the active draft.")
	var option_validation := _validate_reward_option(option)
	if not option_validation.get("accepted", false):
		return CommandValidationScript.new(false, option_validation.get("status", "INVALID_REWARD_OPTION"), option_validation.get("message", "The selected reward option is invalid."), option_validation.get("details", {}))
	return CommandValidationScript.new(true, CommandValidationScript.VALID, "", {"draft_id": draft_id, "option_id": selected_option_id})

func execute_choice(selected_draft_id: String, selected_option_id: String) -> Dictionary:
	if state.phase == RunPhaseScript.ELITE_REWARD:
		var elite_draft = state.reward_draft
		var option = elite_draft.option_by_id(selected_option_id)
		var previous_phase: String = state.phase
		var events: Array = []
		var currency_transactions: Array = []
		if option.kind == RewardOptionScript.RELIC:
			state.build_ownership.owned_relic_ids.append(option.content_id)
		elif option.kind == RewardOptionScript.RUN_TECHNIQUE:
			state.build_ownership.run_technique_ids.append(option.content_id)
		elif option.kind == RewardOptionScript.SKIP:
			var skip_transaction: Dictionary = economy.apply_source(state, RunEconomyScript.GOLD, option.gold_delta, RunEconomyScript.SOURCE_ELITE_REWARD)
			if skip_transaction.is_empty():
				return {"accepted": false, "status": "CURRENCY_SOURCE_REJECTED", "message": "The configured Elite Skip compensation could not be applied."}
			currency_transactions.append(skip_transaction)
			events.append(RunEconomyScript.event_for_transaction(skip_transaction))
			if option.refinement_token_delta > 0:
				var token_transaction: Dictionary = economy.apply_source(state, RunEconomyScript.REFINEMENT_TOKENS, option.refinement_token_delta, RunEconomyScript.SOURCE_ELITE_REWARD)
				if token_transaction.is_empty():
					return {"accepted": false, "status": "CURRENCY_SOURCE_REJECTED", "message": "The configured Elite Skip token compensation could not be applied."}
				currency_transactions.append(token_transaction)
				events.append(RunEconomyScript.event_for_transaction(token_transaction))
		var reward_data := {
			"run_id": state.run_id,
			"draft_id": elite_draft.draft_id,
			"option_id": option.option_id,
			"kind": option.kind,
			"content_id": option.content_id,
			"reward_phase": previous_phase,
			"currency_transactions": currency_transactions.duplicate(true),
		}
		state.reward_draft = null
		state.phase = RunPhaseScript.MAP_CHOICE
		reward_data["phase"] = state.phase
		events.append(DomainEventScript.new(DomainEventScript.REWARD_SELECTED, reward_data.duplicate(true)))
		events.append(_run_phase_event(previous_phase, state.phase))
		state.map_state.last_events = events
		return {"accepted": true, "status": CommandResultScript.ACCEPTED, "events": events, "data": reward_data}
	if state.phase == RunPhaseScript.BOSS_REWARD:
		var boss_draft_id: String = selected_draft_id if not selected_draft_id.is_empty() else state.reward_draft.draft_id
		var selected_option = state.reward_draft.option_by_id(selected_option_id) if state.reward_draft != null else null
		if selected_option == null or selected_option.kind != RewardOptionScript.RULE_BREAKER:
			return {"accepted": false, "status": "INVALID_REWARD_OPTION", "message": "The selected Rule Breaker is not in the active Boss draft."}
		var rule_breaker = content_registry.resolve(selected_option.content_id)
		if not rule_breaker is RuleBreakerDefinitionScript or state.build_ownership.acquired_rule_breaker_ids.has(rule_breaker.content_id):
			return {"accepted": false, "status": "INVALID_REWARD_CONTENT", "message": "The selected Boss Rule Breaker is unavailable."}
		var previous_phase: String = state.phase
		state.build_ownership.acquired_rule_breaker_ids.append(rule_breaker.content_id)
		if state.build_ownership.acquired_rule_breaker_ids.size() == 1:
			_record_run_milestone("first_rule_breaker_acquired")
		state.reward_draft = null
		var reward_data := {
			"run_id": state.run_id,
			"draft_id": boss_draft_id,
			"option_id": selected_option.option_id,
			"kind": RewardOptionScript.RULE_BREAKER,
			"content_id": rule_breaker.content_id,
			"rule_key": rule_breaker.rule_key,
			"permission_level": rule_breaker.permission_level,
			"reward_phase": previous_phase,
		}
		return {
			"accepted": true,
			"status": CommandResultScript.ACCEPTED,
			"events": [DomainEventScript.new(DomainEventScript.REWARD_SELECTED, reward_data)],
			"data": reward_data,
		}
	var draft_id: String = selected_draft_id if not selected_draft_id.is_empty() else state.reward_draft.draft_id
	var option = state.reward_draft.option_by_id(selected_option_id) if state.reward_draft != null else null
	if option == null:
		return {"accepted": false, "status": "INVALID_REWARD_OPTION", "message": "The selected reward option is not in the active draft."}
	var events: Array = []
	var data: Dictionary = {
		"draft_id": draft_id,
		"option_id": option.option_id,
		"kind": option.kind,
		"content_id": option.content_id,
		"tile_id": option.tile_id,
		"modifier_id": option.modifier_id,
	}
	var currency_transactions: Array = []
	if option.kind == RewardOptionScript.ADD_TILE:
		var tile_instance_result := _add_reward_tile(option)
		if not tile_instance_result.get("accepted", false):
			return tile_instance_result
		data["tile_instance_id"] = tile_instance_result["instance_id"]
	elif option.kind == RewardOptionScript.MODIFIED_TILE:
		var modifier_result := _apply_reward_modifier(option)
		if not modifier_result.get("accepted", false):
			return modifier_result
	elif option.kind == RewardOptionScript.SKIP:
		var skip_transaction: Dictionary = economy.apply_source(state, RunEconomyScript.GOLD, option.gold_delta, RunEconomyScript.SOURCE_NORMAL_REWARD_SKIP)
		if skip_transaction.is_empty():
			return {"accepted": false, "status": "CURRENCY_SOURCE_REJECTED", "message": "The configured Skip compensation could not be applied."}
		currency_transactions.append(skip_transaction)
		events.append(RunEconomyScript.event_for_transaction(skip_transaction))
	else:
		return {"accepted": false, "status": "INVALID_REWARD_OPTION", "message": "The selected reward option has an unsupported kind."}

	state.reward_draft = null
	var previous_phase: String = state.phase
	state.phase = RunPhaseScript.MAP_CHOICE
	data["currency_transactions"] = currency_transactions.duplicate(true)
	data["phase"] = state.phase
	events.append(DomainEventScript.new(DomainEventScript.REWARD_SELECTED, data.duplicate(true)))
	events.append(_run_phase_event(previous_phase, state.phase))
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": data,
	}

func _validate_reward_option(option) -> Dictionary:
	if option.kind == RewardOptionScript.SKIP:
		return {"accepted": true}
	if option.kind == RewardOptionScript.ADD_TILE:
		var tile_definition = content_registry.resolve(option.tile_id)
		if not tile_definition is TileDefinitionScript:
			return {"accepted": false, "status": "INVALID_REWARD_CONTENT", "message": "The Add Tile content ID is not registered."}
		var allowed_add_tile_suit := AlphaContractEffectsScript.normal_reward_add_tile_suit(content_registry, state.contract_id)
		if not allowed_add_tile_suit.is_empty() and tile_definition.suit != allowed_add_tile_suit:
			return {"accepted": false, "status": "CONTRACT_RESTRICTION", "message": "The selected Contract does not allow this Add Tile suit."}
		if tile_pool_editor.count_definition(option.tile_id) >= economy.tile_copy_limit:
			return {"accepted": false, "status": "COPY_LIMIT", "message": "Add Tile would exceed the TileDefinition copy limit."}
		return {"accepted": true}
	if option.kind == RewardOptionScript.MODIFIED_TILE:
		if not content_registry.resolve(option.tile_id) is TileDefinitionScript:
			return {"accepted": false, "status": "INVALID_REWARD_CONTENT", "message": "The Modified Tile target content ID is not registered."}
		var modifier = content_registry.resolve(option.modifier_id)
		if not modifier is TileModifierDefinitionScript:
			return {"accepted": false, "status": "INVALID_REWARD_CONTENT", "message": "The Modified Tile modifier ID is not registered."}
		if not tile_pool_editor.contains_instance(option.target_instance_id):
			return {"accepted": false, "status": "INVALID_REWARD_TARGET", "message": "The Modified Tile target is not owned by the run."}
		var modifiers: Array = state.build_ownership.persistent_tile_modifier_state.get(option.target_instance_id, [])
		if modifiers.has(option.modifier_id) and modifiers.count(option.modifier_id) >= modifier.max_per_tile:
			return {"accepted": false, "status": "MODIFIER_LIMIT_REACHED", "message": "The target TileInstance already has the maximum copies of this modifier."}
		return {"accepted": true}
	return {"accepted": false, "status": "INVALID_REWARD_OPTION", "message": "The selected reward option has an unsupported kind."}

func _add_reward_tile(option) -> Dictionary:
	var validation := _validate_reward_option(option)
	if not validation.get("accepted", false):
		return validation
	var tile_instance_result: Dictionary = tile_pool_editor.add_tile(option.tile_id)
	if not tile_instance_result.get("accepted", false):
		return {"accepted": false, "status": "REWARD_APPLICATION_REJECTED", "message": "The Add Tile could not be added to the Run Tile Pool."}
	return {"accepted": true, "instance_id": tile_instance_result.instance_id}

func _apply_reward_modifier(option) -> Dictionary:
	var modifiers: Array = state.build_ownership.persistent_tile_modifier_state.get(option.target_instance_id, []).duplicate()
	modifiers.append(option.modifier_id)
	state.build_ownership.persistent_tile_modifier_state[option.target_instance_id] = modifiers
	return {"accepted": true}

func _record_run_milestone(milestone_id: String) -> void:
	if not milestone_id.is_empty() and not state.milestones.has(milestone_id):
		state.milestones.append(milestone_id)

func _reward_phase_for_encounter(encounter_kind: String) -> String:
	if encounter_kind == EncounterDefinitionScript.ELITE:
		return RunPhaseScript.ELITE_REWARD
	if encounter_kind == EncounterDefinitionScript.BOSS:
		return RunPhaseScript.BOSS_REWARD
	return RunPhaseScript.REWARD_CHOICE

func _invalid_phase(expected_phase: String) -> RefCounted:
	return CommandValidationScript.new(
		false,
		"INVALID_PHASE",
		"The command is only legal during %s." % expected_phase,
		{"expected_phase": expected_phase, "actual_phase": state.phase},
	)

func _run_phase_event(previous_phase: String, next_phase: String):
	return DomainEventScript.new(DomainEventScript.RUN_PHASE_CHANGED, {
		"run_id": state.run_id,
		"from_phase": previous_phase,
		"to_phase": next_phase,
	})
