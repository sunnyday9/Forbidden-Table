class_name RC6StartingHandRulesTest
extends RefCounted

const RunScene = preload("res://scenes/run/run_scene.tscn")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

const SUITS := ["characters", "dots", "bamboo"]
const VIEWPORT_SIZES := [Vector2i(960, 540), Vector2i(540, 960), Vector2i(2560, 1440)]
const STARTING_HAND_RULE_CASES := [
	{"locale": "en", "scale": 1.0},
	{"locale": "en", "scale": 1.25},
	{"locale": "en", "scale": 1.5},
	{"locale": "zh_CN", "scale": 1.0},
	{"locale": "zh_CN", "scale": 1.25},
	{"locale": "zh_CN", "scale": 1.5},
]


func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["RC6 starting-hand-rules suite requires a SceneTree"]
	var suffix := "%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	var original_viewport_size := tree.root.size
	var preferences = Engine.get_main_loop().root.get_node_or_null("PresentationPrefs")
	var original_config_path := str(preferences.config_path) if preferences != null else ""
	var original_preferences: Dictionary = preferences.snapshot() if preferences != null else {}
	var original_locale := TranslationServer.get_locale()
	var isolated_preferences_path := "user://rc6_starting_hand_rules_%s.cfg" % suffix
	if preferences != null:
		preferences.config_path = isolated_preferences_path
		preferences.reload_preferences()
	for viewport_size in VIEWPORT_SIZES:
		for rule_case in STARTING_HAND_RULE_CASES:
			for excluded_suit in SUITS:
				await _test_reserve_suit_choice(tree, viewport_size, str(rule_case.locale), float(rule_case.scale), excluded_suit, suffix, failures)
			await _test_sequence_direct_choice(tree, viewport_size, str(rule_case.locale), float(rule_case.scale), suffix, failures)
	_test_full_hand_copy(suffix, failures)
	if preferences != null:
		preferences.config_path = original_config_path
		preferences.call("_apply_in_memory", original_preferences)
	TranslationServer.set_locale(original_locale)
	tree.root.size = original_viewport_size
	_remove_file(isolated_preferences_path)
	return failures


