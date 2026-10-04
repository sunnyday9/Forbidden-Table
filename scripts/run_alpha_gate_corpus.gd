extends SceneTree

const SimulationManifestScript = preload("res://src/infrastructure/simulation/simulation_manifest.gd")
const AlphaSimulationRunnerScript = preload("res://src/infrastructure/simulation/alpha_simulation_runner.gd")
const AlphaAttemptComparatorScript = preload("res://src/infrastructure/simulation/alpha_attempt_comparator.gd")
const ResumeVerifierScript = preload("res://src/infrastructure/simulation/simulation_corpus_resume_verifier.gd")
const SimulationGateRunnerScript = preload("res://src/infrastructure/simulation/simulation_gate_runner.gd")
const AlphaSimulationStartingPoolFixtureScript = preload("res://src/infrastructure/simulation/alpha_simulation_starting_pool_fixture.gd")
const GnuTimeoutLocatorScript = preload("res://src/infrastructure/simulation/gnu_timeout_locator.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const SnapshotDtoScript = preload("res://src/infrastructure/persistence/snapshot_dto.gd")
const MetaProgressSnapshotScript = preload("res://src/infrastructure/persistence/meta_progress_snapshot.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")

const REPORT_SCHEMA := "alpha.gate-corpus-jsonl.v3"
const OUTLIER_DISPOSITION_SCHEMA := "alpha.gate-corpus-outlier-dispositions.v1"
const VALID_OUTLIER_DISPOSITIONS := ["ACCEPTED_AS_DESIGNED", "REMEDIATION_REQUIRED", "RETEST_REQUIRED"]
const GATE_ID := "stage4_beta"
const BASELINE_SEED_START := 57000
const COMMAND_LIMIT := 1024
const ATTEMPT_TIMEOUT_MSEC := 120000
const MAX_CASES_PER_CHUNK := 20
const DEFAULT_CASES_PER_CHUNK := 4
const PROCESS_TIMEOUT_KILL_AFTER_SECONDS := 30
const BASELINE_POLICIES := ["Partial", "Complete", "Hybrid"]
const BASELINE_ROUTES := ["SERVICE", "EVENT"]
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
const RUNTIME_SOURCE_ROOTS := ["res://src", "res://scenes", "res://scripts"]
const RUNTIME_SOURCE_SNAPSHOT_SCOPE := "SHA-256 of every non-UID file recursively under src/, scenes/, and scripts/, plus project.godot. This identifies the runtime code/content/config snapshot; tests, docs, .godot, and .cache are excluded."
const BASE_GIT_REVISION := "54a8d09635a6ab136ac3c1ce10bca4508799053b"

func _initialize() -> void:
	var options := _parse_arguments(OS.get_cmdline_user_args())
	if options.has("error"):
		_fail(str(options.error), 2)
		return
	if str(options.gate_id) != GATE_ID:
		_fail("--gate must be stage4_beta.", 2)
		return
	var output_path := str(options.output_path)
	var manifest_path := str(options.manifest_path)
	var report_path := str(options.report_path)
	var disposition_path := str(options.outlier_disposition_path)
	if not output_path.is_absolute_path() or not manifest_path.is_absolute_path():
		_fail("--output and --manifest-output must be absolute caller-supplied paths.", 2)
		return
	if output_path == manifest_path or (not report_path.is_empty() and (output_path == report_path or manifest_path == report_path)):
		_fail("--output, --manifest-output, and --report-output must be different files.", 2)
		return
	if not disposition_path.is_empty() and (
		not disposition_path.is_absolute_path()
		or not FileAccess.file_exists(disposition_path)
		or disposition_path in [output_path, manifest_path, report_path]
	):
		_fail("--outlier-disposition-file must be a new input file at an absolute path distinct from all output artifacts.", 2)
		return
	if not bool(options.finalize) and not disposition_path.is_empty():
		_fail("--outlier-disposition-file is only valid with --finalize.", 2)
		return
	if FileAccess.file_exists(output_path):
		_fail("Refusing to overwrite the existing output path: %s" % output_path, 2)
		return
	if not DirAccess.dir_exists_absolute(output_path.get_base_dir()) or not DirAccess.dir_exists_absolute(manifest_path.get_base_dir()):
		_fail("Create the parent directories for --output and --manifest-output before running a chunk.", 2)
		return
	for resume_path_value in options.resume_paths:
		var resume_path := str(resume_path_value)
		if not resume_path.is_absolute_path() or not FileAccess.file_exists(resume_path):
			_fail("Every --resume-from value must identify an existing absolute JSONL file.", 2)
			return
		if resume_path == output_path:
			_fail("--resume-from and --output must be different files; source chunks are preserved.", 2)
			return

	var manifest = _build_manifest()
	if manifest == null:
		return
	var manifest_data: Dictionary = manifest.to_dictionary()
	var manifest_hash := str(manifest.manifest_hash())
	var manifest_write_error := _write_manifest_file(manifest_path, manifest_data)
	if manifest_write_error != OK:
		_fail("Could not create or validate the manifest artifact %s: %s" % [manifest_path, error_string(manifest_write_error)], 2)
		return
	var gate_profile: Dictionary = manifest_data.get("gates", {}).get(GATE_ID, {})
	var cases: Array = gate_profile.get("cases", [])
	if cases.size() != SimulationManifestScript.RUNS_REQUIRED_PER_GATE:
		_fail("The Stage 4 Beta manifest did not produce exactly 1,000 cases.", 2)
		return
	var current_build := _build_metadata(str(manifest_data.get("content_version", "")))
	if current_build.is_empty():
		return
	if bool(options.finalize):
		if not report_path.is_absolute_path() or FileAccess.file_exists(report_path) or not DirAccess.dir_exists_absolute(report_path.get_base_dir()):
			_fail("--finalize requires a new absolute --report-output path in an existing directory.", 2)
			return
	elif not report_path.is_empty():
		_fail("--report-output is only valid with --finalize.", 2)
		return

	var accumulator := SimulationGateRunnerScript.new_streaming_accumulator(gate_profile)
	var resume_state := {"case_count": 0, "repeat_matches": 0, "repeat_divergences": [], "outliers": [], "source_chunks": []}
	var resume_error := _consume_resume_chunks(
		options.resume_paths,
		cases,
		manifest_hash,
		manifest_data,
		current_build,
		accumulator,
		resume_state,
		bool(options.smoke),
	)
	if not str(resume_error).is_empty():
		_fail(str(resume_error), 2)
		return
	var case_count_at_start := int(resume_state.case_count)
	if bool(options.smoke) and case_count_at_start > 0:
		_fail("Smoke runs cannot resume or append to another chunk.", 2)
		return
	if case_count_at_start > cases.size():
		_fail("Resume inputs contain more cases than the 1,000-case manifest.", 2)
		return
	if bool(options.finalize) and case_count_at_start != cases.size():
		_fail("--finalize requires exactly 1,000 previously completed case records.", 2)
		return
	var outlier_review := _resolve_outlier_dispositions(resume_state, disposition_path)
	if not str(outlier_review.get("error", "")).is_empty():
		_fail(str(outlier_review.error), 2)
		return

	var new_case_limit := 1 if bool(options.smoke) else int(options.max_cases)
	var cases_to_run := 0 if bool(options.finalize) else mini(new_case_limit, cases.size() - case_count_at_start)
	if not bool(options.smoke) and not bool(options.finalize):
		if not bool(options.process_timeout_enforced):
			_fail("Full chunks require --process-timeout-enforced and an external GNU timeout wrapper.", 2)
			return
		if _resolved_timeout_executable_path().is_empty():
			_fail("Full chunks require GNU timeout to be resolvable to an absolute executable path.", 2)
			return
		var worst_case_seconds := ceili(float(cases_to_run * 2 * ATTEMPT_TIMEOUT_MSEC) / 1000.0) + PROCESS_TIMEOUT_KILL_AFTER_SECONDS
		if int(options.process_timeout_seconds) < worst_case_seconds:
			_fail("--process-timeout-seconds must be at least %d for this chunk's two attempts per case." % worst_case_seconds, 2)
			return
	if bool(options.finalize) and not bool(options.process_timeout_enforced):
		_fail("--finalize requires --process-timeout-enforced after all bounded chunks used process timeouts.", 2)
		return
	if bool(options.finalize) and _resolved_timeout_executable_path().is_empty():
		_fail("--finalize requires GNU timeout to be resolvable to an absolute executable path.", 2)
		return

	var output_file := FileAccess.open(output_path, FileAccess.WRITE)
	if output_file == null:
		_fail("Could not open the explicit output path %s: %s" % [output_path, error_string(FileAccess.get_open_error())], 2)
		return
	var header_record := _build_header(
		options,
		manifest_data,
		manifest_hash,
		manifest_path,
		current_build,
		case_count_at_start,
		cases_to_run,
		resume_state.source_chunks,
	)
	var write_error := _write_jsonl_record(output_file, header_record)
	if write_error != OK:
		output_file.close()
		_fail("Could not write the corpus chunk header: %s" % error_string(write_error), 2)
		return

	for index in range(case_count_at_start, case_count_at_start + cases_to_run):
		var attempt_case: Dictionary = cases[index]
		var attempt := AlphaSimulationRunnerScript.new().run_attempt(
			attempt_case,
			manifest_hash,
			COMMAND_LIMIT,
			ATTEMPT_TIMEOUT_MSEC,
		)
		var repeated_attempt := AlphaSimulationRunnerScript.new().run_attempt(
			attempt_case,
			manifest_hash,
			COMMAND_LIMIT,
			ATTEMPT_TIMEOUT_MSEC,
		)
		var comparison: Dictionary = AlphaAttemptComparatorScript.compare(attempt, repeated_attempt)
		var attempt_summary: Dictionary = ResumeVerifierScript.summarize_compact_attempt(attempt, GATE_ID)
		var repeated_summary: Dictionary = ResumeVerifierScript.summarize_compact_attempt(repeated_attempt, GATE_ID)
		SimulationGateRunnerScript.accumulate_summary(accumulator, attempt_summary)
		_track_case_report_details(index + 1, attempt_summary, repeated_summary, comparison, resume_state, options)
		var case_record := {
			"record_type": "case",
			"case_number": index + 1,
			"manifest_hash": manifest_hash,
			"attempt_case": attempt_case.duplicate(true),
			"attempt_summary": attempt_summary,
			"repeat_attempt_summary": repeated_summary,
			"repeat_comparison": comparison,
		}
		write_error = _write_jsonl_record(output_file, case_record)
		if write_error != OK:
			output_file.close()
			_fail("Could not flush corpus case %d: %s" % [index + 1, error_string(write_error)], 2)
			return
		if not bool(options.smoke) and (index + 1) % 10 == 0:
			print("Executed and repeated %d / %d declared cases." % [index + 1, cases.size()])
	if bool(options.smoke):
		outlier_review = _resolve_outlier_dispositions(resume_state, "")

	var total_case_count := case_count_at_start + cases_to_run
	var corpus_complete := total_case_count == cases.size() and not bool(options.smoke) and bool(options.finalize)
	var all_cases_present := total_case_count == cases.size() and not bool(options.smoke)
	var smoke_complete := total_case_count == 1 and bool(options.smoke)
	var simulation_gate_pass := false
	var simulation_gate_status := "SMOKE_ONLY_NOT_GATE_EVIDENCE"
	var summary_record: Dictionary = {}
	if corpus_complete or smoke_complete:
		var gate_aggregate: Dictionary = SimulationGateRunnerScript.finish_streaming_aggregate(accumulator)
		var repeat_checks_pass: bool = int(resume_state.repeat_matches) == total_case_count and resume_state.repeat_divergences.is_empty()
		simulation_gate_pass = corpus_complete and repeat_checks_pass and bool(gate_aggregate.get("gate_pass", false)) and bool(outlier_review.get("gate_clear", false))
		if corpus_complete:
			if not repeat_checks_pass:
				simulation_gate_status = "REPEAT_COMPARISON_FAILURE"
			elif bool(gate_aggregate.get("gate_pass", false)) and not bool(outlier_review.get("gate_clear", false)):
				simulation_gate_status = str(outlier_review.get("status", "CONTENT_OWNER_REVIEW_PENDING"))
			else:
				simulation_gate_status = str(gate_aggregate.get("gate_status", "FAIL"))
		summary_record = {
			"record_type": "summary",
			"schema": REPORT_SCHEMA,
			"run_state": "COMPLETE" if corpus_complete else "SMOKE_COMPLETE_NOT_GATE_EVIDENCE",
			"completion_status": "COMPLETE_1000_CASE_CORPUS" if corpus_complete else "SMOKE_NON_GATE_EVIDENCE",
			"report_scope": "STAGE4_BETA_SEEDED_SIMULATION_SUBGATE_ONLY",
			"evidence_class": "FULL_STAGE4_BETA_CORPUS" if corpus_complete else "SMOKE_NON_GATE_EVIDENCE",
			"gate_id": GATE_ID,
			"simulation_gate_status": simulation_gate_status,
			"simulation_gate_pass": simulation_gate_pass,
			"gate_evidence_eligible": corpus_complete and bool(options.process_timeout_enforced),
			"overall_readiness_or_hardening_decision": "NOT_EVALUATED_BY_THIS_CORPUS",
			"manifest_hash": manifest_hash,
			"manifest_artifact": manifest_path,
			"manifest_artifact_sha256": _sha256_file(manifest_path),
			"summary_artifact_path": output_path,
			"build": current_build,
			"execution": _execution_metadata(options, total_case_count, int(resume_state.repeat_matches)),
			"source_chunks": resume_state.source_chunks,
			"process_status_summary": {
				"verified_chunk_count": resume_state.source_chunks.size(),
				"process_timeout_count": 0,
				"nonzero_process_exit_count": 0,
			},
			"policy_outcomes": gate_aggregate.get("policy_outcome_counts", {}),
			"strategy_distributions": gate_aggregate.get("strategy_distributions", {}),
			"terminal_outcome_counts": gate_aggregate.get("terminal_outcome_counts", {}),
			"repeat_divergences": resume_state.repeat_divergences,
			"content_owner_review": outlier_review,
			"visible_outlier_policy": "List every repeat divergence, gate validation error, non-NONE attempt classification, unavailable content result, attempt using at least half the watchdog budget, or attempt using at least 75% of the command budget. Each visible outlier requires a recorded content-owner disposition before this subgate can pass.",
			"visible_outliers": resume_state.outliers,
			"act_2_coverage": _act_two_coverage(gate_aggregate),
			"gate_aggregation": gate_aggregate,
			"performance_evidence_scope": "No player-duration or device-performance evidence is claimed; elapsed_msec is only an attempt-watchdog diagnostic.",
		}
		write_error = _write_jsonl_record(output_file, summary_record)
		if write_error != OK:
			output_file.close()
			_fail("Could not write the final corpus summary: %s" % error_string(write_error), 2)
			return
	output_file.close()
	if corpus_complete:
		var summary_sha256 := _sha256_file(output_path)
		var report_error := _write_markdown_report(report_path, summary_record, summary_sha256)
		if report_error != OK:
			_fail("The corpus summary was written, but report.md could not be written: %s" % error_string(report_error), 2)
			return
		print("ALPHA_GATE_ARTIFACTS manifest_sha256=%s summary_jsonl_sha256=%s report_md_sha256=%s" % [
			str(summary_record.get("manifest_artifact_sha256", "")),
			summary_sha256,
			_sha256_file(report_path),
		])

	if corpus_complete:
		print("ALPHA_GATE_CORPUS gate=%s cases=%d/%d simulation_gate_status=%s simulation_gate_pass=%s output=%s" % [
			GATE_ID,
			total_case_count,
			cases.size(),
			simulation_gate_status,
			str(simulation_gate_pass),
			output_path,
		])
		quit(0 if simulation_gate_pass else 1)
	elif smoke_complete:
		print("ALPHA_GATE_CORPUS gate=%s mode=smoke cases=1/%d output=%s" % [GATE_ID, cases.size(), output_path])
		quit(0)
	else:
		print("ALPHA_GATE_CORPUS gate=%s chunk_cases=%d cumulative_cases=%d/%d output=%s run_state=IN_PROGRESS gate_evidence_eligible=false" % [
			GATE_ID,
			cases_to_run,
			total_case_count,
			cases.size(),
			output_path,
		])
		quit(0)

func _parse_arguments(arguments: Array[String]) -> Dictionary:
	var result := {
		"output_path": "",
		"manifest_path": "",
		"report_path": "",
		"resume_paths": [],
		"gate_id": GATE_ID,
		"smoke": false,
		"full": false,
		"finalize": false,
		"mode_selected": false,
		"max_cases": DEFAULT_CASES_PER_CHUNK,
		"process_timeout_seconds": 0,
		"process_timeout_enforced": false,
		"outlier_disposition_path": "",
	}
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		if argument == "--smoke" or argument == "--full":
			if bool(result.mode_selected):
				return {"error": "Choose exactly one mode: --smoke or --full."}
			result.mode_selected = true
			result.smoke = argument == "--smoke"
			result.full = argument == "--full"
		elif argument == "--finalize":
			result.finalize = true
		elif argument == "--process-timeout-enforced":
			result.process_timeout_enforced = true
		elif argument in ["--output", "--manifest-output", "--report-output", "--outlier-disposition-file", "--gate", "--resume-from", "--max-cases", "--process-timeout-seconds"]:
			if index + 1 >= arguments.size():
				return {"error": "%s requires a value." % argument}
			index += 1
			var value := arguments[index]
			match argument:
				"--output":
					result.output_path = value
				"--manifest-output":
					result.manifest_path = value
				"--report-output":
					result.report_path = value
				"--outlier-disposition-file":
					result.outlier_disposition_path = value
				"--gate":
					result.gate_id = value
				"--resume-from":
					result.resume_paths.append(value)
				"--max-cases":
					if not value.is_valid_int():
						return {"error": "--max-cases must be an integer from 1 through %d." % MAX_CASES_PER_CHUNK}
					result.max_cases = int(value)
				"--process-timeout-seconds":
					if not value.is_valid_int():
						return {"error": "--process-timeout-seconds must be a positive integer."}
					result.process_timeout_seconds = int(value)
		elif argument.begins_with("--output="):
			result.output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--manifest-output="):
			result.manifest_path = argument.trim_prefix("--manifest-output=")
		elif argument.begins_with("--report-output="):
			result.report_path = argument.trim_prefix("--report-output=")
		elif argument.begins_with("--outlier-disposition-file="):
			result.outlier_disposition_path = argument.trim_prefix("--outlier-disposition-file=")
		elif argument.begins_with("--gate="):
			result.gate_id = argument.trim_prefix("--gate=")
		elif argument.begins_with("--max-cases="):
			var value := argument.trim_prefix("--max-cases=")
			if not value.is_valid_int():
				return {"error": "--max-cases must be an integer from 1 through %d." % MAX_CASES_PER_CHUNK}
			result.max_cases = int(value)
		elif argument.begins_with("--process-timeout-seconds="):
			var value := argument.trim_prefix("--process-timeout-seconds=")
			if not value.is_valid_int():
				return {"error": "--process-timeout-seconds must be a positive integer."}
			result.process_timeout_seconds = int(value)
		else:
			return {"error": "Unknown argument: %s" % argument}
		index += 1
	if str(result.output_path).is_empty():
		return {"error": "An explicit output file is required. Use --output /absolute/path/chunk.jsonl."}
	if str(result.manifest_path).is_empty():
		result.manifest_path = str(result.output_path) + ".manifest.json"
	if not bool(result.mode_selected):
		return {"error": "Choose --smoke or --full."}
	if bool(result.smoke) and (bool(result.finalize) or not result.resume_paths.is_empty()):
		return {"error": "Smoke runs cannot be finalized or resumed."}
	if bool(result.smoke) and (int(result.max_cases) != DEFAULT_CASES_PER_CHUNK or int(result.process_timeout_seconds) > 0 or bool(result.process_timeout_enforced)):
		return {"error": "Chunk and process-timeout flags are only valid for full runs."}
	if not bool(result.full) and (bool(result.finalize) or not result.resume_paths.is_empty()):
		return {"error": "Resume and finalize operations require --full."}
	if int(result.max_cases) < 1 or int(result.max_cases) > MAX_CASES_PER_CHUNK:
		return {"error": "--max-cases must be an integer from 1 through %d." % MAX_CASES_PER_CHUNK}
	if bool(result.full) and not bool(result.finalize) and int(result.process_timeout_seconds) <= 0:
		return {"error": "Full chunks require --process-timeout-seconds."}
	if bool(result.full) and bool(result.finalize) and int(result.process_timeout_seconds) <= 0:
		return {"error": "--finalize requires --process-timeout-seconds."}
	if bool(result.finalize) and str(result.report_path).is_empty():
		return {"error": "--finalize requires --report-output /absolute/path/report.md."}
	if not bool(result.finalize) and not str(result.report_path).is_empty():
		return {"error": "--report-output is only valid with --finalize."}
	return result

func _build_manifest():
	var character_ids: Array[String] = AlphaScaleCatalogScript.all_character_ids()
	var contract_ids: Array[String] = AlphaScaleCatalogScript.all_contract_ids()
	if character_ids.size() != 3 or contract_ids.size() != 8:
		_fail("The current Stage 4 Beta catalog is not the required 3-Character/8-Contract roster.", 2)
		return null
	var config := {
		"schema_version": SimulationManifestScript.SCHEMA_VERSION,
		"content_version": AlphaSimulationRunnerScript.content_version_for_gate(GATE_ID),
		"starting_pool_fixture_id": AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID,
		"gate_profiles": [{
			"gate_id": GATE_ID,
			"attempt_count": SimulationManifestScript.RUNS_REQUIRED_PER_GATE,
			"seed_start": BASELINE_SEED_START,
			"policy_ids": BASELINE_POLICIES,
			"character_ids": character_ids,
			"contract_ids": contract_ids,
			"route_ids": BASELINE_ROUTES,
			"required_character_ids": character_ids,
			"required_contract_ids": contract_ids,
			"required_policy_ids": BASELINE_POLICIES,
			"required_act_boundaries": REQUIRED_ACT_BOUNDARIES,
			"required_reward_paths": REQUIRED_REWARD_PATHS,
			"available_reward_paths": AVAILABLE_REWARD_PATHS,
			"not_yet_introduced_reward_paths": [],
			"not_yet_introduced_content_ids": [],
			"content_use_catalog": SimulationManifestScript.stage4_beta_content_use_catalog(),
		}],
	}
	var manifest = SimulationManifestScript.new(config, character_ids, contract_ids)
	if not manifest.is_valid():
		_fail("The Stage 4 Beta manifest is invalid: %s" % ", ".join(manifest.errors()), 2)
		return null
	return manifest

func _write_manifest_file(path: String, manifest_data: Dictionary) -> Error:
	var serialized := JSON.stringify(manifest_data, "\t", true, true) + "\n"
	if FileAccess.file_exists(path):
		var existing = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not existing is Dictionary:
			return ERR_ALREADY_EXISTS
		var stored_manifest: Dictionary = existing
		var stored_hash := str(stored_manifest.get("manifest_hash", ""))
		var stored_payload := stored_manifest.duplicate(true)
		stored_payload.erase("manifest_hash")
		var current_payload := manifest_data.duplicate(true)
		current_payload.erase("manifest_hash")
		if (
			stored_hash != str(manifest_data.get("manifest_hash", ""))
			or stored_hash != _canonical_hash(stored_payload)
			or _canonical_hash(stored_manifest) != _canonical_hash(manifest_data)
			or _canonical_hash(current_payload) != str(manifest_data.get("manifest_hash", ""))
		):
			return ERR_ALREADY_EXISTS
		return OK
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(serialized)
	file.flush()
	var result := file.get_error()
	file.close()
	return result

func _build_header(
	options: Dictionary,
	manifest_data: Dictionary,
	manifest_hash: String,
	manifest_path: String,
	build_data: Dictionary,
	case_count_at_start: int,
	cases_to_run: int,
	resume_source_chunks: Array,
) -> Dictionary:
	var execution := _execution_metadata(options, case_count_at_start, 0)
	execution["start_case_number"] = case_count_at_start + 1
	execution["new_case_limit"] = cases_to_run
	return {
		"record_type": "header",
		"schema": REPORT_SCHEMA,
		"record_format": "JSON Lines; one compact case record per declared attempt; full traces are discarded after exact repeat comparison.",
		"run_state": "IN_PROGRESS",
		"report_scope": "STAGE4_BETA_SEEDED_SIMULATION_SUBGATE_ONLY",
		"evidence_class": "SMOKE_NON_GATE_EVIDENCE" if bool(options.smoke) else "FULL_STAGE4_BETA_CORPUS_CHUNK",
		"gate_id": GATE_ID,
		"gate_evidence_eligible": false,
		"overall_readiness_or_hardening_decision": "NOT_EVALUATED_BY_THIS_CORPUS",
		"manifest_hash": manifest_hash,
		"manifest_artifact": manifest_path,
		"manifest_schema_version": SimulationManifestScript.SCHEMA_VERSION,
		"manifest": manifest_data,
		"build": build_data,
		"resume_source_chunks": resume_source_chunks,
		"execution": execution,
	}

func _execution_metadata(options: Dictionary, cumulative_case_count: int, repeat_matches: int) -> Dictionary:
	return {
		"mode": "STAGE4_BETA_1000_CASE_CORPUS",
		"manifest_case_count": SimulationManifestScript.RUNS_REQUIRED_PER_GATE,
		"expected_case_records": SimulationManifestScript.RUNS_REQUIRED_PER_GATE,
		"cumulative_case_count_at_header": cumulative_case_count,
		"command_limit_per_attempt": COMMAND_LIMIT,
		"attempt_timeout_msec": ATTEMPT_TIMEOUT_MSEC,
		"attempts_per_case": 2,
		"process_timeout_seconds": int(options.process_timeout_seconds),
		"process_timeout_kill_after_seconds": PROCESS_TIMEOUT_KILL_AFTER_SECONDS,
		"process_timeout_enforced": bool(options.process_timeout_enforced),
		"timeout_executable_path": _resolved_timeout_executable_path(),
		"process_timeout_wrapper": "python3 scripts/run_alpha_gate_corpus_chunk.py --timeout-executable <resolved GNU Coreutils path>; it runs --signal=TERM --kill-after=%ds" % PROCESS_TIMEOUT_KILL_AFTER_SECONDS,
		"command": _recorded_timeout_command(options),
		"command_argv": _recorded_timeout_command_argv(options),
		"chunk_limit": int(options.max_cases),
		"smoke_only": bool(options.smoke),
		"starting_pool_fixture_id": AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID,
		"exact_repeats_match_so_far": repeat_matches,
	}

func _recorded_timeout_command(options: Dictionary) -> String:
	var project_path := ProjectSettings.globalize_path("res://")
	var parts: Array[String] = [
		_resolved_timeout_executable_path(),
		"--signal=TERM",
		"--kill-after=%ds" % PROCESS_TIMEOUT_KILL_AFTER_SECONDS,
		str(options.process_timeout_seconds),
		_shell_quote(OS.get_executable_path()),
		"--headless",
		"--path",
		_shell_quote(project_path),
		"--script",
		"res://scripts/run_alpha_gate_corpus.gd",
		"--",
	]
	for argument in OS.get_cmdline_user_args():
		parts.append(_shell_quote(argument))
	return " ".join(parts)

func _resolved_timeout_executable_path() -> String:
	return GnuTimeoutLocatorScript.resolve_path()

func _recorded_timeout_command_argv(options: Dictionary) -> Array[String]:
	var project_path := ProjectSettings.globalize_path("res://")
	var arguments: Array[String] = [
		_resolved_timeout_executable_path(),
		"--signal=TERM",
		"--kill-after=%ds" % PROCESS_TIMEOUT_KILL_AFTER_SECONDS,
		str(options.process_timeout_seconds),
		OS.get_executable_path(),
		"--headless",
		"--path",
		project_path,
		"--script",
		"res://scripts/run_alpha_gate_corpus.gd",
		"--",
	]
	for argument in OS.get_cmdline_user_args():
		arguments.append(str(argument))
	return arguments

func _build_metadata(content_version: String) -> Dictionary:
	var resource_paths: Array[String] = ["res://project.godot"]
	for source_root in RUNTIME_SOURCE_ROOTS:
		if not _collect_runtime_source_paths(str(source_root), resource_paths):
			_fail("Could not enumerate the complete runtime source root %s." % str(source_root), 2)
			return {}
	resource_paths.sort()
	var file_hashes: Dictionary = {}
	for resource_path in resource_paths:
		var absolute_path := ProjectSettings.globalize_path(resource_path)
		var file_hash := _sha256_file(absolute_path)
		if file_hash.is_empty():
			_fail("Could not read runtime source snapshot file %s." % resource_path, 2)
			return {}
		file_hashes[resource_path] = file_hash
	return {
		"project_version": str(ProjectSettings.get_setting("application/config/version", "UNKNOWN")),
		"game_version": SnapshotDtoScript.GAME_VERSION,
		"engine_version": Engine.get_version_info(),
		"content_version": content_version,
		"suspend_snapshot_schema_version": SnapshotDtoScript.SCHEMA_VERSION,
		"meta_progress_snapshot_schema_version": MetaProgressSnapshotScript.CURRENT_SCHEMA_VERSION,
		"replay_record_schema_version": ReplayRecordScript.SCHEMA_VERSION,
		"manifest_schema_version": SimulationManifestScript.SCHEMA_VERSION,
		"corpus_schema": REPORT_SCHEMA,
		"base_git_revision": BASE_GIT_REVISION,
		"source_snapshot_scope": RUNTIME_SOURCE_SNAPSHOT_SCOPE,
		"runtime_source_file_sha256": file_hashes,
		"runtime_source_snapshot_hash": _canonical_hash(file_hashes),
	}

func _collect_runtime_source_paths(resource_root: String, results: Array[String]) -> bool:
	var directory := DirAccess.open(resource_root)
	if directory == null:
		return false
	for file_name in directory.get_files():
		if str(file_name).ends_with(".uid"):
			continue
		results.append(resource_root.path_join(str(file_name)))
	for directory_name in directory.get_directories():
		if str(directory_name).begins_with("."):
			continue
		if not _collect_runtime_source_paths(resource_root.path_join(str(directory_name)), results):
			return false
	return true

func _consume_resume_chunks(
	paths: Array,
	cases: Array,
	manifest_hash: String,
	manifest_data: Dictionary,
	current_build: Dictionary,
	accumulator: Dictionary,
	resume_state: Dictionary,
	smoke_mode: bool,
) -> String:
	var seen_paths := {}
	for path_value in paths:
		var path := str(path_value)
		if seen_paths.has(path):
			return "A resume chunk was listed more than once: %s" % path
		seen_paths[path] = true
		var source := FileAccess.open(path, FileAccess.READ)
		if source == null:
			return "Could not open resume chunk %s: %s" % [path, error_string(FileAccess.get_open_error())]
		var source_hash_before := _sha256_file(path)
		var status_path := path + ".status.json"
		var status_hash_before := _sha256_file(status_path)
		if source_hash_before.is_empty():
			source.close()
			return "Resume chunk %s could not be hashed." % path
		if status_hash_before.is_empty():
			source.close()
			return "Resume chunk %s is missing its GNU timeout process-status sidecar %s." % [path, status_path]
		var status_value = JSON.parse_string(FileAccess.get_file_as_string(status_path))
		if not status_value is Dictionary:
			source.close()
			return "Resume chunk %s has a malformed process-status sidecar." % path
		var process_status: Dictionary = status_value
		var header_line := source.get_line()
		var header_value = JSON.parse_string(header_line)
		if not header_value is Dictionary:
			source.close()
			return "Resume source %s does not begin with a valid JSON header." % path
		var header: Dictionary = header_value
		var execution: Dictionary = header.get("execution", {})
		var embedded_manifest_value = header.get("manifest", {})
		var embedded_build_value = header.get("build", {})
		var embedded_source_chunks_value = header.get("resume_source_chunks", [])
		if (
			str(header.get("record_type", "")) != "header"
			or str(header.get("schema", "")) != REPORT_SCHEMA
			or str(header.get("run_state", "")) != "IN_PROGRESS"
			or str(header.get("gate_id", "")) != GATE_ID
			or str(header.get("manifest_hash", "")) != manifest_hash
			or str(execution.get("mode", "")) != "STAGE4_BETA_1000_CASE_CORPUS"
			or bool(execution.get("smoke_only", false))
			or not bool(execution.get("process_timeout_enforced", false))
		):
			source.close()
			return "Resume chunk %s is not an incomplete, timeout-bounded Stage 4 Beta corpus chunk for this manifest." % path
		if (
			not embedded_manifest_value is Dictionary
			or str(embedded_manifest_value.get("manifest_hash", "")) != manifest_hash
			or _canonical_hash(embedded_manifest_value) != _canonical_hash(manifest_data)
		):
			source.close()
			return "Resume chunk %s embeds a manifest that differs from the current canonical manifest." % path
		if (
			not embedded_build_value is Dictionary
			or _canonical_hash(embedded_build_value) != _canonical_hash(current_build)
			or str(embedded_build_value.get("content_version", "")) != str(current_build.get("content_version", ""))
			or str(embedded_build_value.get("game_version", "")) != str(current_build.get("game_version", ""))
			or int(embedded_build_value.get("suspend_snapshot_schema_version", -1)) != int(current_build.get("suspend_snapshot_schema_version", -2))
			or int(embedded_build_value.get("meta_progress_snapshot_schema_version", -1)) != int(current_build.get("meta_progress_snapshot_schema_version", -2))
			or int(embedded_build_value.get("replay_record_schema_version", -1)) != int(current_build.get("replay_record_schema_version", -2))
			or int(embedded_build_value.get("manifest_schema_version", -1)) != int(current_build.get("manifest_schema_version", -2))
			or str(embedded_build_value.get("corpus_schema", "")) != str(current_build.get("corpus_schema", ""))
			or str(embedded_build_value.get("runtime_source_snapshot_hash", "")) != str(current_build.get("runtime_source_snapshot_hash", ""))
		):
			source.close()
			return "Resume chunk %s build metadata or runtime source snapshot differs from the current build." % path
		var prior_chunks_value: Array = embedded_source_chunks_value if embedded_source_chunks_value is Array else []
		if prior_chunks_value.size() != resume_state.source_chunks.size() or _canonical_hash(prior_chunks_value) != _canonical_hash(resume_state.source_chunks):
			source.close()
			return "Resume chunk %s source-chunk lineage differs from the ordered resume inputs." % path
		var chunk_limit := int(execution.get("chunk_limit", 0))
		var new_case_limit := int(execution.get("new_case_limit", 0))
		var process_timeout_seconds := int(execution.get("process_timeout_seconds", 0))
		var attempt_timeout_msec := int(execution.get("attempt_timeout_msec", 0))
		var expected_start := int(resume_state.case_count) + 1
		var worst_case_seconds := ceili(float(new_case_limit * 2 * attempt_timeout_msec) / 1000.0) + PROCESS_TIMEOUT_KILL_AFTER_SECONDS
		if (
			int(execution.get("start_case_number", -1)) != expected_start
			or chunk_limit < 1 or chunk_limit > MAX_CASES_PER_CHUNK
			or new_case_limit < 1 or new_case_limit > chunk_limit
			or attempt_timeout_msec != ATTEMPT_TIMEOUT_MSEC
			or int(execution.get("process_timeout_kill_after_seconds", 0)) != PROCESS_TIMEOUT_KILL_AFTER_SECONDS
			or process_timeout_seconds < worst_case_seconds
		):
			source.close()
			return "Resume chunk %s has an invalid range or insufficient recorded process/watchdog timeout bounds." % path
		var expected_command_argv_value = execution.get("command_argv", [])
		var status_command_argv_value = process_status.get("command_argv", [])
		var timeout_executable_path := str(process_status.get("timeout_executable_path", ""))
		var timeout_command_matches: bool = (
			expected_command_argv_value is Array
			and status_command_argv_value is Array
			and not timeout_executable_path.is_empty()
			and timeout_executable_path.is_absolute_path()
			and FileAccess.file_exists(timeout_executable_path)
			and not expected_command_argv_value.is_empty()
			and not status_command_argv_value.is_empty()
			and str(expected_command_argv_value[0]) == timeout_executable_path
			and str(status_command_argv_value[0]) == timeout_executable_path
		)
		if (
			str(process_status.get("schema", "")) != "alpha.gate-corpus-process-status.v1"
			or int(process_status.get("process_exit_code", -1)) != 0
			or str(process_status.get("timeout_implementation", "")) != "GNU coreutils timeout"
			or not str(process_status.get("timeout_version", "")).contains("GNU coreutils")
			or int(process_status.get("timeout_seconds", 0)) != process_timeout_seconds
			or int(process_status.get("kill_after_seconds", 0)) != PROCESS_TIMEOUT_KILL_AFTER_SECONDS
			or str(process_status.get("output_path", "")) != path
			or str(process_status.get("output_sha256", "")) != source_hash_before
			or not expected_command_argv_value is Array
			or not status_command_argv_value is Array
			or not timeout_command_matches
			or _canonical_hash(expected_command_argv_value) != _canonical_hash(status_command_argv_value)
		):
			source.close()
			return "Resume chunk %s has a missing, nonzero, timed-out, or mismatched GNU process-status record." % path
		var case_start := expected_start
		var had_truncated_final_record := false
		while not source.eof_reached():
			var source_line := source.get_line()
			if source_line.is_empty():
				continue
			var record_value = JSON.parse_string(source_line)
			if not record_value is Dictionary:
				if source.eof_reached() and not _file_ends_in_newline(path):
					print("Ignoring one truncated final JSONL record in %s; its case will be rerun." % path)
					had_truncated_final_record = true
					break
				source.close()
				return "Resume chunk %s contains a malformed nonfinal JSONL record." % path
			var record: Dictionary = record_value
			if str(record.get("record_type", "")) == "summary":
				source.close()
				return "Completed report %s cannot be resumed as an incomplete chunk." % path
			var case_index := int(resume_state.case_count)
			if case_index >= cases.size():
				source.close()
				return "Resume inputs contain more than the 1,000 manifest cases."
			var expected_case: Dictionary = cases[case_index]
			var validation: Dictionary = ResumeVerifierScript.validate_record(record, expected_case, manifest_hash, case_index + 1)
			if not bool(validation.get("valid", false)):
				source.close()
				return "Resume case %d failed validation: %s." % [case_index + 1, ", ".join(validation.get("errors", []))]
			if str(record.get("manifest_hash", "")) != manifest_hash:
				source.close()
				return "Resume case %d has the wrong manifest hash." % [case_index + 1]
			var attempt_summary: Dictionary = record.get("attempt_summary", {})
			SimulationGateRunnerScript.accumulate_summary(accumulator, attempt_summary)
			_track_case_report_details(
				case_index + 1,
				attempt_summary,
				record.get("repeat_attempt_summary", {}),
				record.get("repeat_comparison", {}),
				resume_state,
				{"process_timeout_seconds": execution.get("process_timeout_seconds", 0)},
			)
			resume_state.case_count = case_index + 1
		source.close()
		var source_hash_after := _sha256_file(path)
		if source_hash_before.is_empty() or source_hash_after != source_hash_before:
			return "Resume source chunk %s changed while it was being read." % path
		var status_hash_after := _sha256_file(status_path)
		if status_hash_after != status_hash_before:
			return "Resume chunk process-status sidecar %s changed while it was being read." % status_path
		var contributed_cases := int(resume_state.case_count) - (case_start - 1)
		if contributed_cases > new_case_limit:
			return "Resume chunk %s contains more case records than its declared chunk limit." % path
		resume_state.source_chunks.append({
			"path": path,
			"sha256": source_hash_before,
			"process_status_path": status_path,
			"process_status_sha256": status_hash_before,
			"process_exit_code": int(process_status.get("process_exit_code", -1)),
			"process_output_sha256": str(process_status.get("output_sha256", "")),
			"timeout_implementation": str(process_status.get("timeout_implementation", "")),
			"timeout_executable_path": timeout_executable_path,
			"case_start": case_start,
			"case_end": case_start + contributed_cases - 1,
			"case_count": contributed_cases,
			"truncated_final_record_discarded": had_truncated_final_record,
			"process_timeout_seconds": process_timeout_seconds,
			"attempt_timeout_msec": attempt_timeout_msec,
			"chunk_limit": chunk_limit,
			"command": str(process_status.get("command", execution.get("command", ""))),
			"command_argv": status_command_argv_value.duplicate(true),
		})
	if smoke_mode and not paths.is_empty():
		return "Smoke runs cannot use resume chunks."
	return ""

func _resolve_outlier_dispositions(report_state: Dictionary, disposition_path: String) -> Dictionary:
	var outliers: Array = report_state.get("outliers", [])
	if outliers.is_empty() and disposition_path.is_empty():
		return {
			"schema": OUTLIER_DISPOSITION_SCHEMA,
			"status": "NO_VISIBLE_OUTLIERS",
			"gate_clear": true,
			"visible_outlier_count": 0,
			"disposition_file_path": "",
			"disposition_file_sha256": "",
			"dispositions": [],
		}
	if disposition_path.is_empty():
		return {
			"schema": OUTLIER_DISPOSITION_SCHEMA,
			"status": "CONTENT_OWNER_REVIEW_PENDING",
			"gate_clear": false,
			"visible_outlier_count": outliers.size(),
			"disposition_file_path": "",
			"disposition_file_sha256": "",
			"dispositions": [],
		}
	var document_value = JSON.parse_string(FileAccess.get_file_as_string(disposition_path))
	if not document_value is Dictionary:
		return {"error": "The outlier disposition file must contain a JSON object."}
	var document: Dictionary = document_value
	if str(document.get("schema", "")) != OUTLIER_DISPOSITION_SCHEMA:
		return {"error": "The outlier disposition file has an unsupported schema."}
	var entries_value = document.get("dispositions", null)
	if not entries_value is Array:
		return {"error": "The outlier disposition file must contain a dispositions array."}
	var expected_cases := {}
	for outlier_value in outliers:
		if outlier_value is Dictionary:
			expected_cases[int(outlier_value.get("case_number", 0))] = true
	var decisions_by_case := {}
	for entry_value in entries_value:
		if not entry_value is Dictionary:
			return {"error": "Every outlier disposition must be an object."}
		var entry: Dictionary = entry_value
		var case_number := int(entry.get("case_number", 0))
		var owner := str(entry.get("owner", "")).strip_edges()
		var disposition := str(entry.get("disposition", ""))
		var rationale := str(entry.get("rationale", "")).strip_edges()
		if case_number < 1 or not expected_cases.has(case_number):
			return {"error": "The disposition file contains an unknown outlier case number %d." % case_number}
		if decisions_by_case.has(case_number):
			return {"error": "The disposition file repeats outlier case number %d." % case_number}
		if owner.is_empty() or not VALID_OUTLIER_DISPOSITIONS.has(disposition) or rationale.is_empty():
			return {"error": "Each disposition needs a non-empty owner and rationale and a supported disposition value."}
		decisions_by_case[case_number] = {
			"case_number": case_number,
			"owner": owner,
			"disposition": disposition,
			"rationale": rationale,
		}
	if decisions_by_case.size() != expected_cases.size():
		return {"error": "The disposition file must contain exactly one decision for each of the %d visible outliers." % expected_cases.size()}
	var decisions: Array[Dictionary] = []
	var gate_clear := true
	for case_number_value in expected_cases.keys():
		var case_number := int(case_number_value)
		var decision: Dictionary = decisions_by_case[case_number]
		decisions.append(decision)
		if str(decision.get("disposition", "")) != "ACCEPTED_AS_DESIGNED":
			gate_clear = false
	for outlier_value in outliers:
		if not outlier_value is Dictionary:
			continue
		var outlier: Dictionary = outlier_value
		var decision: Dictionary = decisions_by_case.get(int(outlier.get("case_number", 0)), {})
		outlier["owner_disposition"] = str(decision.get("disposition", ""))
		outlier["content_owner_decision"] = decision.duplicate(true)
		var attempts_value = outlier.get("attempts", [])
		if attempts_value is Array:
			for attempt_value in attempts_value:
				if not attempt_value is Dictionary:
					continue
				var attempt: Dictionary = attempt_value
				attempt["owner_disposition"] = str(decision.get("disposition", ""))
				attempt["content_owner_decision"] = decision.duplicate(true)
	for divergence_value in report_state.get("repeat_divergences", []):
		if not divergence_value is Dictionary:
			continue
		var divergence: Dictionary = divergence_value
		var decision: Dictionary = decisions_by_case.get(int(divergence.get("case_number", 0)), {})
		if not decision.is_empty():
			divergence["owner_disposition"] = str(decision.get("disposition", ""))
			divergence["content_owner_decision"] = decision.duplicate(true)
	decisions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("case_number", 0)) < int(right.get("case_number", 0)))
	return {
		"schema": OUTLIER_DISPOSITION_SCHEMA,
		"status": "DISPOSITIONED_ACCEPTED_AS_DESIGNED" if gate_clear else "CONTENT_OWNER_ACTION_REQUIRED",
		"gate_clear": gate_clear,
		"visible_outlier_count": outliers.size(),
		"disposition_file_path": disposition_path,
		"disposition_file_sha256": _sha256_file(disposition_path),
		"dispositions": decisions,
	}

