extends RefCounted

const RunSceneScript = preload("res://scenes/run/run_scene.tscn")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

var _failures: Array[String] = []
var _suspend_path := ""
var _profile_path := ""


func run() -> Array[String]:
	_failures.clear()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["RC2 journey regression requires an active SceneTree"]
	var original_window_size: Vector2i = tree.root.size
	var suffix := str(Time.get_ticks_usec())
	_suspend_path = "user://rc2_journey_%s_suspend.json" % suffix
	_profile_path = "user://rc2_journey_%s_profile.json" % suffix
	tree.root.size = Vector2i(1600, 1200)
	var scene = RunSceneScript.instantiate()
	scene.suspend_file_path = _suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new(_profile_path)
	)
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var original_preferences: Dictionary = scene._applied_preferences.duplicate(true)
	var active_controller = scene.controller
	if active_controller == null:
		_failures.append("fixture: RunScene starts with an in-memory Character selection Run")
	else:
		var saved_domain = _saved_domain(scene, suffix)
		var cases: Array[Dictionary] = [
			{"name": "tall", "size": Vector2i(1600, 1200), "tall": true, "short": false},
			{"name": "large-wide", "size": Vector2i(2560, 1440), "tall": true, "short": false},
			{"name": "fullscreen-capture", "size": Vector2i(2552, 1506), "tall": true, "short": false},
			{"name": "opening-capture", "size": Vector2i(2556, 1494), "tall": true, "short": false},
			{"name": "window", "size": Vector2i(1280, 720), "tall": false, "short": false},
			{"name": "wide", "size": Vector2i(960, 540), "tall": false, "short": false},
			{"name": "portrait", "size": Vector2i(720, 1280), "tall": true, "short": false},
			{"name": "short", "size": Vector2i(360, 240), "tall": false, "short": true},
		]
		for locale in ["en", "zh_CN"]:
			for ui_scale in [1.0, 1.25, 1.5]:
				var preferences := {
					"locale": locale,
					"ui_scale": ui_scale,
					"presentation_mode": "NORMAL",
					"reduced_motion": false,
					"ambient_glow": true,
				}
				scene._set_active_controller(active_controller)
				scene._suspend_choice_panel.visible = false
				scene._apply_presentation_preferences(preferences, true)
				for case in cases:
					tree.root.size = case["size"]
					for _frame in 4:
						await tree.process_frame
					scene._run_root_scroll.scroll_vertical = 0
					scene._journey_view.main_scroll().scroll_vertical = 0
					await tree.process_frame
					_assert_character_guidance(scene, str(case["name"]), bool(case["tall"]), float(ui_scale))
					_assert_character_semantics(scene, str(locale))
					_assert_character_composition_layout(scene, str(case["name"]), case["size"], float(ui_scale))
					if str(case["name"]) in ["wide", "portrait", "short"]:
						await _assert_character_action_reachability(scene, tree, str(case["name"]), case["size"])

					scene._set_active_controller(null)
					scene._pending_resume_domain = saved_domain
					scene._show_valid_suspend_choice(saved_domain, {}, true, "MAP_NODE")
					scene._render()
					for _frame in 4:
						await tree.process_frame
					_assert_saved_run_opening(scene, tree, str(case["name"]), case["size"], bool(case["tall"]), bool(case["short"]), float(ui_scale), str(locale))

					scene._pending_resume_domain = null
					scene._suspend_choice_panel.visible = false
					scene._set_active_controller(active_controller)
					scene._render()
					for _frame in 4:
						await tree.process_frame

		scene._apply_presentation_preferences(original_preferences, true)
		scene._pending_resume_domain = null
		scene._suspend_choice_panel.visible = false
		scene._set_active_controller(active_controller)
		scene._render()
		await _assert_retained_character_focus_on_resize(scene, tree)
		scene.queue_free()
		await tree.process_frame
	tree.root.size = original_window_size
	await _assert_focus_callback_lifetime(tree)
	await _assert_battle_scroll_routing(tree, suffix)
	_remove_user_file(_suspend_path)
	_remove_user_file(_suspend_path + ".tmp")
	_remove_user_file(_suspend_path + ".bak")
	_remove_user_file(_profile_path)
	return _failures


