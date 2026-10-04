extends RefCounted

const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	TranslationServer.set_locale("en")
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	var controller = RunPresentationControllerScript.new(RunDomainScript.new("presentation.events", 8103, registry))
	var failures: Array[String] = []

	var initial_snapshot: Dictionary = controller.snapshot()
	assert_true(initial_snapshot.get("battle_event_revision", -1) == 0, "a new controller starts with event revision zero", failures)
	assert_true(initial_snapshot.get("battle_events", null) is Array and initial_snapshot.battle_events.is_empty(), "a new controller exposes an empty battle-event batch", failures)

	var character_result = controller.confirm("character:base.character.sequence")
	assert_true(character_result.accepted, "the public Character command is accepted", failures)
	var character_snapshot: Dictionary = controller.snapshot()
	var expected_events: Array = []
	for event in character_result.events:
		expected_events.append(event.to_dictionary())
	assert_true(character_snapshot.get("battle_event_revision", -1) == 1, "one nonempty command event batch advances the public revision once", failures)
	assert_true(character_snapshot.get("battle_events", []) == expected_events, "the snapshot exposes complete serialized DomainEvents in order", failures)
	assert_true(character_snapshot.get("last_domain_event_types", []) == _event_types(expected_events), "legacy event type feedback follows the transported event order", failures)

	var caller_snapshot: Dictionary = controller.snapshot()
	var caller_events: Array = caller_snapshot.get("battle_events", [])
	if not caller_events.is_empty():
		var caller_event: Dictionary = caller_events[0]
		var caller_payload: Dictionary = caller_event.get("data", {})
		caller_payload["character_id"] = "caller.changed"
		caller_payload["nested_probe"] = {"records": [{"value": "original"}]}
		var nested_probe: Dictionary = caller_payload["nested_probe"]
		nested_probe.records[0]["value"] = "caller.changed"
		caller_event["data"] = caller_payload
		caller_events[0] = caller_event
	var after_caller_mutation: Dictionary = controller.snapshot()
	assert_true(after_caller_mutation.get("battle_events", []) == expected_events, "nested caller mutations cannot change a later controller snapshot", failures)

	controller.focus_next()
	var after_focus: Dictionary = controller.snapshot()
	assert_true(after_focus.get("battle_event_revision", -1) == 1 and after_focus.get("battle_events", []) == expected_events, "focus changes retain the latest event batch without advancing its revision", failures)
	TranslationServer.set_locale("zh_CN")
	controller.refresh_localized_presentation()
	var after_localization: Dictionary = controller.snapshot()
	assert_true(after_localization.get("battle_event_revision", -1) == 1 and after_localization.get("battle_events", []) == expected_events, "an empty localization refresh retains the batch and does not replay it", failures)
	assert_true(after_localization.get("last_domain_event_types", []).is_empty(), "empty localization refresh preserves the existing event-type reset behavior", failures)
	TranslationServer.set_locale("en")

	var contract_result = controller.confirm("contract:base.contract.pressure")
	assert_true(contract_result.accepted, "the next public Contract command is accepted", failures)
	var contract_snapshot: Dictionary = controller.snapshot()
	var contract_events: Array = []
	for event in contract_result.events:
		contract_events.append(event.to_dictionary())
	assert_true(contract_snapshot.get("battle_event_revision", -1) == 2, "a second nonempty command batch advances the revision monotonically", failures)
	assert_true(contract_snapshot.get("battle_events", []) == contract_events, "a newer command replaces the prior transported batch in domain order", failures)
	assert_true(contract_snapshot.get("last_domain_event_types", []) == _event_types(contract_events), "legacy event type feedback still describes the latest domain batch", failures)

	return failures

func _event_types(events: Array) -> Array:
	var result: Array = []
	for event in events:
		result.append(str(event.get("event_type", "")))
	return result

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
