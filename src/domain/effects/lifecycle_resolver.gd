class_name LifecycleResolver
extends RefCounted

const ActiveEffectInstanceScript = preload("res://src/domain/effects/active_effect_instance.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")

const NO_BOUNDARY := ""
const ACTION := DurationSpecScript.ACTION
const WINDOW := DurationSpecScript.WINDOW
const SETTLEMENT_WINDOW := DurationSpecScript.SETTLEMENT_WINDOW
const TURN := DurationSpecScript.TURN
const BATTLE := DurationSpecScript.BATTLE
const BOSS_PHASE := DurationSpecScript.BOSS_PHASE
const ACT := DurationSpecScript.ACT
const RUN := DurationSpecScript.RUN

var _state

func _init(effect_state = null) -> void:
	_state = effect_state

func can_apply(state, effect_or_id, duration = null, policy = null) -> String:
	if state == null:
		return "NO_STATE"
	var identifier := _identifier(effect_or_id)
	if identifier.is_empty():
		return "INVALID_EFFECT_ID"
	var stack_policy = _policy(effect_or_id, policy)
	if stack_policy == StackPolicyScript.UNIQUE and not _effect_keys(state, identifier).is_empty():
		return "EFFECT_ALREADY_ACTIVE"
	return ""

func apply_effect(
	state,
	effect_or_id,
	duration = null,
	policy = null,
	source_id: String = "",
	stacks: int = 1,
	uses: int = -1,
	charges: int = -1,
	max_stacks: int = 0,
	sequence_index: int = -1,
) -> Array:
	var identifier := _identifier(effect_or_id)
	var duration_spec = _duration(effect_or_id, duration)
	var stack_policy = _policy(effect_or_id, policy)
	if max_stacks <= 0 and effect_or_id != null and not effect_or_id is String:
		max_stacks = int(effect_or_id.get("max_stacks"))
	if source_id.is_empty() and effect_or_id != null and not effect_or_id is String:
		source_id = str(effect_or_id.get("source_id"))
	if state == null or identifier.is_empty():
		return [_rejected_event(identifier, "INVALID_EFFECT_ID", sequence_index)]
	var existing_keys: Array = _effect_keys(state, identifier)
	if stack_policy == StackPolicyScript.UNIQUE and not existing_keys.is_empty():
		return [_rejected_event(identifier, "EFFECT_ALREADY_ACTIVE", sequence_index)]

	var events: Array = []
	if stack_policy == StackPolicyScript.REPLACE:
		for key in existing_keys:
			state.active_effects.erase(key)
			events.append(_event(DomainEventScript.EFFECT_REMOVED, {
				"effect_id": identifier,
				"removed_effect_id": key,
				"reason": "replaced",
				"sequence_index": sequence_index,
			}))
		existing_keys.clear()

	if stack_policy == StackPolicyScript.REFRESH_DURATION and not existing_keys.is_empty():
		var refreshed: ActiveEffectInstanceScript = state.active_effects[existing_keys[0]]
		refreshed.refresh(duration_spec)
		if not refreshed.is_active():
			state.active_effects.erase(refreshed.instance_id)
			events.append(_event(DomainEventScript.EFFECT_EXPIRED, {
				"effect_id": refreshed.definition_id,
				"instance_id": refreshed.instance_id,
				"reason": "zero_duration_or_charges",
				"sequence_index": sequence_index,
			}))
			return events
		events.append(_event(DomainEventScript.EFFECT_REFRESHED, _effect_data(refreshed, sequence_index)))
		return events

	if stack_policy == StackPolicyScript.ADD_DURATION and not existing_keys.is_empty():
		var extended: ActiveEffectInstanceScript = state.active_effects[existing_keys[0]]
		extended.add_duration(duration_spec)
		events.append(_event(DomainEventScript.EFFECT_REFRESHED, _effect_data(extended, sequence_index)))
		return events

	if stack_policy == StackPolicyScript.ADD_STACKS and not existing_keys.is_empty():
		var stacked: ActiveEffectInstanceScript = state.active_effects[existing_keys[0]]
		var previous_stacks := stacked.stacks
		var limit := max_stacks if max_stacks > 0 else stacked.max_stacks
		stacked.stacks = previous_stacks + maxi(1, stacks)
		if limit > 0:
			stacked.stacks = mini(stacked.stacks, limit)
		events.append(_event(DomainEventScript.EFFECT_STACKED, {
			"effect_id": identifier,
			"instance_id": stacked.instance_id,
			"previous_stacks": previous_stacks,
			"stacks": stacked.stacks,
			"limited": limit > 0 and stacked.stacks == limit,
			"sequence_index": sequence_index,
		}))
		return events

	var instance_id := identifier
	if stack_policy == StackPolicyScript.INDEPENDENT_INSTANCES:
		instance_id = _next_instance_id(state, identifier)
	var instance := ActiveEffectInstanceScript.new(identifier, duration_spec, stack_policy, source_id, stacks, uses, charges, instance_id, max_stacks)
	if not instance.is_active():
		events.append(_event(DomainEventScript.EFFECT_EXPIRED, {
			"effect_id": instance.definition_id,
			"instance_id": instance.instance_id,
			"reason": "zero_duration_or_charges",
			"sequence_index": sequence_index,
		}))
		return events
	state.active_effects[instance_id] = instance
	events.append(_event(DomainEventScript.EFFECT_APPLIED, _effect_data(instance, sequence_index)))
	return events

