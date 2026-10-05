class_name AlphaGateCorpusResumeTest
extends RefCounted

const ResumeVerifierScript = preload("res://src/infrastructure/simulation/simulation_corpus_resume_verifier.gd")
const AttemptComparatorScript = preload("res://src/infrastructure/simulation/alpha_attempt_comparator.gd")
const SimulationManifestScript = preload("res://src/infrastructure/simulation/simulation_manifest.gd")
const AlphaSimulationRunnerScript = preload("res://src/infrastructure/simulation/alpha_simulation_runner.gd")
const AlphaSimulationStartingPoolFixtureScript = preload("res://src/infrastructure/simulation/alpha_simulation_starting_pool_fixture.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const SnapshotDtoScript = preload("res://src/infrastructure/persistence/snapshot_dto.gd")
const MetaProgressSnapshotScript = preload("res://src/infrastructure/persistence/meta_progress_snapshot.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")
const GnuTimeoutLocatorScript = preload("res://src/infrastructure/simulation/gnu_timeout_locator.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_gnu_timeout_path_is_native_and_existing(failures)
	test_windows_git_timeout_fallback(failures)
	test_stage4_beta_manifest_balances_all_character_contract_policy_strata(failures)
	test_resume_rejects_an_unverified_repeat_claim(failures)
	test_compact_resume_links_projection_and_summary_digest(failures)
	test_cli_resume_rejects_a_forged_comparison(failures)
	test_cli_rejects_tampered_provenance(failures)
	test_cli_requires_successful_gnu_timeout_status(failures)
	test_process_wrapper_records_real_status_and_hashes(failures)
	test_cli_finalizes_bounded_chunks_and_preserves_sources(failures)
	for failure in failures:
		push_error(failure)
	return failures

func test_gnu_timeout_path_is_native_and_existing(failures: Array[String]) -> void:
	var path := GnuTimeoutLocatorScript.resolve_path()
	assert_true(not path.is_empty() and path.is_absolute_path() and FileAccess.file_exists(path), "GNU timeout resolves to an existing native executable path", failures)
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var version_output: Array[String] = []
	var version_exit_code := OS.execute(path, ["--version"], version_output, true)
	assert_true(version_exit_code == 0 and "GNU coreutils" in "\n".join(version_output), "the resolved timeout executable is GNU coreutils, not a same-named system command (%s)" % "\n".join(version_output), failures)


func test_windows_git_timeout_fallback(failures: Array[String]) -> void:
	var fixture_root := ProjectSettings.globalize_path("res://.godot/gnu_timeout_locator_fixture")
	var system_timeout := fixture_root.path_join("Windows/System32/timeout.exe")
	var git_executable := fixture_root.path_join("Program Files/Git/cmd/git.exe").replace("/", "\\")
	var git_timeout := fixture_root.path_join("Program Files/Git/usr/bin/timeout.exe")
	var existing_paths := {system_timeout: true, git_timeout: true}
	var file_exists_check := func(path: String) -> bool:
		return existing_paths.has(path)
	var gnu_timeout_check := func(path: String) -> bool:
		return path == git_timeout
	var resolved_path := GnuTimeoutLocatorScript._resolve_path_from_candidates(
		"Windows",
		[system_timeout],
		[git_executable],
		file_exists_check,
		gnu_timeout_check,
	)
	assert_true(
		resolved_path == git_timeout,
		"Windows timeout discovery skips an incompatible System32 timeout.exe and derives Git usr/bin/timeout.exe through a spaced installation path",
		failures,
	)
	var incompatible_only_path := GnuTimeoutLocatorScript._resolve_path_from_candidates(
		"Windows",
		[system_timeout],
		[],
		file_exists_check,
		gnu_timeout_check,
	)
	assert_true(incompatible_only_path.is_empty(), "Windows timeout discovery never accepts a candidate that fails GNU identity validation", failures)

func test_stage4_beta_manifest_balances_all_character_contract_policy_strata(failures: Array[String]) -> void:
	var character_ids: Array[String] = AlphaScaleCatalogScript.all_character_ids()
	var contract_ids: Array[String] = AlphaScaleCatalogScript.all_contract_ids()
	var policies: Array[String] = ["Partial", "Complete", "Hybrid"]
	var routes: Array[String] = ["EVENT", "SERVICE"]
	var content_use_catalog: Dictionary = SimulationManifestScript.stage4_beta_content_use_catalog()
	var case_plan: Array = SimulationManifestScript.build_balanced_case_plan(
		character_ids,
		contract_ids,
		policies,
		routes,
		SimulationManifestScript.RUNS_REQUIRED_PER_GATE,
	)
	var config := {
		"schema_version": SimulationManifestScript.SCHEMA_VERSION,
		"content_version": AlphaSimulationRunnerScript.content_version_for_gate("stage4_beta"),
		"starting_pool_fixture_id": AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID,
		"gate_profiles": [{
			"gate_id": "stage4_beta",
			"attempt_count": SimulationManifestScript.RUNS_REQUIRED_PER_GATE,
			"seed_start": 57000,
			"policy_ids": policies,
			"character_ids": character_ids,
			"contract_ids": contract_ids,
			"route_ids": routes,
			"required_character_ids": character_ids,
			"required_contract_ids": contract_ids,
			"required_policy_ids": policies,
			"content_use_catalog": content_use_catalog,
		}],
	}
	var manifest = SimulationManifestScript.new(config, character_ids, contract_ids)
	var gate: Dictionary = manifest.to_dictionary().get("gates", {}).get("stage4_beta", {})
	var content_categories: Dictionary = content_use_catalog.get("categories", {})
	var cases: Array = gate.get("cases", [])
	var stratum_counts := {}
	var stratum_route_counts := {}
	var policy_counts := {"Partial": 0, "Complete": 0, "Hybrid": 0}
	var seed_ids := {}
	for index in range(cases.size()):
		var attempt_case: Dictionary = cases[index]
		var planned_case: Dictionary = case_plan[index] if index < case_plan.size() else {}
		var stratum := "%s|%s|%s" % [
			str(attempt_case.get("policy_id", "")),
			str(attempt_case.get("character_id", "")),
			str(attempt_case.get("contract_id", "")),
		]
		stratum_counts[stratum] = int(stratum_counts.get(stratum, 0)) + 1
		var route_counts: Dictionary = stratum_route_counts.get(stratum, {})
		var route_id := str(attempt_case.get("route_id", ""))
		route_counts[route_id] = int(route_counts.get(route_id, 0)) + 1
		stratum_route_counts[stratum] = route_counts
		var policy_id := str(attempt_case.get("policy_id", ""))
		if policy_counts.has(policy_id):
			policy_counts[policy_id] += 1
		var seed := int(attempt_case.get("seed", -1))
		seed_ids[seed] = true
		for field in ["policy_id", "character_id", "contract_id", "route_id"]:
			assert_true(attempt_case.get(field, null) == planned_case.get(field, null), "manifest case %d follows the deterministic balanced plan for %s" % [index + 1, field], failures)

	assert_true(manifest.is_valid(), "the Stage 4 Beta manifest accepts the complete production roster and deterministic balanced schedule", failures)
	assert_true(character_ids.size() == 3 and contract_ids.size() == 8, "the Stage 4 Beta plan uses the authored three-Character/eight-Contract roster", failures)
	assert_true(cases.size() == 1000, "the Stage 4 Beta manifest declares exactly 1,000 complete cases", failures)
	assert_true(stratum_counts.size() == 72, "the Stage 4 Beta manifest covers all 24 pairs under all three policies", failures)
	assert_true(gate.get("content_use_catalog", {}) == content_use_catalog, "the manifest preserves the accepted observed-content budget and subcategory source", failures)
	assert_true(content_categories.get("characters", {}).get("ids", []).size() == 3 and content_categories.get("contracts", {}).get("ids", []).size() == 8, "the observed-use denominators name all three Characters and eight Contracts from #87", failures)
	assert_true(content_categories.get("yaku", {}).get("ids", []).size() == 24 and content_categories.get("relics", {}).get("ids", []).size() == 50, "the observed-use denominators preserve the accepted 24 Yaku and 50 Relics", failures)
	assert_true(content_categories.get("rule_breakers", {}).get("ids", []).size() == 10 and content_categories.get("modifiers", {}).get("ids", []).size() == 12, "the observed-use denominators preserve the accepted 10 Rule Breakers and 12 Modifiers", failures)
	assert_true(content_categories.get("techniques", {}).get("subcategories", {}).get("run_techniques", {}).get("ids", []).size() == 21 and content_categories.get("techniques", {}).get("subcategories", {}).get("core_techniques", {}).get("ids", []).size() == 3, "the Technique report preserves separate 21 Run and 3 Core Technique budgets", failures)
	for family in ["normal_enemies", "elite_enemies", "bosses"]:
		var family_catalog: Dictionary = content_categories.get(family, {})
		var act_catalogs: Dictionary = family_catalog.get("subcategories", {})
		assert_true(act_catalogs.get("act_1", {}).get("ids", []).size() + act_catalogs.get("act_2", {}).get("ids", []).size() == family_catalog.get("ids", []).size(), "%s denominators keep per-Act budgets disjoint and sum to the unique-ID total" % family, failures)
	assert_true(content_categories.get("normal_enemies", {}).get("subcategories", {}).get("act_1", {}).get("ids", []).size() == 7 and content_categories.get("normal_enemies", {}).get("subcategories", {}).get("act_2", {}).get("ids", []).size() == 7, "the catalog exposes seven Act 1 and seven Act 2 Normal definitions", failures)
	assert_true(content_categories.get("elite_enemies", {}).get("subcategories", {}).get("act_1", {}).get("ids", []).size() == 3 and content_categories.get("elite_enemies", {}).get("subcategories", {}).get("act_2", {}).get("ids", []).size() == 3, "the catalog exposes three Act 1 and three Act 2 Elite definitions", failures)
	assert_true(content_categories.get("bosses", {}).get("subcategories", {}).get("act_1", {}).get("ids", []).size() == 2 and content_categories.get("bosses", {}).get("subcategories", {}).get("act_2", {}).get("ids", []).size() == 2, "the catalog exposes two Act 1 and two Act 2 Boss definitions", failures)
	assert_true(content_categories.get("events", {}).get("ids", []).size() == 24 and content_categories.get("events", {}).get("subcategories", {}).get("act_2", {}).get("ids", []).size() == 12, "the event observed-use denominator includes the 24 authored production events with Act 2 placement", failures)
	assert_true(policy_counts == {"Partial": 334, "Complete": 333, "Hybrid": 333}, "the 1,000 cases are balanced across policies without a win-rate quota", failures)
	assert_true(seed_ids.size() == 1000 and cases[0].get("seed", -1) == 57000 and cases[-1].get("seed", -1) == 57999, "the manifest assigns a unique sequential seed to every declared case", failures)
	for stratum in stratum_counts:
		var count := int(stratum_counts[stratum])
		assert_true(count in [13, 14], "every Character×Contract×policy stratum receives 13 or 14 seeds", failures)
		var route_counts: Dictionary = stratum_route_counts[stratum]
		assert_true(route_counts.keys().size() == 2, "every stratum is exercised on both authored route strategies", failures)
		assert_true(absi(int(route_counts.get("EVENT", 0)) - int(route_counts.get("SERVICE", 0))) <= 1, "route assignment is balanced within each stratum", failures)

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

func test_compact_resume_links_projection_and_summary_digest(failures: Array[String]) -> void:
	var expected_case := {
		"attempt_index": 0,
		"attempt_id": "stage4_beta.00001",
		"gate_id": "stage4_beta",
		"seed": 57000,
		"policy_id": "Partial",
		"character_id": "base.character.sequence",
		"contract_id": "base.contract.pressure",
		"route_id": "SERVICE",
		"starting_pool_fixture_id": "phase2.character_biased_complete_hand.v1",
	}
	var first_attempt := _sample_attempt(expected_case)
	first_attempt["gate_id"] = "stage4_beta"
	first_attempt["attempt_id"] = expected_case.attempt_id
	first_attempt["manifest_hash"] = "compact-manifest"
	first_attempt["strategy"] = {"policy_id": "Partial"}
	var repeated_attempt := first_attempt.duplicate(true)
	var record := {
		"record_type": "case",
		"case_number": 1,
		"manifest_hash": "compact-manifest",
		"attempt_case": expected_case.duplicate(true),
		"attempt_summary": ResumeVerifierScript.summarize_compact_attempt(first_attempt, "stage4_beta"),
		"repeat_attempt_summary": ResumeVerifierScript.summarize_compact_attempt(repeated_attempt, "stage4_beta"),
		"repeat_comparison": AttemptComparatorScript.compare(first_attempt, repeated_attempt),
	}
	var valid_result: Dictionary = ResumeVerifierScript.validate_record(record, expected_case, "compact-manifest", 1)
	assert_true(valid_result.get("valid", false), "compact resume links its attempt summaries to complete deterministic field maps and comparison projections", failures)
	assert_true(not record.has("attempt") and not record.has("repeat_attempt"), "compact corpus records do not retain full attempt traces", failures)
	var round_trip_value = JSON.parse_string(JSON.stringify(record))
	var round_trip_result: Dictionary = ResumeVerifierScript.validate_record(round_trip_value, expected_case, "compact-manifest", 1) if round_trip_value is Dictionary else {"valid": false, "errors": ["JSON round trip failed"]}
	assert_true(round_trip_result.get("valid", false), "compact comparison and summary digests remain stable after JSON numeric decoding", failures)
	var corrupt_summary: Dictionary = record.duplicate(true)
	corrupt_summary["attempt_summary"]["coverage_contribution"]["characters"] = ["forged.character"]
	var corrupt_summary_result: Dictionary = ResumeVerifierScript.validate_record(corrupt_summary, expected_case, "compact-manifest", 1)
	assert_true(not corrupt_summary_result.get("valid", true) and str(corrupt_summary_result.get("errors", [])).contains("compact summary/content digest is invalid"), "resume rejects a changed compact coverage contribution without its digest", failures)
	var corrupt_projection: Dictionary = record.duplicate(true)
	corrupt_projection["repeat_comparison"]["expected_field_hashes"]["outcome"] = "forged-hash"
	var corrupt_projection_result: Dictionary = ResumeVerifierScript.validate_record(corrupt_projection, expected_case, "compact-manifest", 1)
	assert_true(not corrupt_projection_result.get("valid", true) and str(corrupt_projection_result.get("errors", [])).contains("repeat comparison fingerprints differ from their compact attempt summaries"), "resume rejects field hashes not linked to their attempt summary", failures)

func test_cli_resume_rejects_a_forged_comparison(failures: Array[String]) -> void:
	var scratch_path := ProjectSettings.globalize_path("res://.godot/alpha_corpus_resume_test")
	DirAccess.make_dir_recursive_absolute(scratch_path)
	var smoke_path := scratch_path.path_join("smoke.jsonl")
	var resume_path := scratch_path.path_join("forged-resume.jsonl")
	var output_path := scratch_path.path_join("resumed-output.jsonl")
	var smoke_args := PackedStringArray([
		"--smoke",
		"--gate", "stage4_beta",
		"--output", smoke_path,
	])
	var smoke_result := _execute_corpus_cli(smoke_args)
	var smoke_exit := int(smoke_result.exit_code)
	assert_true(smoke_exit == 0, "the real corpus CLI can produce a one-case smoke source (exit=%d, output=%s)" % [smoke_exit, str(smoke_result.output)], failures)
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
	header = _full_chunk_header(header, 1, 1, [], 990)
	case_record["repeat_comparison"] = {"matches": true}
	var resume_file := FileAccess.open(resume_path, FileAccess.WRITE)
	assert_true(resume_file != null, "the forged interrupted-report input can be written under the F: project", failures)
	if resume_file == null:
		_cleanup_files([smoke_path, resume_path, output_path])
		return
	resume_file.store_string(JSON.stringify(header) + "\n")
	resume_file.store_string(JSON.stringify(case_record) + "\n")
	resume_file.close()
	_write_process_status(resume_path, header, 0)
	var resume_args := PackedStringArray([
		"--full",
		"--gate", "stage4_beta",
		"--resume-from", resume_path,
		"--output", output_path,
		"--process-timeout-seconds", "990",
		"--process-timeout-enforced",
	])
	var resume_result := _execute_corpus_cli(resume_args)
	var resume_output_text := str(resume_result.output)
	assert_true(int(resume_result.exit_code) == 2, "the real corpus CLI rejects an unverifiable resumed case before running the remaining manifest cases (exit=%d, %s)" % [int(resume_result.exit_code), resume_output_text], failures)
	assert_true(resume_output_text.contains("repeat comparison field hash count is invalid"), "the real corpus CLI reports the forged compact repeat-comparison field (%s)" % resume_output_text, failures)
	_cleanup_files([smoke_path, smoke_path + ".manifest.json", resume_path, resume_path + ".status.json", output_path, output_path + ".manifest.json"])

func test_cli_rejects_tampered_provenance(failures: Array[String]) -> void:
	var project_path := ProjectSettings.globalize_path("res://")
	var scratch_path := ProjectSettings.globalize_path("res://.godot/alpha_corpus_provenance_test")
	DirAccess.make_dir_recursive_absolute(scratch_path)
	var smoke_path := scratch_path.path_join("smoke.jsonl")
	var source_text := _create_smoke_source(smoke_path, failures)
	if source_text.is_empty():
		return
	var source_lines := source_text.strip_edges().split("\n")
	var header_value = JSON.parse_string(source_lines[0])
	if not header_value is Dictionary:
		assert_true(false, "the provenance fixture has a valid corpus header", failures)
		return
	var base_header: Dictionary = header_value
	var build_metadata: Dictionary = base_header.get("build", {})
	assert_true(
		str(build_metadata.get("game_version", "")) == SnapshotDtoScript.GAME_VERSION
		and int(build_metadata.get("suspend_snapshot_schema_version", -1)) == SnapshotDtoScript.SCHEMA_VERSION
		and int(build_metadata.get("meta_progress_snapshot_schema_version", -1)) == MetaProgressSnapshotScript.CURRENT_SCHEMA_VERSION
		and int(build_metadata.get("replay_record_schema_version", -1)) == ReplayRecordScript.SCHEMA_VERSION,
		"the emitted corpus build metadata records exact game, SuspendSnapshot, MetaProgressSnapshot, and ReplayRecord versions",
		failures,
	)
	var mismatch_build_path := scratch_path.path_join("mismatched-build.jsonl")
	var mismatch_manifest_path := scratch_path.path_join("mismatched-manifest.jsonl")
	var mismatch_schema_path := scratch_path.path_join("mismatched-schema.jsonl")
	var missing_lineage_path := scratch_path.path_join("missing-lineage.jsonl")
	var mismatch_build_output := scratch_path.path_join("mismatch-build-output.jsonl")
	var mismatch_manifest_output := scratch_path.path_join("mismatch-manifest-output.jsonl")
	var mismatch_schema_output := scratch_path.path_join("mismatch-schema-output.jsonl")
	var missing_lineage_output := scratch_path.path_join("missing-lineage-output.jsonl")
	var chunk_header: Dictionary = _full_chunk_header(base_header, 1, 1, [], 270)
	var bad_build_header: Dictionary = chunk_header.duplicate(true)
	var build_data: Dictionary = bad_build_header.get("build", {})
	build_data["runtime_source_snapshot_hash"] = "tampered-source-snapshot"
	bad_build_header["build"] = build_data
	_write_jsonl_records(mismatch_build_path, [bad_build_header])
	_write_process_status(mismatch_build_path, bad_build_header, 0)
	var build_result := _execute_corpus_cli([
		"--full", "--gate", "stage4_beta", "--resume-from", mismatch_build_path,
		"--output", mismatch_build_output, "--process-timeout-seconds", "270", "--process-timeout-enforced",
	])
	assert_true(int(build_result.exit_code) == 2 and str(build_result.output).contains("build metadata or runtime source snapshot differs"), "resume rejects chunks whose current runtime build snapshot differs", failures)

	var bad_schema_header: Dictionary = chunk_header.duplicate(true)
	var schema_build: Dictionary = bad_schema_header.get("build", {})
	schema_build["meta_progress_snapshot_schema_version"] = int(schema_build.get("meta_progress_snapshot_schema_version", -1)) + 1
	bad_schema_header["build"] = schema_build
	_write_jsonl_records(mismatch_schema_path, [bad_schema_header])
	_write_process_status(mismatch_schema_path, bad_schema_header, 0)
	var schema_result := _execute_corpus_cli([
		"--full", "--gate", "stage4_beta", "--resume-from", mismatch_schema_path,
		"--output", mismatch_schema_output, "--process-timeout-seconds", "270", "--process-timeout-enforced",
	])
	assert_true(int(schema_result.exit_code) == 2 and str(schema_result.output).contains("build metadata or runtime source snapshot differs"), "resume rejects a chunk with a mismatched MetaProgressSnapshot schema identity", failures)

	var bad_manifest_header: Dictionary = chunk_header.duplicate(true)
	var embedded_manifest: Dictionary = bad_manifest_header.get("manifest", {})
	embedded_manifest["content_version"] = "tampered-content-version"
	bad_manifest_header["manifest"] = embedded_manifest
	_write_jsonl_records(mismatch_manifest_path, [bad_manifest_header])
	_write_process_status(mismatch_manifest_path, bad_manifest_header, 0)
	var manifest_result := _execute_corpus_cli([
		"--full", "--gate", "stage4_beta", "--resume-from", mismatch_manifest_path,
		"--output", mismatch_manifest_output, "--process-timeout-seconds", "270", "--process-timeout-enforced",
	])
	assert_true(int(manifest_result.exit_code) == 2 and str(manifest_result.output).contains("embeds a manifest that differs"), "resume rejects a header whose embedded canonical manifest differs from the current manifest", failures)

	var bad_lineage_header: Dictionary = chunk_header.duplicate(true)
	bad_lineage_header["resume_source_chunks"] = [{"path": "missing-prior-chunk.jsonl", "sha256": "missing"}]
	_write_jsonl_records(missing_lineage_path, [bad_lineage_header])
	_write_process_status(missing_lineage_path, bad_lineage_header, 0)
	var lineage_result := _execute_corpus_cli([
		"--full", "--gate", "stage4_beta", "--resume-from", missing_lineage_path,
		"--output", missing_lineage_output, "--process-timeout-seconds", "270", "--process-timeout-enforced",
	])
	assert_true(int(lineage_result.exit_code) == 2 and str(lineage_result.output).contains("source-chunk lineage differs"), "resume rejects a chunk that claims an omitted source chunk", failures)

	var manifest_artifact := smoke_path + ".manifest.json"
	var manifest_artifact_value = JSON.parse_string(FileAccess.get_file_as_string(manifest_artifact))
	assert_true(manifest_artifact_value is Dictionary, "the smoke source has a parseable separate manifest artifact", failures)
	if manifest_artifact_value is Dictionary:
		var tampered_artifact: Dictionary = manifest_artifact_value
		tampered_artifact["content_version"] = "tampered-but-same-hash"
		_write_json_file(manifest_artifact, tampered_artifact)
		var artifact_result := _execute_corpus_cli([
			"--full", "--gate", "stage4_beta", "--manifest-output", manifest_artifact,
			"--output", scratch_path.path_join("bad-manifest-output.jsonl"),
			"--process-timeout-seconds", "270", "--process-timeout-enforced",
		])
		assert_true(
			int(artifact_result.exit_code) == 2 and str(artifact_result.output).contains("Could not create or validate the manifest artifact"),
			"the CLI validates an existing manifest's canonical payload and hash (exit=%d, output=%s)" % [int(artifact_result.exit_code), str(artifact_result.output)],
			failures,
		)

	_cleanup_files([
		smoke_path, manifest_artifact, mismatch_build_path, mismatch_build_path + ".status.json", mismatch_manifest_path, mismatch_manifest_path + ".status.json", mismatch_schema_path, mismatch_schema_path + ".status.json", missing_lineage_path, missing_lineage_path + ".status.json",
		mismatch_build_output, mismatch_manifest_output, mismatch_schema_output, missing_lineage_output,
		scratch_path.path_join("bad-manifest-output.jsonl"),
	])

func test_cli_requires_successful_gnu_timeout_status(failures: Array[String]) -> void:
	var scratch_path := ProjectSettings.globalize_path("res://.godot/alpha_corpus_status_test")
	DirAccess.make_dir_recursive_absolute(scratch_path)
	var smoke_path := scratch_path.path_join("smoke.jsonl")
	var source_text := _create_smoke_source(smoke_path, failures)
	if source_text.is_empty():
		return
	var header_value = JSON.parse_string(source_text.strip_edges().split("\n")[0])
	if not header_value is Dictionary:
		assert_true(false, "the status fixture begins with a valid smoke header", failures)
		return
	var base_header: Dictionary = header_value
	var chunk_path := scratch_path.path_join("status-source.jsonl")
	var output_path := scratch_path.path_join("status-output.jsonl")
	var statuses := [124, 7, 0]
	for status_code in statuses:
		var chunk_header: Dictionary = _full_chunk_header(base_header, 1, 1, [], 270)
		_write_jsonl_records(chunk_path, [chunk_header])
		_write_process_status(chunk_path, chunk_header, int(status_code))
		if int(status_code) == 0:
			var sidecar_value = JSON.parse_string(FileAccess.get_file_as_string(chunk_path + ".status.json"))
			if sidecar_value is Dictionary:
				var sidecar: Dictionary = sidecar_value
				sidecar["output_sha256"] = "tampered-output-hash"
				_write_json_file(chunk_path + ".status.json", sidecar)
		var result := _execute_corpus_cli([
			"--full", "--gate", "stage4_beta", "--resume-from", chunk_path,
			"--output", output_path, "--process-timeout-seconds", "270", "--process-timeout-enforced",
		])
		assert_true(
			int(result.exit_code) == 2 and str(result.output).contains("process-status record"),
			"finalization input with process exit %d or a tampered status digest is rejected before simulation (exit=%d, output=%s)" % [int(status_code), int(result.exit_code), str(result.output)],
			failures,
		)
		_cleanup_files([output_path, output_path + ".manifest.json"])
	var good_header: Dictionary = _full_chunk_header(base_header, 1, 1, [], 270)
	_write_jsonl_records(chunk_path, [good_header])
	_cleanup_files([chunk_path + ".status.json"])
	var missing_result := _execute_corpus_cli([
		"--full", "--gate", "stage4_beta", "--resume-from", chunk_path,
		"--output", output_path, "--process-timeout-seconds", "270", "--process-timeout-enforced",
	])
	assert_true(int(missing_result.exit_code) == 2 and str(missing_result.output).contains("missing its GNU timeout process-status sidecar"), "resume rejects a missing process-status sidecar before simulation", failures)
	_cleanup_files([smoke_path, smoke_path + ".manifest.json", chunk_path, chunk_path + ".status.json", output_path, output_path + ".manifest.json"])

func test_process_wrapper_records_real_status_and_hashes(failures: Array[String]) -> void:
	var scratch_path := ProjectSettings.globalize_path("res://.godot/alpha_corpus_wrapper_test")
	DirAccess.make_dir_recursive_absolute(scratch_path)
	var wrapper_path := ProjectSettings.globalize_path("res://scripts/run_alpha_gate_corpus_chunk.py")
	var python_path := "python3"
	var success_path := scratch_path.path_join("success.jsonl")
	var failure_path := scratch_path.path_join("failure.jsonl")
	var timeout_path := scratch_path.path_join("timeout.jsonl")
	var writer_code := "from pathlib import Path; import sys; Path(sys.argv[-1]).write_text('fixture')"
	var success_code := _execute_process_wrapper(python_path, wrapper_path, success_path, 10, [python_path, "-c", writer_code, "--output", success_path])
	assert_true(int(success_code.exit_code) == 0, "the process wrapper returns a real GNU timeout success status (%s)" % str(success_code.output), failures)
	var success_status = JSON.parse_string(FileAccess.get_file_as_string(success_path + ".status.json")) if FileAccess.file_exists(success_path + ".status.json") else null
	assert_true(success_status is Dictionary and int(success_status.get("process_exit_code", -1)) == 0 and str(success_status.get("output_sha256", "")) == _sha256_file(success_path), "success sidecar records the exact exit code, command argv, and output SHA-256", failures)
	assert_true(success_status is Dictionary and str(success_status.get("timeout_executable_path", "")).is_absolute_path() and str(success_status.get("timeout_executable_path", "")) == GnuTimeoutLocatorScript.resolve_path() and str(success_status.get("command_argv", [""])[0]) == str(success_status.get("timeout_executable_path", "")), "the process sidecar uses the exact resolved GNU timeout path as argv[0]", failures)
	var failure_writer_code := "from pathlib import Path; import sys; Path(sys.argv[-1]).write_text('failed'); raise SystemExit(7)"
	var failure_result := _execute_process_wrapper(python_path, wrapper_path, failure_path, 10, [python_path, "-c", failure_writer_code, "--output", failure_path])
	var failure_status = JSON.parse_string(FileAccess.get_file_as_string(failure_path + ".status.json")) if FileAccess.file_exists(failure_path + ".status.json") else null
	assert_true(int(failure_result.exit_code) == 7 and failure_status is Dictionary and int(failure_status.get("process_exit_code", -1)) == 7, "the process wrapper persists nonzero command status without rewriting it as success", failures)
	var sleeper_code := "import sys,time; from pathlib import Path; Path(sys.argv[-1]).write_text('partial'); time.sleep(10)"
	var timeout_result := _execute_process_wrapper(python_path, wrapper_path, timeout_path, 1, [python_path, "-c", sleeper_code, "--output", timeout_path])
	var timeout_status = JSON.parse_string(FileAccess.get_file_as_string(timeout_path + ".status.json")) if FileAccess.file_exists(timeout_path + ".status.json") else null
	assert_true(int(timeout_result.exit_code) == 124 and timeout_status is Dictionary and int(timeout_status.get("process_exit_code", -1)) == 124, "the process wrapper records GNU timeout status 124 for an interrupted command", failures)
	for output_path in [success_path, failure_path, timeout_path]:
		_cleanup_files([output_path, output_path + ".status.json"])

func _execute_process_wrapper(python_path: String, wrapper_path: String, output_path: String, timeout_seconds: int, command_argv: Array[String]) -> Dictionary:
	var arguments := PackedStringArray([
		wrapper_path,
		str(timeout_seconds),
		output_path,
		"--timeout-executable",
		GnuTimeoutLocatorScript.resolve_path(),
		"--",
	])
	for argument in command_argv:
		arguments.append(argument)
	var output: Array[String] = []
	var exit_code := OS.execute(python_path, arguments, output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}

func test_cli_finalizes_bounded_chunks_and_preserves_sources(failures: Array[String]) -> void:
	var project_path := ProjectSettings.globalize_path("res://")
	var scratch_path := ProjectSettings.globalize_path("res://.godot/alpha_corpus_finalize_test")
	var cleanup_paths: Array[String] = []
	if DirAccess.dir_exists_absolute(scratch_path):
		var prior_files := DirAccess.get_files_at(scratch_path)
		for prior_file in prior_files:
			DirAccess.remove_absolute(scratch_path.path_join(str(prior_file)))
		DirAccess.remove_absolute(scratch_path)
	DirAccess.make_dir_recursive_absolute(scratch_path)
	var smoke_path := scratch_path.path_join("smoke.jsonl")
	cleanup_paths.append(smoke_path)
	cleanup_paths.append(smoke_path + ".manifest.json")
	var source_text := _create_smoke_source(smoke_path, failures)
	if source_text.is_empty():
		_cleanup_files(cleanup_paths)
		return
	var source_lines := source_text.strip_edges().split("\n")
	var header_value = JSON.parse_string(source_lines[0])
	if not header_value is Dictionary:
		assert_true(false, "the finalization fixture has a valid smoke header", failures)
		_cleanup_files(cleanup_paths)
		return
	var base_header: Dictionary = header_value
	var manifest: Dictionary = base_header.get("manifest", {})
	var manifest_hash := str(base_header.get("manifest_hash", ""))
	var gate: Dictionary = manifest.get("gates", {}).get("stage4_beta", {})
	var cases: Array = gate.get("cases", [])
	assert_true(cases.size() == 1000 and not manifest_hash.is_empty(), "synthetic source fixtures use the exact 1,000-case declared manifest", failures)
	if cases.size() != 1000 or manifest_hash.is_empty():
		_cleanup_files(cleanup_paths)
		return
	var source_references: Array = []
	var source_hashes: Array[String] = []
	var chunk_paths: Array[String] = []
	var chunk_count := ceili(float(cases.size()) / 20.0)
	for chunk_index in range(chunk_count):
		var case_start := chunk_index * 20 + 1
		var case_end_exclusive := mini(case_start + 20, cases.size() + 1)
		var case_limit := case_end_exclusive - case_start
		var chunk_path := scratch_path.path_join("chunk-%02d.jsonl" % chunk_index)
		chunk_paths.append(chunk_path)
		cleanup_paths.append(chunk_path)
		var output_file := FileAccess.open(chunk_path, FileAccess.WRITE)
		assert_true(output_file != null, "each bounded synthetic source chunk can be written", failures)
		if output_file == null:
			_cleanup_files(cleanup_paths)
			return
		var chunk_header: Dictionary = _full_chunk_header(base_header, case_start, case_limit, source_references, 4830)
		var header_error := _write_jsonl_line(output_file, chunk_header)
		assert_true(header_error == OK, "each source chunk header can be flushed", failures)
		for case_index in range(case_start - 1, case_end_exclusive - 1):
			var expected_case: Dictionary = cases[case_index]
			var attempt := _sample_attempt(expected_case)
			if case_index == 0:
				attempt["elapsed_msec"] = 100
			attempt["manifest_hash"] = manifest_hash
			var repeated_attempt: Dictionary = attempt.duplicate(true)
			if case_index == 0:
				repeated_attempt["elapsed_msec"] = 60000
			var case_record := {
				"record_type": "case",
				"case_number": case_index + 1,
				"manifest_hash": manifest_hash,
				"attempt_case": expected_case.duplicate(true),
				"attempt_summary": ResumeVerifierScript.summarize_compact_attempt(attempt, "stage4_beta"),
				"repeat_attempt_summary": ResumeVerifierScript.summarize_compact_attempt(repeated_attempt, "stage4_beta"),
				"repeat_comparison": AttemptComparatorScript.compare(attempt, repeated_attempt),
			}
			var case_error := _write_jsonl_line(output_file, case_record)
			if case_error != OK:
				output_file.close()
				assert_true(false, "every synthetic compact source case is written (%s)" % error_string(case_error), failures)
				_cleanup_files(cleanup_paths)
				return
		output_file.close()
		_write_process_status(chunk_path, chunk_header, 0)
		var chunk_sha256 := _sha256_file(chunk_path)
		var process_status_path := chunk_path + ".status.json"
		var process_status_sha256 := _sha256_file(process_status_path)
		assert_true(not chunk_sha256.is_empty(), "every immutable source chunk has a SHA-256", failures)
		assert_true(not process_status_sha256.is_empty(), "every bounded source chunk has a process-status SHA-256", failures)
		source_hashes.append(chunk_sha256)
		source_references.append({
			"path": chunk_path,
			"sha256": chunk_sha256,
			"process_status_path": process_status_path,
			"process_status_sha256": process_status_sha256,
			"process_exit_code": 0,
			"process_output_sha256": chunk_sha256,
			"timeout_implementation": "GNU coreutils timeout",
			"timeout_executable_path": str(chunk_header.get("execution", {}).get("timeout_executable_path", "")),
			"case_start": case_start,
			"case_end": case_end_exclusive - 1,
			"case_count": case_limit,
			"truncated_final_record_discarded": false,
			"process_timeout_seconds": 4830,
			"attempt_timeout_msec": 120000,
			"chunk_limit": 20,
			"command": "synthetic bounded source fixture",
			"command_argv": chunk_header.get("execution", {}).get("command_argv", []).duplicate(true),
		})
		cleanup_paths.append(process_status_path)

	var summary_path := scratch_path.path_join("summary.jsonl")
	var report_path := scratch_path.path_join("report.md")
	var disposition_path := scratch_path.path_join("outlier-dispositions.json")
	var reviewed_summary_path := scratch_path.path_join("reviewed-summary.jsonl")
	var reviewed_report_path := scratch_path.path_join("reviewed-report.md")
	cleanup_paths.append(summary_path)
	cleanup_paths.append(summary_path + ".manifest.json")
	cleanup_paths.append(summary_path + ".status.json")
	cleanup_paths.append(report_path)
	cleanup_paths.append(disposition_path)
	cleanup_paths.append(reviewed_summary_path)
	cleanup_paths.append(reviewed_summary_path + ".manifest.json")
	cleanup_paths.append(reviewed_summary_path + ".status.json")
	cleanup_paths.append(reviewed_report_path)
	var finalize_command: Array[String] = [
		OS.get_executable_path(), "--headless", "--path", project_path,
		"--script", "res://scripts/run_alpha_gate_corpus.gd", "--",
		"--full", "--finalize", "--gate", "stage4_beta", "--output", summary_path,
		"--report-output", report_path, "--process-timeout-seconds", "120", "--process-timeout-enforced",
	]
	for chunk_path in chunk_paths:
		finalize_command.append("--resume-from")
		finalize_command.append(chunk_path)
	var finalize_result := _execute_process_wrapper("python3", ProjectSettings.globalize_path("res://scripts/run_alpha_gate_corpus_chunk.py"), summary_path, 120, finalize_command)
	assert_true(int(finalize_result.exit_code) == 1, "the full bounded source set finalizes into a complete report while honestly failing unavailable coverage gates (%s)" % str(finalize_result.output), failures)
	assert_true(str(finalize_result.output).contains("ALPHA_GATE_ARTIFACTS"), "finalization prints the exact manifest, summary, and report SHA-256 values", failures)
	var summary_lines: PackedStringArray = FileAccess.get_file_as_string(summary_path).strip_edges().split("\n") if FileAccess.file_exists(summary_path) else PackedStringArray()
	assert_true(summary_lines.size() == 2, "the final summary JSONL contains a provenance header and one compact 1,000-case aggregate", failures)
	if summary_lines.size() == 2:
		var summary_value = JSON.parse_string(summary_lines[1])
		assert_true(summary_value is Dictionary, "the final summary JSONL summary record parses", failures)
		if summary_value is Dictionary:
			var summary: Dictionary = summary_value
			var recorded_chunks: Array = summary.get("source_chunks", [])
			assert_true(str(summary.get("run_state", "")) == "COMPLETE" and str(summary.get("completion_status", "")) == "COMPLETE_1000_CASE_CORPUS", "only explicit finalization records COMPLETE for the exact 1,000 cases", failures)
			assert_true(bool(summary.get("gate_evidence_eligible", false)) and int(summary.get("execution", {}).get("exact_repeats_match_so_far", -1)) == 1000, "finalization records 1,000 exact repeat matches and bounded process-timeout evidence", failures)
			assert_true(summary.get("process_status_summary", {}).get("verified_chunk_count", -1) == 50 and summary.get("process_status_summary", {}).get("process_timeout_count", -1) == 0, "finalization reports fifty verified process statuses and zero process timeouts", failures)
			assert_true(summary.get("content_owner_review", {}).get("status", "") == "CONTENT_OWNER_REVIEW_PENDING" and not bool(summary.get("simulation_gate_pass", true)), "a visible outlier without owner disposition blocks the simulation subgate", failures)
			var visible_outliers: Array = summary.get("visible_outliers", [])
			assert_true(visible_outliers.size() == 1, "the slow deterministic repeat is retained as one case-level visible outlier", failures)
			if visible_outliers.size() == 1 and visible_outliers[0] is Dictionary:
				var visible_outlier: Dictionary = visible_outliers[0]
				var attempts: Array = visible_outlier.get("attempts", [])
				assert_true(visible_outlier.get("reasons", []).has("REPEAT_WATCHDOG_BUDGET_HALF_OR_MORE"), "a repeat attempt using half the watchdog budget is classified as a visible outlier", failures)
				assert_true(attempts.size() == 2 and int(attempts[0].get("elapsed_msec", -1)) == 100 and int(attempts[1].get("elapsed_msec", -1)) == 60000, "visible outlier evidence reports elapsed time for both attempts", failures)
				assert_true(attempts.size() == 2 and str(attempts[0].get("owner_disposition", "")) == "PENDING_CONTENT_OWNER_REVIEW" and str(attempts[1].get("owner_disposition", "")) == "PENDING_CONTENT_OWNER_REVIEW", "both attempts inherit the pending case-level owner disposition", failures)
			assert_true(summary.get("strategy_distributions", {}).get("Complete", {}).get("attempt_count", 0) > 0 and summary.get("strategy_distributions", {}).get("Complete", {}).has("accepted_action_counts"), "the aggregate reports strategy command, action, and settlement distributions by policy", failures)
			assert_true(recorded_chunks.size() == 50, "the aggregate references every bounded source chunk", failures)
			assert_true(recorded_chunks.size() == source_hashes.size(), "the source-chunk references are complete for the multi-chunk finalization", failures)
			for index in range(mini(recorded_chunks.size(), source_hashes.size())):
				var reference: Dictionary = recorded_chunks[index]
				assert_true(str(reference.get("sha256", "")) == source_hashes[index] and str(reference.get("path", "")) == chunk_paths[index] and int(reference.get("process_exit_code", -1)) == 0 and not str(reference.get("process_status_sha256", "")).is_empty(), "finalization records each source chunk's exact immutable data and successful process status", failures)
	assert_true(FileAccess.file_exists(report_path), "complete finalization writes the required Markdown report", failures)
	if FileAccess.file_exists(report_path):
		var report_text := FileAccess.get_file_as_string(report_path)
		assert_true(report_text.contains("Summary JSONL") and report_text.contains("Observed usage coverage") and report_text.contains("Failures, divergences, and visible outliers") and report_text.contains("Verified GNU timeout statuses: `50`") and report_text.contains("Strategy distributions"), "report includes artifact identity, strategy and content use, verified process status, and outlier disposition", failures)
		assert_true(report_text.contains("Game version: `%s`; SuspendSnapshot schema: `%d`; MetaProgressSnapshot schema: `%d`; ReplayRecord schema: `%d`" % [SnapshotDtoScript.GAME_VERSION, SnapshotDtoScript.SCHEMA_VERSION, MetaProgressSnapshotScript.CURRENT_SCHEMA_VERSION, ReplayRecordScript.SCHEMA_VERSION]), "report lists exact game, save, and replay schema versions", failures)
	var pending_lines := FileAccess.get_file_as_string(summary_path).strip_edges().split("\n")
	var pending_summary_value = JSON.parse_string(pending_lines[1]) if pending_lines.size() > 1 else null
	var outlier_dispositions: Array[Dictionary] = []
	if pending_summary_value is Dictionary:
		for outlier_value in pending_summary_value.get("visible_outliers", []):
			if outlier_value is Dictionary:
				outlier_dispositions.append({
					"case_number": int(outlier_value.get("case_number", 0)),
					"owner": "Synthetic Content Owner",
					"disposition": "ACCEPTED_AS_DESIGNED",
					"rationale": "The synthetic timing outlier is included to verify disposition handling.",
				})
	_write_json_file(disposition_path, {
		"schema": "alpha.gate-corpus-outlier-dispositions.v1",
		"dispositions": outlier_dispositions,
	})
	var reviewed_command: Array[String] = [
		OS.get_executable_path(), "--headless", "--path", project_path,
		"--script", "res://scripts/run_alpha_gate_corpus.gd", "--",
		"--full", "--finalize", "--gate", "stage4_beta", "--output", reviewed_summary_path,
		"--report-output", reviewed_report_path, "--outlier-disposition-file", disposition_path,
		"--process-timeout-seconds", "120", "--process-timeout-enforced",
	]
	for chunk_path in chunk_paths:
		reviewed_command.append("--resume-from")
		reviewed_command.append(chunk_path)
	var reviewed_result := _execute_process_wrapper("python3", ProjectSettings.globalize_path("res://scripts/run_alpha_gate_corpus_chunk.py"), reviewed_summary_path, 120, reviewed_command)
	assert_true(
		int(reviewed_result.exit_code) == 1,
		"content-owner dispositions are recorded while independent coverage gates remain failing (exit=%d, output=%s)" % [int(reviewed_result.exit_code), str(reviewed_result.output)],
		failures,
	)
	var reviewed_lines := FileAccess.get_file_as_string(reviewed_summary_path).strip_edges().split("\n") if FileAccess.file_exists(reviewed_summary_path) else PackedStringArray()
	var reviewed_summary_value = JSON.parse_string(reviewed_lines[1]) if reviewed_lines.size() > 1 else null
	assert_true(reviewed_summary_value is Dictionary and reviewed_summary_value.get("content_owner_review", {}).get("status", "") == "DISPOSITIONED_ACCEPTED_AS_DESIGNED" and bool(reviewed_summary_value.get("content_owner_review", {}).get("gate_clear", false)), "a complete owner decision file clears only the outlier review blocker", failures)
	if reviewed_summary_value is Dictionary:
		var reviewed_outliers: Array = reviewed_summary_value.get("visible_outliers", [])
		assert_true(reviewed_outliers.size() == 1 and reviewed_outliers[0].get("content_owner_decision", {}).get("owner", "") == "Synthetic Content Owner", "the final report preserves the recorded owner, disposition, and rationale", failures)
		if reviewed_outliers.size() == 1:
			var reviewed_attempts: Array = reviewed_outliers[0].get("attempts", [])
			assert_true(reviewed_attempts.size() == 2 and reviewed_attempts[0].get("content_owner_decision", {}).get("owner", "") == "Synthetic Content Owner" and reviewed_attempts[1].get("content_owner_decision", {}).get("owner", "") == "Synthetic Content Owner", "the accepted case-level owner disposition is preserved for both attempts", failures)
	var final_status_value = JSON.parse_string(FileAccess.get_file_as_string(summary_path + ".status.json")) if FileAccess.file_exists(summary_path + ".status.json") else null
	assert_true(final_status_value is Dictionary and int(final_status_value.get("process_exit_code", -1)) == 1 and str(final_status_value.get("output_sha256", "")) == _sha256_file(summary_path) and str(final_status_value.get("report_output_sha256", "")) == _sha256_file(report_path), "finalizer status artifact separately records its exit code and exact summary/report hashes", failures)
	for index in range(chunk_paths.size()):
		assert_true(_sha256_file(chunk_paths[index]) == source_hashes[index], "finalization preserves source chunk %d byte-for-byte" % index, failures)
	_cleanup_files(cleanup_paths)

func _create_smoke_source(path: String, failures: Array[String]) -> String:
	_cleanup_files([path, path + ".manifest.json"])
	var smoke_args := PackedStringArray([
		"--smoke", "--gate", "stage4_beta", "--output", path,
	])
	var smoke_result := _execute_corpus_cli(smoke_args)
	assert_true(int(smoke_result.exit_code) == 0, "the real corpus CLI emits a smoke source for provenance fixtures (exit=%d, output=%s)" % [int(smoke_result.exit_code), str(smoke_result.output)], failures)
	return FileAccess.get_file_as_string(path) if int(smoke_result.exit_code) == 0 and FileAccess.file_exists(path) else ""

func _full_chunk_header(base_header: Dictionary, case_start: int, case_limit: int, prior_references: Array, timeout_seconds: int) -> Dictionary:
	var header: Dictionary = base_header.duplicate(true)
	header["run_state"] = "IN_PROGRESS"
	header["evidence_class"] = "FULL_STAGE4_BETA_CORPUS_CHUNK"
	header["gate_evidence_eligible"] = false
	header["resume_source_chunks"] = prior_references.duplicate(true)
	var execution: Dictionary = header.get("execution", {})
	execution["mode"] = "STAGE4_BETA_1000_CASE_CORPUS"
	execution["smoke_only"] = false
	execution["process_timeout_enforced"] = true
	execution["process_timeout_seconds"] = timeout_seconds
	execution["process_timeout_kill_after_seconds"] = 30
	execution["attempt_timeout_msec"] = 120000
	execution["chunk_limit"] = 20 if case_limit > 1 else 1
	execution["start_case_number"] = case_start
	execution["new_case_limit"] = case_limit
	execution["command"] = "synthetic bounded source fixture"
	var timeout_path := _resolved_timeout_executable_path()
	execution["timeout_executable_path"] = timeout_path
	execution["command_argv"] = [timeout_path, "--signal=TERM", "--kill-after=30s", str(timeout_seconds), "synthetic-bounded-command"]
	header["execution"] = execution
	return header

func _write_process_status(chunk_path: String, header: Dictionary, exit_code: int, output_hash_override: String = "") -> void:
	var execution: Dictionary = header.get("execution", {})
	var output_hash := _sha256_file(chunk_path) if output_hash_override.is_empty() else output_hash_override
	_write_json_file(chunk_path + ".status.json", {
		"schema": "alpha.gate-corpus-process-status.v1",
		"timeout_implementation": "GNU coreutils timeout",
		"timeout_version": "timeout (GNU coreutils) 9.1",
		"timeout_executable_path": str(execution.get("timeout_executable_path", "")),
		"timeout_seconds": int(execution.get("process_timeout_seconds", 0)),
		"kill_after_seconds": 30,
		"process_exit_code": exit_code,
		"error": "" if exit_code == 0 else "test fixture exit",
		"command_argv": execution.get("command_argv", []).duplicate(true),
		"command": str(execution.get("command", "")),
		"output_path": chunk_path,
		"output_sha256": output_hash,
		"report_output_path": "",
		"report_output_sha256": "",
	})

func _execute_corpus_cli(arguments: PackedStringArray) -> Dictionary:
	var output_path := ""
	for index in range(arguments.size() - 1):
		if arguments[index] == "--output":
			output_path = arguments[index + 1]
			break
	if output_path.is_empty():
		return {"exit_code": 2, "output": "CLI fixture is missing its explicit --output path."}
	var status_path := output_path + ".status.json"
	_cleanup_files([status_path])
	var command_argv: Array[String] = [
		OS.get_executable_path(),
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://scripts/run_alpha_gate_corpus.gd",
		"--",
	]
	for argument in arguments:
		command_argv.append(str(argument))
	var wrapper_arguments := PackedStringArray([
		ProjectSettings.globalize_path("res://scripts/run_alpha_gate_corpus_chunk.py"),
		"120",
		output_path,
		"--timeout-executable",
		GnuTimeoutLocatorScript.resolve_path(),
		"--",
	])
	for argument in command_argv:
		wrapper_arguments.append(argument)
	var output: Array[String] = []
	var exit_code := OS.execute("python3", wrapper_arguments, output, true)
	_cleanup_files([status_path])
	return {"exit_code": exit_code, "output": "\n".join(output)}

func _resolved_timeout_executable_path() -> String:
	return GnuTimeoutLocatorScript.resolve_path()

func _write_jsonl_records(path: String, records: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	for record in records:
		file.store_string(JSON.stringify(record, "", true, true) + "\n")
	file.close()

func _write_json_file(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
	file.close()

func _write_jsonl_line(file: FileAccess, value: Dictionary) -> Error:
	file.store_string(JSON.stringify(value, "", true, true) + "\n")
	file.flush()
	return file.get_error()

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
		"events": [
			{"event_type": "CharacterSelected", "data": {"character_id": attempt_case.character_id}},
			{"event_type": "ContractSelected", "data": {"contract_id": attempt_case.contract_id}},
		],
		"strategy": {"policy_id": attempt_case.policy_id},
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
		"authoritative_state_valid": true,
	}

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
