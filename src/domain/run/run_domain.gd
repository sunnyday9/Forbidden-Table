class_name RunDomain
extends RefCounted

const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const BattleCommandScript = preload("res://src/domain/commands/battle_command.gd")
const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const CharacterPassiveDefinitionScript = preload("res://src/content/definitions/character_passive_definition.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaContractEffectsScript = preload("res://src/domain/run/alpha_contract_effects.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RuleBreakerDefinitionScript = preload("res://src/content/definitions/rule_breaker_definition.gd")
const CombatStateScript = preload("res://src/domain/combat/combat_state.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const DomainRngStreamsScript = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifierScript = preload("res://src/infrastructure/replay/replay_verifier.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const EncounterFactoryScript = preload("res://src/domain/battle/encounter_factory.gd")
const EffectContextScript = preload("res://src/domain/effects/effect_context.gd")
const EffectScript = preload("res://src/domain/effects/effect.gd")
const ApplyRunModifierOperationScript = preload("res://src/domain/effects/operations/apply_run_modifier_operation.gd")
const ActiveEffectInstanceScript = preload("res://src/domain/effects/active_effect_instance.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const EventDefinitionScript = preload("res://src/content/definitions/event_definition.gd")
const EventStateScript = preload("res://src/domain/run/event_state.gd")
const LifecycleResolverScript = preload("res://src/domain/effects/lifecycle_resolver.gd")
const MiniActMapCatalogScript = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const RewardOptionScript = preload("res://src/domain/run/reward_option.gd")
const RewardDraftSelectorScript = preload("res://src/domain/run/reward_draft_selector.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunBattleSnapshotScript = preload("res://src/domain/run/run_battle_snapshot.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")
const RunModifierEffectResolverScript = preload("res://src/domain/run/run_modifier_effect_resolver.gd")
const RunMapStateScript = preload("res://src/domain/run/run_map_state.gd")
const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")
const RunTilePoolStateScript = preload("res://src/domain/run/run_tile_pool_state.gd")
const RunStateScript = preload("res://src/domain/run/run_state.gd")
const RunShopWorkshopFlowScript = preload("res://src/domain/run/run_shop_workshop_flow.gd")
const RunSummaryFlowScript = preload("res://src/domain/run/run_summary_flow.gd")
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")
const RunStartingPoolFactoryScript = preload("res://src/domain/run/run_starting_pool_factory.gd")
const ShopOfferSelectorScript = preload("res://src/domain/run/shop_offer_selector.gd")
const ShopStateScript = preload("res://src/domain/run/shop_state.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")
const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const WorkshopStateScript = preload("res://src/domain/run/workshop_state.gd")

var state
var content_registry
var rng_streams
var map_definition
var encounter_factory
var reward_draft_selector
var economy
var current_battle
var shop_offer_selector
var replay_record
var unlock_policy
var shop_workshop_flow
var run_summary_flow

func _init(
	initial_run_id: String = "run.1",
	initial_seed: int = 13,
	domain_content_registry = null,
	initial_content_version: String = "",
	domain_rng_streams = null,
	initial_act_count: int = 1,
	initial_tile_pool = null,
	initial_unlock_policy = null,
) -> void:
	content_registry = domain_content_registry if domain_content_registry != null else ContentRegistryScript.new()
	var resolved_content_version := initial_content_version
	if resolved_content_version.is_empty() and content_registry.has_method("content_version"):
		resolved_content_version = content_registry.content_version()
	rng_streams = domain_rng_streams if domain_rng_streams != null else DomainRngStreamsScript.new(initial_seed)
	map_definition = MiniActMapCatalogScript.definition()
	encounter_factory = EncounterFactoryScript.new(content_registry)
	reward_draft_selector = RewardDraftSelectorScript.new()
	economy = RunEconomyScript.new()
	shop_offer_selector = ShopOfferSelectorScript.new()
	current_battle = null
	unlock_policy = initial_unlock_policy if initial_unlock_policy is MetaProgressStateScript else MetaProgressStateScript.new()
	state = RunStateScript.new(initial_run_id, initial_seed, resolved_content_version, initial_tile_pool, null, initial_act_count)
	shop_workshop_flow = RunShopWorkshopFlowScript.new(state, content_registry, rng_streams, economy, shop_offer_selector)
	run_summary_flow = RunSummaryFlowScript.new(state, content_registry)
	replay_record = ReplayRecordScript.new(initial_seed, resolved_content_version, initial_run_id)
	replay_record.record_initial_checkpoint(checkpoint(), rng_snapshot(), _terminal_outcome())

func rebind_state(restored_state) -> void:
	state = restored_state
	shop_workshop_flow.bind_state(restored_state)
	run_summary_flow.bind_state(restored_state)

static func new_alpha_run(
	initial_run_id: String = "run.1",
	initial_seed: int = 13,
	domain_content_registry = null,
	initial_content_version: String = "",
	domain_rng_streams = null,
	initial_tile_pool = null,
	initial_unlock_policy = null,
):
	return RunDomain.new(initial_run_id, initial_seed, domain_content_registry, initial_content_version, domain_rng_streams, 2, initial_tile_pool, initial_unlock_policy)

func execute(command) -> RefCounted:
	var result: RefCounted
	if command == null or not command.has_method("execute"):
		result = CommandResultScript.new(
			"",
			"UnknownCommand",
			"",
			"",
			false,
			CommandResultScript.REJECTED,
			CommandValidationScript.new(false, "UNKNOWN_COMMAND", "Unsupported run command."),
		)
	elif command is BattleCommandScript:
		result = execute_battle(command)
	else:
		result = command.execute(self)
	if result != null and result.has_method("is_replayable") and result.is_replayable():
		replay_record.record_command(command.to_dictionary(), result.state_checkpoint, rng_snapshot(), _terminal_outcome(), result.events)
	return result

func verify_replay(record = replay_record, resume_factory: Callable = Callable()):
	var replay_factory := func(replay_seed: int, replay_content_version: String):
		if record != null and record is ReplayRecordScript and record.restored_replay_factory.is_valid():
			return record.restored_replay_factory.call(replay_seed, replay_content_version)
		var replay_run_id: String = state.run_id
		if record != null and not record.run_id.is_empty():
			replay_run_id = record.run_id
		var replay_domain = RunDomain.new(replay_run_id, replay_seed, content_registry, replay_content_version, null, state.act_count, null, unlock_policy)
		var initial_run_state: Dictionary = {}
		if record != null and not record.checkpoints.is_empty():
			var initial_domain_state: Dictionary = record.checkpoints[0].domain_snapshot.data
			initial_run_state = initial_domain_state.get("run_state", {})
		var initial_pool: Dictionary = initial_run_state.get("tile_pool", {}) if initial_run_state is Dictionary else {}
		var initial_tile_records: Array = []
		for tile_data in initial_pool.get("tile_instances", []):
			if not tile_data is Dictionary:
				continue
			var tile_record = RunTileInstanceRecordScript.new(
				str(tile_data.get("instance_id", "")),
				str(tile_data.get("definition_id", "")),
				str(tile_data.get("ownership_scope", "RUN")),
				str(tile_data.get("lifetime_scope", tile_data.get("lifetime", "RUN"))),
				str(tile_data.get("origin", "RUN_POOL")),
			)
			initial_tile_records.append(tile_record)
		var initial_tile_pool = RunTilePoolStateScript.new(initial_tile_records)
		return RunDomain.new(replay_run_id, replay_seed, content_registry, replay_content_version, null, state.act_count, initial_tile_pool, unlock_policy)
	return ReplayVerifierScript.verify(record, replay_factory, state.content_version, resume_factory)

func validate_choose_character(selected_character_id: String) -> RefCounted:
	if state.character_id == selected_character_id and not selected_character_id.is_empty():
		return CommandValidationScript.new(false, "DUPLICATE_CHOICE", "The Character has already been selected.")
	if state.phase != RunPhaseScript.CHARACTER_SELECT:
		return _invalid_phase(RunPhaseScript.CHARACTER_SELECT)
	var definition = content_registry.resolve(selected_character_id)
	if not definition is CharacterDefinitionScript:
		return CommandValidationScript.new(false, "INVALID_CHARACTER_ID", "The selected Character ID is not registered.")
	if not unlock_policy.is_unlocked("CHARACTER", selected_character_id):
		return CommandValidationScript.new(false, "CHARACTER_LOCKED", "The selected Character is locked in the active progression profile.", {"character_id": selected_character_id})
	var starting_tile_ids := RunStartingPoolFactoryScript.tile_definition_ids(definition.starting_tile_pool_bias)
	if starting_tile_ids.size() != RunStartingPoolFactoryScript.TILE_COUNT:
		return CommandValidationScript.new(false, "INVALID_STARTING_POOL", "The selected Character has no valid starting Tile Pool profile.", {"character_id": selected_character_id})
	for tile_id in starting_tile_ids:
		if not content_registry.resolve(tile_id) is TileDefinitionScript:
			return CommandValidationScript.new(false, "INVALID_STARTING_POOL", "The selected Character's starting Tile Pool references unavailable tile content.", {"character_id": selected_character_id, "tile_id": tile_id})
	return CommandValidationScript.new(true)

func execute_choose_character(selected_character_id: String) -> Dictionary:
	var previous_phase: String = state.phase
	var character = content_registry.resolve(selected_character_id)
	state.tile_pool = RunTilePoolStateScript.new(RunStartingPoolFactoryScript.create(selected_character_id, character.starting_tile_pool_bias))
	state.character_id = selected_character_id
	state.build_ownership.character_core_technique_id = character.core_technique_id
	if not state.build_ownership.owned_relic_ids.has(character.starting_relic_id):
		state.build_ownership.owned_relic_ids.append(character.starting_relic_id)
	_record_run_milestone("character_chosen")
	state.phase = RunPhaseScript.CONTRACT_SELECT
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": [
			DomainEventScript.new(DomainEventScript.CHARACTER_SELECTED, {
				"run_id": state.run_id,
				"character_id": selected_character_id,
			}),
			_run_phase_event(previous_phase, state.phase),
		],
		"data": {"character_id": selected_character_id, "phase": state.phase},
	}

func validate_choose_contract(selected_contract_id: String) -> RefCounted:
	if state.contract_id == selected_contract_id and not selected_contract_id.is_empty():
		return CommandValidationScript.new(false, "DUPLICATE_CHOICE", "The Contract has already been selected.")
	if state.phase != RunPhaseScript.CONTRACT_SELECT:
		return _invalid_phase(RunPhaseScript.CONTRACT_SELECT)
	var definition = content_registry.resolve(selected_contract_id)
	if not definition is ContractDefinitionScript:
		return CommandValidationScript.new(false, "INVALID_CONTRACT_ID", "The selected Contract ID is not registered.")
	if not unlock_policy.is_unlocked("CONTRACT", selected_contract_id):
		return CommandValidationScript.new(false, "CONTRACT_LOCKED", "The selected Contract is locked in the active progression profile.", {"contract_id": selected_contract_id})
	return CommandValidationScript.new(true)

func execute_choose_contract(selected_contract_id: String) -> Dictionary:
	var previous_phase: String = state.phase
	state.contract_id = selected_contract_id
	_record_run_milestone("contract_chosen")
	state.map_state.initialize(map_definition, rng_streams.map)
	state.phase = RunPhaseScript.MAP_CHOICE
	var selection_data := {"run_id": state.run_id, "contract_id": selected_contract_id}
	var contract_reward_transactions: Array = []
	var token_reward := AlphaContractEffectsScript.refinement_tokens_on_contract_selection(content_registry, selected_contract_id)
	if token_reward > 0:
		var token_transaction: Dictionary = economy.apply_source(state, RunEconomyScript.REFINEMENT_TOKENS, token_reward, RunEconomyScript.SOURCE_CONTRACT_SELECTION)
		if not token_transaction.is_empty():
			contract_reward_transactions.append(token_transaction)
	var yaku_hint := AlphaContractEffectsScript.yaku_hint(content_registry, selected_contract_id)
	if not yaku_hint.is_empty():
		selection_data["yaku_hint"] = yaku_hint
	if not contract_reward_transactions.is_empty():
		selection_data["currency_transactions"] = contract_reward_transactions.duplicate(true)
	var events: Array = [DomainEventScript.new(DomainEventScript.CONTRACT_SELECTED, selection_data.duplicate(true))]
	if not contract_reward_transactions.is_empty():
		_events_for_currency_transaction(events, contract_reward_transactions[0])
	events.append(_run_phase_event(previous_phase, state.phase))
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": selection_data.merged({"phase": state.phase}),
	}

func validate_select_map_node(selected_node_id: String) -> RefCounted:
	if state.phase != RunPhaseScript.MAP_CHOICE:
		return _invalid_phase(RunPhaseScript.MAP_CHOICE)
	if not state.map_state.is_initialized() or map_definition.graph_issues().size() > 0:
		return CommandValidationScript.new(false, "INVALID_MAP_DEFINITION", "The authored Mini-Act map is not navigable.")
	if not map_definition.node_ids.has(selected_node_id) or map_definition.node_definition(selected_node_id) == null:
		return CommandValidationScript.new(false, "INVALID_MAP_NODE_ID", "The selected Map Node ID is not authored.")
	if state.map_state.is_terminal():
		return CommandValidationScript.new(false, "TERMINAL_NODE", "The Boss is terminal and cannot be selected again.")
	if state.map_state.is_visited(selected_node_id):
		return CommandValidationScript.new(false, "VISITED_NODE", "The selected Map Node has already been visited.")
	if not state.map_state.is_adjacent(selected_node_id, map_definition):
		return CommandValidationScript.new(false, "NON_ADJACENT_NODE", "The selected Map Node is not adjacent to the current node.")
	var encounter_validation := _validate_node_encounter(selected_node_id)
	if not encounter_validation.get("accepted", true):
		return CommandValidationScript.new(false, encounter_validation.get("status", "INVALID_ENCOUNTER_DEFINITION"), encounter_validation.get("message", "The selected encounter is invalid."), encounter_validation.get("details", {}))
	return CommandValidationScript.new(true)

func execute_select_map_node(selected_node_id: String) -> Dictionary:
	var node = map_definition.node_definition(selected_node_id)
	var encounter_id := _encounter_id_for_node(selected_node_id)
	var battle = null
	if _is_battle_node(node) and not encounter_id.is_empty():
		battle = encounter_factory.create(state, encounter_id, rng_streams, _encounter_kind_for_node(node))
		if battle == null:
			return {"accepted": false, "status": encounter_factory.last_error.get("status", "INVALID_ENCOUNTER_DEFINITION"), "message": encounter_factory.last_error.get("message", "The selected encounter is invalid.")}
	var edge_id: String = state.map_state.select_node(selected_node_id, map_definition)
	var payload_id: String = state.map_state.payload_ids[selected_node_id]
	var event := DomainEventScript.new(DomainEventScript.MAP_NODE_SELECTED, {
		"run_id": state.run_id,
		"map_definition_id": state.map_state.map_definition_id,
		"node_id": selected_node_id,
		"edge_id": edge_id,
		"payload_id": payload_id,
	})
	var events: Array = [event]
	if battle != null:
		current_battle = battle
		state.phase = RunPhaseScript.BATTLE
		events.append(DomainEventScript.new(DomainEventScript.BATTLE_STARTED, {
			"run_id": state.run_id,
			"encounter_id": battle.encounter_id,
			"encounter_kind": battle.encounter_kind,
			"enemy_ids": battle.context.enemy_ids,
		}))
		events.append_array(battle.battle_start_effect_events)
		events.append(_run_phase_event(RunPhaseScript.MAP_CHOICE, state.phase))
		state.current_battle_snapshot = RunBattleSnapshotScript.new(battle.checkpoint())
		if battle.outcome() in [CombatStateScript.VICTORY, CombatStateScript.DEFEAT]:
			events.append_array(apply_battle_outcome())
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": {
			"node_id": selected_node_id,
			"edge_id": edge_id,
			"payload_id": payload_id,
			"phase": state.phase,
			"encounter_id": encounter_id,
		},
	}