func _assert_retained_character_focus_on_resize(scene, tree: SceneTree) -> void:
	var original_size: Vector2i = tree.root.size
	var original_preferences: Dictionary = scene._applied_preferences.duplicate(true)
	var resize_preferences := original_preferences.duplicate(true)
	resize_preferences["locale"] = "en"
	resize_preferences["ui_scale"] = 1.0
	scene._apply_presentation_preferences(resize_preferences, true)
	var focus_target: Button = scene._journey_view.action_button("character:base.character.reserve") as Button
	var settings: Control = scene._settings_button as Control
	_assert(focus_target != null and not focus_target.disabled, "retained-focus resize fixture has a real available Character action")
	if focus_target == null or focus_target.disabled:
		scene._apply_presentation_preferences(original_preferences, true)
		tree.root.size = original_size
		return
	tree.root.size = Vector2i(960, 540)
	for _frame in 4:
		await tree.process_frame
	var root_scroll: ScrollContainer = scene._run_root_scroll as ScrollContainer
	if root_scroll != null:
		root_scroll.scroll_vertical = 0
	if settings != null and settings.is_visible_in_tree():
		settings.grab_focus()
		await tree.process_frame
	focus_target.grab_focus()
	for _frame in 4:
		await tree.process_frame
	_assert(tree.root.get_viewport().gui_get_focus_owner() == focus_target, "compact viewport focuses a Character action before resize")
	_assert(root_scroll != null and root_scroll.scroll_vertical > 0.0, "compact lower Character choice scrolls the outer page into view")
	_assert_retained_character_target_visible(scene, focus_target, Vector2i(960, 540), "960x540 before resize")
	tree.root.size = Vector2i(720, 1280)
	for _frame in 5:
		await tree.process_frame
	_assert(tree.root.get_viewport().gui_get_focus_owner() == focus_target, "viewport resize retains the focused Character action")
	_assert_retained_character_target_visible(scene, focus_target, Vector2i(720, 1280), "720x1280 after resize")
	tree.root.size = Vector2i(960, 540)
	for _frame in 5:
		await tree.process_frame
	_assert(tree.root.get_viewport().gui_get_focus_owner() == focus_target, "viewport height shrink retains the focused Character action")
	_assert(root_scroll != null and root_scroll.scroll_vertical > 0.0, "shrinking back to the compact height reveals the focused lower Character choice by scrolling")
	_assert_retained_character_target_visible(scene, focus_target, Vector2i(960, 540), "960x540 after height shrink")
	scene._apply_presentation_preferences(original_preferences, true)
	tree.root.size = original_size
	for _frame in 3:
		await tree.process_frame


func _assert_retained_character_target_visible(scene, focus_target: Control, viewport_size: Vector2i, label: String) -> void:
	var stage: Control = scene._run_columns as Control
	var root_scroll: ScrollContainer = scene._run_root_scroll as ScrollContainer
	var inner_scroll: ScrollContainer = scene._journey_view.main_scroll() as ScrollContainer
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var target_rect := focus_target.get_global_rect()
	var stage_rect := stage.get_global_rect() if stage != null else Rect2()
	var root_rect := root_scroll.get_global_rect().intersection(viewport_rect) if root_scroll != null else Rect2()
	var inner_rect := inner_scroll.get_global_rect().intersection(viewport_rect) if inner_scroll != null else Rect2()
	_assert(stage != null and stage_rect.grow(1.0).encloses(target_rect), "%s: retained focus stays inside the Character stage (%s, target %s)" % [label, stage_rect, target_rect])
	_assert(inner_scroll != null and inner_rect.grow(1.0).encloses(target_rect), "%s: retained focus stays inside the inner Character viewport (%s, target %s)" % [label, inner_rect, target_rect])
	_assert(root_scroll != null and root_rect.grow(1.0).encloses(target_rect), "%s: retained focus stays inside the visible Run page (%s, target %s, scroll %.1f)" % [label, root_rect, target_rect, root_scroll.scroll_vertical if root_scroll != null else -1.0])
	_assert(viewport_rect.grow(1.0).encloses(target_rect), "%s: retained focus stays inside the requested window" % label)


