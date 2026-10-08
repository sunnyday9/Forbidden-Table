extends SceneTree

var failures: Array[String] = []
var completed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("PACKAGED_VERSION: ", ProjectSettings.get_setting("application/config/version"))
	_check(ProjectSettings.get_setting("application/config/version") == "1.0.0-mvp.1", "packed MVP application identity")
	print("PACKAGED_USER_DIR: ", OS.get_user_data_dir())
	for resource in ["res://scenes/run/run_scene.tscn", "res://src/presentation/ui/battle_view.gd", "res://src/presentation/ui/player_action_text.gd", "res://localization/en.en.translation", "res://localization/zh_CN.zh_CN.translation"]:
		_check(ResourceLoader.exists(resource) and ResourceLoader.load(resource) != null, "packed resource loads: " + resource)
	_check(not ResourceLoader.exists("res://tests/new_player_experience_test.gd"), "regression tests excluded from the player package")
	_check(not ResourceLoader.exists("res://tests/hand_play_order_test.gd"), "new hand-play tests excluded from the player package")
	_check(ResourceLoader.load("res://src/domain/commands/play_hand_tiles_command.gd") != null, "new play command loads from package")
	var packed_scene = ResourceLoader.load("res://scenes/run/run_scene.tscn")
	if packed_scene == null:
		quit(1)
		return
	var scene = packed_scene.instantiate()
	root.add_child(scene)
	for frame in 6:
		await process_frame
	_check(scene.controller != null, "packed RunScene creates its controller")
	if scene.controller == null:
		quit(1)
		return
	for kind in ["CHARACTER", "CONTRACT", "MAP_NODE"]:
		var chosen := false
		for action in scene.controller.action_descriptors():
			if str(action.get("kind", "")) != kind:
				continue
			if kind == "CHARACTER" and str(action.get("target_id", "")) != "base.character.sequence":
				continue
			var result = scene._on_action_pressed(str(action.id))
			_check(result != null and result.accepted, "packaged start accepts " + kind)
			chosen = true
			break
		_check(chosen, "packaged start offers " + kind)
		for frame in 3:
			await process_frame
	_check(str(scene.controller.domain.state.phase) == "BATTLE", "packaged new run reaches a real battle")
	var view = scene.find_child("BattleView", true, false)
	_check(view != null and view.is_visible_in_tree(), "packed BattleView loads without fallback")
	_check(scene.find_child("PlayerGuidanceRail", true, false) != null, "packed persistent guidance rail exists")
	var helper = ResourceLoader.load("res://src/presentation/ui/player_action_text.gd")
	var effects = helper.definition_effect_lines(scene.controller.domain.content_registry, "base.technique.core.sequence_line")
	_check(not effects.is_empty(), "packed typed effect copy resolves")
	var battle = scene.controller.domain.current_battle
	_check(battle.combat_state.turn_play_enabled and view.action_button("battle.end_turn").disabled, "packed fresh battle requires a play before End Turn")
	var checkpoint: Dictionary = scene.controller.domain.checkpoint()
	var rng: Dictionary = scene.controller.domain.rng_snapshot()
	var count: int = scene.controller.domain.replay_record.commands.size()
	view.find_child("SortHandButton", true, false).pressed.emit()
	_check(scene.controller.domain.checkpoint() == checkpoint and scene.controller.domain.rng_snapshot() == rng and scene.controller.domain.replay_record.commands.size() == count, "packed sort is cosmetic")
	var hand: Array = battle.zones.contents("Hand")
	for tile in hand.slice(0, 3): view._on_tile_pressed(str(tile.instance_id))
	var play_button = view.action_button("battle.play_selection")
	_check(play_button != null and not play_button.disabled, "packed three-tile selection exposes Play")
	if play_button != null: play_button.pressed.emit()
	for frame in 4: await process_frame
	_check(battle.combat_state.played_tile_ids_this_turn.size() == 3 and scene.controller.domain.replay_record.commands.size() == count + 1, "packed Play UI submits one batch command")
	var discard = view.find_child("BattleZone_Discard", true, false)
	_check(discard != null and discard.find_child("ZoneTiles", true, false) == null and discard.find_child("ZoneHeading", true, false).text.contains("3"), "packed Discard shows count without faces")
	_check(not battle.validate_play_hand_tiles([str(hand[3].instance_id)]).is_valid(), "packed fourth play is blocked")
	_check(not view.action_button("battle.end_turn").disabled, "packed End Turn unlocks after play")
	view.action_button("battle.end_turn").pressed.emit()
	for frame in 4: await process_frame
	_check(battle.combat_state.played_tile_ids_this_turn.is_empty() and view.action_button("battle.end_turn").disabled, "packed next turn resets and requires a new play")
	completed = true
	for failure in failures:
		print("FAIL: ", failure)
	print("PACKAGED_HAND_PLAY_SMOKE: ", "PASS" if failures.is_empty() else "FAIL")
	await create_timer(1.2).timeout
	scene.free()
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
