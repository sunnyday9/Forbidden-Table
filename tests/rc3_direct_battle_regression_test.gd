class_name Rc3DirectBattleRegressionTest
extends RefCounted

const BattleViewScript = preload("res://src/presentation/ui/battle_view.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const PatternCandidateScript = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")
const RunSceneScript = preload("res://scenes/run/run_scene.gd")
const RunScenePacked = preload("res://scenes/run/run_scene.tscn")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")

var _label_provider_nodes: Array[Node] = []


func run() -> Array[String]:
	var failures: Array[String] = []
	_label_provider_nodes.clear()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["RC3 direct Battle regression requires SceneTree"]
	var prior_size := tree.root.size
	tree.root.size = Vector2i(1280, 800)
	var suffix := "%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	var controller = _battle_controller("rc3.direct.battle." + suffix, failures)
	if controller == null:
		tree.root.size = prior_size
		return failures
	var battle = controller.domain.current_battle
	var hand_definitions := [
		"base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.east",
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3",
		"base.tile.characters.4",
	]
	_replace_test_hand(battle, hand_definitions, "rc3.direct.triplet." + suffix, failures)
	_assert(battle.settlement_window.open(), "actual SettlementWindow opens for the deterministic 3-East hand", failures)
	_assert(battle.can_settle(), "actual BattleDomain permits settlement while capacity remains", failures)
	var east_ids: Array[String] = []
	for tile in battle.zones.contents(TileZoneScript.HAND):
		if str(tile.definition_id) == "base.tile.honors.east":
			east_ids.append(str(tile.instance_id))
	_assert(east_ids.size() == 3 and east_ids[0] != east_ids[1] and east_ids[1] != east_ids[2], "the East triplet uses three distinct physical instances of the same definition", failures)
	var triplet_action: Dictionary = _triplet_action(controller.action_descriptors(), east_ids)
	_assert(not triplet_action.is_empty(), "actual legal action descriptors expose the East Triplet candidate", failures)
	if triplet_action.is_empty():
		tree.root.size = prior_size
		return failures

	var view = BattleViewScript.new()
	view.set_external_preferences_owner()
	_configure_battle_view(view, controller, tree)
	tree.root.add_child(view)
	await _settle(tree)
	view.render()
	await _settle(tree)
	var requested_ids: Array[String] = []
	var accepted_results: Array[bool] = []
	view.action_requested.connect(func(action_id: String) -> void:
		requested_ids.append(action_id)
		var result = controller.confirm(action_id)
		accepted_results.append(result != null and bool(result.accepted))
	)
	controller.presentation_changed.connect(func() -> void: view.render())
	var replay_before: int = controller.domain.replay_record.commands.size()
	var checkpoint_before: Dictionary = controller.domain.checkpoint()
	for east_id in east_ids:
		var tile_button = view.tile_button(east_id)
		_assert(tile_button != null, "Battle renders the exact East physical tile %s" % east_id, failures)
		if tile_button != null:
			await _click_control(tree, tile_button, failures)
	_assert(view.selected_tile_ids().size() == 3, "clicking the three East faces selects the three physical tiles", failures)
	_assert(controller.domain.checkpoint() == checkpoint_before and controller.domain.replay_record.commands.size() == replay_before, "tile-face clicks only select; they do not execute or auto-settle", failures)
	var available_hint := view.find_child("BattleSelectionHint", true, false) as Label
	var available_capacity = battle.settlement_window.settlement_capacity()
	_assert(available_hint != null and available_hint.text.contains(LocalizationCatalogScript.format("UI_BATTLE_TABLE_SETTLEMENT_CAPACITY_REMAINING", [available_capacity.remaining, available_capacity.maximum])), "a legal selected set shows the remaining/max Settlement allowance", failures)
	var action_id := str(triplet_action.get("id", ""))
	var play_button: Button = view.action_button(action_id)
	_assert(play_button != null, "exactly selected legal East Triplet is offered as a Play action", failures)
	_assert(not _has_pair_partial_candidate(controller.action_descriptors()), "a Pair is not exposed as a partial meld action under current domain rules", failures)
	_assert(view.commit_button() != null and not view.commit_button().is_visible_in_tree(), "Battle actions do not display a second Commit step", failures)
	if play_button != null:
		await _click_control(tree, play_button, failures)
	_assert(requested_ids == [action_id], "one Battle action-button press immediately emits exactly one command request", failures)
	_assert(accepted_results.size() == 1 and accepted_results[0], "the immediately requested legal East Triplet is accepted by BattleDomain", failures)
	_assert(controller.domain.replay_record.commands.size() == replay_before + 1, "one Play press records one authoritative settlement command", failures)
	_assert(view.selected_action_id.is_empty(), "direct execution does not leave a pending selected action", failures)
	view.queue_free()
	await _settle(tree)

	await _test_pair_requires_complete_hand(tree, suffix, failures)
	await _test_exhausted_capacity_explanation(tree, suffix, failures)
	await _test_closed_window_explanation(tree, suffix, failures)
	await _test_actual_run_scene_hand_layout(tree, suffix, failures)
	await _test_component_battle_hand_layout(tree, suffix, failures)
	for label_provider in _label_provider_nodes:
		if is_instance_valid(label_provider):
			label_provider.free()
	_label_provider_nodes.clear()
	tree.root.size = prior_size
	print("RC3_DIRECT_BATTLE_REPORT failures=%d" % failures.size())
	return failures


