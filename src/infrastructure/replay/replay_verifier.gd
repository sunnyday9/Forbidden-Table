class_name ReplayVerifier
extends RefCounted

const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const ReplayCheckpointScript = preload("res://src/infrastructure/replay/replay_checkpoint.gd")
const ReplayCommandFactoryScript = preload("res://src/infrastructure/replay/replay_command_factory.gd")
const ReplayDivergenceReportScript = preload("res://src/infrastructure/replay/replay_divergence_report.gd")

static func verify(record, replay_factory: Callable, expected_content_version: String = ""):
	if record == null:
		return ReplayDivergenceReportScript.new(ReplayDivergenceReportScript.DIVERGED, "MISSING_RECORD")
	if not expected_content_version.is_empty() and record.content_version != expected_content_version:
		return ReplayDivergenceReportScript.new(
			ReplayDivergenceReportScript.DIVERGED,
			"CONTENT_VERSION_MISMATCH",
			-1,
			-1,
			expected_content_version,
			record.content_version,
		)
	if record.checkpoints.size() != record.commands.size() + 1:
		return ReplayDivergenceReportScript.new(ReplayDivergenceReportScript.DIVERGED, "CHECKPOINT_SEQUENCE_INVALID")

	var controller = replay_factory.call(record.run_seed, record.content_version)
	var initial_report = _compare_checkpoint(record.checkpoints[0], _checkpoint_for(controller, 0, 0), 0, 0)
	if initial_report != null:
		return initial_report

	for index in range(record.commands.size()):
		var command_record = record.commands[index]
		var expected_command_serialization: String = command_record.serialized_command
		var actual_command_serialization: String = DeterministicSerializerScript.serialize_command(command_record.to_command_dictionary())
		if expected_command_serialization != actual_command_serialization:
			return ReplayDivergenceReportScript.new(
				ReplayDivergenceReportScript.DIVERGED,
				"COMMAND_MISMATCH",
				index + 1,
				index,
				expected_command_serialization,
				actual_command_serialization,
			)

		var command = ReplayCommandFactoryScript.from_record(command_record)
		if command == null:
			return ReplayDivergenceReportScript.new(ReplayDivergenceReportScript.DIVERGED, "COMMAND_TYPE_UNSUPPORTED", index + 1, index, command_record.command_type, null)
		var result = controller.submit(command)
		if result == null or not result.is_accepted():
			return ReplayDivergenceReportScript.new(ReplayDivergenceReportScript.DIVERGED, "COMMAND_REJECTED", index + 1, index, command_record.to_dictionary(), result.to_dictionary() if result != null else null)

		var actual_checkpoint = _checkpoint_for(controller, index + 1, index + 1)
		var checkpoint_report = _compare_checkpoint(record.checkpoints[index + 1], actual_checkpoint, index + 1, index)
		if checkpoint_report != null:
			return checkpoint_report

	var terminal_outcome := str(controller.combat_state.terminal_outcome) if controller != null and controller.combat_state != null else ""
	if terminal_outcome != record.terminal_outcome:
		return ReplayDivergenceReportScript.new(
			ReplayDivergenceReportScript.DIVERGED,
			"TERMINAL_OUTCOME_MISMATCH",
			record.checkpoints.size() - 1,
			record.commands.size(),
			record.terminal_outcome,
			terminal_outcome,
			terminal_outcome,
		)
	return ReplayDivergenceReportScript.new(ReplayDivergenceReportScript.MATCH, "MATCH", -1, -1, null, null, terminal_outcome)

static func _checkpoint_for(controller, sequence_index: int, command_index: int):
	return ReplayCheckpointScript.new(
		sequence_index,
		command_index,
		controller.domain.checkpoint(),
		controller.domain.rng_snapshot(),
		controller.combat_state.terminal_outcome,
	)

static func _compare_checkpoint(expected, actual, checkpoint_index: int, command_index: int):
	if expected.domain_state_hash != actual.domain_state_hash:
		return ReplayDivergenceReportScript.new(
			ReplayDivergenceReportScript.DIVERGED,
			"DOMAIN_STATE_HASH_MISMATCH",
			checkpoint_index,
			command_index,
			expected.to_dictionary(),
			actual.to_dictionary(),
		)
	if expected.rng_state != actual.rng_state:
		return ReplayDivergenceReportScript.new(
			ReplayDivergenceReportScript.DIVERGED,
			"RNG_STATE_MISMATCH",
			checkpoint_index,
			command_index,
			expected.rng_state,
			actual.rng_state,
		)
	if expected.terminal_outcome != actual.terminal_outcome:
		return ReplayDivergenceReportScript.new(
			ReplayDivergenceReportScript.DIVERGED,
			"CHECKPOINT_TERMINAL_OUTCOME_MISMATCH",
			checkpoint_index,
			command_index,
			expected.terminal_outcome,
			actual.terminal_outcome,
		)
	return null
