extends SceneTree

const SimulationManifestScript = preload("res://src/infrastructure/simulation/simulation_manifest.gd")
const AlphaSimulationRunnerScript = preload("res://src/infrastructure/simulation/alpha_simulation_runner.gd")
const AlphaAttemptComparatorScript = preload("res://src/infrastructure/simulation/alpha_attempt_comparator.gd")
const SimulationGateRunnerScript = preload("res://src/infrastructure/simulation/simulation_gate_runner.gd")
const AlphaSimulationStartingPoolFixtureScript = preload("res://src/infrastructure/simulation/alpha_simulation_starting_pool_fixture.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")

const REPORT_SCHEMA := "alpha.gate-corpus-jsonl.v1"
const BASELINE_CONTENT_VERSION := "content.slice.v2"
const BASELINE_SEED_START := 57000
const COMMAND_LIMIT := 1024
const DEFAULT_GATE_ID := "hardening"
const BASELINE_POLICIES := ["Partial", "Complete", "Hybrid"]
const BASELINE_ROUTES := ["EVENT", "SERVICE"]
const REQUIRED_ACT_BOUNDARIES := [
	"ACT_1_BOSS_REWARD_TO_ACT_2",
	"ACT_2_BOSS_REWARD_TO_SUMMARY",
]
const REQUIRED_REWARD_PATHS := ["NORMAL_REWARD", "ELITE_REWARD", "BOSS_RULE_BREAKER"]
const ACT_1_BOSS_THREE_CHOICE_PATH := "ACT_1_BOSS_RULE_BREAKER_THREE_CHOICES"
const ACT_2_BOSS_THREE_CHOICE_PATH := "ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"
const ACT_2_BOSS_POOL_CONTENT_ID := "alpha.act_two.boss_rule_breaker_pool"
const ACT_2_SUMMARY_BOUNDARY := "ACT_2_BOSS_REWARD_TO_SUMMARY"
const AVAILABLE_REWARD_PATHS := [
	"NORMAL_REWARD",
	"ELITE_REWARD",
	"BOSS_RULE_BREAKER",
	ACT_1_BOSS_THREE_CHOICE_PATH,
	ACT_2_BOSS_THREE_CHOICE_PATH,
]

