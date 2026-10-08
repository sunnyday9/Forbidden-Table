extends RefCounted

const Scene = preload("res://scenes/run/run_scene.gd")
const Domain = preload("res://src/domain/run/run_domain.gd")
const Controller = preload("res://src/presentation/run/run_presentation_controller.gd")
const Play = preload("res://src/domain/commands/play_hand_tiles_command.gd")
const Discard = preload("res://src/domain/commands/discard_tile_command.gd")
const End = preload("res://src/domain/commands/end_turn_command.gd")
const Draw = preload("res://src/domain/commands/draw_command.gd")
const Zone = preload("res://src/domain/tiles/tile_zone.gd")
const Save = preload("res://src/infrastructure/persistence/save_mapper.gd")
const Replay = preload("res://src/infrastructure/replay/replay_verifier.gd")
const View = preload("res://src/presentation/ui/battle_view.gd")
const Sample = preload("res://src/presentation/run/guided_sample_session.gd")

var completed := false
var _sequence := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	var builder = Scene.new()
	var registry = builder._validated_content_registry().registry
	builder.free()
	var domain = _new_domain(registry, 90121)
	var battle = domain.current_battle
	var untouched: Dictionary = domain.checkpoint()
	var rejected = domain.execute(End.new(_id()))
	_check(not rejected.accepted and rejected.validation.code == "PLAY_REQUIRED" and domain.checkpoint() == untouched, "End Turn rejects zero played tiles without changing state", failures)
	var ids := _ids(battle.zones.contents(Zone.HAND))
	var invalid = domain.execute(Play.new(_id(), [ids[0], ids[0]]))
	_check(not invalid.accepted and domain.checkpoint() == untouched, "duplicate batch rejects atomically", failures)
	invalid = domain.execute(Play.new(_id(), [ids[0], "missing.tile"]))
	_check(not invalid.accepted and domain.checkpoint() == untouched, "batch with a missing tile rejects atomically", failures)
	var tp_before: int = battle.combat_state.tp
	var pressure_before: int = battle.combat_state.pressure
	var wall_before: int = battle.draw_wall.size()
	var played = domain.execute(Discard.new(_id(), ids[0]))
	_check(played.accepted and battle.combat_state.played_tile_ids_this_turn.size() == 1, "single-tile action starts the turn allowance before drawing", failures)
	_check(battle.draw_wall.size() == wall_before and battle.combat_state.tp == tp_before and battle.combat_state.pressure == pressure_before and battle.combat_state.draw_actions_used_this_turn == 0, "playing neither draws replacements nor spends Draw/TP/Pressure", failures)
	var drawn = domain.execute(Draw.new(_id()))
	_check(drawn.accepted and battle.combat_state.played_tile_ids_this_turn.size() == 1, "a normal draw does not reset the play allowance", failures)
	played = domain.execute(Play.new(_id(), [ids[1], ids[2]]))
	_check(played.accepted and battle.combat_state.played_tile_ids_this_turn.size() == 3, "separate actions share a maximum of three played tiles", failures)
	var full_turn: Dictionary = domain.checkpoint()
	invalid = domain.execute(Play.new(_id(), [_ids(battle.zones.contents(Zone.HAND))[0]]))
	_check(not invalid.accepted and invalid.validation.code == "PLAY_LIMIT" and domain.checkpoint() == full_turn, "a fourth play rejects without mutation", failures)
	var saved = Save.suspend_snapshot(domain)
	var restored: Dictionary = Save.load_into_domain(saved.serialize(), registry)
	_check(bool(restored.get("accepted", false)), "mid-turn snapshot restores", failures)
	if bool(restored.get("accepted", false)):
		_check(restored.domain.current_battle.combat_state.played_tile_ids_this_turn == battle.combat_state.played_tile_ids_this_turn, "reload preserves all three played IDs", failures)
		var restored_hand := _ids(restored.domain.current_battle.zones.contents(Zone.HAND))
		_check(not restored.domain.execute(Discard.new(_id(), restored_hand[0])).accepted, "reload cannot grant a fourth play", failures)
	var ended = domain.execute(End.new(_id()))
	_check(ended.accepted and battle.combat_state.played_tile_ids_this_turn.is_empty(), "successful End Turn resets the allowance", failures)
	_check(not domain.execute(End.new(_id())).accepted, "new turn again requires a played tile", failures)
	var factory := func(seed: int, _content_version: String): return Domain.new(domain.state.run_id, seed, registry)
	_check(Replay.verify(domain.replay_record, factory, domain.state.content_version).is_match(), "single and batch plays plus turn reset replay exactly", failures)
	for definition_ids in [["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3"], ["base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.east"], ["base.tile.characters.1", "base.tile.dots.2", "base.tile.characters.3"], ["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.4"]]:
		await _check_combo(registry, definition_ids, failures)
	await _check_combo(registry, ["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3"], failures, true)
	var empty_domain = _new_domain(registry, 90123)
	for tile in empty_domain.current_battle.zones.contents(Zone.HAND):
		empty_domain.current_battle.zones.transfer(str(tile.instance_id), Zone.HAND, Zone.DISCARD)
	_check(empty_domain.execute(End.new(_id())).accepted, "an empty Hand can end the turn without a play", failures)
	await _check_view(registry, failures)
	completed = true
	return failures

