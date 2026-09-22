class_name RunDomain
extends RefCounted

const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const DomainRngStreamsScript = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunStateScript = preload("res://src/domain/run/run_state.gd")

var state
var content_registry
var rng_streams

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