func validate_enter_event(selected_event_id: String = "") -> RefCounted:
	if state.phase != RunPhaseScript.MAP_CHOICE:
		return _invalid_phase(RunPhaseScript.MAP_CHOICE)
	var node_id: String = state.map_state.current_node_id
	var node = map_definition.node_definition(node_id)
	if node == null or node.node_kind != "EVENT":
		return CommandValidationScript.new(false, "INVALID_EVENT_NODE", "Event entry requires the current Map Node to be an Event.")
	if state.event_state.active:
		return CommandValidationScript.new(false, "EVENT_ALREADY_ACTIVE", "An Event is already active.")
	if state.event_state.has_completed_node(node_id):
		return CommandValidationScript.new(false, "EVENT_COMPLETED", "This Event node has already been completed.")
	var authored_event_id := _event_id_for_node(node_id)
	var event_id := selected_event_id if not selected_event_id.is_empty() else authored_event_id
	if event_id.is_empty() or (not authored_event_id.is_empty() and event_id != authored_event_id):
		return CommandValidationScript.new(false, "INVALID_EVENT_ID", "The selected Event ID is not the current authored Event.")
	var definition = content_registry.resolve(event_id)
	if not definition is EventDefinitionScript:
		return CommandValidationScript.new(false, "INVALID_EVENT_DEFINITION", "The current Event ID is not a registered EventDefinition.")
	var definition_validation = definition.validate()
	if definition_validation == null or not definition_validation.is_valid():
		return CommandValidationScript.new(false, "INVALID_EVENT_DEFINITION", "The current EventDefinition is invalid.")
	return CommandValidationScript.new(true, CommandValidationScript.VALID, "", {"event_id": event_id})