func _check_combo(registry, definitions: Array, failures: Array[String], split := false) -> void:
	var domain = _new_domain(registry, 90122)
	var battle = domain.current_battle
	var requested: Dictionary = {}
	for definition_id in definitions:
		requested[definition_id] = int(requested.get(definition_id, 0)) + 1
	for definition_id in requested:
		var copies := 0
		for tile in domain.state.tile_pool.tile_instances:
			if tile.definition_id == definition_id: copies += 1
		while copies < int(requested[definition_id]):
			var extra = load("res://src/domain/tiles/tile_instance.gd").new("rc8.fixture.copy.%d" % copies, str(definition_id))
			domain.state.tile_pool.tile_instances.append(extra)
			battle.zones.add(extra, Zone.DRAW_WALL)
			copies += 1
	for tile in battle.zones.contents(Zone.HAND):
		battle.zones.transfer(str(tile.instance_id), Zone.HAND, Zone.DISCARD)
	var used: Dictionary = {}
	var chosen: Array[String] = []
	for definition_id in definitions:
		for zone in [Zone.DISCARD, Zone.DRAW_WALL]:
			var found := false
			for tile in battle.zones.contents(zone):
				if tile.definition_id == definition_id and not used.has(tile.instance_id):
					battle.zones.transfer(str(tile.instance_id), zone, Zone.HAND)
					used[tile.instance_id] = true
					chosen.append(str(tile.instance_id))
					found = true
					break
			if found: break
	if chosen.size() != 3:
		_check(false, "combo fixture owns the requested physical copies: " + str(definitions), failures)
		return
	var expected: bool = definitions[0] == definitions[1] and definitions[1] == definitions[2] or definitions == ["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3"]
	var before_gold: int = domain.state.gold
	if split:
		var first_play = domain.execute(Play.new(_id(), [chosen[2], chosen[0]]))
		_check(first_play.accepted and domain.state.gold == before_gold, "two tiles earn no premature bonus", failures)
	var played = domain.execute(Play.new(_id(), [chosen[1]] if split else [chosen[2], chosen[0], chosen[1]]))
	_check(played.accepted and domain.state.gold == before_gold + (3 if expected else 0), "combo pays exactly once independent of input order: " + str(definitions), failures)
	var restored: Dictionary = Save.load_into_domain(Save.suspend_snapshot(domain).serialize(), registry)
	_check(bool(restored.get("accepted", false)) and restored.domain.state.gold == domain.state.gold, "paid combo and quota survive reload", failures)
	_check(battle.validate_end_turn().is_valid(), "playing all tiles does not soft-lock End Turn", failures)

