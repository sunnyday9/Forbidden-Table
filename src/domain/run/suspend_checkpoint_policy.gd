extends RefCounted

const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")

const STABLE_BOUNDARIES := [
	"MAP_NODE", "BATTLE_START", "TURN_START", "DRAW_ACTION", "BATTLE_ACTION",
	"SETTLEMENT_COMPLETE", "ENEMY_INTENT_COMPLETE", "SHOP", "WORKSHOP",
	"EVENT_CHOICE_BEFORE", "EVENT_CHOICE_AFTER", "REWARD", "RUN_SUMMARY", "RUN_COMPLETE",
]
const UNSTABLE_BOUNDARIES := ["EFFECT_QUEUE", "REACTION_WINDOW", "PATTERN_RESOLUTION", "BOSS_TRANSITION"]

static func boundary_for_phase(phase: String, event_active: bool = false, battle_queue_active: bool = false) -> String:
	match phase:
		RunPhaseScript.MAP_CHOICE:
			return "MAP_NODE"
		RunPhaseScript.BATTLE:
			return "EFFECT_QUEUE" if battle_queue_active else "BATTLE_START"
		RunPhaseScript.SHOP:
			return "SHOP"
		RunPhaseScript.WORKSHOP:
			return "WORKSHOP"
		RunPhaseScript.EVENT:
			return "EVENT_CHOICE_BEFORE" if event_active else "EVENT_CHOICE_AFTER"
		RunPhaseScript.REWARD_CHOICE, RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD:
			return "REWARD"
		RunPhaseScript.RUN_SUMMARY:
			return "RUN_SUMMARY"
		RunPhaseScript.RUN_COMPLETE:
			return "RUN_COMPLETE"
	return ""

static func is_boundary_valid_for_phase(boundary: String, phase: String) -> bool:
	match boundary:
		"MAP_NODE":
			return phase == RunPhaseScript.MAP_CHOICE
		"BATTLE_START", "TURN_START", "DRAW_ACTION", "BATTLE_ACTION", "SETTLEMENT_COMPLETE", "ENEMY_INTENT_COMPLETE":
			return phase == RunPhaseScript.BATTLE
		"SHOP":
			return phase == RunPhaseScript.SHOP
		"WORKSHOP":
			return phase == RunPhaseScript.WORKSHOP
		"EVENT_CHOICE_BEFORE", "EVENT_CHOICE_AFTER":
			return phase == RunPhaseScript.EVENT
		"REWARD":
			return phase in [RunPhaseScript.REWARD_CHOICE, RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD]
		"RUN_SUMMARY":
			return phase == RunPhaseScript.RUN_SUMMARY
		"RUN_COMPLETE":
			return phase == RunPhaseScript.RUN_COMPLETE
	return false

static func resolve_result_boundary(requested_boundary: String, resulting_phase: String, inferred_boundary: String) -> String:
	if is_boundary_valid_for_phase(requested_boundary, resulting_phase):
		return requested_boundary
	if is_boundary_valid_for_phase(inferred_boundary, resulting_phase):
		return inferred_boundary
	return ""
