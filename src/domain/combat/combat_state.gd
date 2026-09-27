class_name CombatState
extends RefCounted

const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const EnemyIntentScript = preload("res://src/domain/combat/enemy_intent.gd")
const IntentGraphScript = preload("res://src/domain/combat/intent_graph.gd")
const IntentTransitionScript = preload("res://src/domain/combat/intent_transition.gd")
const IntentTransitionSelectionScript = preload("res://src/domain/combat/intent_transition_selection.gd")
const DrawEscalationPolicyScript = preload("res://src/domain/tiles/draw_escalation_policy.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

const ONGOING := "ONGOING"
const VICTORY := "VICTORY"
const DEFEAT := "DEFEAT"

var enemy_hp: int
var enemy_max_hp: int
var pressure: int
var pressure_limit: int
var fatigue: int
var starvation_count: int
var starvation_active: bool
var current_intent
var intent_index: int
var intent_graph
var intent_rng
var boss_phases: Array
var boss_phase_index: int
var boss_phase_id: String
var boss_phase_count: int
var pending_death: bool
var pending_defeat: bool
var pending_death_sequence_index: int
var pending_defeat_sequence_index: int
var terminal_sequence_index: int
var terminal_outcome: String
var queue_index: int
var state_based_check_count: int
var tp: int
var triggered_signature_passive_ids: Array[String]
var stability: int
var draw_capacity: int
var draw_actions_used_this_turn: int
var settlement_capacity: int
var reserve_capacity: int
var active_effects: Dictionary
var zones
var draw_wall
var contamination_service
var battle_end_cleanup_done: bool

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
	initial_settlement_capacity: int = 2,
	initial_reserve_capacity: int = 3,
	initial_fatigue: int = 0,
	initial_intent_graph = null,
	initial_intent_rng = null,
) -> void:
	enemy_max_hp = maxi(0, initial_enemy_hp)
	enemy_hp = enemy_max_hp
	pressure_limit = maxi(1, initial_pressure_limit)
	pressure = clampi(initial_pressure, 0, pressure_limit)
	fatigue = maxi(0, initial_fatigue)
	starvation_count = 0
	starvation_active = false
	intent_graph = _build_intent_graph(initial_intent_loop, initial_intent_graph)
	intent_index = 0
	current_intent = intent_graph.intent(intent_graph.start_intent_id)
	intent_rng = initial_intent_rng
	boss_phases = []
	boss_phase_index = -1
	boss_phase_id = ""
	boss_phase_count = 0
	pending_death = false
	pending_defeat = false
	pending_death_sequence_index = -1
	pending_defeat_sequence_index = -1
	terminal_sequence_index = -1
	terminal_outcome = ONGOING
	queue_index = 0
	state_based_check_count = 0
	tp = maxi(0, initial_tp)
	triggered_signature_passive_ids = []
	stability = maxi(0, initial_stability)
	draw_capacity = maxi(0, initial_draw_capacity)
	draw_actions_used_this_turn = 0
	settlement_capacity = maxi(0, initial_settlement_capacity)
	reserve_capacity = maxi(0, initial_reserve_capacity)
	active_effects = {}
	zones = null
	draw_wall = null
	contamination_service = null
	battle_end_cleanup_done = false
	_next_sequence_index = 0
	_queue_active = false

func is_active() -> bool:
	return terminal_outcome == ONGOING

func draw_actions_remaining() -> int:
	return maxi(0, draw_capacity - maxi(0, draw_actions_used_this_turn))

func intent_loop() -> Array:
	return intent_graph.intents()

func peek_next_intent():
	if current_intent == null:
		return null
	var selection = select_next_intent()
	return intent_graph.intent(selection.target_intent_id) if selection.is_selected() else current_intent

func advance_intent(target_intent_id: String = "") -> bool:
	var target = intent_graph.intent(target_intent_id) if not target_intent_id.is_empty() else peek_next_intent()
	if target == null:
		return false
	current_intent = target
	intent_index += 1
	return true

func set_intent_graph(graph) -> void:
	if graph is IntentGraphScript:
		intent_graph = graph
		current_intent = graph.intent(graph.start_intent_id)
		intent_index = 0

func set_intent_rng(rng) -> void:
	intent_rng = rng

func configure_boss_phases(phase_definitions: Array) -> bool:
	if phase_definitions.size() < 2:
		return false
	var normalized_phases: Array = []
	for phase in phase_definitions:
		if not phase is Dictionary:
			return false
		var phase_id := str(phase.get("phase_id", ""))
		var phase_graph = phase.get("intent_graph")
		var phase_max_hp := int(phase.get("max_hp", 0))
		var phase_pressure_limit := int(phase.get("pressure_limit", 0))
		if phase_id.is_empty() or phase_graph == null or not phase_graph.has_method("validation") or not phase_graph.validation().is_valid():
			return false
		if phase_max_hp < 1 or phase_pressure_limit < 1:
			return false
		normalized_phases.append({
			"phase_id": phase_id,
			"intent_graph": phase_graph,
			"max_hp": phase_max_hp,
			"pressure_limit": phase_pressure_limit,
			"pressure_relief": maxi(0, int(phase.get("pressure_relief", 0))),
			"battle_values": phase.get("battle_values", {}).duplicate(true) if phase.get("battle_values", {}) is Dictionary else {},
		})
	boss_phases = normalized_phases
	boss_phase_index = 0
	boss_phase_count = normalized_phases.size()
	_activate_boss_phase(0, false)
	return true