func _check_view(registry, failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var session = Sample.new()
	session.start(registry)
	var controller = session.controller
	_choose(controller, "CHARACTER")
	_choose(controller, "CONTRACT")
	_choose(controller, "MAP_NODE")
	var fixture_battle = controller.domain.current_battle
	for definition_id in ["base.tile.honors.east", "base.tile.honors.south", "base.tile.honors.east"]:
		for tile in fixture_battle.zones.contents(Zone.DRAW_WALL):
			if str(tile.definition_id) == definition_id:
				var replaced = fixture_battle.zones.contents(Zone.HAND)[0]
				fixture_battle.zones.transfer(str(replaced.instance_id), Zone.HAND, Zone.DISCARD)
				fixture_battle.zones.transfer(str(tile.instance_id), Zone.DRAW_WALL, Zone.HAND)
				break
	var view = View.new()
	view.configure(controller, Callable(), Callable(), Callable())
	view.set_presentation_preferences("en", 1.0, "INSTANT", true, false)
	tree.root.add_child(view)
	view.render()
	await tree.process_frame
	var battle = controller.domain.current_battle
	var checkpoint: Dictionary = battle.checkpoint()
	var rng: Dictionary = battle.rng_snapshot()
	var command_count: int = controller.domain.replay_record.commands.size()
	var original := _ids(battle.zones.contents(Zone.HAND))
	view._on_tile_pressed(original[0])
	view._sort_hand()
	var sorted_order: Array = view._hand_order.duplicate()
	var sorted_honors: Array[String] = []
	for instance_id in sorted_order:
		var tile = battle._hand_tile(str(instance_id))
		if str(tile.definition_id).begins_with("base.tile.honors."): sorted_honors.append(str(tile.definition_id))
	_check(sorted_honors == ["base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.south"], "sorting groups identical honors despite their shared zero rank", failures)
	view._reorder_hand_tile(str(sorted_order[-1]), str(sorted_order[0]))
	_check(view._hand_order[0] == sorted_order[-1], "manual reorder inserts a tile at any position", failures)
	view._move_focused_hand_tile(1)
	var custom_order: Array = view._hand_order.duplicate()
	view.render()
	await tree.process_frame
	_check(view._hand_order == custom_order and view.selected_tile_ids().has(original[0]), "custom order and selection survive UI refresh", failures)
	_check(battle.checkpoint() == checkpoint and battle.rng_snapshot() == rng and controller.domain.replay_record.commands.size() == command_count, "sorting and ordering never change gameplay, RNG or replay", failures)
	var row = view.find_child("BattleHandTiles", true, false)
	var target = row.get_child(0)
	var source = row.get_child(row.get_child_count() - 1)
	var drag := {"kind": "hand_tile_order", "owner": view.get_instance_id(), "instance_id": source.tile_instance_id}
	_check(target._can_drop_data(Vector2.ZERO, drag), "Hand tiles accept their own reorder drag", failures)
	target._drop_data(Vector2.ZERO, drag)
	_check(view._hand_order[0] == source.tile_instance_id, "drag/drop callback changes visible order", failures)
	_check(not target._can_drop_data(Vector2.ZERO, {"kind": "hand_tile_order", "owner": -1, "instance_id": source.tile_instance_id}), "drag cannot reorder another battle or Reserve", failures)
	view.hand_play_requested.connect(func(ids): controller.play_hand_tiles(ids))
	view._on_clear_tiles()
	for id in original.slice(0, 3): view._on_tile_pressed(str(id))
	var play_button: Button = view.find_child("BattleAction_battle_play_selection", true, false)
	_check(play_button != null and not play_button.disabled, "selecting three tiles offers an explicit Play action", failures)
	if play_button != null: play_button.emit_signal("pressed")
	view.render()
	await tree.process_frame
	var discard = view.find_child("BattleZone_Discard", true, false)
	_check(discard != null and discard.find_child("ZoneTiles", true, false) == null and discard.find_child("ZoneHeading", true, false).text.contains(str(battle.zones.size(Zone.DISCARD))), "Discard displays its count without historical tile faces", failures)
	_check(battle.combat_state.played_tile_ids_this_turn.size() == 3, "batch Play button submits the serializable command", failures)
	for frame in 5: await tree.process_frame
	view.free()

func _new_domain(registry, seed: int):
	var domain = Domain.new("rc8.hand-play", seed, registry)
	var controller = Controller.new(domain)
	_choose(controller, "CHARACTER")
	_choose(controller, "CONTRACT")
	_choose(controller, "MAP_NODE")
	return domain

func _choose(controller, kind: String) -> void:
	for action in controller.action_descriptors():
		if str(action.get("kind", "")) == kind:
			if kind == "CHARACTER" and str(action.get("target_id", "")) != "base.character.sequence": continue
			controller.confirm(str(action.id))
			return

func _ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile in tiles: ids.append(str(tile.instance_id))
	return ids

func _id() -> String:
	_sequence += 1
	return "rc8.test.%d" % _sequence

func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