func _assert_battle_scroll_routing(tree: SceneTree, suffix: String) -> void:
	var original_window_size: Vector2i = tree.root.size
	var suspend_path := "user://rc2_journey_scroll_%s_suspend.json" % suffix
	var profile_path := "user://rc2_journey_scroll_%s_profile.json" % suffix
	tree.root.size = Vector2i(960, 540)
	var scene = RunSceneScript.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new(profile_path)
	)
	tree.root.add_child(scene)
	for _frame in 3:
		await tree.process_frame
	if scene.controller == null:
		_failures.append("scroll-routing fixture starts a real Run")
	else:
		scene._on_action_pressed("character:base.character.sequence")
		var contract_actions: Array = scene.controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "CONTRACT")
		_assert(not contract_actions.is_empty(), "scroll-routing fixture reaches Contract after the direct Sequence choice")
		if not contract_actions.is_empty():
			scene._on_action_pressed(str(contract_actions[0].get("id", "")))
		var start_node_id := str(scene.controller.domain.map_definition.start_node_id)
		scene._on_action_pressed("map:%s" % start_node_id)
		for _frame in 3:
			await tree.process_frame
		var is_battle := scene.controller != null and str(scene.controller.domain.state.phase) == RunPhaseScript.BATTLE
		_assert(is_battle, "scroll-routing fixture reaches Battle through Character, Contract, and map actions")
		var guidance: Label = scene._tutorial_prompt as Label
		_assert(guidance != null and guidance.visible and not guidance.text.strip_edges().is_empty(), "scroll-routing fixture uses the real visible tutorial prompt")
		var overview: ScrollContainer = scene._overview_scroll as ScrollContainer
		var root_scroll: ScrollContainer = scene._run_root_scroll as ScrollContainer
		_assert(overview != null and root_scroll != null, "scroll-routing fixture has both production overview and page scrolls")
		if is_battle and guidance != null and overview != null and root_scroll != null:
			tree.root.size = Vector2i(960, 240)
			for _frame in 4:
				await tree.process_frame
			var inner_bar: VScrollBar = overview.get_v_scroll_bar()
			var outer_bar: VScrollBar = root_scroll.get_v_scroll_bar()
			var inner_range := inner_bar.max_value - inner_bar.page
			var outer_range := outer_bar.max_value - outer_bar.page
			var guidance_rect := guidance.get_global_rect()
			_assert(inner_range <= 1.0, "real Battle guidance fits the inner viewport at 960x240")
			_assert(outer_range > 1.0, "real Run page has outer overflow at 960x240")
			_assert(scene._guidance_scroll.get_global_rect().grow(1.0).encloses(guidance_rect), "real Battle prompt remains within the persistent guidance viewport at 960x240")
			if inner_range <= 1.0 and outer_range > 1.0:
				root_scroll.scroll_vertical = 0
				scene._scroll_overview(1)
				_assert(root_scroll.scroll_vertical > 0, "packed RunScene scroll helper sends Down to the overflowing page when guidance fits")
				scene._scroll_overview(-1)
				_assert(root_scroll.scroll_vertical == 0, "packed RunScene scroll helper sends Up back to the page start")

			tree.root.size = Vector2i(360, 240)
			for _frame in 8:
				await tree.process_frame
			inner_bar = overview.get_v_scroll_bar()
			outer_bar = root_scroll.get_v_scroll_bar()
			inner_range = inner_bar.max_value - inner_bar.page
			_assert(inner_range <= 1.0, "normal narrow Battle guidance fits its measured inner viewport at 360x240")
			_assert(outer_bar.max_value > outer_bar.page + 1.0, "normal narrow Run page retains outer overflow at 360x240")
			if inner_range <= 1.0 and outer_bar.max_value > outer_bar.page + 1.0:
				root_scroll.scroll_vertical = 0
				overview.scroll_vertical = 0
				scene._scroll_overview(1)
				_assert(root_scroll.scroll_vertical > 0.0 and overview.scroll_vertical == 0.0, "packed RunScene sends Down to the overflowing outer page when normal guidance fits")
				scene._scroll_overview(-1)
				_assert(root_scroll.scroll_vertical == 0.0, "packed RunScene returns the outer page to its start before inner scrolling")

			# Normal content grows to its measured height and correctly scrolls with
			# the outer page. Preserve the inner-scroll routing contract using a
			# separate, explicitly clipped test fixture; this does not claim normal
			# Battle guidance should overflow at this size.
			var clipped_fixture := ScrollContainer.new()
			clipped_fixture.name = "RC2JourneyInnerScrollFixture"
			clipped_fixture.position = Vector2(8.0, 8.0)
			clipped_fixture.size = Vector2(200.0, 96.0)
			clipped_fixture.focus_mode = Control.FOCUS_ALL
			clipped_fixture.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			var fixture_content := Control.new()
			fixture_content.custom_minimum_size = Vector2(180.0, 600.0)
			clipped_fixture.add_child(fixture_content)
			scene.add_child(clipped_fixture)
			scene._overview_scroll = clipped_fixture
			overview = clipped_fixture
			await tree.process_frame
			await tree.process_frame
			inner_bar = overview.get_v_scroll_bar()
			inner_range = inner_bar.max_value - inner_bar.page
			_assert(inner_range > 1.0, "synthetic clipped guidance fixture provides a real inner-scroll range")
			if inner_range > 1.0:
				for use_controller in [false, true]:
					for _step in scene.find_children("*", "Control", true, false).size() + 1:
						if tree.root.get_viewport().gui_get_focus_owner() == overview:
							break
						scene._move_control_focus(1)
						await tree.process_frame
					_assert(tree.root.get_viewport().gui_get_focus_owner() == overview, "Tab/shoulder can focus the clipped guidance scroll fixture")
					root_scroll.scroll_vertical = 0.0
					overview.scroll_vertical = 0.0
					var outer_start := root_scroll.scroll_vertical
					scene._scroll_overview(1)
					_assert(overview.scroll_vertical > 0.0, "RunScene sends Down to an overflowing inner guidance viewport")
					_assert(root_scroll.scroll_vertical == outer_start, "inner guidance scrolling leaves outer page position unchanged")
					scene._scroll_overview(-1)
					_assert(overview.scroll_vertical == 0.0, "RunScene sends Up to inner guidance until it returns to the start")
					_assert(root_scroll.scroll_vertical == outer_start, "inner guidance Up does not move outer page position")
	if is_instance_valid(scene):
		scene.queue_free()
		await tree.process_frame
	tree.root.size = original_window_size
	_remove_user_file(suspend_path)
	_remove_user_file(suspend_path + ".tmp")
	_remove_user_file(suspend_path + ".bak")
	_remove_user_file(profile_path)


