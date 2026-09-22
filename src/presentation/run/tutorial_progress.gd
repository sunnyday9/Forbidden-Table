class_name TutorialProgress
extends RefCounted

const DRAW_PATTERN_PARTIAL := "tutorial.draw_pattern_partial_settlement"
const TP_CORE_TECHNIQUE := "tutorial.tp_core_technique"
const RESERVE_INTEGRITY := "tutorial.reserve_integrity"
const YAKU_COMPLETE_HAND := "tutorial.yaku_complete_hand"
const CONTAMINATION_INTENT := "tutorial.contamination_intent"
const STEP_IDS := [
	DRAW_PATTERN_PARTIAL,
	TP_CORE_TECHNIQUE,
	RESERVE_INTEGRITY,
	YAKU_COMPLETE_HAND,
	CONTAMINATION_INTENT,
]

const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const TutorialProgressScript = preload("res://src/presentation/run/tutorial_progress.gd")

var enabled := true
var completed_step_ids: Array = []
var current_step_id := DRAW_PATTERN_PARTIAL

func observe(events: Array) -> void:
	if not enabled or current_step_id.is_empty():
		return
	for event in events:
		if event == null:
			continue
		var event_type := str(event.event_type) if event.has_method("to_dictionary") else str(event.get("event_type", ""))
		if _event_completes_current_step(event_type):
			_complete_current_step()
			break

func reset() -> void:
	enabled = true
	completed_step_ids = []
	current_step_id = DRAW_PATTERN_PARTIAL

func disable() -> void:
	enabled = false

func enable() -> void:
	enabled = true
	if current_step_id.is_empty() and completed_step_ids.size() < STEP_IDS.size():
		current_step_id = STEP_IDS[completed_step_ids.size()]

func is_complete() -> bool:
	return completed_step_ids.size() == STEP_IDS.size()

func to_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"enabled": enabled,
		"completed_step_ids": completed_step_ids.duplicate(),
		"current_step_id": current_step_id,
	}

static func from_dictionary(data: Dictionary):
	var progress = TutorialProgressScript.new()
	progress.enabled = bool(data.get("enabled", true))
	progress.completed_step_ids = []
	for step_id in data.get("completed_step_ids", []):
		if str(step_id) in STEP_IDS and not progress.completed_step_ids.has(str(step_id)):
			progress.completed_step_ids.append(str(step_id))
	progress.current_step_id = str(data.get("current_step_id", ""))
	if progress.current_step_id.is_empty() and not progress.is_complete():
		progress.current_step_id = STEP_IDS[progress.completed_step_ids.size()]
	return progress

func _event_completes_current_step(event_type: String) -> bool:
	match current_step_id:
		DRAW_PATTERN_PARTIAL:
			return event_type in [DomainEventScript.TILE_DRAWN, DomainEventScript.PATTERN_SETTLED]
		TP_CORE_TECHNIQUE:
			return event_type == DomainEventScript.TP_CHANGED
		RESERVE_INTEGRITY:
			return event_type in [DomainEventScript.RESERVE_STORED, DomainEventScript.RESERVE_SWAPPED, DomainEventScript.INTEGRITY_CHANGED]
		YAKU_COMPLETE_HAND:
			return event_type == DomainEventScript.COMPLETE_HAND_SETTLED
		CONTAMINATION_INTENT:
			return event_type in [DomainEventScript.CONTAMINATION_APPLIED, DomainEventScript.ENEMY_INTENT_RESOLVED]
	return false

func _complete_current_step() -> void:
	if not completed_step_ids.has(current_step_id):
		completed_step_ids.append(current_step_id)
	var next_index := STEP_IDS.find(current_step_id) + 1
	current_step_id = STEP_IDS[next_index] if next_index < STEP_IDS.size() else ""
