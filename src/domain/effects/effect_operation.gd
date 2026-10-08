class_name EffectOperation
extends RefCounted

var operation_id: String

func _init(identifier: String = "operation") -> void:
	operation_id = identifier

func validate(_context, _targets: Dictionary) -> String:
	return ""

func apply(_context, _targets: Dictionary, _sequence_index: int, _effect_id: String) -> Array:
	return []

func hand_addition_demand(_context, _targets: Dictionary) -> int:
	return 0

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id}

func _has_state(context) -> bool:
	return context != null and context.state != null

func _target_matches(targets: Dictionary, key: String, expected_kind: String) -> bool:
	return targets.has(key) and targets[key].get("kind", "") == expected_kind

func _event(event_type: String, data: Dictionary):
	const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
	return DomainEventScript.new(event_type, data)
