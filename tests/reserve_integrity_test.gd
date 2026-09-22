class_name ReserveIntegrityTest
extends RefCounted

const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const IntegrityCause = preload("res://src/domain/tiles/integrity_cause.gd")
const IntegrityLoss = preload("res://src/domain/tiles/integrity_loss.gd")
const BreakPolicy = preload("res://src/domain/tiles/break_policy.gd")
const TileActionService = preload("res://src/domain/tiles/tile_action_service.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_reserve_has_base_capacity_and_unique_zone_ownership(failures)
	test_draw_action_stores_and_atomically_swaps_tiles(failures)
	test_failed_swap_rolls_back_without_mutation(failures)
	test_swapped_tile_refreshes_same_draw_settlement_checkpoint(failures)
	test_reserve_entry_initializes_integrity_once(failures)
	test_integrity_loss_preserves_structured_cause_and_break_policy(failures)
	test_break_policy_routes_each_zero_integrity_destination(failures)
	test_repair_and_battle_end_runtime_reset(failures)
	test_integrity_events_are_deterministic(failures)
	return failures

func test_reserve_has_base_capacity_and_unique_zone_ownership(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	for index in range(3):
		assert_true(zones.add(TileInstance.new("run.reserve.capacity.%d" % index, "base.tile.man.%d" % (index + 1)), TileZone.RESERVE), "Reserve accepts its base capacity", failures)
	var fourth := TileInstance.new("run.reserve.capacity.overflow", "base.tile.man.4")
	assert_true(not zones.add(fourth, TileZone.RESERVE), "Reserve rejects a fourth tile at base capacity", failures)
	assert_true(zones.size(TileZone.RESERVE) == 3, "Reserve capacity rejection is atomic", failures)
	assert_true(zones.zone_of("run.reserve.capacity.0") == TileZone.RESERVE, "a TileInstance has one authoritative zone", failures)
	assert_true(zones.add(fourth, TileZone.HAND), "the same rejected instance can be accepted in another zone", failures)
	assert_true(zones.transfer("run.reserve.capacity.0", TileZone.RESERVE, TileZone.HAND), "a Reserve tile can leave Reserve", failures)
	assert_true(zones.transfer(fourth.instance_id, TileZone.HAND, TileZone.RESERVE), "leaving Reserve frees a bounded slot", failures)
	assert_true(zones.zone_of(fourth.instance_id) == TileZone.RESERVE, "stable tile identity survives Reserve re-entry", failures)

func test_draw_action_stores_and_atomically_swaps_tiles(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var hand_tile := TileInstance.new("run.reserve.action.hand", "base.tile.man.1")
	var second_hand_tile := TileInstance.new("run.reserve.action.hand.2", "base.tile.man.2")
	var reserve_tile := TileInstance.new("run.reserve.action.reserve", "base.tile.man.9")
	zones.add(hand_tile, TileZone.HAND)
	zones.add(second_hand_tile, TileZone.HAND)
	zones.add(reserve_tile, TileZone.RESERVE)
	var actions := TileActionService.new(null, zones)

	var store_result = actions.store_to_reserve(hand_tile.instance_id)
	assert_true(store_result.is_accepted(), "a Draw Action can store a Hand tile in Reserve", failures)
	assert_true(zones.contains_in_zone(hand_tile.instance_id, TileZone.RESERVE), "store transfers the stable Hand TileInstance", failures)
	var swap_result = actions.swap_with_reserve(second_hand_tile.instance_id, reserve_tile.instance_id)
	assert_true(swap_result.is_accepted(), "a Draw Action can atomically swap Hand and Reserve", failures)
	assert_true(zones.contains_in_zone(second_hand_tile.instance_id, TileZone.RESERVE), "the outgoing Hand tile enters Reserve", failures)
	assert_true(zones.contains_in_zone(reserve_tile.instance_id, TileZone.HAND), "the swapped-in tile is immediately usable in Hand", failures)
	assert_true(second_hand_tile.integrity_initialized(), "an atomic swap initializes the tile entering Reserve", failures)
	assert_true(swap_result.events.size() == 1 and swap_result.events[0].event_type == DomainEvent.RESERVE_SWAPPED, "the swap emits one deterministic domain event", failures)

func test_failed_swap_rolls_back_without_mutation(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var hand_tile := TileInstance.new("run.reserve.rollback.hand", "base.tile.man.1")
	zones.add(hand_tile, TileZone.HAND)
	var actions := TileActionService.new(null, zones)
	var result = actions.swap_with_reserve(hand_tile.instance_id, "run.reserve.rollback.missing")
	assert_true(not result.is_accepted(), "a swap with a missing Reserve tile is rejected", failures)
	assert_true(zones.contains_in_zone(hand_tile.instance_id, TileZone.HAND), "a rejected swap leaves Hand unchanged", failures)
	assert_true(zones.size(TileZone.RESERVE) == 0, "a rejected swap leaves Reserve unchanged", failures)
	assert_true(result.events.is_empty(), "a rejected swap emits no mutation event", failures)

func test_swapped_tile_refreshes_same_draw_settlement_checkpoint(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var first := TileInstance.new("run.reserve.checkpoint.1", "base.tile.characters.1")
	var second := TileInstance.new("run.reserve.checkpoint.2", "base.tile.characters.2")
	var outgoing := TileInstance.new("run.reserve.checkpoint.out", "base.tile.characters.9")
	var incoming := TileInstance.new("run.reserve.checkpoint.in", "base.tile.characters.3")
	zones.add(first, TileZone.HAND)
	zones.add(second, TileZone.HAND)
	zones.add(outgoing, TileZone.HAND)
	zones.add(incoming, TileZone.RESERVE)
	var registry = _registry()
	var evaluator = preload("res://src/domain/mahjong/pattern/pattern_evaluator.gd").new(registry)
	var window = preload("res://src/domain/mahjong/settlement/settlement_window.gd").new(evaluator, zones)
	var actions := TileActionService.new(null, zones, window)
	window.open()
	var result = actions.swap_with_reserve(outgoing.instance_id, incoming.instance_id)
	assert_true(result.is_accepted(), "the swap for a Draw Action succeeds", failures)
	assert_true(window.candidates().size() == 1, "the settlement checkpoint sees the swapped-in tile immediately", failures)
	if window.candidates().size() == 1:
		assert_true(_candidate_ids(window.candidates()[0]).has(incoming.instance_id), "the swapped-in TileInstance is selectable in the same action", failures)

func test_reserve_entry_initializes_integrity_once(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var tile := TileInstance.new("run.reserve.integrity.init", "base.tile.man.5")
	zones.add(tile, TileZone.HAND)
	var actions := TileActionService.new(null, zones)
	actions.store_to_reserve(tile.instance_id)
	assert_true(tile.integrity_initialized(), "first Reserve entry initializes runtime Integrity", failures)
	var initial_integrity := tile.integrity
	actions.apply_integrity_loss(tile.instance_id, IntegrityLoss.new(1, IntegrityCause.ACTIVE_MANIPULATION_WEAR))
	zones.transfer(tile.instance_id, TileZone.RESERVE, TileZone.HAND)
	zones.transfer(tile.instance_id, TileZone.HAND, TileZone.RESERVE)
	assert_true(tile.integrity == initial_integrity - 1, "leaving and re-entering Reserve does not refresh Integrity", failures)

func test_integrity_loss_preserves_structured_cause_and_break_policy(failures: Array[String]) -> void:
	var loss := IntegrityLoss.new(2, IntegrityCause.ENEMY_DAMAGE, BreakPolicy.EXHAUST)
	assert_true(loss.amount == 2, "IntegrityLoss carries an amount", failures)
	assert_true(loss.cause == IntegrityCause.ENEMY_DAMAGE, "IntegrityLoss carries a structured cause", failures)
	assert_true(loss.break_policy == BreakPolicy.EXHAUST, "IntegrityLoss carries an explicit BreakPolicy", failures)
	assert_true(loss.to_dictionary()["cause"] == IntegrityCause.ENEMY_DAMAGE, "IntegrityLoss serializes deterministic cause data", failures)

func test_break_policy_routes_each_zero_integrity_destination(failures: Array[String]) -> void:
	assert_true(_break_destination(IntegrityCause.NATURAL_DECAY, BreakPolicy.DISCARD) == TileZone.DISCARD, "natural decay breaks to Discard", failures)
	assert_true(_break_destination(IntegrityCause.ACTIVE_MANIPULATION_WEAR, BreakPolicy.EXHAUST) == TileZone.EXHAUST, "active player wear breaks to Exhaust", failures)
	assert_true(_break_destination(IntegrityCause.ENEMY_DAMAGE, BreakPolicy.DISCARD) == TileZone.DISCARD, "normal enemy damage breaks to Discard", failures)
	assert_true(_break_destination(IntegrityCause.ENEMY_DAMAGE, BreakPolicy.EXHAUST) == TileZone.EXHAUST, "explicit Elite/Boss Exhaust breaks to Exhaust", failures)

func test_repair_and_battle_end_runtime_reset(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var tile := TileInstance.new("run.reserve.integrity.reset", "base.tile.man.5")
	zones.add(tile, TileZone.RESERVE)
	var actions := TileActionService.new(null, zones)
	actions.apply_integrity_loss(tile.instance_id, IntegrityLoss.new(2, IntegrityCause.ENEMY_DAMAGE))
	assert_true(actions.repair_integrity(tile.instance_id, 1).is_accepted(), "explicit repair is accepted", failures)
	assert_true(tile.integrity == tile.max_integrity - 1, "explicit repair restores runtime Integrity without exceeding its maximum", failures)
	actions.end_battle()
	assert_true(not tile.integrity_initialized(), "battle end resets runtime Integrity", failures)
	zones.transfer(tile.instance_id, TileZone.RESERVE, TileZone.HAND)
	actions.store_to_reserve(tile.instance_id)
	actions.apply_integrity_loss(tile.instance_id, IntegrityLoss.new(tile.integrity, IntegrityCause.ACTIVE_MANIPULATION_WEAR))
	actions.end_battle(true)
	assert_true(tile.integrity_initialized(), "an explicit run-level preservation keeps Integrity runtime state", failures)

func test_integrity_events_are_deterministic(failures: Array[String]) -> void:
	var first = _integrity_event_trace(7001)
	var second = _integrity_event_trace(7001)
	assert_true(first == second, "identical integrity commands emit identical event traces", failures)

func _break_destination(cause: String, policy: String) -> String:
	var zones := TileZoneContainer.new()
	var tile := TileInstance.new("run.reserve.break.%s.%s" % [cause, policy], "base.tile.man.5")
	zones.add(tile, TileZone.RESERVE)
	var actions := TileActionService.new(null, zones)
	actions.apply_integrity_loss(tile.instance_id, IntegrityLoss.new(tile.integrity, cause, policy))
	return zones.zone_of(tile.instance_id)

func _integrity_event_trace(seed: int) -> String:
	var zones := TileZoneContainer.new()
	var tile := TileInstance.new("run.reserve.events.%d" % seed, "base.tile.man.5")
	zones.add(tile, TileZone.RESERVE)
	var actions := TileActionService.new(null, zones)
	var result = actions.apply_integrity_loss(tile.instance_id, IntegrityLoss.new(1, IntegrityCause.ENEMY_DAMAGE))
	var serialized: Array = []
	for event in result.events:
		serialized.append(event.to_dictionary())
	return JSON.stringify(serialized)

func _registry():
	var registry = preload("res://src/content/registry/content_registry.gd").new()
	for rank in range(1, 10):
		registry.register(preload("res://src/content/definitions/tile_definition.gd").new(
			"base.tile.characters.%d" % rank,
			"characters",
			rank,
		))
	return registry

func _candidate_ids(candidate) -> Array[String]:
	var ids: Array[String] = []
	for tile_instance in candidate.tile_instances:
		ids.append(tile_instance.instance_id)
	return ids

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
