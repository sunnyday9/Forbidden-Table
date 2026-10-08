class_name DiscardCapacityRulesTest
extends RefCounted

const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const SelectMapNodeCommandScript = preload("res://src/domain/commands/select_map_node_command.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const EndTurnCommandScript = preload("res://src/domain/commands/end_turn_command.gd")
const DiscardTileCommandScript = preload("res://src/domain/commands/discard_tile_command.gd")
const StoreTileCommandScript = preload("res://src/domain/commands/store_tile_command.gd")
const SwapReserveTileCommandScript = preload("res://src/domain/commands/swap_reserve_tile_command.gd")
const SaveCoordinatorScript = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_full_hand_turn_start_discard_is_free_and_waits_for_fresh_draw(failures)
	test_reserve_swap_does_not_consume_normal_discard(failures)
	test_capacity_discard_state_saves_and_legacy_checkpoint_defaults_false(failures)
	test_draw_budget_and_normal_discard_allowance_restore_together(failures)
	return failures

func test_full_hand_turn_start_discard_is_free_and_waits_for_fresh_draw(failures: Array[String]) -> void:
	var domain: RunDomainScript = _new_battle("turn-start-escape", 90101)
	if domain == null or domain.current_battle == null:
		assert_true(false, "the full-Hand fixture enters a normal battle", failures)
		return
	var battle = domain.current_battle
	battle.combat_state.draw_capacity = 8
	battle.combat_state.enemy_hp = 999
	battle.combat_state.pressure_limit = 999
	for draw_index in range(3):
		var draw_result = domain.execute(DrawCommandScript.new("rc7.turn-start.draw.%d" % draw_index))
		assert_true(draw_result.accepted, "a normal Draw fills one opening Hand slot", failures)
	if battle.zones.size(TileZoneScript.HAND) != 14:
		assert_true(false, "three accepted Draw commands fill the Hand to fourteen", failures)
		return
	var ended = domain.execute(EndTurnCommandScript.new("rc7.turn-start.end"))
	assert_true(ended.accepted, "the full-Hand player can end the turn", failures)
	assert_true(battle.combat_state.draw_actions_used_this_turn == 0, "a fresh turn resets the normal Draw Action budget", failures)
	assert_true(battle.zones.size(TileZoneScript.HAND) == 14, "End Turn preserves all fourteen Hand tiles", failures)

	var selected_id: String = str(battle.zones.contents(TileZoneScript.HAND)[0].instance_id)
	var before_tp: int = battle.combat_state.tp
	var before_pressure: int = battle.combat_state.pressure
	var before_fatigue: int = battle.combat_state.fatigue
	var before_starvation: int = battle.combat_state.starvation_count
	var before_draw_budget: int = battle.combat_state.draw_actions_remaining()
	var before_wall_size: int = battle.draw_wall.size()
	var escape = domain.execute(DiscardTileCommandScript.new("rc7.turn-start.capacity-discard", selected_id))
	assert_true(escape.accepted, "a full Hand has one legal Discard escape before the next Draw", failures)
	if escape.accepted:
		assert_true(battle.zones.size(TileZoneScript.HAND) == 13 and battle.zones.size(TileZoneScript.DISCARD) == 1, "the escape moves exactly the selected physical tile to Discard", failures)
		assert_true(battle.combat_state.draw_actions_used_this_turn == 0 and battle.combat_state.draw_actions_remaining() == before_draw_budget, "Discard grants no Draw Action and spends none", failures)
		assert_true(battle.draw_wall.size() == before_wall_size, "Discard does not consume or reorder a hidden Draw Wall tile", failures)
		assert_true(battle.combat_state.tp == before_tp and battle.combat_state.pressure == before_pressure, "Discard does not grant TP or change Pressure", failures)
		assert_true(battle.combat_state.fatigue == before_fatigue and battle.combat_state.starvation_count == before_starvation, "Discard does not trigger Fatigue or Starvation", failures)
		assert_true(bool(battle.checkpoint().combat_state.get("discard_action_used_since_draw", false)), "the accepted full-Hand escape records its discard allowance until a fresh Draw", failures)

	var second_id: String = str(battle.zones.contents(TileZoneScript.HAND)[0].instance_id)
	var second_without_draw = domain.execute(DiscardTileCommandScript.new("rc7.turn-start.second-discard", second_id))
	assert_true(not second_without_draw.accepted and second_without_draw.validation.code == "DRAW_ACTION_NOT_STARTED", "a second non-capacity Discard cannot occur before a fresh Draw", failures)
	var refreshed = domain.execute(DrawCommandScript.new("rc7.turn-start.fresh-draw"))
	assert_true(refreshed.accepted and battle.zones.size(TileZoneScript.HAND) == 14, "one fresh Draw restores capacity and refreshes discard eligibility", failures)
	if refreshed.accepted:
		var repeated_id: String = str(battle.zones.contents(TileZoneScript.HAND)[0].instance_id)
		var repeated = domain.execute(DiscardTileCommandScript.new("rc7.turn-start.repeated-capacity-discard", repeated_id))
		assert_true(repeated.accepted and battle.zones.size(TileZoneScript.HAND) == 13, "another fourteen-to-thirteen escape is legal after the fresh Draw", failures)
		var duplicate_id: String = str(battle.zones.contents(TileZoneScript.HAND)[0].instance_id)
		var duplicate = domain.execute(DiscardTileCommandScript.new("rc7.turn-start.duplicate-discard", duplicate_id))
		assert_true(not duplicate.accepted and duplicate.validation.code == "DISCARD_ALREADY_USED_SINCE_DRAW", "only one normal Discard is allowed after that Draw", failures)

func test_reserve_swap_does_not_consume_normal_discard(failures: Array[String]) -> void:
	var domain: RunDomainScript = _new_battle("swap-then-discard", 90102)
	if domain == null or domain.current_battle == null:
		assert_true(false, "the Reserve fixture enters a normal battle", failures)
		return
	var battle = domain.current_battle
	battle.combat_state.enemy_hp = 999
	var first_draw = domain.execute(DrawCommandScript.new("rc7.swap.first-draw"))
	assert_true(first_draw.accepted, "the first Draw opens the Reserve manipulation window", failures)
	if not first_draw.accepted:
		return
	var stored_id: String = str(battle.zones.contents(TileZoneScript.HAND)[0].instance_id)
	var stored = domain.execute(StoreTileCommandScript.new("rc7.swap.store", stored_id))
	assert_true(stored.accepted, "a Hand tile can be stored in Reserve", failures)
	if not stored.accepted:
		return
	var next_draw = domain.execute(DrawCommandScript.new("rc7.swap.second-draw"))
	assert_true(next_draw.accepted, "a fresh normal Draw opens the next manipulation window", failures)
	if not next_draw.accepted:
		return
	var hand_id: String = str(battle.zones.contents(TileZoneScript.HAND)[0].instance_id)
	var reserve_id: String = str(battle.zones.contents(TileZoneScript.RESERVE)[0].instance_id)
	var swapped = domain.execute(SwapReserveTileCommandScript.new("rc7.swap.swap", hand_id, reserve_id))
	assert_true(swapped.accepted and battle.combat_state.tile_manipulation_used_this_draw, "Reserve Swap consumes its own one-operation-per-Draw allowance", failures)
	if not swapped.accepted:
		return
	var discard_id := ""
	for tile in battle.zones.contents(TileZoneScript.HAND):
		if str(tile.instance_id) != reserve_id:
			discard_id = str(tile.instance_id)
			break
	assert_true(not discard_id.is_empty(), "the swap leaves a distinct Hand TileInstance available for Discard", failures)
	if discard_id.is_empty():
		return
	var before_draws: int = battle.combat_state.draw_actions_used_this_turn
	var discarded = domain.execute(DiscardTileCommandScript.new("rc7.swap.then-discard", discard_id))
	assert_true(discarded.accepted, "Discard remains available after a Reserve Swap on the same normal Draw", failures)
	if discarded.accepted:
		assert_true(battle.combat_state.tile_manipulation_used_this_draw, "Discard does not clear or rewrite the separate Reserve manipulation allowance", failures)
		assert_true(battle.combat_state.draw_actions_used_this_turn == before_draws, "Reserve Swap followed by Discard spends no additional Draw Action", failures)
		assert_true(battle.zones.contains_in_zone(discard_id, TileZoneScript.DISCARD), "the selected Hand instance reaches Discard through the real command seam", failures)

func test_capacity_discard_state_saves_and_legacy_checkpoint_defaults_false(failures: Array[String]) -> void:
	var domain: RunDomainScript = _new_battle("capacity-save", 90103)
	if domain == null or domain.current_battle == null:
		assert_true(false, "the persistence fixture enters a normal battle", failures)
		return
	var battle = domain.current_battle
	battle.combat_state.draw_capacity = 8
	battle.combat_state.enemy_hp = 999
	for draw_index in range(3):
		var draw_result = domain.execute(DrawCommandScript.new("rc7.save.draw.%d" % draw_index))
		assert_true(draw_result.accepted, "the persistence fixture fills its Hand with normal Draws", failures)
	var end_turn = domain.execute(EndTurnCommandScript.new("rc7.save.end-turn"))
	assert_true(end_turn.accepted, "the full Hand reaches the next turn before save", failures)
	if not end_turn.accepted:
		return
	var first_id: String = str(battle.zones.contents(TileZoneScript.HAND)[0].instance_id)
	var escape = domain.execute(DiscardTileCommandScript.new("rc7.save.capacity-discard", first_id))
	assert_true(escape.accepted, "the save fixture uses the full-Hand capacity escape", failures)
	if not escape.accepted:
		return
	var saved_checkpoint: Dictionary = battle.checkpoint()
	assert_true(bool(saved_checkpoint.combat_state.get("discard_action_used_since_draw", false)), "the Battle checkpoint serializes the discard allowance", failures)
	var saved = SaveCoordinatorScript.new().save(domain)
	assert_true(saved.get("accepted", false), "the active Battle with a used capacity escape saves at a stable boundary", failures)
	if not saved.get("accepted", false):
		return
	var loaded = SaveMapperScript.load_into_domain(saved.snapshot.to_dictionary(), _registry())
	assert_true(loaded.get("accepted", false), "the saved discard allowance hydrates through the public save pipeline", failures)
	if not loaded.get("accepted", false):
		return
	var loaded_battle = loaded.domain.current_battle
	assert_true(loaded_battle.checkpoint() == saved_checkpoint, "resume preserves the exact discard-use checkpoint state", failures)
	assert_true(loaded_battle.combat_state.draw_actions_used_this_turn == 0, "the capacity-escape save preserves the unused normal Draw budget", failures)
	var filler = loaded_battle.zones.contents(TileZoneScript.DRAW_WALL)[0]
	assert_true(loaded_battle.zones.transfer(str(filler.instance_id), TileZoneScript.DRAW_WALL, TileZoneScript.HAND), "the fixture restores a full visible Hand without a normal Draw", failures)
	var blocked_id: String = str(loaded_battle.zones.contents(TileZoneScript.HAND)[0].instance_id)
	var blocked = loaded.domain.execute(DiscardTileCommandScript.new("rc7.save.blocked.second-capacity-discard", blocked_id))
	assert_true(not blocked.accepted and blocked.validation.code == "CAPACITY_DISCARD_ALREADY_USED", "restored state blocks a second full-Hand escape before a fresh Draw", failures)

	var legacy_checkpoint: Dictionary = loaded_battle.checkpoint()
	var legacy_combat_state: Dictionary = legacy_checkpoint.get("combat_state", {}).duplicate(true)
	legacy_combat_state.erase("discard_action_used_since_draw")
	legacy_checkpoint["combat_state"] = legacy_combat_state
	assert_true(loaded_battle.restore_checkpoint(legacy_checkpoint), "a legacy Battle checkpoint without the optional discard field remains restorable", failures)
	var reserialized_legacy_checkpoint: Dictionary = loaded_battle.checkpoint()
	assert_true(not reserialized_legacy_checkpoint.get("combat_state", {}).has("discard_action_used_since_draw"), "a false default stays absent when a legacy Battle checkpoint is re-serialized", failures)
	var legacy_discard_id: String = str(loaded_battle.zones.contents(TileZoneScript.HAND)[0].instance_id)
	var legacy_discard = loaded.domain.execute(DiscardTileCommandScript.new("rc7.save.legacy-default", legacy_discard_id))
	assert_true(legacy_discard.accepted, "a missing legacy discard field defaults to an unused allowance", failures)
	assert_true(bool(loaded_battle.checkpoint().get("combat_state", {}).get("discard_action_used_since_draw", false)), "a successful Discard adds the optional field after legacy hydration", failures)

func test_draw_budget_and_normal_discard_allowance_restore_together(failures: Array[String]) -> void:
	var domain: RunDomainScript = _new_battle("draw-budget-save", 90104)
	if domain == null or domain.current_battle == null:
		assert_true(false, "the Draw-budget restore fixture enters a normal battle", failures)
		return
	var battle = domain.current_battle
	battle.combat_state.enemy_hp = 999
	var draw = domain.execute(DrawCommandScript.new("rc7.budget.draw"))
	assert_true(draw.accepted, "the budget fixture spends one real normal Draw Action", failures)
	if not draw.accepted:
		return
	var selected_id: String = str(battle.zones.contents(TileZoneScript.HAND)[0].instance_id)
	var discard = domain.execute(DiscardTileCommandScript.new("rc7.budget.discard", selected_id))
	assert_true(discard.accepted, "a normal Discard is available after that Draw", failures)
	if not discard.accepted:
		return
	var expected_used_draws: int = battle.combat_state.draw_actions_used_this_turn
	var expected_remaining_draws: int = battle.combat_state.draw_actions_remaining()
	var saved = SaveCoordinatorScript.new().save(domain)
	assert_true(saved.get("accepted", false), "the used Draw and Discard allowances save together", failures)
	if not saved.get("accepted", false):
		return
	var loaded = SaveMapperScript.load_into_domain(saved.snapshot.to_dictionary(), _registry())
	assert_true(loaded.get("accepted", false), "the used Draw and Discard allowances hydrate together", failures)
	if not loaded.get("accepted", false):
		return
	var restored = loaded.domain.current_battle
	assert_true(restored.combat_state.draw_actions_used_this_turn == expected_used_draws, "resume restores the exact normal Draw Actions already spent this turn", failures)
	assert_true(restored.combat_state.draw_actions_remaining() == expected_remaining_draws, "resume restores the remaining normal Draw budget", failures)
	assert_true(restored.combat_state.discard_action_used_since_draw, "resume restores the one-Discard-per-fresh-Draw allowance", failures)
	var next_hand_id: String = str(restored.zones.contents(TileZoneScript.HAND)[0].instance_id)
	var duplicate = loaded.domain.execute(DiscardTileCommandScript.new("rc7.budget.duplicate", next_hand_id))
	assert_true(not duplicate.accepted and duplicate.validation.code == "DISCARD_ALREADY_USED_SINCE_DRAW", "a restored normal Discard cannot be repeated before another Draw", failures)

func _new_battle(suffix: String, seed: int) -> RunDomainScript:
	var registry = _registry()
	var domain = RunDomainScript.new("rc7.discard.%s" % suffix, seed, registry)
	var character = domain.execute(ChooseCharacterCommandScript.new("rc7.%s.character" % suffix, Phase2CatalogScript.CHARACTER_IDS[0]))
	var contract = domain.execute(ChooseContractCommandScript.new("rc7.%s.contract" % suffix, Phase2CatalogScript.CONTRACT_IDS[0]))
	if not character.accepted or not contract.accepted:
		return null
	var selected = domain.execute(SelectMapNodeCommandScript.new("rc7.%s.enter" % suffix, domain.map_definition.start_node_id))
	# Archive coverage for RC7 saves: their current battle retains the old rule.
	if selected.accepted:
		domain.current_battle.combat_state.turn_play_enabled = false
	return domain if selected.accepted else null

func _registry():
	var registry = ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	return registry

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
