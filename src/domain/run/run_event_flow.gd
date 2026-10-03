class_name RunEventFlow
extends RefCounted

const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const EffectContextScript = preload("res://src/domain/effects/effect_context.gd")
const EffectScript = preload("res://src/domain/effects/effect.gd")
const ApplyRunModifierOperationScript = preload("res://src/domain/effects/operations/apply_run_modifier_operation.gd")
const ActiveEffectInstanceScript = preload("res://src/domain/effects/active_effect_instance.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const EventDefinitionScript = preload("res://src/content/definitions/event_definition.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")
const RunMapStateScript = preload("res://src/domain/run/run_map_state.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")

var state
var content_registry
var rng_streams
var economy

func _init(initial_state, initial_content_registry, initial_rng_streams, initial_economy) -> void:
	state = initial_state
	content_registry = initial_content_registry
	rng_streams = initial_rng_streams
	economy = initial_economy

func bind_state(authoritative_state) -> void:
	state = authoritative_state

func validate_enter(selected_event_id: String, current_map_definition) -> RefCounted:
	if state.phase != RunPhaseScript.MAP_CHOICE:
		return _invalid_phase(RunPhaseScript.MAP_CHOICE)
	var node_id: String = state.map_state.current_node_id
	var node = current_map_definition.node_definition(node_id)
	if node == null or node.node_kind != "EVENT":
		return CommandValidationScript.new(false, "INVALID_EVENT_NODE", "Event entry requires the current Map Node to be an Event.")
	if state.event_state.active:
		return CommandValidationScript.new(false, "EVENT_ALREADY_ACTIVE", "An Event is already active.")
	if state.event_state.has_completed_node(node_id):
		return CommandValidationScript.new(false, "EVENT_COMPLETED", "This Event node has already been completed.")
	var authored_event_id := _event_id_for_node(node_id, current_map_definition)
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

func enter(selected_event_id: String, current_map_definition) -> Dictionary:
	var node_id: String = state.map_state.current_node_id
	var event_id := selected_event_id if not selected_event_id.is_empty() else _event_id_for_node(node_id, current_map_definition)
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

func validate_choose_option(selected_event_id: String, selected_entry_id: String, selected_option_id: String) -> RefCounted:
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

func choose_option(selected_event_id: String, selected_entry_id: String, selected_option_id: String, current_map_definition) -> Dictionary:
	var choice = state.event_state.choice_by_id(selected_option_id)
	if choice == null:
		return {"accepted": false, "status": "INVALID_EVENT_OPTION", "message": "The selected Event option ID is not legal for the active Event."}
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
	var effects_result := _resolve_event_effects(effects, current_map_definition)
	if not effects_result.get("accepted", false):
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

func _resolve_event_effects(effects: Array, current_map_definition) -> Dictionary:
	var events: Array = []
	var sequence_index := 0
	for effect in effects:
		if effect is EffectScript:
			var result = effect.resolve_in_context(EffectContextScript.new(state), sequence_index)
			if result == null or not result.is_resolved():
				return {"accepted": false, "status": "EVENT_EFFECT_REJECTED", "message": "An Event Effect was rejected during resolution."}
			events.append_array(result.events)
		elif effect is Dictionary:
			var dictionary_result := _resolve_declarative_event_effect(effect, sequence_index, current_map_definition)
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
		var modifier_operation := ApplyRunModifierOperationScript.new(
			modifier_id,
			int(effect.get("value", 1)),
			DurationSpecScript.new(scope, duration_amount),
			stack_policy,
			str(effect.get("source_id", state.contract_id)),
			effect.get("parameters", {}) if effect.get("parameters", {}) is Dictionary else {},
		)
		var applicability_reason: String = modifier_operation.validate(EffectContextScript.new(state), {})
		if not applicability_reason.is_empty():
			return {
				"accepted": false,
				"status": applicability_reason,
				"message": "The Event run modifier cannot be applied in the current Run state.",
				"details": {"reason": applicability_reason, "modifier_id": modifier_id},
			}
		return {"accepted": true}
	if kind == "MAP_REVEAL":
		if not effect.get("node_ids", []) is Array:
			return {"accepted": false, "status": "INVALID_MAP_REVEAL", "message": "Map reveal effects require stable node IDs."}
		return {"accepted": true}
	return {"accepted": false, "status": "INVALID_EVENT_EFFECT", "message": "The Event declarative Effect kind is unsupported."}

func _resolve_declarative_event_effect(effect: Dictionary, sequence_index: int, current_map_definition) -> Dictionary:
	var kind := str(effect.get("kind", effect.get("type", effect.get("effect_type", ""))))
	if kind in ["GOLD", "GOLD_DELTA", "REFINEMENT_TOKENS", "REFINEMENT_TOKENS_DELTA"]:
		var currency := RunEconomyScript.GOLD if kind.begins_with("GOLD") else RunEconomyScript.REFINEMENT_TOKENS
		var amount := int(effect.get("amount", effect.get("delta", 0)))
		var transaction: Dictionary = economy.apply_source(state, currency, amount, RunEconomyScript.SOURCE_HIGH_RISK_CONTENT) if amount >= 0 else economy.apply_sink(state, currency, -amount, RunEconomyScript.SINK_EVENT_TRADE)
		if transaction.is_empty():
			return {"accepted": false, "status": "EVENT_EFFECT_REJECTED", "message": "The Event currency effect was rejected."}
		transaction["sequence_index"] = sequence_index
		return {"accepted": true, "events": [RunEconomyScript.event_for_transaction(transaction)]}
	if kind == "MAP_REVEAL":
		var revealed: Array[String] = []
		for node_id in effect.get("node_ids", []):
			var node_id_text := str(node_id)
			if current_map_definition.node_ids.has(node_id_text):
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

func _event_id_for_node(node_id: String, current_map_definition) -> String:
	var node = current_map_definition.node_definition(node_id)
	if node == null:
		return ""
	var payload_id: String = state.map_state.payload_ids.get(node_id, "")
	if content_registry.resolve(payload_id) is EventDefinitionScript:
		return payload_id
	if content_registry.resolve(node.content_reference_id) is EventDefinitionScript:
		return node.content_reference_id
	return ""

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
