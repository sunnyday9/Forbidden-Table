class_name AlphaFixedRunBenchmarkTest
extends RefCounted

const FixedRunBenchmarkScript = preload("res://scripts/alpha_fixed_run_attempt.gd")
const AttemptComparatorScript = preload("res://src/infrastructure/simulation/alpha_attempt_comparator.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_fixed_benchmark_attempt_is_complete_and_reproducible(failures)
	return failures

func test_fixed_benchmark_attempt_is_complete_and_reproducible(failures: Array[String]) -> void:
	var first_definition: Dictionary = FixedRunBenchmarkScript.fixed_workload_definition()
	var second_definition: Dictionary = FixedRunBenchmarkScript.fixed_workload_definition()
	var result: Dictionary = FixedRunBenchmarkScript.run_fixed_attempt()
	var repeated_result: Dictionary = FixedRunBenchmarkScript.run_fixed_attempt()
	assert_true(not first_definition.has("benchmark_error"), "the fixed benchmark workload builds successfully", failures)
	assert_true(not second_definition.has("benchmark_error"), "the repeated fixed benchmark workload builds successfully", failures)
	assert_true(not result.has("benchmark_error"), "the fixed benchmark attempt runs successfully", failures)
	assert_true(not repeated_result.has("benchmark_error"), "the repeated fixed benchmark attempt runs successfully", failures)
	if first_definition.has("benchmark_error") or second_definition.has("benchmark_error") or result.has("benchmark_error") or repeated_result.has("benchmark_error"):
		return

	var first_workload: Dictionary = first_definition.get("workload", {})
	var second_workload: Dictionary = second_definition.get("workload", {})
	var result_workload: Dictionary = result.get("workload", {})
	var repeated_workload: Dictionary = repeated_result.get("workload", {})
	var attempt: Dictionary = result.get("attempt", {})
	var repeated_attempt: Dictionary = repeated_result.get("attempt", {})
	var repeat_report: Dictionary = AttemptComparatorScript.compare(attempt, repeated_attempt)
	assert_true(result.get("benchmark_id", "") == "alpha.fixed-complete-run.v3", "the full two-Act benchmark has a stable workload ID", failures)
	assert_true(first_workload == second_workload, "the fixed attempt case and manifest are stable across repetitions", failures)
	assert_true(first_workload == result_workload, "the executed attempt uses the declared stable workload", failures)
	assert_true(first_workload == repeated_workload, "the repeated attempt uses the same declared stable workload", failures)
	assert_true(repeat_report.get("matches", false), "fixed-seed attempts reproduce accepted commands, checkpoints, RNG, events, and outcome (%s)" % str(repeat_report.get("differences", [])), failures)
	assert_true(int(first_workload.get("seed", -1)) == 57001, "the benchmark uses the proven full-Run seed under the Draw Action budget", failures)
	assert_true(str(first_workload.get("policy_id", "")) == "Complete", "the benchmark uses its declared fixed strategy policy", failures)
	assert_true(str(first_workload.get("character_id", "")) == "base.character.reserve", "the benchmark uses its proven character", failures)
	assert_true(str(first_workload.get("contract_id", "")) == "base.contract.pool_bias", "the benchmark uses its proven contract", failures)
	assert_true(str(first_workload.get("route_id", "")) == "SERVICE", "the benchmark uses its proven route", failures)
	assert_true(int(first_workload.get("command_limit", 0)) == 1024, "the benchmark uses a fixed command limit", failures)
	assert_true(attempt.get("two_act_profile", false), "the runner executes the two-Act profile", failures)
	assert_true(attempt.get("configured_act_count", 0) == 2, "the attempt records the configured two-Act count", failures)
	assert_true(attempt.get("act_reached", 0) == 2, "the fixed benchmark reaches the final Act", failures)
	assert_true(attempt.get("progress_status", "") == "TERMINAL_AFTER_FINAL_ACT", "the fixed benchmark terminates after the final Act", failures)
	assert_true(attempt.get("terminal", false), "the complete Run reaches a terminal summary", failures)
	assert_true(attempt.get("outcome", "") == "VICTORY", "the fixed benchmark reaches the real two-Act ending", failures)
	var act_two_transition_seen := false
	var run_summary_seen := false
	for event in attempt.get("events", []):
		if not event is Dictionary:
			continue
		var event_type := str(event.get("event_type", ""))
		var event_data: Dictionary = event.get("data", {})
		if event_type == "ActTransitioned" and int(event_data.get("to_act", 0)) == 2:
			act_two_transition_seen = true
		if event_type == "RunSummaryReached":
			run_summary_seen = true
	assert_true(act_two_transition_seen, "the benchmark reaches Act 2 through the authoritative Domain transition", failures)
	assert_true(run_summary_seen, "the benchmark reaches the authoritative Run Summary", failures)
	assert_true(attempt.get("failure_classification", "") == "NONE", "a complete gameplay outcome is not a harness failure", failures)
	assert_true(attempt.get("replay_status", "") == "MATCH", "the accepted-command replay verifies", failures)
	assert_true(attempt.get("accepted_command_count", -1) == attempt.get("accepted_commands", []).size(), "accepted-command count matches the recorded trace", failures)
	assert_true(attempt.get("checkpoints", []).size() == attempt.get("accepted_command_count", -2) + 1, "the attempt retains initial and accepted-command checkpoints", failures)
	assert_true(attempt.get("checkpoint_hashes", []).size() == attempt.get("checkpoints", []).size(), "every checkpoint has a state hash", failures)
	assert_true(attempt.get("rng_snapshots", []).size() == attempt.get("checkpoints", []).size(), "every checkpoint has an RNG snapshot", failures)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
