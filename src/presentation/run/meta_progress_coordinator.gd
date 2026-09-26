class_name MetaProgressCoordinator
extends RefCounted

const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")

var state
var store
var last_persistence_error := ""
var last_profile_load_error := ""
var last_rejected_profile_path := ""
var profile_loaded := false
var recovery_required := false

func _init(initial_store = null, initial_state = null) -> void:
	store = initial_store if initial_store != null else MetaProgressStoreScript.new()
	state = initial_state if initial_state != null else MetaProgressStateScript.new()

func load_profile() -> Dictionary:
	var loaded: Dictionary = store.load_profile()
	if loaded.get("accepted", false):
		state = loaded.state
		profile_loaded = true
		recovery_required = false
		last_profile_load_error = ""
		last_rejected_profile_path = ""
	else:
		state = MetaProgressStateScript.new()
		profile_loaded = false
		recovery_required = true
		last_profile_load_error = str(loaded.get("code", "META_PROGRESS_LOAD_FAILED"))
		last_rejected_profile_path = str(loaded.get("preserved_path", ""))
	return loaded

func is_unlocked(kind: String, content_id: String) -> bool:
	return state.is_unlocked(kind, content_id)

func observe_run_state(run_state) -> Dictionary:
	if run_state == null:
		return {"accepted": false, "code": "MISSING_RUN_STATE", "changed": false}
	if recovery_required or not profile_loaded:
		return {"accepted": true, "changed": false, "persisted": false, "reason": "PROFILE_RECOVERY_REQUIRED"}
	if not [RunPhaseScript.RUN_SUMMARY, RunPhaseScript.RUN_COMPLETE].has(str(run_state.phase)):
		return {"accepted": true, "changed": false, "reason": "RUN_NOT_TERMINAL"}
	if int(run_state.act_index) != 2 or int(run_state.act_count) != 2:
		return {"accepted": true, "changed": false, "reason": "NOT_ACT_TWO_ALPHA"}
	if str(run_state.terminal_summary.outcome) != "VICTORY" or str(run_state.terminal_summary.reason) != "BOSS_DEFEATED":
		return {"accepted": true, "changed": false, "reason": "NOT_NORMAL_ENDING"}
	var changed = state.record_act_two_normal_ending(str(run_state.run_id))
	if not changed:
		return {"accepted": true, "changed": false, "reason": "ALREADY_RECORDED_OR_TEST_PROFILE"}
	var saved: Dictionary = store.save_profile(state)
	last_persistence_error = "" if saved.get("accepted", false) else str(saved.get("code", "META_PROGRESS_SAVE_FAILED"))
	return {"accepted": true, "changed": true, "persisted": bool(saved.get("accepted", false)), "save_result": saved}

func reset_profile() -> Dictionary:
	if not recovery_required:
		return {"accepted": false, "code": "PROFILE_RESET_NOT_REQUIRED"}
	if last_rejected_profile_path.is_empty():
		return {"accepted": false, "code": "REJECTED_PROFILE_NOT_PRESERVED"}
	var fresh_state = MetaProgressStateScript.new()
	var saved: Dictionary = store.save_profile(fresh_state)
	if not saved.get("accepted", false):
		last_persistence_error = str(saved.get("code", "META_PROGRESS_RESET_FAILED"))
		return saved
	state = fresh_state
	profile_loaded = true
	recovery_required = false
	last_profile_load_error = ""
	last_persistence_error = ""
	saved["preserved_path"] = last_rejected_profile_path
	return saved
