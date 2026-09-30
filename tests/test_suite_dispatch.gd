extends RefCounted

const SUITES := [
	{"id": "stage2-exit-review", "flag": "--stage2-exit-review", "default": true},
	{"id": "alpha-simulation", "flag": "--alpha-simulation", "default": true},
	{"id": "alpha-simulation-coverage", "flag": "--alpha-simulation-coverage", "also_selected_by_flag": "--alpha-simulation", "default": true},
	{"id": "run-scene", "flag": "--run-scene", "default": true},
	{"id": "meta-progress", "flag": "--meta-progress", "default": true},
	{"id": "character-passive", "flag": "--character-passive", "default": true},
	{"id": "run-summary", "flag": "--run-summary", "default": true},
	{"id": "stage4-content", "flag": "--stage4-content", "default": true},
	{"id": "stage4-onboarding-flow", "flag": "--stage4-onboarding-flow", "default": false},
	{"id": "stage4-accessibility", "flag": "--stage4-accessibility", "default": true},
]

static func select_suite_ids(test_arguments: PackedStringArray, focused_test_requested: bool) -> Array[String]:
	var selected_ids: Array[String] = []
	for suite in SUITES:
		var selected_by_flag: bool = (
			test_arguments.has(str(suite.get("flag", "")))
			or test_arguments.has(str(suite.get("also_selected_by_flag", "")))
		)
		var selected_by_default: bool = not focused_test_requested and bool(suite.get("default", false))
		if selected_by_flag or selected_by_default:
			selected_ids.append(str(suite.get("id", "")))
	return selected_ids