func _initialize() -> void:
	var options := _parse_arguments(OS.get_cmdline_user_args())
	if options.has("error"):
		_fail(str(options.error), 2)
		return
	var output_path := str(options.output_path)
	if not output_path.is_absolute_path():
		_fail("--output must be an absolute caller-supplied file path.", 2)
		return
	var resume_path := str(options.resume_path)
	if not resume_path.is_empty():
		if not resume_path.is_absolute_path() or not FileAccess.file_exists(resume_path):
			_fail("--resume-from must identify an existing absolute JSONL file.", 2)
			return
		if resume_path == output_path:
			_fail("--resume-from and --output must be different files; the source is preserved.", 2)
			return
		if bool(options.smoke):
			_fail("A smoke report cannot be resumed as gate evidence.", 2)
			return
	if FileAccess.file_exists(output_path):
		_fail("Refusing to overwrite the existing output path: %s" % output_path, 2)
		return
	if not DirAccess.dir_exists_absolute(output_path.get_base_dir()):
		_fail("The parent directory for --output does not exist: %s" % output_path.get_base_dir(), 2)
		return

	var gate_id := str(options.gate_id)
	var manifest = _build_manifest(gate_id)
	if manifest == null:
		return
	var manifest_data: Dictionary = manifest.to_dictionary()
	var gate_profiles: Dictionary = manifest_data.get("gates", {})
	var gate_profile: Dictionary = gate_profiles.get(gate_id, {})
	var cases: Array = gate_profile.get("cases", [])
	if cases.size() != SimulationManifestScript.RUNS_REQUIRED_PER_GATE:
		_fail("The baseline manifest did not produce exactly 1,000 cases.", 2)
		return
	if not resume_path.is_empty():
		var resume_header := _read_resume_header(resume_path, gate_id, str(manifest.manifest_hash()), cases.size())
		if resume_header.has("error"):
			_fail(str(resume_header.error), 2)
			return

	var smoke_mode: bool = bool(options.smoke)
	var cases_to_run := 1 if smoke_mode else cases.size()
	var manifest_hash: String = str(manifest.manifest_hash())
	var report_file := FileAccess.open(output_path, FileAccess.WRITE)
	if report_file == null:
		_fail("Could not open the explicit output path %s: %s" % [output_path, error_string(FileAccess.get_open_error())], 2)
		return
	var header_record := {
		"record_type": "header",
		"schema": REPORT_SCHEMA,
		"record_format": "JSON Lines; a final summary record marks completion.",
		"run_state": "IN_PROGRESS",
		"report_scope": "SEEDED_SIMULATION_SUBGATE_ONLY",
		"evidence_class": "SMOKE_NON_GATE_EVIDENCE" if smoke_mode else "FULL_BASELINE_GATE_CORPUS",
		"gate_id": gate_id,
		"gate_evidence_eligible": false,
		"overall_readiness_or_hardening_decision": "NOT_EVALUATED_BY_THIS_CORPUS",
		"manifest_hash": manifest_hash,
		"manifest": manifest_data,
		"execution": {
			"mode": "SMOKE_ONE_CASE" if smoke_mode else "FULL_1000_CASE_CORPUS",
			"manifest_case_count": cases.size(),
			"expected_case_records": cases_to_run,
			"command_limit_per_attempt": COMMAND_LIMIT,
			"starting_pool_fixture_id": AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID,
		},
	}
	var write_error := _write_jsonl_record(report_file, header_record)
	if write_error != OK:
		report_file.close()
		_fail("Could not write the corpus header to %s: %s" % [output_path, error_string(write_error)], 2)
		return

	var aggregate_attempts: Array[Dictionary] = []
	var repeat_match_count := 0
	var repeat_divergences: Array[Dictionary] = []
	var resumed_case_count := 0
	if not resume_path.is_empty():
		var resume_file := FileAccess.open(resume_path, FileAccess.READ)
		if resume_file == null:
			report_file.close()
			_fail("Could not open the resume source %s: %s" % [resume_path, error_string(FileAccess.get_open_error())], 2)
			return
		resume_file.get_line()
		while not resume_file.eof_reached():
			var source_line := resume_file.get_line()
			if source_line.is_empty():
				continue
			var source_record = JSON.parse_string(source_line)
			if not source_record is Dictionary:
				resume_file.close()
				report_file.close()
				_fail("The resume source contains an invalid JSONL record after its header.", 2)
				return
			var record_type := str(source_record.get("record_type", ""))
			if record_type == "summary":
				resume_file.close()
				report_file.close()
				_fail("The resume source already has a summary; completed reports cannot be resumed.", 2)
				return
			if record_type != "case" or resumed_case_count >= cases.size():
				resume_file.close()
				report_file.close()
				_fail("The resume source contains an unexpected record or more cases than its manifest.", 2)
				return
			var expected_case: Dictionary = cases[resumed_case_count]
			var attempt_case: Dictionary = source_record.get("attempt_case", {})
			var attempt: Dictionary = source_record.get("attempt", {})
			var comparison: Dictionary = source_record.get("repeat_comparison", {})
			var case_errors: Array[String] = []
			if int(source_record.get("case_number", 0)) != resumed_case_count + 1:
				case_errors.append("nonsequential case number")
			if not _case_matches_manifest_case(attempt_case, expected_case):
				case_errors.append("case fields differ from the manifest")
			if int(attempt.get("seed", -1)) != int(expected_case.get("seed", -2)):
				case_errors.append("attempt seed differs from the manifest")
			for key in ["policy_id", "character_id", "contract_id", "route_id", "attempt_id"]:
				if str(attempt.get(key, "")) != str(expected_case.get(key, "")):
					case_errors.append("attempt %s differs from the manifest" % key)
			if str(attempt.get("manifest_hash", "")) != manifest_hash:
				case_errors.append("attempt manifest hash differs")
			if comparison.is_empty():
				case_errors.append("repeat comparison is missing")
			if not case_errors.is_empty():
				resume_file.close()
				report_file.close()
				_fail("Resume case %d failed validation: %s." % [resumed_case_count + 1, ", ".join(case_errors)], 2)
				return
			aggregate_attempts.append(attempt)
			if bool(comparison.get("matches", false)):
				repeat_match_count += 1
			else:
				repeat_divergences.append({
					"attempt_id": str(expected_case.get("attempt_id", "")),
					"differences": comparison.get("differences", []).duplicate(),
				})
			report_file.store_string(source_line + "\n")
			if report_file.get_error() != OK:
				resume_file.close()
				report_file.close()
				_fail("Could not copy a verified resume case into %s." % output_path, 2)
				return
			resumed_case_count += 1
		resume_file.close()
		print("Validated and preserved %d completed cases from the interrupted corpus." % resumed_case_count)

	for index in range(resumed_case_count, cases_to_run):
		var attempt_case: Dictionary = cases[index]
		var attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(
			attempt_case,
			manifest_hash,
			COMMAND_LIMIT,
		)
		var repeated_attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(
			attempt_case,
			manifest_hash,
			COMMAND_LIMIT,
		)
		var comparison: Dictionary = AlphaAttemptComparatorScript.compare(attempt, repeated_attempt)
		if bool(comparison.get("matches", false)):
			repeat_match_count += 1
		else:
			repeat_divergences.append({
				"attempt_id": str(attempt_case.get("attempt_id", "")),
				"differences": comparison.get("differences", []).duplicate(),
			})
		aggregate_attempts.append(attempt)
		var case_record := {
			"record_type": "case",
			"case_number": index + 1,
			"attempt_case": attempt_case.duplicate(true),
			"attempt": attempt,
			"repeat_attempt_summary": _attempt_summary(repeated_attempt),
			"repeat_comparison": comparison,
		}
		write_error = _write_jsonl_record(report_file, case_record)
		if write_error != OK:
			report_file.close()
			_fail("Could not write corpus case %d to %s: %s" % [index + 1, output_path, error_string(write_error)], 2)
			return
		if not smoke_mode and (index + 1) % 100 == 0:
			print("Executed and repeated %d / %d manifest cases." % [index + 1, cases_to_run])

	var gate_aggregate: Dictionary = SimulationGateRunnerScript.aggregate(gate_profile, aggregate_attempts)
	var repeat_checks_pass := repeat_match_count == cases_to_run and repeat_divergences.is_empty()
	var simulation_gate_pass := (
		not smoke_mode
		and repeat_checks_pass
		and bool(gate_aggregate.get("gate_pass", false))
	)
	var simulation_gate_status := "SMOKE_ONLY_NOT_GATE_EVIDENCE"
	if not smoke_mode:
		if not repeat_checks_pass:
			simulation_gate_status = "REPEAT_COMPARISON_FAILURE"
		else:
			simulation_gate_status = str(gate_aggregate.get("gate_status", "FAIL"))

	var summary_record := {
		"record_type": "summary",
		"schema": REPORT_SCHEMA,
		"run_state": "COMPLETE",
		"report_scope": "SEEDED_SIMULATION_SUBGATE_ONLY",
		"evidence_class": "SMOKE_NON_GATE_EVIDENCE" if smoke_mode else "FULL_BASELINE_GATE_CORPUS",
		"gate_id": gate_id,
		"simulation_gate_status": simulation_gate_status,
		"simulation_gate_pass": simulation_gate_pass,
		"gate_evidence_eligible": not smoke_mode and cases_to_run == SimulationManifestScript.RUNS_REQUIRED_PER_GATE,
		"overall_readiness_or_hardening_decision": "NOT_EVALUATED_BY_THIS_CORPUS",
		"manifest_hash": manifest_hash,
		"execution": {
			"mode": "SMOKE_ONE_CASE" if smoke_mode else "FULL_1000_CASE_CORPUS",
			"manifest_case_count": cases.size(),
			"attempts_executed": cases_to_run,
			"exact_cases_repeated": cases_to_run,
			"repeat_matches": repeat_match_count,
			"repeat_divergence_count": repeat_divergences.size(),
			"command_limit_per_attempt": COMMAND_LIMIT,
			"starting_pool_fixture_id": AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID,
		},
		"repeat_divergences": repeat_divergences,
		"act_2_coverage": _act_two_coverage(gate_aggregate),
		"gate_aggregation": gate_aggregate,
	}
	write_error = _write_jsonl_record(report_file, summary_record)
	if write_error != OK:
		report_file.close()
		_fail("Could not write the final summary to %s: %s" % [output_path, error_string(write_error)], 2)
		return
	report_file.close()
	print("ALPHA_GATE_CORPUS gate=%s mode=%s attempts=%d/%d simulation_gate_status=%s simulation_gate_pass=%s output=%s" % [
		gate_id,
		"smoke" if smoke_mode else "full",
		cases_to_run,
		cases.size(),
		simulation_gate_status,
		str(simulation_gate_pass),
		output_path,
	])
	quit(0 if smoke_mode or simulation_gate_pass else 1)

