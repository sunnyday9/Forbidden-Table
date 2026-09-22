class_name EffectFrameworkTest
extends RefCounted

const CombatResolver = preload("res://src/domain/combat/combat_resolver.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const Effect = preload("res://src/domain/effects/effect.gd")
const EffectContext = preload("res://src/domain/effects/effect_context.gd")
const EffectTarget = preload("res://src/domain/effects/effect_target.gd")
const EffectTrigger = preload("res://src/domain/effects/effect_trigger.gd")
const AlwaysCondition = preload("res://src/domain/effects/conditions/always_condition.gd")
const StateCondition = preload("res://src/domain/effects/conditions/state_condition.gd")
const GainTPOperation = preload("res://src/domain/effects/operations/gain_tp_operation.gd")
const DealDamageOperation = preload("res://src/domain/effects/operations/deal_damage_operation.gd")
const GainStabilityOperation = preload("res://src/domain/effects/operations/gain_stability_operation.gd")
const GainPressureOperation = preload("res://src/domain/effects/operations/gain_pressure_operation.gd")
const ModifyDrawCapacityOperation = preload("res://src/domain/effects/operations/modify_draw_capacity_operation.gd")
const ModifySettlementCapacityOperation = preload("res://src/domain/effects/operations/modify_settlement_capacity_operation.gd")
const ModifyReserveCapacityOperation = preload("res://src/domain/effects/operations/modify_reserve_capacity_operation.gd")
const MoveTileOperation = preload("res://src/domain/effects/operations/move_tile_operation.gd")
const DiscardTileOperation = preload("res://src/domain/effects/operations/discard_tile_operation.gd")
const ExhaustTileOperation = preload("res://src/domain/effects/operations/exhaust_tile_operation.gd")
const DrawTileOperation = preload("res://src/domain/effects/operations/draw_tile_operation.gd")
const ApplyEffectOperation = preload("res://src/domain/effects/operations/apply_effect_operation.gd")
const RemoveEffectOperation = preload("res://src/domain/effects/operations/remove_effect_operation.gd")
const AtomicReserveSwapOperation = preload("res://src/domain/effects/operations/atomic_reserve_swap_operation.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")
const DrawWall = preload("res://src/domain/tiles/draw_wall.gd")
const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_typed_effect_resolves_through_queue(failures)
	test_all_numeric_primitives_are_causal_and_deterministic(failures)
	test_tile_primitives_and_draw_are_domain_operations(failures)
	test_apply_and_remove_effect_are_typed_operations(failures)
	test_invalid_condition_and_target_are_atomic(failures)
	test_reserve_swap_and_capacity_are_atomic(failures)
	test_same_seed_and_commands_repeat_effect_result(failures)
	return failures

func test_typed_effect_resolves_through_queue(failures: Array[String]) -> void:
	var state = CombatState.new(10, 10)
	var effect = Effect.new(
		"prototype.damage",
		EffectTrigger.new(EffectTrigger.MANUAL),
		[AlwaysCondition.new()],
		[EffectTarget.new("enemy", EffectTarget.ENEMY)],
		[DealDamageOperation.new(3, "enemy")],
	)
	var queue = CombatResolver.new().begin_queue(state)
	assert_true(queue.enqueue_effect(effect), "a typed Effect enters the resolution queue", failures)
	assert_true(state.enemy_hp == 10, "queued Effects do not mutate before the boundary", failures)
	var result = queue.drain()

	assert_true(result.is_resolved(), "a typed Effect resolves at the queue boundary", failures)
	assert_true(state.enemy_hp == 7, "DealDamage changes domain state", failures)
	assert_true(result.processed_item_count == 1, "the queue counts the typed operation", failures)
	assert_true(_has_event(result.events, DomainEvent.ENEMY_HP_CHANGED), "DealDamage emits a causal DomainEvent", failures)

func test_all_numeric_primitives_are_causal_and_deterministic(failures: Array[String]) -> void:
	var state = CombatState.new(20, 10, 4, [], 2, 1, 3, 1, 2)
	var effect = Effect.new(
		"prototype.resources",
		EffectTrigger.new(EffectTrigger.MANUAL),
		[],
		[],
		[
			GainTPOperation.new(4),
			GainStabilityOperation.new(2),
			GainPressureOperation.new(3),
			ModifyDrawCapacityOperation.new(2),
			ModifySettlementCapacityOperation.new(1),
			ModifyReserveCapacityOperation.new(1),
		],
	)
	var result = CombatResolver.new().resolve_atomic_queue(state, [effect])

	assert_true(result.is_resolved(), "all resource primitives resolve in one queue", failures)
	assert_true(state.tp == 6, "GainTP changes TP", failures)
	assert_true(state.stability == 3, "GainStability changes Stability", failures)
	assert_true(state.pressure == 5, "GainStability then GainPressure has deterministic ordering", failures)
	assert_true(state.draw_capacity == 5, "Draw capacity modification is typed", failures)
	assert_true(state.settlement_capacity == 2, "Settlement capacity modification is typed", failures)
	assert_true(state.reserve_capacity == 3, "Reserve capacity modification is typed", failures)
	assert_true(_has_event(result.events, DomainEvent.TP_CHANGED), "GainTP emits a causal event", failures)
	assert_true(_has_event(result.events, DomainEvent.CAPACITY_CHANGED), "capacity changes emit a causal event", failures)

func test_tile_primitives_and_draw_are_domain_operations(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var hand_tile := TileInstance.new("run.effect.hand", "base.tile.man.1")
	var discard_tile := TileInstance.new("run.effect.discard", "base.tile.man.2")
	var draw_tile := TileInstance.new("run.effect.draw", "base.tile.man.3")
	var second_draw_tile := TileInstance.new("run.effect.draw.second", "base.tile.man.4")
	for tile in [hand_tile, discard_tile, draw_tile, second_draw_tile]:
		zones.add(tile, TileZone.TILE_POOL)
	zones.transfer(hand_tile.instance_id, TileZone.TILE_POOL, TileZone.HAND)
	zones.transfer(discard_tile.instance_id, TileZone.TILE_POOL, TileZone.HAND)
	zones.transfer(draw_tile.instance_id, TileZone.TILE_POOL, TileZone.DRAW_WALL)
	zones.transfer(second_draw_tile.instance_id, TileZone.TILE_POOL, TileZone.DRAW_WALL)
	var wall := DrawWall.new(zones, DomainRngStreams.new(17).draw_wall)
	wall.initialize()
	var context_state = CombatState.new(10, 10)
	var context := EffectContext.new(context_state, zones, wall)
	var effect = Effect.new(
		"prototype.tiles",
		EffectTrigger.new(EffectTrigger.MANUAL),
		[], [],
		[
			MoveTileOperation.new(hand_tile.instance_id, TileZone.HAND, TileZone.RESERVE),
			DiscardTileOperation.new(discard_tile.instance_id),
			DrawTileOperation.new(),
			MoveTileOperation.new(draw_tile.instance_id, TileZone.DRAW_WALL, TileZone.HAND),
			ExhaustTileOperation.new(draw_tile.instance_id),
		],
	)
	var result = CombatResolver.new().resolve_atomic_queue(context_state, [effect], context)

	assert_true(result.is_resolved(), "tile operations resolve without presentation objects", failures)
	assert_true(zones.contains_in_zone(hand_tile.instance_id, TileZone.RESERVE), "MoveTile reaches Reserve", failures)
	assert_true(zones.contains_in_zone(discard_tile.instance_id, TileZone.DISCARD), "DiscardTile reaches Discard", failures)
	assert_true(zones.contains_in_zone(draw_tile.instance_id, TileZone.EXHAUST), "ExhaustTile reaches Exhaust", failures)
	assert_true(zones.size(TileZone.HAND) == 1, "DrawTile transfers one tile into Hand", failures)
	assert_true(_has_event(result.events, DomainEvent.TILE_MOVED), "tile movement emits a causal event", failures)

func test_apply_and_remove_effect_are_typed_operations(failures: Array[String]) -> void:
	var state = CombatState.new(10, 10)
	var apply_result = CombatResolver.new().resolve_atomic_queue(state, [Effect.new(
		"prototype.status.apply", EffectTrigger.new(EffectTrigger.MANUAL), [], [], [ApplyEffectOperation.new("status.focus")]
	)])
	var remove_result = CombatResolver.new().resolve_atomic_queue(state, [Effect.new(
		"prototype.status.remove", EffectTrigger.new(EffectTrigger.MANUAL), [], [], [RemoveEffectOperation.new("status.focus")]
	)])

	assert_true(apply_result.is_resolved() and state.active_effects.is_empty(), "Apply and Remove Effect are queue-resolved operations", failures)
	assert_true(_has_event(apply_result.events, DomainEvent.EFFECT_APPLIED), "ApplyEffect emits a causal event", failures)
	assert_true(_has_event(remove_result.events, DomainEvent.EFFECT_REMOVED), "RemoveEffect emits a causal event", failures)

func test_invalid_condition_and_target_are_atomic(failures: Array[String]) -> void:
	var state = CombatState.new(10, 10, 0, [], 0, 0, 3, 1, 3)
	var conditional_effect = Effect.new(
		"prototype.rejected.condition", EffectTrigger.new(EffectTrigger.MANUAL),
		[StateCondition.new("pressure", StateCondition.GREATER_THAN, 0)], [],
		[GainTPOperation.new(5), DealDamageOperation.new(4)],
	)
	var condition_result = CombatResolver.new().resolve_atomic_queue(state, [conditional_effect])
	assert_true(_has_event(condition_result.events, DomainEvent.EFFECT_REJECTED), "a false condition rejects the Effect", failures)
	assert_true(condition_result.effect_results.size() == 1 and condition_result.effect_results[0].status == "REJECTED_CONDITION", "the queue exposes the rejected condition result", failures)
	assert_true(state.tp == 0 and state.enemy_hp == 10, "a condition rejection has no partial mutation", failures)

	var target_effect = Effect.new(
		"prototype.rejected.target", EffectTrigger.new(EffectTrigger.MANUAL), [],
		[EffectTarget.new("missing", EffectTarget.TILE, "not.present")],
		[GainTPOperation.new(5), DealDamageOperation.new(4, "missing")],
	)
	var target_result = CombatResolver.new().resolve_atomic_queue(state, [target_effect])
	assert_true(_has_event(target_result.events, DomainEvent.EFFECT_REJECTED), "an invalid target rejects the Effect", failures)
	assert_true(state.tp == 0 and state.enemy_hp == 10, "a target rejection has no partial mutation", failures)
	assert_true(_has_event(target_result.events, DomainEvent.EFFECT_REJECTED), "rejection is auditable", failures)
	assert_true(target_result.effect_results.size() == 1 and target_result.effect_results[0].status == "REJECTED_TARGET", "the queue exposes the rejected target result", failures)

func test_reserve_swap_and_capacity_are_atomic(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var hand_tile := TileInstance.new("run.effect.swap.hand", "base.tile.man.4")
	var reserve_tile := TileInstance.new("run.effect.swap.reserve", "base.tile.man.5")
	zones.add(hand_tile, TileZone.HAND)
	zones.add(reserve_tile, TileZone.RESERVE)
	var state = CombatState.new(10, 10, 0, [], 0, 0, 3, 1, 1)
	var context := EffectContext.new(state, zones)
	var result = CombatResolver.new().resolve_atomic_queue(state, [Effect.new(
		"prototype.reserve.swap", EffectTrigger.new(EffectTrigger.MANUAL), [], [],
		[AtomicReserveSwapOperation.new(hand_tile.instance_id, reserve_tile.instance_id)]
	)], context)

	assert_true(result.is_resolved(), "Reserve swap is a domain-level atomic primitive", failures)
	assert_true(zones.contains_in_zone(hand_tile.instance_id, TileZone.RESERVE), "swap moves Hand tile into Reserve", failures)
	assert_true(zones.contains_in_zone(reserve_tile.instance_id, TileZone.HAND), "swap moves Reserve tile into Hand", failures)
	var rejected = CombatResolver.new().resolve_atomic_queue(state, [Effect.new(
		"prototype.reserve.capacity.reject", EffectTrigger.new(EffectTrigger.MANUAL), [], [], [ModifyReserveCapacityOperation.new(-2)]
	)], context)
	assert_true(_has_event(rejected.events, DomainEvent.EFFECT_REJECTED), "capacity cannot invalidate occupied Reserve", failures)
	assert_true(state.reserve_capacity == 1 and zones.size(TileZone.RESERVE) == 1, "invalid capacity leaves Reserve unchanged", failures)

func test_same_seed_and_commands_repeat_effect_result(failures: Array[String]) -> void:
	var first = _run_deterministic_draw(901)
	var second = _run_deterministic_draw(901)
	assert_true(first == second, "same state, content, seed, and Effect commands repeat results", failures)

func _run_deterministic_draw(seed: int) -> String:
	var zones := TileZoneContainer.new()
	for index in range(3):
		zones.add(TileInstance.new("run.effect.deterministic.%d" % index, "base.tile.man.%d" % (index + 1)), TileZone.TILE_POOL)
	var wall := DrawWall.new(zones, DomainRngStreams.new(seed).draw_wall)
	wall.initialize()
	var state = CombatState.new(10, 10)
	var result = CombatResolver.new().resolve_atomic_queue(state, [Effect.new(
		"prototype.deterministic.draw", EffectTrigger.new(EffectTrigger.MANUAL), [], [], [DrawTileOperation.new()]
	)], EffectContext.new(state, zones, wall))
	return JSON.stringify(result.to_dictionary())

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
