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
		reserve_button.pressed.emit()
		_check(controller.domain.checkpoint() == checkpoint, "Choosing the contextual action leaves gameplay unchanged", failures)
		_check(not view.commit_button().disabled, "Only a pending legal action enables Commit", failures)
		view.set_presentation_preferences("zh_CN", 1.5, "INSTANT", true)
		view.render()
		_check(view.selected_tile_ids() == [chosen_id] and view.selected_action_id == reserve_id, "Locale and motion refresh preserve physical and action selection", failures)
		for resized_size in [Vector2i(360, 900), Vector2i(1920, 1080)]:
			tree.root.size = resized_size
			for frame in range(4):
				await tree.process_frame
			_check(view.selected_tile_ids() == [chosen_id] and view.selected_action_id == reserve_id, "Live window resize preserves the pending physical tile and action", failures)
			_check(controller.domain.checkpoint() == checkpoint, "Live resizing changes no gameplay state", failures)
		var requests: Array[String] = []
		view.action_requested.connect(func(id): requests.append(id))
		view.commit_button().pressed.emit()
		_check(requests == [reserve_id], "Commit emits exactly the selected stable action ID", failures)
		view.cancel()
		_check(view.selected_tile_ids().is_empty() and view.commit_button().disabled, "Cancel clears tiles and pending action without committing", failures)
	_check(controller.domain.checkpoint() == checkpoint and controller.domain.replay_record.commands.size() == command_count, "Selection, preferences and cancellation issue no authoritative command", failures)
	TranslationServer.set_locale("en")
	view.queue_free()
	await tree.process_frame
	tree.root.size = previous_size
	return failures

func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