func execute_enter_event(selected_event_id: String = "") -> Dictionary:
	var node_id: String = state.map_state.current_node_id
	var event_id := selected_event_id if not selected_event_id.is_empty() else _event_id_for_node(node_id)
	var definition = content_registry.resolve(event_id)
	var entry_id := "event.%s.%d" % [state.run_id, state.event_state.entry_sequence + 1]
	if not state.event_state.begin(node_id, entry_id, definition, rng_streams.event.snapshot()):
		return {"accepted": false, "status": "INVALID_EVENT_DEFINITION", "message": "The EventState could not begin the selected Event."}
	var previous_phase: String = state.phase
	state.phase = RunPhaseScript.EVENT
	var events: Array = [
		DomainEventScript.new(DomainEventScript.EVENT_ENTERED, {
			"run_id": state.run_id,
			"node_id": node_id,
			"entry_id": entry_id,
			"event_id": event_id,
			"option_ids": state.event_state.legal_choice_ids(),
			"event_rng_state": state.event_state.event_rng_state.duplicate(true),
		}),
		_run_phase_event(previous_phase, state.phase),
	]
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": {
			"node_id": node_id,
			"entry_id": entry_id,
			"event_id": event_id,
			"option_ids": state.event_state.legal_choice_ids(),
			"phase": state.phase,
		},
	}

func validate_choose_event_option(selected_event_id: String, selected_entry_id: String, selected_option_id: String) -> RefCounted:
	if state.phase != RunPhaseScript.EVENT or not state.event_state.active:
		return _invalid_phase(RunPhaseScript.EVENT)
	if not selected_event_id.is_empty() and selected_event_id != state.event_state.event_id:
		return CommandValidationScript.new(false, "INVALID_EVENT_ID", "The selected Event ID is not active.")
	if not selected_entry_id.is_empty() and selected_entry_id != state.event_state.entry_id:
		return CommandValidationScript.new(false, "INVALID_EVENT_ENTRY", "The selected Event entry is not active.")
	var choice = state.event_state.choice_by_id(selected_option_id)
	if choice == null:
		return CommandValidationScript.new(false, "INVALID_EVENT_OPTION", "The selected Event option ID is not legal for the active Event.")
	var effects_validation := _validate_event_choice_effects(choice)
	if not effects_validation.get("accepted", false):
		return CommandValidationScript.new(false, effects_validation.get("status", "INVALID_EVENT_EFFECT"), effects_validation.get("message", "The selected Event option cannot be resolved."), effects_validation.get("details", {}))
	return CommandValidationScript.new(true, CommandValidationScript.VALID, "", {
		"event_id": state.event_state.event_id,
		"entry_id": state.event_state.entry_id,
		"option_id": selected_option_id,
	})

func execute_choose_event_option(selected_event_id: String, selected_entry_id: String, selected_option_id: String) -> Dictionary:
	var choice = state.event_state.choice_by_id(selected_option_id)
	if choice == null:
		return {"accepted": false, "status": "INVALID_EVENT_OPTION", "message": "The selected Event option ID is not legal for the active Event."}
	var resolution_rng_state: Dictionary = rng_streams.snapshot()
	var resolution_state: Dictionary = _event_resolution_snapshot()
	var alternative := _select_event_alternative(choice)
	var events: Array = [DomainEventScript.new(DomainEventScript.EVENT_OPTION_CHOSEN, {
		"run_id": state.run_id,
		"event_id": state.event_state.event_id,
		"entry_id": state.event_state.entry_id if selected_entry_id.is_empty() else selected_entry_id,
		"option_id": selected_option_id,
	})]
	var alternative_id := str(alternative.get("alternative_id", ""))
	if not alternative_id.is_empty():
		events.append(DomainEventScript.new(DomainEventScript.EVENT_ALTERNATIVE_RESOLVED, {
			"run_id": state.run_id,
			"event_id": state.event_state.event_id,
			"entry_id": state.event_state.entry_id,
			"option_id": selected_option_id,
			"alternative_id": alternative_id,
			"roll": alternative.get("roll", 0),
			"total_weight": alternative.get("total_weight", 0),
		}))
	var effects: Array = choice.get("effects", []).duplicate(true) if choice is Dictionary else []
	effects.append_array(alternative.get("effects", []).duplicate(true))
	var effects_result := _resolve_event_effects(effects)
	if not effects_result.get("accepted", false):
		_restore_event_resolution_snapshot(resolution_state)
		rng_streams.restore(resolution_rng_state)
		return effects_result
	events.append_array(effects_result.get("events", []))
	state.event_state.event_rng_state = rng_streams.event.snapshot()
	state.event_state.mark_completed(selected_option_id, alternative_id)
	var previous_phase: String = state.phase
	state.phase = RunPhaseScript.MAP_CHOICE
	var resolution_data := {
		"run_id": state.run_id,
		"event_id": state.event_state.event_id,
		"entry_id": state.event_state.entry_id,
		"node_id": state.event_state.node_id,
		"option_id": selected_option_id,
		"alternative_id": alternative_id,
		"event_rng_state": state.event_state.event_rng_state.duplicate(true),
		"phase": state.phase,
	}
	events.append(DomainEventScript.new(DomainEventScript.EVENT_RESOLVED, resolution_data.duplicate(true)))
	events.append(DomainEventScript.new(DomainEventScript.EVENT_EXITED, resolution_data.duplicate(true)))
	events.append(_run_phase_event(previous_phase, state.phase))
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": resolution_data,
	}

