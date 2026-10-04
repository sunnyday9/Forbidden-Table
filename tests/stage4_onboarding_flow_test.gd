class_name Stage4OnboardingFlowTest
extends RefCounted

const RunScene = preload("res://scenes/run/run_scene.tscn")
const MetaProgressCoordinator = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStore = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const AlphaScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ContentVersionMigration = preload("res://src/infrastructure/persistence/content_version_migration.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const TutorialProgress = preload("res://src/presentation/run/tutorial_progress.gd")
const ShopOffer = preload("res://src/domain/run/shop_offer.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const UseWorkshopServiceCommand = preload("res://src/domain/commands/use_workshop_service_command.gd")
const ScriptedContentRegistry = preload("res://tests/fixtures/stage4_onboarding_content_registry.gd")
const CRITICAL_BATTLE_ACTION_KINDS := ["DRAW", "PARTIAL_SETTLEMENT", "TECHNIQUE", "DISCARD", "END_TURN", "RESERVE", "RESERVE_SWAP", "COMPLETE_HAND"]

var _virtual_keyboard_accepts := 0
var _virtual_controller_accepts := 0
var _virtual_keyboard_cancels := 0
var _virtual_controller_cancels := 0
var _virtual_keyboard_navigations := 0
var _virtual_controller_navigations := 0
var _forced_input_mode := ""
var _keyboard_action_inputs := 0
var _controller_action_inputs := 0
var _keyboard_run_outcomes := 0
var _controller_run_outcomes := 0
var _battle_keyboard_outcomes: Dictionary = {}
var _battle_controller_outcomes: Dictionary = {}

func run() -> Array[String]:
	var failures: Array[String] = []
	await test_virtual_inputs_obey_input_map(failures)
	await test_virtual_focus_navigation_and_controller_confirm(failures)
	await test_virtual_battle_critical_actions(failures)
	await test_virtual_cancel_exits_shop(failures)
	await test_virtual_suspend_resume(failures)
	await test_new_profile_tutorial_two_act_flow_and_unlocked_roster(failures)
	return failures

func test_virtual_inputs_obey_input_map(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_input_map_profile_%s.json" % suffix
	var suspend_path := "user://stage4_input_map_suspend_%s.json" % suffix
	var scene = _new_test_scene(profile_path, suspend_path)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	if scene.controller == null:
		assert_true(false, "InputMap fallback check starts a Run", failures)
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	var original_down_events: Array = InputMap.action_get_events("ui_down")
	InputMap.action_erase_events("ui_down")
	var focused_before := str(scene.controller.snapshot().get("focused_action_id", ""))
	_push_key(scene, KEY_DOWN)
	assert_true(str(scene.controller.snapshot().get("focused_action_id", "")) == focused_before, "keyboard input without a ui_down InputMap binding does not move Run focus", failures)
	for event in original_down_events:
		InputMap.action_add_event("ui_down", event)

	var original_accept_events: Array = InputMap.action_get_events("ui_accept")
	InputMap.action_erase_events("ui_accept")
	var phase_before := str(scene.controller.domain.state.phase)
	_push_joypad_button(scene, JOY_BUTTON_A)
	assert_true(str(scene.controller.domain.state.phase) == phase_before, "controller input without a ui_accept InputMap binding does not confirm a Run action", failures)
	for event in original_accept_events:
		InputMap.action_add_event("ui_accept", event)
	tree.root.remove_child(scene)
	scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)

func test_virtual_focus_navigation_and_controller_confirm(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_input_focus_profile_%s.json" % suffix
	var suspend_path := "user://stage4_input_focus_suspend_%s.json" % suffix
	var scene = _new_test_scene(profile_path, suspend_path)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(960, 540)
	tree.root.add_child(scene)
	await tree.process_frame
	if scene.controller == null:
		assert_true(false, "virtual focus setup starts a Run", failures)
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	var initial_focus_ids: Array = scene.controller.snapshot().get("focus_action_ids", [])
	var first_id := str(initial_focus_ids[0]) if not initial_focus_ids.is_empty() else ""
	var second_id := str(initial_focus_ids[1]) if initial_focus_ids.size() > 1 else ""
	var first_button: Button = find_action_button(scene, first_id)
	var focus_owner: Control = scene.get_viewport().gui_get_focus_owner()
	assert_true(not initial_focus_ids.is_empty() and first_id == str(scene.controller.snapshot().get("focused_action_id", "")), "the first visible Character choice matches the presentation focus", failures)
	assert_true(first_button != null and first_button.has_focus() and focus_owner == first_button, "the first visible Character choice owns visible focus", failures)
	if first_button == null or not first_button.has_focus() or second_id.is_empty():
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	_push_virtual_direction(scene, 1, false)
	var second_button: Button = find_action_button(scene, second_id)
	assert_true(scene.get_viewport().gui_get_focus_owner() != first_button, "keyboard Down visibly advances to the next interactive control", failures)
	_navigate_to_action(scene, second_id, failures)
	_push_virtual_direction(scene, -1, true)
	first_button = find_action_button(scene, first_id)
	assert_true(scene.get_viewport().gui_get_focus_owner() != second_button, "controller D-pad Up visibly moves to the previous interactive control", failures)
	_navigate_to_action(scene, first_id, failures)
	var before_selection: int = scene.controller.domain.replay_record.commands.size()
	_push_key(scene, KEY_ENTER)
	assert_phase(scene, RunPhase.CHARACTER_SELECT, "keyboard Enter selects the visibly focused Character without committing", failures)
	assert_true(scene.controller.domain.replay_record.commands.size() == before_selection, "Character selection leaves authoritative state unchanged", failures)
	_commit_pending_choice(scene, first_id, "Character commit", failures, false)
	assert_phase(scene, RunPhase.CONTRACT_SELECT, "keyboard Enter on the commit control confirms the selected Character", failures)
	assert_true(first_id.begins_with("character:") and str(scene.controller.domain.state.character_id) == first_id.trim_prefix("character:"), "the confirmed Character matches the focused choice", failures)
	tree.root.remove_child(scene)
	scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)

func test_virtual_battle_critical_actions(failures: Array[String]) -> void:
	var previous_mode := _forced_input_mode
	_forced_input_mode = "keyboard"
	await _run_virtual_battle_critical_actions(failures)
	_assert_battle_action_coverage("keyboard", failures)
	_forced_input_mode = "controller"
	await _run_virtual_battle_critical_actions(failures)
	_assert_battle_action_coverage("controller", failures)
	_forced_input_mode = previous_mode

func _run_virtual_battle_critical_actions(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_battle_inputs_profile_%s.json" % suffix
	var suspend_path := "user://stage4_battle_inputs_suspend_%s.json" % suffix
	var scene = _new_test_scene(profile_path, suspend_path)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	if scene.controller == null:
		assert_true(false, "mapped Battle action setup starts a Run", failures)
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	press_action(scene, "character:%s" % Phase2Catalog.CHARACTER_IDS[0], RunPhase.CONTRACT_SELECT, failures)
	press_action(scene, "contract:%s" % Phase2Catalog.CONTRACT_IDS[0], RunPhase.MAP_CHOICE, failures)
	press_action(scene, "map:%s" % scene.controller.domain.map_definition.start_node_id, RunPhase.BATTLE, failures)
	var battle = scene.controller.domain.current_battle
	assert_true(battle != null, "mapped Battle route creates the authoritative BattleDomain", failures)
	if battle == null:
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	# Test-only prestate keeps the encounter alive while every mapped Battle action is checked.
	battle.combat_state.enemy_max_hp = 1000
	battle.combat_state.enemy_hp = 1000
	battle.combat_state.pressure_limit = 1000
	battle.combat_state.pressure = 0
	_prepare_mapped_battle_hand(battle, [
		"base.tile.characters.1", "base.tile.characters.1", "base.tile.characters.1",
		"base.tile.characters.2", "base.tile.characters.3", "base.tile.characters.4",
		"base.tile.characters.5", "base.tile.characters.6", "base.tile.characters.7",
		"base.tile.characters.2", "base.tile.characters.3", "base.tile.characters.8", "base.tile.characters.9",
	], "partial", failures)
	scene._render()
	var hand_before_draw: int = int(battle.zones.size(TileZone.HAND))
	press_battle_action(scene, "battle.draw", failures)
	assert_true(battle.zones.size(TileZone.HAND) == hand_before_draw + 1, "mapped Draw adds a tile to the authoritative Hand", failures)

	var partial_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "PARTIAL_SETTLEMENT")
	assert_true(not partial_actions.is_empty(), "the deterministic test hand exposes a legal partial Settlement action", failures)
	if not partial_actions.is_empty():
		var partial_hand_before: int = int(battle.zones.size(TileZone.HAND))
		var partial_discard_before: int = int(battle.zones.size(TileZone.DISCARD))
		press_battle_action(scene, str(partial_actions[0].get("id", "")), failures)
		assert_true(battle.zones.size(TileZone.HAND) < partial_hand_before and battle.zones.size(TileZone.DISCARD) > partial_discard_before, "mapped partial Settlement moves its selected Pattern out of Hand", failures)

	var technique_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "TECHNIQUE")
	assert_true(not technique_actions.is_empty(), "the starting build exposes an available mapped Technique action", failures)
	if not technique_actions.is_empty():
		var enemy_hp_before: int = int(battle.combat_state.enemy_hp)
		press_battle_action(scene, str(technique_actions[0].get("id", "")), failures)
		assert_true(battle.combat_state.enemy_hp < enemy_hp_before, "mapped Technique changes the authoritative enemy HP", failures)

	var discard_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "DISCARD")
	assert_true(not discard_actions.is_empty(), "a mapped Draw exposes a legal Discard action", failures)
	if not discard_actions.is_empty():
		var discarded_id := str(discard_actions[0].get("target_id", ""))
		press_battle_action(scene, str(discard_actions[0].get("id", "")), failures)
		assert_true(battle.zones.zone_of(discarded_id) == TileZone.DISCARD, "mapped Discard moves the selected TileInstance into Discard", failures)

	var intent_index_before: int = int(battle.combat_state.intent_index)
	press_battle_action(scene, "battle.end_turn", failures)
	assert_true(battle.combat_state.intent_index == intent_index_before + 1, "mapped End Turn advances the authoritative enemy Intent", failures)
	press_battle_action(scene, "battle.draw", failures)
	var reserve_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "RESERVE")
	assert_true(not reserve_actions.is_empty(), "a mapped Draw exposes a legal Reserve action", failures)
	if not reserve_actions.is_empty():
		var reserved_id := str(reserve_actions[0].get("target_id", ""))
		press_battle_action(scene, str(reserve_actions[0].get("id", "")), failures)
		assert_true(battle.zones.zone_of(reserved_id) == TileZone.RESERVE, "mapped Reserve moves the selected TileInstance into Reserve", failures)

	press_battle_action(scene, "battle.end_turn", failures)
	press_battle_action(scene, "battle.draw", failures)
	var swap_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "RESERVE_SWAP")
	assert_true(not swap_actions.is_empty(), "a mapped Draw with a populated Reserve exposes a legal Reserve Swap", failures)
	if not swap_actions.is_empty():
		var hand_id := str(swap_actions[0].get("hand_instance_id", ""))
		var reserve_id := str(swap_actions[0].get("reserve_instance_id", ""))
		press_battle_action(scene, str(swap_actions[0].get("id", "")), failures)
		assert_true(battle.zones.zone_of(hand_id) == TileZone.RESERVE and battle.zones.zone_of(reserve_id) == TileZone.HAND, "mapped Reserve Swap exchanges the selected Hand and Reserve TileInstances", failures)

	_prepare_mapped_battle_hand(battle, [
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3",
		"base.tile.characters.4", "base.tile.characters.5", "base.tile.characters.6",
		"base.tile.characters.7", "base.tile.characters.7",
	], "complete", failures)
	_sync_test_fixture_focus(scene)
	scene._render()
	var complete_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "COMPLETE_HAND")
	assert_true(battle.can_complete_hand() and not complete_actions.is_empty(), "the deterministic complete-hand fixture exposes a legal Complete Hand action", failures)
	if not complete_actions.is_empty():
		press_battle_action(scene, str(complete_actions[0].get("id", "")), failures)
		assert_true(battle.is_recovering(), "mapped Complete Hand enters authoritative Recovery", failures)
	tree.root.remove_child(scene)
	scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)