func _test_actual_run_scene_hand_layout(tree: SceneTree, suffix: String, failures: Array[String]) -> void:
	var prior_locale := TranslationServer.get_locale()
	var suspend_path := "user://rc3_battle_layout_%s_suspend.json" % suffix
	var profile_path := "user://rc3_battle_layout_%s_profile.json" % suffix
	var scene = RunScenePacked.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	tree.root.add_child(scene)
	await _settle(tree)
	scene._apply_presentation_preferences({
		"locale": "en",
		"ui_scale": 1.0,
		"presentation_mode": "NORMAL",
		"reduced_motion": true,
		"ambient_glow": false,
	}, true)
	await _settle(tree)
	var controller = scene.controller
	_assert(controller != null, "actual RunScene creates a controller using unique suspend/profile paths", failures)
	if controller == null:
		await _close_actual_run_scene(tree, scene, suspend_path, profile_path)
		TranslationServer.set_locale(prior_locale)
		return
	var character_action := _first_action_of_kind(controller.action_descriptors(), "CHARACTER")
	var contract_action: Dictionary
	var map_action: Dictionary
	var result
	_assert(not character_action.is_empty(), "actual RunScene offers its real Character action", failures)
	if not character_action.is_empty():
		result = controller.confirm(str(character_action.get("id", "")))
		_assert(result != null and bool(result.accepted), "actual RunScene accepts its real Character action", failures)
	contract_action = _first_action_of_kind(controller.action_descriptors(), "CONTRACT")
	_assert(not contract_action.is_empty(), "actual RunScene offers its real Contract action", failures)
	if not contract_action.is_empty():
		result = controller.confirm(str(contract_action.get("id", "")))
		_assert(result != null and bool(result.accepted), "actual RunScene accepts its real Contract action", failures)
	map_action = _first_action_of_kind(controller.action_descriptors(), "MAP_NODE")
	_assert(not map_action.is_empty(), "actual RunScene offers its real starting Map action", failures)
	if not map_action.is_empty():
		result = controller.confirm(str(map_action.get("id", "")))
		_assert(result != null and bool(result.accepted) and controller.domain.state.phase == RunPhaseScript.BATTLE, "actual RunScene enters its real Battle phase", failures)
	await _settle_long(tree, 18)
	if controller.domain.current_battle == null:
		_assert(false, "actual RunScene reaches a Battle before hand-layout assertions", failures)
		await _close_actual_run_scene(tree, scene, suspend_path, profile_path)
		TranslationServer.set_locale(prior_locale)
		return
	var battle = controller.domain.current_battle
	_replace_test_hand(battle, [
		"base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.east",
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3", "base.tile.characters.4",
	], "rc3.direct.run-scene-layout." + suffix, failures)
	_assert(battle.settlement_window.open(), "actual RunScene layout fixture opens the real SettlementWindow", failures)
	for locale in ["en", "zh_CN"]:
		scene._apply_presentation_preferences({
			"locale": locale,
			"ui_scale": 1.0,
			"presentation_mode": "NORMAL",
			"reduced_motion": true,
			"ambient_glow": false,
		}, true)
		scene._render()
		await _settle_long(tree, 18)
		var view: Control = scene.get("_battle_view") as Control
		var hand_surface := view.find_child("BattleHandSurface", true, false) as Control if view != null else null
		var hand_tray := view.find_child("BattleHandTray", true, false) as Control if view != null else null
		var hand_scroll := view.find_child("BattleHandScroll", true, false) as ScrollContainer if view != null else null
		var hand_row := view.find_child("BattleHandTiles", true, false) as HBoxContainer if view != null else null
		var arena := view.find_child("BattleEnemyIntentBanner", true, false) as Control if view != null else null
		var decision := view.find_child("BattleDecisionSurface", true, false) as Control if view != null else null
		var viewport_rect := tree.root.get_visible_rect()
		print("RC3_RUN_LAYOUT locale=%s viewport=%s view=%s arena=%s arena_min=%s decision=%s tray=%s row=%s hand_scroll=%s scale=%s" % [locale, viewport_rect, view.get_global_rect() if view != null else Rect2(), arena.get_global_rect() if arena != null else Rect2(), arena.get_combined_minimum_size() if arena != null else Vector2(), decision.get_global_rect() if decision != null else Rect2(), hand_tray.get_global_rect() if hand_tray != null else Rect2(), hand_row.get_global_rect() if hand_row != null else Rect2(), hand_scroll.get_global_rect() if hand_scroll != null else Rect2(), view.get("_ui_scale") if view != null else null])
		_assert(view != null and view.is_visible_in_tree(), "%s actual RunScene displays its configured BattleView" % locale, failures)
		_assert(hand_surface != null and hand_surface.is_visible_in_tree(), "%s actual RunScene exposes the Hand surface" % locale, failures)
		_assert(hand_tray != null and hand_tray.is_visible_in_tree(), "%s actual RunScene exposes the Hand tray" % locale, failures)
		_assert(hand_scroll != null and hand_scroll.is_visible_in_tree(), "%s actual RunScene exposes the horizontally scrollable Hand" % locale, failures)
		_assert(hand_row != null and hand_row.is_visible_in_tree(), "%s actual RunScene exposes its Hand tile row" % locale, failures)
		if hand_surface != null:
			_assert(_control_fully_visible(hand_surface, viewport_rect), "%s full Hand area stays inside the viewport and clipping ancestors" % locale, failures)
		if hand_tray != null:
			_assert(_control_fully_visible(hand_tray, viewport_rect), "%s full Hand tray stays inside the viewport and clipping ancestors" % locale, failures)
		var tiles: Array[TileFaceButton] = []
		if hand_row != null:
			for child in hand_row.get_children():
				if child is TileFaceButton:
					tiles.append(child as TileFaceButton)
		_assert(tiles.size() == 13, "%s actual RunScene renders all 13 hand tile controls" % locale, failures)
		var first_tile_y := -1.0
		var previous_tile_right := -1.0
		for tile in tiles:
			if hand_scroll != null:
				hand_scroll.ensure_control_visible(tile)
				await tree.process_frame
			var tile_rect := tile.get_global_rect()
			var face_rect := tile.face_rect
			_assert(tile.is_visible_in_tree() and _control_fully_visible(tile, viewport_rect), "%s tile %s scrolls fully into view" % [locale, tile.tile_instance_id], failures)
			_assert(face_rect != null and face_rect.texture != null and _control_fully_visible(face_rect, viewport_rect), "%s tile %s displays a fully visible textured face after scrolling" % [locale, tile.tile_instance_id], failures)
			if first_tile_y < 0.0:
				first_tile_y = tile_rect.position.y
			_assert(first_tile_y < 0.0 or absf(tile_rect.position.y - first_tile_y) <= 2.0, "%s 13-tile Hand stays on one visible row" % locale, failures)
			_assert(previous_tile_right < 0.0 or tile.position.x >= previous_tile_right - 1.0, "%s hand row lays out non-overlapping tile hit targets" % locale, failures)
			previous_tile_right = tile.position.x + tile.size.x
			_assert(tile_rect.get_center().x >= viewport_rect.position.x and tile_rect.get_center().x < viewport_rect.end.x and tile_rect.get_center().y >= viewport_rect.position.y and tile_rect.get_center().y < viewport_rect.end.y, "%s tile-center hit point remains inside the viewport" % locale, failures)
	await _close_actual_run_scene(tree, scene, suspend_path, profile_path)
	TranslationServer.set_locale(prior_locale)