func advance_run_boundary(boundary: String) -> Array:
	return LifecycleResolverScript.new().advance(state, boundary)

func _validate_event_choice_effects(choice: Dictionary) -> Dictionary:
	var effects = choice.get("effects", [])
	if not effects is Array:
		return {"accepted": false, "status": "INVALID_EVENT_EFFECTS", "message": "Event choice effects must be an Array."}
	var alternatives = choice.get("alternatives", [])
	if not alternatives is Array:
		return {"accepted": false, "status": "INVALID_EVENT_ALTERNATIVES", "message": "Event alternatives must be an Array."}
	var all_effect_sets: Array = [effects]
	for alternative in alternatives:
		if not alternative is Dictionary:
			return {"accepted": false, "status": "INVALID_EVENT_ALTERNATIVE", "message": "Event alternatives must be dictionaries."}
		var alternative_effects = alternative.get("effects", [])
		if not alternative_effects is Array:
			return {"accepted": false, "status": "INVALID_EVENT_EFFECTS", "message": "Event alternative effects must be an Array."}
		var combined_effects: Array = effects.duplicate(true)
		combined_effects.append_array(alternative_effects.duplicate(true))
		all_effect_sets.append(combined_effects)
	for effect_set in all_effect_sets:
		var projected_gold: int = state.gold
		var projected_tokens: int = state.refinement_tokens
		for effect in effect_set:
			if effect is EffectScript:
				var effect_validation: Dictionary = effect.validate_in_context(EffectContextScript.new(state))
				if not effect_validation.get("valid", false):
					return {"accepted": false, "status": "INVALID_EVENT_EFFECT", "message": "An Event Effect cannot be resolved.", "details": effect_validation}
				for operation in effect.operations:
					if operation.has_method("to_dictionary"):
						var operation_data: Dictionary = operation.to_dictionary()
						if operation_data.get("operation_id", "") == "ModifyRunCurrency":
							var amount := int(operation_data.get("amount", 0))
							if operation_data.get("currency", "") == RunEconomyScript.GOLD:
								projected_gold += amount
								if projected_gold < 0:
									return {"accepted": false, "status": "INSUFFICIENT_GOLD", "message": "The Event choice requires more Gold than the run owns."}
							elif operation_data.get("currency", "") == RunEconomyScript.REFINEMENT_TOKENS:
								projected_tokens += amount
								if projected_tokens < 0:
									return {"accepted": false, "status": "INSUFFICIENT_REFINEMENT_TOKENS", "message": "The Event choice requires more Refinement Tokens than the run owns."}
			elif effect is Dictionary:
				var dictionary_validation := _validate_declarative_event_effect(effect)
				if not dictionary_validation.get("accepted", false):
					return dictionary_validation
				var declarative_kind := str(effect.get("kind", effect.get("type", effect.get("effect_type", ""))))
				if declarative_kind in ["GOLD", "GOLD_DELTA", "REFINEMENT_TOKENS", "REFINEMENT_TOKENS_DELTA"]:
					var declarative_currency := RunEconomyScript.GOLD if declarative_kind.begins_with("GOLD") else RunEconomyScript.REFINEMENT_TOKENS
					var declarative_amount := int(effect.get("amount", effect.get("delta", 0)))
					if declarative_currency == RunEconomyScript.GOLD:
						projected_gold += declarative_amount
						if projected_gold < 0:
							return {"accepted": false, "status": "INSUFFICIENT_GOLD", "message": "The Event choice requires more Gold than the run owns."}
					else:
						projected_tokens += declarative_amount
						if projected_tokens < 0:
							return {"accepted": false, "status": "INSUFFICIENT_REFINEMENT_TOKENS", "message": "The Event choice requires more Refinement Tokens than the run owns."}
			else:
				return {"accepted": false, "status": "INVALID_EVENT_EFFECT", "message": "Event choices require typed declarative Effects."}
	return {"accepted": true}

func _event_resolution_snapshot() -> Dictionary:
	var active_effect_objects: Dictionary = {}
	var active_effect_data: Dictionary = {}
	for effect_key in state.active_effects.keys():
		var effect = state.active_effects[effect_key]
		active_effect_objects[effect_key] = effect
		if effect is ActiveEffectInstanceScript:
			active_effect_data[effect_key] = effect.to_dictionary()
	return {
		"gold": state.gold,
		"refinement_tokens": state.refinement_tokens,
		"phase": state.phase,
		"knowledge_state": state.map_state.knowledge_state.duplicate(true),
		"last_events": state.map_state.last_events.duplicate(true),
		"event_rng_state": state.event_state.event_rng_state.duplicate(true),
		"active_effect_objects": active_effect_objects,
		"active_effect_data": active_effect_data,
	}

func _restore_event_resolution_snapshot(snapshot: Dictionary) -> void:
	state.gold = int(snapshot.get("gold", state.gold))
	state.refinement_tokens = int(snapshot.get("refinement_tokens", state.refinement_tokens))
	state.phase = str(snapshot.get("phase", state.phase))
	state.map_state.knowledge_state.clear()
	for node_id in snapshot.get("knowledge_state", {}).keys():
		state.map_state.knowledge_state[node_id] = snapshot["knowledge_state"][node_id]
	state.map_state.last_events = snapshot.get("last_events", []).duplicate(true)
	state.event_state.event_rng_state = snapshot.get("event_rng_state", {}).duplicate(true)
	state.active_effects.clear()
	var active_effect_objects: Dictionary = snapshot.get("active_effect_objects", {})
	var active_effect_data: Dictionary = snapshot.get("active_effect_data", {})
	for effect_key in active_effect_objects.keys():
		var effect = active_effect_objects[effect_key]
		var effect_data: Dictionary = active_effect_data.get(effect_key, {})
		if effect is ActiveEffectInstanceScript and not effect_data.is_empty():
			effect.instance_id = str(effect_data.get("instance_id", effect.instance_id))
			effect.definition_id = str(effect_data.get("definition_id", effect.definition_id))
			effect.source_id = str(effect_data.get("source_id", effect.source_id))
			var duration_data: Dictionary = effect_data.get("duration", {})
			effect.duration_scope = str(duration_data.get("scope", effect.duration_scope))
			effect.remaining = int(duration_data.get("remaining", effect.remaining))
			effect.stacks = int(effect_data.get("stacks", effect.stacks))
			effect.stack_policy = str(effect_data.get("stack_policy", effect.stack_policy))
			effect.max_stacks = int(effect_data.get("max_stacks", effect.max_stacks))
			effect.uses_remaining = int(effect_data.get("uses_remaining", effect.uses_remaining))
			effect.charges_remaining = int(effect_data.get("charges_remaining", effect.charges_remaining))
			effect.runtime_parameters = effect_data.get("runtime_parameters", {}).duplicate(true)
		state.active_effects[effect_key] = effect