func _parse_arguments(arguments: Array[String]) -> Dictionary:
	var result := {
		"output_path": "",
		"resume_path": "",
		"gate_id": DEFAULT_GATE_ID,
		"smoke": false,
		"mode_selected": false,
	}
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		if argument == "--smoke" or argument == "--full":
			if bool(result.mode_selected):
				return {"error": "Choose exactly one mode: --smoke or --full."}
			result.mode_selected = true
			result.smoke = argument == "--smoke"
		elif argument == "--output" or argument == "--gate" or argument == "--resume-from":
			if index + 1 >= arguments.size():
				return {"error": "%s requires a value." % argument}
			index += 1
			if argument == "--output":
				result.output_path = arguments[index]
			elif argument == "--resume-from":
				result.resume_path = arguments[index]
			else:
				result.gate_id = arguments[index]
		elif argument.begins_with("--output="):
			result.output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--resume-from="):
			result.resume_path = argument.trim_prefix("--resume-from=")
		elif argument.begins_with("--gate="):
			result.gate_id = argument.trim_prefix("--gate=")
		else:
			return {"error": "Unknown argument: %s" % argument}
		index += 1
	if str(result.output_path).is_empty():
		return {"error": "An explicit output file is required. Use --output /absolute/path/report.jsonl."}
	if not bool(result.mode_selected):
		return {"error": "Choose --smoke for one case or --full for the 1,000-case corpus."}
	if str(result.gate_id) not in ["readiness", "hardening"]:
		return {"error": "--gate must be readiness or hardening."}
	return result