func _prepare_mapped_battle_hand(battle, definition_ids: Array, fixture_name: String, failures: Array[String]) -> void:
	for tile in battle.zones.contents(TileZone.HAND):
		var moved: bool = battle.zones.transfer(str(tile.instance_id), TileZone.HAND, TileZone.DISCARD)
		assert_true(moved, "%s test fixture moves the previous Hand tile out of Hand" % fixture_name, failures)
	for index in definition_ids.size():
		var tile := TileInstance.new("stage4.input.%s.%02d" % [fixture_name, index], str(definition_ids[index]))
		assert_true(battle.zones.add(tile, TileZone.HAND), "%s test fixture installs a deterministic Hand tile" % fixture_name, failures)

func _sync_test_fixture_focus(scene) -> void:
	var action_ids: Array = []
	for action in scene.controller.action_descriptors():
		action_ids.append(str(action.get("id", "")))
	scene.controller.state.set_focus_actions(action_ids, str(scene.controller.snapshot().get("focused_action_id", "")))

func test_virtual_cancel_exits_shop(failures: Array[String]) -> void:
	var previous_mode := _forced_input_mode
	var keyboard_outcomes_before := _keyboard_run_outcomes
	var keyboard_inputs_before := _keyboard_action_inputs
	_forced_input_mode = "keyboard"
	await _run_virtual_cancel_exits_shop(failures)
	assert_true(_keyboard_run_outcomes > keyboard_outcomes_before, "keyboard RunScene input reaches mapped Shop and Workshop outcomes", failures)
	assert_true(_keyboard_action_inputs > keyboard_inputs_before, "keyboard RunScene input confirms mapped Shop and Workshop actions", failures)
	var controller_outcomes_before := _controller_run_outcomes
	var controller_inputs_before := _controller_action_inputs
	_forced_input_mode = "controller"
	await _run_virtual_cancel_exits_shop(failures)
	assert_true(_controller_run_outcomes > controller_outcomes_before, "controller RunScene input reaches mapped Shop and Workshop outcomes", failures)
	assert_true(_controller_action_inputs > controller_inputs_before, "controller RunScene input confirms mapped Shop and Workshop actions", failures)
	_forced_input_mode = previous_mode