func select_next_intent():
	if intent_graph == null:
		return IntentTransitionSelectionScript.new(IntentTransitionSelectionScript.INVALID_GRAPH, "", "", "CombatState has no Intent Graph.")
	return intent_graph.select_next_intent(
		current_intent.intent_id if current_intent != null else "",
		public_battle_state(),
		intent_rng,
	)

func public_battle_state() -> Dictionary:
	return {
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"pressure": pressure,
		"pressure_limit": pressure_limit,
		"fatigue": fatigue,
		"starvation_count": starvation_count,
		"starvation_active": starvation_active,
		"tp": tp,
		"triggered_signature_passive_ids": triggered_signature_passive_ids.duplicate(),
		"stability": stability,
		"draw_capacity": draw_capacity,
		"draw_actions_used_this_turn": draw_actions_used_this_turn,
		"draw_actions_remaining": draw_actions_remaining(),
		"settlement_capacity": settlement_capacity,
		"reserve_capacity": reserve_capacity,
		"terminal_outcome": terminal_outcome,
		"boss_phase_index": boss_phase_index,
		"boss_phase_id": boss_phase_id,
		"boss_phase_count": boss_phase_count,
		"current_intent_id": current_intent.intent_id if current_intent != null else "",
		"battle_end_cleanup_done": battle_end_cleanup_done,
	}

func to_dictionary() -> Dictionary:
	return {
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"pressure": pressure,
		"pressure_limit": pressure_limit,
		"fatigue": fatigue,
		"starvation_count": starvation_count,
		"starvation_active": starvation_active,
		"current_intent": current_intent.to_dictionary() if current_intent != null else {},
		"intent_index": intent_index,
		"intent_graph": intent_graph.to_dictionary() if intent_graph != null else {},
		"intent_rng": intent_rng.snapshot() if intent_rng != null and intent_rng.has_method("snapshot") else {},
		"boss_phases": _boss_phase_data(),
		"boss_phase_index": boss_phase_index,
		"boss_phase_id": boss_phase_id,
		"boss_phase_count": boss_phase_count,
		"pending_death": pending_death,
		"pending_defeat": pending_defeat,
		"pending_death_sequence_index": pending_death_sequence_index,
		"pending_defeat_sequence_index": pending_defeat_sequence_index,
		"terminal_sequence_index": terminal_sequence_index,
		"terminal_outcome": terminal_outcome,
		"queue_index": queue_index,
		"state_based_check_count": state_based_check_count,
		"tp": tp,
		"triggered_signature_passive_ids": triggered_signature_passive_ids.duplicate(),
		"stability": stability,
		"draw_capacity": draw_capacity,
		"draw_actions_used_this_turn": draw_actions_used_this_turn,
		"settlement_capacity": settlement_capacity,
		"reserve_capacity": reserve_capacity,
		"active_effects": _sorted_effect_ids(),
		"active_effect_details": _sorted_effect_details(),
		"battle_end_cleanup_done": battle_end_cleanup_done,
		"contamination": _contamination_snapshot(),
	}

func set_contamination_service(service) -> void:
	contamination_service = service

func _contamination_snapshot() -> Array:
	var snapshot: Array = []
	if zones == null:
		return snapshot
	var zones_to_snapshot: Array = TileZoneScript.all()
	zones_to_snapshot.append(TileZoneScript.PURGED)
	for zone in zones_to_snapshot:
		for tile in zones.contents(zone):
			if tile != null and tile.has_method("to_dictionary"):
				var tile_data: Dictionary = tile.to_dictionary()
				tile_data["zone"] = zone
				snapshot.append(tile_data)
	snapshot.sort_custom(func(left, right): return left.get("instance_id", "") < right.get("instance_id", ""))
	return snapshot

func has_pending_terminal() -> bool:
	return pending_death or pending_defeat

func increment_fatigue(source_id: String = "", sequence_index: int = -1) -> Array:
	var previous_fatigue := fatigue
	fatigue += 1
	var event_sequence := sequence_index if sequence_index >= 0 else _next_effect_sequence_index()
	return [DomainEventScript.new(DomainEventScript.FATIGUE_CHANGED, {
		"source": source_id,
		"previous_fatigue": previous_fatigue,
		"fatigue": fatigue,
		"amount": fatigue - previous_fatigue,
		"sequence_index": event_sequence,
	})]