func _read_resume_header(path: String, gate_id: String, manifest_hash: String, expected_case_count: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "Could not open the resume source %s: %s" % [path, error_string(FileAccess.get_open_error())]}
	var header_line := file.get_line()
	file.close()
	var header_value = JSON.parse_string(header_line)
	if not header_value is Dictionary:
		return {"error": "The resume source does not begin with a valid JSON header."}
	var header: Dictionary = header_value
	var execution: Dictionary = header.get("execution", {})
	if (
		str(header.get("record_type", "")) != "header"
		or str(header.get("run_state", "")) != "IN_PROGRESS"
		or str(header.get("gate_id", "")) != gate_id
		or str(header.get("manifest_hash", "")) != manifest_hash
		or str(execution.get("mode", "")) != "FULL_1000_CASE_CORPUS"
		or int(execution.get("expected_case_records", 0)) != expected_case_count
	):
		return {"error": "The resume header is not an interrupted full corpus for this exact gate and manifest."}
	return {"header": header}

func _case_matches_manifest_case(actual: Dictionary, expected: Dictionary) -> bool:
	for key in ["attempt_index", "seed"]:
		if int(actual.get(key, -1)) != int(expected.get(key, -2)):
			return false
	for key in ["attempt_id", "gate_id", "policy_id", "character_id", "contract_id", "route_id", "starting_pool_fixture_id"]:
		if str(actual.get(key, "")) != str(expected.get(key, "")):
			return false
	return true