func _track_case_report_details(case_number: int, attempt_summary: Dictionary, repeated_summary: Dictionary, comparison: Dictionary, report_state: Dictionary, options: Dictionary) -> void:
	if bool(comparison.get("matches", false)):
		report_state.repeat_matches = int(report_state.repeat_matches) + 1
	else:
		report_state.repeat_divergences.append({
			"case_number": case_number,
			"attempt_id": str(attempt_summary.get("attempt_id", "")),
			"status": str(comparison.get("status", "DIVERGED")),
			"differences": comparison.get("differences", []).duplicate(),
			"expected_projection_hash": str(comparison.get("expected_projection_hash", "")),
			"actual_projection_hash": str(comparison.get("actual_projection_hash", "")),
			"expected_field_hashes": comparison.get("expected_field_hashes", {}).duplicate(true),
			"actual_field_hashes": comparison.get("actual_field_hashes", {}).duplicate(true),
			"owner_disposition": "PENDING_CONTENT_OWNER_REVIEW",
		})
	var reasons: Array[String] = []
	var failure_classification := str(attempt_summary.get("failure_classification", ""))
	if failure_classification != "NONE":
		reasons.append("ATTEMPT_FAILURE:%s" % (failure_classification if not failure_classification.is_empty() else "UNCLASSIFIED"))
	var repeat_failure := str(repeated_summary.get("failure_classification", ""))
	if repeat_failure != "NONE":
		reasons.append("REPEAT_ATTEMPT_FAILURE:%s" % (repeat_failure if not repeat_failure.is_empty() else "UNCLASSIFIED"))
	var validation_errors: Array = attempt_summary.get("gate_validation_errors", []) if attempt_summary.get("gate_validation_errors", null) is Array else []
	if validation_errors is Array and not validation_errors.is_empty():
		reasons.append("GATE_VALIDATION_ERRORS")
	if not bool(attempt_summary.get("content_available", false)):
		reasons.append("CONTENT_UNAVAILABLE")
	var elapsed := int(attempt_summary.get("elapsed_msec", 0))
	if elapsed >= ATTEMPT_TIMEOUT_MSEC / 2:
		reasons.append("WATCHDOG_BUDGET_HALF_OR_MORE")
	var repeated_elapsed := int(repeated_summary.get("elapsed_msec", 0))
	if repeated_elapsed >= ATTEMPT_TIMEOUT_MSEC / 2:
		reasons.append("REPEAT_WATCHDOG_BUDGET_HALF_OR_MORE")
	var command_count := int(attempt_summary.get("accepted_command_count", 0))
	if command_count >= floori(float(COMMAND_LIMIT) * 0.75):
		reasons.append("COMMAND_BUDGET_75_PERCENT")
	if not bool(comparison.get("matches", false)):
		reasons.append("REPEAT_DIVERGENCE")
	if not reasons.is_empty():
		report_state.outliers.append({
			"case_number": case_number,
			"attempt_id": str(attempt_summary.get("attempt_id", "")),
			"policy_id": str(attempt_summary.get("policy_id", "")),
			"character_id": str(attempt_summary.get("character_id", "")),
			"contract_id": str(attempt_summary.get("contract_id", "")),
			"seed": int(attempt_summary.get("seed", 0)),
			"outcome": str(attempt_summary.get("outcome", "")),
			"reasons": reasons,
			"failure_classification": failure_classification,
			"failure_detail": str(attempt_summary.get("failure_detail", "")),
			"gate_validation_errors": validation_errors.duplicate() if validation_errors is Array else [],
			"elapsed_msec": elapsed,
			"accepted_command_count": command_count,
			"repeat_status": str(comparison.get("status", "")),
			"owner_disposition": "PENDING_CONTENT_OWNER_REVIEW",
			"attempts": [
				{
					"attempt_number": 1,
					"attempt_id": str(attempt_summary.get("attempt_id", "")),
					"elapsed_msec": elapsed,
					"accepted_command_count": command_count,
					"failure_classification": failure_classification,
					"failure_detail": str(attempt_summary.get("failure_detail", "")),
					"owner_disposition": "PENDING_CONTENT_OWNER_REVIEW",
				},
				{
					"attempt_number": 2,
					"attempt_id": str(repeated_summary.get("attempt_id", "")),
					"elapsed_msec": repeated_elapsed,
					"accepted_command_count": int(repeated_summary.get("accepted_command_count", 0)),
					"failure_classification": repeat_failure,
					"failure_detail": str(repeated_summary.get("failure_detail", "")),
					"owner_disposition": "PENDING_CONTENT_OWNER_REVIEW",
				},
			],
		})

