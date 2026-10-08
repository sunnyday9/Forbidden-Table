class_name StartingHandLimitRegressionTest
extends RefCounted

const BattlePhase := "BATTLE"
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const EnemyDefinitionScript = preload("res://src/content/definitions/enemy_definition.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const EffectScript = preload("res://src/domain/effects/effect.gd")
const EffectContextScript = preload("res://src/domain/effects/effect_context.gd")
const EffectTriggerScript = preload("res://src/domain/effects/effect_trigger.gd")
const DrawTileOperationScript = preload("res://src/domain/effects/operations/draw_tile_operation.gd")
const MoveTileOperationScript = preload("res://src/domain/effects/operations/move_tile_operation.gd")
const ContaminationDefinitionScript = preload("res://src/domain/tiles/contamination_definition.gd")
const ContaminationServiceScript = preload("res://src/domain/tiles/contamination_service.gd")
const DrawResolverScript = preload("res://src/domain/tiles/draw_resolver.gd")
const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")
const DrawWallScript = preload("res://src/domain/tiles/draw_wall.gd")
const DrawResultScript = preload("res://src/domain/tiles/draw_result.gd")
const CombatStateScript = preload("res://src/domain/combat/combat_state.gd")
const ReserveServiceScript = preload("res://src/domain/tiles/reserve_service.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")
const TileZoneContainerScript = preload("res://src/domain/tiles/tile_zone_container.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")
const RunTilePoolStateScript = preload("res://src/domain/run/run_tile_pool_state.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const SelectMapNodeCommandScript = preload("res://src/domain/commands/select_map_node_command.gd")
const UseTechniqueCommandScript = preload("res://src/domain/commands/use_technique_command.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const LoadValidatorScript = preload("res://src/infrastructure/persistence/load_validator.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const DomainRngStreamsScript = preload("res://src/infrastructure/rng/domain_rng_streams.gd")

const INITIAL_HAND_SIZE := 11
const MAX_HAND_SIZE := 14
const INTRO_NODE_ID := "base.map_node.intro"


func run() -> Array[String]:
	var failures: Array[String] = []
	test_fresh_battles_start_with_eleven_deterministic_tiles(failures)
	test_starting_relic_grants_reserve_capacity_without_extra_draw(failures)
	test_excess_battle_entry_draw_effects_are_skipped_safely(failures)
	test_opening_tile_order_variants_are_validated_and_deterministic(failures)
	test_small_fixture_deals_only_available_tiles(failures)
	test_zone_boundary_rejects_hand_overflow_atomically(failures)
	test_draw_capacity_rejection_has_no_draw_side_effects(failures)
	test_effect_and_technique_chains_preflight_hand_capacity(failures)
	test_hand_injection_and_reserve_swap_respect_limit(failures)
	test_over_limit_checkpoint_rejection_preserves_live_battle(failures)
	test_legacy_over_limit_save_is_rejected_without_mutation(failures)
	test_suspend_resume_preserves_dealt_hand_and_replay(failures)
	print("RC6_STARTING_HAND_LIMIT_REPORT failures=%d" % failures.size())
	return failures


func test_fresh_battles_start_with_eleven_deterministic_tiles(failures: Array[String]) -> void:
	var first = _prepared_domain("rc6.starting-hand", 61011, failures)
	var second = _prepared_domain("rc6.starting-hand", 61011, failures)
	if first == null or second == null:
		return
	var encounter_cases := [
		{"id": "base.encounter.normal.left", "kind": EncounterDefinitionScript.NORMAL},
		{"id": "base.encounter.elite", "kind": EncounterDefinitionScript.ELITE},
		{"id": "base.encounter.boss", "kind": EncounterDefinitionScript.BOSS},
	]
	var first_checkpoints: Array[Dictionary] = []
	var second_checkpoints: Array[Dictionary] = []
	for encounter_case in encounter_cases:
		var first_battle = first.encounter_factory.create(first.state, str(encounter_case.id), first.rng_streams, str(encounter_case.kind))
		var second_battle = second.encounter_factory.create(second.state, str(encounter_case.id), second.rng_streams, str(encounter_case.kind))
		_assert(first_battle != null and second_battle != null, "%s can construct fresh deterministic battles" % encounter_case.id, failures)
		if first_battle == null or second_battle == null:
			continue
		_assert(first_battle.zones.size(TileZoneScript.HAND) == INITIAL_HAND_SIZE, "%s starts with exactly eleven tiles" % encounter_case.id, failures)
		_assert(first_battle.combat_state.draw_actions_used_this_turn == 0, "%s opening deal does not spend a Draw Action" % encounter_case.id, failures)
		_assert(first_battle.combat_state.fatigue == 0 and first_battle.combat_state.pressure == 0 and first_battle.combat_state.starvation_count == 0, "%s opening deal does not trigger draw fatigue, starvation, or pressure" % encounter_case.id, failures)
		_assert(first_battle.zones.size(TileZoneScript.DRAW_WALL) == first.state.tile_pool.tile_instances.size() - INITIAL_HAND_SIZE, "%s deals directly from the initialized wall" % encounter_case.id, failures)
		first_checkpoints.append(first_battle.checkpoint())
		second_checkpoints.append(second_battle.checkpoint())
	_assert(first_checkpoints == second_checkpoints, "same run seed, pool, and encounter reproduce the same dealt hand and wall order", failures)


func test_starting_relic_grants_reserve_capacity_without_extra_draw(failures: Array[String]) -> void:
	var domain = _prepared_domain("rc6.opening-relic", 61016, failures, 0)
	if domain == null:
		return
	var battle = domain.encounter_factory.create(domain.state, "base.encounter.normal.left", domain.rng_streams, EncounterDefinitionScript.NORMAL)
	_assert(battle != null, "the Character with the Reserve-capacity starter Relic creates a fresh battle", failures)
	if battle == null:
		return
	_assert(battle.zones.size(TileZoneScript.HAND) == INITIAL_HAND_SIZE, "the Reserve starter Relic leaves the fresh opening Hand at exactly eleven tiles", failures)
	_assert(battle.zones.size(TileZoneScript.DRAW_WALL) == domain.state.tile_pool.tile_instances.size() - INITIAL_HAND_SIZE, "the opening deal consumes exactly eleven wall tiles without relic top-up", failures)
	_assert(battle.zones.size(TileZoneScript.RESERVE) == 0, "Reserve capacity does not automatically fill the Reserve zone", failures)
	_assert(battle.combat_state.reserve_capacity == 4 and battle.reserve_service.reserve_capacity == 4 and battle.zones.reserve_capacity == 4, "the starter Relic grants one synchronized Reserve slot", failures)
	_assert(battle.battle_start_effect_events.size() == 1 and battle.battle_start_effect_events[0].event_type == "CapacityChanged" and battle.battle_start_effect_events[0].data.get("capacity", "") == "reserve_capacity" and battle.battle_start_effect_events[0].data.get("effect_id", "") == "content.base.relic.open_hand" and int(battle.battle_start_effect_events[0].data.get("value", -1)) == 4, "battle entry exposes the starter Relic's factual Reserve-capacity effect", failures)
	_assert(battle.battle_start_effect_events.all(func(event): return event.event_type != "TileDrawn"), "the Reserve starter Relic does not draw an extra tile", failures)
	_assert(battle.combat_state.draw_actions_used_this_turn == 0, "the starter Relic leaves the normal Draw Action budget unused", failures)


func test_excess_battle_entry_draw_effects_are_skipped_safely(failures: Array[String]) -> void:
	var domain = _prepared_domain("rc6.entry-draw-cap", 61021, failures)
	if domain == null:
		return
	var entry_effects: Array = []
	for index in range(INITIAL_HAND_SIZE + 1):
		entry_effects.append(EffectScript.new(
			"rc6.entry.draw.%d" % index,
			EffectTriggerScript.new(EffectTriggerScript.MANUAL),
			[],
			[],
			[DrawTileOperationScript.new(DrawSourceScript.EFFECT)],
		))
	var relic_id := "base.relic.rc6_five_entry_draws"
	var relic_registration = domain.content_registry.register(RelicDefinitionScript.new(relic_id, entry_effects))
	_assert(relic_registration.is_valid(), "five effect draws form a valid test-only entry Relic", failures)
	if not relic_registration.is_valid():
		return
	domain.state.build_ownership.owned_relic_ids.clear()
	domain.state.build_ownership.owned_relic_ids.append(relic_id)
	domain.state.build_ownership.owned_relic_ids.sort()
	var start_result = domain.execute(SelectMapNodeCommandScript.new("rc6.entry-draw-cap.enter", INTRO_NODE_ID))
	_assert(start_result.accepted, "over-capacity automatic draws are skipped instead of blocking battle entry", failures)
	if not start_result.accepted:
		return
	var battle = domain.current_battle
	var tile_draw_events: Array = battle.battle_start_effect_events.filter(func(event): return event.event_type == "TileDrawn")
	_assert(battle.zones.size(TileZoneScript.HAND) == INITIAL_HAND_SIZE, "automatic entry draws and direct top-up stay within the eleven-tile opening Hand", failures)
	_assert(tile_draw_events.size() == INITIAL_HAND_SIZE, "entry effects consume available opening slots and effects that exceed the limit are skipped whole", failures)
	_assert(battle.combat_state.draw_actions_used_this_turn == 0 and battle.combat_state.fatigue == 0 and battle.combat_state.pressure == 0, "skipped entry draws spend no normal action and create no shortage penalty", failures)


func test_opening_tile_order_variants_are_validated_and_deterministic(failures: Array[String]) -> void:
	var first = _prepared_domain("rc6.opening-orders", 61017, failures)
	var second = _prepared_domain("rc6.opening-orders", 61017, failures)
	if first == null or second == null:
		return
	_set_pool(first, 20, "rc6.opening-orders")
	_set_pool(second, 20, "rc6.opening-orders")
	var unavailable_variant: Array[String] = []
	for _index in range(MAX_HAND_SIZE):
		unavailable_variant.append("base.tile.honors.red")
	var selected_variant := _ordered_test_definitions()
	var encounter_id := "base.encounter.rc6.opening_orders"
	_assert(_register_opening_order_encounter(first, encounter_id, [unavailable_variant, selected_variant], failures), "the encounter fixture carries two valid authored order variants", failures)
	_assert(_register_opening_order_encounter(second, encounter_id, [unavailable_variant, selected_variant], failures), "the repeat encounter fixture registers identically", failures)
	var first_battle = first.encounter_factory.create(first.state, encounter_id, first.rng_streams, EncounterDefinitionScript.NORMAL)
	var second_battle = second.encounter_factory.create(second.state, encounter_id, second.rng_streams, EncounterDefinitionScript.NORMAL)
	_assert(first_battle != null and second_battle != null, "the factory skips an unavailable prefix and applies the first satisfiable one", failures)
	if first_battle == null or second_battle == null:
		return
	var opening_hand_definitions: Array[String] = _zone_definition_ids(first_battle.zones, TileZoneScript.HAND)
	var ordered_wall_definitions: Array[String] = _zone_definition_ids(first_battle.zones, TileZoneScript.DRAW_WALL)
	_assert(opening_hand_definitions == selected_variant.slice(0, INITIAL_HAND_SIZE), "the first eleven authored tile definitions become the dealt hand in authored order", failures)
	_assert(ordered_wall_definitions.slice(0, 3) == selected_variant.slice(INITIAL_HAND_SIZE, MAX_HAND_SIZE), "the remaining authored prefix stays on top for the tutorial's next three draws", failures)
	_assert(_zone_tile_count(first_battle.zones) == 20, "reordering moves no tile between zones or out of the wall", failures)
	_assert(first_battle.checkpoint() == second_battle.checkpoint(), "same seed and selected opening-order variant reproduce identical physical tile order", failures)

	var malformed = _prepared_domain("rc6.opening-orders-malformed", 61018, failures)
	if malformed == null:
		return
	_set_pool(malformed, 20, "rc6.opening-orders-malformed")
	var malformed_encounter_id := "base.encounter.rc6.opening_orders_malformed"
	_assert(_register_opening_order_encounter(malformed, malformed_encounter_id, [selected_variant, ["base.tile.characters.1"]], failures), "malformed-order encounter is registered as content data", failures)
	var malformed_rng_before: Dictionary = malformed.rng_streams.snapshot()
	var malformed_pool_before: Dictionary = malformed.state.tile_pool.to_dictionary()
	var malformed_battle = malformed.encounter_factory.create(malformed.state, malformed_encounter_id, malformed.rng_streams, EncounterDefinitionScript.NORMAL)
	_assert(malformed_battle == null and malformed.encounter_factory.last_error.get("status", "") == "OPENING_TILE_ORDER_INVALID", "malformed authored order data rejects fresh encounter construction", failures)
	_assert(malformed.rng_streams.snapshot() == malformed_rng_before and malformed.state.tile_pool.to_dictionary() == malformed_pool_before, "rejecting malformed order data restores RNG and preserves the Run pool", failures)

	var unavailable = _prepared_domain("rc6.opening-orders-unavailable", 61019, failures)
	if unavailable == null:
		return
	_set_pool(unavailable, 20, "rc6.opening-orders-unavailable")
	var unavailable_encounter_id := "base.encounter.rc6.opening_orders_unavailable"
	_assert(_register_opening_order_encounter(unavailable, unavailable_encounter_id, [unavailable_variant], failures), "unsatisfiable-order encounter is registered as content data", failures)
	var unavailable_rng_before: Dictionary = unavailable.rng_streams.snapshot()
	var unavailable_battle = unavailable.encounter_factory.create(unavailable.state, unavailable_encounter_id, unavailable.rng_streams, EncounterDefinitionScript.NORMAL)
	_assert(unavailable_battle == null and unavailable.encounter_factory.last_error.get("status", "") == "OPENING_TILE_ORDER_UNAVAILABLE", "a well-formed order with unavailable copies rejects cleanly", failures)
	_assert(unavailable.rng_streams.snapshot() == unavailable_rng_before, "an unsatisfiable order restores the pre-creation RNG state", failures)


func test_small_fixture_deals_only_available_tiles(failures: Array[String]) -> void:
	var domain = _prepared_domain("rc6.small-pool", 61012, failures)
	if domain == null:
		return
	_set_pool(domain, 4, "rc6.small-pool")
	var battle = domain.encounter_factory.create(domain.state, "base.encounter.normal.left", domain.rng_streams, EncounterDefinitionScript.NORMAL)
	_assert(battle != null, "a deliberately small test pool still creates a battle", failures)
	if battle == null:
		return
	_assert(battle.zones.size(TileZoneScript.HAND) == 4, "a pool smaller than eleven deals each available tile and stops", failures)
	_assert(battle.zones.size(TileZoneScript.DRAW_WALL) == 0, "a small-pool opening deal leaves no unaccounted tile in the wall", failures)
	_assert(battle.combat_state.draw_actions_used_this_turn == 0 and battle.combat_state.fatigue == 0 and battle.combat_state.pressure == 0, "a short fixture deal does not consume action budget or create shortage penalties", failures)


func test_zone_boundary_rejects_hand_overflow_atomically(failures: Array[String]) -> void:
	var zones = TileZoneContainerScript.new()
	for index in range(MAX_HAND_SIZE):
		_assert(zones.add(_tile("rc6.zone.hand.%02d" % index), TileZoneScript.HAND), "the authoritative zone accepts hand tile %d within the ceiling" % (index + 1), failures)
	var overflow_tile = _tile("rc6.zone.hand.overflow")
	var add_accepted: bool = zones.add(overflow_tile, TileZoneScript.HAND)
	_assert(not add_accepted, "adding a fifteenth tile directly to Hand is rejected", failures)
	_assert(zones.size(TileZoneScript.HAND) == MAX_HAND_SIZE and not zones.contains(overflow_tile.instance_id), "rejected Hand add leaves every tile and ownership record unchanged", failures)
	_assert(zones.add(_tile("rc6.zone.wall.overflow"), TileZoneScript.DRAW_WALL), "the fixture keeps a tile available outside Hand", failures)
	var transfer_accepted: bool = zones.transfer("rc6.zone.wall.overflow", TileZoneScript.DRAW_WALL, TileZoneScript.HAND)
	_assert(not transfer_accepted, "transferring a fifteenth tile into Hand is rejected", failures)
	_assert(zones.contains_in_zone("rc6.zone.wall.overflow", TileZoneScript.DRAW_WALL) and zones.size(TileZoneScript.HAND) == MAX_HAND_SIZE, "rejected transfer leaves the source tile in place", failures)


func test_draw_capacity_rejection_has_no_draw_side_effects(failures: Array[String]) -> void:
	var fixture := _zone_fixture(13, 3, "rc6.draw")
	var before_zones: Dictionary = _zone_snapshot(fixture.zones)
	var before_wall: Dictionary = fixture.wall.rng_snapshot()
	var result = fixture.resolver.draw(2, DrawSourceScript.TECHNIQUE)
	_assert(result.status == "HAND_CAPACITY_REACHED" and not result.is_accepted(), "a multi-tile request larger than remaining space rejects with HAND_CAPACITY_REACHED", failures)
	_assert(result.drawn == 0 and result.shortfall == 2 and result.events.is_empty(), "overflowing draw request is rejected as one atomic operation", failures)
	_assert(_zone_snapshot(fixture.zones) == before_zones and fixture.wall.rng_snapshot() == before_wall, "rejected draw leaves the wall order and every tile zone unchanged", failures)
	_assert(fixture.state.fatigue == 0 and fixture.state.pressure == 0 and fixture.state.starvation_count == 0 and not fixture.state.starvation_active, "a forbidden draw creates no fatigue, starvation, or pressure effects", failures)
	var accepted = fixture.resolver.draw(1, DrawSourceScript.NORMAL_ACTION)
	_assert(accepted.status == DrawResultScript.ACCEPTED and fixture.zones.size(TileZoneScript.HAND) == MAX_HAND_SIZE, "one tile still draws successfully when exactly one slot remains", failures)
	var full_before: Dictionary = _zone_snapshot(fixture.zones)
	var full_result = fixture.resolver.draw(1, DrawSourceScript.NORMAL_ACTION)
	_assert(full_result.status == "HAND_CAPACITY_REACHED" and _zone_snapshot(fixture.zones) == full_before, "the full hand rejects further direct draws without consuming a wall tile", failures)
	_assert(fixture.state.fatigue == 0 and fixture.state.pressure == 0 and fixture.state.starvation_count == 0, "a full-hand rejection stays free of shortage consequences", failures)


func test_effect_and_technique_chains_preflight_hand_capacity(failures: Array[String]) -> void:
	var fixture := _zone_fixture(13, 4, "rc6.effect")
	var context = EffectContextScript.new(fixture.state, fixture.zones, fixture.wall)
	var chained_effect = EffectScript.new(
		"rc6.effect.double_draw",
		EffectTriggerScript.new(EffectTriggerScript.MANUAL),
		[],
		[],
		[DrawTileOperationScript.new(DrawSourceScript.EFFECT), DrawTileOperationScript.new(DrawSourceScript.EFFECT)],
	)
	var effect_before: Dictionary = _zone_snapshot(fixture.zones)
	var effect_result = chained_effect.resolve_in_context(context, 0)
	_assert(not effect_result.is_resolved(), "an effect chain that asks for two slots with one remaining is rejected before execution", failures)
	_assert(_zone_snapshot(fixture.zones) == effect_before, "rejected effect chain has no partial draw", failures)

	var domain = _prepared_domain("rc6.technique-chain", 61013, failures)
	if domain == null:
		return
	var technique_id := "base.technique.rc6_double_draw"
	var technique = TechniqueDefinitionScript.new(technique_id, TechniqueDefinitionScript.ACTIVE, 0, [
		EffectScript.new("rc6.technique.effect.one", EffectTriggerScript.new(EffectTriggerScript.MANUAL), [], [], [DrawTileOperationScript.new(DrawSourceScript.TECHNIQUE)]),
		EffectScript.new("rc6.technique.effect.two", EffectTriggerScript.new(EffectTriggerScript.MANUAL), [], [], [DrawTileOperationScript.new(DrawSourceScript.TECHNIQUE)]),
	])
	var technique_registration = domain.content_registry.register(technique)
	_assert(technique_registration.is_valid(), "the two-draw Technique fixture is valid", failures)
	if not technique_registration.is_valid():
		return
	domain.state.build_ownership.run_technique_ids.append(technique_id)
	domain.state.build_ownership.run_technique_ids.sort()
	var battle_start = domain.execute(SelectMapNodeCommandScript.new("rc6.technique-chain.enter", INTRO_NODE_ID))
	_assert(battle_start.accepted, "the owned test Technique enters its ordinary battle timing", failures)
	if not battle_start.accepted:
		return
	var battle = domain.current_battle
	var fill_result = battle.tile_actions.draw_resolver.draw(2, DrawSourceScript.TECHNIQUE)
	_assert(fill_result.drawn == 2 and battle.zones.size(TileZoneScript.HAND) == 13, "fixture reaches thirteen tiles before testing a two-effect Technique", failures)
	var battle_before: Dictionary = battle.checkpoint()
	var tp_before: int = battle.combat_state.tp
	var rejected_technique = domain.execute(UseTechniqueCommandScript.new("rc6.technique-chain.activate", technique_id))
	_assert(not rejected_technique.accepted, "a Technique whose effects exceed remaining hand capacity is rejected", failures)
	_assert(battle.checkpoint() == battle_before and battle.combat_state.tp == tp_before, "rejected Technique preserves Hand, Draw Wall, TP, and all battle state atomically", failures)


func test_hand_injection_and_reserve_swap_respect_limit(failures: Array[String]) -> void:
	var fixture := _zone_fixture(MAX_HAND_SIZE, 0, "rc6.paths")
	var reserve_tile = _tile("rc6.paths.reserve")
	_assert(fixture.zones.add(reserve_tile, TileZoneScript.RESERVE), "a Reserve tile can coexist with a full Hand", failures)
	var reserve_service = ReserveServiceScript.new(fixture.zones, 3)
	var hand_tile = fixture.zones.contents(TileZoneScript.HAND)[0]
	var swapped = reserve_service.swap(hand_tile.instance_id, reserve_tile.instance_id)
	_assert(swapped.is_accepted(), "count-neutral Reserve swap remains available at fourteen tiles", failures)
	_assert(fixture.zones.size(TileZoneScript.HAND) == MAX_HAND_SIZE and fixture.zones.size(TileZoneScript.RESERVE) == 1, "Reserve swap preserves the hand-size invariant", failures)
	var before: Dictionary = _zone_snapshot(fixture.zones)
	var contamination_service = ContaminationServiceScript.new(fixture.zones, fixture.state)
	var injection = contamination_service.inject_contamination("rc6.paths.injected", "base.tile.characters.1", ContaminationDefinitionScript.new("rc6.contamination"), TileZoneScript.HAND)
	_assert(not injection.is_accepted(), "contamination injection cannot create a fifteenth Hand tile", failures)
	_assert(_zone_snapshot(fixture.zones) == before and not fixture.zones.contains("rc6.paths.injected"), "rejected injection does not leave a partial tile or event state", failures)


func test_over_limit_checkpoint_rejection_preserves_live_battle(failures: Array[String]) -> void:
	var domain = _prepared_domain("rc6.restore", 61014, failures)
	if domain == null:
		return
	_set_pool(domain, 20, "rc6.restore")
	var battle = domain.encounter_factory.create(domain.state, "base.encounter.normal.left", domain.rng_streams, EncounterDefinitionScript.NORMAL)
	if battle == null:
		_assert(false, "checkpoint restore fixture creates a battle", failures)
		return
	var live_before: Dictionary = battle.checkpoint()
	var over_limit: Dictionary = live_before.duplicate(true)
	var hand_ids: Array = over_limit.zones[TileZoneScript.HAND]
	var wall_ids: Array = over_limit.zones[TileZoneScript.DRAW_WALL]
	while hand_ids.size() <= MAX_HAND_SIZE and not wall_ids.is_empty():
		var moved_id := str(wall_ids.pop_front())
		hand_ids.append(moved_id)
		for tile_data in over_limit.tile_instances:
			if str(tile_data.get("instance_id", "")) == moved_id:
				tile_data["zone"] = TileZoneScript.HAND
				break
	over_limit.zones[TileZoneScript.HAND] = hand_ids
	over_limit.zones[TileZoneScript.DRAW_WALL] = wall_ids
	over_limit.draw_wall = wall_ids.duplicate()
	_assert(hand_ids.size() > MAX_HAND_SIZE, "restore fixture represents an over-limit prior-save checkpoint", failures)
	var restored: bool = battle.restore_checkpoint(over_limit)
	_assert(not restored, "a checkpoint containing more than fourteen Hand tiles is rejected", failures)
	_assert(battle.checkpoint() == live_before, "rejected over-limit checkpoint leaves the live battle intact", failures)


func test_legacy_over_limit_save_is_rejected_without_mutation(failures: Array[String]) -> void:
	var domain = _prepared_domain("rc6.legacy-over-limit-save", 61022, failures)
	if domain == null:
		return
	var start_result = domain.execute(SelectMapNodeCommandScript.new("rc6.legacy-over-limit-save.enter", INTRO_NODE_ID))
	_assert(start_result.accepted, "the prior-save compatibility fixture enters a real battle", failures)
	if not start_result.accepted:
		return
	var saved: Dictionary = SaveMapperScript.suspend_snapshot(domain).to_dictionary()
	var state: Dictionary = saved.get("authoritative_state", {}).duplicate(true)
	var battle_checkpoint: Dictionary = state.get("current_battle_snapshot", {}).duplicate(true)
	var checkpoint_zones: Dictionary = battle_checkpoint.get("zones", {}).duplicate(true)
	var hand_ids: Array = checkpoint_zones.get(TileZoneScript.HAND, []).duplicate()
	var wall_ids: Array = checkpoint_zones.get(TileZoneScript.DRAW_WALL, []).duplicate()
	while hand_ids.size() <= MAX_HAND_SIZE and not wall_ids.is_empty():
		var moved_id := str(wall_ids.pop_front())
		hand_ids.append(moved_id)
		for tile_data in battle_checkpoint.get("tile_instances", []):
			if str(tile_data.get("instance_id", "")) == moved_id:
				tile_data["zone"] = TileZoneScript.HAND
				break
	checkpoint_zones[TileZoneScript.HAND] = hand_ids
	checkpoint_zones[TileZoneScript.DRAW_WALL] = wall_ids
	battle_checkpoint["zones"] = checkpoint_zones
	battle_checkpoint["draw_wall"] = wall_ids.duplicate()
	state["current_battle_snapshot"] = battle_checkpoint
	saved["authoritative_state"] = state
	saved["run_state"] = state.duplicate(true)
	var metadata: Dictionary = saved.get("checkpoint_metadata", {}).duplicate(true)
	var hash_state: Dictionary = state.duplicate(true)
	hash_state.erase("run_started_at_unix_seconds")
	metadata["state_hash"] = DeterministicSerializerScript.hash(hash_state)
	saved["checkpoint_metadata"] = metadata
	_assert(hand_ids.size() == MAX_HAND_SIZE + 1, "the compatibility fixture creates a structurally consistent fifteen-tile saved Hand", failures)
	var submitted: Dictionary = saved.duplicate(true)
	var validation: Dictionary = LoadValidatorScript.new().validate(saved, domain.content_registry)
	_assert(not validation.get("accepted", false), "an over-limit legacy save is rejected before reconstruction", failures)
	_assert(_has_validation_error(validation, "HAND_LIMIT_EXCEEDED"), "legacy rejection reports the exact Hand limit diagnostic", failures)
	_assert(saved == submitted, "validating the prior save leaves the supplied file data unchanged", failures)


func test_suspend_resume_preserves_dealt_hand_and_replay(failures: Array[String]) -> void:
	var domain = _prepared_domain("rc6.resume", 61015, failures)
	if domain == null:
		return
	var start_result = domain.execute(SelectMapNodeCommandScript.new("rc6.resume.enter", INTRO_NODE_ID))
	_assert(start_result.accepted and domain.state.phase == RunPhaseScript.BATTLE, "normal Run enters a new battle through the map command", failures)
	if not start_result.accepted:
		return
	var checkpoint_before: Dictionary = domain.current_battle.checkpoint()
	var opening_hand: Array[String] = _zone_ids(domain.current_battle.zones, TileZoneScript.HAND)
	_assert(opening_hand.size() == INITIAL_HAND_SIZE, "the first Run command captures the eleven-tile opening hand", failures)
	var save = SaveMapperScript.suspend_snapshot(domain)
	var loaded: Dictionary = SaveMapperScript.load_into_domain(save.to_dictionary(), domain.content_registry)
	_assert(loaded.get("accepted", false), "a battle with a dealt hand survives Suspend/Resume", failures)
	if loaded.get("accepted", false):
		_assert(loaded.domain.current_battle.checkpoint() == checkpoint_before, "Resume restores the saved Hand and wall without dealing a replacement hand", failures)
		_assert(_zone_ids(loaded.domain.current_battle.zones, TileZoneScript.HAND) == opening_hand, "Resume keeps every saved tile instance in its original hand order", failures)
	var replay = domain.verify_replay()
	_assert(replay.is_match(), "the accepted battle-entry replay reproduces the same opening deal", failures)


func _prepared_domain(run_id: String, seed: int, failures: Array[String], character_index: int = 1):
	var registry = ContentRegistryScript.new()
	var registration = Phase2CatalogScript.register_all(registry)
	_assert(registration.is_valid(), "Phase 2 content registers for %s" % run_id, failures)
	if not registration.is_valid():
		return null
	var domain = RunDomainScript.new(run_id, seed, registry)
	var character = domain.execute(ChooseCharacterCommandScript.new("%s.character" % run_id, Phase2CatalogScript.CHARACTER_IDS[character_index]))
	var contract = domain.execute(ChooseContractCommandScript.new("%s.contract" % run_id, Phase2CatalogScript.CONTRACT_IDS[0]))
	_assert(character.accepted and contract.accepted, "the fresh fixture selects a Character and Contract", failures)
	return domain


func _set_pool(domain, tile_count: int, prefix: String) -> void:
	var records: Array = []
	for index in range(tile_count):
		records.append(RunTileInstanceRecordScript.new(
			"%s.tile.%03d" % [prefix, index + 1],
			"base.tile.characters.%d" % ((index % 9) + 1),
			"RUN",
			"RUN",
		))
	domain.state.tile_pool = RunTilePoolStateScript.new(records)


func _register_opening_order_encounter(domain, encounter_id: String, orders: Array, failures: Array[String]) -> bool:
	var template = domain.content_registry.resolve("base.enemy.wall_taxer")
	if template == null:
		_assert(false, "the opening-order fixture resolves a normal enemy template", failures)
		return false
	var enemy_id := encounter_id.replace("encounter", "enemy")
	var enemy = EnemyDefinitionScript.new(enemy_id, template.intent_graph, EnemyDefinitionScript.NORMAL, template.max_hp, {"opening_tile_orders": orders})
	var enemy_registration = domain.content_registry.register(enemy)
	var encounter = EncounterDefinitionScript.new(encounter_id, [enemy_id], EncounterDefinitionScript.NORMAL)
	var encounter_registration = domain.content_registry.register(encounter)
	var accepted: bool = enemy_registration.is_valid() and encounter_registration.is_valid()
	_assert(accepted, "the authored opening-order enemy and encounter register", failures)
	return accepted


func _ordered_test_definitions() -> Array[String]:
	var definitions: Array[String] = []
	for index in range(MAX_HAND_SIZE):
		definitions.append("base.tile.characters.%d" % ((index % 9) + 1))
	return definitions


func _zone_fixture(hand_count: int, wall_count: int, prefix: String) -> Dictionary:
	var zones = TileZoneContainerScript.new()
	for index in range(hand_count):
		zones.add(_tile("%s.hand.%02d" % [prefix, index + 1]), TileZoneScript.HAND)
	for index in range(wall_count):
		zones.add(_tile("%s.wall.%02d" % [prefix, index + 1]), TileZoneScript.TILE_POOL)
	var state = CombatStateScript.new(20, 50)
	var rng = DomainRngStreamsScript.new(61020 + hand_count + wall_count)
	var wall = DrawWallScript.new(zones, rng.draw_wall)
	wall.initialize()
	return {"zones": zones, "state": state, "wall": wall, "resolver": DrawResolverScript.new(wall, zones, state)}


func _tile(instance_id: String):
	return TileInstanceScript.new(instance_id, "base.tile.characters.1")


func _zone_snapshot(zones) -> Dictionary:
	var snapshot: Dictionary = {}
	for zone in TileZoneScript.all():
		snapshot[zone] = _zone_ids(zones, zone)
	return snapshot


func _zone_ids(zones, zone: String) -> Array[String]:
	var ids: Array[String] = []
	for tile_instance in zones.contents(zone):
		ids.append(str(tile_instance.instance_id))
	return ids


func _zone_definition_ids(zones, zone: String) -> Array[String]:
	var definition_ids: Array[String] = []
	for tile_instance in zones.contents(zone):
		definition_ids.append(str(tile_instance.definition_id))
	return definition_ids


func _zone_tile_count(zones) -> int:
	var count := 0
	for zone in TileZoneScript.all():
		count += zones.size(zone)
	return count


func _has_validation_error(result: Dictionary, code: String) -> bool:
	for error in result.get("errors", []):
		if str(error.get("code", "")) == code:
			return true
	return false


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
