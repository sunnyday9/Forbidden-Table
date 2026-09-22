class_name ApplyEffectOperation
extends "res://src/domain/effects/effect_operation.gd"

var applied_effect_id: String

func _init(identifier: String) -> void:
	super("ApplyEffect")
	applied_effect_id = identifier

func validate(context, _targets: Dictionary) -> String:
	if not _has_state(context):
		return "NO_STATE"
	return "INVALID_EFFECT_ID" if applied_effect_id.is_empty() else ""

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	context.state.active_effects[applied_effect_id] = true
	return [_event("EffectApplied", {"effect_id": effect_id, "applied_effect_id": applied_effect_id, "sequence_index": sequence_index})]

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "applied_effect_id": applied_effect_id}
