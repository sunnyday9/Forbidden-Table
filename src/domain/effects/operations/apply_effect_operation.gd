class_name ApplyEffectOperation
extends "res://src/domain/effects/effect_operation.gd"

const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")
const LifecycleResolverScript = preload("res://src/domain/effects/lifecycle_resolver.gd")

var applied_effect_id: String
var effect_definition
var duration_spec
var stack_policy
var source_id: String
var stacks: int
var uses: int
var charges: int
var max_stacks: int

func _init(
	identifier,
	effect_duration = null,
	effect_stack_policy = null,
	effect_source_id: String = "",
	effect_stacks: int = 1,
	effect_uses: int = -1,
	effect_charges: int = -1,
	effect_max_stacks: int = 0,
) -> void:
	super("ApplyEffect")
	effect_definition = identifier if not identifier is String else null
	applied_effect_id = identifier if identifier is String else str(identifier.get("effect_id"))
	duration_spec = effect_duration if effect_duration is DurationSpecScript else null
	stack_policy = effect_stack_policy
	source_id = effect_source_id
	stacks = effect_stacks
	uses = effect_uses
	charges = effect_charges
	max_stacks = effect_max_stacks

func validate(context, _targets: Dictionary) -> String:
	if not _has_state(context):
		return "NO_STATE"
	if applied_effect_id.is_empty():
		return "INVALID_EFFECT_ID"
	var resolver := LifecycleResolverScript.new()
	return resolver.can_apply(context.state, _identifier(), duration_spec, stack_policy)

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	var resolver := LifecycleResolverScript.new()
	return resolver.apply_effect(context.state, _identifier(), duration_spec, stack_policy, source_id, stacks, uses, charges, _max_stacks(), sequence_index)

func to_dictionary() -> Dictionary:
	var declared_duration = duration_spec
	if declared_duration == null and effect_definition != null:
		declared_duration = effect_definition.get("duration_spec")
	var declared_policy = stack_policy
	if declared_policy == null and effect_definition != null:
		declared_policy = effect_definition.get("stack_policy")
	var declared_max_stacks := _max_stacks()
	return {
		"operation_id": operation_id,
		"applied_effect_id": applied_effect_id,
		"duration": declared_duration.to_dictionary() if declared_duration != null else null,
		"stack_policy": declared_policy.policy_id if declared_policy is StackPolicyScript else declared_policy,
		"source_id": source_id,
		"stacks": stacks,
		"uses": uses,
		"charges": charges,
		"max_stacks": declared_max_stacks,
	}

func _identifier():
	return effect_definition if effect_definition != null else applied_effect_id

func _max_stacks() -> int:
	if max_stacks > 0:
		return max_stacks
	if effect_definition != null:
		return int(effect_definition.get("max_stacks"))
	return 0
