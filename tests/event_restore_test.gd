class_name EventRestoreTest
extends RefCounted

const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const ShopOfferScript = preload("res://src/domain/run/shop_offer.gd")
const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const JsonIntegerCodecScript = preload("res://src/infrastructure/serialization/json_integer_codec.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_completed_node_histories_survive_json_restore(failures)
	return failures

func test_completed_node_histories_survive_json_restore(failures: Array[String]) -> void:
	var registry = ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	var source = RunDomainScript.new("event.restore.roundtrip", 8402, registry)
	var character_result = source.execute(ChooseCharacterCommandScript.new("event.restore.character", "base.character.sequence"))
	var contract_result = source.execute(ChooseContractCommandScript.new("event.restore.contract", "base.contract.pressure"))
	assert_true(character_result.accepted and contract_result.accepted, "the fixture reaches a stable map checkpoint", failures)
	if not character_result.accepted or not contract_result.accepted:
		return

	var event_state = source.state.event_state
	event_state.node_id = "base.map_node.event.right"
	event_state.entry_id = "event.restore.roundtrip.1"
	event_state.event_id = "base.event.map_reveal"
	event_state.choices = [{"choice_id": "map_reveal.annotate", "alternative_id": "map_reveal.annotation"}]
	event_state.entry_sequence = 1
	event_state.event_rng_state = source.rng_streams.event.snapshot()
	event_state.mark_completed("map_reveal.annotate", "map_reveal.annotation")

	var shop_state = source.state.shop_state
	shop_state.node_id = "base.map_node.shop"
	shop_state.entry_id = "event.restore.roundtrip.shop.1"
	shop_state.offers.append(ShopOfferScript.new("event.restore.shop.offer", 0, ShopOfferScript.RELIC, "base.relic.open_hand", 5))
	shop_state.mark_completed()
	var workshop_state = source.state.workshop_state
	workshop_state.begin("base.map_node.workshop", "event.restore.roundtrip.workshop.1")
	workshop_state.mark_completed()

	var expected_event_nodes: Array[String] = ["base.map_node.event.right"]
	var expected_shop_nodes: Array[String] = ["base.map_node.shop"]
	var expected_workshop_nodes: Array[String] = ["base.map_node.workshop"]
	var snapshot = SaveMapperScript.suspend_snapshot(source)
	var serialized_snapshot: String = snapshot.serialize()
	var parsed = JsonIntegerCodecScript.parse(serialized_snapshot)
	assert_true(parsed.accepted, "the suspend snapshot passes through the real JSON encoder and integer-safe parser", failures)
	if parsed.accepted:
		var wire_state: Dictionary = parsed.data.get("authoritative_state", {})
		assert_true(wire_state.get("event_state", {}).get("completed_node_ids", []) == expected_event_nodes, "the JSON suspend stores completed Event node IDs", failures)
		assert_true(wire_state.get("shop_state", {}).get("completed_node_ids", []) == expected_shop_nodes, "the JSON suspend stores completed Shop node IDs", failures)
		assert_true(wire_state.get("workshop_state", {}).get("completed_node_ids", []) == expected_workshop_nodes, "the JSON suspend stores completed Workshop node IDs", failures)

	var loaded = SaveMapperScript.load_into_domain(serialized_snapshot, registry)
	assert_true(loaded.get("accepted", false), "the serialized suspend restores through the normal SaveMapper validation pipeline", failures)
	if not loaded.get("accepted", false):
		return
	assert_true(loaded.domain.checkpoint() == source.checkpoint(), "the restored Run reproduces the exact authoritative checkpoint", failures)
	assert_true(loaded.domain.state.event_state.completed_node_ids == expected_event_nodes, "restored Event completion history retains its typed node IDs", failures)
	assert_true(loaded.domain.state.shop_state.completed_node_ids == expected_shop_nodes, "restored Shop completion history retains its typed node IDs", failures)
	assert_true(loaded.domain.state.workshop_state.completed_node_ids == expected_workshop_nodes, "restored Workshop completion history retains its typed node IDs", failures)
	assert_true(
		loaded.domain.state.event_state.choices == event_state.choices
		and loaded.domain.state.event_state.selected_choice_id == "map_reveal.annotate"
		and loaded.domain.state.event_state.resolved_alternative_id == "map_reveal.annotation",
		"available and selected Event choice data survives alongside completion history",
		failures,
	)
	assert_true(
		loaded.domain.state.shop_state.offers.size() == 1
		and loaded.domain.state.shop_state.offers[0].status == ShopOfferScript.AVAILABLE,
		"the available Shop offer remains available after restoring completion history",
		failures,
	)
	_test_malformed_completed_node_history_is_rejected(serialized_snapshot, registry, "shop_state", "INVALID_SHOP_PURCHASE_STATE", failures)
	_test_malformed_completed_node_history_is_rejected(serialized_snapshot, registry, "event_state", "INVALID_EVENT_STATE", failures)
	_test_malformed_completed_node_history_is_rejected(serialized_snapshot, registry, "workshop_state", "INVALID_WORKSHOP_PURCHASE_STATE", failures)
	_test_absent_completed_node_history_defaults_to_empty(serialized_snapshot, registry, failures)

func _test_malformed_completed_node_history_is_rejected(serialized_snapshot: String, registry, owner_field: String, expected_error: String, failures: Array[String]) -> void:
	var owner_node_id: String = {
		"shop_state": "base.map_node.shop",
		"event_state": "base.map_node.event.right",
		"workshop_state": "base.map_node.workshop",
	}[owner_field]
	var malformed_values: Array = [
		{"label": "non-array", "value": "not-an-array"},
		{"label": "non-string element", "value": [owner_node_id, 17]},
	]
	for malformed in malformed_values:
		var invalid_history := _snapshot_with_history(serialized_snapshot, owner_field, malformed.value, false)
		assert_true(not invalid_history.is_empty(), "%s %s fixture has a valid recomputed checkpoint hash" % [owner_field, malformed.label], failures)
		var loaded := SaveMapperScript.load_into_domain(invalid_history, registry)
		assert_true(not loaded.get("accepted", false), "%s %s history is rejected" % [owner_field, malformed.label], failures)
		assert_true(loaded.get("code", "") == "VALIDATION_FAILED", "%s %s is rejected during validation before reconstruction" % [owner_field, malformed.label], failures)
		assert_true(_has_validation_error(loaded, expected_error), "%s %s reports %s" % [owner_field, malformed.label, expected_error], failures)
		assert_true(not loaded.has("domain"), "%s %s rejection exposes no partially reconstructed Domain" % [owner_field, malformed.label], failures)

func _test_absent_completed_node_history_defaults_to_empty(serialized_snapshot: String, registry, failures: Array[String]) -> void:
	var legacy_snapshot := _snapshot_with_history(serialized_snapshot, "shop_state", null, true)
	var parsed := JsonIntegerCodecScript.parse(legacy_snapshot)
	if not parsed.get("accepted", false):
		assert_true(false, "legacy snapshot without completion-history fields parses", failures)
		return
	var state: Dictionary = parsed.data.get("authoritative_state", {})
	state.get("event_state", {}).erase("completed_node_ids")
	state.get("workshop_state", {}).erase("completed_node_ids")
	var compatibility_snapshot := _serialize_with_valid_state_hash(parsed.data)
	var loaded := SaveMapperScript.load_into_domain(compatibility_snapshot, registry)
	assert_true(loaded.get("accepted", false), "a legacy snapshot with absent Shop/Event/Workshop completion-history fields remains loadable", failures)
	if loaded.get("accepted", false):
		assert_true(loaded.domain.state.shop_state.completed_node_ids.is_empty(), "an absent Shop history defaults to an empty typed history", failures)
		assert_true(loaded.domain.state.event_state.completed_node_ids.is_empty(), "an absent Event history defaults to an empty typed history", failures)
		assert_true(loaded.domain.state.workshop_state.completed_node_ids.is_empty(), "an absent Workshop history defaults to an empty typed history", failures)

func _snapshot_with_history(serialized_snapshot: String, owner_field: String, value, erase_field: bool) -> String:
	var parsed := JsonIntegerCodecScript.parse(serialized_snapshot)
	if not parsed.get("accepted", false):
		return ""
	var snapshot: Dictionary = parsed.data
	var state: Dictionary = snapshot.get("authoritative_state", {})
	var owner: Dictionary = state.get(owner_field, {})
	if erase_field:
		owner.erase("completed_node_ids")
	else:
		owner["completed_node_ids"] = value
	return _serialize_with_valid_state_hash(snapshot)

func _serialize_with_valid_state_hash(snapshot: Dictionary) -> String:
	var state: Dictionary = snapshot.get("authoritative_state", {})
	var deterministic_state: Dictionary = state.duplicate(true)
	deterministic_state.erase("run_started_at_unix_seconds")
	var metadata: Dictionary = snapshot.get("checkpoint_metadata", {})
	metadata["state_hash"] = DeterministicSerializerScript.hash(deterministic_state)
	return JSON.stringify(snapshot)

func _has_validation_error(result: Dictionary, code: String) -> bool:
	for error in result.get("errors", []):
		if str(error.get("code", "")) == code:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
