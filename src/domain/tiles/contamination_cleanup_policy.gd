class_name ContaminationCleanupPolicy
extends RefCounted

const REMOVE_TILE := "REMOVE_TILE"
const CLEAR_CONTAMINATION := "CLEAR_CONTAMINATION"
const KEEP := "KEEP"

const ALL_POLICIES: Array[String] = [REMOVE_TILE, CLEAR_CONTAMINATION, KEEP]

static func is_valid(policy: String) -> bool:
	return ALL_POLICIES.has(policy)
