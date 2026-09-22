class_name CombatState
extends RefCounted

const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const EnemyIntentScript = preload("res://src/domain/combat/enemy_intent.gd")

const ONGOING := "ONGOING"
const VICTORY := "VICTORY"
const DEFEAT := "DEFEAT"

var enemy_hp: int
var enemy_max_hp: int
var pressure: int
var pressure_limit: int
var current_intent
var intent_index: int
var pending_death: bool
var pending_defeat: bool
var pending_death_sequence_index: int
var pending_defeat_sequence_index: int
var terminal_sequence_index: int
var terminal_outcome: String
var queue_index: int
var state_based_check_count: int
var tp: int
var stability: int
var draw_capacity: int
var settlement_capacity: int
var reserve_capacity: int
var active_effects: Dictionary
var zones
var draw_wall

var _intent_loop: Array
var _next_sequence_index: int
var _queue_active: bool

func _init(
	initial_enemy_hp: int,
	initial_pressure_limit: int,
	initial_pressure: int = 0,
	initial_intent_loop: Array = [],
	initial_tp: int = 0,
	initial_stability: int = 0,
	initial_draw_capacity: int = 3,
	initial_settlement_capacity: int = 1,
	initial_reserve_capacity: int = 3,
) -> void:
	enemy_max_hp = maxi(0, initial_enemy_hp)
	enemy_hp = enemy_max_hp
	pressure_limit = maxi(1, initial_pressure_limit)
	pressure = clampi(initial_pressure, 0, pressure_limit)
	_intent_loop = _validated_intent_loop(initial_intent_loop)
	intent_index = 0
	current_intent = _intent_loop[intent_index]
	pending_death = false
	pending_defeat = false
	pending_death_sequence_index = -1
	pending_defeat_sequence_index = -1
	terminal_sequence_index = -1
	terminal_outcome = ONGOING
	queue_index = 0
	state_based_check_count = 0
	tp = maxi(0, initial_tp)
	stability = maxi(0, initial_stability)
	draw_capacity = maxi(0, initial_draw_capacity)
	settlement_capacity = maxi(0, initial_settlement_capacity)
	reserve_capacity = maxi(0, initial_reserve_capacity)
	active_effects = {}
	zones = null
	draw_wall = null
	_next_sequence_index = 0
	_queue_active = false

func is_active() -> bool:
	return terminal_outcome == ONGOING

func intent_loop() -> Array:
	return _intent_loop.duplicate()

func peek_next_intent():
	return _intent_loop[(intent_index + 1) % _intent_loop.size()]

func advance_intent() -> void:
	intent_index = (intent_index + 1) % _intent_loop.size()
	current_intent = _intent_loop[intent_index]

func to_dictionary() -> Dictionary:
	return {
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"pressure": pressure,
		"pressure_limit": pressure_limit,
		"current_intent": current_intent.to_dictionary(),
		"intent_index": intent_index,
		"pending_death": pending_death,
		"pending_defeat": pending_defeat,
		"pending_death_sequence_index": pending_death_sequence_index,
		"pending_defeat_sequence_index": pending_defeat_sequence_index,
		"terminal_sequence_index": terminal_sequence_index,
		"terminal_outcome": terminal_outcome,
		"queue_index": queue_index,
		"state_based_check_count": state_based_check_count,
		"tp": tp,
		"stability": stability,
		"draw_capacity": draw_capacity,
		"settlement_capacity": settlement_capacity,
		"reserve_capacity": reserve_capacity,
		"active_effects": _sorted_effect_ids(),
		"active_effect_details": _sorted_effect_details(),
	}

func has_pending_terminal() -> bool:
	return pending_death or pending_defeat

func is_queue_active() -> bool:
	return _queue_active

func _validated_intent_loop(candidate_loop: Array) -> Array:
	var intents: Array = []
	for intent in candidate_loop:
		if intent is EnemyIntentScript:
			intents.append(intent)
	if intents.is_empty():
		intents.append(EnemyIntentScript.new("pressure_rise", "Pressure Rise", 2))
		intents.append(EnemyIntentScript.new("pressure_surge", "Pressure Surge", 3))
	return intents