func _assert_focus_callback_lifetime(tree: SceneTree) -> void:
	var continue_fixture: Dictionary = await _new_focus_lifetime_fixture(tree, str(Time.get_ticks_usec()))
	var continue_scene = continue_fixture["scene"]
	var continue_callback := Callable(continue_scene, "_focus_suspend_choice_after_layout")
	_assert(
		tree.process_frame.is_connected(continue_callback),
		"Continue fixture schedules a one-shot focus reveal on the next frame"
	)
	continue_scene._on_resume_run_pressed()
	var focus_after_continue := tree.root.get_viewport().gui_get_focus_owner()
	_assert(
		not continue_scene._suspend_choice_panel.visible,
		"Continue closes the saved-run choice before the scheduled frame"
	)
	_assert(focus_after_continue != null, "Continue leaves keyboard focus in the resumed Run")
	await tree.process_frame
	_assert(
		tree.root.get_viewport().gui_get_focus_owner() == focus_after_continue,
		"post-layout focus reveal does not steal focus after Continue transitions into the Run"
	)
	_assert(not tree.process_frame.is_connected(continue_callback), "Continue focus callback disconnects after its one-shot frame")
	var continue_suspend_path: String = continue_fixture["suspend_path"]
	var continue_profile_path: String = continue_fixture["profile_path"]
	continue_scene.free()
	_remove_user_file(continue_suspend_path)
	_remove_user_file(continue_suspend_path + ".tmp")
	_remove_user_file(continue_suspend_path + ".bak")
	_remove_user_file(continue_profile_path)

	var new_run_fixture: Dictionary = await _new_focus_lifetime_fixture(tree, str(Time.get_ticks_usec()))
	var new_run_scene = new_run_fixture["scene"]
	var new_run_callback := Callable(new_run_scene, "_focus_suspend_choice_after_layout")
	var saved_run_id := str(new_run_scene._pending_resume_domain.state.run_id)
	new_run_scene._on_new_run_from_suspend_pressed()
	_assert(new_run_scene.controller != null, "one New Run activation starts a fresh Run before the scheduled frame")
	_assert(new_run_scene.controller == null or str(new_run_scene.controller.domain.state.run_id) != saved_run_id, "New Run does not resume the saved Run")
	_assert(not new_run_scene._suspend_choice_panel.visible, "New Run closes the saved-run choice before the scheduled frame")
	var focus_after_new_run = tree.root.get_viewport().gui_get_focus_owner()
	await tree.process_frame
	_assert(
		tree.root.get_viewport().gui_get_focus_owner() == focus_after_new_run,
		"post-layout focus reveal does not steal focus after New Run transitions"
	)
	_assert(not tree.process_frame.is_connected(new_run_callback), "New Run focus callback disconnects after its one-shot frame")
	var new_run_suspend_path: String = new_run_fixture["suspend_path"]
	var new_run_profile_path: String = new_run_fixture["profile_path"]
	new_run_scene.free()
	_remove_user_file(new_run_suspend_path)
	_remove_user_file(new_run_suspend_path + ".tmp")
	_remove_user_file(new_run_suspend_path + ".bak")
	_remove_user_file(new_run_profile_path)

	var dispose_fixture: Dictionary = await _new_focus_lifetime_fixture(tree, str(Time.get_ticks_usec()))
	var disposable_scene = dispose_fixture["scene"]
	var dispose_callback := Callable(disposable_scene, "_focus_suspend_choice_after_layout")
	_assert(
		tree.process_frame.is_connected(dispose_callback),
		"free-before-frame fixture has a one-shot owner-bound focus reveal"
	)
	var dispose_suspend_path: String = dispose_fixture["suspend_path"]
	var dispose_profile_path: String = dispose_fixture["profile_path"]
	disposable_scene.free()
	_assert(
		not tree.process_frame.is_connected(dispose_callback),
		"freeing RunScene before the next frame cancels its bound focus reveal"
	)
	await tree.process_frame
	_remove_user_file(dispose_suspend_path)
	_remove_user_file(dispose_suspend_path + ".tmp")
	_remove_user_file(dispose_suspend_path + ".bak")
	_remove_user_file(dispose_profile_path)


func _new_focus_lifetime_fixture(tree: SceneTree, suffix: String) -> Dictionary:
	var suspend_path := "user://rc2_journey_lifetime_%s_suspend.json" % suffix
	var profile_path := "user://rc2_journey_lifetime_%s_profile.json" % suffix
	var scene = RunSceneScript.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new(profile_path)
	)
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var saved_domain = _saved_domain(scene, suffix)
	scene._set_active_controller(null)
	scene._pending_resume_domain = saved_domain
	scene._show_valid_suspend_choice(saved_domain, {}, true, "MAP_NODE")
	return {"scene": scene, "suspend_path": suspend_path, "profile_path": profile_path}


func _saved_domain(scene, suffix: String):
	var domain = RunDomainScript.new_alpha_run("rc2.journey.%s" % suffix, int(suffix) % 2147483647, scene._content_registry)
	domain.execute(ChooseCharacterCommandScript.new("rc2.journey.%s.character" % suffix, "base.character.sequence"))
	domain.execute(ChooseContractCommandScript.new("rc2.journey.%s.contract" % suffix, "base.contract.pressure"))
	return domain


