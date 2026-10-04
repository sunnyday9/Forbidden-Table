extends RefCounted

const SELECTION_SCRIPT_PATH := "res://src/presentation/ui/battle_tile_selection.gd"
const Stage45BattleUiTestScript = preload("res://tests/stage45_battle_ui_test.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	assert_true(
		ResourceLoader.exists(SELECTION_SCRIPT_PATH),
		"the public tile-selection module is available",
		failures,
	)
	if not ResourceLoader.exists(SELECTION_SCRIPT_PATH):
		return failures

	var selection_path := OS.get_environment("BATTLE_TILE_SELECTION_SCRIPT")
	if selection_path.is_empty():
		selection_path = SELECTION_SCRIPT_PATH
	var selection_script: Script = load(selection_path)
	var selection = selection_script.new()
	selection.reconcile(["copy.a", "copy.b"], [])
	selection.toggle("copy.a")
	var actions: Array[Dictionary] = [
		{"id": "discard.copy.a", "kind": "DISCARD", "target_id": "copy.a", "details": {"tile_id": "base.tile.characters.1", "instance_id": "copy.a"}},
		{"id": "discard.copy.b", "kind": "DISCARD", "target_id": "copy.b", "details": {"tile_id": "base.tile.characters.1", "instance_id": "copy.b"}},
		{"id": "battle.draw", "kind": "DRAW"},
		{"id": "battle.end_turn", "kind": "END_TURN"},
		{"id": "battle.technique", "kind": "TECHNIQUE", "target_id": "technique.global"},
	]
	var matching: Array = selection.matching_actions(actions)
	assert_true(selection.selected_ids() == ["copy.a"], "selection stores the chosen physical copy", failures)
	assert_true(_action_ids(matching) == ["discard.copy.a"], "one Hand copy exposes only its exact tile action", failures)
	assert_true(
		selection.selected_ids() != ["copy.b"] and _action_ids(matching).find("discard.copy.b") < 0,
		"a second copy of the same definition is never conflated with the selected instance",
		failures,
	)
	var returned_action: Dictionary = matching[0]
	returned_action["target_id"] = "copy.b"
	matching[0] = returned_action
	assert_true(actions[0].get("target_id", "") == "copy.a", "matched descriptor snapshots cannot mutate authoritative actions", failures)
	var selected_snapshot: Array = selection.selected_ids()
	selected_snapshot.clear()
	assert_true(selection.selected_ids() == ["copy.a"], "the selected ID snapshot cannot mutate the current selection", failures)
	selection.toggle("copy.a")
	assert_true(selection.selected_ids().is_empty(), "toggling the same physical tile off clears its selection", failures)
	selection.toggle("unavailable.copy")
	assert_true(selection.selected_ids().is_empty(), "a tile outside the reconciled Hand and Reserve cannot be selected", failures)
	selection.toggle("copy.b")
	selection.clear()
	assert_true(selection.selected_ids().is_empty(), "clear removes every selected physical tile", failures)
	assert_true(selection.matching_actions(actions).is_empty(), "no contextual actions are returned without a tile selection", failures)
	_test_partial_settlement(selection_script, failures)
	_test_complete_hand(selection_script, failures)
	_test_reserve_swap_and_reconcile(selection_script, failures)
	_test_live_descriptors_and_purity(selection_script, failures)
	return failures


func _test_partial_settlement(selection_script: Script, failures: Array[String]) -> void:
	var selection = selection_script.new()
	selection.reconcile(["hand.a", "hand.b", "hand.c", "hand.extra", "hand.unmatched"], ["reserve.a"])
	selection.toggle("hand.a")
	selection.toggle("hand.b")
	selection.toggle("hand.c")
	var actions: Array[Dictionary] = [
		{
			"id": "settle.exact",
			"kind": "PARTIAL_SETTLEMENT",
			"target_id": "candidate.exact",
			"details": {"instance_ids": ["hand.c", "hand.a", "hand.b"]},
		},
		{
			"id": "settle.larger",
			"kind": "PARTIAL_SETTLEMENT",
			"target_id": "candidate.larger",
			"details": {"instance_ids": ["hand.a", "hand.b", "hand.c", "hand.extra"]},
		},
	]
	assert_true(
		_action_ids(selection.matching_actions(actions)) == ["settle.exact"],
		"Partial Settlement requires the selected Hand instances to equal one whole candidate",
		failures,
	)
	selection.toggle("reserve.a")
	assert_true(
		selection.matching_actions(actions).is_empty(),
		"a Reserve selection cannot be included in a Partial Settlement candidate",
		failures,
	)
	selection.toggle("reserve.a")
	selection.toggle("hand.extra")
	assert_true(
		_action_ids(selection.matching_actions(actions)) == ["settle.larger"],
		"an expanded selection matches the larger candidate only when it exactly covers that candidate",
		failures,
	)
	selection.toggle("hand.unmatched")
	assert_true(
		selection.matching_actions(actions).is_empty(),
		"an extra selected Hand tile with no corresponding legal descriptor exposes no settlement action",
		failures,
	)


