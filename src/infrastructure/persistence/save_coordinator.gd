class_name SaveCoordinator
extends RefCounted

const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const SuspendCheckpointPolicyScript = preload("res://src/domain/run/suspend_checkpoint_policy.gd")

const STABLE_BOUNDARIES := SuspendCheckpointPolicyScript.STABLE_BOUNDARIES
const UNSTABLE_BOUNDARIES := SuspendCheckpointPolicyScript.UNSTABLE_BOUNDARIES

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
	if not SuspendCheckpointPolicyScript.is_boundary_valid_for_phase(resolved, str(domain.state.phase)):
		return _reject("CHECKPOINT_BOUNDARY_MISMATCH", {"boundary": resolved, "phase": str(domain.state.phase)})
	return {"accepted": true, "boundary": resolved}

func save(domain, boundary: String = "") -> Dictionary:
	var check := can_save(domain, boundary)
	if not check.accepted:
		return check
	var metadata := {"stable": true, "stable_boundary": check.boundary, "checkpoint_sequence": int(domain.state.reward_draft_sequence) + int(domain.state.tile_instance_sequence), "state_hash": domain.checkpoint().state_hash}
	return {"accepted": true, "snapshot": SaveMapperScript.suspend_snapshot(domain, metadata), "checkpoint_metadata": metadata}

func boundary_for(domain) -> String:
	if domain == null or domain.state == null:
		return ""
	return _boundary_for(domain)

func _boundary_for(domain) -> String:
	var battle_queue_active: bool = (
		domain.current_battle != null
		and domain.current_battle.combat_state != null
		and domain.current_battle.combat_state.is_queue_active()
	)
	var event_active: bool = domain.state.event_state.active if domain.state.event_state != null else false
	return SuspendCheckpointPolicyScript.boundary_for_phase(str(domain.state.phase), event_active, battle_queue_active)

func _reject(code: String, details: Dictionary = {}) -> Dictionary:
	return {"accepted": false, "code": code, "details": details}