func _assert_character_guidance(scene, case_name: String, tall: bool, ui_scale: float) -> void:
	var viewport: Rect2 = scene.get_viewport_rect()
	var scroll: ScrollContainer = scene._overview_scroll as ScrollContainer
	var guidance: Label = scene._help_value as Label
	_assert(scroll != null and guidance != null and guidance.visible, "%s: essential Character guidance exists" % case_name)
	if scroll == null or guidance == null or not guidance.visible or not tall:
		return
	var scroll_rect := scroll.get_global_rect()
	var guidance_rect := guidance.get_global_rect()
	_assert(
		scroll_rect.grow(1.0).encloses(guidance_rect),
		"%s: Character guidance fits its reading viewport at scale %.2f (guidance y=%.1f..%.1f, viewport y=%.1f..%.1f)" % [case_name, ui_scale, guidance_rect.position.y, guidance_rect.end.y, scroll_rect.position.y, scroll_rect.end.y]
	)
	_assert(
		viewport.grow(1.0).encloses(guidance_rect),
		"%s: essential Character guidance stays inside the window at scale %.2f" % [case_name, ui_scale]
	)


func _assert_character_semantics(scene, locale: String) -> void:
	var character = scene._content_registry.resolve("base.character.sequence")
	var sequence_pool_guidance := LocalizationCatalogScript.text("UI_RUN_CHARACTER_POOL_SEQUENCE")
	var relic: String = _localized_fact_label("UI_RUN_CHARACTER_FACT_RELIC")
	var technique: String = _localized_fact_label("UI_RUN_CHARACTER_FACT_TECHNIQUE")
	var passive: String = _localized_fact_label("UI_RUN_CHARACTER_FACT_PASSIVE")
	var fact_labels: Array[String] = [relic, technique, passive]
	var card: Control = scene._journey_view.find_child("CharacterCard_Sequence", true, false) as Control
	var facts: Label = card.find_child("CharacterFacts", true, false) as Label if card != null else null
	_assert(facts != null, "%s: Character comparison card exposes its fact rows" % locale)
	if facts == null:
		return
	_assert(not sequence_pool_guidance.is_empty() and facts.text.contains(sequence_pool_guidance), "%s: Sequence card shows the exact localized 68-tile pool guidance" % locale)
	for label in fact_labels:
		_assert(not label.is_empty() and facts.text.contains(label), "%s: Character facts label %s" % [locale, label])
	for value in [
		scene._pretty_id(str(character.starting_relic_id)),
		scene._pretty_id(str(character.core_technique_id)),
		scene._pretty_id(str(character.signature_passive_id)),
	]:
		_assert(value.is_empty() or facts.text.contains(value), "%s: labeled Character fact keeps its mechanic value %s" % [locale, value])


func _localized_fact_label(key: String) -> String:
	var formatted := LocalizationCatalogScript.format(key, ["__VALUE__"])
	return formatted.replace("__VALUE__", "").strip_edges()


