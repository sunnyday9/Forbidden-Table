class_name RemoveEffectOperation
extends "res://src/domain/effects/effect_operation.gd"

var removed_effect_id: String

func _init(identifier: String) -> void:
	super("RemoveEffect")
	removed_effect_id = identifier

func validate(context, _targets: Dictionary) -> String:
	if not _has_state(context):
		return "NO_STATE"
	if removed_effect_id.is_empty() or not context.state.active_effects.has(removed_effect_id):
		return "EFFECT_NOT_APPLIED"
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	context.state.active_effects.erase(removed_effect_id)
	return [_event("EffectRemoved", {"effect_id": effect_id, "removed_effect_id": removed_effect_id, "sequence_index": sequence_index})]

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "removed_effect_id": removed_effect_id}
