extends SceneTree

const SmokeTest = preload("res://tests/domain_smoke_test.gd")
const ContentRegistryTest = preload("res://tests/content_registry_test.gd")
const RngStreamTest = preload("res://tests/rng_stream_test.gd")
const TileZoneTest = preload("res://tests/tile_zone_test.gd")
const DrawActionTest = preload("res://tests/draw_action_test.gd")

func _init() -> void:
	var content_registry_only := "--content-registry" in OS.get_cmdline_args()
	var rng_only := "--rng" in OS.get_cmdline_args()
	var tile_zones_only := "--tile-zones" in OS.get_cmdline_args()
	var draw_actions_only := "--draw-actions" in OS.get_cmdline_args()
	var focused_test_requested := content_registry_only or rng_only or tile_zones_only or draw_actions_only
	var failures: Array[String] = []
	if not focused_test_requested:
		failures.append_array(SmokeTest.new().run())
	if not focused_test_requested or content_registry_only:
		failures.append_array(ContentRegistryTest.new().run())
	if not focused_test_requested or rng_only:
		failures.append_array(RngStreamTest.new().run())
	if not focused_test_requested or tile_zones_only:
		failures.append_array(TileZoneTest.new().run())
	if not focused_test_requested or draw_actions_only:
		failures.append_array(DrawActionTest.new().run())
	if "--fail" in OS.get_cmdline_args():
		failures.append("ASSERTION FAILED: forced failure probe")
		push_error("ASSERTION FAILED: forced failure probe")

	if failures.is_empty():
		if content_registry_only:
			print("PASS: content registry tests")
		elif rng_only:
			print("PASS: RNG stream tests")
		elif tile_zones_only:
			print("PASS: tile zone tests")
		elif draw_actions_only:
			print("PASS: draw action tests")
		else:
			print("PASS: domain smoke scenario, content registry, RNG stream, tile zone, and draw action tests")
		quit(0)
		return

	for failure in failures:
		print("FAIL: " + failure)
	quit(1)
