class_name StackPolicy
extends RefCounted

const REPLACE := "REPLACE"
const REFRESH_DURATION := "REFRESH_DURATION"
const ADD_STACKS := "ADD_STACKS"
const ADD_DURATION := "ADD_DURATION"
const INDEPENDENT_INSTANCES := "INDEPENDENT_INSTANCES"
const UNIQUE := "UNIQUE"

var policy_id: String
var max_stacks: int

func _init(identifier: String = REPLACE, stack_limit: int = 0) -> void:
	policy_id = identifier if not identifier.is_empty() else REPLACE
	max_stacks = maxi(0, stack_limit)

func to_dictionary() -> Dictionary:
	return {"policy": policy_id, "max_stacks": max_stacks}
