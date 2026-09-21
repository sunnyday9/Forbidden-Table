extends SceneTree

const SmokeTest = preload("res://tests/domain_smoke_test.gd")
const ContentRegistryTest = preload("res://tests/content_registry_test.gd")

func _init() -> void:
	var content_registry_only := "--content-registry" in OS.get_cmdline_args()
	var failures: Array[String] = []
	if not content_registry_only:
		failures.append_array(SmokeTest.new().run())
	failures.append_array(ContentRegistryTest.new().run())
	if "--fail" in OS.get_cmdline_args():
		failures.append("ASSERTION FAILED: forced failure probe")
		push_error("ASSERTION FAILED: forced failure probe")

	if failures.is_empty():
		if content_registry_only:
			print("PASS: content registry tests")
		else:
			print("PASS: domain smoke scenario and content registry tests")
		quit(0)
		return

	for failure in failures:
		print("FAIL: " + failure)
	quit(1)