func _run_virtual_cancel_exits_shop(failures: Array[String]) -> void:
	var mode_cancel_count_before := _virtual_controller_cancels if _use_controller_input() else _virtual_keyboard_cancels
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_input_cancel_profile_%s.json" % suffix
	var suspend_path := "user://stage4_input_cancel_suspend_%s.json" % suffix
	var scene = _new_test_scene(profile_path, suspend_path)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	if scene.controller == null:
		assert_true(false, "virtual cancel regression setup starts a Run", failures)
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	var domain = scene.controller.domain
	press_action(scene, "character:%s" % Phase2Catalog.CHARACTER_IDS[0], RunPhase.CONTRACT_SELECT, failures)
	press_action(scene, "contract:%s" % Phase2Catalog.CONTRACT_IDS[0], RunPhase.MAP_CHOICE, failures)
	press_action(scene, "map:%s" % domain.map_definition.start_node_id, RunPhase.BATTLE, failures)
	if not win_active_battle(scene, failures):
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	press_action(scene, "map:base.map_node.normal.left", RunPhase.BATTLE, failures)
	if not win_active_battle(scene, failures):
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	press_action(scene, "map:base.map_node.shop", RunPhase.MAP_CHOICE, failures)
	assert_true(str(domain.state.map_state.current_node_id) == "base.map_node.shop", "mapped Shop route selects the authoritative Shop node", failures)
	press_action(scene, "run.enter.shop", RunPhase.SHOP, failures)
	assert_phase(scene, RunPhase.SHOP, "the regression setup reaches its Shop", failures)
	scene.controller.domain.state.gold = 1000
	scene._render()
	var shop_offers: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "SHOP_OFFER")
	assert_true(not shop_offers.is_empty(), "Shop exposes a legal visible offer choice", failures)
	if not shop_offers.is_empty():
		var shop_offer: Dictionary = shop_offers[0]
		var offer_id := str(shop_offer.get("target_id", ""))
		var offer_price := int(shop_offer.get("details", {}).get("price", 0))
		var shop_gold_before := int(scene.controller.domain.state.gold)
		press_action(scene, str(shop_offer.get("id", "")), RunPhase.SHOP, failures)
		var purchased_offer = scene.controller.domain.state.shop_state.offer_by_id(offer_id)
		assert_true(purchased_offer != null and purchased_offer.status == ShopOffer.SOLD, "mapped confirmation marks the selected Shop offer SOLD", failures)
		assert_true(scene.controller.domain.state.gold == shop_gold_before - offer_price, "mapped Shop purchase spends the displayed Gold price", failures)
	_push_virtual_cancel(scene, _use_controller_input())
	assert_phase(scene, RunPhase.MAP_CHOICE, "mapped cancel leaves Shop after its purchase", failures)
	assert_visible_action_focus(scene, "Shop exit restores visible focus to an available Map route", failures)
	press_action(scene, "map:base.map_node.workshop", RunPhase.MAP_CHOICE, failures)
	press_action(scene, "run.enter.workshop", RunPhase.WORKSHOP, failures)
	var services: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "WORKSHOP_SELECT_SERVICE")
	assert_true(not services.is_empty(), "Workshop exposes at least one legal, focusable service choice", failures)
	var target_services: Array = services.filter(func(action): return str(action.get("service_id", "")) in [UseWorkshopServiceCommand.TRANSFORM, UseWorkshopServiceCommand.ADD_MODIFIER])
	assert_true(not target_services.is_empty(), "Workshop exposes a legal service that requires an explicit target choice", failures)
	if not target_services.is_empty():
		press_action(scene, str(target_services[0].get("id", "")), RunPhase.WORKSHOP, failures)
		var nested_choices: Array = scene.controller.action_descriptors()
		assert_true(nested_choices.any(func(action): return action.get("kind", "") == "WORKSHOP_SELECT_TARGET"), "choosing a Workshop service exposes a visible target selection", failures)
		_push_virtual_cancel(scene, _use_controller_input())
		var returned_choices: Array = scene.controller.action_descriptors()
		assert_true(returned_choices.any(func(action): return action.get("kind", "") == "WORKSHOP_SELECT_SERVICE"), "mapped cancel backs out of Workshop target selection to the visible service list", failures)
		var focused_service_id := str(scene.controller.snapshot().get("focused_action_id", ""))
		var focused_service_button: Button = find_action_button(scene, focused_service_id)
		assert_true(focused_service_button != null and focused_service_button.has_focus(), "controller B restores visible focus to a Workshop service choice", failures)
	var transform_services: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "WORKSHOP_SELECT_SERVICE" and str(action.get("service_id", "")) == UseWorkshopServiceCommand.TRANSFORM)
	assert_true(not transform_services.is_empty(), "Workshop exposes a legal Transform action with value choices", failures)
	if not transform_services.is_empty():
		press_action(scene, str(transform_services[0].get("id", "")), RunPhase.WORKSHOP, failures)
		var transform_targets: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "WORKSHOP_SELECT_TARGET" and str(action.get("service_id", "")) == UseWorkshopServiceCommand.TRANSFORM)
		assert_true(not transform_targets.is_empty(), "Transform exposes a visible target selection", failures)
		if not transform_targets.is_empty():
			var selected_target_id := str(transform_targets[0].get("instance_id", ""))
			var tile_record = _find_run_tile_record(scene, selected_target_id)
			var definition_before := str(tile_record.definition_id) if tile_record != null else ""
			press_action(scene, str(transform_targets[0].get("id", "")), RunPhase.WORKSHOP, failures)
			var transform_values: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "WORKSHOP_SERVICE" and str(action.get("service_id", "")) == UseWorkshopServiceCommand.TRANSFORM and str(action.get("instance_id", "")) == selected_target_id and str(action.get("value_id", "")) != definition_before)
			assert_true(not transform_values.is_empty(), "mapped Transform target selection exposes a distinct legal tile definition", failures)
			if not transform_values.is_empty():
				var expected_definition := str(transform_values[0].get("value_id", ""))
				press_action(scene, str(transform_values[0].get("id", "")), RunPhase.WORKSHOP, failures)
				tile_record = _find_run_tile_record(scene, selected_target_id)
				assert_true(tile_record != null and str(tile_record.definition_id) == expected_definition and expected_definition != definition_before, "mapped Transform changes the selected TileInstance to its chosen value", failures)
	var command_services: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "WORKSHOP_SELECT_SERVICE" and str(action.get("service_id", "")) in [UseWorkshopServiceCommand.REMOVE, UseWorkshopServiceCommand.DUPLICATE])
	assert_true(not command_services.is_empty(), "Workshop exposes a legal Remove or Duplicate command after returning from target selection", failures)
	if not command_services.is_empty():
		var selected_service: Dictionary = command_services[0]
		var selected_service_id := str(selected_service.get("service_id", ""))
		press_action(scene, str(selected_service.get("id", "")), RunPhase.WORKSHOP, failures)
		var service_commands: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "WORKSHOP_SERVICE")
		assert_true(not service_commands.is_empty(), "choosing a concrete Workshop service exposes a visible command action", failures)
		if not service_commands.is_empty():
			var tile_count_before: int = int(scene.controller.domain.state.tile_pool.tile_instances.size())
			press_action(scene, str(service_commands[0].get("id", "")), RunPhase.WORKSHOP, failures)
			var tile_delta: int = int(scene.controller.domain.state.tile_pool.tile_instances.size()) - tile_count_before
			var expected_tile_delta := -1 if selected_service_id == UseWorkshopServiceCommand.REMOVE else 1
			assert_true(tile_delta == expected_tile_delta, "mapped Workshop %s command changes the Run Tile Pool as presented" % selected_service_id, failures)
	_push_virtual_cancel(scene, _use_controller_input())
	assert_phase(scene, RunPhase.MAP_CHOICE, "mapped cancel leaves Workshop and returns to the map", failures)
	assert_visible_action_focus(scene, "Workshop exit restores visible focus to an available Map route", failures)
	var mode_cancel_count_after := _virtual_controller_cancels if _use_controller_input() else _virtual_keyboard_cancels
	assert_true(mode_cancel_count_after > mode_cancel_count_before, "%s mapped cancel reaches a visible Workshop back or exit action" % _forced_input_mode, failures)
	tree.root.remove_child(scene)
	scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)

