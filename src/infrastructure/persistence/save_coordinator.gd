class_name SaveCoordinator
extends RefCounted

const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")

const STABLE_BOUNDARIES := ["MAP_NODE", "BATTLE_START", "TURN_START", "DRAW_ACTION", "SETTLEMENT_COMPLETE", "ENEMY_INTENT_COMPLETE", "SHOP", "WORKSHOP", "EVENT_CHOICE_BEFORE", "EVENT_CHOICE_AFTER", "REWARD", "RUN_SUMMARY", "RUN_COMPLETE"]
const UNSTABLE_BOUNDARIES := ["EFFECT_QUEUE", "REACTION_WINDOW", "PATTERN_RESOLUTION", "BOSS_TRANSITION"]

func can_save(domain, boundary: String = "") -> Dictionary:
	if domain == null or domain.state == null:
		return _reject("MISSING_DOMAIN")
	if not RunPhaseScript.all().has(str(domain.state.phase)):
		return _reject("INVALID_RUN_PHASE", {"phase": str(domain.state.phase)})
	var actual_boundary := _boundary_for(domain)
	if UNSTABLE_BOUNDARIES.has(actual_boundary):
		return _reject("UNSTABLE_CHECKPOINT", {"boundary": actual_boundary})
	var resolved := boundary if not boundary.is_empty() else _boundary_for(domain)
	if not STABLE_BOUNDARIES.has(resolved):
		return _reject("UNSUPPORTED_CHECKPOINT", {"boundary": resolved})
	return {"accepted": true, "boundary": resolved}

func save(domain, boundary: String = "") -> Dictionary:
	var check := can_save(domain, boundary)
	if not check.accepted:
		return check
	var metadata := {"stable": true, "stable_boundary": check.boundary, "checkpoint_sequence": int(domain.state.reward_draft_sequence) + int(domain.state.tile_instance_sequence), "state_hash": domain.checkpoint().state_hash}
	return {"accepted": true, "snapshot": SaveMapperScript.suspend_snapshot(domain, metadata), "checkpoint_metadata": metadata}

func _boundary_for(domain) -> String:
	match domain.state.phase:
		RunPhaseScript.MAP_CHOICE:
			return "MAP_NODE"
		RunPhaseScript.BATTLE:
			if domain.current_battle != null and domain.current_battle.combat_state != null:
				if domain.current_battle.combat_state.is_queue_active():
					return "EFFECT_QUEUE"
			return "BATTLE_START"
		RunPhaseScript.SHOP:
			return "SHOP"
		RunPhaseScript.WORKSHOP:
			return "WORKSHOP"
		RunPhaseScript.EVENT:
			return "EVENT_CHOICE_BEFORE" if domain.state.event_state.active else "EVENT_CHOICE_AFTER"
		RunPhaseScript.REWARD_CHOICE, RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD:
			return "REWARD"
		RunPhaseScript.RUN_SUMMARY:
			return "RUN_SUMMARY"
		RunPhaseScript.RUN_COMPLETE:
			return "RUN_COMPLETE"
	return ""

func _reject(code: String, details: Dictionary = {}) -> Dictionary:
	return {"accepted": false, "code": code, "details": details}
