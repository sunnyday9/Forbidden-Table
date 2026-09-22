class_name EffectLifecycleTest
extends RefCounted

const CombatResolver = preload("res://src/domain/combat/combat_resolver.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const DurationSpec = preload("res://src/domain/effects/duration_spec.gd")
const Effect = preload("res://src/domain/effects/effect.gd")
const ApplyEffectOperation = preload("res://src/domain/effects/operations/apply_effect_operation.gd")
const LifecycleResolver = preload("res://src/domain/effects/lifecycle_resolver.gd")
const StackPolicy = preload("res://src/domain/effects/stack_policy.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_action_duration_expires_at_queue_boundary(failures)
	test_boundaries_only_expire_matching_scopes(failures)
	test_stack_policies_are_deterministic_and_bounded(failures)
	test_uses_and_charges_are_atomic_and_expire(failures)
	test_repeated_lifecycle_resolution_is_deterministic(failures)
	return failures

func test_action_duration_expires_at_queue_boundary(failures: Array[String]) -> void:
	var state = CombatState.new(10, 10)
	var action_effect = Effect.new(
		"status.action",
		null,
		[],
		[],
		[],
		DurationSpec.new(DurationSpec.ACTION, 1),
		StackPolicy.REPLACE,
	)
	var install_result = CombatResolver.new().resolve_atomic_queue(state, [Effect.new(
		"status.apply",
		null,
		[],
		[],
		[ApplyEffectOperation.new(action_effect)],
	)], null, LifecycleResolver.NO_BOUNDARY)
	assert_true(install_result.is_resolved(), "duration declarations apply through the resolution queue", failures)
	assert_true(state.active_effects.has("status.action"), "an action effect is active before its boundary", failures)

	var boundary_result = CombatResolver.new().resolve_atomic_queue(state, [], null, LifecycleResolver.ACTION)
	assert_true(not state.active_effects.has("status.action"), "an action effect expires at the action boundary", failures)
	assert_true(_has_event(boundary_result.events, DomainEvent.EFFECT_EXPIRED), "expiration emits a deterministic domain event", failures)

func test_boundaries_only_expire_matching_scopes(failures: Array[String]) -> void:
	var state = CombatState.new(10, 10)
	var resolver := LifecycleResolver.new()
	resolver.apply_effect(state, _effect("status.window", DurationSpec.WINDOW, 1))
	resolver.apply_effect(state, _effect("status.turn", DurationSpec.TURN, 1))
	resolver.apply_effect(state, _effect("status.battle", DurationSpec.BATTLE, 1))
	resolver.advance(state, LifecycleResolver.ACTION)
	assert_true(state.active_effects.has("status.window"), "window effects survive an action boundary", failures)
	assert_true(state.active_effects.has("status.turn"), "turn effects survive an action boundary", failures)
	assert_true(state.active_effects.has("status.battle"), "battle effects survive an action boundary", failures)
	resolver.advance(state, LifecycleResolver.WINDOW)
	assert_true(not state.active_effects.has("status.window"), "window effects expire at the window boundary", failures)
	assert_true(state.active_effects.has("status.turn"), "turn effects survive a window boundary", failures)
	resolver.advance(state, LifecycleResolver.TURN)
	assert_true(not state.active_effects.has("status.turn"), "turn effects expire at the turn boundary", failures)
	assert_true(state.active_effects.has("status.battle"), "battle effects survive a turn boundary", failures)
	resolver.advance(state, LifecycleResolver.BATTLE)
	assert_true(not state.active_effects.has("status.battle"), "battle effects expire at the battle boundary", failures)

func test_stack_policies_are_deterministic_and_bounded(failures: Array[String]) -> void:
	var state = CombatState.new(10, 10)
	var resolver := LifecycleResolver.new()
	resolver.apply_effect(state, _effect("status.replace", DurationSpec.PERMANENT, 0, StackPolicy.REPLACE, "first"))
	resolver.apply_effect(state, _effect("status.replace", DurationSpec.PERMANENT, 0, StackPolicy.REPLACE, "second"))
	assert_true(resolver.active_effect(state, "status.replace").source_id == "second", "REPLACE keeps the newest deterministic instance", failures)

	resolver.apply_effect(state, _effect("status.refresh", DurationSpec.TURN, 2), null, StackPolicy.REFRESH_DURATION)
	resolver.advance(state, LifecycleResolver.TURN)
	resolver.apply_effect(state, _effect("status.refresh", DurationSpec.TURN, 3), null, StackPolicy.REFRESH_DURATION)
	assert_true(resolver.active_effect(state, "status.refresh").remaining == 3, "REFRESH_DURATION resets rather than adds remaining time", failures)

	resolver.apply_effect(state, Effect.new("status.stack", null, [], [], [], DurationSpec.new(), StackPolicy.new(StackPolicy.ADD_STACKS, 2)), null, null, "", 1)
	var stack_events = resolver.apply_effect(state, Effect.new("status.stack", null, [], [], [], DurationSpec.new(), StackPolicy.new(StackPolicy.ADD_STACKS, 2)), null, null, "", 3)
	assert_true(resolver.active_effect(state, "status.stack").stacks == 2, "ADD_STACKS clamps at its explicit limit", failures)
	assert_true(bool(stack_events[0].data.limited), "stack limits are observable and deterministic", failures)

	resolver.apply_effect(state, _effect("status.unique"))
	var rejected = resolver.apply_effect(state, _effect("status.unique"), null, StackPolicy.UNIQUE)
	assert_true(rejected.size() == 1 and rejected[0].event_type == DomainEvent.EFFECT_REJECTED, "UNIQUE rejects a duplicate effect", failures)
	assert_true(state.active_effects.size() == 4, "a rejected unique effect leaves active state unchanged", failures)

func test_uses_and_charges_are_atomic_and_expire(failures: Array[String]) -> void:
	var state = CombatState.new(10, 10)
	var resolver := LifecycleResolver.new()
	resolver.apply_effect(state, _effect("status.uses", DurationSpec.USES, 2))
	resolver.apply_effect(state, _effect("status.charges", DurationSpec.CHARGES, 2))
	resolver.consume_effect(state, "status.uses", 1)
	var rejected_uses = resolver.consume_effect(state, "status.uses", 2)
	assert_true(rejected_uses[0].event_type == DomainEvent.EFFECT_REJECTED, "insufficient uses reject without a partial decrement", failures)
	assert_true(resolver.active_effect(state, "status.uses").uses_remaining == 1, "failed use consumption is atomic", failures)
	resolver.consume_effect(state, "status.uses", 1)
	assert_true(not resolver.has_active(state, "status.uses"), "the final use expires the effect and removes stale state", failures)
	resolver.consume_effect(state, "status.charges", 0, 2)
	assert_true(not resolver.has_active(state, "status.charges"), "charges expire the effect atomically", failures)

func test_repeated_lifecycle_resolution_is_deterministic(failures: Array[String]) -> void:
	var first = _run_lifecycle_sequence()
	var second = _run_lifecycle_sequence()
	assert_true(first == second, "repeated lifecycle resolution produces identical state and events", failures)

func _run_lifecycle_sequence() -> String:
	var state = CombatState.new(10, 10)
	var resolver := LifecycleResolver.new()
	resolver.apply_effect(state, _effect("status.repeat", DurationSpec.TURN, 2), null, StackPolicy.REPLACE, "source")
	var events: Array = []
	events.append_array(resolver.advance(state, LifecycleResolver.TURN, 1))
	events.append_array(resolver.advance(state, LifecycleResolver.TURN, 2))
	return JSON.stringify({"state": state.to_dictionary(), "events": _event_data(events)})

func _effect(identifier: String, scope: String = DurationSpec.PERMANENT, amount: int = 0, policy: String = StackPolicy.REPLACE, source: String = ""):
	return Effect.new(identifier, null, [], [], [], DurationSpec.new(scope, amount), policy, source)

func _event_data(events: Array) -> Array:
	var data: Array = []
	for event in events:
		data.append(event.to_dictionary())
	return data

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
