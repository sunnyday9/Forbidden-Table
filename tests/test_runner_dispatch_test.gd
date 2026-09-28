extends RefCounted

const TestSuiteDispatch = preload("res://tests/test_suite_dispatch.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var default_suite_ids := TestSuiteDispatch.select_suite_ids(PackedStringArray(), false)
	var expected_default_suite_ids: Array[String] = [
		"stage2-exit-review",
		"alpha-simulation",
		"alpha-simulation-coverage",
		"run-scene",
		"meta-progress",
		"character-passive",
		"run-summary",
		"stage4-content",
	]
	assert_true(
		default_suite_ids == expected_default_suite_ids,
		"the default runner selects Stage 2 exit review, Alpha simulation and coverage, Run scene, Meta Progress, Character passive, Run Summary, and Stage 4 aggregate content exactly once",
		failures
	)
	var focused_cases: Array[Dictionary] = [
		{"flag": "--stage2-exit-review", "suites": ["stage2-exit-review"]},
		{"flag": "--alpha-simulation", "suites": ["alpha-simulation", "alpha-simulation-coverage"]},
		{"flag": "--run-scene", "suites": ["run-scene"]},
		{"flag": "--meta-progress", "suites": ["meta-progress"]},
		{"flag": "--character-passive", "suites": ["character-passive"]},
		{"flag": "--run-summary", "suites": ["run-summary"]},
		{"flag": "--stage4-content", "suites": ["stage4-content"]},
	]
	for focused_case in focused_cases:
		var expected_ids: Array[String] = []
		for expected_id in focused_case.get("suites", []):
			expected_ids.append(str(expected_id))
		var focused_flag := str(focused_case.get("flag", ""))
		assert_true(
			TestSuiteDispatch.select_suite_ids(PackedStringArray([focused_flag]), true) == expected_ids,
			"focused %s selects only its assigned suite(s)" % focused_flag,
			failures
		)
	assert_true(
		TestSuiteDispatch.select_suite_ids(PackedStringArray(["--rng"]), true).is_empty(),
		"an unrelated focused option does not select the default-only suites",
		failures
	)
	assert_true(
		TestSuiteDispatch.select_suite_ids(PackedStringArray(["--run-summary", "--run-summary"]), true) == ["run-summary"],
		"repeated focus arguments do not dispatch a suite more than once",
		failures
	)
	return failures

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