func _start_queue() -> bool:
	if _queue_active or not is_active():
		return false
	_queue_active = true
	return true

func _abort_queue_without_boundary() -> void:
	_queue_active = false

func _next_effect_sequence_index() -> int:
	_next_sequence_index += 1
	return _next_sequence_index

func _apply_step(step, sequence_index: int) -> Array:
	var events: Array = []
	if step.damage_amount > 0:
		events.append_array(_apply_damage(step.damage_amount, step.source_id, sequence_index))
	if step.pressure_delta != 0:
		events.append_array(_apply_pressure(step.pressure_delta, step.source_id, sequence_index))
	return events

func _sorted_effect_ids() -> Array:
	var ids: Array = active_effects.keys()
	ids.sort()
	return ids

func _sorted_effect_details() -> Array:
	var details: Array = []
	for effect_id in _sorted_effect_ids():
		var effect = active_effects[effect_id]
		details.append(effect.to_dictionary() if effect is Object and effect.has_method("to_dictionary") else {"instance_id": str(effect_id)})
	return details

func _apply_damage(amount: int, source_id: String, sequence_index: int) -> Array:
	var events: Array = []
	var previous_hp := enemy_hp
	enemy_hp = maxi(0, enemy_hp - amount)
	if enemy_hp != previous_hp:
		events.append(DomainEventScript.new(DomainEventScript.ENEMY_HP_CHANGED, {
			"source_id": source_id,
			"previous_hp": previous_hp,
			"enemy_hp": enemy_hp,
			"amount": previous_hp - enemy_hp,
			"sequence_index": sequence_index,
		}))
	if enemy_hp <= 0 and not pending_death:
		pending_death = true
		pending_death_sequence_index = sequence_index
		events.append(DomainEventScript.new(DomainEventScript.PENDING_DEATH, {
			"source_id": source_id,
			"sequence_index": sequence_index,
		}))
	return events

func _apply_pressure(amount: int, source_id: String, sequence_index: int) -> Array:
	var events: Array = []
	var previous_pressure := pressure
	pressure = clampi(pressure + amount, 0, pressure_limit)
	if pressure != previous_pressure:
		events.append(DomainEventScript.new(DomainEventScript.PRESSURE_CHANGED, {
			"source_id": source_id,
			"previous_pressure": previous_pressure,
			"pressure": pressure,
			"pressure_limit": pressure_limit,
			"amount": pressure - previous_pressure,
			"sequence_index": sequence_index,
		}))
	if pressure >= pressure_limit and not pending_defeat:
		pending_defeat = true
		pending_defeat_sequence_index = sequence_index
		events.append(DomainEventScript.new(DomainEventScript.PENDING_DEFEAT, {
			"source_id": source_id,
			"sequence_index": sequence_index,
		}))
	return events

func _finish_queue() -> Array:
	_queue_active = false
	queue_index += 1
	return _run_state_based_checks()

func _run_state_based_checks() -> Array:
	state_based_check_count += 1
	var events: Array = []
	if terminal_outcome != ONGOING:
		return events
	if pending_death and pending_defeat:
		if pending_death_sequence_index < pending_defeat_sequence_index:
			terminal_outcome = VICTORY
			terminal_sequence_index = pending_death_sequence_index
		else:
			terminal_outcome = DEFEAT
			terminal_sequence_index = pending_defeat_sequence_index
	elif pending_death:
		terminal_outcome = VICTORY
		terminal_sequence_index = pending_death_sequence_index
	elif pending_defeat:
		terminal_outcome = DEFEAT
		terminal_sequence_index = pending_defeat_sequence_index

	if terminal_outcome == VICTORY:
		events.append(DomainEventScript.new(DomainEventScript.BATTLE_WON, {
			"queue_index": queue_index,
			"terminal_sequence_index": terminal_sequence_index,
		}))
	elif terminal_outcome == DEFEAT:
		events.append(DomainEventScript.new(DomainEventScript.BATTLE_LOST, {
			"queue_index": queue_index,
			"terminal_sequence_index": terminal_sequence_index,
		}))
	return events
