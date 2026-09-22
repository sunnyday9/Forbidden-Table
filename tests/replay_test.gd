class_name ReplayTest
extends RefCounted

const BattleController = preload("res://src/presentation/battle/battle_controller.gd")
const CommandResult = preload("res://src/domain/commands/command_result.gd")
const DrawCommand = preload("res://src/domain/commands/draw_command.gd")
const SettlePatternCommand = preload("res://src/domain/commands/settle_pattern_command.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_replay_command_serialization_has_stable_order(failures)
	test_replay_excludes_rejected_and_preview_commands(failures)
	test_identical_replay_reproduces_checkpoints_and_terminal_outcome(failures)
	test_changed_command_is_structured_divergence(failures)
	test_changed_content_version_is_structured_divergence(failures)
	test_rng_divergence_is_structured(failures)
	return failures

func test_replay_command_serialization_has_stable_order(failures: Array[String]) -> void:
	var command := SettlePatternCommand.new(
		"replay.settle.1",
		["tile.b", "tile.a"],
		"player.1",
		"battle.hand",
	)
	var expected := "{\"actor_id\":\"player.1\",\"command_id\":\"replay.settle.1\",\"command_type\":\"SettlePattern\",\"instance_ids\":[\"tile.a\",\"tile.b\"],\"preview\":false,\"target_id\":\"battle.hand\"}"
	assert_true(command.serialize() == expected, "command serialization has a stable field and payload order", failures)

func test_replay_excludes_rejected_and_preview_commands(failures: Array[String]) -> void:
	var controller := BattleController.new(13, "content.replay.test")
	var preview_result = controller.submit(DrawCommand.new("replay.preview", "player.1", "", true))
	var rejected_result = controller.submit(SettlePatternCommand.new("replay.rejected", ["missing.tile"]))
	var accepted_result = controller.submit(DrawCommand.new("replay.accepted", "player.1"))

	assert_true(preview_result.status == CommandResult.PREVIEW_ONLY, "preview command has preview status", failures)
	assert_true(not rejected_result.accepted, "invalid command is rejected", failures)
	assert_true(accepted_result.accepted, "valid command is accepted", failures)
	assert_true(controller.replay_record.commands.size() == 1, "only accepted authoritative commands enter ReplayRecord", failures)
	assert_true(controller.replay_record.commands[0].command_id == "replay.accepted", "ReplayRecord excludes preview and rejected IDs", failures)

func test_identical_replay_reproduces_checkpoints_and_terminal_outcome(failures: Array[String]) -> void:
	var controller := BattleController.new(13, "content.replay.test")
	controller.submit(DrawCommand.new("replay.same.draw", "player.1"))
	var report = controller.verify_replay()

	assert_true(report.is_match(), "identical seed, content, commands, and checkpoints replay identically", failures)
	assert_true(report.terminal_outcome == controller.combat_state.terminal_outcome, "identical replay preserves terminal outcome", failures)

func test_rng_divergence_is_structured(failures: Array[String]) -> void:
	var controller := BattleController.new(13, "content.replay.test")
	controller.submit(DrawCommand.new("replay.rng.draw", "player.1"))
	var checkpoint = controller.replay_record.checkpoints[1]
	checkpoint.rng_state["streams"]["draw_wall"]["state"] += 1
	var report = controller.verify_replay()

	assert_true(report.is_diverged(), "a changed RNG checkpoint diverges", failures)
	assert_true(report.reason == "RNG_STATE_MISMATCH", "RNG divergence has a structured reason", failures)
	assert_true(report.checkpoint_index == 1, "RNG divergence identifies its checkpoint", failures)

func test_changed_command_is_structured_divergence(failures: Array[String]) -> void:
	var controller := BattleController.new(13, "content.replay.test")
	controller.submit(DrawCommand.new("replay.command.original", "player.1"))
	controller.replay_record.commands[0].command_id = "replay.command.changed"
	var report = controller.verify_replay()

	assert_true(report.is_diverged(), "a changed command diverges", failures)
	assert_true(report.reason == "COMMAND_MISMATCH", "command divergence has a structured reason", failures)

func test_changed_content_version_is_structured_divergence(failures: Array[String]) -> void:
	var controller := BattleController.new(13, "content.replay.test")
	controller.replay_record.content_version = "content.replay.changed"
	var report = controller.verify_replay()

	assert_true(report.is_diverged(), "a changed content version diverges", failures)
	assert_true(report.reason == "CONTENT_VERSION_MISMATCH", "content divergence has a structured reason", failures)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
