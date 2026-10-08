class_name Rc5BattleLayoutRegressionTest
extends RefCounted

const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const BattleViewScript = preload("res://src/presentation/ui/battle_view.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const RunSceneScript = preload("res://scenes/run/run_scene.gd")
const RunScenePacked = preload("res://scenes/run/run_scene.tscn")
const TileFaceButtonScript = preload("res://src/presentation/ui/tile_face_button.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["RC5 Battle layout regression requires SceneTree"]
	var prior_size := tree.root.size
	var prior_locale := TranslationServer.get_locale()
	var suffix := "%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	tree.root.size = Vector2i(1280, 720)
	var controller = _battle_controller("rc5.battle.layout." + suffix, failures)
	if controller == null:
		tree.root.size = prior_size
		TranslationServer.set_locale(prior_locale)
		return failures
	var battle = controller.domain.current_battle
	_replace_test_hand(battle, [
		"base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.east",
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3", "base.tile.characters.4",
	], suffix, failures)
	battle.settlement_window.close()
	var setup_draw = controller.confirm("battle.draw")
	_assert(setup_draw != null and bool(setup_draw.accepted), "layout fixture uses an accepted Draw to unlock tile manipulation choices", failures)
	battle = controller.domain.current_battle
	_replace_test_hand(battle, [
		"base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.east",
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3", "base.tile.characters.4",
	], suffix + ".after-draw", failures)
	_assert(battle.settlement_window.open(), "layout fixture opens a real SettlementWindow for the East triplet", failures)

	var label_provider = RunSceneScript.new()
	label_provider.controller = controller
	var view = BattleViewScript.new()
	view.set_external_preferences_owner()
	view.configure(
		controller,
		Callable(label_provider, "_action_label"),
		Callable(label_provider, "_action_tooltip"),
		Callable(label_provider, "_action_details_text"),
	)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(view)
	var requested_action_ids: Array[String] = []
	var accepted_commands: Array[bool] = []
	view.action_requested.connect(func(action_id: String) -> void:
		requested_action_ids.append(action_id)
		var result = controller.confirm(action_id)
		accepted_commands.append(result != null and bool(result.accepted))
	)
	controller.presentation_changed.connect(func() -> void:
		if is_instance_valid(view):
			view.render()
	)

	var viewport_cases := [
		{"name": "960x540", "size": Vector2i(960, 540)},
		{"name": "1280x720", "size": Vector2i(1280, 720)},
		{"name": "1920x1080", "size": Vector2i(1920, 1080)},
		{"name": "540x960 portrait", "size": Vector2i(540, 960)},
	]
	for scale in [1.0, 1.25, 1.5]:
		for locale in ["en", "zh_CN"]:
			TranslationServer.set_locale(locale)
			for viewport_case in viewport_cases:
				tree.root.size = viewport_case.size
				view.set_presentation_preferences(locale, scale, "NORMAL", true, false)
				view.render()
				await _settle(tree, 7)
				await _check_layout_case(view, controller, viewport_case, locale, scale, tree, failures)

	# Real pointer events check that the bottom row is usable and that selecting
	# tiles only reveals actions; it never settles them without a Play press.
	tree.root.size = Vector2i(1280, 720)
	TranslationServer.set_locale("en")
	view.set_presentation_preferences("en", 1.0, "NORMAL", true, false)
	view.render()
	await _settle(tree, 8)
	var hand_scroll := view.find_child("BattleHandScroll", true, false) as ScrollContainer
	var east_ids := _ids_for_definition(battle.zones.contents(TileZoneScript.HAND), "base.tile.honors.east")
	_assert(east_ids.size() == 3 and east_ids[0] != east_ids[1] and east_ids[1] != east_ids[2], "interaction fixture has three distinct East tile controls", failures)
	var checkpoint_before_selection: Dictionary = controller.domain.checkpoint()
	var command_count_before_selection: int = controller.domain.replay_record.commands.size()
	if hand_scroll != null and not east_ids.is_empty():
		hand_scroll.scroll_horizontal = 0
		await _settle(tree, 2)
		for east_index in east_ids.size():
			var east_id := east_ids[east_index]
			var tile_button = view.tile_button(east_id)
			_assert(tile_button != null and tile_button.face_rect.texture != null, "each East selection target renders a real face", failures)
			if tile_button != null:
				await _click_control(tree, tile_button, failures)
			if east_index == 0:
				_assert(view.selected_tile_ids() == [east_id], "one tile click exposes tile-specific actions without selecting the whole hand", failures)
				var selected_action_kinds: Dictionary = {}
				for action in controller.action_descriptors():
					var action_kind := str(action.get("kind", ""))
					if action_kind not in ["RESERVE", "DISCARD"] or str(action.get("target_id", "")) != east_id:
						continue
					var contextual_button := view.action_button(str(action.get("id", ""))) as Button
					_assert(contextual_button != null and not contextual_button.disabled, "%s becomes an enabled direct action for the selected physical tile" % action_kind, failures)
					if contextual_button != null:
						var action_scroll := view.find_child("BattleChoiceScroll", true, false) as ScrollContainer
						if action_scroll != null and action_scroll.is_ancestor_of(contextual_button):
							action_scroll.ensure_control_visible(contextual_button)
							await _settle(tree, 2)
							_assert(_center_visible_with_clips(contextual_button, tree.root.get_visible_rect()), "%s can scroll into the visible action surface" % action_kind, failures)
						else:
							_assert(false, "%s action is placed in the scrollable action surface" % action_kind, failures)
					selected_action_kinds[action_kind] = true
				_assert(selected_action_kinds.has("RESERVE"), "the selected tile offers a Reserve control", failures)
				_assert(selected_action_kinds.has("DISCARD"), "the selected tile offers a Discard control", failures)
		_assert(view.selected_tile_ids().size() == 3, "mouse-selecting the three East faces reveals the exact Play candidate", failures)
		_assert(controller.domain.checkpoint() == checkpoint_before_selection and controller.domain.replay_record.commands.size() == command_count_before_selection, "tile selection alone issues no settlement or other command", failures)
		var candidate_action := _triplet_action(controller.action_descriptors(), east_ids)
		var candidate_id := str(candidate_action.get("id", ""))
		var play_button := view.action_button(candidate_id) as Button
		_assert(not candidate_action.is_empty() and play_button != null and not play_button.disabled, "the legal East Triplet is a reachable enabled Play action", failures)
		if play_button != null:
			var action_scroll := view.find_child("BattleChoiceScroll", true, false) as ScrollContainer
			if action_scroll != null:
				action_scroll.ensure_control_visible(play_button)
				await _settle(tree, 2)
			_assert(_center_visible_with_clips(play_button, tree.root.get_visible_rect()), "Play action can be scrolled to a visible, clickable location", failures)
			var command_count_before_play: int = controller.domain.replay_record.commands.size()
			await _click_control(tree, play_button, failures)
			_assert(requested_action_ids == [candidate_id], "one direct Play press emits one action request and no confirmation step", failures)
			_assert(accepted_commands == [true], "the direct Play press submits an accepted domain command", failures)
			_assert(controller.domain.replay_record.commands.size() == command_count_before_play + 1, "one Play press records exactly one domain command", failures)
	else:
		_assert(false, "Battle exposes the scrollable player Hand for pointer interaction", failures)

	view.queue_free()
	label_provider.free()
	await _settle(tree, 2)
	await _test_actual_run_scene_matrix(tree, suffix, failures)
	tree.root.size = prior_size
	TranslationServer.set_locale(prior_locale)
	print("RC5_BATTLE_LAYOUT_REPORT failures=%d" % failures.size())
	return failures


func _test_actual_run_scene_matrix(tree: SceneTree, suffix: String, failures: Array[String]) -> void:
	var prior_locale := TranslationServer.get_locale()
	var suspend_path := "user://rc5_actual_battle_%s_suspend.json" % suffix
	var profile_path := "user://rc5_actual_battle_%s_profile.json" % suffix
	tree.root.size = Vector2i(1280, 720)
	var run_scene = RunScenePacked.instantiate()
	run_scene.suspend_file_path = suspend_path
	run_scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	tree.root.add_child(run_scene)
	await _settle(tree, 12)
	run_scene._apply_presentation_preferences({
		"locale": "en",
		"ui_scale": 1.0,
		"presentation_mode": "NORMAL",
		"reduced_motion": true,
		"ambient_glow": false,
	}, true)
	await _settle(tree, 12)
	var controller = run_scene.controller
	_assert(controller != null, "real RunScene initializes a controller with isolated suspend/profile paths", failures)
	if controller == null:
		await _close_actual_run_scene(tree, run_scene, suspend_path, profile_path)
		TranslationServer.set_locale(prior_locale)
		return
	for kind in ["CHARACTER", "CONTRACT", "MAP_NODE"]:
		var action := _first_action_of_kind(controller.action_descriptors(), kind)
		_assert(not action.is_empty(), "real RunScene offers its actual %s setup choice" % kind, failures)
		if action.is_empty():
			await _close_actual_run_scene(tree, run_scene, suspend_path, profile_path)
			TranslationServer.set_locale(prior_locale)
			return
		var result = controller.confirm(str(action.get("id", "")))
		_assert(result != null and bool(result.accepted), "real RunScene accepts its actual %s setup choice" % kind, failures)
		if result == null or not bool(result.accepted):
			await _close_actual_run_scene(tree, run_scene, suspend_path, profile_path)
			TranslationServer.set_locale(prior_locale)
			return
	await _settle(tree, 18)
	var battle = controller.domain.current_battle
	_assert(battle != null and controller.domain.state.phase == RunPhaseScript.BATTLE, "real RunScene enters a Battle before shell layout checks", failures)
	if battle == null:
		await _close_actual_run_scene(tree, run_scene, suspend_path, profile_path)
		TranslationServer.set_locale(prior_locale)
		return
	_replace_test_hand(battle, [
		"base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.east",
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3", "base.tile.characters.4",
	], "actual.%s" % suffix, failures)
	_assert(battle.settlement_window.open(), "real RunScene fixture opens its real SettlementWindow", failures)
	run_scene._render()
	await _settle(tree, 18)
	await _test_settings_focus_preserves_tile_inspection(run_scene, tree, failures)
	var viewport_cases := [
		{"name": "960x540", "size": Vector2i(960, 540)},
		{"name": "540x960 portrait", "size": Vector2i(540, 960)},
		{"name": "1920x1080", "size": Vector2i(1920, 1080)},
	]
	for scale in [1.0, 1.25, 1.5]:
		for locale in ["en", "zh_CN"]:
			for viewport_case in viewport_cases:
				var case_name := "actual RunScene/%s/%s/%d%%" % [str(viewport_case.get("name", "viewport")), locale, roundi(scale * 100.0)]
				tree.root.size = viewport_case.size
				run_scene._apply_presentation_preferences({
					"locale": locale,
					"ui_scale": scale,
					"presentation_mode": "NORMAL",
					"reduced_motion": true,
					"ambient_glow": false,
				}, true)
				run_scene._render()
				await _settle(tree, 18)
				var view: Control = run_scene.get("_battle_view") as Control
				var action_surface := view.find_child("BattleActions", true, false) as Control if view != null else null
				var hand_surface := view.find_child("BattleHandSurface", true, false) as Control if view != null else null
				var hand_scroll := view.find_child("BattleHandScroll", true, false) as ScrollContainer if view != null else null
				var hand_row := view.find_child("BattleHandTiles", true, false) as HBoxContainer if view != null else null
				var action_scroll := view.find_child("BattleChoiceScroll", true, false) as ScrollContainer if view != null else null
				var root_scroll := run_scene.find_child("RunRootScroll", true, false) as ScrollContainer
				var viewport_rect := tree.root.get_visible_rect()
				_assert(view != null and view.is_visible_in_tree(), "%s creates and shows the real BattleView" % case_name, failures)
				_assert(action_surface != null and hand_surface != null and hand_scroll != null and hand_row != null and action_scroll != null and root_scroll != null, "%s exposes action, hand, and actual RunScene scroll surfaces" % case_name, failures)
				if view == null or action_surface == null or hand_surface == null or hand_scroll == null or hand_row == null or action_scroll == null or root_scroll == null:
					continue
				var view_rect := view.get_global_rect()
				var action_rect := action_surface.get_global_rect()
				var hand_rect := hand_surface.get_global_rect()
				var run_columns := run_scene.get("_run_columns") as Control
				_assert(
					action_rect.position.y < hand_rect.position.y and action_rect.end.y <= hand_rect.position.y + 2.0
					and absf(action_rect.position.x - hand_rect.position.x) <= 2.0
					and absf(action_rect.size.x - hand_rect.size.x) <= 2.0,
					"%s keeps the full-width action bar immediately above the hand" % case_name,
					failures,
				)
				var root_scrollbar := root_scroll.get_v_scroll_bar()
				var action_scrollbar := action_scroll.get_v_scroll_bar()
				var root_maximum := maxf(0.0, root_scrollbar.max_value - root_scrollbar.page)
				var required_view_height := hand_rect.end.y - view_rect.position.y + 8.0
				print("RC5_ACTUAL_RUN_SCENE_GEOMETRY case=%s viewport=%s columns=%s columns_min=%s view=%s view_min=%s required_view_height=%.1f actions=%s hand=%s root_scroll_page=%.1f root_scroll_max=%.1f root_scroll=%.1f" % [
					case_name,
					str(viewport_rect),
					str(run_columns.get_global_rect() if run_columns != null else Rect2()),
					str(run_columns.custom_minimum_size if run_columns != null else Vector2.ZERO),
					str(view_rect),
					str(view.get_combined_minimum_size()),
					required_view_height,
					str(action_rect),
					str(hand_rect),
					root_scrollbar.page,
					root_maximum,
					root_scroll.scroll_vertical,
				])
				var action_count := 0
				var enabled_action_count := 0
				for candidate in view.find_children("*", "Button", true, false):
					var button := candidate as Button
					var action_id := str(button.get_meta("run_action_id", ""))
					if action_id.is_empty():
						continue
					action_count += 1
					if button.disabled:
						continue
					enabled_action_count += 1
					button.grab_focus()
					await _settle(tree, 4)
					_assert(tree.root.gui_get_focus_owner() == button, "%s can focus actual action %s" % [case_name, action_id], failures)
					var button_context := "case=%s action=%s path=%s queued=%s button=%s actionScroll=%s actionScrollV=%.1f/%.1f(page=%.1f) actionSurface=%s view=%s rootScroll=%.1f/%.1f clips=%s" % [case_name, action_id, str(button.get_path()), str(button.is_queued_for_deletion()), str(button.get_global_rect()), str(action_scroll.get_global_rect()), action_scroll.scroll_vertical, maxf(0.0, action_scrollbar.max_value - action_scrollbar.page), action_scrollbar.page, str(action_surface.get_global_rect()), str(view.get_global_rect()), root_scroll.scroll_vertical, root_maximum, _clip_chain_description(button, viewport_rect)]
					_assert(_center_visible_with_clips(button, viewport_rect), "%s focuses action center through actual ancestor clipping (%s)" % [case_name, button_context], failures)
				_assert(action_count > 0 and enabled_action_count > 0, "%s exposes and focuses at least one selectable real action" % case_name, failures)
				var hand_tiles: Array[TileFaceButtonScript] = []
				for child in hand_row.get_children():
					if child is TileFaceButtonScript:
						hand_tiles.append(child as TileFaceButtonScript)
				_assert(hand_tiles.size() == 13, "%s builds all 13 physical tile controls in the actual RunScene" % case_name, failures)
				if hand_tiles.size() == 13:
					for tile in [hand_tiles.front(), hand_tiles.back()]:
						tile.grab_focus()
						await _settle(tree, 4)
						var face_rect := tile.face_rect as Control
						var tile_context := "case=%s tile=%s tileRect=%s faceRect=%s view=%s rootScroll=%.1f/%.1f" % [case_name, tile.tile_instance_id, str(tile.get_global_rect()), str(face_rect.get_global_rect() if face_rect != null else Rect2()), str(view.get_global_rect()), root_scroll.scroll_vertical, root_maximum]
						_assert(tree.root.gui_get_focus_owner() == tile, "%s can focus first/last physical tile %s" % [case_name, tile.tile_instance_id], failures)
						_assert(tile.face_rect != null and tile.face_rect.texture != null, "%s draws a real texture for physical tile %s" % [case_name, tile.tile_instance_id], failures)
						_assert(_center_visible_with_clips(tile, viewport_rect), "%s reveals tile center through actual hand/RunScene clip ancestors (%s)" % [case_name, tile_context], failures)
						_assert(face_rect != null and _center_visible_with_clips(face_rect, viewport_rect), "%s reveals the actual first/last tile face through clipping (%s)" % [case_name, tile_context], failures)
	await _close_actual_run_scene(tree, run_scene, suspend_path, profile_path)
	TranslationServer.set_locale(prior_locale)


func _test_settings_focus_preserves_tile_inspection(run_scene: Node, tree: SceneTree, failures: Array[String]) -> void:
	var battle_view := run_scene.get("_battle_view") as Control
	var settings_button := run_scene.find_child("SettingsButton", true, false) as Button
	var hand_row := battle_view.find_child("BattleHandTiles", true, false) as HBoxContainer if battle_view != null else null
	var inspection := battle_view.call("inspection_label") as Label if battle_view != null else null
	_assert(battle_view != null and settings_button != null and hand_row != null and inspection != null, "actual RunScene exposes Battle inspection and its Header Settings control", failures)
	if battle_view == null or settings_button == null or hand_row == null or inspection == null or hand_row.get_child_count() == 0:
		return
	var tile := hand_row.get_child(0) as TileFaceButtonScript
	_assert(tile != null and not tile.tooltip_text.is_empty(), "actual hand tile exposes localized inspection copy", failures)
	if tile == null:
		return
	tile.grab_focus()
	await _settle(tree, 4)
	var expected_inspection := tile.tooltip_text
	_assert(inspection.text == expected_inspection and not expected_inspection.is_empty(), "focusing an actual hand tile populates its Battle inspector", failures)
	settings_button.grab_focus()
	await _settle(tree, 4)
	_assert(tree.root.gui_get_focus_owner() == settings_button, "Header Settings can take focus while a hand tile remains inspected", failures)
	_assert(inspection.text == expected_inspection, "moving focus to Header Settings leaves the inspected hand tile readable", failures)
	for mode in ["NORMAL", "FAST", "INSTANT"]:
		var preferences: Dictionary = run_scene.get("_applied_preferences").duplicate(true)
		preferences["presentation_mode"] = mode
		run_scene._apply_presentation_preferences(preferences, true)
		await _settle(tree, 8)
		_assert(tree.root.gui_get_focus_owner() == settings_button, "mode %s keeps valid Header Settings focus through Battle rerender" % mode, failures)
		_assert(inspection.text == expected_inspection, "mode %s keeps the selected tile text in the Battle inspector" % mode, failures)


func _first_action_of_kind(actions: Array, kind: String) -> Dictionary:
	if kind == "CHARACTER":
		for action in actions:
			if str(action.get("target_id", "")) == "base.character.sequence":
				return action
	for action in actions:
		if action is Dictionary and str(action.get("kind", "")) == kind:
			return action
	return {}


func _close_actual_run_scene(tree: SceneTree, scene: Node, suspend_path: String, profile_path: String) -> void:
	if is_instance_valid(scene):
		if scene.get_parent() == tree.root:
			tree.root.remove_child(scene)
		scene.free()
	for base_path in [suspend_path, profile_path]:
		for extension in ["", ".tmp", ".bak"]:
			var absolute_path := ProjectSettings.globalize_path(base_path + extension)
			if FileAccess.file_exists(absolute_path):
				DirAccess.remove_absolute(absolute_path)


func _check_layout_case(
	view: Control,
	controller: Object,
	viewport_case: Dictionary,
	locale: String,
	scale: float,
	tree: SceneTree,
	failures: Array[String],
) -> void:
	var case_name := "%s/%s/%d%%" % [str(viewport_case.get("name", "viewport")), locale, roundi(scale * 100.0)]
	var viewport_rect := tree.root.get_visible_rect()
	var board := view.find_child("BattleBoardSurface", true, false) as Control
	var board_scroll := view.find_child("BattleViewportScroll", true, false) as ScrollContainer
	var action_panel := view.find_child("BattleActions", true, false) as Control
	var action_scroll := view.find_child("BattleChoiceScroll", true, false) as ScrollContainer
	var hand_surface := view.find_child("BattleHandSurface", true, false) as Control
	var hand_tray := view.find_child("BattleHandTray", true, false) as Control
	var hand_scroll := view.find_child("BattleHandScroll", true, false) as ScrollContainer
	var hand_row := view.find_child("BattleHandTiles", true, false) as HBoxContainer
	var enemy_arena := view.find_child("BattleEnemyIntentBanner", true, false) as Control
	var critical_scroll := view.find_child("BattleCriticalScroll", true, false) as ScrollContainer
	var table := view.find_child("BattleTable", true, false) as Control
	var zones := view.find_child("BattleZones", true, false) as Control
	_assert(board != null and board_scroll != null and action_panel != null and action_scroll != null and hand_surface != null and hand_tray != null and hand_scroll != null and hand_row != null, "%s builds board, action and hand surfaces" % case_name, failures)
	if board == null or board_scroll == null or action_panel == null or action_scroll == null or hand_surface == null or hand_tray == null or hand_scroll == null or hand_row == null:
		return
	var board_rect := board.get_global_rect()
	var action_rect := action_panel.get_global_rect()
	var hand_rect := hand_surface.get_global_rect()
	_assert((view as Control).is_visible_in_tree() and _fully_visible(view, viewport_rect), "%s BattleView fits the viewport" % case_name, failures)
	_assert(action_rect.position.x >= viewport_rect.position.x and action_rect.end.x <= viewport_rect.end.x + 1.0, "%s full-width action surface stays in the viewport" % case_name, failures)
	_assert(absf(action_rect.position.x - hand_rect.position.x) <= 2.0 and absf(action_rect.size.x - hand_rect.size.x) <= 2.0, "%s actions align with the Hand instead of a right-side column" % case_name, failures)
	_assert(board_rect.position.y < action_rect.position.y and action_rect.end.y <= hand_rect.position.y + 2.0, "%s board, action bar, then pinned Hand follow the requested order" % case_name, failures)
	_assert(_fully_visible(action_panel, viewport_rect) and _fully_visible(hand_surface, viewport_rect) and _fully_visible(hand_tray, viewport_rect), "%s selectable action bar and complete Hand tray remain visible" % case_name, failures)
	_assert(_fully_visible(hand_scroll, viewport_rect) and hand_row.get_child_count() == 13, "%s exposes all 13 physical tile controls through a one-row Hand scroller" % case_name, failures)
	_assert(hand_row is HBoxContainer and hand_row.size.y > 0.0 and hand_scroll.get_h_scroll_bar() != null, "%s preserves one row and horizontal access when faces do not fit" % case_name, failures)
	_assert(table != null and zones != null and table.is_ancestor_of(zones) and board_scroll.is_ancestor_of(table), "%s keeps Reserve, Discard and Exhaust on the middle board surface" % case_name, failures)
	_assert(critical_scroll != null and enemy_arena != null and critical_scroll.is_ancestor_of(enemy_arena), "%s keeps enemy/status information in its own scrollable top rail" % case_name, failures)
	_assert(view.find_child("BattleYakuProgress", true, false) == null and view.find_child("YakuLocalGroup", true, false) == null and view.find_child("YakuHandGroup", true, false) == null, "%s removes the central detailed Yaku lists" % case_name, failures)
	_assert(view.find_child("BattleSelectionActions", true, false) != null and view.find_child("BattleTurnActions", true, false) != null, "%s provides selection-specific Play and general turn-action groups" % case_name, failures)

	var hand_buttons: Array[TileFaceButton] = []
	for child in hand_row.get_children():
		if child is TileFaceButton:
			hand_buttons.append(child as TileFaceButton)
	_assert(hand_buttons.size() == 13 and hand_buttons.all(func(tile): return tile.face_rect != null and tile.face_rect.texture != null), "%s loads a real textured face for every hand control" % case_name, failures)
	if not hand_buttons.is_empty():
		hand_scroll.scroll_horizontal = 0
		hand_scroll.ensure_control_visible(hand_buttons[0])
		await tree.process_frame
		_assert(_center_visible_with_clips(hand_buttons[0], viewport_rect), "%s scrolls the first physical tile into the visible hand tray" % case_name, failures)
		hand_scroll.scroll_horizontal = int(maxf(0.0, hand_scroll.get_h_scroll_bar().max_value - hand_scroll.get_h_scroll_bar().page))
		hand_scroll.ensure_control_visible(hand_buttons.back())
		await tree.process_frame
		_assert(_center_visible_with_clips(hand_buttons.back(), viewport_rect), "%s scrolls the last physical tile into the visible hand tray" % case_name, failures)

	var draw_button := view.call("action_button", "battle.draw") as Button
	var end_turn_button := view.call("action_button", "battle.end_turn") as Button
	_assert(draw_button != null and end_turn_button != null, "%s presents Draw and End Turn as direct actions" % case_name, failures)
	var turn_action_count := 0
	var technique_action_count := 0
	for action in controller.action_descriptors():
		var kind := str(action.get("kind", ""))
		if kind not in ["DRAW", "END_TURN", "TECHNIQUE"]:
			continue
		turn_action_count += 1
		if kind == "TECHNIQUE":
			technique_action_count += 1
		var button := view.call("action_button", str(action.get("id", ""))) as Button
		_assert(button != null, "%s renders every offered %s action" % [case_name, kind], failures)
		if button == null:
			continue
		action_scroll.ensure_control_visible(button)
		await tree.process_frame
		_assert(_center_visible_with_clips(button, viewport_rect), "%s can scroll each %s button into the clipped action viewport" % [case_name, kind], failures)
		_assert(button.custom_minimum_size.y >= 44.0 * scale - 1.0, "%s keeps %s at a full-size pointer target" % [case_name, kind], failures)
	_assert(turn_action_count >= 2, "%s fixture includes real Draw and End Turn command choices" % case_name, failures)
	_assert(technique_action_count > 0, "%s fixture exposes a Technique command alongside turn actions" % case_name, failures)

	var enemy_name := view.find_child("EnemyName", true, false) as Label
	var enemy_hp := view.find_child("BattleEnemyHP", true, false) as Label
	var status := view.find_child("BattleTurnStatus", true, false) as Label
	_assert(enemy_name != null and enemy_name.get_theme_font_size("font_size") == ForbiddenThemeScript.font_size_for("heading", scale), "%s scales the enemy heading with the shared typography role" % case_name, failures)
	_assert(enemy_hp != null and enemy_hp.get_theme_font_size("font_size") == ForbiddenThemeScript.font_size_for("caption", scale), "%s scales compact enemy facts with the caption role" % case_name, failures)
	_assert(status != null and status.get_theme_font_size("font_size") == ForbiddenThemeScript.font_size_for("body", scale), "%s scales status copy with the body role" % case_name, failures)
	if draw_button != null:
		_assert(draw_button.get_theme_font_size("font_size") == ForbiddenThemeScript.font_size_for("button", scale), "%s scales action buttons with the button role" % case_name, failures)
	if hand_scroll != null:
		hand_scroll.scroll_horizontal = 0
	if action_scroll != null:
		action_scroll.scroll_vertical = 0


func _battle_controller(run_id: String, failures: Array[String]):
	var registry = ContentRegistryScript.new()
	for report in [Phase2CatalogScript.register_all(registry), AlphaActTwoCatalogScript.register_all(registry), AlphaScaleCatalogScript.register_all(registry)]:
		_assert(report.is_valid(), "test content catalogs register without errors", failures)
	var domain = RunDomainScript.new_alpha_run(run_id, 314159, registry)
	var controller = RunPresentationControllerScript.new(domain)
	var character_result = controller.confirm("character:base.character.sequence")
	_assert(character_result != null and bool(character_result.accepted), "test Run selects the real Sequence Character", failures)
	var contract_result = controller.confirm("contract:base.contract.pressure")
	_assert(contract_result != null and bool(contract_result.accepted), "test Run selects a real Contract", failures)
	var map_actions: Array = controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "MAP_NODE")
	_assert(not map_actions.is_empty(), "test Run exposes its actual starting Map action", failures)
	if map_actions.is_empty():
		return null
	var map_result = controller.confirm(str(map_actions[0].get("id", "")))
	_assert(map_result != null and bool(map_result.accepted) and domain.state.phase == RunPhaseScript.BATTLE, "test Run enters a real Battle phase", failures)
	return controller


func _replace_test_hand(battle, definition_ids: Array, suffix: String, failures: Array[String]) -> void:
	for tile in battle.zones.contents(TileZoneScript.HAND):
		_assert(battle.zones.transfer(str(tile.instance_id), TileZoneScript.HAND, TileZoneScript.DISCARD), "fixture moves the original Hand tile into Discard", failures)
	for index in definition_ids.size():
		var tile = TileInstanceScript.new("rc5.battle.%s.%02d" % [suffix, index], str(definition_ids[index]))
		_assert(battle.zones.add(tile, TileZoneScript.HAND), "fixture adds a unique physical tile to Hand", failures)


func _ids_for_definition(tiles: Array, definition_id: String) -> Array[String]:
	var result: Array[String] = []
	for tile in tiles:
		if str(tile.definition_id) == definition_id:
			result.append(str(tile.instance_id))
	return result


func _triplet_action(actions: Array, expected_ids: Array[String]) -> Dictionary:
	for action in actions:
		if not action is Dictionary or str(action.get("kind", "")) != "PARTIAL_SETTLEMENT":
			continue
		var details: Dictionary = action.get("details", {})
		if str(details.get("pattern_type", "")) != "Triplet":
			continue
		var actual_ids: Array = details.get("instance_ids", []).duplicate()
		var sorted_expected: Array = expected_ids.duplicate()
		actual_ids.sort()
		sorted_expected.sort()
		if actual_ids == sorted_expected:
			return action
	return {}


func _click_control(tree: SceneTree, control: Control, failures: Array[String]) -> void:
	var center := control.get_global_rect().get_center()
	_assert(_center_visible_with_clips(control, tree.root.get_visible_rect()), "pointer target %s is visible inside viewport and clipping ancestors" % control.name, failures)
	if not _center_visible_with_clips(control, tree.root.get_visible_rect()):
		return
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	var press := InputEventMouseButton.new()
	press.position = center
	press.global_position = center
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := InputEventMouseButton.new()
	release.position = center
	release.global_position = center
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await tree.process_frame


func _center_visible_with_clips(control: Control, viewport_rect: Rect2) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var center := control.get_global_rect().get_center()
	if not viewport_rect.has_point(center):
		return false
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var parent := ancestor as Control
			if not parent.is_visible_in_tree() or parent.clip_contents and not parent.get_global_rect().has_point(center):
				return false
		ancestor = ancestor.get_parent()
	return true


func _clip_chain_description(control: Control, viewport_rect: Rect2) -> String:
	var center := control.get_global_rect().get_center()
	var entries: Array[String] = ["viewport=%s center=%s" % [str(viewport_rect), str(center)]]
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var parent := ancestor as Control
			entries.append("%s:%s visible=%s clip=%s rect=%s contains=%s" % [parent.name, parent.get_class(), str(parent.is_visible_in_tree()), str(parent.clip_contents), str(parent.get_global_rect()), str(parent.get_global_rect().has_point(center))])
		ancestor = ancestor.get_parent()
	return " | ".join(entries)


func _fully_visible(control: Control, viewport_rect: Rect2) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var rect := control.get_global_rect()
	var visible := rect.intersection(viewport_rect)
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var parent := ancestor as Control
			if not parent.is_visible_in_tree():
				return false
			if parent.clip_contents:
				visible = visible.intersection(parent.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect.size.x > 0.0 and rect.size.y > 0.0 and visible.is_equal_approx(rect)


func _settle(tree: SceneTree, frames: int) -> void:
	for _frame in range(frames):
		await tree.process_frame


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if condition:
		return
	failures.append("ASSERTION FAILED: " + message)
	push_error("ASSERTION FAILED: " + message)