func _file_ends_in_newline(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() == 0:
		if file != null:
			file.close()
		return false
	file.seek_end(-1)
	var ends_in_newline := file.get_8() == 10
	file.close()
	return ends_in_newline

func _act_two_coverage(gate_aggregate: Dictionary) -> Dictionary:
	var coverage: Dictionary = gate_aggregate.get("coverage", {})
	var acts: Dictionary = coverage.get("acts", {})
	var boss_outcomes: Dictionary = coverage.get("boss_outcomes", {})
	var reward_paths: Dictionary = coverage.get("reward_paths", {})
	var boundaries: Dictionary = coverage.get("act_boss_boundaries", {})
	var reward_status := _requirement_status(reward_paths, ACT_2_BOSS_THREE_CHOICE_PATH)
	var act_two_boundary_observed: bool = boundaries.get("observed_ids", []).has(ACT_2_SUMMARY_BOUNDARY)
	return {
		"act_2_observed": acts.get("observed_ids", []).has("ACT_2"),
		"act_2_boss_outcome_observed": boss_outcomes.get("observed_ids", []).has("ACT_2_BOSS"),
		"act_2_boss_three_choice_reward_path": {
			"id": ACT_2_BOSS_THREE_CHOICE_PATH,
			"content_id": ACT_2_BOSS_POOL_CONTENT_ID,
			"availability_status": "AVAILABLE" if AVAILABLE_REWARD_PATHS.has(ACT_2_BOSS_THREE_CHOICE_PATH) else "NOT_AVAILABLE",
			"coverage_status": str(reward_status.get("coverage_status", "NOT_COVERED")),
		},
		"act_2_boss_reward_to_summary_boundary": {
			"id": ACT_2_SUMMARY_BOUNDARY,
			"availability_status": "AVAILABLE" if AVAILABLE_REWARD_PATHS.has(ACT_2_BOSS_THREE_CHOICE_PATH) else "BLOCKED_BY_UNAVAILABLE_ACT_2_BOSS_REWARD_POOL",
			"coverage_status": "COVERED" if act_two_boundary_observed else "NOT_COVERED",
		},
		"unavailable_content_ids": gate_aggregate.get("unavailable_content_ids", []).duplicate(),
	}

func _requirement_status(coverage_detail: Dictionary, requirement_id: String) -> Dictionary:
	for status_value in coverage_detail.get("requirement_statuses", []):
		if status_value is Dictionary and str(status_value.get("id", "")) == requirement_id:
			return status_value
	return {}

func _canonical_hash(value) -> String:
	return DeterministicSerializerScript.hash(_canonicalize_json_numbers(value))

func _canonicalize_json_numbers(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key in value.keys():
				result[str(key)] = _canonicalize_json_numbers(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_canonicalize_json_numbers(item))
			return result
		TYPE_FLOAT:
			var number := float(value)
			if is_finite(number) and floor(number) == number and number >= -9007199254740991.0 and number <= 9007199254740991.0:
				return int(number)
	return value

func _sha256_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	while not file.eof_reached():
		context.update(file.get_buffer(65536))
	var status := file.get_error()
	file.close()
	if status != OK and status != ERR_FILE_EOF:
		return ""
	return context.finish().hex_encode()

func _write_markdown_report(path: String, summary: Dictionary, summary_sha256: String) -> Error:
	var build: Dictionary = summary.get("build", {})
	var execution: Dictionary = summary.get("execution", {})
	var gate_aggregate: Dictionary = summary.get("gate_aggregation", {})
	var coverage: Dictionary = gate_aggregate.get("coverage", {})
	var lines: Array[String] = [
		"# Stage 4 Beta seeded simulation corpus",
		"",
		"- Completion: `%s`" % str(summary.get("completion_status", "UNKNOWN")),
		"- Run state: `%s`" % str(summary.get("run_state", "UNKNOWN")),
		"- Gate evidence eligible: `%s`" % str(summary.get("gate_evidence_eligible", false)),
		"- Simulation gate: `%s` (pass `%s`)" % [str(summary.get("simulation_gate_status", "UNKNOWN")), str(summary.get("simulation_gate_pass", false))],
		"- Manifest: `%s` (artifact SHA-256 `%s`)" % [str(summary.get("manifest_hash", "")), str(summary.get("manifest_artifact_sha256", ""))],
		"- Summary JSONL: `%s` (SHA-256 `%s`)" % [str(summary.get("summary_artifact_path", "")), summary_sha256],
		"",
		"## Build and schema",
		"",
		"- Project version: `%s`; engine: `%s`" % [str(build.get("project_version", "")), JSON.stringify(build.get("engine_version", {}))],
		"- Content version: `%s`; manifest schema: `%s`; corpus schema: `%s`" % [str(build.get("content_version", "")), str(build.get("manifest_schema_version", "")), str(build.get("corpus_schema", ""))],
		"- Game version: `%s`; SuspendSnapshot schema: `%s`; MetaProgressSnapshot schema: `%s`; ReplayRecord schema: `%s`" % [str(build.get("game_version", "")), str(build.get("suspend_snapshot_schema_version", "")), str(build.get("meta_progress_snapshot_schema_version", "")), str(build.get("replay_record_schema_version", ""))],
		"- Base Git revision: `%s`" % str(build.get("base_git_revision", "")),
		"- Runtime source snapshot SHA-256: `%s` (%d files)" % [str(build.get("runtime_source_snapshot_hash", "")), (build.get("runtime_source_file_sha256", {}) as Dictionary).size()],
		"- Snapshot scope: %s" % str(build.get("source_snapshot_scope", "")),
		"",
		"## Execution bounds and commands",
		"",
		"- Cases: `%d/%d`; attempts per case: `%d`; cooperative attempt watchdog: `%d ms`; per-chunk process timeout: `%d s`; kill-after: `%d s`." % [int(execution.get("cumulative_case_count_at_header", 0)), int(execution.get("manifest_case_count", 0)), int(execution.get("attempts_per_case", 2)), int(execution.get("attempt_timeout_msec", 0)), int(execution.get("process_timeout_seconds", 0)), int(execution.get("process_timeout_kill_after_seconds", 0))],
		"- Finalization command: `%s`" % str(execution.get("command", "")),
		"",
		"## Policy outcomes",
		"",
		"```json",
		JSON.stringify(summary.get("policy_outcomes", {}), "\t", true, true),
		"```",
		"",
		"Terminal outcomes: `%s`." % JSON.stringify(summary.get("terminal_outcome_counts", {}), "", true, true),
		"",
		"## Strategy distributions",
		"",
		"```json",
		JSON.stringify(summary.get("strategy_distributions", {}), "\t", true, true),
		"```",
		"",
		"## Source chunks",
		"",
		"Verified GNU timeout statuses: `%d`; process timeouts: `%d`; nonzero chunk exits: `%d`." % [int(summary.get("process_status_summary", {}).get("verified_chunk_count", 0)), int(summary.get("process_status_summary", {}).get("process_timeout_count", 0)), int(summary.get("process_status_summary", {}).get("nonzero_process_exit_count", 0))],
		"",
	]
	for source_chunk_value in summary.get("source_chunks", []):
		var source_chunk: Dictionary = source_chunk_value if source_chunk_value is Dictionary else {}
		lines.append("- Cases %d–%d (%d): `%s`, SHA-256 `%s`; GNU timeout exit `%s` at `%s s`; status `%s` (SHA-256 `%s`); output SHA-256 `%s`." % [int(source_chunk.get("case_start", 0)), int(source_chunk.get("case_end", 0)), int(source_chunk.get("case_count", 0)), str(source_chunk.get("path", "")), str(source_chunk.get("sha256", "")), str(source_chunk.get("process_exit_code", "")), str(source_chunk.get("process_timeout_seconds", "")), str(source_chunk.get("process_status_path", "")), str(source_chunk.get("process_status_sha256", "")), str(source_chunk.get("process_output_sha256", ""))])
		lines.append("  Command argv: `%s`" % JSON.stringify(source_chunk.get("command_argv", []), "", true, true))
		lines.append("  Resolved GNU timeout executable: `%s`" % str(source_chunk.get("timeout_executable_path", "")))
	lines.append_array([
		"",
		"## Observed usage coverage",
		"",
		"The categories below report observed selection, acquisition, ownership, activation, scoring, and encounter facts against the #87 catalog budgets. They do not claim that every production item was used or that use was balanced.",
		"",
		"```json",
		JSON.stringify(coverage.get("content_use", {}), "\t", true, true),
		"```",
		"",
		"## Failures, divergences, and visible outliers",
		"",
		"Visible outliers need one recorded content-owner decision each. The subgate cannot pass while a decision is pending or requests remediation/retest. Defeat is a valid terminal outcome; no win-rate target is applied.",
		"",
		"```json",
		JSON.stringify({
			"profile_errors": gate_aggregate.get("profile_errors", []),
			"invalid_attempts": gate_aggregate.get("invalid_attempts", []),
			"content_owner_review": summary.get("content_owner_review", {}),
			"repeat_divergences": summary.get("repeat_divergences", []),
			"visible_outliers": summary.get("visible_outliers", []),
		}, "\t", true, true),
		"```",
		"",
		"## Evidence limits",
		"",
		str(summary.get("performance_evidence_scope", "")),
		"",
	])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	file.flush()
	var status := file.get_error()
	file.close()
	return status

func _write_jsonl_record(file: FileAccess, record: Dictionary) -> Error:
	file.store_string(JSON.stringify(record, "", true, true) + "\n")
	file.flush()
	return file.get_error()

func _shell_quote(value: String) -> String:
	var safe_characters := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./:=+-"
	var is_safe := not value.is_empty()
	for character in value:
		if not safe_characters.contains(character):
			is_safe = false
			break
	if is_safe:
		return value
	return "'" + value.replace("'", "'\\''") + "'"

func _fail(message: String, exit_code: int) -> void:
	push_error(message)
	quit(exit_code)
