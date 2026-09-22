class_name Effect
extends "res://src/domain/combat/combat_resolution_effect.gd"

const EffectContextScript = preload("res://src/domain/effects/effect_context.gd")
const EffectTriggerScript = preload("res://src/domain/effects/effect_trigger.gd")
const EffectTargetScript = preload("res://src/domain/effects/effect_target.gd")
const EffectConditionScript = preload("res://src/domain/effects/effect_condition.gd")
const EffectOperationScript = preload("res://src/domain/effects/effect_operation.gd")
const EffectResolutionResultScript = preload("res://src/domain/effects/effect_resolution_result.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")

var trigger
var conditions: Array
var targets: Array
var operations: Array

func _init(
	effect_identifier: String,
	effect_trigger = null,
	effect_conditions: Array = [],
	effect_targets: Array = [],
	effect_operations: Array = [],
) -> void:
	super(effect_identifier)
	effect_id = effect_identifier
	trigger = effect_trigger if effect_trigger is EffectTriggerScript else EffectTriggerScript.new(str(effect_trigger) if effect_trigger != null else EffectTriggerScript.MANUAL)
	conditions = effect_conditions.duplicate()
	targets = effect_targets.duplicate()
	operations = effect_operations.duplicate()

func resolve(queue, state, sequence_index: int):
	var context = queue.effect_context() if queue != null and queue.has_method("effect_context") else EffectContextScript.new(state)
	return resolve_in_context(context, sequence_index)

func resolve_in_context(context, sequence_index: int):
	var resolved_targets: Dictionary = {}
	for target in targets:
		if not target is EffectTargetScript:
			return _rejected(EffectResolutionResultScript.REJECTED_TARGET, "INVALID_TARGET_DECLARATION", sequence_index)
		var resolved: Dictionary = target.resolve(context)
		if not bool(resolved.get("valid", false)):
			return _rejected(EffectResolutionResultScript.REJECTED_TARGET, str(resolved.get("reason", "INVALID_TARGET")), sequence_index)
		resolved_targets[target.key] = resolved

	for condition in conditions:
		if not condition is EffectConditionScript or not condition.evaluate(context, resolved_targets):
			var condition_reason: String = condition.failure_reason() if condition is EffectConditionScript else "INVALID_CONDITION_DECLARATION"
			return _rejected(EffectResolutionResultScript.REJECTED_CONDITION, condition_reason, sequence_index)

	for operation in operations:
		if not operation is EffectOperationScript:
			return _rejected(EffectResolutionResultScript.REJECTED_OPERATION, "INVALID_OPERATION_DECLARATION", sequence_index)
		var validation_reason: String = operation.validate(context, resolved_targets)
		if not validation_reason.is_empty():
			return _rejected(EffectResolutionResultScript.REJECTED_OPERATION, validation_reason, sequence_index)

	var events: Array = []
	for operation in operations:
		events.append_array(operation.apply(context, resolved_targets, sequence_index, effect_id))
	return EffectResolutionResultScript.new(EffectResolutionResultScript.RESOLVED, effect_id, trigger.trigger_id, "", events)

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
		"resolution_kind": "DECLARATIVE_EFFECT",
	}
