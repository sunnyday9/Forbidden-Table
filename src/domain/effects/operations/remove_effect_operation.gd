class_name RemoveEffectOperation
extends "res://src/domain/effects/effect_operation.gd"

const LifecycleResolverScript = preload("res://src/domain/effects/lifecycle_resolver.gd")

var removed_effect_id: String

func _init(identifier: String) -> void:
	super("RemoveEffect")
	removed_effect_id = identifier

func validate(context, _targets: Dictionary) -> String:
	if not _has_state(context):
		return "NO_STATE"
	if removed_effect_id.is_empty() or not LifecycleResolverScript.new().has_active(context.state, removed_effect_id):
		return "EFFECT_NOT_APPLIED"
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	return LifecycleResolverScript.new().remove_effect(context.state, removed_effect_id, sequence_index)

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "removed_effect_id": removed_effect_id}
