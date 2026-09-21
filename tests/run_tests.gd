extends SceneTree

const SmokeTest = preload("res://tests/domain_smoke_test.gd")

func _init() -> void:
	var test = SmokeTest.new()
	var failures: Array[String] = []
	failures.append_array(test.run())
	if "--fail" in OS.get_cmdline_args():
		test.assert_true(false, "forced failure probe", failures)

	if failures.is_empty():
		print("PASS: domain smoke scenario")
		quit(0)
		return

	for failure in failures:
		print("FAIL: " + failure)
	quit(1)
