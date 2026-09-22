class_name DomainCommandTest
extends RefCounted

const BattleController = preload("res://src/presentation/battle/battle_controller.gd")
const CommandResult = preload("res://src/domain/commands/command_result.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const DrawCommand = preload("res://src/domain/commands/draw_command.gd")
const SettlePatternCommand = preload("res://src/domain/commands/settle_pattern_command.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_command_serialization_is_stable(failures)
	test_rejected_command_is_atomic(failures)
	test_accepted_command_returns_events_and_checkpoint(failures)
	test_settlement_uses_the_shared_result_contract(failures)
	test_preview_command_is_not_replayable(failures)
	return failures

func test_command_serialization_is_stable(failures: Array[String]) -> void:
	var command := SettlePatternCommand.new(
		"stage1.settle.7",
		["tile.b", "tile.a"],
		"player.1",
		"battle.hand",
	)
	var expected := {
		"command_id": "stage1.settle.7",
		"command_type": "SettlePattern",
		"actor_id": "player.1",
		"target_id": "battle.hand",
		"preview": false,
		"instance_ids": ["tile.a", "tile.b"],
	}
	assert_true(command.to_dictionary() == expected, "commands expose deterministic stable fields", failures)
	assert_true(command.serialize() == JSON.stringify(expected), "command serialization is deterministic", failures)

func test_rejected_command_is_atomic(failures: Array[String]) -> void:
	var controller := BattleController.new()
	var draw_result = controller.submit(DrawCommand.new("stage1.atomic.draw"))
	var checkpoint_before: Dictionary = controller.domain.checkpoint()
	var result = controller.submit(SettlePatternCommand.new("stage1.atomic.reject", ["missing.tile"]))

	assert_true(draw_result.accepted, "the atomicity setup Draw is accepted", failures)
	assert_true(not result.accepted, "invalid selection is rejected", failures)
	assert_true(result.status == CommandResult.REJECTED, "rejection has a structured result status", failures)
	assert_true(not result.validation.is_valid(), "rejection exposes failed validation", failures)
	assert_true(result.events.is_empty(), "rejected commands emit no state-changing events", failures)
	assert_true(not result.replayable, "rejected commands are not replayable", failures)
	assert_true(controller.domain.checkpoint() == checkpoint_before, "rejected commands leave authoritative state unchanged", failures)

func test_accepted_command_returns_events_and_checkpoint(failures: Array[String]) -> void:
	var controller := BattleController.new()
	var result = controller.submit(DrawCommand.new("stage1.accepted.draw", "player.1"))

	assert_true(result.accepted, "a valid Draw command is accepted", failures)
	assert_true(result.status == CommandResult.ACCEPTED, "accepted commands have a structured result status", failures)
	assert_true(result.command_id == "stage1.accepted.draw", "the result retains the stable command ID", failures)
	assert_true(_has_event(result.events, DomainEvent.TILE_DRAWN), "accepted commands return their DomainEvents", failures)
	assert_true(not result.state_checkpoint.is_empty(), "accepted commands return a state checkpoint", failures)
	assert_true(result.state_checkpoint == controller.domain.checkpoint(), "the checkpoint describes resulting domain state", failures)
	assert_true(result.replayable, "accepted authoritative commands are replayable", failures)

func test_preview_command_is_not_replayable(failures: Array[String]) -> void:
	var controller := BattleController.new()
	var checkpoint_before: Dictionary = controller.domain.checkpoint()
	var result = controller.submit(DrawCommand.new("stage1.preview.draw", "player.1", "", true))

	assert_true(not result.replayable, "preview commands are not replayable", failures)
	assert_true(result.events.is_empty(), "preview commands do not emit authoritative events", failures)
	assert_true(controller.domain.checkpoint() == checkpoint_before, "preview commands do not mutate authoritative state", failures)

func test_settlement_uses_the_shared_result_contract(failures: Array[String]) -> void:
	var controller := BattleController.new()
	controller.submit(DrawCommand.new("stage1.accepted.settlement.draw"))
	var pattern = controller.presentation.pattern_highlights[0]
	var result = controller.submit(SettlePatternCommand.new(
		"stage1.accepted.settlement",
		pattern["instance_ids"],
	))

	assert_true(result is CommandResult, "Settlement returns the shared CommandResult", failures)
	assert_true(result.accepted, "a valid Settlement command is accepted", failures)
	assert_true(result.status == "COMPLETED", "Settlement preserves its Stage 0 completion status", failures)
	assert_true(_has_event(result.events, DomainEvent.PATTERN_SETTLED), "Settlement returns its DomainEvents", failures)
	assert_true(result.replayable, "accepted Settlement commands are replayable", failures)

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
