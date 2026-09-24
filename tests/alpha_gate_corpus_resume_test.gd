class_name AlphaGateCorpusResumeTest
extends RefCounted

const ResumeVerifierScript = preload("res://src/infrastructure/simulation/simulation_corpus_resume_verifier.gd")
const AttemptComparatorScript = preload("res://src/infrastructure/simulation/alpha_attempt_comparator.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_resume_rejects_an_unverified_repeat_claim(failures)
	test_cli_resume_rejects_a_forged_comparison(failures)
	for failure in failures:
		push_error(failure)
	return failures

func test_resume_rejects_an_unverified_repeat_claim(failures: Array[String]) -> void:
	var expected_case := {
		"attempt_index": 0,
		"attempt_id": "readiness.00001",
		"gate_id": "readiness",
		"seed": 57000,
		"policy_id": "Partial",
		"character_id": "base.character.sequence",
		"contract_id": "base.contract.pressure",
		"route_id": "SERVICE",
		"starting_pool_fixture_id": "phase2.character_biased_complete_hand.v1",
	}
	var first_attempt := _sample_attempt(expected_case)
	var repeated_attempt := first_attempt.duplicate(true)
	var record := {
		"record_type": "case",
		"case_number": 1,
		"attempt_case": expected_case.duplicate(true),
		"attempt": first_attempt,
		"repeat_attempt": repeated_attempt,
		"repeat_attempt_summary": ResumeVerifierScript.summarize_attempt(repeated_attempt),
		"repeat_comparison": AttemptComparatorScript.compare(first_attempt, repeated_attempt),
	}
	var valid_result: Dictionary = ResumeVerifierScript.validate_record(record, expected_case, "test-manifest", 1)
	assert_true(valid_result.get("valid", false), "a complete stored attempt pair with its comparison can be resumed", failures)
	var serialized_record := JSON.stringify(record)
	var parsed_record = JSON.parse_string(serialized_record)
	assert_true(parsed_record is Dictionary, "a stored case survives its JSONL serialization round-trip", failures)
	if parsed_record is Dictionary:
		var round_trip_result: Dictionary = ResumeVerifierScript.validate_record(parsed_record, expected_case, "test-manifest", 1)
		assert_true(
			round_trip_result.get("valid", false),
			"a complete JSONL case remains resumable after JSON numeric decoding (%s)" % str(round_trip_result.get("errors", [])),
			failures,
		)
		var string_seed_record: Dictionary = parsed_record.duplicate(true)
		string_seed_record["repeat_attempt_summary"]["seed"] = "57000"
		var string_seed_result: Dictionary = ResumeVerifierScript.validate_record(string_seed_record, expected_case, "test-manifest", 1)
		assert_true(not string_seed_result.get("valid", true), "resume rejects numeric summary fields encoded as strings", failures)
		var fractional_seed_record: Dictionary = parsed_record.duplicate(true)
		fractional_seed_record["repeat_attempt_summary"]["seed"] = 57000.5
		var fractional_seed_result: Dictionary = ResumeVerifierScript.validate_record(fractional_seed_record, expected_case, "test-manifest", 1)
		assert_true(not fractional_seed_result.get("valid", true), "resume rejects fractional summary fields", failures)
		var extra_summary_record: Dictionary = parsed_record.duplicate(true)
		extra_summary_record["repeat_attempt_summary"]["unexpected"] = "value"
		var extra_summary_result: Dictionary = ResumeVerifierScript.validate_record(extra_summary_record, expected_case, "test-manifest", 1)
		assert_true(not extra_summary_result.get("valid", true), "resume rejects unexpected summary fields", failures)

	record["repeat_comparison"] = {"matches": true}
	var forged_result: Dictionary = ResumeVerifierScript.validate_record(record, expected_case, "test-manifest", 1)
	assert_true(not forged_result.get("valid", true), "resume rejects a Boolean-only repeat claim that does not match the stored attempt pair", failures)

func test_cli_resume_rejects_a_forged_comparison(failures: Array[String]) -> void:
	var project_path := ProjectSettings.globalize_path("res://")
	var scratch_path := ProjectSettings.globalize_path("res://.godot/alpha_corpus_resume_test")
	DirAccess.make_dir_recursive_absolute(scratch_path)
	var smoke_path := scratch_path.path_join("smoke.jsonl")
	var resume_path := scratch_path.path_join("forged-resume.jsonl")
	var output_path := scratch_path.path_join("resumed-output.jsonl")
	var executable_path := OS.get_executable_path()
	var smoke_args := PackedStringArray([
		"--headless",
		"--path", project_path,
		"--script", "res://scripts/run_alpha_gate_corpus.gd",
		"--",
		"--smoke",
		"--gate", "readiness",
		"--output", smoke_path,
	])
	var smoke_output: Array[String] = []
	var smoke_exit := OS.execute(executable_path, smoke_args, smoke_output, true)
	assert_true(smoke_exit == 0, "the real corpus CLI can produce a one-case smoke source (%s)" % "\n".join(smoke_output), failures)
	if smoke_exit != 0:
		_cleanup_files([smoke_path, resume_path, output_path])
		return
	var smoke_text := FileAccess.get_file_as_string(smoke_path)
	var lines := smoke_text.strip_edges().split("\n")
	assert_true(lines.size() == 3, "the smoke JSONL contains a header, case, and summary", failures)
	if lines.size() != 3:
		_cleanup_files([smoke_path, resume_path, output_path])
		return
	var header_value = JSON.parse_string(lines[0])
	var case_value = JSON.parse_string(lines[1])
	assert_true(header_value is Dictionary and case_value is Dictionary, "the real corpus CLI emitted parseable JSONL records", failures)
	if not header_value is Dictionary or not case_value is Dictionary:
		_cleanup_files([smoke_path, resume_path, output_path])
		return
	var header: Dictionary = header_value
	var case_record: Dictionary = case_value
	header["run_state"] = "IN_PROGRESS"
	var execution: Dictionary = header.get("execution", {})
	execution["mode"] = "FULL_1000_CASE_CORPUS"
	execution["expected_case_records"] = 1000
	header["execution"] = execution
	case_record["repeat_comparison"] = {"matches": true}
	var resume_file := FileAccess.open(resume_path, FileAccess.WRITE)
	assert_true(resume_file != null, "the forged interrupted-report input can be written under the F: project", failures)
	if resume_file == null:
		_cleanup_files([smoke_path, resume_path, output_path])
		return
	resume_file.store_string(JSON.stringify(header) + "\n")
	resume_file.store_string(JSON.stringify(case_record) + "\n")
	resume_file.close()
	var resume_args := PackedStringArray([
		"--headless",
		"--path", project_path,
		"--script", "res://scripts/run_alpha_gate_corpus.gd",
		"--",
		"--full",
		"--gate", "readiness",
		"--resume-from", resume_path,
		"--output", output_path,
	])
	var resume_output: Array[String] = []
	var resume_exit := OS.execute(executable_path, resume_args, resume_output, true)
	var resume_output_text := "\n".join(resume_output)
	assert_true(resume_exit == 2, "the real corpus CLI rejects an unverifiable resumed case before running the remaining manifest cases (%s)" % resume_output_text, failures)
	assert_true(resume_output_text.contains("repeat comparison does not match the stored attempt pair"), "the real corpus CLI reports the forged repeat-comparison field", failures)
	_cleanup_files([smoke_path, resume_path, output_path])

func _cleanup_files(paths: Array[String]) -> void:
	for path in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _sample_attempt(attempt_case: Dictionary) -> Dictionary:
	return {
		"attempt_id": attempt_case.attempt_id,
		"manifest_hash": "test-manifest",
		"gate_id": attempt_case.gate_id,
		"seed": attempt_case.seed,
		"policy_id": attempt_case.policy_id,
		"character_id": attempt_case.character_id,
		"contract_id": attempt_case.contract_id,
		"route_id": attempt_case.route_id,
		"accepted_command_count": 0,
		"accepted_commands": [],
		"checkpoints": [{}],
		"checkpoint_hashes": ["checkpoint-hash"],
		"rng_snapshots": [{}],
		"events": [],
		"strategy": attempt_case.policy_id,
		"outcome": "DEFEAT",
		"two_act_profile": true,
		"configured_act_count": 2,
		"act_reached": 1,
		"progress_status": "TERMINAL_BEFORE_FINAL_ACT",
		"terminal": true,
		"content_available": true,
		"unavailable_content_paths": [],
		"failure_classification": "NONE",
		"replay_status": "MATCH",
	}

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