func test_virtual_suspend_resume(failures: Array[String]) -> void:
	var previous_mode := _forced_input_mode
	var keyboard_outcomes_before := _keyboard_run_outcomes
	var keyboard_inputs_before := _keyboard_action_inputs
	_forced_input_mode = "keyboard"
	await _run_virtual_suspend_resume(failures)
	assert_true(_keyboard_run_outcomes > keyboard_outcomes_before, "keyboard RunScene input reaches Suspend and Resume outcomes", failures)
	assert_true(_keyboard_action_inputs > keyboard_inputs_before, "keyboard RunScene input confirms Suspend and Resume actions", failures)
	var controller_outcomes_before := _controller_run_outcomes
	var controller_inputs_before := _controller_action_inputs
	_forced_input_mode = "controller"
	await _run_virtual_suspend_resume(failures)
	assert_true(_controller_run_outcomes > controller_outcomes_before, "controller RunScene input reaches Suspend and Resume outcomes", failures)
	assert_true(_controller_action_inputs > controller_inputs_before, "controller RunScene input confirms Suspend and Resume actions", failures)
	_forced_input_mode = previous_mode

func _run_virtual_suspend_resume(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_input_resume_profile_%s.json" % suffix
	var suspend_path := "user://stage4_input_resume_suspend_%s.json" % suffix
	var tree := Engine.get_main_loop() as SceneTree
	var suspended_scene = _new_test_scene(profile_path, suspend_path)
	tree.root.add_child(suspended_scene)
	await tree.process_frame
	if suspended_scene.controller == null:
		assert_true(false, "virtual resume setup starts its source Run", failures)
		tree.root.remove_child(suspended_scene)
		suspended_scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	press_action(suspended_scene, "character:%s" % Phase2Catalog.CHARACTER_IDS[0], RunPhase.CONTRACT_SELECT, failures)
	press_action(suspended_scene, "contract:%s" % Phase2Catalog.CONTRACT_IDS[0], RunPhase.MAP_CHOICE, failures)
	var run_id := str(suspended_scene.controller.domain.state.run_id)
	var checkpoint: Dictionary = suspended_scene.controller.domain.checkpoint()
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(suspend_path)), "the selected Contract writes a resumable Suspend Save", failures)
	tree.root.remove_child(suspended_scene)
	suspended_scene.free()

	var resumed_scene = _new_test_scene(profile_path, suspend_path)
	tree.root.add_child(resumed_scene)
	await tree.process_frame
	var resume_button: Button = find_named_node(resumed_scene, "ResumeRunButton")
	assert_true(resumed_scene.controller == null and resume_button.visible and not resume_button.disabled, "launch presents an enabled, focusable Resume Run decision for the saved Run", failures)
	_activate_button(resumed_scene, resume_button, "Resume Run", failures)
	assert_true(resumed_scene.controller != null, "virtual confirmation attaches the resumed Run controller", failures)
	if resumed_scene.controller != null:
		assert_true(str(resumed_scene.controller.domain.state.run_id) == run_id, "virtual Resume restores the same Run identity", failures)
		assert_true(resumed_scene.controller.domain.checkpoint() == checkpoint, "virtual Resume restores the saved checkpoint without changing Run state", failures)
		assert_phase(resumed_scene, RunPhase.MAP_CHOICE, "virtual Resume returns to the saved map choice", failures)
	tree.root.remove_child(resumed_scene)
	resumed_scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)

func test_new_profile_tutorial_two_act_flow_and_unlocked_roster(failures: Array[String]) -> void:
	var previous_mode := _forced_input_mode
	var keyboard_outcomes_before := _keyboard_run_outcomes
	var keyboard_inputs_before := _keyboard_action_inputs
	_forced_input_mode = "keyboard"
	await _run_new_profile_tutorial_two_act_flow_and_unlocked_roster(failures, "keyboard")
	assert_true(_keyboard_run_outcomes - keyboard_outcomes_before >= 25, "keyboard RunScene input reaches the complete onboarding and two-Act outcome path", failures)
	assert_true(_keyboard_action_inputs > keyboard_inputs_before, "keyboard RunScene input confirms onboarding and two-Act actions", failures)
	var controller_outcomes_before := _controller_run_outcomes
	var controller_inputs_before := _controller_action_inputs
	_forced_input_mode = "controller"
	await _run_new_profile_tutorial_two_act_flow_and_unlocked_roster(failures, "controller")
	assert_true(_controller_run_outcomes - controller_outcomes_before >= 25, "controller RunScene input reaches the complete onboarding and two-Act outcome path", failures)
	assert_true(_controller_action_inputs > controller_inputs_before, "controller RunScene input confirms onboarding and two-Act actions", failures)
	_forced_input_mode = previous_mode