func _resolve_event_effects(effects: Array) -> Dictionary:
	var events: Array = []
	var sequence_index := 0
	for effect in effects:
		if effect is EffectScript:
			var result = effect.resolve_in_context(EffectContextScript.new(state), sequence_index)
			if result == null or not result.is_resolved():
				return {"accepted": false, "status": "EVENT_EFFECT_REJECTED", "message": "An Event Effect was rejected during resolution."}
			events.append_array(result.events)
		elif effect is Dictionary:
			var dictionary_result := _resolve_declarative_event_effect(effect, sequence_index)
			if not dictionary_result.get("accepted", false):
				return dictionary_result
			events.append_array(dictionary_result.get("events", []))
		else:
			return {"accepted": false, "status": "INVALID_EVENT_EFFECT", "message": "Event choices require typed declarative Effects."}
		sequence_index += 1
	return {"accepted": true, "events": events}

func _select_event_alternative(choice: Dictionary) -> Dictionary:
	var alternatives = choice.get("alternatives", [])
	if not alternatives is Array or alternatives.is_empty():
		return {}
	var total_weight := 0
	for alternative in alternatives:
		if alternative is Dictionary:
			total_weight += maxi(0, int(alternative.get("weight", 0)))
	if total_weight <= 0:
		return {}
	var roll: int = rng_streams.event.next_int(1, total_weight)
	var cumulative := 0
	for alternative in alternatives:
		if not alternative is Dictionary:
			continue
		cumulative += maxi(0, int(alternative.get("weight", 0)))
		if roll <= cumulative:
			var selected: Dictionary = alternative.duplicate(true)
			selected["roll"] = roll
			selected["total_weight"] = total_weight
			return selected
	return {}

func _validate_declarative_event_effect(effect: Dictionary) -> Dictionary:
	var kind := str(effect.get("kind", effect.get("type", effect.get("effect_type", ""))))
	if kind in ["GOLD", "GOLD_DELTA", "REFINEMENT_TOKENS", "REFINEMENT_TOKENS_DELTA"]:
		var currency := RunEconomyScript.GOLD if kind.begins_with("GOLD") else RunEconomyScript.REFINEMENT_TOKENS
		var amount := int(effect.get("amount", effect.get("delta", 0)))
		var current: int = state.gold if currency == RunEconomyScript.GOLD else state.refinement_tokens
		if current + amount < 0:
			return {"accepted": false, "status": "INSUFFICIENT_%s" % currency, "message": "The Event choice requires more currency than the run owns."}
		return {"accepted": true}
	if kind == "RUN_MODIFIER":
		var modifier_id := str(effect.get("modifier_id", ""))
		var scope := str(effect.get("scope", ""))
		var duration_amount := int(effect.get("duration_amount", effect.get("amount", 1)))
		var stack_policy := str(effect.get("stack_policy", StackPolicyScript.REPLACE))
		if modifier_id.is_empty() or scope.is_empty() or scope == DurationSpecScript.PERMANENT:
			return {"accepted": false, "status": "INVALID_MODIFIER_SCOPE", "message": "Run modifiers require a stable ID and explicit scope."}
		if not [DurationSpecScript.ACTION, DurationSpecScript.WINDOW, DurationSpecScript.SETTLEMENT_WINDOW, DurationSpecScript.TURN, DurationSpecScript.BATTLE, DurationSpecScript.BOSS_PHASE, DurationSpecScript.ACT, DurationSpecScript.RUN].has(scope) or duration_amount <= 0:
			return {"accepted": false, "status": "INVALID_MODIFIER_SCOPE", "message": "Run modifiers require a positive supported DurationSpec boundary."}
		if not [StackPolicyScript.REPLACE, StackPolicyScript.REFRESH_DURATION, StackPolicyScript.ADD_STACKS, StackPolicyScript.ADD_DURATION, StackPolicyScript.INDEPENDENT_INSTANCES, StackPolicyScript.UNIQUE].has(stack_policy):
			return {"accepted": false, "status": "INVALID_MODIFIER_STACK_POLICY", "message": "Run modifiers require a supported StackPolicy."}
		return {"accepted": true}
	if kind == "MAP_REVEAL":
		if not effect.get("node_ids", []) is Array:
			return {"accepted": false, "status": "INVALID_MAP_REVEAL", "message": "Map reveal effects require stable node IDs."}
		return {"accepted": true}
	return {"accepted": false, "status": "INVALID_EVENT_EFFECT", "message": "The Event declarative Effect kind is unsupported."}

func _resolve_declarative_event_effect(effect: Dictionary, sequence_index: int) -> Dictionary:
	var kind := str(effect.get("kind", effect.get("type", effect.get("effect_type", ""))))
	if kind in ["GOLD", "GOLD_DELTA", "REFINEMENT_TOKENS", "REFINEMENT_TOKENS_DELTA"]:
		var currency := RunEconomyScript.GOLD if kind.begins_with("GOLD") else RunEconomyScript.REFINEMENT_TOKENS
		var amount := int(effect.get("amount", effect.get("delta", 0)))
		var transaction: Dictionary = economy.apply_source(state, currency, amount, RunEconomyScript.SOURCE_HIGH_RISK_CONTENT) if amount >= 0 else economy.apply_sink(state, currency, -amount, RunEconomyScript.SINK_EVENT_TRADE)
		if transaction.is_empty():
			return {"accepted": false, "status": "EVENT_EFFECT_REJECTED", "message": "The Event currency effect was rejected."}
		transaction["sequence_index"] = sequence_index
		var event_type := DomainEventScript.GOLD_CHANGED if currency == RunEconomyScript.GOLD else DomainEventScript.REFINEMENT_TOKENS_CHANGED
		return {"accepted": true, "events": [DomainEventScript.new(event_type, transaction)]}
	if kind == "MAP_REVEAL":
		var revealed: Array[String] = []
		for node_id in effect.get("node_ids", []):
			var node_id_text := str(node_id)
			if map_definition.node_ids.has(node_id_text):
				state.map_state.knowledge_state[node_id_text] = RunMapStateScript.EXACT
				revealed.append(node_id_text)
		return {"accepted": true, "events": [DomainEventScript.new(DomainEventScript.MAP_REVEALED, {"run_id": state.run_id, "node_ids": revealed, "sequence_index": sequence_index})]}
	if kind == "RUN_MODIFIER":
		var modifier_id := str(effect.get("modifier_id", ""))
		var scope := str(effect.get("scope", ""))
		var duration_amount := int(effect.get("duration_amount", effect.get("amount", 1)))
		var duration := DurationSpecScript.new(scope, duration_amount)
		var stack_policy := str(effect.get("stack_policy", StackPolicyScript.REPLACE))
		var source_id := str(effect.get("source_id", state.contract_id))
		var parameters: Dictionary = effect.get("parameters", {}) if effect.get("parameters", {}) is Dictionary else {}
		var operation := ApplyRunModifierOperationScript.new(
			modifier_id,
			int(effect.get("value", 1)),
			duration,
			stack_policy,
			source_id,
			parameters,
		)
		var typed_effect := EffectScript.new("event.modifier.%s.%d" % [modifier_id, sequence_index], null, [], [], [operation], duration, stack_policy, source_id)
		var result = typed_effect.resolve_in_context(EffectContextScript.new(state), sequence_index)
		if result == null or not result.is_resolved():
			return {"accepted": false, "status": "EVENT_EFFECT_REJECTED", "message": "The Event run modifier was rejected."}
		return {"accepted": true, "events": result.events}
	return {"accepted": false, "status": "INVALID_EVENT_EFFECT", "message": "The Event declarative Effect kind is unsupported."}

