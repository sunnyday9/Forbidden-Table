class_name ApplyRunModifierOperation
extends "res://src/domain/effects/effect_operation.gd"

const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const LifecycleResolverScript = preload("res://src/domain/effects/lifecycle_resolver.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")

var modifier_id: String
var modifier_value: int
var duration_spec
var stack_policy: String
var source_id: String
var parameters: Dictionary

func _init(
	modifier_identifier: String,
	value: int = 1,
	modifier_duration = null,
	modifier_stack_policy = StackPolicyScript.REPLACE,
	modifier_source_id: String = "",
	modifier_parameters: Dictionary = {},
) -> void:
	super("ApplyRunModifier")
	modifier_id = modifier_identifier
	modifier_value = value
	duration_spec = modifier_duration if modifier_duration is DurationSpecScript else DurationSpecScript.new(DurationSpecScript.RUN, 1)
	stack_policy = modifier_stack_policy.policy_id if modifier_stack_policy is StackPolicyScript else str(modifier_stack_policy)
	source_id = modifier_source_id
	parameters = modifier_parameters.duplicate(true)

func validate(context, _targets: Dictionary) -> String:
	var run_state = _run_state(context)
	if run_state == null:
		return "NO_STATE"
	if not run_state.has_method("active_modifier") or not run_state.active_effects is Dictionary:
		return "RUN_STATE_REQUIRED"
	if modifier_id.is_empty():
		return "INVALID_MODIFIER_ID"
	if duration_spec == null or duration_spec.scope == DurationSpecScript.PERMANENT or not duration_spec.is_boundary_duration() or duration_spec.amount <= 0:
		return "INVALID_MODIFIER_SCOPE"
	if not [
		StackPolicyScript.REPLACE,
		StackPolicyScript.REFRESH_DURATION,
		StackPolicyScript.ADD_STACKS,
		StackPolicyScript.ADD_DURATION,
		StackPolicyScript.INDEPENDENT_INSTANCES,
		StackPolicyScript.UNIQUE,
	].has(stack_policy):
		return "INVALID_MODIFIER_STACK_POLICY"
	return LifecycleResolverScript.new().can_apply(run_state, _effect_id(), duration_spec, stack_policy)

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	var run_state = _run_state(context)
	if run_state == null:
		return [_event(DomainEventScript.EFFECT_REJECTED, {
			"effect_id": effect_id,
			"operation_id": operation_id,
			"reason": "NO_RUN_STATE",
			"sequence_index": sequence_index,
		})]
	var lifecycle := LifecycleResolverScript.new()
	var resolved_source_id := source_id
	if resolved_source_id.is_empty():
		resolved_source_id = str(run_state.get("contract_id"))
	var events := lifecycle.apply_effect(
		run_state,
		_effect_id(),
		duration_spec,
		stack_policy,
		resolved_source_id,
		1,
		-1,
		-1,
		0,
		sequence_index,
	)
	var instance = lifecycle.active_effect(run_state, _effect_id())
	if instance != null:
		instance.runtime_parameters = parameters.duplicate(true)
		instance.runtime_parameters["modifier_id"] = modifier_id
		instance.runtime_parameters["value"] = modifier_value
		instance.runtime_parameters["scope"] = duration_spec.scope
		events.append(DomainEventScript.new(DomainEventScript.RUN_MODIFIER_CHANGED, {
			"effect_id": effect_id,
			"modifier_id": modifier_id,
			"instance_id": instance.instance_id,
			"source_id": resolved_source_id,
			"value": modifier_value,
			"scope": duration_spec.scope,
			"sequence_index": sequence_index,
		}))
	return events

func to_dictionary() -> Dictionary:
	return {
		"operation_id": operation_id,
		"modifier_id": modifier_id,
		"value": modifier_value,
		"duration": duration_spec.to_dictionary(),
		"stack_policy": stack_policy,
		"source_id": source_id,
		"parameters": parameters.duplicate(true),
	}

func _effect_id() -> String:
	return "run.modifier.%s" % modifier_id

func _run_state(context):
	if context == null:
		return null
	return context.run_state if context.get("run_state") != null else context.state