func apply(
	effect_or_id,
	duration = null,
	policy = null,
	source_id: String = "",
	stacks: int = 1,
	uses: int = -1,
	charges: int = -1,
	max_stacks: int = 0,
	sequence_index: int = -1,
) -> Array:
	return apply_effect(_state, effect_or_id, duration, policy, source_id, stacks, uses, charges, max_stacks, sequence_index)

func remove_effect(state, identifier: String, sequence_index: int = -1) -> Array:
	var events: Array = []
	for key in _effect_keys(state, identifier):
		state.active_effects.erase(key)
		events.append(_event(DomainEventScript.EFFECT_REMOVED, {
			"effect_id": identifier,
			"removed_effect_id": key,
			"reason": "removed",
			"sequence_index": sequence_index,
		}))
	return events

func consume_effect(state, identifier: String, uses: int = 0, charges: int = 0, sequence_index: int = -1) -> Array:
	var keys := _effect_keys(state, identifier)
	if keys.is_empty() or uses < 0 or charges < 0:
		return [_rejected_event(identifier, "EFFECT_NOT_ACTIVE", sequence_index)]
	var instance: ActiveEffectInstanceScript = state.active_effects[keys[0]]
	if not instance.can_consume(uses, charges):
		return [_rejected_event(identifier, "INSUFFICIENT_USES_OR_CHARGES", sequence_index)]
	instance.consume(uses, charges)
	var events: Array = [_event(DomainEventScript.EFFECT_CONSUMED, {
			"effect_id": identifier,
			"instance_id": instance.instance_id,
			"uses": uses,
			"charges": charges,
			"uses_remaining": instance.uses_remaining,
			"charges_remaining": instance.charges_remaining,
			"sequence_index": sequence_index,
		})]
	if not instance.is_active():
		state.active_effects.erase(instance.instance_id)
		events.append(_event(DomainEventScript.EFFECT_EXPIRED, {
			"effect_id": instance.definition_id,
			"instance_id": instance.instance_id,
			"reason": "consumed",
			"sequence_index": sequence_index,
		}))
	return events

func consume_uses(state, identifier: String, amount: int = 1, sequence_index: int = -1) -> Array:
	return consume_effect(state, identifier, amount, 0, sequence_index)

func consume_charges(state, identifier: String, amount: int = 1, sequence_index: int = -1) -> Array:
	return consume_effect(state, identifier, 0, amount, sequence_index)

func consume(identifier: String, uses: int = 0, charges: int = 0, sequence_index: int = -1) -> Array:
	return consume_effect(_state, identifier, uses, charges, sequence_index)