func validate_enter_shop() -> RefCounted:
	return shop_workshop_flow.validate(RunShopWorkshopFlowScript.ENTER_SHOP, {"map_definition": map_definition})

func execute_enter_shop() -> Dictionary:
	return shop_workshop_flow.execute(RunShopWorkshopFlowScript.ENTER_SHOP)

func validate_buy_shop_offer(selected_entry_id: String, selected_offer_id: String) -> RefCounted:
	return shop_workshop_flow.validate(RunShopWorkshopFlowScript.BUY_SHOP_OFFER, {
		"entry_id": selected_entry_id,
		"offer_id": selected_offer_id,
	})

func execute_buy_shop_offer(selected_entry_id: String, selected_offer_id: String) -> Dictionary:
	return shop_workshop_flow.execute(RunShopWorkshopFlowScript.BUY_SHOP_OFFER, {
		"entry_id": selected_entry_id,
		"offer_id": selected_offer_id,
	})

func validate_refresh_shop(selected_entry_id: String) -> RefCounted:
	return shop_workshop_flow.validate(RunShopWorkshopFlowScript.REFRESH_SHOP, {"entry_id": selected_entry_id})

func execute_refresh_shop(selected_entry_id: String) -> Dictionary:
	return shop_workshop_flow.execute(RunShopWorkshopFlowScript.REFRESH_SHOP, {"entry_id": selected_entry_id})

func validate_exit_shop() -> RefCounted:
	return shop_workshop_flow.validate(RunShopWorkshopFlowScript.EXIT_SHOP)

func execute_exit_shop() -> Dictionary:
	return shop_workshop_flow.execute(RunShopWorkshopFlowScript.EXIT_SHOP)

func validate_enter_workshop() -> RefCounted:
	return shop_workshop_flow.validate(RunShopWorkshopFlowScript.ENTER_WORKSHOP, {"map_definition": map_definition})

func execute_enter_workshop() -> Dictionary:
	return shop_workshop_flow.execute(RunShopWorkshopFlowScript.ENTER_WORKSHOP)

func validate_use_workshop_service(
	service_id: String,
	instance_id: String,
	value_id: String = "",
	modifier_id: String = "",
	replace_existing: bool = false,
) -> RefCounted:
	return shop_workshop_flow.validate(RunShopWorkshopFlowScript.USE_WORKSHOP_SERVICE, {
		"service_id": service_id,
		"instance_id": instance_id,
		"value_id": value_id,
		"modifier_id": modifier_id,
		"replace_existing": replace_existing,
	})

func execute_use_workshop_service(
	service_id: String,
	instance_id: String,
	value_id: String = "",
	modifier_id: String = "",
	replace_existing: bool = false,
) -> Dictionary:
	return shop_workshop_flow.execute(RunShopWorkshopFlowScript.USE_WORKSHOP_SERVICE, {
		"service_id": service_id,
		"instance_id": instance_id,
		"value_id": value_id,
		"modifier_id": modifier_id,
		"replace_existing": replace_existing,
	})

func validate_exit_workshop() -> RefCounted:
	return shop_workshop_flow.validate(RunShopWorkshopFlowScript.EXIT_WORKSHOP)

func execute_exit_workshop() -> Dictionary:
	return shop_workshop_flow.execute(RunShopWorkshopFlowScript.EXIT_WORKSHOP)

func execute_battle(command):
	var before_checkpoint: Dictionary = checkpoint()
	if state.phase != RunPhaseScript.BATTLE or current_battle == null:
		return CommandResultScript.new(
			command.command_id if command != null else "",
			command.command_type() if command != null and command.has_method("command_type") else "BattleCommand",
			command.actor_id if command != null else "",
			command.target_id if command != null else "",
			false,
			CommandResultScript.REJECTED,
			CommandValidationScript.new(false, "INVALID_PHASE", "Battle commands require an active BattleDomain."),
			[],
			before_checkpoint,
			before_checkpoint,
		)
	var result = current_battle.execute(command)
	var passive_events: Array = []
	if result.accepted:
		_record_run_summary_metrics(result.data, result.events)
		if _has_event_type(result.events, DomainEventScript.COMPLETE_HAND_SETTLED):
			var character = content_registry.resolve(state.character_id)
			var passive = content_registry.resolve(character.signature_passive_id) if character is CharacterDefinitionScript else null
			if passive is CharacterPassiveDefinitionScript and passive.trigger_id == CharacterPassiveDefinitionScript.AFTER_COMPLETE_HAND:
				var passive_result: Dictionary = current_battle.resolve_character_passive(passive)
				if passive_result.get("accepted", false):
					passive_events = passive_result.get("events", [])
	var transfer_events: Array = []
	if current_battle != null and current_battle.combat_state != null:
		state.current_battle_snapshot = RunBattleSnapshotScript.new(current_battle.checkpoint())
		if current_battle.is_terminal():
			transfer_events = apply_battle_outcome()
	var result_data: Dictionary = result.data.duplicate(true)
	result_data["run_phase"] = state.phase
	return CommandResultScript.new(
		result.command_id,
		result.command_type,
		result.actor_id,
		result.target_id,
		result.accepted,
		result.status,
		result.validation,
		result.events + passive_events + transfer_events,
		before_checkpoint,
		checkpoint(),
		result.preview,
		result.message,
		result_data,
	)

