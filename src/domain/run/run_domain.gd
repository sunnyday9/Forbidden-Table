class_name RunDomain
extends RefCounted

const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const BattleCommandScript = preload("res://src/domain/commands/battle_command.gd")
const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const CharacterPassiveDefinitionScript = preload("res://src/content/definitions/character_passive_definition.gd")
const AlphaContractEffectsScript = preload("res://src/domain/run/alpha_contract_effects.gd")
const CombatStateScript = preload("res://src/domain/combat/combat_state.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const DomainRngStreamsScript = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifierScript = preload("res://src/infrastructure/replay/replay_verifier.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const EncounterFactoryScript = preload("res://src/domain/battle/encounter_factory.gd")
const ActiveEffectInstanceScript = preload("res://src/domain/effects/active_effect_instance.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const EventStateScript = preload("res://src/domain/run/event_state.gd")
const LifecycleResolverScript = preload("res://src/domain/effects/lifecycle_resolver.gd")
const MiniActMapCatalogScript = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const RewardDraftSelectorScript = preload("res://src/domain/run/reward_draft_selector.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunBattleSnapshotScript = preload("res://src/domain/run/run_battle_snapshot.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")
const RunModifierEffectResolverScript = preload("res://src/domain/run/run_modifier_effect_resolver.gd")
const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")
const RunTilePoolStateScript = preload("res://src/domain/run/run_tile_pool_state.gd")
const RunStateScript = preload("res://src/domain/run/run_state.gd")
const RunShopWorkshopFlowScript = preload("res://src/domain/run/run_shop_workshop_flow.gd")
const RunSummaryFlowScript = preload("res://src/domain/run/run_summary_flow.gd")
const RunEventFlowScript = preload("res://src/domain/run/run_event_flow.gd")
const RunTilePoolEditorScript = preload("res://src/domain/run/run_tile_pool_editor.gd")
const RunRewardFlowScript = preload("res://src/domain/run/run_reward_flow.gd")
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")
const RunStartingPoolFactoryScript = preload("res://src/domain/run/run_starting_pool_factory.gd")
const ShopOfferSelectorScript = preload("res://src/domain/run/shop_offer_selector.gd")
const ShopStateScript = preload("res://src/domain/run/shop_state.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
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
var run_event_flow
var tile_pool_editor
var reward_flow

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
	tile_pool_editor = RunTilePoolEditorScript.new(state)
	shop_workshop_flow = RunShopWorkshopFlowScript.new(state, content_registry, rng_streams, economy, shop_offer_selector, tile_pool_editor)
	run_summary_flow = RunSummaryFlowScript.new(state, content_registry)
	run_event_flow = RunEventFlowScript.new(state, content_registry, rng_streams, economy)
	reward_flow = RunRewardFlowScript.new(state, content_registry, rng_streams, economy, reward_draft_selector, tile_pool_editor)
	replay_record = ReplayRecordScript.new(initial_seed, resolved_content_version, initial_run_id)
	replay_record.record_initial_checkpoint(checkpoint(), rng_snapshot(), _terminal_outcome())

func rebind_state(restored_state) -> void:
	state = restored_state
	tile_pool_editor.bind_state(restored_state)
	shop_workshop_flow.bind_state(restored_state)
	run_summary_flow.bind_state(restored_state)
	run_event_flow.bind_state(restored_state)
	if reward_flow != null:
		reward_flow.bind_state(restored_state)

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
		events.append(RunEconomyScript.event_for_transaction(contract_reward_transactions[0]))
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
	return run_event_flow.validate_enter(selected_event_id, map_definition)

func execute_enter_event(selected_event_id: String = "") -> Dictionary:
	return run_event_flow.enter(selected_event_id, map_definition)

func validate_choose_event_option(selected_event_id: String, selected_entry_id: String, selected_option_id: String) -> RefCounted:
	return run_event_flow.validate_choose_option(selected_event_id, selected_entry_id, selected_option_id)

func execute_choose_event_option(selected_event_id: String, selected_entry_id: String, selected_option_id: String) -> Dictionary:
	var resolution_rng_state: Dictionary = rng_streams.snapshot()
	var resolution_state: Dictionary = _event_resolution_snapshot()
	var result: Dictionary = run_event_flow.choose_option(selected_event_id, selected_entry_id, selected_option_id, map_definition)
	if not result.get("accepted", false):
		_restore_event_resolution_snapshot(resolution_state)
		rng_streams.restore(resolution_rng_state)
	return result

func advance_run_boundary(boundary: String) -> Array:
	return LifecycleResolverScript.new().advance(state, boundary)

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

func _workshop_price(service_key: String) -> int:
	return shop_workshop_flow.workshop_price(service_key)

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
			events.append(RunEconomyScript.event_for_transaction(tax_transaction))
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
			events.append(RunEconomyScript.event_for_transaction(risk_bargain_transaction))
	var previous_phase: String = state.phase
	events.append_array(reward_flow.create_draft(encounter_kind_before, encounter_id_before, previous_phase))
	state.map_state.last_events = events
	return events

func validate_choose_reward(selected_draft_id: String, selected_option_id: String) -> RefCounted:
	return reward_flow.validate_choice(selected_draft_id, selected_option_id)

func execute_choose_reward(selected_draft_id: String, selected_option_id: String) -> Dictionary:
	var resolving_boss_reward: bool = state.phase == RunPhaseScript.BOSS_REWARD
	var result: Dictionary = reward_flow.execute_choice(selected_draft_id, selected_option_id)
	if not result.get("accepted", false) or not resolving_boss_reward:
		return result
	var reward_data: Dictionary = result.get("data", {}).duplicate(true)
	var previous_phase := str(reward_data.get("reward_phase", state.phase))
	var events: Array = result.get("events", []).duplicate()
	if state.act_index < state.act_count:
		events.append_array(_transition_to_act_two(previous_phase))
	else:
		events.append_array(enter_run_summary("VICTORY", "BOSS_DEFEATED", {
			"act_index": state.act_index,
			"reward_option_id": reward_data.get("option_id", ""),
			"rule_breaker_id": reward_data.get("content_id", ""),
		}))
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": result.get("status", CommandResultScript.ACCEPTED),
		"events": events,
		"data": reward_data.merged({"phase": state.phase}),
	}

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