func _assert_character_composition_layout(scene, case_name: String, viewport_size: Vector2i, ui_scale: float) -> void:
	var status_panel: Control = scene._run_status_panel as Control
	var root_scroll: ScrollContainer = scene._run_root_scroll as ScrollContainer
	var header: Control = scene._run_header as Control
	var cards: Control = scene._journey_view.find_child("CharacterCards", true, false) as Control
	_assert(status_panel != null and root_scroll != null and header != null and cards != null, "%s: Character guidance and comparison cards exist in the Run body" % case_name)
	if status_panel == null or root_scroll == null or header == null or cards == null:
		return
	var status_rect := status_panel.get_global_rect()
	var cards_rect := cards.get_global_rect()
	var root_rect := root_scroll.get_global_rect()
	var header_rect := header.get_global_rect()
	var window_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var visible_root_rect := root_rect.intersection(window_rect)
	var actual_viewport_size: Vector2 = scene.get_viewport_rect().size
	var card_grid: GridContainer = scene._journey_view.find_child("CharacterCards", true, false) as GridContainer
	var page_rect: Rect2 = scene._page.get_global_rect()
	_assert(root_rect.size.x <= float(viewport_size.x) + 1.0, "%s: Run page scroll fits the requested viewport width %.1fpx (actual %.1fpx, scene %.1fpx, viewport %.1fpx; page %.1fpx, stage %.1fpx, limit %.1fpx, grid %.1fpx/%d cols)" % [case_name, float(viewport_size.x), root_rect.size.x, scene.size.x, actual_viewport_size.x, page_rect.size.x, scene._run_columns.size.x, scene._journey_view._content_width_limit, card_grid.size.x if card_grid != null else -1.0, card_grid.columns if card_grid != null else -1])
	var usable_left := maxf(visible_root_rect.position.x, page_rect.position.x)
	var usable_right := minf(visible_root_rect.end.x, page_rect.end.x)
	var usable_top := maxf(visible_root_rect.position.y, header_rect.end.y)
	var usable_rect := Rect2(Vector2(usable_left, usable_top), Vector2(maxf(0.0, usable_right - usable_left), maxf(0.0, visible_root_rect.end.y - usable_top)))
	var composition_top := minf(status_rect.position.y, cards_rect.position.y)
	var composition_bottom := maxf(status_rect.end.y, cards_rect.end.y)
	var composition_rect := Rect2(Vector2(minf(status_rect.position.x, cards_rect.position.x), composition_top), Vector2(maxf(status_rect.end.x, cards_rect.end.x) - minf(status_rect.position.x, cards_rect.position.x), composition_bottom - composition_top))
	var gap := maxf(0.0, cards_rect.position.y - status_rect.end.y)
	var max_width := minf(maxf(0.0, page_rect.size.x), 1500.0 * ui_scale)
	_assert(
		status_rect.size.x <= max_width + 4.0 and cards_rect.size.x <= max_width + 4.0,
		"%s: Character guidance and cards stay within the centered composition width %.1fpx (status %.1fpx, cards %.1fpx)" % [case_name, max_width, status_rect.size.x, cards_rect.size.x]
	)
	var horizontal_center_delta := absf(composition_rect.get_center().x - usable_rect.get_center().x)
	_assert(horizontal_center_delta <= maxf(24.0 * ui_scale, usable_rect.size.x * 0.04), "%s: Character guidance and cards center within the usable body horizontally (offset %.1fpx)" % [case_name, horizontal_center_delta])
	_assert(gap <= 64.0 * ui_scale, "%s: Character guidance stays close to the card row (gap %.1fpx)" % [case_name, gap])
	var card_controls: Array[Node] = cards.find_children("*", "BaseButton", true, false)
	_assert(not card_controls.is_empty(), "%s: Character card composition retains real focusable controls" % case_name)
	for control in card_controls:
		if control is Control and (control as Control).is_visible_in_tree():
			_assert(cards_rect.grow(1.0).encloses((control as Control).get_global_rect()), "%s: Character card controls remain inside the visible card row" % case_name)
	var inner_scroll: ScrollContainer = scene._journey_view.main_scroll() as ScrollContainer
	var root_bar: VScrollBar = root_scroll.get_v_scroll_bar()
	var inner_bar: VScrollBar = inner_scroll.get_v_scroll_bar() if inner_scroll != null else null
	var actual_overflow := root_bar.max_value > root_bar.page + 1.0 or (inner_bar != null and inner_bar.max_value > inner_bar.page + 1.0)
	if not actual_overflow:
		var center_delta := absf(composition_rect.get_center().y - usable_rect.get_center().y)
		_assert(
			center_delta <= maxf(48.0 * ui_scale, usable_rect.size.y * 0.06),
			"%s: guidance and cards center together in the usable body (offset %.1fpx, composition %.1fpx, body %.1fpx)" % [case_name, center_delta, composition_rect.get_center().y, usable_rect.get_center().y]
		)
	else:
		_assert(
			composition_rect.position.y <= usable_rect.position.y + 64.0 * ui_scale,
			"%s: a constrained Character composition keeps guidance at the scroll start" % case_name
		)


