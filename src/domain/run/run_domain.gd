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
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunBattleSnapshotScript = preload("res://src/domain/run/run_battle_snapshot.gd")
const RunStateScript = preload("res://src/domain/run/run_state.gd")

var state
var content_registry
var rng_streams
var map_definition
var encounter_factory
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
		return events
	var previous_phase: String = state.phase
	state.phase = _reward_phase_for_encounter(encounter_kind_before)
	events.append(_run_phase_event(previous_phase, state.phase))
	return events

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