func _first_action_of_kind(actions: Array, kind: String) -> Dictionary:
	if kind == "CHARACTER":
		for action in actions:
			if str(action.get("target_id", "")) == "base.character.sequence":
				return action
	for action in actions:
		if action is Dictionary and str(action.get("kind", "")) == kind:
			return action
	return {}


func _test_component_battle_hand_layout(tree: SceneTree, suffix: String, failures: Array[String]) -> void:
	var prior_size := tree.root.size
	tree.root.size = Vector2i(1280, 800)
	var controller = _battle_controller("rc3.direct.component-layout." + suffix, failures)
	if controller == null:
		tree.root.size = prior_size
		return
	var battle = controller.domain.current_battle
	_replace_test_hand(battle, [
		"base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.east",
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3", "base.tile.characters.4",
	], "rc3.direct.component-layout." + suffix, failures)
	_assert(battle.settlement_window.open(), "standalone BattleView fixture opens its real SettlementWindow", failures)
	var view = BattleViewScript.new()
	view.set_external_preferences_owner()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_configure_battle_view(view, controller, tree)
	tree.root.add_child(view)
	for locale in ["en", "zh_CN"]:
		view.set_presentation_preferences(locale, 1.0, "NORMAL", true, false)
		view.render()
		await _settle_long(tree, 18)
		var arena := view.find_child("BattleEnemyIntentBanner", true, false) as Control
		var top_scroll := view.find_child("BattleCriticalScroll", true, false) as ScrollContainer
		var decision := view.find_child("BattleDecisionSurface", true, false) as Control
		var hand_surface := view.find_child("BattleHandSurface", true, false) as Control
		var hand_tray := view.find_child("BattleHandTray", true, false) as Control
		var hand_row := view.find_child("BattleHandTiles", true, false) as HBoxContainer
		var viewport_rect := tree.root.get_visible_rect()
		if arena != null and top_scroll != null and decision != null:
			var vertical_gap := decision.get_global_rect().position.y - top_scroll.get_global_rect().end.y
			_assert(top_scroll.is_ancestor_of(arena) and vertical_gap >= 4.0 and vertical_gap <= 18.0, "%s Battle board and action column follow the complete scrollable enemy/resource rail" % locale, failures)
		var tiles: Array[TileFaceButton] = []
		if hand_row != null:
			for child in hand_row.get_children():
				if child is TileFaceButton:
					tiles.append(child as TileFaceButton)
		_assert(hand_surface != null and _control_fully_visible(hand_surface, viewport_rect), "%s full standalone Battle Hand surface stays inside the viewport" % locale, failures)
		_assert(hand_tray != null and _control_fully_visible(hand_tray, viewport_rect), "%s standalone Battle Hand tray stays inside the viewport" % locale, failures)
		_assert(tiles.size() == 13, "%s standalone BattleView renders all 13 Hand controls" % locale, failures)
		var first_tile_y := -1.0
		var previous_tile_right := -1.0
		for tile in tiles:
			var hand_scroll := view.find_child("BattleHandScroll", true, false) as ScrollContainer
			if hand_scroll != null:
				hand_scroll.ensure_control_visible(tile)
				await tree.process_frame
			var tile_rect := tile.get_global_rect()
			_assert(_control_fully_visible(tile, viewport_rect), "%s standalone tile %s scrolls fully into view" % [locale, tile.tile_instance_id], failures)
			_assert(tile.face_rect != null and tile.face_rect.texture != null and _control_fully_visible(tile.face_rect, viewport_rect), "%s standalone tile %s displays a visible tile face after scrolling" % [locale, tile.tile_instance_id], failures)
			if first_tile_y < 0.0:
				first_tile_y = tile_rect.position.y
			_assert(first_tile_y < 0.0 or absf(tile_rect.position.y - first_tile_y) <= 2.0, "%s standalone 13-tile Hand stays on one row" % locale, failures)
			_assert(previous_tile_right < 0.0 or tile.position.x >= previous_tile_right - 1.0, "%s standalone Hand row lays out non-overlapping tile hit targets" % locale, failures)
			previous_tile_right = tile.position.x + tile.size.x
	view.queue_free()
	await _settle(tree)
	tree.root.size = prior_size


