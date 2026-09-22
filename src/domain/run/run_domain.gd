class_name RunDomain
extends RefCounted

const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const BattleCommandScript = preload("res://src/domain/commands/battle_command.gd")
const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const CombatStateScript = preload("res://src/domain/combat/combat_state.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const DomainRngStreamsScript = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const EncounterFactoryScript = preload("res://src/domain/battle/encounter_factory.gd")
const MiniActMapCatalogScript = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const RewardOptionScript = preload("res://src/domain/run/reward_option.gd")
const RewardDraftSelectorScript = preload("res://src/domain/run/reward_draft_selector.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunBattleSnapshotScript = preload("res://src/domain/run/run_battle_snapshot.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")
const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")
const RunStateScript = preload("res://src/domain/run/run_state.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")

var state
var content_registry
var rng_streams
var map_definition
var encounter_factory
var reward_draft_selector
var economy
var current_battle

func _init(
	initial_run_id: String = "run.1",
	initial_seed: int = 13,
	domain_content_registry = null,
	initial_content_version: String = "",
	domain_rng_streams = null,
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
	current_battle = null
	state = RunStateScript.new(initial_run_id, initial_seed, resolved_content_version)

func execute(command) -> RefCounted:
	if command == null or not command.has_method("execute"):
		return CommandResultScript.new(
			"",
			"UnknownCommand",
			"",
			"",
			false,
			CommandResultScript.REJECTED,
			CommandValidationScript.new(false, "UNKNOWN_COMMAND", "Unsupported run command."),
		)
	if command is BattleCommandScript:
		return execute_battle(command)
	return command.execute(self)

func validate_choose_character(selected_character_id: String) -> RefCounted:
	if state.character_id == selected_character_id and not selected_character_id.is_empty():
		return CommandValidationScript.new(false, "DUPLICATE_CHOICE", "The Character has already been selected.")
	if state.phase != RunPhaseScript.CHARACTER_SELECT:
		return _invalid_phase(RunPhaseScript.CHARACTER_SELECT)
	var definition = content_registry.resolve(selected_character_id)
	if not definition is CharacterDefinitionScript:
		return CommandValidationScript.new(false, "INVALID_CHARACTER_ID", "The selected Character ID is not registered.")
	return CommandValidationScript.new(true)

func execute_choose_character(selected_character_id: String) -> Dictionary:
	var previous_phase: String = state.phase
	state.character_id = selected_character_id
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
	return CommandValidationScript.new(true)

func execute_choose_contract(selected_contract_id: String) -> Dictionary:
	var previous_phase: String = state.phase
	state.contract_id = selected_contract_id
	state.map_state.initialize(map_definition, rng_streams.map)
	state.phase = RunPhaseScript.MAP_CHOICE
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": [
			DomainEventScript.new(DomainEventScript.CONTRACT_SELECTED, {
				"run_id": state.run_id,
				"contract_id": selected_contract_id,
			}),
			_run_phase_event(previous_phase, state.phase),
		],
		"data": {"contract_id": selected_contract_id, "phase": state.phase},
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
		events.append(_run_phase_event(RunPhaseScript.MAP_CHOICE, state.phase))
		state.current_battle_snapshot = RunBattleSnapshotScript.new(battle.checkpoint())
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
		result.events + transfer_events,
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
	var events: Array = [DomainEventScript.new(DomainEventScript.BATTLE_OUTCOME_TRANSFERRED, {
		"run_id": state.run_id,
		"encounter_id": encounter_id_before,
		"encounter_kind": encounter_kind_before,
		"outcome": outcome,
	})]
	events.append_array(current_battle.end_battle())
	current_battle = null
	state.current_battle_snapshot = null
	if outcome == CombatStateScript.DEFEAT:
		events.append_array(enter_run_summary("DEFEAT", "BATTLE_DEFEAT", {"encounter_id": encounter_id_before}))
		state.map_state.last_events = events
		return events
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
		)
		events.append(DomainEventScript.new(DomainEventScript.REWARD_DRAFT_CREATED, {
			"run_id": state.run_id,
			"draft": state.reward_draft.to_dictionary(),
		}))
	events.append(_run_phase_event(previous_phase, state.phase))
	state.map_state.last_events = events
	return events

func validate_choose_reward(selected_draft_id: String, selected_option_id: String) -> RefCounted:
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
		if not content_registry.resolve(option.tile_id) is TileDefinitionScript:
			return {"accepted": false, "status": "INVALID_REWARD_CONTENT", "message": "The Add Tile content ID is not registered."}
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

func _reward_phase_for_encounter(encounter_kind: String) -> String:
	if encounter_kind == EncounterDefinitionScript.ELITE:
		return RunPhaseScript.ELITE_REWARD
	if encounter_kind == EncounterDefinitionScript.BOSS:
		return RunPhaseScript.BOSS_REWARD
	return RunPhaseScript.REWARD_CHOICE

func enter_run_summary(outcome: String, reason: String = "", summary_data: Dictionary = {}) -> Array:
	if state.phase == RunPhaseScript.RUN_SUMMARY or state.phase == RunPhaseScript.RUN_COMPLETE:
		return []
	if outcome.is_empty() or outcome == "ONGOING":
		return []
	var previous_phase: String = state.phase
	state.terminal_summary.outcome = outcome
	state.terminal_summary.reason = reason
	state.terminal_summary.summary_data = summary_data.duplicate(true)
	state.phase = RunPhaseScript.RUN_SUMMARY
	return [
		DomainEventScript.new(DomainEventScript.RUN_SUMMARY_REACHED, {
			"run_id": state.run_id,
			"outcome": outcome,
			"reason": reason,
			"summary_data": summary_data.duplicate(true),
		}),
		_run_phase_event(previous_phase, state.phase),
	]

func validate_acknowledge_run_summary() -> RefCounted:
	if state.phase != RunPhaseScript.RUN_SUMMARY:
		return _invalid_phase(RunPhaseScript.RUN_SUMMARY)
	return CommandValidationScript.new(true)

func execute_acknowledge_run_summary() -> Dictionary:
	var previous_phase: String = state.phase
	state.phase = RunPhaseScript.RUN_COMPLETE
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": [
			DomainEventScript.new(DomainEventScript.RUN_COMPLETED, {
				"run_id": state.run_id,
				"outcome": state.terminal_summary.outcome,
			}),
			_run_phase_event(previous_phase, state.phase),
		],
		"data": {"outcome": state.terminal_summary.outcome, "phase": state.phase},
	}

func checkpoint() -> Dictionary:
	var run_state_checkpoint: Dictionary = state.to_dictionary()
	return {
		"schema_version": 1,
		"run_state": run_state_checkpoint,
		"rng_state": rng_snapshot(),
		"state_hash": DeterministicSerializerScript.hash(run_state_checkpoint),
	}

func rng_snapshot() -> Dictionary:
	return rng_streams.snapshot() if rng_streams != null else {}

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
