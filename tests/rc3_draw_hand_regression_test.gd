class_name Rc3DrawHandRegressionTest
extends RefCounted

const GuidedSampleMapCatalogScript = preload("res://src/presentation/run/guided_sample_map_catalog.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const EndTurnCommandScript = preload("res://src/domain/commands/end_turn_command.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunSceneScript = preload("res://scenes/run/run_scene.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

const WINDOWED_SIZE := Vector2i(1280, 720)
const FULLSCREEN_SIZE := Vector2i(2512, 1432)


func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["RC3 draw-hand regression requires a SceneTree"]

	var original_window_size := tree.root.size
	tree.root.size = WINDOWED_SIZE
	var preferences = tree.root.get_node_or_null("PresentationPrefs")
	var prior_preferences: Dictionary = preferences.snapshot() if preferences != null else {}
	var prior_config_path := str(preferences.config_path) if preferences != null else ""
	_set_test_locale(preferences, "en")
	var suffix := "%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]

	await _test_normal_run(tree, preferences, suffix, failures)
	await _test_guided_sample(tree, preferences, suffix, failures)

	if preferences != null and not prior_preferences.is_empty():
		preferences.config_path = prior_config_path
		preferences.call("_apply_in_memory", prior_preferences)
	else:
		TranslationServer.set_locale("en")
	tree.root.size = original_window_size
	print("RC3_DRAW_HAND_REPORT failures=%d source=%s" % [failures.size(), ProjectSettings.get_setting("application/config/name", "Forbidden Table")])
	return failures


func _test_normal_run(tree: SceneTree, preferences, suffix: String, failures: Array[String]) -> void:
	var suspend_path := "user://rc3_draw_hand_%s_normal_suspend.json" % suffix
	var profile_path := "user://rc3_draw_hand_%s_normal_profile.json" % suffix
	var scene = _new_run_scene(tree, suspend_path, profile_path)
	await _settle(tree)
	var reached_battle := await _advance_to_battle(scene, "", failures, "normal Run")
	_assert(reached_battle, "normal Run reaches its first Battle through real Run actions", failures)
	if reached_battle:
		await _draw_and_check(scene, tree, "normal Run", failures)
	scene.queue_free()
	await _settle(tree)
	_cleanup_test_paths([suspend_path, profile_path])


func _test_guided_sample(tree: SceneTree, preferences, suffix: String, failures: Array[String]) -> void:
	_set_test_locale(preferences, "en")
	var suspend_path := "user://rc3_draw_hand_%s_sample_suspend.json" % suffix
	var profile_path := "user://rc3_draw_hand_%s_sample_profile.json" % suffix
	var scene = _new_run_scene(tree, suspend_path, profile_path)
	await _settle(tree)
	var entry := scene.find_child("GuidedSampleButton", true, false) as Button
	_assert(entry != null and entry.visible and not entry.disabled, "Run offers the Guided Sample entry", failures)
	if entry != null:
		entry.emit_signal("pressed")
	await _settle(tree)
	var active: bool = scene._guided_sample_session != null and scene._guided_sample_session.is_active()
	_assert(active, "Guided Sample starts its real isolated session", failures)
	var reached_battle := false
	if active and scene.controller != null:
		var character_ok := _accept_action(scene, "CHARACTER", "", failures, "Guided Sample")
		var contract_ok := character_ok and _accept_action(scene, "CONTRACT", "", failures, "Guided Sample")
		var map_ok := contract_ok and _accept_action(scene, "MAP_NODE", GuidedSampleMapCatalogScript.INTRO_NODE, failures, "Guided Sample")
		await _settle(tree)
		reached_battle = map_ok and str(scene.controller.domain.state.phase) == RunPhaseScript.BATTLE
	_assert(reached_battle, "Guided Sample reaches its first Battle through the real Run scene", failures)
	if reached_battle:
		await _draw_and_check(scene, tree, "Guided Sample", failures)
	_assert(not FileAccess.file_exists(suspend_path), "Guided Sample does not write campaign Suspend data", failures)
	scene.queue_free()
	await _settle(tree)
	_cleanup_test_paths([suspend_path, profile_path])


func _draw_and_check(scene, tree: SceneTree, context: String, failures: Array[String]) -> void:
	var view = scene._battle_view
	_assert(view != null and view.visible and view.is_visible_in_tree(), "%s displays the real BattleView" % context, failures)
	if view == null:
		return
	var observed_commands: Array[Dictionary] = []
	var command_observer := func(command, result) -> void:
		var kind := "DRAW" if command is DrawCommandScript else "END_TURN" if command is EndTurnCommandScript else ""
		if not kind.is_empty():
			observed_commands.append({"kind": kind, "accepted": bool(result.accepted)})
	scene.controller.command_processed.connect(command_observer)
	var initial_hand: Array = scene.controller.domain.current_battle.zones.contents(TileZoneScript.HAND)
	var initial_count := initial_hand.size()
	_assert(initial_count == 11, "%s starts with the required eleven visible Hand tiles (%d)" % [context, initial_count], failures)
	var draw_count := 0
	var turn_count := 0
	while scene.controller.domain.current_battle != null and scene.controller.domain.current_battle.zones.size(TileZoneScript.HAND) < 14 and draw_count + turn_count < 12:
		var battle = scene.controller.domain.current_battle
		var before_count: int = battle.zones.size(TileZoneScript.HAND)
		var can_draw: bool = battle.can_draw()
		var draw_control := view.action_button("battle.draw") as Button
		_assert(draw_control != null and draw_control.disabled == not can_draw, "%s Draw control enabled state matches Battle draw budget" % context, failures)
		if can_draw:
			var observed_before := observed_commands.size()
			var draw_committed := await _submit_ui_action(view, "battle.draw", context, failures)
			if not draw_committed:
				break
			var draw_result_accepted := observed_commands.size() == observed_before + 1 and str(observed_commands.back().get("kind", "")) == "DRAW" and bool(observed_commands.back().get("accepted", false))
			_assert(draw_result_accepted, "%s UI Draw submits one accepted DrawCommand" % context, failures)
			await _settle(tree)
			var after_draw: int = scene.controller.domain.current_battle.zones.size(TileZoneScript.HAND) if scene.controller.domain.current_battle != null else before_count
			if draw_result_accepted and after_draw == before_count + 1:
				draw_count += 1
				var next_battle = scene.controller.domain.current_battle
				if next_battle != null and not next_battle.can_draw():
					var exhausted_draw_control := view.action_button("battle.draw") as Button
					_assert(exhausted_draw_control != null and exhausted_draw_control.disabled, "%s exhausted Draw budget disables the visible Draw button" % context, failures)
				continue
			_assert(false, "%s accepted Draw adds one physical tile (%d -> %d)" % [context, before_count, after_draw], failures)
			break
		var observed_before_end_turn := observed_commands.size()
		if not await _submit_ui_action(view, "battle.end_turn", context, failures):
			break
		turn_count += 1
		await _settle(tree)
		var end_turn_accepted := observed_commands.size() == observed_before_end_turn + 1 and str(observed_commands.back().get("kind", "")) == "END_TURN" and bool(observed_commands.back().get("accepted", false))
		_assert(end_turn_accepted, "%s UI End Turn submits one accepted EndTurnCommand" % context, failures)
		var next_battle = scene.controller.domain.current_battle
		if next_battle != null:
			var next_can_draw: bool = next_battle.can_draw()
			var refreshed_draw_control := view.action_button("battle.draw") as Button
			_assert(refreshed_draw_control != null and refreshed_draw_control.disabled == not next_can_draw, "%s Draw enabled state refreshes after a real End Turn" % context, failures)
			if next_can_draw:
				_assert(not refreshed_draw_control.disabled, "%s accepted End Turn re-enables Draw for the next turn" % context, failures)
	_assert(draw_count == 3, "%s adds three tiles to its opening Hand through accepted Draw commands" % context, failures)
	var battle = scene.controller.domain.current_battle
	if battle == null:
		if scene.controller.command_processed.is_connected(command_observer):
			scene.controller.command_processed.disconnect(command_observer)
		return
	var hand: Array = battle.zones.contents(TileZoneScript.HAND)
	_assert(hand.size() == 14, "%s Draw produces fourteen visible physical tiles without exceeding the cap" % context, failures)
	if hand.size() == 14:
		var gated_end_turn := view.action_button("battle.end_turn") as Button
		_assert(gated_end_turn != null and gated_end_turn.disabled, "%s requires a tile play before End Turn at the Hand cap" % context, failures)
		view.tile_button(str(hand[0].instance_id)).pressed.emit()
		_assert(await _submit_ui_action(view, "battle.discard:%s" % str(hand[0].instance_id), context, failures), "%s plays one tile at the Hand cap" % context, failures)
		await _settle(tree)
		_assert(await _submit_ui_action(view, "battle.end_turn", context, failures), "%s accepts End Turn after playing from a capped Hand" % context, failures)
		await _settle(tree)
		_assert(await _submit_ui_action(view, "battle.draw", context, failures), "%s replenishes the played tile after its turn budget refreshes" % context, failures)
		await _settle(tree)
		hand = battle.zones.contents(TileZoneScript.HAND)
		var capped_draw := view.action_button("battle.draw") as Button
		_assert(capped_draw != null and capped_draw.disabled and not battle.can_draw(), "%s full Hand keeps Draw unavailable even after its turn budget refreshes" % context, failures)
	if scene.controller.command_processed.is_connected(command_observer):
		scene.controller.command_processed.disconnect(command_observer)
	var view_hand := view.find_child("BattleHandTiles", true, false) as HBoxContainer
	_assert(view_hand != null and view_hand.get_child_count() == hand.size(), "%s redraw creates one visible-control candidate for each physical Hand tile" % context, failures)
	if view_hand == null:
		if scene.controller.command_processed.is_connected(command_observer):
			scene.controller.command_processed.disconnect(command_observer)
		return

	for layout in [
		{"name": "windowed 1280x720", "size": WINDOWED_SIZE},
		{"name": "fullscreen 2512x1432", "size": FULLSCREEN_SIZE},
	]:
		tree.root.size = layout.size
		await _settle(tree)
		_assert(view.is_visible_in_tree(), "%s BattleView remains visible at %s" % [context, layout.name], failures)
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(tree.root.size))
		for tile in hand:
			var instance_id := str(tile.instance_id)
			var button := view.tile_button(instance_id) as Button
			_assert(button != null and button.get_parent() == view_hand, "%s %s places tile %s in the real Hand row" % [context, layout.name, instance_id], failures)
			if button == null:
				continue
			var face := button.get_node_or_null("TileFace") as TextureRect
			var texture := face.texture as Texture2D if face != null else null
			_assert(button.is_visible_in_tree() and not button.disabled and button.mouse_filter == Control.MOUSE_FILTER_STOP, "%s %s tile %s is visible and mouse-clickable" % [context, layout.name, instance_id], failures)
			var control_rect := button.get_global_rect()
			var face_rect := face.get_global_rect() if face != null else Rect2()
			var visible_face_rect := _visible_hand_face_rect(face, view_hand, viewport_rect) if face != null else Rect2()
			var visible_ratio := visible_face_rect.get_area() / maxf(1.0, face_rect.get_area())
			_assert(control_rect.has_area() and visible_ratio >= 0.95, "%s %s tile %s face overlaps the Hand row and survives ancestor/viewport clipping (control=%s, visible_face=%s, ratio=%.2f)" % [context, layout.name, instance_id, str(control_rect), str(visible_face_rect), visible_ratio], failures)
			_assert(texture != null and _texture_has_visible_art(texture), "%s %s tile %s has a loaded, nonblank displayed face" % [context, layout.name, instance_id], failures)

		var first_id := str(hand[0].instance_id) if not hand.is_empty() else ""
		var first_button := view.tile_button(first_id) as Button
		if first_button != null:
			var first_face := first_button.get_node_or_null("TileFace") as TextureRect
			if first_face != null:
				await _click_viewport_position(tree, first_face.get_global_rect().get_center())
			var selected: Array[String] = view.selected_tile_ids()
			_assert(selected.has(first_id) and bool(first_button.get("selected")), "%s %s viewport click selects its physical Hand instance" % [context, layout.name], failures)
			if first_face != null:
				await _click_viewport_position(tree, first_face.get_global_rect().get_center())
			_assert(not view.selected_tile_ids().has(first_id), "%s %s second tile press clears that selection" % [context, layout.name], failures)
	if scene.controller.command_processed.is_connected(command_observer):
		scene.controller.command_processed.disconnect(command_observer)


