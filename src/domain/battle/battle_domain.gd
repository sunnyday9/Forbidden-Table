class_name BattleDomain
extends RefCounted

const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const CombatConversionProfileScript = preload("res://src/domain/combat/combat_conversion_profile.gd")
const CompleteHandInterpretationScript = preload("res://src/domain/mahjong/complete_hand/complete_hand_interpretation.gd")
const CompleteHandSettlementResultScript = preload("res://src/domain/mahjong/settlement/complete_hand_settlement_result.gd")
const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")
const ReserveActionResultScript = preload("res://src/domain/tiles/reserve_action_result.gd")
const ReserveServiceScript = preload("res://src/domain/tiles/reserve_service.gd")
const RecoveryStateScript = preload("res://src/domain/recovery/recovery_state.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const ContaminationServiceScript = preload("res://src/domain/tiles/contamination_service.gd")
const ActiveEffectInstanceScript = preload("res://src/domain/effects/active_effect_instance.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")
const SettlementCapacityScript = preload("res://src/domain/mahjong/settlement/settlement_capacity.gd")
const EffectContextScript = preload("res://src/domain/effects/effect_context.gd")
const CharacterPassiveDefinitionScript = preload("res://src/content/definitions/character_passive_definition.gd")

var zones
var draw_wall
var tile_actions
var settlement_window
var settlement_turn
var score_resolver
var conversion_resolver
var conversion_profile
var combat_state
var combat_resolver
var reserve_service
var complete_hand_evaluator
var hand_yaku_resolver
var local_yaku_resolver
var recovery_state
var complete_hand_destination: String
var _complete_hand_conversion_profile
var _rng_streams
var encounter_id: String
var encounter_kind: String
var encounter_definition
var enemy_definition
var enemy_definitions: Array
var context
var battle_start_effect_events: Array = []
var build_effect_resolver
var contamination_service
var _battle_end_cleaned := false

func _init(
	domain_zones,
	domain_draw_wall,
	domain_tile_actions,
	domain_settlement_window,
	domain_settlement_turn,
	domain_score_resolver,
	domain_conversion_resolver,
	domain_conversion_profile,
	domain_combat_state,
	domain_combat_resolver,
	domain_reserve_service = null,
	domain_complete_hand_evaluator = null,
	domain_hand_yaku_resolver = null,
	domain_normal_hand_baseline: int = 13,
	domain_recovery_baseline: int = 10,
	domain_complete_hand_destination: String = TileZoneScript.DISCARD,
	domain_local_yaku_resolver = null,
	domain_rng_streams = null,
) -> void:
	zones = domain_zones
	draw_wall = domain_draw_wall
	tile_actions = domain_tile_actions
	settlement_window = domain_settlement_window
	settlement_turn = domain_settlement_turn
	score_resolver = domain_score_resolver
	conversion_resolver = domain_conversion_resolver
	conversion_profile = domain_conversion_profile
	combat_state = domain_combat_state
	combat_resolver = domain_combat_resolver
	reserve_service = domain_reserve_service
	complete_hand_evaluator = domain_complete_hand_evaluator
	hand_yaku_resolver = domain_hand_yaku_resolver
	local_yaku_resolver = domain_local_yaku_resolver
	complete_hand_destination = domain_complete_hand_destination
	_rng_streams = domain_rng_streams
	encounter_id = ""
	encounter_kind = ""
	encounter_definition = null
	enemy_definition = null
	enemy_definitions = []
	context = null
	battle_start_effect_events = []
	recovery_state = RecoveryStateScript.new(domain_normal_hand_baseline, domain_recovery_baseline)
	_complete_hand_conversion_profile = _build_complete_hand_conversion_profile()
	if reserve_service == null and tile_actions != null:
		reserve_service = tile_actions.reserve_service
	if reserve_service == null:
		reserve_service = ReserveServiceScript.new(zones, combat_state.reserve_capacity if combat_state != null else 3)
	if combat_state != null:
		combat_state.zones = zones
		combat_state.draw_wall = draw_wall
		if tile_actions != null and tile_actions.has_method("set_combat_state"):
			tile_actions.set_combat_state(combat_state)
		reserve_service.set_capacity(combat_state.reserve_capacity)
	var tile_action_contamination = tile_actions.get("contamination_service") if tile_actions != null else null
	contamination_service = tile_action_contamination if tile_action_contamination != null else ContaminationServiceScript.new(zones, combat_state)
	if tile_actions != null and tile_actions.has_method("set_contamination_service"):
		tile_actions.set_contamination_service(contamination_service)
	if combat_state != null and combat_state.has_method("set_contamination_service"):
		combat_state.set_contamination_service(contamination_service)

func execute(command):
	if command == null or not command.has_method("execute"):
		return CommandResultScript.new(
			"",
			"UnknownCommand",
			"",
			"",
			false,
			CommandResultScript.REJECTED,
			CommandValidationScript.new(false, "UNKNOWN_COMMAND", "Unsupported domain command."),
		)
	return command.execute(self)

func outcome() -> String:
	return combat_state.terminal_outcome if combat_state != null else ""

func is_terminal() -> bool:
	return combat_state != null and not combat_state.is_active()

func public_state() -> Dictionary:
	var state: Dictionary = combat_state.public_battle_state() if combat_state != null else {}
	state["encounter_id"] = encounter_id
	state["encounter_kind"] = encounter_kind
	state["enemy_ids"] = enemy_definition_ids()
	state["enemy_identity"] = enemy_definition.enemy_identity if enemy_definition != null else ""
	state["intent_graph"] = (
		combat_state.intent_graph.to_dictionary()
		if combat_state != null and combat_state.intent_graph != null and combat_state.intent_graph.has_method("to_dictionary")
		else {}
	)
	return state

func enemy_definition_ids() -> Array:
	var ids: Array = []
	for definition in enemy_definitions:
		if definition != null:
			ids.append(definition.content_id)
	return ids

func validate_draw() -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	if combat_state.draw_actions_remaining() <= 0:
		return CommandValidationScript.new(false, "DRAW_ACTION_BUDGET_EXHAUSTED", "No Draw Actions remain this turn.")
	if tile_actions == null or draw_wall == null or not draw_wall.is_initialized():
		return CommandValidationScript.new(false, "DRAW_WALL_NOT_READY", "The Draw Wall is not ready.")
	return CommandValidationScript.new(true)

func resolve_character_passive(passive_definition) -> Dictionary:
	if not passive_definition is CharacterPassiveDefinitionScript or combat_state == null or not combat_state.is_active():
		return {"accepted": false, "status": "INVALID_CHARACTER_PASSIVE"}
	if combat_state.triggered_signature_passive_ids.has(passive_definition.content_id):
		return {"accepted": false, "status": "CHARACTER_PASSIVE_ALREADY_TRIGGERED"}
	var effect_context = EffectContextScript.new(combat_state, zones, draw_wall, reserve_service, contamination_service)
	var queue = combat_resolver.begin_queue(combat_state, 256, effect_context)
	for effect in passive_definition.effects:
		if effect == null or not effect.has_method("validate_in_context") or not effect.validate_in_context(effect_context).get("valid", false):
			return {"accepted": false, "status": "CHARACTER_PASSIVE_EFFECT_REJECTED"}
		if not queue.enqueue_effect(effect):
			queue.drain()
			return {"accepted": false, "status": "CHARACTER_PASSIVE_QUEUE_REJECTED"}
	queue.add_event(DomainEventScript.new(DomainEventScript.CHARACTER_PASSIVE_TRIGGERED, {
		"passive_id": passive_definition.content_id,
		"trigger_id": passive_definition.trigger_id,
	}))
	var result = queue.drain()
	if result.is_resolved():
		combat_state.triggered_signature_passive_ids.append(passive_definition.content_id)
	return {"accepted": result.is_resolved(), "status": result.status, "events": result.events}



func execute_draw() -> Dictionary:
	var draw_result = tile_actions.draw()
	var events: Array = draw_result.events
	if draw_result.is_accepted():
		combat_state.draw_actions_used_this_turn += 1
		if settlement_window != null:
			settlement_window.open()
	return {
		"accepted": draw_result.is_accepted(),
		"status": draw_result.status,
		"events": events,
		"data": draw_result.to_dictionary(),
	}

func validate_end_turn() -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	return validate_enemy_intent()

func validate_enemy_intent() -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	if combat_resolver == null:
		return CommandValidationScript.new(false, "COMBAT_RESOLVER_NOT_READY", "The CombatResolver is not ready.")
	if combat_state.intent_graph == null or not combat_state.intent_graph.validation().is_valid():
		return CommandValidationScript.new(false, "INVALID_INTENT_GRAPH", "The enemy Intent Graph is invalid.", _intent_graph_issues())
	return CommandValidationScript.new(true)

func execute_end_turn() -> Dictionary:
	var before_recovery: Dictionary = recovery_state.to_dictionary() if recovery_state != null else {}
	var events: Array = []
	var recovery_ended := false
	if recovery_state != null and recovery_state.is_recovering():
		events.append(DomainEventScript.new(DomainEventScript.RECOVERY_TURN_ELAPSED, {
			"turns_elapsed": recovery_state.turns_elapsed + 1,
			"hand_size": zones.size(TileZoneScript.HAND),
		}))
		if recovery_state.advance_turn(zones.size(TileZoneScript.HAND)):
			recovery_ended = true
			events.append(DomainEventScript.new(DomainEventScript.RECOVERY_ENDED, {
				"turns_elapsed": recovery_state.turns_elapsed,
				"hand_size": zones.size(TileZoneScript.HAND),
				"normal_hand_baseline": recovery_state.normal_hand_baseline,
			}))
	var intent_result = resolve_enemy_intent()
	if not bool(intent_result.get("accepted", false)):
		_restore_recovery_state(before_recovery)
		return {
			"accepted": false,
			"status": str(intent_result.get("status", "INTENT_RESOLUTION_REJECTED")),
			"message": "The enemy Intent could not be resolved.",
			"events": [],
			"data": {"intent": intent_result},
		}
	events.append_array(intent_result.events)
	if intent_result.get("accepted", false):
		combat_state.draw_actions_used_this_turn = 0
	return {
		"accepted": true,
		"status": "RECOVERY_ENDED" if recovery_ended else "TURN_ENDED",
		"events": events,
		"data": {"recovery": recovery_state.to_dictionary(), "intent": intent_result},
	}

func validate_store_tile(instance_id: String) -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	if tile_actions == null or zones == null or not zones.contains_in_zone(instance_id, TileZoneScript.HAND):
		return CommandValidationScript.new(false, ReserveActionResultScript.INVALID_TILE, "The selected TileInstance is not in Hand.")
	if zones.size(TileZoneScript.RESERVE) >= combat_state.reserve_capacity:
		return CommandValidationScript.new(false, ReserveActionResultScript.RESERVE_CAPACITY_REACHED, "Reserve is full.")
	return CommandValidationScript.new(true)

func execute_store_tile(instance_id: String) -> Dictionary:
	var result = tile_actions.store_to_reserve(instance_id)
	return {"accepted": result.is_accepted(), "status": result.status, "events": result.events}

func validate_swap_reserve_tiles(hand_instance_id: String, reserve_instance_id: String) -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	if zones == null or not zones.contains_in_zone(hand_instance_id, TileZoneScript.HAND):
		return CommandValidationScript.new(false, ReserveActionResultScript.INVALID_TILE, "The selected Hand TileInstance is invalid.")
	if not zones.contains_in_zone(reserve_instance_id, TileZoneScript.RESERVE):
		return CommandValidationScript.new(false, ReserveActionResultScript.INVALID_RESERVE_TILE, "The selected Reserve TileInstance is invalid.")
	return CommandValidationScript.new(true)

func execute_swap_reserve_tiles(hand_instance_id: String, reserve_instance_id: String) -> Dictionary:
	var result = tile_actions.swap_with_reserve(hand_instance_id, reserve_instance_id)
	return {"accepted": result.is_accepted(), "status": result.status, "events": result.events}

func can_settle() -> bool:
	if settlement_window != null and settlement_window.is_open():
		settlement_window.refresh()
	return (
		combat_state != null
		and combat_state.is_active()
		and settlement_window != null
		and settlement_window.has_capacity()
		and not settlement_window.candidates().is_empty()
	)

func validate_settlement(selected_instance_ids: Array) -> RefCounted:
	if settlement_window != null and settlement_window.is_open():
		settlement_window.refresh()
	if not can_settle():
		return CommandValidationScript.new(
			false,
			"SETTLEMENT_UNAVAILABLE",
			"No highlighted Pattern can be settled.",
		)
	var selection_result = settlement_window.validate(selected_instance_ids)
	if selection_result == null or not selection_result.is_accepted():
		return CommandValidationScript.new(
			false,
			"SETTLEMENT_REJECTED",
			"The selected Pattern was rejected.",
			{"reason": selection_result.status if selection_result != null else "INVALID_SELECTION"},
		)
	var effect_validation := _validate_tile_modifier_effects(selected_instance_ids)
	if not effect_validation.is_valid():
		return effect_validation
	return CommandValidationScript.new(true)

func validate_settlement_candidate(candidate_id: String) -> RefCounted:
	if not can_settle():
		return CommandValidationScript.new(
			false,
			"SETTLEMENT_UNAVAILABLE",
			"No highlighted Pattern can be settled.",
		)
	var selection_result = settlement_window.validate_candidate(candidate_id)
	if selection_result == null or not selection_result.is_accepted():
		return CommandValidationScript.new(
			false,
			"SETTLEMENT_REJECTED",
			"The selected Pattern was rejected.",
			{"reason": selection_result.status if selection_result != null else "INVALID_SELECTION"},
		)
	var effect_validation := _validate_tile_modifier_effects(_tile_instance_ids_for_candidate(candidate_id))
	if not effect_validation.is_valid():
		return effect_validation
	return CommandValidationScript.new(true)

func complete_hand_interpretations() -> Array:
	if complete_hand_evaluator == null or zones == null:
		return []
	return complete_hand_evaluator.evaluate(zones.contents(TileZoneScript.HAND))

func can_complete_hand() -> bool:
	return combat_state != null and combat_state.is_active() and recovery_state != null and recovery_state.can_complete_hand() and not complete_hand_interpretations().is_empty()

func is_recovering() -> bool:
	return recovery_state != null and recovery_state.is_recovering()

func validate_complete_hand(interpretation_id: String) -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	if recovery_state != null and recovery_state.is_recovering():
		return CommandValidationScript.new(false, "RECOVERY_LOCKED", "Complete Hand is unavailable during Recovery.")
	var interpretation = _complete_hand_by_id(interpretation_id)
	if interpretation == null:
		return CommandValidationScript.new(false, "INVALID_INTERPRETATION", "The selected Complete Hand interpretation is not available.")
	if not _valid_complete_hand_destination():
		return CommandValidationScript.new(false, "INVALID_DESTINATION", "The Complete Hand destination policy is invalid.")
	var settled_ids: Array[String] = []
	for tile_instance in interpretation.tile_instances:
		settled_ids.append(tile_instance.instance_id)
	var effect_validation := _validate_tile_modifier_effects(settled_ids)
	if not effect_validation.is_valid():
		return effect_validation
	return CommandValidationScript.new(true)

func execute_complete_hand(interpretation_id: String) -> Dictionary:
	var transaction := _capture_build_effect_transaction()
	var interpretation = _complete_hand_by_id(interpretation_id)
	if interpretation == null:
		return {"accepted": false, "status": CompleteHandSettlementResultScript.INVALID_INTERPRETATION}
	var settled_ids: Array[String] = []
	for tile_instance in interpretation.tile_instances:
		if not zones.contains_in_zone(tile_instance.instance_id, TileZoneScript.HAND):
			return {"accepted": false, "status": CompleteHandSettlementResultScript.TRANSFER_FAILED}
	for tile_instance in interpretation.tile_instances:
		if not zones.transfer(tile_instance.instance_id, TileZoneScript.HAND, complete_hand_destination):
			for moved_id in settled_ids:
				zones.transfer(moved_id, complete_hand_destination, TileZoneScript.HAND)
			return {"accepted": false, "status": CompleteHandSettlementResultScript.TRANSFER_FAILED}
		settled_ids.append(tile_instance.instance_id)
	var build_effect_result: Dictionary = settlement_turn.resolve_tile_modifier_effects(settled_ids)
	if not build_effect_result.get("accepted", false):
		_restore_build_effect_transaction(transaction)
		return {"accepted": false, "status": "BUILD_EFFECT_REJECTED", "message": "A Tile Modifier effect was rejected during Complete Hand resolution."}

	var score_result = score_resolver.resolve_complete_hand(interpretation, hand_yaku_resolver, _yaku_state()) if score_resolver != null and score_resolver.has_method("resolve_complete_hand") else score_resolver.resolve(interpretation)
	var combat_output = conversion_resolver.resolve(score_result, _complete_hand_conversion_profile, combat_state.to_dictionary())
	var combat_result = combat_resolver.resolve_combat_conversion(combat_state, combat_output)
	var pattern_types: Array[String] = []
	for group in interpretation.groups:
		if group != null and not pattern_types.has(str(group.pattern_type)):
			pattern_types.append(str(group.pattern_type))
	var events: Array = [DomainEventScript.new(DomainEventScript.COMPLETE_HAND_SETTLED, {
		"interpretation_id": interpretation.interpretation_id,
		"hand_type": interpretation.hand_type,
		"pattern_types": pattern_types,
		"instance_ids": settled_ids,
		"destination": complete_hand_destination,
		"score": score_result.total,
	})]
	events.append_array(build_effect_result.get("events", []))
	events.append_array(combat_result.events)
	var recovery_baseline: int = recovery_state.recovery_baseline
	events.append(DomainEventScript.new(DomainEventScript.COMPLETE_HAND_REBUILD_STARTED, {
		"requested": maxi(0, recovery_baseline - zones.size(TileZoneScript.HAND)),
		"source": DrawSourceScript.COMPLETE_HAND_REBUILD,
		"recovery_baseline": recovery_baseline,
	}))
	var rebuild_draws: Array = []
	while zones.size(TileZoneScript.HAND) < recovery_baseline:
		var draw_result = tile_actions.draw(DrawSourceScript.COMPLETE_HAND_REBUILD)
		rebuild_draws.append(draw_result)
		events.append_array(draw_result.events)
		if draw_result.shortfall > 0:
			break
	recovery_state.start()
	events.append(DomainEventScript.new(DomainEventScript.RECOVERY_STARTED, recovery_state.to_dictionary()))
	var result_status := CompleteHandSettlementResultScript.COMPLETED
	if zones.size(TileZoneScript.HAND) < recovery_baseline:
		result_status = CompleteHandSettlementResultScript.REBUILD_SHORTFALL
	var settlement_result := CompleteHandSettlementResultScript.new(
		result_status,
		interpretation,
		score_result,
		combat_output,
		settled_ids,
		rebuild_draws,
		events,
		recovery_state.to_dictionary(),
	)
	return {
		"accepted": settlement_result.is_accepted(),
		"status": settlement_result.status,
		"events": settlement_result.events,
		"data": settlement_result.to_dictionary(),
	}

func execute_settlement(selected_instance_ids: Array) -> Dictionary:
	var transaction := _capture_build_effect_transaction()
	var turn_result = settlement_turn.resolve_partial_settlement(selected_instance_ids)
	return _execute_settlement_result(turn_result, transaction)

func execute_settlement_candidate(candidate_id: String) -> Dictionary:
	var transaction := _capture_build_effect_transaction()
	var turn_result = settlement_turn.resolve_partial_settlement_candidate(candidate_id)
	return _execute_settlement_result(turn_result, transaction)

func _execute_settlement_result(turn_result, transaction: Dictionary = {}) -> Dictionary:
	if turn_result != null and turn_result.status == "BUILD_EFFECT_REJECTED":
		if not _restore_build_effect_transaction(transaction):
			push_error("Tile Modifier effect rejection could not restore its battle, Run, and RNG checkpoint.")
			return {"accepted": false, "status": "BUILD_EFFECT_ROLLBACK_FAILED", "message": "The failed Tile Modifier effect could not be rolled back."}
		return {"accepted": false, "status": "BUILD_EFFECT_REJECTED", "message": "A Tile Modifier effect was rejected during settlement resolution."}
	var settlement_result = turn_result.settlement_result
	if settlement_result == null or not settlement_result.is_accepted():
		return {
			"accepted": false,
			"status": "SETTLEMENT_REJECTED",
			"message": "The selected Pattern was rejected.",
		}

	var events: Array = turn_result.events

	var score_result = score_resolver.resolve(settlement_result.settled_pattern, local_yaku_resolver, _yaku_state())
	var combat_output = conversion_resolver.resolve(score_result, conversion_profile, combat_state.to_dictionary())
	var combat_result = combat_resolver.resolve_combat_conversion(combat_state, combat_output)
	events.append_array(combat_result.events)
	return {
		"accepted": true,
		"status": turn_result.status,
		"events": events,
		"data": {
			"settlement": turn_result.to_dictionary(),
			"score": score_result.to_dictionary(),
			"combat_output": combat_output.to_dictionary(),
		},
	}

func _validate_tile_modifier_effects(instance_ids: Array) -> RefCounted:
	if settlement_turn == null or not settlement_turn.has_method("validate_tile_modifier_effects"):
		return CommandValidationScript.new(true)
	var validation: Dictionary = settlement_turn.validate_tile_modifier_effects(instance_ids)
	if validation.get("accepted", false):
		return CommandValidationScript.new(true)
	return CommandValidationScript.new(
		false,
		"BUILD_EFFECT_REJECTED",
		"A Tile Modifier effect cannot resolve for the selected TileInstances.",
		{"effect_id": str(validation.get("effect_id", "")), "reason": str(validation.get("reason", "BUILD_EFFECT_REJECTED"))},
	)

func _tile_instance_ids_for_candidate(candidate_id: String) -> Array[String]:
	var ids: Array[String] = []
	if settlement_window == null:
		return ids
	for candidate in settlement_window.candidates():
		if candidate != null and candidate.candidate_id == candidate_id:
			for tile_instance in candidate.tile_instances:
				ids.append(tile_instance.instance_id)
			return ids
	return ids

func _capture_build_effect_transaction() -> Dictionary:
	var run_state = context.run_state if context != null else null
	return {
		"battle": _capture_battle_transaction(),
		"run_state": build_effect_resolver.capture_run_state(run_state) if build_effect_resolver != null and run_state != null else {},
		"settlement_turn": settlement_turn.transaction_snapshot() if settlement_turn != null and settlement_turn.has_method("transaction_snapshot") else {},
	}

func _restore_build_effect_transaction(snapshot: Dictionary) -> bool:
	if not snapshot.has("battle") or not _restore_battle_transaction(snapshot.get("battle", {})):
		return false
	var run_state = context.run_state if context != null else null
	if build_effect_resolver != null and run_state != null:
		if not build_effect_resolver.restore_run_state(run_state, snapshot.get("run_state", {})):
			return false
	if settlement_turn != null and settlement_turn.has_method("restore_transaction_snapshot"):
		settlement_turn.restore_transaction_snapshot(snapshot.get("settlement_turn", {}))
	return true

func resolve_enemy_intent():
	if combat_resolver == null:
		return {"accepted": false, "status": "COMBAT_RESOLVER_NOT_READY", "events": []}
	var before_state: Dictionary = _capture_battle_transaction()
	var result = combat_resolver.resolve_enemy_intent(combat_state)
	var events: Array = result.events.duplicate()
	if not result.is_resolved():
		if not _restore_battle_transaction(before_state):
			push_error("Enemy Intent rejection could not restore its battle and RNG checkpoint.")
			return {
				"accepted": false,
				"status": "INTENT_ROLLBACK_FAILED",
				"events": events,
				"data": result.to_dictionary(),
			}
		return {"accepted": false, "status": result.status, "events": events, "data": result.to_dictionary()}
	if result.is_resolved() and reserve_service != null and combat_state.is_active():
		events.append_array(reserve_service.natural_decay())
	return {"accepted": result.is_resolved(), "status": result.status, "events": events, "data": result.to_dictionary()}

func execute_enemy_intent() -> Dictionary:
	return resolve_enemy_intent()

func end_battle(preserve_run_level: bool = false, preserved_instance_ids: Array = []) -> Array:
	if _battle_end_cleaned:
		return []
	if combat_state != null and combat_state.is_active():
		return []
	var events: Array = []
	if contamination_service != null:
		events.append_array(contamination_service.cleanup_battle())
	if reserve_service != null:
		events.append_array(reserve_service.end_battle(preserve_run_level, preserved_instance_ids))
	_battle_end_cleaned = true
	if combat_state != null:
		combat_state.battle_end_cleanup_done = true
	return events

func checkpoint() -> Dictionary:
	var zone_checkpoint: Dictionary = {}
	if zones != null:
		for zone in TileZoneScript.all():
			zone_checkpoint[zone] = _tile_ids(zones.contents(zone))
		zone_checkpoint[TileZoneScript.PURGED] = _tile_ids(zones.contents(TileZoneScript.PURGED))
	var candidate_checkpoint: Array = []
	if settlement_window != null:
		for candidate in settlement_window.candidates():
			candidate_checkpoint.append(_tile_ids(candidate.tile_instances))
	return {
		"schema_version": 2,
		"zones": zone_checkpoint,
		"draw_wall": _tile_ids(draw_wall.contents()) if draw_wall != null else [],
		"reserve": _tile_ids(zones.contents(TileZoneScript.RESERVE)) if zones != null else [],
		"integrity": _integrity_snapshot(),
		"combat_state": combat_state.to_dictionary() if combat_state != null else {},
		"settlement": {
			"submitted": settlement_turn != null and not settlement_turn.settled_instance_ids().is_empty(),
			"window_open": settlement_window.is_open() if settlement_window != null else false,
			"candidates": candidate_checkpoint,
			"settled_instance_ids": settlement_turn.settled_instance_ids() if settlement_turn != null else [],
			"capacity": settlement_window.settlement_capacity().to_dictionary() if settlement_window != null else {},
		},
		"complete_hand": {
			"interpretations": _interpretation_checkpoints(),
			"destination": complete_hand_destination,
		},
		"recovery": recovery_state.to_dictionary() if recovery_state != null else {},
		"tile_instances": _tile_checkpoints(),
	}

func rng_snapshot() -> Dictionary:
	if _rng_streams != null and _rng_streams.has_method("snapshot"):
		return _rng_streams.snapshot()
	var streams := {}
	if draw_wall != null and draw_wall.has_method("rng_snapshot"):
		streams["draw_wall"] = draw_wall.rng_snapshot()
	if combat_state != null and combat_state.intent_rng != null and combat_state.intent_rng.has_method("snapshot"):
		streams["enemy"] = combat_state.intent_rng.snapshot()
	return {"version": 1, "streams": streams}

func _capture_battle_transaction() -> Dictionary:
	return {
		"checkpoint": checkpoint(),
		"rng": rng_snapshot(),
		"next_sequence_index": combat_state._next_sequence_index if combat_state != null else 0,
	}

func _restore_battle_transaction(snapshot: Dictionary) -> bool:
	var checkpoint_snapshot: Variant = snapshot.get("checkpoint", null)
	var rng_state: Variant = snapshot.get("rng", null)
	if not checkpoint_snapshot is Dictionary or not rng_state is Dictionary:
		return false
	var checkpoint_restored := restore_checkpoint(checkpoint_snapshot)
	if not checkpoint_restored:
		var combat_checkpoint: Variant = checkpoint_snapshot.get("combat_state", null)
		var recovery_checkpoint: Variant = checkpoint_snapshot.get("recovery", null)
		if combat_checkpoint is Dictionary and recovery_checkpoint is Dictionary:
			checkpoint_restored = _restore_combat_checkpoint(combat_checkpoint) and _restore_recovery_state(recovery_checkpoint)
	var rng_restored := _restore_rng_snapshot(rng_state)
	if combat_state != null:
		combat_state._next_sequence_index = int(snapshot.get("next_sequence_index", combat_state._next_sequence_index))
	return checkpoint_restored and rng_restored

func _restore_recovery_state(snapshot: Dictionary) -> bool:
	if not snapshot is Dictionary:
		return false
	if recovery_state == null:
		return snapshot.is_empty()
	recovery_state.normal_hand_baseline = int(snapshot.get("normal_hand_baseline", recovery_state.normal_hand_baseline))
	recovery_state.recovery_baseline = int(snapshot.get("recovery_baseline", recovery_state.recovery_baseline))
	recovery_state.minimum_recovery_turns = int(snapshot.get("minimum_recovery_turns", recovery_state.minimum_recovery_turns))
	recovery_state.turns_elapsed = int(snapshot.get("turns_elapsed", 0))
	recovery_state.active = bool(snapshot.get("active", false))
	return true

func _restore_rng_snapshot(snapshot: Dictionary) -> bool:
	if _rng_streams != null and _rng_streams.has_method("restore"):
		return _rng_streams.restore(snapshot)
	var stream_snapshots: Variant = snapshot.get("streams", null)
	if not stream_snapshots is Dictionary:
		return false
	if stream_snapshots.has("draw_wall"):
		var draw_wall_rng = draw_wall.get("_draw_wall_rng") if draw_wall != null else null
		if draw_wall_rng == null or not draw_wall_rng.has_method("restore") or not draw_wall_rng.restore(stream_snapshots["draw_wall"]):
			return false
	if stream_snapshots.has("enemy"):
		if combat_state == null or combat_state.intent_rng == null or not combat_state.intent_rng.has_method("restore"):
			return false
		if not combat_state.intent_rng.restore(stream_snapshots["enemy"]):
			return false
	return rng_snapshot() == snapshot

func restore_checkpoint(snapshot: Dictionary) -> bool:
	if int(snapshot.get("schema_version", -1)) != 2:
		return false
	var tile_checkpoints = snapshot.get("tile_instances", [])
	var combat_checkpoint = snapshot.get("combat_state", {})
	if not tile_checkpoints is Array or not combat_checkpoint is Dictionary:
		return false
	if zones == null or not zones.has_method("clear"):
		return false
	var settled_instance_ids = snapshot.get("settlement", {}).get("settled_instance_ids", []) if snapshot.get("settlement", {}) is Dictionary else null
	if not settled_instance_ids is Array:
		return false
	var requested_reserve_capacity := int(combat_checkpoint.get("reserve_capacity", zones.reserve_capacity))
	zones.clear()
	if not zones.set_reserve_capacity(requested_reserve_capacity):
		return false
	var restored_ids: Dictionary = {}
	for tile_data in tile_checkpoints:
		if not tile_data is Dictionary:
			return false
		var instance_id := str(tile_data.get("instance_id", ""))
		var zone := str(tile_data.get("zone", ""))
		if instance_id.is_empty() or restored_ids.has(instance_id) or not TileZoneScript.is_valid(zone):
			return false
		var tile = TileInstanceScript.from_checkpoint(tile_data)
		if tile == null or not zones.add(tile, zone):
			return false
		restored_ids[instance_id] = true
	var zone_checkpoints = snapshot.get("zones", null)
	if not _restore_zone_orders(zone_checkpoints):
		return false
	if not _restore_combat_checkpoint(combat_checkpoint):
		return false
	if not _restore_settlement_checkpoint(snapshot.get("settlement", {})):
		return false
	var complete_hand = snapshot.get("complete_hand", {})
	if not complete_hand is Dictionary:
		return false
	complete_hand_destination = str(complete_hand.get("destination", complete_hand_destination))
	if not _valid_complete_hand_destination():
		return false
	var recovery = snapshot.get("recovery", {})
	if not _restore_recovery_state(recovery):
		return false
	return true

func _restore_zone_orders(zone_checkpoints) -> bool:
	if not zone_checkpoints is Dictionary:
		return false
	var expected_zones: Array[String] = TileZoneScript.all()
	expected_zones.append(TileZoneScript.PURGED)
	if zone_checkpoints.size() != expected_zones.size():
		return false
	for zone in zone_checkpoints.keys():
		if not expected_zones.has(str(zone)):
			return false
	for zone in expected_zones:
		if not zone_checkpoints.has(zone) or not zone_checkpoints[zone] is Array:
			return false
		var ordered_instance_ids: Array[String] = []
		var seen_ids: Dictionary = {}
		for serialized_id in zone_checkpoints[zone]:
			if typeof(serialized_id) != TYPE_STRING or str(serialized_id).is_empty() or seen_ids.has(serialized_id):
				return false
			if not zones.contains_in_zone(str(serialized_id), zone):
				return false
			seen_ids[serialized_id] = true
			ordered_instance_ids.append(str(serialized_id))
		if not zones.reorder(zone, ordered_instance_ids):
			return false
	return true

func _restore_combat_checkpoint(snapshot: Dictionary) -> bool:
	if combat_state == null:
		return false
	for field in [
		"enemy_hp", "enemy_max_hp", "pressure", "pressure_limit", "fatigue", "starvation_count",
		"starvation_active", "intent_index", "boss_phase_index", "boss_phase_id", "boss_phase_count",
		"pending_death", "pending_defeat", "pending_death_sequence_index", "pending_defeat_sequence_index",
		"terminal_sequence_index", "terminal_outcome", "queue_index", "state_based_check_count", "tp",
		"stability", "draw_capacity", "draw_actions_used_this_turn", "settlement_capacity", "reserve_capacity", "battle_end_cleanup_done",
	]:
		if snapshot.has(field):
			combat_state.set(field, snapshot[field])
	var triggered_passives: Variant = snapshot.get("triggered_signature_passive_ids", [])
	if not triggered_passives is Array:
		return false
	combat_state.triggered_signature_passive_ids.clear()
	for passive_id in triggered_passives:
		if not passive_id is String or str(passive_id).is_empty():
			return false
		combat_state.triggered_signature_passive_ids.append(str(passive_id))
	if combat_state.intent_rng != null and snapshot.get("intent_rng", {}) is Dictionary:
		if not combat_state.intent_rng.restore(snapshot.get("intent_rng", {})):
			return false
	var graph = combat_state.intent_graph
	var phase_index := int(snapshot.get("boss_phase_index", -1))
	if phase_index >= 0 and phase_index < combat_state.boss_phases.size():
		graph = combat_state.boss_phases[phase_index].get("intent_graph")
	if graph == null:
		return false
	combat_state.intent_graph = graph
	var intent_data = snapshot.get("current_intent", {})
	if not intent_data is Dictionary:
		return false
	var current_intent_id := str(intent_data.get("intent_id", ""))
	combat_state.current_intent = graph.intent(current_intent_id)
	if combat_state.current_intent == null:
		return false
	var active_effect_details = snapshot.get("active_effect_details", [])
	if not active_effect_details is Array:
		return false
	combat_state.active_effects = _effects_from_checkpoint(active_effect_details)
	return true

func _restore_settlement_checkpoint(snapshot: Dictionary) -> bool:
	if not snapshot is Dictionary or settlement_window == null or settlement_turn == null:
		return false
	var capacity_data = snapshot.get("capacity", {})
	if not capacity_data is Dictionary:
		return false
	var settled_instance_ids = snapshot.get("settled_instance_ids", [])
	if not settled_instance_ids is Array:
		return false
	settlement_window.close()
	settlement_window.set_settlement_capacity(SettlementCapacityScript.new(capacity_data))
	settlement_turn._settled_instance_ids = {}
	for instance_id in snapshot.get("settled_instance_ids", []):
		settlement_turn._settled_instance_ids[str(instance_id)] = true
	if bool(snapshot.get("window_open", false)) and not settlement_window.open():
		return false
	settlement_window.settlement_capacity()._remaining = int(capacity_data.get("remaining", settlement_window.settlement_capacity().maximum))
	for instance_id in snapshot.get("settled_instance_ids", []):
		settlement_window._settled_instance_ids[str(instance_id)] = true
	if bool(snapshot.get("window_open", false)):
		settlement_window.refresh()
	return true

func _effects_from_checkpoint(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		if not value is Dictionary:
			return {}
		var duration: Dictionary = value.get("duration", {})
		var effect := ActiveEffectInstanceScript.new(
			str(value.get("definition_id", "")),
			DurationSpecScript.new(str(duration.get("scope", DurationSpecScript.PERMANENT)), int(duration.get("remaining", 0))),
			StackPolicyScript.new(str(value.get("stack_policy", StackPolicyScript.REPLACE)), int(value.get("max_stacks", 0))),
			str(value.get("source_id", "")), int(value.get("stacks", 1)), int(value.get("uses_remaining", -1)),
			int(value.get("charges_remaining", -1)), str(value.get("instance_id", "")), int(value.get("max_stacks", 0)), value.get("runtime_parameters", {})
		)
		result[effect.instance_id] = effect
	return result

func _complete_hand_by_id(interpretation_id: String):
	for interpretation in complete_hand_interpretations():
		if interpretation is CompleteHandInterpretationScript and interpretation.interpretation_id == interpretation_id:
			return interpretation
	return null

func _valid_complete_hand_destination() -> bool:
	return [TileZoneScript.DISCARD, TileZoneScript.EXHAUST, TileZoneScript.DRAW_WALL].has(complete_hand_destination)

func _interpretation_checkpoints() -> Array:
	var result: Array = []
	for interpretation in complete_hand_interpretations():
		result.append(interpretation.to_dictionary())
	return result

func _intent_graph_issues() -> Dictionary:
	return {"issues": combat_state.intent_graph.validation_issues() if combat_state != null and combat_state.intent_graph != null else []}

func _build_complete_hand_conversion_profile():
	if conversion_profile is CombatConversionProfileScript:
		var config: Dictionary = conversion_profile.to_dictionary()
		var stability_curve: Dictionary = config.get("stability_curve", {}).duplicate(true)
		if float(stability_curve.get("multiplier", 0.0)) <= 0.0:
			stability_curve["multiplier"] = 0.5
		config["stability_curve"] = stability_curve
		config["id"] = "%s.complete_hand" % conversion_profile.profile_id
		return CombatConversionProfileScript.new(config)
	return CombatConversionProfileScript.new({
		"id": "combat_conversion.complete_hand",
		"damage_curve": {"mode": "linear", "multiplier": 1.0},
		"stability_curve": {"mode": "linear", "multiplier": 0.5},
	})

func _tile_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile_instance in tiles:
		ids.append(tile_instance.instance_id)
	return ids

func _integrity_snapshot() -> Array:
	var snapshot: Array = []
	if zones == null:
		return snapshot
	for zone in TileZoneScript.all():
		for tile_instance in zones.contents(zone):
			if tile_instance.integrity_initialized():
				snapshot.append({"instance_id": tile_instance.instance_id, "integrity": tile_instance.integrity, "max_integrity": tile_instance.max_integrity})
	snapshot.sort_custom(func(left, right): return left.instance_id < right.instance_id)
	return snapshot

func _tile_checkpoints() -> Array:
	var result: Array = []
	if zones == null:
		return result
	var zones_to_snapshot: Array = TileZoneScript.all()
	zones_to_snapshot.append(TileZoneScript.PURGED)
	for zone in zones_to_snapshot:
		for tile_instance in zones.contents(zone):
			if tile_instance == null or not tile_instance.has_method("to_dictionary"):
				continue
			var tile_data: Dictionary = tile_instance.to_dictionary()
			tile_data["zone"] = zone
			result.append(tile_data)
	result.sort_custom(func(left, right): return left.get("instance_id", "") < right.get("instance_id", ""))
	return result

func _yaku_state() -> Dictionary:
	return {
		"hand": zones.contents(TileZoneScript.HAND) if zones != null else [],
		"reserve": zones.contents(TileZoneScript.RESERVE) if zones != null else [],
	}