func _run_new_profile_tutorial_two_act_flow_and_unlocked_roster(failures: Array[String], input_mode: String) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_onboarding_profile_%s.json" % suffix
	var suspend_path := "user://stage4_onboarding_suspend_%s.json" % suffix
	var scene = _new_test_scene(profile_path, suspend_path)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	assert_true(scene.find_child("TutorialPrompt", true, false) is Label, "RunScene exposes a player-visible tutorial prompt", failures)
	assert_true(scene._preferences_overlay.find_child("TutorialEnabledButton", true, false) is CheckButton, "Help exposes a tutorial enable or disable action", failures)
	assert_true(scene._preferences_overlay.find_child("TutorialResetButton", true, false) is Button, "Help exposes a tutorial reset action", failures)
	assert_true(scene.controller.tutorial_progress.completed_step_ids.is_empty(), "tutorial has no completed steps before the first Battle", failures)
	var new_run_at_start: Button = find_named_node(scene, "NewRunButton")
	assert_true(new_run_at_start != null and new_run_at_start.disabled, "New Run is disabled while the first Run is in progress", failures)
	assert_true(scene.controller != null, "a new profile starts through the normal RunScene launch path", failures)
	if scene.controller == null:
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	var state = scene.controller.domain.state
	var run_id := str(state.run_id)
	var build_info: Dictionary = Engine.get_version_info()
	var engine_version := str(build_info.get("string", "unknown"))
	var build_version := str(ProjectSettings.get_setting("application/config/version", "unknown"))
	var content_version := str(state.content_version)
	var replay_game_version := str(scene.controller.domain.replay_record.game_version)
	assert_true(engine_version.begins_with("4.7.2"), "the scripted flow reports the pinned Godot engine version", failures)
	assert_true(build_version == "stage3-alpha-playable-1", "the scripted flow reports the configured application build version", failures)
	assert_true(replay_game_version == "game.phase2.v1", "the scripted flow reports the replay compatibility version separately", failures)
	assert_true(content_version == ContentVersionMigration.ACT_TWO_SCALE_V13, "the scripted flow uses the pinned Stage 4 Beta content bundle", failures)
	assert_true(scene.controller.domain.state.act_count == 2, "a new profile starts one continuous two-Act Run", failures)
	assert_actions_visible_and_enabled(scene, "CHARACTER", Phase2Catalog.CHARACTER_IDS, failures)
	assert_help_prompt(scene, "CHARACTER_SELECT", "Choose a Character", failures)

	press_action(scene, "character:%s" % Phase2Catalog.CHARACTER_IDS[0], RunPhase.CONTRACT_SELECT, failures)
	assert_actions_visible_and_enabled(scene, "CONTRACT", Phase2Catalog.CONTRACT_IDS, failures)
	assert_help_prompt(scene, "CONTRACT_SELECT", "Select a Contract", failures)
	press_action(scene, "contract:%s" % Phase2Catalog.CONTRACT_IDS[0], RunPhase.MAP_CHOICE, failures)
	assert_help_prompt(scene, "MAP_CHOICE", "adjacent node", failures)
	press_action(scene, "map:%s" % scene.controller.domain.map_definition.start_node_id, RunPhase.BATTLE, failures)
	assert_help_prompt(scene, "BATTLE", "Draw tiles", failures)
	var tutorial_prompt: Label = find_named_node(scene, "TutorialPrompt")

	assert_true(tutorial_prompt.visible and not tutorial_prompt.text.is_empty(), "the first Run presents tutorial guidance during Battle", failures)
	var step_before_disable: String = scene.controller.tutorial_progress.current_step_id
	_apply_tutorial_help(scene, false, failures)
	assert_true(not scene.controller.tutorial_progress.enabled and not tutorial_prompt.visible, "disabling tutorial guidance hides its prompt", failures)
	press_action(scene, "battle.draw", RunPhase.BATTLE, failures)
	assert_true(scene.controller.tutorial_progress.current_step_id == step_before_disable, "a disabled tutorial does not advance on a real Draw event", failures)
	assert_true(scene._preferences_overlay.find_child("TutorialResetButton", true, false) != null, "Help retains tutorial Reset while disabled", failures)
	_apply_tutorial_help(scene, true, failures)
	assert_true(scene.controller.tutorial_progress.enabled and scene.controller.tutorial_progress.current_step_id == TutorialProgress.DRAW_PATTERN_PARTIAL, "Reset reenables tutorial guidance at the first step", failures)
	assert_true(tutorial_prompt.visible and tutorial_prompt.text.contains("draw a tile"), "Reset restores the first visible tutorial prompt", failures)
	press_action(scene, "battle.draw", RunPhase.BATTLE, failures)
	assert_true(scene.controller.tutorial_progress.current_step_id == TutorialProgress.TP_CORE_TECHNIQUE, "an enabled tutorial advances from the authoritative Draw event", failures)
	assert_true(tutorial_prompt.text.contains("Core Technique"), "the next tutorial step displays its matching prompt", failures)
	win_active_battle(scene, failures)
	assert_phase(scene, RunPhase.REWARD_CHOICE, "winning the intro encounter opens its Normal reward", failures)
	choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	assert_phase(scene, RunPhase.MAP_CHOICE, "choosing a Normal reward returns to the map", failures)

	for act_index in [1, 2]:
		if not complete_remaining_act_path(scene, act_index, failures):
			scene.free()
			_clear_test_file(profile_path)
			_clear_test_file(suspend_path)
			return
		if act_index == 1:
			assert_true(scene.controller.domain.state.act_index == 2 and scene.controller.domain.state.phase == RunPhase.MAP_CHOICE, "the Act 1 Boss reward crosses the boundary into the same Run's Act 2 map", failures)
			assert_true(find_named_node(scene, "RunPhaseLabel").text.contains("Act 2 of 2"), "the Act 1 reward presents the Act 2 destination", failures)
		else:
			assert_phase(scene, RunPhase.RUN_SUMMARY, "the Act 2 Boss reward reaches the Normal Ending Run Summary", failures)
			assert_true(find_named_node(scene, "RunSummaryPanel").visible and find_named_node(scene, "RunSummaryText").text.contains("Result: Victory (Boss Defeated)"), "Run Summary visibly presents the Normal Ending", failures)
			var finish_button: Button = find_named_node(scene, "CommitSelectedButton")
			assert_true(finish_button.visible and not finish_button.disabled, "Run Summary exposes an enabled Finish Run action", failures)
			assert_true(scene.get_viewport().gui_get_focus_owner() == finish_button and finish_button.has_focus(), "Run Summary initial visible focus lands on Finish Run", failures)
			_activate_button(scene, finish_button, "Finish Run", failures)
			assert_phase(scene, RunPhase.RUN_COMPLETE, "acknowledging Run Summary finishes the Run", failures)
	var new_run_button: Button = find_named_node(scene, "NewRunButton")
	assert_true(new_run_button.visible and not new_run_button.disabled, "New Run is enabled only after Run completion", failures)
	assert_true(scene.meta_progress_coordinator.state.unlocked_character_ids.size() == 3, "the completed first Run unlocks the third Character", failures)
	assert_true(scene.meta_progress_coordinator.state.unlocked_contract_ids.size() == 8, "the completed first Run unlocks the full eight-Contract roster", failures)
	var completed_summary = scene.controller.domain.state.terminal_summary
	assert_true(completed_summary.outcome == "VICTORY" and completed_summary.reason == "BOSS_DEFEATED", "the authoritative ending records the normal Act 2 Boss victory", failures)
	_activate_button(scene, new_run_button, "New Run", failures)
	assert_true(scene.controller != null and scene.controller.domain.state.run_id != run_id, "New Run starts a new Run through the normal selection flow", failures)
	var all_character_ids: Array = Phase2Catalog.CHARACTER_IDS.duplicate()
	all_character_ids.append(AlphaScaleCatalog.CHARACTER_ID)
	assert_actions_visible_and_enabled(scene, "CHARACTER", all_character_ids, failures)
	assert_help_prompt(scene, "CHARACTER_SELECT", "Choose a Character", failures)
	press_action(scene, "character:%s" % AlphaScaleCatalog.CHARACTER_ID, RunPhase.CONTRACT_SELECT, failures)
	var all_contract_ids: Array = Phase2Catalog.CONTRACT_IDS.duplicate()
	all_contract_ids.append_array(AlphaScaleCatalog.CONTRACT_IDS)
	assert_actions_visible_and_enabled(scene, "CONTRACT", all_contract_ids, failures)
	assert_help_prompt(scene, "CONTRACT_SELECT", "Select a Contract", failures)
	press_action(scene, "contract:%s" % AlphaScaleCatalog.CONTRACT_IDS[-1], RunPhase.MAP_CHOICE, failures)
	assert_true(scene.controller.domain.state.character_id == AlphaScaleCatalog.CHARACTER_ID and scene.controller.domain.state.contract_id == AlphaScaleCatalog.CONTRACT_IDS[-1], "the newly unlocked Character and Contract both start through normal selection", failures)
	assert_true(scene.controller.snapshot().authoritative_snapshot == scene.controller.domain.checkpoint(), "the final selection screen mirrors the authoritative Run checkpoint", failures)

	var mechanical_status := "PASS" if failures.is_empty() else "FAIL"
	if input_mode == "controller":
		print("STAGE4_ONBOARDING_FLOW_REPORT script=res://tests/stage4_onboarding_flow_test.gd focused_command='./scripts/test.sh --stage4-onboarding-flow' full_command='./scripts/test.sh' build_version=%s replay_game_version=%s engine=%s content_bundle=%s fixture=onboarding_combat(enemy_hp=1,pressure_limit=1000,core_damage=1,test_only);battle_input_fixture(enemy_max_hp=1000,enemy_hp=1000,pressure=0,pressure_limit=1000,starting_hand_relocated_to_discard=true,partial_hand_tiles=13,complete_hand_tiles=14,focus_resynced_to_fixture_actions=true,test_only);shop_workshop_fixture(gold_override=1000,test_only) seed=%d keyboard_mapping=Enter/Esc/Tab/arrows controller_mapping=A/B/DPad/shoulders keyboard_accepts=%d controller_accepts=%d keyboard_cancel=%d controller_cancel=%d keyboard_focus_moves=%d controller_focus_moves=%d keyboard_action_inputs=%d controller_action_inputs=%d keyboard_run_outcomes=%d controller_run_outcomes=%d keyboard_battle_outcomes=%s controller_battle_outcomes=%s defect_ledger=none(severity=NA,owner=NA) physical_device=NOT_PERFORMED native_metrics=NOT_CLAIMED mechanical_flow=%s human_comprehension_or_clarity=NOT_EVALUATED" % [
		build_version, replay_game_version, engine_version, content_version, int(scene.controller.domain.state.seed), _virtual_keyboard_accepts, _virtual_controller_accepts, _virtual_keyboard_cancels, _virtual_controller_cancels, _virtual_keyboard_navigations, _virtual_controller_navigations, _keyboard_action_inputs, _controller_action_inputs, _keyboard_run_outcomes, _controller_run_outcomes, _battle_outcomes_report(_battle_keyboard_outcomes), _battle_outcomes_report(_battle_controller_outcomes), mechanical_status,
		])
	tree.root.remove_child(scene)
	scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)

