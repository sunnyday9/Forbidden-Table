class_name Effect
extends "res://src/domain/combat/combat_resolution_effect.gd"

const EffectContextScript = preload("res://src/domain/effects/effect_context.gd")
const EffectTriggerScript = preload("res://src/domain/effects/effect_trigger.gd")
const EffectTargetScript = preload("res://src/domain/effects/effect_target.gd")
const EffectConditionScript = preload("res://src/domain/effects/effect_condition.gd")
const EffectOperationScript = preload("res://src/domain/effects/effect_operation.gd")
const EffectResolutionResultScript = preload("res://src/domain/effects/effect_resolution_result.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")

var trigger
var conditions: Array
var targets: Array
var operations: Array
var duration_spec
var stack_policy: String
var max_stacks: int

func _init(
	effect_identifier: String,
	effect_trigger = null,
	effect_conditions: Array = [],
	effect_targets: Array = [],
	effect_operations: Array = [],
	effect_duration = null,
	effect_stack_policy = StackPolicyScript.REPLACE,
	effect_source_id: String = "",
	effect_max_stacks: int = 0,
) -> void:
	super(effect_identifier)
	effect_id = effect_identifier
	trigger = effect_trigger if effect_trigger is EffectTriggerScript else EffectTriggerScript.new(str(effect_trigger) if effect_trigger != null else EffectTriggerScript.MANUAL)
	conditions = effect_conditions.duplicate()
	targets = effect_targets.duplicate()
	operations = effect_operations.duplicate()
	duration_spec = effect_duration if effect_duration is DurationSpecScript else DurationSpecScript.new()
	stack_policy = effect_stack_policy.policy_id if effect_stack_policy is StackPolicyScript else str(effect_stack_policy)
	max_stacks = effect_max_stacks if effect_max_stacks > 0 else (effect_stack_policy.max_stacks if effect_stack_policy is StackPolicyScript else 0)
	source_id = effect_source_id if not effect_source_id.is_empty() else effect_identifier

func resolve(queue, state, sequence_index: int):
	var context = queue.effect_context() if queue != null and queue.has_method("effect_context") else EffectContextScript.new(state)
	return resolve_in_context(context, sequence_index)

func resolve_in_context(context, sequence_index: int):
	var validation := validate_in_context(context)
	if not bool(validation.get("valid", false)):
		return _rejected(
			str(validation.get("status", EffectResolutionResultScript.REJECTED_OPERATION)),
			str(validation.get("reason", "EFFECT_VALIDATION_FAILED")),
			sequence_index,
		)
	var resolved_targets: Dictionary = validation.get("resolved_targets", {})
	var events: Array = []
	for operation in operations:
		events.append_array(operation.apply(context, resolved_targets, sequence_index, effect_id))
	return EffectResolutionResultScript.new(EffectResolutionResultScript.RESOLVED, effect_id, trigger.trigger_id, "", events)

func validate_in_context(context) -> Dictionary:
	var resolved_targets: Dictionary = {}
	for target in targets:
		if not target is EffectTargetScript:
			return {"valid": false, "status": EffectResolutionResultScript.REJECTED_TARGET, "reason": "INVALID_TARGET_DECLARATION"}
		var resolved: Dictionary = target.resolve(context)
		if not bool(resolved.get("valid", false)):
			return {"valid": false, "status": EffectResolutionResultScript.REJECTED_TARGET, "reason": str(resolved.get("reason", "INVALID_TARGET"))}
		resolved_targets[target.key] = resolved

	for condition in conditions:
		if not condition is EffectConditionScript or not condition.evaluate(context, resolved_targets):
			var condition_reason: String = condition.failure_reason() if condition is EffectConditionScript else "INVALID_CONDITION_DECLARATION"
			return {"valid": false, "status": EffectResolutionResultScript.REJECTED_CONDITION, "reason": condition_reason}

	for operation in operations:
		if not operation is EffectOperationScript:
			return {"valid": false, "status": EffectResolutionResultScript.REJECTED_OPERATION, "reason": "INVALID_OPERATION_DECLARATION"}
		var validation_reason: String = operation.validate(context, resolved_targets)
		if not validation_reason.is_empty():
			return {"valid": false, "status": EffectResolutionResultScript.REJECTED_OPERATION, "reason": validation_reason}

	return {"valid": true, "resolved_targets": resolved_targets}

func _rejected(status: String, reason: String, sequence_index: int):
	return EffectResolutionResultScript.new(
		status,
		effect_id,
		trigger.trigger_id,
		reason,
		[DomainEventScript.new(DomainEventScript.EFFECT_REJECTED, {
			"effect_id": effect_id,
			"trigger_id": trigger.trigger_id,
			"status": status,
			"reason": reason,
			"sequence_index": sequence_index,
		})],
	)

func to_dictionary() -> Dictionary:
	var condition_data: Array = []
	for condition in conditions:
		condition_data.append(condition.to_dictionary())
	var target_data: Array = []
	for target in targets:
		target_data.append(target.to_dictionary())
	var operation_data: Array = []
	for operation in operations:
		operation_data.append(operation.to_dictionary())
	return {
		"effect_id": effect_id,
		"trigger": trigger.to_dictionary(),
		"conditions": condition_data,
		"targets": target_data,
		"operations": operation_data,
		"duration": duration_spec.to_dictionary(),
		"stack_policy": stack_policy,
		"max_stacks": max_stacks,
		"source_id": source_id,
		"resolution_kind": "DECLARATIVE_EFFECT",
	}