func apply_battle_outcome() -> Array:
	if state.phase != RunPhaseScript.BATTLE or current_battle == null:
		return []
	var outcome: String = current_battle.outcome()
	if not [CombatStateScript.VICTORY, CombatStateScript.DEFEAT].has(outcome):
		return []
	var encounter_id_before: String = current_battle.encounter_id
	var encounter_kind_before: String = current_battle.encounter_kind
	var reward_tax_requested: int = maxi(0, int(current_battle.combat_state.reward_tax))
	var events: Array = [DomainEventScript.new(DomainEventScript.BATTLE_OUTCOME_TRANSFERRED, {
		"run_id": state.run_id,
		"encounter_id": encounter_id_before,
		"encounter_kind": encounter_kind_before,
		"outcome": outcome,
	})]
	events.append_array(current_battle.end_battle())
	if outcome == CombatStateScript.VICTORY and encounter_kind_before == EncounterDefinitionScript.BOSS:
		state.boss_progress.append({"act_index": state.act_index, "encounter_id": encounter_id_before})
		_record_run_milestone("act_%d_boss_defeated" % state.act_index)
	current_battle = null
	state.current_battle_snapshot = null
	if outcome == CombatStateScript.DEFEAT:
		events.append_array(enter_run_summary("DEFEAT", "BATTLE_DEFEAT", {"encounter_id": encounter_id_before}))
		state.map_state.last_events = events
		return events
	if reward_tax_requested > 0:
		var reward_tax_applied: int = mini(reward_tax_requested, maxi(0, state.gold))
		if reward_tax_applied > 0:
			var tax_transaction: Dictionary = economy.apply_sink(
				state,
				RunEconomyScript.GOLD,
				reward_tax_applied,
				RunEconomyScript.SINK_ENEMY_REWARD_TAX,
			)
			_events_for_currency_transaction(events, tax_transaction)
		events.append(DomainEventScript.new(DomainEventScript.ENEMY_REWARD_TAX_APPLIED, {
			"encounter_id": encounter_id_before,
			"requested_amount": reward_tax_requested,
			"amount": reward_tax_applied,
			"currency": RunEconomyScript.GOLD,
		}))
	var risk_bargain_gold: int = RunModifierEffectResolverScript.new().risk_bargain_victory_gold(state)
	if risk_bargain_gold > 0:
		var risk_bargain_transaction: Dictionary = economy.apply_source(
			state,
			RunEconomyScript.GOLD,
			risk_bargain_gold,
			RunEconomyScript.SOURCE_EVENT_RISK_BARGAIN_VICTORY,
		)
		if not risk_bargain_transaction.is_empty():
			_events_for_currency_transaction(events, risk_bargain_transaction)
	var previous_phase: String = state.phase
	state.phase = _reward_phase_for_encounter(encounter_kind_before)
	if encounter_kind_before == EncounterDefinitionScript.NORMAL:
		var draft_index: int = state.reward_draft_sequence
		state.reward_draft_sequence += 1
		state.reward_draft = reward_draft_selector.create_normal_draft(
			state,
			content_registry,
			rng_streams.reward,
			encounter_id_before,
			draft_index,
			economy.normal_skip_gold,
			economy.tile_copy_limit,
		)
		events.append(DomainEventScript.new(DomainEventScript.REWARD_DRAFT_CREATED, {
			"run_id": state.run_id,
			"draft": state.reward_draft.to_dictionary(),
		}))
	elif encounter_kind_before == EncounterDefinitionScript.ELITE:
		var draft_index: int = state.reward_draft_sequence
		state.reward_draft_sequence += 1
		state.reward_draft = reward_draft_selector.create_elite_build_draft(
			state,
			content_registry,
			rng_streams.reward,
			encounter_id_before,
			draft_index,
			Phase2CatalogScript.REWARD_POOL_ID,
			AlphaContractEffectsScript.elite_skip_gold(economy.elite_skip_gold, content_registry, state.contract_id),
			AlphaContractEffectsScript.refinement_tokens_on_elite_skip(content_registry, state.contract_id),
		)
		if state.reward_draft != null:
			events.append(DomainEventScript.new(DomainEventScript.REWARD_DRAFT_CREATED, {
				"run_id": state.run_id,
				"draft": state.reward_draft.to_dictionary(),
			}))
	elif encounter_kind_before == EncounterDefinitionScript.BOSS:
		var draft_index: int = state.reward_draft_sequence
		state.reward_draft_sequence += 1
		var boss_reward_pool_id: String = Phase2CatalogScript.BOSS_RULE_BREAKER_POOL_ID
		if state.act_index >= 2:
			boss_reward_pool_id = AlphaActTwoCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_POOL_ID
		state.reward_draft = reward_draft_selector.create_boss_rule_breaker_draft(
			state,
			content_registry,
			rng_streams.reward,
			encounter_id_before,
			draft_index,
			boss_reward_pool_id,
		)
		if state.reward_draft != null:
			events.append(DomainEventScript.new(DomainEventScript.REWARD_DRAFT_CREATED, {
				"run_id": state.run_id,
				"draft": state.reward_draft.to_dictionary(),
			}))
	events.append(_run_phase_event(previous_phase, state.phase))
	state.map_state.last_events = events
	return events

func validate_choose_reward(selected_draft_id: String, selected_option_id: String) -> RefCounted:
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