func complete_remaining_act_path(scene, act_index: int, failures: Array[String]) -> bool:
	var domain = scene.controller.domain
	var prefix := "base.map_node.act_two." if act_index == 2 else "base.map_node."
	if act_index == 2:
		press_map_target(scene, prefix + "intro", RunPhase.BATTLE, failures)
		if not win_active_battle(scene, failures):
			return false
		choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	var normal_left_id := prefix + "normal.left"
	press_map_target(scene, normal_left_id, RunPhase.BATTLE, failures)
	if not win_active_battle(scene, failures):
		return false
	choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	var event_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "MAP_NODE" and action.get("node_kind", "") == "EVENT")
	assert_true(event_actions.size() == 1, "Act %d branch presents one selectable Event route" % act_index, failures)
	if event_actions.is_empty():
		return false
	press_action(scene, str(event_actions[0].get("id", "")), RunPhase.MAP_CHOICE, failures)
	assert_true(str(domain.state.map_state.current_node_id).contains("event.left"), "the Event route updates the authoritative current Map node", failures)
	var enter_event = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "ENTER_EVENT")
	assert_true(enter_event.size() == 1, "the visited Event node enables its Enter Event action", failures)
	if enter_event.is_empty():
		return false
	press_action(scene, str(enter_event[0].get("id", "")), RunPhase.EVENT, failures)
	var event_options = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "EVENT_OPTION" and action.get("target_id", "") == "leave")
	assert_true(not event_options.is_empty(), "Event presentation exposes the safe Leave choice", failures)
	if event_options.is_empty():
		return false
	press_action(scene, str(event_options[0].get("id", "")), RunPhase.MAP_CHOICE, failures)
	assert_true(domain.state.event_state.completed and not domain.state.event_state.selected_choice_id.is_empty(), "the selected Event choice updates authoritative Event state", failures)
	press_map_target(scene, prefix + "normal.mid", RunPhase.BATTLE, failures)
	if not win_active_battle(scene, failures):
		return false
	choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	press_map_kind(scene, "ELITE", RunPhase.BATTLE, failures)
	if not win_active_battle(scene, failures):
		return false
	assert_phase(scene, RunPhase.ELITE_REWARD, "the Act %d Elite win opens its reward choices" % act_index, failures)
	choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	press_map_kind(scene, "BOSS", RunPhase.BATTLE, failures)
	if not win_active_battle(scene, failures):
		return false
	assert_phase(scene, RunPhase.BOSS_REWARD, "the Act %d Boss win opens its three-choice Rule Breaker draft" % act_index, failures)
	var boss_rewards: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "BOSS_REWARD")
	assert_true(boss_rewards.size() == 3, "Act %d Boss reward visibly enables three choices" % act_index, failures)
	var boss_reward_choice_ids: Array = []
	for action in boss_rewards:
		boss_reward_choice_ids.append(str(action.get("target_id", "")))
	assert_actions_visible_and_enabled(scene, "BOSS_REWARD", boss_reward_choice_ids, failures)
	if boss_rewards.is_empty():
		return false
	var selected_content_id := str(boss_rewards[0].get("content_id", ""))
	press_action(scene, str(boss_rewards[0].get("id", "")), RunPhase.MAP_CHOICE if act_index == 1 else RunPhase.RUN_SUMMARY, failures)
	assert_true(domain.state.build_ownership.acquired_rule_breaker_ids.has(selected_content_id), "the selected Act %d Boss reward is applied to authoritative build ownership" % act_index, failures)
	assert_true(domain.state.reward_draft == null, "the selected Act %d Boss draft is consumed" % act_index, failures)
	return true

func press_map_target(scene, target_id: String, expected_phase: String, failures: Array[String]) -> void:
	press_action(scene, "map:%s" % target_id, expected_phase, failures)

func press_map_kind(scene, node_kind: String, expected_phase: String, failures: Array[String]) -> void:
	var actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "MAP_NODE" and action.get("node_kind", "") == node_kind)
	assert_true(actions.size() == 1, "%s route is visible and unambiguous" % node_kind, failures)
	if actions.is_empty():
		return
	press_action(scene, str(actions[0].get("id", "")), expected_phase, failures)

func choose_first_reward(scene, expected_phase: String, failures: Array[String]) -> void:
	var rewards: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") in ["REWARD", "ELITE_REWARD"])
	assert_true(not rewards.is_empty(), "the active reward screen exposes an enabled reward choice", failures)
	if rewards.is_empty():
		return
	press_action(scene, str(rewards[0].get("id", "")), expected_phase, failures)
	assert_true(scene.controller.domain.state.reward_draft == null, "the selected reward draft is consumed", failures)

func win_active_battle(scene, failures: Array[String]) -> bool:
	var domain = scene.controller.domain
	assert_true(domain.current_battle != null, "the selected encounter creates an authoritative BattleDomain", failures)
	if domain.current_battle == null:
		return false
	# The fixture exposes one-damage Core Techniques; actions still resolve through the player-facing controls.
	var action_count := 0
	while str(domain.state.phase) == RunPhase.BATTLE and action_count < 16:
		var technique_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "TECHNIQUE")
		if not technique_actions.is_empty():
			press_battle_action(scene, str(technique_actions[0].get("id", "")), failures)
		else:
			press_action(scene, "battle.end_turn", RunPhase.BATTLE, failures)
		action_count += 1
	var victory := str(domain.state.phase) in [RunPhase.REWARD_CHOICE, RunPhase.ELITE_REWARD, RunPhase.BOSS_REWARD, RunPhase.RUN_SUMMARY]
	assert_true(victory, "the visible Core Technique action resolves the encounter to its next Run destination", failures)
	return victory

func press_battle_action(scene, action_id: String, failures: Array[String]) -> void:
	_select_action_tiles(scene, action_id, failures)
	var button: Button = find_action_button(scene, action_id)
	assert_true(button != null and button.visible and not button.disabled, "Battle action %s is visibly enabled" % action_id, failures)
	if button == null or button.disabled:
		return
	var action_kind := ""
	for action in scene.controller.action_descriptors():
		if str(action.get("id", "")) == action_id:
			action_kind = str(action.get("kind", ""))
			break
	var activated_button_name: String = str(button.name)
	var command_count_before: int = scene.controller.domain.replay_record.commands.size()
	_activate_button(scene, button, "Battle action %s" % action_id, failures)
	assert_true(scene.controller.domain.replay_record.commands.size() == command_count_before + 1, "Battle action %s submits one accepted authoritative Command" % action_id, failures)
	var phase := str(scene.controller.domain.state.phase)
	assert_true(phase in [RunPhase.BATTLE, RunPhase.REWARD_CHOICE, RunPhase.ELITE_REWARD, RunPhase.BOSS_REWARD, RunPhase.RUN_SUMMARY], "Battle action %s reaches a valid encounter destination" % action_id, failures)
	var snapshot_matches: bool = scene.controller.snapshot().authoritative_snapshot == scene.controller.domain.checkpoint()
	assert_true(snapshot_matches, "Battle action %s refreshes the presentation from authoritative state" % action_id, failures)
	if _forced_input_mode in ["keyboard", "controller"] and scene.controller.domain.replay_record.commands.size() == command_count_before + 1 and snapshot_matches:
		_run_outcome_reached(_forced_input_mode)
		var coverage: Dictionary = _battle_keyboard_outcomes if _forced_input_mode == "keyboard" else _battle_controller_outcomes
		coverage[action_kind] = int(coverage.get(action_kind, 0)) + 1
	if phase == RunPhase.BATTLE:
		assert_help_prompt_visible(scene, phase, failures)