func _control_fully_visible(control: Control, viewport_rect: Rect2) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var rect := control.get_global_rect()
	var visible_rect := rect.intersection(viewport_rect)
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var ancestor_control := ancestor as Control
			if not ancestor_control.is_visible_in_tree():
				return false
			if ancestor_control.clip_contents:
				visible_rect = visible_rect.intersection(ancestor_control.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect.size.x > 0.0 and rect.size.y > 0.0 and visible_rect.is_equal_approx(rect)


func _settle_long(tree: SceneTree, frame_count: int) -> void:
	for _frame in range(frame_count):
		await tree.process_frame


func _close_actual_run_scene(tree: SceneTree, scene: Node, suspend_path: String, profile_path: String) -> void:
	if is_instance_valid(scene):
		if scene.get_parent() == tree.root:
			tree.root.remove_child(scene)
		scene.free()
	for base_path in [suspend_path, profile_path]:
		for suffix in ["", ".tmp", ".bak"]:
			var absolute_path := ProjectSettings.globalize_path(base_path + suffix)
			if FileAccess.file_exists(absolute_path):
				DirAccess.remove_absolute(absolute_path)


func _test_pair_requires_complete_hand(tree: SceneTree, suffix: String, failures: Array[String]) -> void:
	var controller = _battle_controller("rc3.direct.pair." + suffix, failures)
	if controller == null:
		return
	var battle = controller.domain.current_battle
	var checkpoint_before_pair: Dictionary = controller.domain.checkpoint()
	var replay_before_pair: int = controller.domain.replay_record.commands.size()
	var definitions := [
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3",
		"base.tile.characters.4", "base.tile.characters.5", "base.tile.characters.6",
		"base.tile.characters.7", "base.tile.characters.7",
	]
	_replace_test_hand(battle, definitions, "rc3.direct.complete." + suffix, failures)
	var complete_action: Dictionary = {}
	for action in controller.action_descriptors():
		if str(action.get("kind", "")) == "COMPLETE_HAND":
			complete_action = action
			break
	_assert(not complete_action.is_empty(), "actual Complete Hand evaluator exposes the deterministic two-7 pair interpretation", failures)
	if complete_action.is_empty():
		return
	var details: Dictionary = complete_action.get("details", {})
	var pair_ids: Array = details.get("pair_instance_ids", [])
	_assert(pair_ids.size() == 2 and str(pair_ids[0]) != str(pair_ids[1]), "the legal Complete Hand pair names two distinct physical copies", failures)
	_assert(not controller.action_descriptors().any(func(action): return str(action.get("kind", "")) == "PARTIAL_SETTLEMENT" and str(action.get("details", {}).get("pattern_type", "")) == PatternCandidateScript.PAIR), "a Pair alone is not a Partial Settlement candidate", failures)
	var view = BattleViewScript.new()
	view.set_external_preferences_owner()
	_configure_battle_view(view, controller, tree)
	tree.root.add_child(view)
	await _settle(tree)
	view.render()
	await _settle(tree)
	for raw_id in pair_ids:
		var pair_button = view.tile_button(str(raw_id))
		if pair_button != null:
			await _click_control(tree, pair_button, failures)
	_assert(view.selected_tile_ids().size() == 2, "two equal-definition physical Pair copies remain distinct selections", failures)
	_assert(view.action_button(str(complete_action.get("id", ""))) == null, "a Pair selection alone cannot trigger Complete Hand on a 14-tile hand", failures)
	var pair_hint := view.find_child("BattleSelectionHint", true, false) as Label
	_assert(pair_hint != null and pair_hint.text.contains(LocalizationCatalogScript.text("UI_BATTLE_TABLE_PAIR_INCOMPLETE")), "a Pair selection explains that it needs to be part of a Complete Hand", failures)
	_assert(controller.domain.checkpoint() == checkpoint_before_pair and controller.domain.replay_record.commands.size() == replay_before_pair, "invalid incomplete Pair selection creates no command", failures)
	view.queue_free()
	await _settle(tree)


func _test_exhausted_capacity_explanation(tree: SceneTree, suffix: String, failures: Array[String]) -> void:
	var controller = _battle_controller("rc3.direct.capacity." + suffix, failures)
	if controller == null:
		return
	var battle = controller.domain.current_battle
	var checkpoint_before_selection: Dictionary = controller.domain.checkpoint()
	var replay_before_selection: int = controller.domain.replay_record.commands.size()
	_replace_test_hand(battle, [
		"base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.east",
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.3", "base.tile.bamboo.5",
		"base.tile.dots.2", "base.tile.dots.4", "base.tile.dots.6", "base.tile.characters.9",
	], "rc3.direct.capacity." + suffix, failures)
	var window = battle.settlement_window
	_assert(window.open(), "capacity fixture opens on an actual East Triplet candidate", failures)
	var capacity = window.settlement_capacity()
	while capacity.remaining > 0:
		_assert(capacity.consume(), "capacity fixture spends one real SettlementCapacity unit", failures)
	_assert(capacity.remaining == 0 and battle.settlement_window.candidates().any(func(candidate): return str(candidate.pattern_type) == PatternCandidateScript.TRIPLET and _same_ids(_candidate_ids(candidate), _ids_for_definition(battle.zones.contents(TileZoneScript.HAND), "base.tile.honors.east"))), "an actual East Triplet remains structurally legal after the two-per-battle capacity is spent", failures)
	_assert(not battle.can_settle(), "BattleDomain blocks further settlements when remaining capacity is zero", failures)
	var view = BattleViewScript.new()
	view.set_external_preferences_owner()
	_configure_battle_view(view, controller, tree)
	tree.root.add_child(view)
	await _settle(tree)
	view.render()
	await _settle(tree)
	for east_id in _ids_for_definition(battle.zones.contents(TileZoneScript.HAND), "base.tile.honors.east"):
		var tile_button = view.tile_button(east_id)
		if tile_button != null:
			await _click_control(tree, tile_button, failures)
	var hint := view.find_child("BattleSelectionHint", true, false) as Label
	_assert(hint != null and hint.text.contains(LocalizationCatalogScript.format("UI_BATTLE_TABLE_SETTLEMENT_CAPACITY_EXHAUSTED", [capacity.spent, capacity.maximum])), "valid selected Triplet explains exhausted Settlement capacity instead of generic No Match", failures)
	_assert(hint != null and hint.text.contains(LocalizationCatalogScript.format("UI_BATTLE_TABLE_SETTLEMENT_CAPACITY_REMAINING", [capacity.remaining, capacity.maximum])), "the selected Triplet reports the remaining/maximum settlement allowance", failures)
	var east_triplet_candidates: Array = battle.settlement_window.candidates().filter(func(value): return str(value.pattern_type) == PatternCandidateScript.TRIPLET and _same_ids(_candidate_ids(value), _ids_for_definition(battle.zones.contents(TileZoneScript.HAND), "base.tile.honors.east")))
	var candidate = east_triplet_candidates[0] if not east_triplet_candidates.is_empty() else null
	var blocked_button := view.action_button("battle.settle:" + str(candidate.candidate_id)) if candidate != null else null
	_assert(blocked_button != null and blocked_button.disabled, "a structurally legal but blocked Triplet remains visible as a disabled Play action", failures)
	if blocked_button != null:
		await _click_control(tree, blocked_button, failures)
	_assert(not _has_action_kind(controller.action_descriptors(), "PARTIAL_SETTLEMENT"), "exhausted capacity keeps every partial-play action non-executable", failures)
	_assert(controller.domain.checkpoint() == checkpoint_before_selection and controller.domain.replay_record.commands.size() == replay_before_selection, "selection while capacity is exhausted issues no domain command", failures)
	view.queue_free()
	await _settle(tree)


func _test_closed_window_explanation(tree: SceneTree, suffix: String, failures: Array[String]) -> void:
	var controller = _battle_controller("rc3.direct.closed." + suffix, failures)
	if controller == null:
		return
	var battle = controller.domain.current_battle
	var checkpoint_before: Dictionary = controller.domain.checkpoint()
	var replay_before: int = controller.domain.replay_record.commands.size()
	_replace_test_hand(battle, [
		"base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.east",
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.3", "base.tile.bamboo.5",
		"base.tile.dots.2", "base.tile.dots.4", "base.tile.dots.6", "base.tile.characters.9",
	], "rc3.direct.closed." + suffix, failures)
	var window = battle.settlement_window
	_assert(window.open(), "closed-window fixture opens on an actual East Triplet candidate", failures)
	_assert(window.settlement_capacity().remaining > 0, "closed-window fixture keeps its real Settlement allowance", failures)
	window.close()
	_assert(not window.is_open(), "the real SettlementWindow closes", failures)
	var view = BattleViewScript.new()
	view.set_external_preferences_owner()
	_configure_battle_view(view, controller, tree)
	tree.root.add_child(view)
	await _settle(tree)
	view.render()
	await _settle(tree)
	for east_id in _ids_for_definition(battle.zones.contents(TileZoneScript.HAND), "base.tile.honors.east"):
		var tile_button = view.tile_button(east_id)
		if tile_button != null:
			await _click_control(tree, tile_button, failures)
	var candidates: Array = window.candidates().filter(func(candidate): return str(candidate.pattern_type) == PatternCandidateScript.TRIPLET and _same_ids(_candidate_ids(candidate), _ids_for_definition(battle.zones.contents(TileZoneScript.HAND), "base.tile.honors.east")))
	var candidate = candidates[0] if not candidates.is_empty() else null
	var blocked_button := view.action_button("battle.settle:" + str(candidate.candidate_id)) if candidate != null else null
	var hint := view.find_child("BattleSelectionHint", true, false) as Label
	_assert(hint != null and hint.text.contains(LocalizationCatalogScript.text("UI_BATTLE_TABLE_WINDOW_CLOSED")), "valid selected Triplet explains a closed SettlementWindow", failures)
	_assert(blocked_button != null and blocked_button.disabled, "closed-window Triplet remains visible as a disabled Play action", failures)
	_assert(controller.domain.checkpoint() == checkpoint_before and controller.domain.replay_record.commands.size() == replay_before, "closed-window selection issues no domain command", failures)
	view.queue_free()
	await _settle(tree)


func _triplet_action(actions: Array, expected_ids: Array[String]) -> Dictionary:
	for action in actions:
		if not action is Dictionary or str(action.get("kind", "")) != "PARTIAL_SETTLEMENT":
			continue
		var details: Dictionary = action.get("details", {})
		if str(details.get("pattern_type", "")) == PatternCandidateScript.TRIPLET and _same_ids(details.get("instance_ids", []), expected_ids):
			return action
	return {}


func _same_ids(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	var sorted_first: Array = first.duplicate()
	var sorted_second: Array = second.duplicate()
	sorted_first.sort()
	sorted_second.sort()
	return sorted_first == sorted_second


func _candidate_ids(candidate) -> Array[String]:
	var ids: Array[String] = []
	for tile in candidate.tile_instances:
		ids.append(str(tile.instance_id))
	return ids


func _ids_for_definition(hand: Array, definition_id: String) -> Array[String]:
	var ids: Array[String] = []
	for tile in hand:
		if str(tile.definition_id) == definition_id:
			ids.append(str(tile.instance_id))
	return ids


func _battle_controller(run_id: String, failures: Array[String]):
	var registry = ContentRegistryScript.new()
	for report in [Phase2CatalogScript.register_all(registry), AlphaActTwoCatalogScript.register_all(registry), AlphaScaleCatalogScript.register_all(registry)]:
		_assert(report.is_valid(), "test content catalogs register without errors", failures)
	var domain = RunDomainScript.new_alpha_run(run_id, 314159, registry)
	var controller = RunPresentationControllerScript.new(domain)
	var character_result = controller.confirm("character:base.character.sequence")
	_assert(character_result != null and character_result.accepted, "test Run selects a real Character", failures)
	var contract_result = controller.confirm("contract:base.contract.pressure")
	_assert(contract_result != null and contract_result.accepted, "test Run selects a real Contract", failures)
	var map_actions: Array = controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "MAP_NODE")
	_assert(not map_actions.is_empty(), "test Run exposes its real starting Map action", failures)
	if map_actions.is_empty():
		return null
	var map_result = controller.confirm(str(map_actions[0].get("id", "")))
	_assert(map_result != null and map_result.accepted and domain.state.phase == RunPhaseScript.BATTLE, "test Run reaches its actual Battle phase", failures)
	return controller


func _replace_test_hand(battle, definition_ids: Array, fixture_name: String, failures: Array[String]) -> void:
	for tile in battle.zones.contents(TileZoneScript.HAND):
		_assert(battle.zones.transfer(str(tile.instance_id), TileZoneScript.HAND, TileZoneScript.DISCARD), "%s fixture moves the previous Hand instance into Discard" % fixture_name, failures)
	for index in definition_ids.size():
		var fixture_tile = TileInstanceScript.new("rc3.direct.%s.%02d" % [fixture_name, index], str(definition_ids[index]))
		_assert(battle.zones.add(fixture_tile, TileZoneScript.HAND), "%s fixture installs an exact physical Hand instance" % fixture_name, failures)


func _has_action_kind(actions: Array, kind: String) -> bool:
	return actions.any(func(action): return str(action.get("kind", "")) == kind)


func _has_pair_partial_candidate(actions: Array) -> bool:
	return actions.any(func(action): return str(action.get("kind", "")) == "PARTIAL_SETTLEMENT" and str(action.get("details", {}).get("pattern_type", "")) == PatternCandidateScript.PAIR)


func _settle(tree: SceneTree) -> void:
	for _frame in range(4):
		await tree.process_frame


func _configure_battle_view(view, controller, tree: SceneTree) -> void:
	var label_provider = RunSceneScript.new()
	label_provider.controller = controller
	_label_provider_nodes.append(label_provider)
	view.configure(
		controller,
		Callable(label_provider, "_action_label"),
		Callable(label_provider, "_action_tooltip"),
		Callable(label_provider, "_action_details_text"),
	)
	var preferences = tree.root.get_node_or_null("PresentationPrefs")
	var values: Dictionary = preferences.snapshot() if preferences != null and preferences.has_method("snapshot") else {
		"locale": "en",
		"ui_scale": 1.0,
		"presentation_mode": "NORMAL",
		"reduced_motion": false,
		"ambient_glow": true,
	}
	view.set_presentation_preferences(
		str(values.get("locale", "en")),
		float(values.get("ui_scale", 1.0)),
		str(values.get("presentation_mode", "NORMAL")),
		bool(values.get("reduced_motion", false)),
		bool(values.get("ambient_glow", true)),
	)


func _click_control(tree: SceneTree, control: Control, failures: Array[String]) -> void:
	var control_rect := control.get_global_rect()
	var position := control_rect.get_center()
	var viewport_rect: Rect2 = tree.root.get_visible_rect()
	var clipped_rect := control_rect.intersection(viewport_rect)
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var ancestor_control := ancestor as Control
			if not ancestor_control.is_visible_in_tree():
				clipped_rect = Rect2()
				break
			if ancestor_control.clip_contents:
				clipped_rect = clipped_rect.intersection(ancestor_control.get_global_rect())
		ancestor = ancestor.get_parent()
	var center_is_visible := control.is_visible_in_tree() and viewport_rect.has_point(position) and clipped_rect.has_point(position)
	if not center_is_visible:
		var battle_view: Node = control
		while battle_view != null:
			var script := battle_view.get_script() as Script
			if script != null and script.resource_path.ends_with("/src/presentation/ui/battle_view.gd"):
				break
			battle_view = battle_view.get_parent()
		var view_rect: Rect2 = battle_view.get_global_rect() if battle_view is Control else Rect2()
		var view_scale := float(battle_view.get("_ui_scale")) if battle_view != null and battle_view.get("_ui_scale") != null else -1.0
		var preferences = tree.root.get_node_or_null("PresentationPrefs")
		var preference_snapshot: Dictionary = preferences.call("snapshot") if preferences != null and preferences.has_method("snapshot") else {}
		var root_child_names: Array[String] = []
		for child in tree.root.get_children():
			root_child_names.append(str(child.name))
		print("RC3_MOUSE_GEOMETRY control=%s rect=%s viewport=%s clipped=%s view_rect=%s ui_scale=%.2f locale=%s prefs=%s root_children=%s" % [control.get_path(), control_rect, viewport_rect, clipped_rect, view_rect, view_scale, TranslationServer.get_locale(), preference_snapshot, root_child_names])
	_assert(center_is_visible, "mouse click center for %s is visible inside viewport and every clipping ancestor (control=%s clipped=%s viewport=%s)" % [control.name, control_rect, clipped_rect, viewport_rect], failures)
	if not center_is_visible:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := InputEventMouseButton.new()
	release.position = position
	release.global_position = position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await tree.process_frame


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if condition:
		print("PASS " + message)
		return
	failures.append("ASSERTION FAILED: " + message)
	push_error("ASSERTION FAILED: " + message)