func _test_complete_hand(selection_script: Script, failures: Array[String]) -> void:
	var instance_ids: Array[String] = []
	for index in range(1, 15):
		instance_ids.append("hand.%02d" % index)
	var selection = selection_script.new()
	selection.reconcile(instance_ids, [])
	for instance_id in instance_ids:
		selection.toggle(instance_id)
	var action := {
		"id": "complete.structured",
		"kind": "COMPLETE_HAND",
		"target_id": "complete.interpretation",
		"details": {
			"groups": [
				{"pattern_type": "SEQUENCE", "instance_ids": ["hand.01", "hand.02", "hand.03"]},
				{"pattern_type": "SEQUENCE", "instance_ids": ["hand.04", "hand.05", "hand.06"]},
				{"pattern_type": "TRIPLET", "instance_ids": ["hand.07", "hand.08", "hand.09"]},
				{"pattern_type": "TRIPLET", "instance_ids": ["hand.10", "hand.11", "hand.12"]},
			],
			"pair_instance_ids": ["hand.13", "hand.14"],
			"tile_instance_ids": instance_ids.duplicate(),
		},
	}
	var wrong_pair_action: Dictionary = action.duplicate(true)
	wrong_pair_action["id"] = "complete.wrong-pair"
	wrong_pair_action["details"]["pair_instance_ids"] = ["hand.13", "hand.extra"]
	var flat_ids_only_action: Dictionary = action.duplicate(true)
	flat_ids_only_action["id"] = "complete.flat-ids-only"
	flat_ids_only_action["details"] = {"tile_instance_ids": instance_ids.duplicate()}
	var actions: Array[Dictionary] = [action, wrong_pair_action, flat_ids_only_action]
	assert_true(
		_action_ids(selection.matching_actions(actions)) == ["complete.structured"],
		"Complete Hand matching uses the structured meld and pair instance IDs",
		failures,
	)
	selection.toggle("hand.14")
	assert_true(
		selection.matching_actions(actions).is_empty(),
		"a Complete Hand action requires every physical tile in its interpretation",
		failures,
	)


func _test_reserve_swap_and_reconcile(selection_script: Script, failures: Array[String]) -> void:
	var selection = selection_script.new()
	selection.reconcile(["hand.a", "hand.b"], ["reserve.a", "reserve.b"])
	selection.toggle("reserve.b")
	selection.toggle("hand.a")
	var actions: Array[Dictionary] = [
		{
			"id": "swap.hand-a.reserve-b",
			"kind": "RESERVE_SWAP",
			"target_id": "hand.a",
			"hand_instance_id": "hand.a",
			"reserve_instance_id": "reserve.b",
		},
		{
			"id": "swap.hand-b.reserve-b",
			"kind": "RESERVE_SWAP",
			"target_id": "hand.b",
			"hand_instance_id": "hand.b",
			"reserve_instance_id": "reserve.b",
		},
	]
	assert_true(
		_action_ids(selection.matching_actions(actions)) == ["swap.hand-a.reserve-b"],
		"one Hand tile and one Reserve tile expose only their exact legal swap",
		failures,
	)
	selection.clear()
	selection.toggle("hand.a")
	selection.toggle("hand.b")
	assert_true(selection.matching_actions(actions).is_empty(), "two Hand tiles do not expose a Reserve swap", failures)
	selection.clear()
	selection.toggle("hand.a")
	selection.toggle("reserve.a")
	selection.reconcile(["hand.b"], ["reserve.a"])
	assert_true(selection.selected_ids() == ["reserve.a"], "reconcile removes a stale Hand selection while retaining an available Reserve tile", failures)
	assert_true(selection.matching_actions(actions).is_empty(), "stale descriptors are not retained after reconciliation", failures)
	selection.toggle("hand.b")
	assert_true(selection.matching_actions(actions).is_empty(), "an old swap descriptor cannot target a Reserve tile that is no longer available", failures)
	var current_action: Dictionary = {
		"id": "swap.hand-b.reserve-a",
		"kind": "RESERVE_SWAP",
		"target_id": "hand.b",
		"hand_instance_id": "hand.b",
		"reserve_instance_id": "reserve.a",
	}
	assert_true(
		_action_ids(selection.matching_actions([current_action])) == ["swap.hand-b.reserve-a"],
		"selection matches descriptors supplied after the current Hand and Reserve snapshot",
		failures,
	)


