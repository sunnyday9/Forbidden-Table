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
		var actions := view.find_child("BattleActions", true, false) as Control
		var table := view.find_child("BattleTable", true, false) as Control
		var board_surface := view.find_child("BattleBoardSurface", true, false) as Control
		var decision_surface := view.find_child("BattleDecisionSurface", true, false) as BoxContainer
		var zones := view.find_child("BattleZones", true, false) as Control
		_check(hand != null and actions != null and table != null and board_surface != null and decision_surface != null and zones != null, "Hand, contextual actions and known zones remain visible", failures)
		if hand == null or actions == null or table == null or board_surface == null or decision_surface == null or zones == null:
			continue
		var actions_rect := actions.get_global_rect()
		var board_rect := board_surface.get_global_rect()
		var wide_layout: bool = window_size.x - 20 >= 760
		_check(decision_surface.vertical == not wide_layout, "Battle reflows the table and action panel at %s" % window_size, failures)
		if wide_layout:
			_check(actions_rect.position.x >= board_rect.end.x - 1.0 and actions_rect.position.y < board_rect.end.y, "Wide Battle keeps contextual actions beside the Hand and table at %s" % window_size, failures)
		else:
			_check(actions_rect.position.y >= hand.get_global_rect().end.y - 1.0, "Narrow Battle stacks contextual actions after the Hand at %s" % window_size, failures)
		_check(table.is_ancestor_of(zones), "Reserve, Discard and Exhaust occupy the central table", failures)
		_check(hand.get_global_rect().position.x >= 0.0 and hand.get_global_rect().end.x <= window_size.x + 1.0, "Hand reflows within window width %s" % window_size, failures)
		_check(actions.get_global_rect().end.x <= window_size.x + 1.0, "Actions fit window width %s" % window_size, failures)
		if window_size.x >= 1280:
			var first_tile := hand.get_child(0) as Control
			_check(first_tile.size.x >= 63.0, "Wide windows enlarge playable tile faces", failures)
			_check(hand.get_global_rect().position.y >= window_size.y * 0.45, "The Hand sits at the player edge instead of the upper-left", failures)
	view.queue_free()
	await tree.process_frame
	tree.root.size = old_size
	return failures

func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
		push_error("ASSERTION FAILED: " + message)
