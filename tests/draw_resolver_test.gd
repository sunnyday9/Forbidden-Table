class_name DrawResolverTest
extends RefCounted

const CombatState = preload("res://src/domain/combat/combat_state.gd")
const DrawResolver = preload("res://src/domain/tiles/draw_resolver.gd")
const DrawResult = preload("res://src/domain/tiles/draw_result.gd")
const DrawSource = preload("res://src/domain/tiles/draw_source.gd")
const DrawWall = preload("res://src/domain/tiles/draw_wall.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_normal_draw_reports_draw_result_and_source(failures)
	test_empty_wall_reshuffles_discard_and_increments_fatigue_once(failures)
	test_draw_sources_remain_distinguishable(failures)
	test_shortfall_enters_starvation_without_immediate_defeat(failures)
	test_starvation_pressure_escalates_deterministically(failures)
	test_repeated_identical_draws_repeat_state_and_events(failures)
	return failures

func test_normal_draw_reports_draw_result_and_source(failures: Array[String]) -> void:
	var fixture := _fixture(1, 10)
	var result = fixture.resolver.draw(1, DrawSource.NORMAL_ACTION)

	assert_true(result is DrawResult, "normal draws return a DrawResult", failures)
	assert_true(result.status == DrawResult.ACCEPTED, "a normal draw with an available tile is accepted", failures)
	assert_true(result.requested == 1 and result.drawn == 1 and result.shortfall == 0, "normal draw reports requested, drawn, and shortfall", failures)
	assert_true(result.events.size() == 1, "an ordinary draw emits one draw event", failures)
	assert_true(result.events[0].data.source == DrawSource.NORMAL_ACTION, "the draw event preserves the explicit source", failures)

func test_empty_wall_reshuffles_discard_and_increments_fatigue_once(failures: Array[String]) -> void:
	var fixture := _fixture(1, 20)
	var first = fixture.resolver.draw(1, DrawSource.NORMAL_ACTION)
	fixture.zones.transfer(first.tile_instance.instance_id, TileZone.HAND, TileZone.DISCARD)
	var result = fixture.resolver.draw(1, DrawSource.NORMAL_ACTION)

	assert_true(result.status == DrawResult.ACCEPTED, "a discard tile is drawn after the wall is exhausted", failures)
	assert_true(result.drawn == 1 and result.shortfall == 0, "reshuffled draws satisfy the request", failures)
	assert_true(fixture.state.fatigue == 1, "one reshuffle increments Fatigue exactly once", failures)
	assert_true(_count_events(result.events, DomainEvent.DRAW_WALL_RESHUFFLED) == 1, "reshuffle emits one deterministic event", failures)
	assert_true(_count_events(result.events, DomainEvent.FATIGUE_CHANGED) == 1, "reshuffle emits one Fatigue event", failures)
	assert_true(result.events[-1].data["source"] == DrawSource.NORMAL_ACTION, "normal draw keeps its source after reshuffle", failures)

func test_draw_sources_remain_distinguishable(failures: Array[String]) -> void:
	var fixture := _fixture(5, 20)
	var sources: Array[String] = [
		DrawSource.NORMAL_ACTION,
		DrawSource.SETTLEMENT_REPLACEMENT,
		DrawSource.COMPLETE_HAND_REBUILD,
		DrawSource.TECHNIQUE,
		DrawSource.EFFECT,
	]
	var observed: Array[String] = []
	for source in sources:
		var result = fixture.resolver.draw(1, source)
		observed.append(result.events[-1].data.source if result.drawn == 1 else "")

	assert_true(observed == sources, "all explicit DrawSource values remain distinguishable", failures)
	assert_true(fixture.state.fatigue == 0, "available source-specific draws do not create Fatigue", failures)

func test_shortfall_enters_starvation_without_immediate_defeat(failures: Array[String]) -> void:
	var fixture := _fixture(0, 10)
	var result = fixture.resolver.draw(1, DrawSource.NORMAL_ACTION)

	assert_true(result.status == DrawResult.STARVATION, "an unsatisfied request enters Starvation", failures)
	assert_true(result.requested == 1 and result.drawn == 0 and result.shortfall == 1, "Starvation preserves the draw shortfall", failures)
	assert_true(fixture.state.starvation_active, "CombatState records active Starvation", failures)
	assert_true(fixture.state.pressure == 1, "the first Starvation consequence adds Pressure", failures)
	assert_true(fixture.state.terminal_outcome == CombatState.ONGOING, "Starvation does not immediately defeat the battle", failures)
	assert_true(_has_event(result.events, DomainEvent.STARVATION_ENTERED), "Starvation is an auditable event", failures)
	assert_true(_has_event(result.events, DomainEvent.PRESSURE_CHANGED), "Starvation pressure is an auditable event", failures)

func test_starvation_pressure_escalates_deterministically(failures: Array[String]) -> void:
	var fixture := _fixture(0, 20)
	fixture.resolver.draw(1, DrawSource.NORMAL_ACTION)
	fixture.resolver.draw(1, DrawSource.NORMAL_ACTION)
	var result = fixture.resolver.draw(1, DrawSource.NORMAL_ACTION)

	assert_true(fixture.state.starvation_count == 3, "each unsatisfied request advances Starvation escalation", failures)
	assert_true(fixture.state.pressure == 7, "Starvation Pressure follows the 1, 2, 4 escalation", failures)
	assert_true(_has_event(result.events, DomainEvent.STARVATION_ESCALATED), "later Starvation emits an escalation event", failures)
	assert_true(fixture.state.is_active(), "escalating nonlethal Starvation leaves recovery actions legal", failures)

func test_repeated_identical_draws_repeat_state_and_events(failures: Array[String]) -> void:
	var first := _run_sequence(90210)
	var second := _run_sequence(90210)
	assert_true(first == second, "identical seeds and draw requests repeat state and events", failures)

func _run_sequence(seed: int) -> Dictionary:
	var zones := TileZoneContainer.new()
	for index in range(2):
		zones.add(TileInstance.new("run.resolver.%d" % index, "base.tile.man.%d" % (index + 1)), TileZone.TILE_POOL)
	var state := CombatState.new(10, 20)
	var wall := DrawWall.new(zones, DomainRngStreams.new(seed).draw_wall)
	wall.initialize()
	var resolver := DrawResolver.new(wall, zones, state)
	var first = resolver.draw(1, DrawSource.NORMAL_ACTION)
	zones.transfer(first.tile_instance.instance_id, TileZone.HAND, TileZone.DISCARD)
	var second = resolver.draw(2, DrawSource.NORMAL_ACTION)
	return {
		"state": state.to_dictionary(),
		"zones": _zone_ids(zones),
		"first": _result_data(first),
		"second": _result_data(second),
	}

func _fixture(pool_count: int, pressure_limit: int) -> Dictionary:
	var zones := TileZoneContainer.new()
	for index in range(pool_count):
		zones.add(TileInstance.new("run.fixture.%d" % index, "base.tile.man.%d" % ((index % 9) + 1)), TileZone.TILE_POOL)
	var state := CombatState.new(10, pressure_limit)
	var wall := DrawWall.new(zones, DomainRngStreams.new(23).draw_wall)
	wall.initialize()
	return {"zones": zones, "state": state, "resolver": DrawResolver.new(wall, zones, state)}

func _result_data(result) -> Dictionary:
	return {
		"status": result.status,
		"requested": result.requested,
		"drawn": result.drawn,
		"shortfall": result.shortfall,
		"events": result.events.map(func(event): return event.to_dictionary()),
	}

func _zone_ids(zones) -> Dictionary:
	var result := {}
	for zone in TileZone.all():
		var ids: Array[String] = []
		for tile in zones.contents(zone):
			ids.append(tile.instance_id)
		result[zone] = ids
	return result

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for event in events:
		if event.event_type == event_type:
			count += 1
	return count

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
