class_name DomainRngStreams
extends RefCounted

const DeterministicRngStreamScript = preload("res://src/infrastructure/rng/deterministic_rng_stream.gd")
const SNAPSHOT_VERSION := 1
const COMBAT_STREAM_ID := "combat"
const DRAW_WALL_STREAM_ID := "draw_wall"
const ENEMY_STREAM_ID := "enemy"

var combat
var draw_wall
var enemy

func _init(root_seed: int) -> void:
	combat = DeterministicRngStreamScript.new(root_seed, COMBAT_STREAM_ID)
	draw_wall = DeterministicRngStreamScript.new(root_seed, DRAW_WALL_STREAM_ID)
	enemy = DeterministicRngStreamScript.new(root_seed, ENEMY_STREAM_ID)

func snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"streams": {
			COMBAT_STREAM_ID: combat.snapshot(),
			DRAW_WALL_STREAM_ID: draw_wall.snapshot(),
			ENEMY_STREAM_ID: enemy.snapshot(),
		},
	}

func restore(saved_state: Dictionary) -> bool:
	if saved_state.get("version", -1) != SNAPSHOT_VERSION:
		return false
	if typeof(saved_state.get("streams")) != TYPE_DICTIONARY:
		return false

	var stream_states: Dictionary = saved_state["streams"]
	var previous_state: Dictionary = snapshot()
	if _restore_streams(stream_states):
		return true

	var previous_stream_states: Dictionary = previous_state["streams"]
	_restore_streams(previous_stream_states)
	return false

func _restore_streams(stream_states: Dictionary) -> bool:
	if not stream_states.has(COMBAT_STREAM_ID):
		return false
	if not stream_states.has(DRAW_WALL_STREAM_ID):
		return false
	if not stream_states.has(ENEMY_STREAM_ID):
		return false
	if typeof(stream_states[COMBAT_STREAM_ID]) != TYPE_DICTIONARY:
		return false
	if typeof(stream_states[DRAW_WALL_STREAM_ID]) != TYPE_DICTIONARY:
		return false
	if typeof(stream_states[ENEMY_STREAM_ID]) != TYPE_DICTIONARY:
		return false

	if not combat.restore(stream_states[COMBAT_STREAM_ID]):
		return false
	if not draw_wall.restore(stream_states[DRAW_WALL_STREAM_ID]):
		return false
	if not enemy.restore(stream_states[ENEMY_STREAM_ID]):
		return false
	return true