func _visible_hand_face_rect(face: Control, hand_row: Control, viewport_rect: Rect2) -> Rect2:
	var visible_rect := face.get_global_rect()
	visible_rect = visible_rect.intersection(hand_row.get_global_rect())
	visible_rect = visible_rect.intersection(viewport_rect)
	var ancestor := face.get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			visible_rect = visible_rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return visible_rect


func _click_viewport_position(tree: SceneTree, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	tree.root.push_input(motion)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.global_position = position
	press.pressed = true
	tree.root.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.global_position = position
	release.pressed = false
	tree.root.push_input(release)
	await tree.process_frame


func _submit_ui_action(view, action_id: String, context: String, failures: Array[String]) -> bool:
	var action_button := view.action_button(action_id) as Button
	if action_button == null or action_button.disabled:
		return false
	var controller = view.get("_controller")
	if controller == null:
		return false
	var command_count_before: int = controller.domain.replay_record.commands.size()
	var requested_ids: Array[String] = []
	var request_observer := func(requested_id: String) -> void: requested_ids.append(requested_id)
	view.action_requested.connect(request_observer)
	action_button.emit_signal("pressed")
	view.action_requested.disconnect(request_observer)
	var command_count_after: int = controller.domain.replay_record.commands.size()
	_assert(requested_ids == [action_id], "%s activates %s with one action request" % [context, action_id], failures)
	_assert(command_count_after == command_count_before + 1, "%s action activation records one command" % context, failures)
	_assert(view.selected_action_id.is_empty(), "%s action activation leaves no staged choice" % context, failures)
	_assert(view.commit_button() != null and not view.commit_button().is_visible_in_tree(), "%s Battle has no visible extra Commit step" % context, failures)
	return requested_ids == [action_id] and command_count_after == command_count_before + 1


func _texture_has_visible_art(texture: Texture2D) -> bool:
	var image := texture.get_image()
	if image == null or image.is_empty() or image.get_width() < 2 or image.get_height() < 2:
		return false
	var min_luma := 1.0
	var max_luma := 0.0
	var opaque_samples := 0
	for y in range(2, image.get_height() - 2, maxi(1, image.get_height() / 16)):
		for x in range(2, image.get_width() - 2, maxi(1, image.get_width() / 16)):
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.8:
				continue
			var luma := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			min_luma = minf(min_luma, luma)
			max_luma = maxf(max_luma, luma)
			opaque_samples += 1
	return opaque_samples > 4 and max_luma - min_luma > 0.12


func _new_run_scene(tree: SceneTree, suspend_path: String, profile_path: String):
	var scene = RunSceneScript.new()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	tree.root.add_child(scene)
	return scene


func _advance_to_battle(scene, target_map_node_id: String, failures: Array[String], context: String) -> bool:
	for kind in ["CHARACTER", "CONTRACT"]:
		if not _accept_action(scene, kind, "", failures, context):
			return false
	return _accept_action(scene, "MAP_NODE", target_map_node_id if not target_map_node_id.is_empty() else "*", failures, context)


func _accept_action(scene, kind: String, target_id: String, failures: Array[String], context: String) -> bool:
	if kind == "CHARACTER" and target_id.is_empty():
		target_id = "base.character.sequence"
	if scene.controller == null:
		_assert(false, "%s exposes %s before Battle" % [context, kind], failures)
		return false
	for action in scene.controller.action_descriptors():
		if not action is Dictionary or str(action.get("kind", "")) != kind:
			continue
		if target_id != "" and target_id != "*" and str(action.get("target_id", "")) != target_id:
			continue
		var result = scene._on_action_pressed(str(action.get("id", "")))
		var accepted := result != null and bool(result.accepted)
		_assert(accepted, "%s accepts %s" % [context, kind], failures)
		return accepted
	_assert(false, "%s offers a %s action" % [context, kind], failures)
	return false


func _set_test_locale(preferences, locale: String) -> void:
	if preferences != null and preferences.has_method("_apply_in_memory"):
		var values: Dictionary = preferences.snapshot()
		values["locale"] = locale
		preferences.call("_apply_in_memory", values)
	else:
		TranslationServer.set_locale(locale)


func _settle(tree: SceneTree) -> void:
	for _frame in range(5):
		await tree.process_frame


func _cleanup_test_paths(paths: Array[String]) -> void:
	for path in paths:
		for suffix in ["", ".tmp", ".bak", ".rejected"]:
			var absolute_path := ProjectSettings.globalize_path(path + suffix)
			if FileAccess.file_exists(absolute_path):
				DirAccess.remove_absolute(absolute_path)


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if condition:
		print("PASS " + message)
		return
	failures.append("ASSERTION FAILED: " + message)
	push_error("ASSERTION FAILED: " + message)