func _select_action_tiles(scene, action_id: String, failures: Array[String]) -> void:
	if find_action_button(scene, action_id) != null:
		return
	var target_ids: Array = []
	for action in scene.controller.action_descriptors():
		if str(action.get("id", "")) != action_id:
			continue
		var details: Dictionary = action.get("details", {})
		match str(action.get("kind", "")):
			"RESERVE", "DISCARD": target_ids = [str(action.target_id)]
			"RESERVE_SWAP": target_ids = [str(action.hand_instance_id), str(action.reserve_instance_id)]
			"PARTIAL_SETTLEMENT": target_ids = details.get("instance_ids", [])
			"COMPLETE_HAND":
				for group in details.get("groups", []):
					target_ids.append_array(group.get("instance_ids", []))
				target_ids.append_array(details.get("pair_instance_ids", []))
				if target_ids.is_empty():
					target_ids = details.get("tile_instance_ids", [])
		break
	if target_ids.is_empty():
		return
	var clear_button := scene.find_child("ClearTilesButton", true, false) as Button
	if clear_button != null and not clear_button.disabled:
		_activate_button(scene, clear_button, "clear prior tile selection", failures)
	for instance_id in target_ids:
		var tile: Button = scene._battle_view.tile_button(str(instance_id))
		assert_true(tile != null, "physical tile %s is selectable for %s" % [instance_id, action_id], failures)
		if tile != null:
			_activate_button(scene, tile, "select a physical tile for %s" % action_id, failures)

func press_action(scene, action_id: String, expected_phase: String, failures: Array[String]) -> void:
	var actions: Array = scene.controller.action_descriptors()
	var action_index := -1
	for index in actions.size():
		if str(actions[index].get("id", "")) == action_id:
			action_index = index
			break
	assert_true(action_index >= 0, "action %s is available on the current screen" % action_id, failures)
	if action_index < 0:
		return
	var button: Button = find_action_button(scene, action_id)
	assert_true(button is Button and not button.disabled and button.visible, "action %s has an enabled visible RunScene button" % action_id, failures)
	if not (button is Button) or button.disabled:
		return
	var action_kind := str(actions[action_index].get("kind", ""))
	var activated_button_name: String = str(button.name)
	var command_count_before: int = scene.controller.domain.replay_record.commands.size()
	_activate_button(scene, button, "Run action %s" % action_id, failures)
	var presentation_selection := action_kind in ["WORKSHOP_SELECT_SERVICE", "WORKSHOP_SELECT_TARGET", "WORKSHOP_BACK"]
	if presentation_selection:
		assert_true(scene.controller.domain.replay_record.commands.size() == command_count_before, "Workshop focus selection %s remains presentation-only" % action_id, failures)
	else:
		assert_true(scene.controller.domain.replay_record.commands.size() == command_count_before + 1, "action %s submits one accepted authoritative Command" % action_id, failures)
	assert_phase(scene, expected_phase, "selecting %s reaches %s" % [action_id, expected_phase], failures)
	var snapshot_matches: bool = scene.controller.snapshot().authoritative_snapshot == scene.controller.domain.checkpoint()
	assert_true(snapshot_matches, "action %s refreshes the presentation from authoritative state" % action_id, failures)
	if _forced_input_mode in ["keyboard", "controller"] and str(scene.controller.domain.state.phase) == expected_phase and snapshot_matches:
		_run_outcome_reached(_forced_input_mode)

func _run_outcome_reached(input_mode: String) -> void:
	if input_mode == "keyboard":
		_keyboard_run_outcomes += 1
	elif input_mode == "controller":
		_controller_run_outcomes += 1

func _assert_battle_action_coverage(input_mode: String, failures: Array[String]) -> void:
	var coverage: Dictionary = _battle_keyboard_outcomes if input_mode == "keyboard" else _battle_controller_outcomes
	for action_kind in CRITICAL_BATTLE_ACTION_KINDS:
		assert_true(int(coverage.get(action_kind, 0)) > 0, "%s mapped input reaches an authoritative %s Battle outcome" % [input_mode, action_kind], failures)

func _battle_outcomes_report(coverage: Dictionary) -> String:
	var entries: Array[String] = []
	for action_kind in CRITICAL_BATTLE_ACTION_KINDS:
		entries.append("%s:%d" % [action_kind.to_lower(), int(coverage.get(action_kind, 0))])
	return ",".join(entries)

func assert_actions_visible_and_enabled(scene, kind: String, expected_ids: Array, failures: Array[String]) -> void:
	var actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == kind)
	var actual_ids: Array[String] = []
	for action in actions:
		actual_ids.append(str(action.get("target_id", "")))
	actual_ids.sort()
	var sorted_expected: Array[String] = []
	for content_id in expected_ids:
		sorted_expected.append(str(content_id))
	sorted_expected.sort()
	assert_true(actual_ids == sorted_expected, "%s screen exposes the expected selectable content IDs" % kind, failures)
	for action in actions:
		var button: Button = find_action_button(scene, str(action.get("id", "")))
		assert_true(button != null and not button.disabled and button.visible, "%s choice %s is visibly enabled" % [kind, str(action.get("target_id", ""))], failures)
		if button != null:
			assert_true(not button.text.is_empty() or button.find_child("MapNodeLabel", true, false) is Label, "%s choice has a visible label" % kind, failures)

func _find_run_tile_record(scene, instance_id: String):
	for tile_record in scene.controller.domain.state.tile_pool.tile_instances:
		if str(tile_record.instance_id) == instance_id:
			return tile_record
	return null

func find_named_node(scene, node_name: String):
	# Phase views can retain hidden controls with the same local node name.
	# Player-facing checks must resolve the currently visible instance first.
	var matches: Array[Node] = scene.find_children(node_name, "", true, false)
	for candidate in matches:
		if candidate is Control and candidate.is_visible_in_tree():
			return candidate
	return matches[0] if not matches.is_empty() else null

func find_action_button(scene, action_id: String) -> Button:
	for candidate in scene.find_children("*", "Button", true, false):
		if candidate.is_visible_in_tree() and str(candidate.get_meta("run_action_id", "")) == action_id:
			return candidate
	return null

func assert_visible_action_focus(scene, message: String, failures: Array[String]) -> void:
	var focused_action_id := str(scene.controller.snapshot().get("focused_action_id", ""))
	var focused_button: Button = find_action_button(scene, focused_action_id)
	assert_true(not focused_action_id.is_empty() and focused_button != null and focused_button.is_visible_in_tree(), message + " points to a visible action", failures)
	assert_true(focused_button != null and focused_button.has_focus() and scene.get_viewport().gui_get_focus_owner() == focused_button, message + " is the visible GUI focus owner", failures)

func assert_phase(scene, expected_phase: String, message: String, failures: Array[String]) -> void:
	assert_true(str(scene.controller.domain.state.phase) == expected_phase, message, failures)
	assert_true(str(scene.controller.snapshot().get("screen", "")) == "run.%s" % expected_phase.to_lower(), "presentation destination matches authoritative phase %s" % expected_phase, failures)
	if expected_phase in ["CHARACTER_SELECT", "CONTRACT_SELECT", "MAP_CHOICE", "BATTLE"]:
		assert_help_prompt_visible(scene, expected_phase, failures)

func assert_help_prompt(scene, phase: String, expected_text: String, failures: Array[String]) -> void:
	assert_help_prompt_visible(scene, phase, failures)
	var prompt = find_named_node(scene, "RunHelpPrompt")
	if prompt is Label:
		assert_true(prompt.text.contains(expected_text), "%s presents its expected visible next-step text" % phase, failures)

