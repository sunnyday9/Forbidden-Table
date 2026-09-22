class_name BreakPolicy
extends RefCounted

const DISCARD := "DISCARD"
const EXHAUST := "EXHAUST"
const ALL: Array[String] = [DISCARD, EXHAUST]

static func is_valid(policy: String) -> bool:
	return ALL.has(policy)
