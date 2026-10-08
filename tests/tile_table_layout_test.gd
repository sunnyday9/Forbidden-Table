extends RefCounted

const Fixture = preload("res://tests/stage45_battle_ui_test.gd")
const BattleViewScript = preload("res://src/presentation/ui/battle_view.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	var old_size := tree.root.size
	var fixture = Fixture.new()
	var controller = fixture._battle_controller("tile.table.layout", failures)
	fixture._replace_test_hand(controller.domain.current_battle, [
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3",
		"base.tile.characters.4", "base.tile.characters.5", "base.tile.characters.6",
		"base.tile.characters.7", "base.tile.characters.7",
	], "responsive-fourteen", failures)
	var view = BattleViewScript.new()
	view.set_external_preferences_owner()
	view.configure(controller, func(action): return str(action.kind), func(action): return str(action.kind), func(action): return str(action.kind))
	tree.root.add_child(view)
	for window_size in [Vector2i(1280, 800), Vector2i(2560, 1080), Vector2i(360, 640), Vector2i(600, 480)]:
		tree.root.size = window_size
		view.render()
		for frame in range(5):
			await tree.process_frame
		var hand := view.find_child("BattleHandTiles", true, false) as Control
		var hand_surface := view.find_child("BattleHandSurface", true, false) as Control
		var hand_scroll := view.find_child("BattleHandScroll", true, false) as ScrollContainer
		var actions := view.find_child("BattleActions", true, false) as Control
		var table := view.find_child("BattleTable", true, false) as Control
		var board_surface := view.find_child("BattleBoardSurface", true, false) as Control
		var decision_surface := view.find_child("BattleDecisionSurface", true, false) as BoxContainer
		var zones := view.find_child("BattleZones", true, false) as Control
		var action_scroll := view.find_child("BattleChoiceScroll", true, false) as ScrollContainer
		_check(hand != null and hand_surface != null and hand_scroll != null and actions != null and table != null and board_surface != null and decision_surface != null and zones != null and action_scroll != null, "Hand, contextual actions and known zones remain available", failures)
		if hand == null or hand_surface == null or hand_scroll == null or actions == null or table == null or board_surface == null or decision_surface == null or zones == null or action_scroll == null:
			continue
		var actions_rect := actions.get_global_rect()
		var hand_surface_rect := hand_surface.get_global_rect()
		var board_rect := board_surface.get_global_rect()
		_check(decision_surface.vertical, "Battle keeps one play column at %s" % window_size, failures)
		_check(board_rect.position.y < actions_rect.position.y and actions_rect.end.y <= hand_surface_rect.position.y + 2.0, "Board, full-width action bar and pinned Hand stay in that order at %s" % window_size, failures)
		_check(absf(actions_rect.position.x - hand_surface_rect.position.x) <= 2.0 and absf(actions_rect.size.x - hand_surface_rect.size.x) <= 2.0, "BattleActions spans the Hand width instead of occupying a right column at %s" % window_size, failures)
		_check(table.is_ancestor_of(zones), "Reserve, Discard and Exhaust occupy the central table", failures)
		_check(_inside_visible_clip(hand_scroll, Rect2(Vector2.ZERO, Vector2(window_size))), "Hand tray stays inside viewport at %s" % window_size, failures)
		_check(actions_rect.position.x >= 0.0 and actions_rect.end.x <= window_size.x + 1.0, "Actions fit window width %s" % window_size, failures)
		_check(hand is HBoxContainer and hand.get_child_count() == 14, "All fourteen physical tiles stay in one horizontally scrollable hand row at %s" % window_size, failures)
		_check(action_scroll.get_child_count() == 1 and view.action_button("battle.draw") != null and view.action_button("battle.end_turn") != null, "Draw and End Turn remain reachable from the action scroll at %s" % window_size, failures)
		if hand is HBoxContainer and hand.get_child_count() > 1:
			hand_scroll.scroll_horizontal = 0
			await tree.process_frame
			_check(_inside_visible_clip(hand.get_child(0) as Control, Rect2(Vector2.ZERO, Vector2(window_size))), "First Hand tile can be brought into the visible tray at %s" % window_size, failures)
			hand_scroll.scroll_horizontal = int(hand_scroll.get_h_scroll_bar().max_value)
			await tree.process_frame
			_check(_inside_visible_clip(hand.get_child(hand.get_child_count() - 1) as Control, Rect2(Vector2.ZERO, Vector2(window_size))), "Last Hand tile can be brought into the visible tray at %s" % window_size, failures)
		if window_size.x >= 1280:
			var first_tile := hand.get_child(0) as Control
			_check(first_tile.size.x >= 63.0, "Wide windows enlarge playable tile faces", failures)
			_check(hand_surface_rect.end.y >= window_size.y * 0.70, "The Hand remains at the bottom player edge instead of the upper-left", failures)
	view.queue_free()
	await tree.process_frame
	tree.root.size = old_size
	return failures

func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
		push_error("ASSERTION FAILED: " + message)

func _inside_visible_clip(control: Control, viewport: Rect2) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var rect := control.get_global_rect()
	var visible := rect.intersection(viewport)
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
