class_name RunPresentationState
extends RefCounted

const NORMAL := "NORMAL"
const FAST := "FAST"
const INSTANT := "INSTANT"
const MODES := [NORMAL, FAST, INSTANT]

var screen := ""
var phase := ""
var focus_action_ids: Array = []
var focused_index := 0
var details_action_id := ""
var details_payload: Dictionary = {}
var feedback := ""
var presentation_mode := NORMAL
var authoritative_snapshot: Dictionary = {}
var last_domain_event_types: Array = []

func set_focus_actions(action_ids: Array, preferred_id: String = "") -> void:
	var previous_id := focused_action_id()
	focus_action_ids = action_ids.duplicate()
	var next_id := preferred_id if not preferred_id.is_empty() else previous_id
	focused_index = focus_action_ids.find(next_id)
	if focused_index < 0:
		focused_index = 0
	if focus_action_ids.is_empty():
		focused_index = 0

func focused_action_id() -> String:
	if focused_index < 0 or focused_index >= focus_action_ids.size():
		return ""
	return str(focus_action_ids[focused_index])

func focus_next() -> String:
	if focus_action_ids.is_empty():
		return ""
	focused_index = (focused_index + 1) % focus_action_ids.size()
	return focused_action_id()

func focus_previous() -> String:
	if focus_action_ids.is_empty():
		return ""
	focused_index = (focused_index - 1 + focus_action_ids.size()) % focus_action_ids.size()
	return focused_action_id()

func set_mode(mode: String) -> bool:
	if not MODES.has(mode):
		return false
	presentation_mode = mode
	return true

func clear_details() -> void:
	details_action_id = ""
	details_payload = {}

func to_dictionary() -> Dictionary:
	return {
		"screen": screen,
		"phase": phase,
		"focus_action_ids": focus_action_ids.duplicate(),
		"focused_index": focused_index,
		"focused_action_id": focused_action_id(),
		"details_action_id": details_action_id,
		"details_payload": details_payload.duplicate(true),
		"feedback": feedback,
		"presentation_mode": presentation_mode,
		"authoritative_snapshot": authoritative_snapshot.duplicate(true),
		"last_domain_event_types": last_domain_event_types.duplicate(),
	}
