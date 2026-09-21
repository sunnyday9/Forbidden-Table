extends SceneTree

const SmokeTest = preload("res://tests/domain_smoke_test.gd")
const ContentRegistryTest = preload("res://tests/content_registry_test.gd")
const RngStreamTest = preload("res://tests/rng_stream_test.gd")

func _init() -> void:
	var content_registry_only := "--content-registry" in OS.get_cmdline_args()
	var rng_only := "--rng" in OS.get_cmdline_args()
	var failures: Array[String] = []
	if not content_registry_only and not rng_only:
		failures.append_array(SmokeTest.new().run())
	if not rng_only:
		failures.append_array(ContentRegistryTest.new().run())
	if not content_registry_only:
		failures.append_array(RngStreamTest.new().run())
	if "--fail" in OS.get_cmdline_args():
		failures.append("ASSERTION FAILED: forced failure probe")
		push_error("ASSERTION FAILED: forced failure probe")

	if failures.is_empty():
		if content_registry_only:
			print("PASS: content registry tests")
		elif rng_only:
			print("PASS: RNG stream tests")
		else:
			print("PASS: domain smoke scenario, content registry, and RNG stream tests")
		quit(0)
		return

	for failure in failures:
		print("FAIL: " + failure)
	quit(1)