func _assert_character_action_reachability(scene, tree: SceneTree, case_name: String, viewport_size: Vector2i) -> void:
	var root_scroll: ScrollContainer = scene._run_root_scroll as ScrollContainer
	var inner_scroll: ScrollContainer = scene._journey_view.main_scroll() as ScrollContainer
	var stage: Control = scene._run_columns as Control
	var window_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var keyboard_start: Control = scene._settings_button as Control
	if keyboard_start != null and keyboard_start.is_visible_in_tree():
		keyboard_start.grab_focus()
		for _frame in 2:
			await tree.process_frame
	var expected_buttons: Array[Button] = []
	for action in scene.controller.action_descriptors():
		var action_id := str(action.get("id", ""))
		if not action_id.begins_with("character:"):
			continue
		var button: Button = scene._journey_view.action_button(action_id)
		if button != null and not button.disabled:
			expected_buttons.append(button)
	_assert(not expected_buttons.is_empty(), "%s: Character selection exposes available action buttons" % case_name)
	for target in expected_buttons:
		for _step in scene.find_children("*", "Control", true, false).size() + 1:
			if scene.get_viewport().gui_get_focus_owner() == target:
				break
			scene._move_control_focus(1)
			await tree.process_frame
		# RunScene schedules a bounded post-layout reveal after focus moves. Let
		# the scheduled passes and their container reflows complete before taking
		# viewport measurements, especially for wrapped 20px labels.
		for _frame in 6:
			await tree.process_frame
		var action_name := str(target.get_meta("run_action_id", target.name))
		if action_name in ["character:base.character.reserve", "character:base.character.sequence"]:
			var focused: Control = scene.get_viewport().gui_get_focus_owner() as Control
			var root_bar_probe: VScrollBar = root_scroll.get_v_scroll_bar() if root_scroll != null else null
			var inner_bar_probe: VScrollBar = inner_scroll.get_v_scroll_bar() if inner_scroll != null else null
			print("RC2_FOCUS_SETTLED case=%s action=%s focus=%s target=%s root=%s root_range=%.1f/%.1f inner=%s inner_range=%.1f/%.1f stage=%s window=%s" % [case_name, action_name, str(focused.name) if focused != null else "none", str(target.get_global_rect()), str(root_scroll.get_global_rect()) if root_scroll != null else "none", root_bar_probe.max_value if root_bar_probe != null else -1.0, root_bar_probe.page if root_bar_probe != null else -1.0, str(inner_scroll.get_global_rect()) if inner_scroll != null else "none", inner_bar_probe.max_value if inner_bar_probe != null else -1.0, inner_bar_probe.page if inner_bar_probe != null else -1.0, str(stage.get_global_rect()) if stage != null else "none", str(window_rect)])
		_assert(scene.get_viewport().gui_get_focus_owner() == target, "%s: focus navigation reaches %s" % [case_name, action_name])
		var target_rect := target.get_global_rect()
		var stage_rect := stage.get_global_rect() if stage != null else Rect2()
		var root_rect := root_scroll.get_global_rect().intersection(window_rect) if root_scroll != null else Rect2()
		var inner_rect := inner_scroll.get_global_rect() if inner_scroll != null else Rect2()
		_assert(stage != null and stage_rect.grow(1.0).encloses(target_rect), "%s: focused Character action %s stays inside stage %s (button %s)" % [case_name, action_name, stage_rect, target_rect])
		var grid: GridContainer = scene._journey_view.find_child("CharacterCards", true, false) as GridContainer
		var inner_bar := inner_scroll.get_v_scroll_bar() if inner_scroll != null else null
		var root_bar := root_scroll.get_v_scroll_bar() if root_scroll != null else null
		_assert(root_scroll != null and root_rect.grow(1.0).encloses(target_rect), "%s: focused Character action %s is revealed in Run page %s (button %s, scroll %.1f, stage %s min %.1f, grid %s min %s, inner %.1f/%.1f root %.1f/%.1f)" % [case_name, action_name, root_rect, target_rect, root_scroll.scroll_vertical if root_scroll != null else -1.0, stage_rect, stage.custom_minimum_size.y if stage != null else -1.0, grid.get_global_rect() if grid != null else Rect2(), grid.get_combined_minimum_size() if grid != null else Vector2(-1.0, -1.0), inner_bar.max_value if inner_bar != null else -1.0, inner_bar.page if inner_bar != null else -1.0, root_bar.max_value if root_bar != null else -1.0, root_bar.page if root_bar != null else -1.0])
		_assert(inner_scroll != null and inner_rect.grow(1.0).encloses(target_rect), "%s: focused Character action %s is revealed in phase viewport %s (button %s, scroll %.1f)" % [case_name, action_name, inner_rect, target_rect, inner_scroll.scroll_vertical if inner_scroll != null else -1.0])
		_assert(window_rect.grow(1.0).encloses(target_rect), "%s: focused Character action %s remains inside requested window %s (button %s)" % [case_name, action_name, window_rect, target_rect])