func _test_live_descriptors_and_purity(selection_script: Script, failures: Array[String]) -> void:
	var fixture := Stage45BattleUiTestScript.new()
	var controller = fixture._battle_controller("battle.tile-selection", failures)
	if controller == null:
		return
	var draw_result = controller.confirm("battle.draw")
	assert_true(draw_result != null and draw_result.accepted, "the real fixture draws before exposing tile manipulation descriptors", failures)
	if draw_result == null or not draw_result.accepted:
		return
	var battle = controller.domain.current_battle
	var initial_hand_ids := _instance_ids(battle.zones.contents(TileZoneScript.HAND))
	var initial_reserve_ids := _instance_ids(battle.zones.contents(TileZoneScript.RESERVE))
	var selection = selection_script.new()
	selection.reconcile(initial_hand_ids, initial_reserve_ids)
	var descriptors: Array = controller.action_descriptors()
	var hand_id := initial_hand_ids[0] if not initial_hand_ids.is_empty() else ""
	assert_true(not hand_id.is_empty(), "the real battle fixture contains a physical Hand tile", failures)
	if hand_id.is_empty():
		return
	var expected_tile_action_ids: Array[String] = []
	for action in descriptors:
		if str(action.get("kind", "")) in ["RESERVE", "DISCARD"] and str(action.get("target_id", "")) == hand_id:
			expected_tile_action_ids.append(str(action.get("id", "")))
	assert_true(not expected_tile_action_ids.is_empty(), "the real controller exposes a legal action for the selected Hand instance", failures)
	var checkpoint_before: Dictionary = controller.domain.checkpoint()
	var rng_before: Dictionary = controller.domain.rng_snapshot()
	var commands_before: Array = controller.domain.replay_record.commands.duplicate(true)
	selection.toggle(hand_id)
	assert_true(
		_action_ids(selection.matching_actions(descriptors)) == expected_tile_action_ids,
		"matching uses current authoritative RESERVE and DISCARD descriptors by exact target_id",
		failures,
	)
	assert_true(controller.domain.checkpoint() == checkpoint_before, "tile selection and action matching leave the real Domain checkpoint unchanged", failures)
	assert_true(controller.domain.rng_snapshot() == rng_before, "tile selection and action matching consume no Run RNG", failures)
	assert_true(controller.domain.replay_record.commands == commands_before, "tile selection and action matching append no replay command", failures)

	var complete_hand_definitions: Array[String] = [
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3",
		"base.tile.characters.4", "base.tile.characters.5", "base.tile.characters.6",
		"base.tile.characters.7", "base.tile.characters.7",
	]
	fixture._replace_test_hand(battle, complete_hand_definitions, "tile-selection-complete", failures)
	var complete_actions: Array[Dictionary] = []
	for action in controller.action_descriptors():
		if str(action.get("kind", "")) == "COMPLETE_HAND":
			complete_actions.append(action)
	assert_true(not complete_actions.is_empty(), "the existing Stage 4.5 real Run fixture yields a Complete Hand descriptor", failures)
	if complete_actions.is_empty():
		return
	var complete_hand_ids := _instance_ids(battle.zones.contents(TileZoneScript.HAND))
	selection.clear()
	selection.reconcile(complete_hand_ids, _instance_ids(battle.zones.contents(TileZoneScript.RESERVE)))
	for instance_id in complete_hand_ids:
		selection.toggle(instance_id)
	var complete_checkpoint_before: Dictionary = controller.domain.checkpoint()
	var complete_rng_before: Dictionary = controller.domain.rng_snapshot()
	var complete_commands_before: Array = controller.domain.replay_record.commands.duplicate(true)
	assert_true(
		_action_ids(selection.matching_actions(complete_actions)) == _action_ids(complete_actions),
		"the full real Hand matches each authoritative interpretation using its meld and pair IDs",
		failures,
	)
	assert_true(controller.domain.checkpoint() == complete_checkpoint_before, "Complete Hand matching leaves the real Domain checkpoint unchanged", failures)
	assert_true(controller.domain.rng_snapshot() == complete_rng_before, "Complete Hand matching consumes no Run RNG", failures)
	assert_true(controller.domain.replay_record.commands == complete_commands_before, "Complete Hand matching appends no replay command", failures)


func _instance_ids(tiles: Array) -> Array[String]:
	var instance_ids: Array[String] = []
	for tile in tiles:
		instance_ids.append(str(tile.instance_id))
	return instance_ids


func _action_ids(actions: Array) -> Array[String]:
	var ids: Array[String] = []
	for action in actions:
		if action is Dictionary:
			ids.append(str(action.get("id", "")))
	return ids


func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
