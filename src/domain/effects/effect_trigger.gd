class_name EffectTrigger
extends RefCounted

const MANUAL := "MANUAL"
const DRAW := "DRAW"
const SETTLEMENT := "SETTLEMENT"
const TURN_END := "TURN_END"

var trigger_id: String
var priority: int

func _init(identifier: String = MANUAL, trigger_priority: int = 0) -> void:
	trigger_id = identifier
	priority = trigger_priority

func is_valid() -> bool:
	return not trigger_id.is_empty()

func to_dictionary() -> Dictionary:
	return {"trigger_id": trigger_id, "priority": priority}
