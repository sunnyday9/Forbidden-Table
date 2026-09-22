class_name ActiveEffectInstance
extends RefCounted

const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")

var instance_id: String
var definition_id: String
var source_id: String
var duration_scope: String
var remaining: int
var stacks: int
var stack_policy: String
var max_stacks: int
var uses_remaining: int
var charges_remaining: int

func _init(
	identifier: String,
	duration = null,
	policy = StackPolicyScript.REPLACE,
	source: String = "",
	initial_stacks: int = 1,
	initial_uses: int = -1,
	initial_charges: int = -1,
	instance_identifier: String = "",
	stack_limit: int = 0,
) -> void:
	instance_id = instance_identifier if not instance_identifier.is_empty() else identifier
	definition_id = identifier
	source_id = source
	var duration_spec = duration if duration is DurationSpecScript else DurationSpecScript.new()
	duration_scope = duration_spec.scope
	remaining = duration_spec.amount if duration_spec.is_boundary_duration() else -1
	stacks = maxi(1, initial_stacks)
	stack_policy = policy.policy_id if policy is StackPolicyScript else str(policy)
	max_stacks = stack_limit if stack_limit > 0 else (policy.max_stacks if policy is StackPolicyScript else 0)
	if max_stacks > 0:
		stacks = mini(stacks, max_stacks)
	uses_remaining = initial_uses if initial_uses >= 0 else (duration_spec.amount if duration_spec.scope == DurationSpecScript.USES else -1)
	charges_remaining = initial_charges if initial_charges >= 0 else (duration_spec.amount if duration_spec.scope == DurationSpecScript.CHARGES else -1)

func is_active() -> bool:
	return remaining != 0 and uses_remaining != 0 and charges_remaining != 0

func refresh(duration) -> void:
	var duration_spec = duration if duration is DurationSpecScript else DurationSpecScript.new()
	duration_scope = duration_spec.scope
	remaining = duration_spec.amount if duration_spec.is_boundary_duration() else -1
	uses_remaining = -1
	charges_remaining = -1
	if duration_spec.scope == DurationSpecScript.USES:
		uses_remaining = duration_spec.amount
	elif duration_spec.scope == DurationSpecScript.CHARGES:
		charges_remaining = duration_spec.amount

func add_duration(duration) -> void:
	var duration_spec = duration if duration is DurationSpecScript else DurationSpecScript.new()
	if duration_spec.is_boundary_duration() and duration_scope == duration_spec.scope:
		remaining = maxi(0, remaining) + duration_spec.amount

func can_consume(uses: int, charges: int) -> bool:
	return uses >= 0 and charges >= 0 and (uses == 0 or (uses_remaining < 0 or uses_remaining >= uses)) and (charges == 0 or (charges_remaining < 0 or charges_remaining >= charges))

func consume(uses: int, charges: int) -> void:
	if uses > 0 and uses_remaining >= 0:
		uses_remaining -= uses
	if charges > 0 and charges_remaining >= 0:
		charges_remaining -= charges

func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"source_id": source_id,
		"duration": {"scope": duration_scope, "remaining": remaining},
		"stacks": stacks,
		"stack_policy": stack_policy,
		"max_stacks": max_stacks,
		"uses_remaining": uses_remaining,
		"charges_remaining": charges_remaining,
	}
