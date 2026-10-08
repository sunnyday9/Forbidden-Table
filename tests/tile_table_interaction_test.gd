extends RefCounted

const Fixture = preload("res://tests/stage45_battle_ui_test.gd")
const BattleViewScript = preload("res://src/presentation/ui/battle_view.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	var previous_size := tree.root.size
	tree.root.size = Vector2i(1280, 800)
	TranslationServer.set_locale("en")
	var fixture = Fixture.new()
	var controller = fixture._battle_controller("tile.table.interaction", failures)
	if controller == null:
		tree.root.size = previous_size
		return failures
	var view = BattleViewScript.new()
	view.set_external_preferences_owner()
	view.configure(controller, func(action): return str(action.kind), func(action): return str(action.kind), func(action): return str(action.kind))
	var action_results: Array[bool] = []
	view.action_requested.connect(func(action_id: String) -> void:
		var result = controller.confirm(action_id)
		action_results.append(result != null and bool(result.accepted))
	)
	controller.presentation_changed.connect(func() -> void: view.render())
	tree.root.add_child(view)
	controller.confirm("battle.draw")
	view.render()
	for frame in range(3):
		await tree.process_frame
	var hand: Array = controller.domain.current_battle.zones.contents("Hand")
	var chosen_id := str(hand[0].instance_id)
	var chosen = view.tile_button(chosen_id)
	var checkpoint: Dictionary = controller.domain.checkpoint()
	var command_count: int = controller.domain.replay_record.commands.size()
	chosen.pressed.emit()
	_check(chosen.selected, "Pressing a physical Hand tile selects and highlights that copy", failures)
	_check(controller.domain.checkpoint() == checkpoint and controller.domain.replay_record.commands.size() == command_count, "Tile selection changes no gameplay state or replay command", failures)
	for action in controller.action_descriptors():
		if str(action.kind) == "RESERVE":
			var button = view.action_button(str(action.id))
			if str(action.target_id) == chosen_id:
				_check(button != null, "Chosen tile exposes its own legal Reserve button", failures)
			else:
				_check(button == null, "An unselected physical copy does not expose a Reserve button", failures)
	_check(view.selected_tile_ids() == [chosen_id], "Selection reports the exact chosen copy", failures)
	var reserve_id := "battle.store:" + chosen_id
	var reserve_button: Button = view.action_button(reserve_id)
	_check(reserve_button != null, "A legal Reserve action appears after Draw and tile selection", failures)
	if reserve_button != null:
		view.cancel()
		_check(view.selected_tile_ids().is_empty(), "Cancel clears a Hand tile selection without executing its action", failures)
		_check(controller.domain.checkpoint() == checkpoint, "Cancelling tile selection leaves gameplay unchanged", failures)
		chosen = view.tile_button(chosen_id)
		chosen.pressed.emit()
		reserve_button = view.action_button(reserve_id)
		_check(reserve_button != null, "Reselecting the same physical tile restores its Reserve action", failures)
		var requests: Array[String] = []
		view.action_requested.connect(func(id: String) -> void: requests.append(id))
		if reserve_button != null:
			reserve_button.pressed.emit()
		_check(requests == [reserve_id] and action_results == [true], "One direct Reserve press emits one accepted action request", failures)
		_check(controller.domain.replay_record.commands.size() == command_count + 1 and controller.domain.checkpoint() != checkpoint, "The Reserve action executes immediately and records one command", failures)
		_check(controller.domain.current_battle.zones.contents("Reserve").any(func(tile): return str(tile.instance_id) == chosen_id), "The accepted action moves the exact selected copy into Reserve", failures)
		_check(view.selected_tile_ids().is_empty(), "Accepted action clears the stale Hand selection", failures)
		_check(view.commit_button() != null and not view.commit_button().is_visible_in_tree(), "Battle has no visible second Commit step", failures)
		var after_action_checkpoint: Dictionary = controller.domain.checkpoint()
		var after_action_command_count: int = controller.domain.replay_record.commands.size()
		view.set_presentation_preferences("zh_CN", 1.5, "INSTANT", true)
		view.render()
		_check(view.selected_tile_ids().is_empty() and view.selected_action_id.is_empty(), "Locale and motion refresh leave no staged action or stale tile selection", failures)
		_check(controller.domain.checkpoint() == after_action_checkpoint and controller.domain.replay_record.commands.size() == after_action_command_count, "Locale refresh preserves the authoritative post-action state", failures)
		for resized_size in [Vector2i(360, 900), Vector2i(1920, 1080)]:
			tree.root.size = resized_size
			for frame in range(4):
				await tree.process_frame
			_check(view.selected_tile_ids().is_empty() and view.selected_action_id.is_empty(), "Live window resize preserves the cleared selection state", failures)
			_check(controller.domain.checkpoint() == after_action_checkpoint and controller.domain.replay_record.commands.size() == after_action_command_count, "Live resizing changes no gameplay state", failures)
	_check(controller.domain.replay_record.commands.size() == command_count + 1, "Tile selection and cancellation are inert while direct action adds exactly one command", failures)
	TranslationServer.set_locale("en")
	view.queue_free()
	await tree.process_frame
	tree.root.size = previous_size
	return failures

func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
