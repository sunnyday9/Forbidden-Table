class_name RngStreamTest
extends RefCounted

const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_same_seed_repeats_each_domain_sequence(failures)
	test_restoring_stream_state_repeats_sequence(failures)
	test_restoring_all_stream_states_repeats_each_sequence(failures)
	test_consuming_combat_does_not_advance_other_streams(failures)
	return failures

func test_same_seed_repeats_each_domain_sequence(failures: Array[String]) -> void:
	var first_streams = DomainRngStreams.new(123456)
	var second_streams = DomainRngStreams.new(123456)
	var first_combat: Array[int] = []
	var second_combat: Array[int] = []
	var first_draw_wall: Array[int] = []
	var second_draw_wall: Array[int] = []
	var first_enemy: Array[int] = []
	var second_enemy: Array[int] = []
	for _index in range(5):
		first_combat.append(first_streams.combat.next_int(0, 1000))
		second_combat.append(second_streams.combat.next_int(0, 1000))
		first_draw_wall.append(first_streams.draw_wall.next_int(0, 1000))
		second_draw_wall.append(second_streams.draw_wall.next_int(0, 1000))
		first_enemy.append(first_streams.enemy.next_int(0, 1000))
		second_enemy.append(second_streams.enemy.next_int(0, 1000))

	assert_true(first_combat == second_combat, "the same seed repeats the Combat sequence", failures)
	assert_true(first_draw_wall == second_draw_wall, "the same seed repeats the DrawWall sequence", failures)
	assert_true(first_enemy == second_enemy, "the same seed repeats the Enemy sequence", failures)

func test_restoring_stream_state_repeats_sequence(failures: Array[String]) -> void:
	var streams = DomainRngStreams.new(24680)
	streams.combat.next_int(0, 1000)
	var saved_state: Dictionary = streams.combat.snapshot()
	var expected_sequence: Array[int] = []
	for _index in range(5):
		expected_sequence.append(streams.combat.next_int(0, 1000))

	var restored: bool = streams.combat.restore(saved_state)
	var restored_sequence: Array[int] = []
	for _index in range(5):
		restored_sequence.append(streams.combat.next_int(0, 1000))

	assert_true(restored, "a saved Combat stream state can be restored", failures)
	assert_true(expected_sequence == restored_sequence, "restoring a Combat stream repeats its sequence", failures)

func test_restoring_all_stream_states_repeats_each_sequence(failures: Array[String]) -> void:
	var streams = DomainRngStreams.new(13579)
	streams.combat.next_int(0, 1000)
	streams.draw_wall.next_int(0, 1000)
	var saved_state: Dictionary = streams.snapshot()
	var expected_combat: int = streams.combat.next_int(0, 1000)
	var expected_draw_wall: int = streams.draw_wall.next_int(0, 1000)
	var expected_enemy: int = streams.enemy.next_int(0, 1000)

	var restored: bool = streams.restore(saved_state)
	var actual_combat: int = streams.combat.next_int(0, 1000)
	var actual_draw_wall: int = streams.draw_wall.next_int(0, 1000)
	var actual_enemy: int = streams.enemy.next_int(0, 1000)

	assert_true(restored, "all saved stream states can be restored", failures)
	assert_true(expected_combat == actual_combat, "restoring all state repeats Combat", failures)
	assert_true(expected_draw_wall == actual_draw_wall, "restoring all state repeats DrawWall", failures)
	assert_true(expected_enemy == actual_enemy, "restoring all state repeats Enemy", failures)

func test_consuming_combat_does_not_advance_other_streams(failures: Array[String]) -> void:
	var isolated_streams = DomainRngStreams.new(97531)
	var reference_streams = DomainRngStreams.new(97531)
	for _index in range(5):
		isolated_streams.combat.next_int(0, 1000)

	var expected_draw_wall: Array[int] = []
	var expected_enemy: Array[int] = []
	var actual_draw_wall: Array[int] = []
	var actual_enemy: Array[int] = []
	for _index in range(5):
		expected_draw_wall.append(reference_streams.draw_wall.next_int(0, 1000))
		expected_enemy.append(reference_streams.enemy.next_int(0, 1000))
		actual_draw_wall.append(isolated_streams.draw_wall.next_int(0, 1000))
		actual_enemy.append(isolated_streams.enemy.next_int(0, 1000))

	assert_true(expected_draw_wall == actual_draw_wall, "Combat consumption does not advance DrawWall", failures)
	assert_true(expected_enemy == actual_enemy, "Combat consumption does not advance Enemy", failures)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