func _test_reserve_suit_choice(tree: SceneTree, viewport_size: Vector2i, locale: String, ui_scale: float, excluded_suit: String, suffix: String, failures: Array[String]) -> void:
	var case_id := "%sx%s_%s_%s_%s_%s" % [viewport_size.x, viewport_size.y, locale, str(int(ui_scale * 100.0)), excluded_suit, suffix]
	var suspend_path := "user://rc6_reserve_%s_suspend.json" % case_id
	var profile_path := "user://rc6_reserve_%s_profile.json" % case_id
	tree.root.size = viewport_size
	var scene = RunScene.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	tree.root.add_child(scene)
	await _settle_layout(tree)
	scene._apply_presentation_preferences({
		"locale": locale,
		"ui_scale": ui_scale,
		"presentation_mode": "INSTANT",
		"reduced_motion": true,
		"ambient_glow": false,
	}, true)
	await _settle_layout(tree)
	var controller = scene.controller
	assert_true(controller != null, "%s creates a real RunScene controller" % case_id, failures)
	if controller == null:
		_free_scene(scene, suspend_path, profile_path)
		return
	assert_true(controller.domain.state.phase == RunPhaseScript.CHARACTER_SELECT, "%s starts at Character selection" % case_id, failures)
	var view = scene._journey_view
	var reserve_card := view.find_child("CharacterCard_Reserve", true, false) as Control
	var sequence_card := view.find_child("CharacterCard_Sequence", true, false) as Control
	var reserve_facts := reserve_card.find_child("CharacterFacts", true, false) as Label if reserve_card != null else null
	var sequence_facts := sequence_card.find_child("CharacterFacts", true, false) as Label if sequence_card != null else null
	assert_true(reserve_facts != null and reserve_facts.text.contains("72"), "%s explains Reserve’s exact 72-tile starting pool" % case_id, failures)
	assert_true(sequence_facts != null and sequence_facts.text.contains("68"), "%s explains Sequence’s exact 68-tile starting pool" % case_id, failures)
	var reserve_id := "character:base.character.reserve"
	var reserve_button: Button = view.action_button(reserve_id)
	assert_true(reserve_button != null and not reserve_button.disabled, "%s shows an enabled Reserve choice" % case_id, failures)
	if reserve_button == null or reserve_button.disabled:
		_free_scene(scene, suspend_path, profile_path)
		return
	var checkpoint_before: Dictionary = controller.domain.checkpoint()
	var replay_before: String = controller.domain.replay_record.serialize()
	var command_count_before: int = controller._command_sequence
	var accepted_commands_before: int = controller.domain.replay_record.commands.size()
	reserve_button.emit_signal("pressed")
	await _settle_layout(tree)
	var suit_actions: Array = controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "CHARACTER_SUIT")
	assert_true(controller.domain.state.phase == RunPhaseScript.CHARACTER_SELECT, "%s opens a presentation-only suit chooser" % case_id, failures)
	assert_true(suit_actions.size() == 3, "%s exposes exactly three suit-removal choices" % case_id, failures)
	assert_true(controller.domain.checkpoint() == checkpoint_before and controller.domain.replay_record.serialize() == replay_before, "%s does not mutate Run state or replay before the player chooses a suit" % case_id, failures)
	assert_true(controller._command_sequence == command_count_before and controller.domain.replay_record.commands.size() == accepted_commands_before, "%s creates no command while opening the suit chooser" % case_id, failures)
	var heading := view.find_child("CharacterSuitChoiceHeading", true, false) as Label
	var guidance := view.find_child("CharacterSuitChoiceGuidance", true, false) as Label
	assert_true(heading != null and heading.text == LocalizationCatalogScript.text("UI_RUN_CHARACTER_SUIT_PROMPT"), "%s localizes the suit-removal prompt" % case_id, failures)
	assert_true(guidance != null and guidance.text.contains("72"), "%s explains the exact 72-tile result" % case_id, failures)
	var suit_button_id := "character_suit:%s" % excluded_suit
	var suit_button: Button = view.action_button(suit_button_id)
	var label_key := "UI_RUN_CHARACTER_SUIT_LABEL_%s" % excluded_suit.to_upper()
	assert_true(suit_button != null and not suit_button.disabled, "%s offers %s as an enabled choice" % [case_id, excluded_suit], failures)
	if suit_button != null:
		await _focus_and_assert_suit_button_reachable(tree, scene, suit_button, case_id, failures)
	var back_button: Button = view.action_button("character_suit:back")
	assert_true(back_button != null and not back_button.disabled, "%s exposes an enabled Back-to-roster control" % case_id, failures)
	if back_button != null and not back_button.disabled:
		back_button.emit_signal("pressed")
		await _settle_layout(tree)
		var roster_reserve_button: Button = view.action_button(reserve_id)
		assert_true(controller.domain.state.phase == RunPhaseScript.CHARACTER_SELECT and roster_reserve_button != null and view.action_button(suit_button_id) == null, "%s Back returns from the picker to the Character roster" % case_id, failures)
		assert_true(controller.domain.checkpoint() == checkpoint_before and controller.domain.replay_record.serialize() == replay_before and controller._command_sequence == command_count_before and controller.domain.replay_record.commands.size() == accepted_commands_before, "%s Back-to-roster remains presentation-only" % case_id, failures)
		if roster_reserve_button != null:
			roster_reserve_button.emit_signal("pressed")
			await _settle_layout(tree)
			suit_button = view.action_button(suit_button_id)
			assert_true(suit_button != null and not suit_button.disabled, "%s can reopen the suit picker after Back" % case_id, failures)
			if suit_button != null:
				await _focus_and_assert_suit_button_reachable(tree, scene, suit_button, case_id + " reopened", failures)
	if suit_button != null:
		assert_true(suit_button.text == LocalizationCatalogScript.text(label_key), "%s localizes the %s choice" % [case_id, excluded_suit], failures)
		assert_true(is_equal_approx(suit_button.custom_minimum_size.y, 68.0 * ui_scale), "%s scales the suit choice target at %.0f%%" % [case_id, ui_scale * 100.0], failures)
		var command_count_before_suit: int = controller._command_sequence
		var accepted_commands_before_suit: int = controller.domain.replay_record.commands.size()
		suit_button.emit_signal("pressed")
		await _settle_layout(tree)
		assert_true(controller.domain.state.phase == RunPhaseScript.CONTRACT_SELECT, "%s advances directly to Contract after one suit press" % case_id, failures)
		assert_true(controller._command_sequence == command_count_before_suit + 1 and controller.domain.replay_record.commands.size() == accepted_commands_before_suit + 1, "%s dispatches exactly one authoritative command for the suit press" % case_id, failures)
		if controller.domain.replay_record.commands.size() > accepted_commands_before_suit:
			var recorded_command = controller.domain.replay_record.commands.back()
			assert_true(recorded_command.command_type == "ChooseCharacter" and str(recorded_command.payload.get("excluded_suit", "")) == excluded_suit, "%s records the selected suit in ChooseCharacter" % case_id, failures)
		_assert_reserve_pool(controller.domain, excluded_suit, case_id, failures)
	_free_scene(scene, suspend_path, profile_path)
	tree.root.size = Vector2i(1280, 800)