func _build_manifest(gate_id: String):
	if Phase2CatalogScript.CHARACTER_IDS.size() != 2 or Phase2CatalogScript.CONTRACT_IDS.size() != 3:
		_fail("The current Phase 2 catalog is not the required 2-Character/3-Contract baseline.", 2)
		return null
	var config := {
		"schema_version": SimulationManifestScript.SCHEMA_VERSION,
		"content_version": BASELINE_CONTENT_VERSION,
		"starting_pool_fixture_id": AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID,
		"gate_profiles": [{
			"gate_id": gate_id,
			"attempt_count": SimulationManifestScript.RUNS_REQUIRED_PER_GATE,
			"seed_start": BASELINE_SEED_START,
			"policy_ids": BASELINE_POLICIES,
			"character_ids": Phase2CatalogScript.CHARACTER_IDS,
			"contract_ids": Phase2CatalogScript.CONTRACT_IDS,
			"route_ids": BASELINE_ROUTES,
			"required_character_ids": Phase2CatalogScript.CHARACTER_IDS,
			"required_contract_ids": Phase2CatalogScript.CONTRACT_IDS,
			"required_policy_ids": BASELINE_POLICIES,
			"required_act_boundaries": REQUIRED_ACT_BOUNDARIES,
			"required_reward_paths": REQUIRED_REWARD_PATHS,
			"available_reward_paths": AVAILABLE_REWARD_PATHS,
			"not_yet_introduced_reward_paths": [],
			"not_yet_introduced_content_ids": [],
		}],
	}
	var manifest = SimulationManifestScript.new(
		config,
		Phase2CatalogScript.CHARACTER_IDS,
		Phase2CatalogScript.CONTRACT_IDS,
	)
	if not manifest.is_valid():
		_fail("The baseline manifest is invalid: %s" % ", ".join(manifest.errors()), 2)
		return null
	return manifest

func _act_two_coverage(gate_aggregate: Dictionary) -> Dictionary:
	var coverage: Dictionary = gate_aggregate.get("coverage", {})
	var acts: Dictionary = coverage.get("acts", {})
	var boss_outcomes: Dictionary = coverage.get("boss_outcomes", {})
	var reward_paths: Dictionary = coverage.get("reward_paths", {})
	var boundaries: Dictionary = coverage.get("act_boss_boundaries", {})
	var reward_status := _requirement_status(reward_paths, ACT_2_BOSS_THREE_CHOICE_PATH)
	var act_two_boss_reward_available := AVAILABLE_REWARD_PATHS.has(ACT_2_BOSS_THREE_CHOICE_PATH)
	var act_two_boundary_observed: bool = boundaries.get("observed_ids", []).has(ACT_2_SUMMARY_BOUNDARY)
	return {
		"act_2_observed": acts.get("observed_ids", []).has("ACT_2"),
		"act_2_boss_outcome_observed": boss_outcomes.get("observed_ids", []).has("ACT_2_BOSS"),
		"act_2_boss_three_choice_reward_path": {
			"id": ACT_2_BOSS_THREE_CHOICE_PATH,
			"content_id": ACT_2_BOSS_POOL_CONTENT_ID,
			"availability_status": "AVAILABLE" if act_two_boss_reward_available else "NOT_AVAILABLE",
			"coverage_status": str(reward_status.get("coverage_status", "NOT_COVERED")),
		},
		"act_2_boss_reward_to_summary_boundary": {
			"id": ACT_2_SUMMARY_BOUNDARY,
			"availability_status": "AVAILABLE" if act_two_boss_reward_available else "BLOCKED_BY_UNAVAILABLE_ACT_2_BOSS_REWARD_POOL",
			"coverage_status": "COVERED" if act_two_boundary_observed else "NOT_COVERED",
		},
		"unavailable_content_ids": gate_aggregate.get("unavailable_content_ids", []).duplicate(),
	}

func _requirement_status(coverage_detail: Dictionary, requirement_id: String) -> Dictionary:
	for status_value in coverage_detail.get("requirement_statuses", []):
		if status_value is Dictionary and str(status_value.get("id", "")) == requirement_id:
			return status_value
	return {}

func _attempt_summary(attempt: Dictionary) -> Dictionary:
	return {
		"attempt_id": str(attempt.get("attempt_id", "")),
		"seed": int(attempt.get("seed", 0)),
		"policy_id": str(attempt.get("policy_id", "")),
		"act_reached": int(attempt.get("act_reached", 0)),
		"terminal": bool(attempt.get("terminal", false)),
		"outcome": str(attempt.get("outcome", "")),
		"accepted_command_count": int(attempt.get("accepted_command_count", 0)),
		"checkpoint_count": attempt.get("checkpoints", []).size(),
		"replay_status": str(attempt.get("replay_status", "")),
		"failure_classification": str(attempt.get("failure_classification", "")),
	}

func _write_jsonl_record(file: FileAccess, record: Dictionary) -> Error:
	file.store_string(JSON.stringify(record, "", true, true) + "\n")
	file.flush()
	return file.get_error()

func _fail(message: String, exit_code: int) -> void:
	push_error(message)
	quit(exit_code)
