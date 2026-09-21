class_name DomainSmokeTest
extends RefCounted

const DomainSmokeScenario = preload("res://src/domain/smoke_scenario.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var result: Dictionary = DomainSmokeScenario.new().run()
	assert_true(result.get("passed", false), "the domain smoke scenario passes", failures)
	assert_true(result.get("definition_id", "") == "base.tile.man.5", "the smoke scenario uses a stable TileDefinition ID", failures)
	assert_true(result.get("zone", "") == "hand", "the smoke scenario places the TileInstance in Hand", failures)
	return failures

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