func _test_sequence_direct_choice(tree: SceneTree, viewport_size: Vector2i, locale: String, ui_scale: float, suffix: String, failures: Array[String]) -> void:
	var case_id := "%sx%s_%s_%s_sequence_%s" % [viewport_size.x, viewport_size.y, locale, str(int(ui_scale * 100.0)), suffix]
	var suspend_path := "user://rc6_sequence_%s_suspend.json" % case_id
	var profile_path := "user://rc6_sequence_%s_profile.json" % case_id
	tree.root.size = viewport_size
	var scene = RunScene.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	tree.root.add_child(scene)
	await _settle_layout(tree)
	scene._apply_presentation_preferences({"locale": locale, "ui_scale": ui_scale, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
	await _settle_layout(tree)
	var controller = scene.controller
	var sequence_id := "character:base.character.sequence"
	var sequence_button: Button = scene._journey_view.action_button(sequence_id)
	assert_true(sequence_button != null and not sequence_button.disabled, "%s exposes the direct Sequence choice" % case_id, failures)
	if sequence_button != null and not sequence_button.disabled:
		await _focus_and_assert_suit_button_reachable(tree, scene, sequence_button, case_id + " Sequence", failures)
		var checkpoint_before: Dictionary = controller.domain.checkpoint()
		var replay_before: String = controller.domain.replay_record.serialize()
		var command_count_before: int = controller._command_sequence
		sequence_button.emit_signal("pressed")
		await _settle_layout(tree)
		assert_true(controller.domain.state.phase == RunPhaseScript.CONTRACT_SELECT, "%s Sequence advances directly to Contract in one press" % case_id, failures)
		assert_true(controller._command_sequence == command_count_before + 1 and controller.domain.replay_record.commands.size() == 1, "%s records one authoritative Sequence command" % case_id, failures)
		var recorded_command = controller.domain.replay_record.commands.back() if not controller.domain.replay_record.commands.is_empty() else null
		assert_true(recorded_command != null and recorded_command.command_type == "ChooseCharacter" and not recorded_command.payload.has("excluded_suit"), "%s Sequence does not require or record a removed suit" % case_id, failures)
		assert_true(controller.domain.checkpoint() != checkpoint_before and controller.domain.replay_record.serialize() != replay_before, "%s Sequence choice changes the authoritative Run once selected" % case_id, failures)
		assert_true(controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "CHARACTER_SUIT").is_empty() and scene._journey_view.find_child("CharacterSuitChoiceHeading", true, false) == null, "%s never opens the Reserve-only suit picker" % case_id, failures)
		_assert_sequence_pool(controller.domain, case_id, failures)
	_free_scene(scene, suspend_path, profile_path)
	tree.root.size = Vector2i(1280, 800)


func _assert_sequence_pool(domain, case_id: String, failures: Array[String]) -> void:
	var tile_records: Array = domain.state.tile_pool.tile_instances
	var copy_counts: Dictionary = {}
	var has_honors := false
	var every_type_has_two := true
	for tile in tile_records:
		var definition = domain.content_registry.resolve(str(tile.definition_id))
		if definition == null:
			continue
		var definition_id := str(tile.definition_id)
		copy_counts[definition_id] = int(copy_counts.get(definition_id, 0)) + 1
		has_honors = has_honors or str(definition.suit) == "honors"
	for count in copy_counts.values():
		every_type_has_two = every_type_has_two and int(count) == 2
	assert_true(tile_records.size() == 68 and copy_counts.size() == 34, "%s Sequence creates two copies of each of 34 tile types (68 total)" % case_id, failures)
	assert_true(has_honors and every_type_has_two, "%s Sequence keeps honors and exactly two copies of every tile type" % case_id, failures)


func _settle_layout(tree: SceneTree) -> void:
	for _frame in 4:
		await tree.process_frame


func _focus_and_assert_suit_button_reachable(tree: SceneTree, scene, button: Button, case_id: String, failures: Array[String]) -> void:
	if button == null:
		return
	button.grab_focus()
	for _frame in 6:
		await tree.process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	var visible_rect := viewport_rect
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			visible_rect = visible_rect.intersection((ancestor as ScrollContainer).get_global_rect())
		ancestor = ancestor.get_parent()
	var button_rect := button.get_global_rect()
	assert_true(button.is_visible_in_tree() and not button.disabled and visible_rect.grow(1.0).encloses(button_rect), "%s focused choice remains fully visible inside its nested scroll viewports and %s window (button=%s visible=%s)" % [case_id, tree.root.size, button_rect, visible_rect], failures)
	assert_true(tree.root.get_viewport().gui_get_focus_owner() == button, "%s selected choice receives real GUI focus after layout settles" % case_id, failures)


func _assert_reserve_pool(domain, excluded_suit: String, case_id: String, failures: Array[String]) -> void:
	var tile_records: Array = domain.state.tile_pool.tile_instances
	assert_true(tile_records.size() == 72, "%s creates exactly 72 starting tiles" % case_id, failures)
	var copy_counts: Dictionary = {}
	for tile in tile_records:
		var definition = domain.content_registry.resolve(str(tile.definition_id))
		assert_true(definition != null and definition.suit != "honors" and definition.suit != excluded_suit, "%s excludes honors and the chosen %s suit" % [case_id, excluded_suit], failures)
		if definition != null:
			var key := "%s:%d" % [str(definition.suit), int(definition.rank)]
			copy_counts[key] = int(copy_counts.get(key, 0)) + 1
	for suit in SUITS:
		if suit == excluded_suit:
			continue
		for rank in range(1, 10):
			assert_true(int(copy_counts.get("%s:%d" % [suit, rank], 0)) == 4, "%s has four copies of %s %d" % [case_id, suit, rank], failures)


func _test_full_hand_copy(suffix: String, failures: Array[String]) -> void:
	var suspend_path := "user://rc6_hand_cap_%s_suspend.json" % suffix
	var profile_path := "user://rc6_hand_cap_%s_profile.json" % suffix
	var scene = RunScene.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	scene._ready()
	scene._apply_presentation_preferences({"locale": "en", "ui_scale": 1.0, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
	var controller = scene.controller
	controller.confirm("character:base.character.sequence")
	var contract_action: Dictionary = controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "CONTRACT")[0]
	controller.confirm(str(contract_action.get("id", "")))
	var battle_nodes: Array = controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "MAP_NODE" and str(action.get("node_kind", "")) == "BATTLE")
	assert_true(not battle_nodes.is_empty(), "the isolated RunScene fixture exposes a real Battle route for hand-cap copy", failures)
	if battle_nodes.is_empty():
		_free_scene(scene, suspend_path, profile_path)
		return
	controller.confirm(str(battle_nodes[0].get("id", "")))
	var battle = controller.domain.current_battle
	var wall: Array = battle.zones.contents(TileZoneScript.DRAW_WALL)
	for index in range(mini(3, wall.size())):
		battle.zones.transfer(str(wall[index].instance_id), TileZoneScript.DRAW_WALL, TileZoneScript.HAND)
	controller._refresh([])
	var draw_action: Dictionary = controller.action_descriptors().filter(func(action): return str(action.get("id", "")) == "battle.draw")[0]
	assert_true(battle.zones.size(TileZoneScript.HAND) == 14 and not bool(draw_action.get("enabled", true)) and str(draw_action.get("disabled_reason", "")) == "HAND_CAPACITY_REACHED", "the 14-tile limit disables Draw with its typed reason", failures)
	var draw_button: Button = scene._battle_view.action_button("battle.draw") if scene._battle_view != null else null
	var hand_heading := scene._battle_view.find_child("BattleHandHeading", true, false) as Label if scene._battle_view != null else null
	assert_true(draw_button != null and draw_button.disabled and draw_button.tooltip_text.contains(LocalizationCatalogScript.format("UI_BATTLE_HAND_CAP_REACHED", [14])), "the disabled Draw explanation is localized rather than a raw status code", failures)
	assert_true(hand_heading != null and hand_heading.text == LocalizationCatalogScript.format("UI_BATTLE_HAND_CAP", [14]) and hand_heading.tooltip_text == LocalizationCatalogScript.text("UI_BATTLE_HAND_LIMIT_HINT"), "the Hand heading shows 14/14 and exposes opening-hand guidance", failures)
	_free_scene(scene, suspend_path, profile_path)


func _free_scene(scene, suspend_path: String, profile_path: String) -> void:
	if scene != null and is_instance_valid(scene) and scene.is_inside_tree():
		var parent: Node = scene.get_parent()
		if parent != null:
			parent.remove_child(scene)
	scene.free()
	for path in [suspend_path, suspend_path + ".tmp", suspend_path + ".bak", profile_path]:
		_remove_file(path)


func _remove_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