func _assert_saved_run_opening(scene, tree: SceneTree, case_name: String, viewport_size: Vector2i, _tall: bool, short_window: bool, ui_scale: float, locale: String) -> void:
	var viewport: Rect2 = scene.get_viewport_rect()
	var panel: Control = scene._suspend_choice_panel as Control
	var resume: Button = scene._resume_run_button as Button
	var new_run: Button = scene._new_run_from_suspend_button as Button
	var details: Button = scene._suspend_details_button as Button
	var status: Label = scene._suspend_status as Label
	var status_scroll: ScrollContainer = scene._suspend_status_scroll as ScrollContainer
	_assert(panel != null and panel.visible, "%s: a valid saved Run opens its choice card" % case_name)
	_assert(resume != null and resume.visible and not resume.disabled, "%s: Continue is the enabled primary saved-Run action" % case_name)
	_assert(status != null and status.text.contains(scene._pretty_id("base.character.sequence")), "%s: opening summary identifies the saved Character" % case_name)
	_assert(status != null and status.text.contains(scene._pretty_id("base.contract.pressure")), "%s: opening summary identifies the saved Contract" % case_name)
	_assert(status != null and status.text.contains(scene._checkpoint_label("MAP_NODE")), "%s: opening summary identifies the saved checkpoint" % case_name)
	_assert(status != null and status.text.begins_with(scene._suspend_summary_text()), "%s: saved-run summary leads the status reading area" % case_name)
	if status != null and status_scroll != null:
		var status_rect := status.get_global_rect()
		var status_viewport := status_scroll.get_global_rect()
		var status_bar: VScrollBar = status_scroll.get_v_scroll_bar()
		_assert(
			status_rect.position.y >= status_viewport.position.y - 1.0 and status_rect.end.y <= status_viewport.end.y + 1.0,
			"%s: essential saved-run summary fits the status reading viewport at scale %.2f (label %.1fpx, viewport %.1fpx)" % [case_name, ui_scale, status_rect.size.y, status_viewport.size.y]
		)
		_assert(
			status_bar == null or status_bar.max_value <= status_bar.page + 1.0,
			"%s: saved-run summary does not hide essential rows in a nested scroll at scale %.2f" % [case_name, ui_scale]
		)
	if panel == null or not panel.visible or resume == null or new_run == null or details == null:
		return
	var panel_rect := panel.get_global_rect()
	var page_rect: Rect2 = scene._page.get_global_rect()
	var maximum_card_width := 720.0 * ui_scale
	_assert(panel_rect.size.x <= maximum_card_width + 1.0, "%s: saved-Run card stays bounded to %.1fpx, actual %.1fpx" % [case_name, maximum_card_width, panel_rect.size.x])
	_assert(page_rect.grow(1.0).encloses(panel_rect), "%s: saved-Run card remains inside the responsive page" % case_name)
	_assert(resume.get_global_rect().position.y < new_run.get_global_rect().position.y, "%s: Continue appears before New Run" % case_name)
	_assert(details.get_global_rect().position.y > new_run.get_global_rect().end.y, "%s: optional technical details follow the Run actions" % case_name)
	_assert(
		tree.root.get_viewport().gui_get_focus_owner() == resume,
		"%s: Continue receives initial keyboard focus at scale %.2f (%s)" % [case_name, ui_scale, locale]
	)
	var root_scroll: ScrollContainer = scene._run_root_scroll as ScrollContainer
	_assert(root_scroll != null and root_scroll.follow_focus, "%s: opening page scroll follows keyboard focus" % case_name)
	if root_scroll != null:
		var root_width_fits := root_scroll.get_global_rect().size.x <= float(viewport_size.x) + 1.0
		_assert(root_width_fits, "%s: saved opening page scroll fits requested viewport width %.1fpx (actual %.1fpx, scene %.1fpx, viewport %.1fpx)" % [case_name, float(viewport_size.x), root_scroll.get_global_rect().size.x, scene.size.x, scene.get_viewport_rect().size.x])
		if not root_width_fits:
			var chrome := scene.find_child("RunWindowChrome", true, false) as Control
			var margin := scene._run_body_margin as Control
			var page := scene._page as Control
			var slot := scene._suspend_choice_slot as Control
			var card := scene._suspend_choice_panel as Control
			print("RC2_OPENING_WIDTH case=%s locale=%s scale=%.2f viewport=%s scene=%s chrome=%s chrome_min=%s root=%s root_min=%s root_combined=%s root_scrollbar=%s margin=%s margin_min=%s page=%s page_min=%s slot=%s slot_combined=%s card=%s card_custom=%s card_combined=%s" % [case_name, locale, ui_scale, str(viewport_size), str(scene.get_global_rect()), str(chrome.get_global_rect()) if chrome != null else "none", str(chrome.get_combined_minimum_size()) if chrome != null else "none", str(root_scroll.get_global_rect()), str(root_scroll.custom_minimum_size), str(root_scroll.get_combined_minimum_size()), str(root_scroll.get_v_scroll_bar().get_combined_minimum_size()), str(margin.get_global_rect()) if margin != null else "none", str(margin.get_combined_minimum_size()) if margin != null else "none", str(page.get_global_rect()) if page != null else "none", str(page.get_combined_minimum_size()) if page != null else "none", str(slot.get_global_rect()) if slot != null else "none", str(slot.get_combined_minimum_size()) if slot != null else "none", str(card.get_global_rect()) if card != null else "none", str(card.custom_minimum_size) if card != null else "none", str(card.get_combined_minimum_size()) if card != null else "none"])
	var header: Control = scene._run_header as Control
	if root_scroll != null and header != null and panel != null:
		var root_rect := root_scroll.get_global_rect().intersection(Rect2(Vector2.ZERO, Vector2(viewport_size)))
		var header_rect := header.get_global_rect()
		var usable_top := maxf(root_rect.position.y, header_rect.end.y)
		var usable_rect := Rect2(Vector2(root_rect.position.x, usable_top), Vector2(root_rect.size.x, maxf(0.0, root_rect.end.y - usable_top)))
		var panel_rect_centered := panel.get_global_rect()
		var root_bar: VScrollBar = root_scroll.get_v_scroll_bar()
		if root_bar.max_value <= root_bar.page + 1.0:
			var center_delta := absf(panel_rect_centered.get_center().y - usable_rect.get_center().y)
			_assert(
				center_delta <= maxf(48.0 * ui_scale, usable_rect.size.y * 0.06),
				"%s: saved-Run card centers within usable body (offset %.1fpx, card %.1fpx, body %.1fpx)" % [case_name, center_delta, panel_rect_centered.get_center().y, usable_rect.get_center().y]
			)
		else:
			_assert(
				panel_rect_centered.position.y <= usable_rect.position.y + 64.0 * ui_scale,
				"%s: constrained saved-Run opening stays top-fit for scrolling" % case_name
			)
	if short_window and root_scroll != null:
		var scrollbar: VScrollBar = root_scroll.get_v_scroll_bar()
		_assert(scrollbar != null and scrollbar.max_value > scrollbar.page, "%s: a short opening page remains vertically scrollable" % case_name)
		_assert(
			root_scroll.get_global_rect().intersection(Rect2(Vector2.ZERO, Vector2(viewport_size))).grow(1.0).encloses(resume.get_global_rect()),
			"%s: focused Continue remains reachable inside the short-window scroll viewport" % case_name
		)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _remove_user_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