func assert_help_prompt_visible(scene, phase: String, failures: Array[String]) -> void:
	var prompt = find_named_node(scene, "RunHelpPrompt")
	assert_true((prompt is Label and prompt.is_visible_in_tree()) or (phase == "BATTLE" and scene.find_child("SettingsButton", true, false) is Button), "phase guidance or Help / Settings is reachable at %s" % phase, failures)

func _new_test_scene(profile_path: String, suspend_path: String):
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(960, 540)
	var scene = RunScene.instantiate()
	scene.content_registry_factory = func(): return ScriptedContentRegistry.new()
	scene.meta_progress_coordinator = MetaProgressCoordinator.new(MetaProgressStore.new(profile_path))
	scene.suspend_file_path = suspend_path
	return scene

func _activate_button(scene, button: Button, label: String, failures: Array[String]) -> void:
	assert_true(button != null and button.visible and not button.disabled, "%s is visibly enabled" % label, failures)
	if button == null or not button.visible or button.disabled:
		return
	assert_true(button.focus_mode != Control.FOCUS_NONE, "%s accepts visible keyboard/controller focus" % label, failures)
	var action_id := str(button.get_meta("run_action_id")) if button.has_meta("run_action_id") else ""
	if not action_id.is_empty():
		_navigate_to_action(scene, action_id, failures)
	else:
		_navigate_to_control(scene, button)
	if not action_id.is_empty():
		button = find_action_button(scene, action_id)
	assert_true(button.has_focus() and scene.get_viewport().gui_get_focus_owner() == button, "%s presents an unambiguous visible focus target" % label, failures)
	var use_controller := _use_controller_input()
	var activated_button_name: String = str(button.name)
	var command_count_before: int = scene.controller.domain.replay_record.commands.size() if scene.controller != null else -1
	_push_virtual_accept(scene, use_controller)
	if activated_button_name in ["NewRunButton", "NewRunFromSuspendButton"]:
		var confirmation := find_named_node(scene, "ConfirmNewRunButton") as Button
		if confirmation != null and confirmation.is_visible_in_tree():
			_navigate_to_control(scene, confirmation)
			assert_true(confirmation.has_focus(), "New Run confirmation is reachable by mapped navigation", failures)
			_push_virtual_accept(scene, use_controller)
	if not action_id.is_empty() and scene.controller != null and scene.controller.domain.replay_record.commands.size() == command_count_before:
		_commit_pending_choice(scene, action_id, label, failures, use_controller)
	if _forced_input_mode == "keyboard":
		_keyboard_action_inputs += 1
	elif _forced_input_mode == "controller":
		_controller_action_inputs += 1


func _commit_pending_choice(scene, action_id: String, label: String, failures: Array[String], use_controller: bool) -> void:
	# The approved design has separate local choice and authoritative commit controls.
	# Drive the real control with the same mapped input; never call the command seam.
	# Purchases and Workshop services may add a confirmation after choosing.
	for confirmation_step in 2:
		var commit: Button
		for candidate in scene.find_children("*", "Button", true, false):
			if candidate.is_visible_in_tree() and not candidate.disabled and str(candidate.get_meta("run_commit_action_id", "")) == action_id:
				commit = candidate as Button
				break
		if commit == null:
			return
		_navigate_to_control(scene, commit)
		assert_true(commit.has_focus(), "%s exposes a reachable explicit commit control" % label, failures)
		var command_count: int = scene.controller.domain.replay_record.commands.size()
		_push_virtual_accept(scene, use_controller)
		if scene.controller.domain.replay_record.commands.size() != command_count:
			return


func _navigate_to_action(scene, action_id: String, failures: Array[String]) -> void:
	var target := find_action_button(scene, action_id)
	assert_true(target != null and target.is_visible_in_tree() and not target.disabled, "action %s has a reachable visible control" % action_id, failures)
	if target == null:
		return
	_navigate_to_control(scene, target)
	assert_true(target.has_focus(), "mapped Tab/shoulder navigation visibly focuses %s" % action_id, failures)
	if target.has_focus():
		assert_true(str(scene.controller.snapshot().get("focused_action_id", "")) == action_id, "presentation focus follows the visible action %s" % action_id, failures)

func _navigate_to_control(scene, target: Button) -> void:
	var focusable: Array[Button] = []
	for candidate in scene.find_children("*", "Button", true, false):
		if candidate is Button and candidate.is_visible_in_tree() and not candidate.disabled and candidate.focus_mode != Control.FOCUS_NONE:
			focusable.append(candidate)
	if not focusable.has(target):
		return
	# Drive the live focus owner until the target actually owns focus. Dynamic action
	# buttons are rebuilt during Run transitions, so stale GUI focus cannot be
	# treated as an index into the current visible controls.
	for step in focusable.size() + 1:
		if target.has_focus() and scene.get_viewport().gui_get_focus_owner() == target:
			return
		var use_controller := _use_controller_input()
		_push_virtual_focus(scene, 1, use_controller)

func _use_controller_input() -> bool:
	if _forced_input_mode == "controller":
		return true
	if _forced_input_mode == "keyboard":
		return false
	return ((_virtual_keyboard_navigations + _virtual_controller_navigations) % 2) == 1

func _push_virtual_direction(scene, direction: int, use_controller: bool) -> void:
	if use_controller:
		_virtual_controller_navigations += 1
		_push_joypad_button(scene, JOY_BUTTON_DPAD_DOWN if direction > 0 else JOY_BUTTON_DPAD_UP)
	else:
		_virtual_keyboard_navigations += 1
		_push_key(scene, KEY_DOWN if direction > 0 else KEY_UP)

func _push_virtual_focus(scene, direction: int, use_controller: bool) -> void:
	if use_controller:
		_virtual_controller_navigations += 1
		_push_joypad_button(scene, JOY_BUTTON_RIGHT_SHOULDER if direction > 0 else JOY_BUTTON_LEFT_SHOULDER)
	else:
		_virtual_keyboard_navigations += 1
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.physical_keycode = KEY_TAB
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		var release_event := event.duplicate() as InputEventKey
		release_event.pressed = false
		Input.parse_input_event(release_event)
		Input.flush_buffered_events()

func _push_virtual_accept(scene, use_controller: bool) -> void:
	if use_controller:
		_virtual_controller_accepts += 1
		_push_joypad_button(scene, JOY_BUTTON_A)
	else:
		_virtual_keyboard_accepts += 1
		_push_key(scene, KEY_ENTER)

func _push_virtual_cancel(scene, use_controller: bool) -> void:
	if use_controller:
		_virtual_controller_cancels += 1
		_push_joypad_button(scene, JOY_BUTTON_B)
	else:
		_virtual_keyboard_cancels += 1
		_push_key(scene, KEY_ESCAPE)

func _push_key(scene, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release_event := event.duplicate() as InputEventKey
	release_event.pressed = false
	Input.parse_input_event(release_event)
	Input.flush_buffered_events()

func _push_joypad_button(scene, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release_event := event.duplicate() as InputEventJoypadButton
	release_event.pressed = false
	Input.parse_input_event(release_event)
	Input.flush_buffered_events()

func _clear_test_file(path: String) -> void:
	for candidate in [path, "%s.tmp" % path, "%s.bak" % path]:
		var absolute_path := ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)

func _apply_tutorial_help(scene, reset: bool, failures: Array[String]) -> void:
	_activate_button(scene, find_named_node(scene, "SettingsButton") as Button, "Open Help / Settings", failures)
	var overlay: Control = scene._preferences_overlay
	_activate_button(scene, overlay.find_child("HelpTabButton", true, false) as Button, "Help tab", failures)
	_activate_button(scene, overlay.find_child("TutorialResetButton" if reset else "TutorialEnabledButton", true, false) as Button, "Reset tutorial" if reset else "Toggle tutorial", failures)
	_activate_button(scene, overlay.find_child("ApplyButton", true, false) as Button, "Apply tutorial preference", failures)