func execute_choose_reward(selected_draft_id: String, selected_option_id: String) -> Dictionary:
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
			_events_for_currency_transaction(events, skip_transaction)
			if option.refinement_token_delta > 0:
				var token_transaction: Dictionary = economy.apply_source(state, RunEconomyScript.REFINEMENT_TOKENS, option.refinement_token_delta, RunEconomyScript.SOURCE_ELITE_REWARD)
				if token_transaction.is_empty():
					return {"accepted": false, "status": "CURRENCY_SOURCE_REJECTED", "message": "The configured Elite Skip token compensation could not be applied."}
				currency_transactions.append(token_transaction)
				_events_for_currency_transaction(events, token_transaction)
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
		var boss_events: Array = [DomainEventScript.new(DomainEventScript.REWARD_SELECTED, reward_data)]
		if state.act_index < state.act_count:
			boss_events.append_array(_transition_to_act_two(previous_phase))
		else:
			boss_events.append_array(enter_run_summary("VICTORY", "BOSS_DEFEATED", {
				"act_index": state.act_index,
				"reward_option_id": selected_option.option_id,
				"rule_breaker_id": rule_breaker.content_id,
			}))
		state.map_state.last_events = boss_events
		return {
			"accepted": true,
			"status": CommandResultScript.ACCEPTED,
			"events": boss_events,
			"data": reward_data.merged({"phase": state.phase}),
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
		_events_for_currency_transaction(events, skip_transaction)
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
		if _tile_definition_count(option.tile_id) >= economy.tile_copy_limit:
			return {"accepted": false, "status": "COPY_LIMIT", "message": "Add Tile would exceed the TileDefinition copy limit."}
		return {"accepted": true}
	if option.kind == RewardOptionScript.MODIFIED_TILE:
		if not content_registry.resolve(option.tile_id) is TileDefinitionScript:
			return {"accepted": false, "status": "INVALID_REWARD_CONTENT", "message": "The Modified Tile target content ID is not registered."}
		var modifier = content_registry.resolve(option.modifier_id)
		if not modifier is TileModifierDefinitionScript:
			return {"accepted": false, "status": "INVALID_REWARD_CONTENT", "message": "The Modified Tile modifier ID is not registered."}
		if not _tile_instance_exists(option.target_instance_id):
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
	var tile_instance_result := _next_tile_instance_id()
	var tile_instance := RunTileInstanceRecordScript.new(
		tile_instance_result["instance_id"],
		option.tile_id,
		"RUN",
		"RUN",
	)
	if not state.tile_pool.add_tile_instance(tile_instance):
		return {"accepted": false, "status": "REWARD_APPLICATION_REJECTED", "message": "The Add Tile could not be added to the Run Tile Pool."}
	state.tile_instance_sequence = tile_instance_result["sequence"]
	return {"accepted": true, "instance_id": tile_instance.instance_id}

func _apply_reward_modifier(option) -> Dictionary:
	var modifiers: Array = state.build_ownership.persistent_tile_modifier_state.get(option.target_instance_id, []).duplicate()
	modifiers.append(option.modifier_id)
	state.build_ownership.persistent_tile_modifier_state[option.target_instance_id] = modifiers
	return {"accepted": true}

func _tile_definition_count(definition_id: String, excluded_instance_id: String = "") -> int:
	var count := 0
	for tile_instance in state.tile_pool.tile_instances:
		if tile_instance.instance_id != excluded_instance_id and tile_instance.definition_id == definition_id:
			count += 1
	return count

func _next_tile_instance_id() -> Dictionary:
	var sequence: int = state.tile_instance_sequence
	var instance_id := ""
	while instance_id.is_empty() or _tile_instance_exists(instance_id):
		sequence += 1
		instance_id = "run.tile.%d" % sequence
	return {"sequence": sequence, "instance_id": instance_id}

func _tile_instance_exists(instance_id: String) -> bool:
	for tile_instance in state.tile_pool.tile_instances:
		if tile_instance.instance_id == instance_id:
			return true
	return false

func _events_for_currency_transaction(events: Array, transaction: Dictionary) -> void:
	var event_type := DomainEventScript.GOLD_CHANGED if transaction.currency == RunEconomyScript.GOLD else DomainEventScript.REFINEMENT_TOKENS_CHANGED
	events.append(DomainEventScript.new(event_type, transaction))

func _record_run_milestone(milestone_id: String) -> void:
	if not milestone_id.is_empty() and not state.milestones.has(milestone_id):
		state.milestones.append(milestone_id)

func _has_event_type(events: Array, event_type: String) -> bool:
	for event in events:
		if event != null and event.event_type == event_type:
			return true
	return false

func _validate_node_encounter(node_id: String) -> Dictionary:
	var node = map_definition.node_definition(node_id)
	if not _is_battle_node(node):
		return {"accepted": true}
	var encounter_id := _encounter_id_for_node(node_id)
	if encounter_id.is_empty():
		return {"accepted": true} if not _has_registered_encounters() else {
			"accepted": false,
			"status": "INVALID_ENCOUNTER_ID",
			"message": "The selected battle node has no registered EncounterDefinition.",
		}
	return encounter_factory.validate(state, encounter_id, _encounter_kind_for_node(node))

func _has_registered_encounters() -> bool:
	for definition in content_registry.enumerate():
		if definition is EncounterDefinitionScript:
			return true
	return false

func _encounter_id_for_node(node_id: String) -> String:
	var node = map_definition.node_definition(node_id)
	if node == null:
		return ""
	var payload_id: String = state.map_state.payload_ids.get(node_id, "")
	if content_registry.resolve(payload_id) is EncounterDefinitionScript:
		return payload_id
	if content_registry.resolve(node.content_reference_id) is EncounterDefinitionScript:
		return node.content_reference_id
	return ""

func _event_id_for_node(node_id: String) -> String:
	var node = map_definition.node_definition(node_id)
	if node == null:
		return ""
	var payload_id: String = state.map_state.payload_ids.get(node_id, "")
	if content_registry.resolve(payload_id) is EventDefinitionScript:
		return payload_id
	if content_registry.resolve(node.content_reference_id) is EventDefinitionScript:
		return node.content_reference_id
	return ""

func _is_battle_node(node) -> bool:
	return node != null and node.node_kind in ["BATTLE", "ELITE", "BOSS"]

func _encounter_kind_for_node(node) -> String:
	if node == null:
		return ""
	if node.node_kind == "ELITE":
		return EncounterDefinitionScript.ELITE
	if node.node_kind == "BOSS":
		return EncounterDefinitionScript.BOSS
	return EncounterDefinitionScript.NORMAL

func _reward_phase_for_encounter(encounter_kind: String) -> String:
	if encounter_kind == EncounterDefinitionScript.ELITE:
		return RunPhaseScript.ELITE_REWARD
	if encounter_kind == EncounterDefinitionScript.BOSS:
		return RunPhaseScript.BOSS_REWARD
	return RunPhaseScript.REWARD_CHOICE

func _transition_to_act_two(previous_phase: String) -> Array:
	var events: Array = _clear_act_boundary_effects()
	state.act_index = 2
	_record_run_milestone("act_2_reached")
	map_definition = MiniActMapCatalogScript.act_two_definition()
	state.map_state.initialize(map_definition, rng_streams.map)
	state.current_battle_snapshot = null
	current_battle = null
	state.shop_state = ShopStateScript.new()
	state.workshop_state = WorkshopStateScript.new()
	state.event_state = EventStateScript.new()
	state.phase = RunPhaseScript.MAP_CHOICE
	events.append(DomainEventScript.new(DomainEventScript.ACT_TRANSITIONED, {
		"run_id": state.run_id,
		"from_act": 1,
		"to_act": state.act_index,
		"map_definition_id": map_definition.content_id,
	}))
	events.append(_run_phase_event(previous_phase, state.phase))
	return events

func _clear_act_boundary_effects() -> Array:
	var events: Array = []
	var effect_keys: Array = state.active_effects.keys()
	effect_keys.sort()
	for effect_key in effect_keys:
		var effect = state.active_effects.get(effect_key)
		if not effect is ActiveEffectInstanceScript or not [DurationSpecScript.BATTLE, DurationSpecScript.ACT].has(effect.duration_scope):
			continue
		state.active_effects.erase(effect_key)
		events.append(DomainEventScript.new(DomainEventScript.EFFECT_REMOVED, {
			"effect_id": effect.definition_id,
			"removed_effect_id": effect.instance_id,
			"reason": "act_transition",
		}))
	return events

func enter_run_summary(outcome: String, reason: String = "", summary_data: Dictionary = {}) -> Array:
	return run_summary_flow.enter(outcome, reason, summary_data)

func _record_run_summary_metrics(command_data: Dictionary, events: Array) -> void:
	run_summary_flow.record_metrics(command_data, events)

func validate_acknowledge_run_summary() -> RefCounted:
	return run_summary_flow.validate_acknowledge()

func execute_acknowledge_run_summary() -> Dictionary:
	return run_summary_flow.execute_acknowledge()

func checkpoint() -> Dictionary:
	var run_state_checkpoint: Dictionary = state.to_dictionary()
	# Wall-clock tracking is saved for the player summary but excluded from deterministic replay state.
	run_state_checkpoint.erase("run_started_at_unix_seconds")
	return {
		"schema_version": 1,
		"run_state": run_state_checkpoint,
		"rng_state": rng_snapshot(),
		"stable_boundary": _stable_checkpoint_boundary(),
		"state_hash": DeterministicSerializerScript.hash(run_state_checkpoint),
	}

func rng_snapshot() -> Dictionary:
	return rng_streams.snapshot() if rng_streams != null else {}

func _terminal_outcome() -> String:
	return str(state.terminal_summary.outcome) if state != null and state.terminal_summary != null else "ONGOING"

func _invalid_phase(expected_phase: String) -> RefCounted:
	return CommandValidationScript.new(
		false,
		"INVALID_PHASE",
		"The command is only legal during %s." % expected_phase,
		{"expected_phase": expected_phase, "actual_phase": state.phase},
	)

func _stable_checkpoint_boundary() -> String:
	match state.phase:
		RunPhaseScript.EVENT:
			return "EVENT_CHOICE_BEFORE" if state.event_state.active else "MAP_NODE"
		RunPhaseScript.SHOP:
			return "SHOP"
		RunPhaseScript.WORKSHOP:
			return "WORKSHOP"
		RunPhaseScript.BATTLE:
			return "BATTLE_START"
		RunPhaseScript.MAP_CHOICE:
			return "MAP_NODE"
		RunPhaseScript.REWARD_CHOICE, RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD:
			return "REWARD"
	return state.phase

func _run_phase_event(previous_phase: String, next_phase: String):
	return DomainEventScript.new(DomainEventScript.RUN_PHASE_CHANGED, {
		"run_id": state.run_id,
		"from_phase": previous_phase,
		"to_phase": next_phase,
	})