func advance(state_or_boundary, boundary: String = "", sequence_index: int = -1) -> Array:
	var state = state_or_boundary
	var target_boundary := boundary
	if state_or_boundary is String:
		state = _state
		target_boundary = state_or_boundary
	if state == null or target_boundary.is_empty():
		return []
	var events: Array = []
	for key in _sorted_keys(state.active_effects):
		if not state.active_effects.has(key):
			continue
		var instance = state.active_effects[key]
		if not instance is ActiveEffectInstanceScript or not _matches_boundary(instance.duration_scope, target_boundary) or instance.remaining < 0:
			continue
		var previous_remaining: int = instance.remaining
		instance.remaining = maxi(0, instance.remaining - 1)
		if instance.remaining == 0:
			state.active_effects.erase(key)
			events.append(_event(DomainEventScript.EFFECT_EXPIRED, {
				"effect_id": instance.definition_id,
				"instance_id": instance.instance_id,
				"boundary": target_boundary,
				"previous_remaining": previous_remaining,
				"sequence_index": sequence_index,
			}))
		else:
			events.append(_event(DomainEventScript.EFFECT_DURATION_DECREMENTED, {
				"effect_id": instance.definition_id,
				"instance_id": instance.instance_id,
				"boundary": target_boundary,
				"previous_remaining": previous_remaining,
				"remaining": instance.remaining,
				"sequence_index": sequence_index,
			}))
	return events

func advance_boundary(boundary: String, sequence_index: int = -1) -> Array:
	return advance(_state, boundary, sequence_index)

func has_active(state, identifier: String) -> bool:
	return not _effect_keys(state, identifier).is_empty()

func has_boundary_effect(state, boundary: String) -> bool:
	if state == null:
		return false
	for key in _sorted_keys(state.active_effects):
		var instance = state.active_effects[key]
		if instance is ActiveEffectInstanceScript and _matches_boundary(instance.duration_scope, boundary) and instance.remaining >= 0:
			return true
	return false

func active_effect(state, identifier: String):
	var keys := _effect_keys(state, identifier)
	return state.active_effects[keys[0]] if not keys.is_empty() else null

func _identifier(effect_or_id) -> String:
	if effect_or_id is String:
		return effect_or_id
	return str(effect_or_id.get("effect_id")) if effect_or_id != null else ""

func _duration(effect_or_id, override_duration):
	if override_duration is DurationSpecScript:
		return override_duration
	if effect_or_id != null and not effect_or_id is String:
		var declared = effect_or_id.get("duration_spec")
		if declared is DurationSpecScript:
			return declared
	return DurationSpecScript.new()

func _policy(effect_or_id, override_policy):
	if override_policy is StackPolicyScript:
		return override_policy.policy_id
	if override_policy is String and not override_policy.is_empty():
		return override_policy
	if effect_or_id != null and not effect_or_id is String:
		var declared = effect_or_id.get("stack_policy")
		if declared is StackPolicyScript:
			return declared.policy_id
		if declared is String and not declared.is_empty():
			return declared
	return StackPolicyScript.REPLACE

func _effect_keys(state, identifier: String) -> Array:
	if state == null or not state.active_effects is Dictionary:
		return []
	var result: Array = []
	for key in state.active_effects.keys():
		var key_text := str(key)
		if key_text == identifier or key_text.begins_with(identifier + "#"):
			result.append(key_text)
	result.sort()
	return result

func _sorted_keys(dictionary: Dictionary) -> Array:
	var keys: Array = dictionary.keys()
	keys.sort()
	return keys

func _next_instance_id(state, identifier: String) -> String:
	var index := 1
	while state.active_effects.has("%s#%d" % [identifier, index]):
		index += 1
	return "%s#%d" % [identifier, index]

func _matches_boundary(scope: String, boundary: String) -> bool:
	return (
		scope == boundary
		or (scope == DurationSpecScript.SETTLEMENT_WINDOW and boundary == DurationSpecScript.WINDOW)
		or (scope == DurationSpecScript.WINDOW and boundary == DurationSpecScript.SETTLEMENT_WINDOW)
	)

func _effect_data(instance: ActiveEffectInstanceScript, sequence_index: int) -> Dictionary:
	var data := instance.to_dictionary()
	data["sequence_index"] = sequence_index
	return data

func _event(event_type: String, data: Dictionary):
	return DomainEventScript.new(event_type, data)

func _rejected_event(identifier: String, reason: String, sequence_index: int):
	return _event(DomainEventScript.EFFECT_REJECTED, {
		"effect_id": identifier,
		"status": "REJECTED_LIFECYCLE",
		"reason": reason,
		"sequence_index": sequence_index,
	})
