extends RefCounted

const MODULE_SUITES := [
	"res://tests/stage45_ui_foundation_test.gd",
	"res://tests/stage45_bilingual_test.gd",
	"res://tests/stage45_run_ui_test.gd",
	"res://tests/stage45_battle_ui_test.gd",
	"res://tests/stage45_mouse_motion_test.gd",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	for path in MODULE_SUITES:
		var suite: Script = load(path) as Script
		if suite == null or not suite.can_instantiate():
			failures.append("Stage 4.5 module suite could not load: " + path)
			continue
		var instance = suite.new()
		failures.append_array(await instance.run())
	print("STAGE45_UI_REPORT modules=%d failures=%d physical_device=NOT_PERFORMED participant_testing=NOT_PERFORMED" % [MODULE_SUITES.size(), failures.size()])
	return failures