func enter_starvation(
	requested: int,
	shortfall: int,
	source_id: String = "",
	sequence_index: int = -1,
	policy = null,
) -> Array:
	starvation_count += 1
	starvation_active = true
	var event_sequence := sequence_index if sequence_index >= 0 else _next_effect_sequence_index()
	var escalation_policy = policy if policy != null else DrawEscalationPolicyScript.new()
	var pressure_amount: int = escalation_policy.pressure_for_starvation(starvation_count) + escalation_policy.pressure_for_fatigue(fatigue)
	var event_type := DomainEventScript.STARVATION_ENTERED if starvation_count == 1 else DomainEventScript.STARVATION_ESCALATED
	var events: Array = [DomainEventScript.new(event_type, {
		"source": source_id,
		"requested": requested,
		"shortfall": shortfall,
		"starvation_count": starvation_count,
		"pressure_amount": pressure_amount,
		"sequence_index": event_sequence,
	})]
	events.append_array(_apply_pressure(pressure_amount, "draw.starvation", event_sequence))
	return events

func is_queue_active() -> bool:
	return _queue_active

func _build_intent_graph(candidate_loop: Array, candidate_graph):
	if candidate_graph is IntentGraphScript:
		return candidate_graph
	var intents: Array = []
	for intent in candidate_loop:
		if intent is EnemyIntentScript:
			intents.append(intent)
	if not intents.is_empty():
		return IntentGraphScript.from_intent_loop(intents)
	return IntentGraphScript.new("pressure_rise", [
		EnemyIntentScript.new("pressure_rise", "Pressure Rise", 2, EnemyIntentScript.PRESSURE, [
			IntentTransitionScript.fixed("pressure_rise.to.surge", "pressure_surge"),
		]),
		EnemyIntentScript.new("pressure_surge", "Pressure Surge", 3, EnemyIntentScript.PRESSURE, [
			IntentTransitionScript.fixed("pressure_surge.to.rise", "pressure_rise"),
		]),
	])

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
	var death_is_first := pending_death and (
		not pending_defeat or pending_death_sequence_index < pending_defeat_sequence_index
	)
	if pending_defeat and not death_is_first:
		terminal_outcome = DEFEAT
		terminal_sequence_index = pending_defeat_sequence_index
	elif pending_death:
		if _has_next_boss_phase():
			events.append(_advance_boss_phase())
			return events
		terminal_outcome = VICTORY
		terminal_sequence_index = pending_death_sequence_index

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

func _has_next_boss_phase() -> bool:
	return boss_phase_count > 0 and boss_phase_index + 1 < boss_phase_count

func _advance_boss_phase():
	var previous_phase_index := boss_phase_index
	var previous_phase_id := boss_phase_id
	var previous_pressure := pressure
	var previous_max_hp := enemy_max_hp
	boss_phase_index += 1
	_activate_boss_phase(boss_phase_index, true)
	return DomainEventScript.new(DomainEventScript.BOSS_PHASE_CHANGED, {
		"queue_index": queue_index,
		"previous_phase_index": previous_phase_index,
		"previous_phase_id": previous_phase_id,
		"phase_index": boss_phase_index,
		"phase_id": boss_phase_id,
		"previous_enemy_max_hp": previous_max_hp,
		"enemy_max_hp": enemy_max_hp,
		"previous_pressure": previous_pressure,
		"pressure": pressure,
		"pressure_relief": previous_pressure - pressure,
	})

func _activate_boss_phase(index: int, apply_pressure_relief: bool) -> void:
	var phase: Dictionary = boss_phases[index]
	var phase_values: Dictionary = phase.get("battle_values", {}) if phase.get("battle_values", {}) is Dictionary else {}
	var previous_pressure := pressure
	enemy_max_hp = int(phase_values.get("max_hp", phase["max_hp"]))
	enemy_hp = enemy_max_hp
	pressure_limit = maxi(1, int(phase_values.get("pressure_limit", phase["pressure_limit"])))
	if apply_pressure_relief:
		pressure = clampi(previous_pressure - int(phase_values.get("pressure_relief", phase.get("pressure_relief", 0))), 0, pressure_limit)
	else:
		pressure = clampi(previous_pressure, 0, pressure_limit)
	if phase_values.has("tp"):
		tp = maxi(0, int(phase_values["tp"]))
	if phase_values.has("stability"):
		stability = maxi(0, int(phase_values["stability"]))
	if phase_values.has("draw_capacity"):
		draw_capacity = maxi(0, int(phase_values["draw_capacity"]))
	if phase_values.has("settlement_capacity"):
		settlement_capacity = maxi(0, int(phase_values["settlement_capacity"]))
	set_intent_graph(phase["intent_graph"])
	boss_phase_id = str(phase["phase_id"])
	pending_death = false
	pending_defeat = false
	pending_death_sequence_index = -1
	pending_defeat_sequence_index = -1

func _boss_phase_data() -> Array:
	var phases: Array = []
	for phase in boss_phases:
		phases.append({
			"phase_id": phase.get("phase_id", ""),
			"max_hp": phase.get("max_hp", 0),
			"pressure_limit": phase.get("pressure_limit", 0),
			"pressure_relief": phase.get("pressure_relief", 0),
			"battle_values": phase.get("battle_values", {}).duplicate(true) if phase.get("battle_values", {}) is Dictionary else {},
			"intent_graph": phase["intent_graph"].to_dictionary() if phase.get("intent_graph") != null and phase["intent_graph"].has_method("to_dictionary") else {},
		})
	return phases
