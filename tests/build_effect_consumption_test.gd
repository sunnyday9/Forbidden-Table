class_name BuildEffectConsumptionTest
extends RefCounted

const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const MiniActMapCatalogScript = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifierScript = preload("res://src/infrastructure/replay/replay_verifier.gd")
const SaveCoordinatorScript = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const ModifyRunCurrencyOperationScript = preload("res://src/domain/effects/operations/modify_run_currency_operation.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")
const SettlePatternCommandScript = preload("res://src/domain/commands/settle_pattern_command.gd")
const SelectMapNodeCommandScript = preload("res://src/domain/commands/select_map_node_command.gd")
const SettleCompleteHandCommandScript = preload("res://src/domain/commands/settle_complete_hand_command.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_owned_starting_relic_effect_replays_and_resumes_once(failures)
	test_act_two_rule_breaker_effect_applies_only_when_owned(failures)
	test_tile_modifier_effect_is_scoped_to_settled_instance_and_replays(failures)
	test_tile_modifier_effect_resolves_for_complete_hand(failures)
	test_invalid_tile_modifier_rejects_settlement_atomically(failures)
	test_invalid_owned_entry_effect_rejects_map_entry_atomically(failures)
	return failures

func test_owned_starting_relic_effect_replays_and_resumes_once(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	var domain := _prepared_domain("build-effects.relic", 7821, registry)
	var selected = domain.execute(SelectMapNodeCommandScript.new("build-effects.relic.enter", "base.map_node.normal.left"))
	assert_true(selected.accepted, "the prepared run enters a valid battle", failures)
	if not selected.accepted:
		return

	var battle = domain.current_battle
	assert_true(domain.state.build_ownership.owned_relic_ids.has("base.relic.open_hand"), "the Character's starting Relic is owned", failures)
	assert_true(battle.zones.size(TileZoneScript.HAND) == 1, "an owned battle-entry DrawTile Relic effect draws exactly one tile", failures)
	assert_true(battle.combat_state.tp == 0, "a registered but unowned GainTP Relic has no battle effect", failures)
	assert_true(_has_effect_event(selected.events, DomainEventScript.TILE_DRAWN, "content.base.relic.open_hand"), "the accepted map command exposes the Relic's factual draw event", failures)

	var checkpoint_before_resume: Dictionary = domain.checkpoint()
	var rng_before_resume: Dictionary = domain.rng_snapshot()
	var saved = SaveCoordinatorScript.new().save(domain)
	assert_true(saved.accepted, "an active battle with resolved entry effects is saved at its stable boundary", failures)
	if saved.accepted:
		var resumed = SaveMapperScript.load_into_domain(saved.snapshot.to_dictionary(), registry)
		assert_true(resumed.accepted, "the saved battle resumes through the public load pipeline", failures)
		if resumed.accepted:
			assert_true(resumed.domain.current_battle.zones.size(TileZoneScript.HAND) == 1, "resuming a battle does not reapply its one-time entry draw", failures)
			assert_true(resumed.domain.checkpoint() == checkpoint_before_resume, "resuming preserves the battle checkpoint after entry effects", failures)
			assert_true(resumed.domain.rng_snapshot() == rng_before_resume, "resuming does not advance RNG for already resolved entry effects", failures)

	var replay = domain.verify_replay()
	assert_true(replay.is_match(), "accepted map commands replay the same owned Relic effects and checkpoint", failures)

func test_act_two_rule_breaker_effect_applies_only_when_owned(failures: Array[String]) -> void:
	var registry := _alpha_registry()
	var rule_breaker_id: String = AlphaActTwoCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_IDS[0]
	var unowned_domain := _prepared_act_two_domain("build-effects.act-two-unowned", 7822, registry, false)
	var unowned_selection = unowned_domain.execute(SelectMapNodeCommandScript.new("build-effects.act-two-unowned.enter", "base.map_node.act_two.normal.left"))
	assert_true(unowned_selection.accepted, "the Act Two comparison run enters its authored battle", failures)
	if not unowned_selection.accepted:
		return
	var unowned_capacity: int = unowned_domain.current_battle.combat_state.settlement_capacity
	assert_true(not unowned_domain.state.build_ownership.acquired_rule_breaker_ids.has(rule_breaker_id), "the comparison run does not own the registered Rule Breaker", failures)

	var owned_domain := _prepared_act_two_domain("build-effects.act-two-owned", 7822, registry, true)
	var selection = owned_domain.execute(SelectMapNodeCommandScript.new("build-effects.act-two-owned.enter", "base.map_node.act_two.normal.left"))
	assert_true(selection.accepted, "the prepared Act Two run enters its authored battle", failures)
	if not selection.accepted:
		return
	var owned_capacity: int = owned_domain.current_battle.combat_state.settlement_capacity
	assert_true(owned_capacity == unowned_capacity + 1, "an acquired Act Two Rule Breaker changes battle settlement capacity", failures)
	assert_true(owned_domain.current_battle.settlement_window.settlement_capacity().maximum == unowned_domain.current_battle.settlement_window.settlement_capacity().maximum + 1, "the settlement window consumes the acquired capacity effect", failures)
	assert_true(_has_capacity_event(selection.events, "settlement_capacity", owned_capacity), "the accepted map command exposes the Rule Breaker's capacity event", failures)

	var saved = SaveCoordinatorScript.new().save(owned_domain)
	assert_true(saved.accepted, "the Act Two battle with an acquired Rule Breaker is saveable", failures)
	if saved.accepted:
		var resumed = SaveMapperScript.load_into_domain(saved.snapshot.to_dictionary(), registry)
		assert_true(resumed.accepted, "the Act Two Rule Breaker battle resumes from its checkpoint", failures)
		if resumed.accepted:
			assert_true(resumed.domain.current_battle.combat_state.settlement_capacity == owned_capacity, "resume preserves the acquired Rule Breaker's battle effect without applying it again", failures)

	var replay_factory := func(replay_seed: int, _replay_content_version: String):
		var replay_domain := _prepared_act_two_domain("build-effects.act-two-owned", replay_seed, registry, true)
		_record_replay_segment(replay_domain)
		return replay_domain
	var replay = ReplayVerifierScript.verify(owned_domain.replay_record, replay_factory, owned_domain.state.content_version)
	assert_true(replay.is_match(), "the accepted Act Two map command reproduces its owned Rule Breaker effect", failures)

	assert_true(unowned_domain.current_battle.combat_state.settlement_capacity == unowned_capacity, "a registered but unowned Act Two Rule Breaker has no battle effect", failures)

func test_tile_modifier_effect_is_scoped_to_settled_instance_and_replays(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	var domain: RunDomainScript = _prepared_modifier_domain("build-effects.modifier", 7823, registry)
	var battle = domain.current_battle
	var candidates: Array = battle.settlement_window.candidates()
	if candidates.is_empty():
		assert_true(false, "the modifier fixture prepares a legal settlement candidate", failures)
		return
	var candidate = candidates[0]
	var ownership_setup := _assign_modifier_to_candidate_and_other_tile(domain, candidate)
	var unrelated_owner_id: String = str(ownership_setup.get("unrelated_instance_id", ""))
	assert_true(not unrelated_owner_id.is_empty(), "the fixture has an unsettled TileInstance to test ownership scoping", failures)
	if unrelated_owner_id.is_empty():
		return
	domain.state.current_battle_snapshot = preload("res://src/domain/run/run_battle_snapshot.gd").new(battle.checkpoint())
	_record_replay_segment(domain)
	var tp_before: int = battle.combat_state.tp
	var result = domain.execute(SettlePatternCommandScript.new(
		"build-effects.modifier.settle",
		[],
		"",
		"",
		false,
		candidate.candidate_id,
	))
	assert_true(result.accepted, "a candidate containing a modified TileInstance settles", failures)
	assert_true(battle.combat_state.tp == tp_before + 1, "the settled TileInstance modifier resolves its typed GainTP operation", failures)
	assert_true(_has_effect_event(result.events, DomainEventScript.TP_CHANGED, "content.base.modifier.flexible_identity"), "modifier settlement returns its factual typed-effect event", failures)
	assert_true(_event_count(result.events, DomainEventScript.TP_CHANGED) == 1, "a matching modifier on an unsettled tile has no effect", failures)
	assert_true(_event_count(result.events, DomainEventScript.EFFECT_REJECTED) == 0, "a targetless optional Purge effect is skipped without a misleading rejection event", failures)

	var saved = SaveCoordinatorScript.new().save(domain)
	assert_true(saved.accepted, "the run with persistent per-instance modifier state is saveable", failures)
	if saved.accepted:
		var resumed = SaveMapperScript.load_into_domain(saved.snapshot.to_dictionary(), registry)
		assert_true(resumed.accepted, "the settled modifier run resumes through the public load pipeline", failures)
		if resumed.accepted:
			assert_true(resumed.domain.state.build_ownership.persistent_tile_modifier_state == domain.state.build_ownership.persistent_tile_modifier_state, "resume preserves exact per-instance modifier ownership", failures)
			assert_true(resumed.domain.current_battle.combat_state.tp == tp_before + 1, "resume does not reapply the settlement modifier effect", failures)

	var replay_factory := func(replay_seed: int, _replay_content_version: String):
		var replay_domain: RunDomainScript = _prepared_modifier_domain("build-effects.modifier", replay_seed, registry)
		var replay_candidate = replay_domain.current_battle.settlement_window.candidates()[0]
		_assign_modifier_to_candidate_and_other_tile(replay_domain, replay_candidate)
		replay_domain.state.current_battle_snapshot = preload("res://src/domain/run/run_battle_snapshot.gd").new(replay_domain.current_battle.checkpoint())
		_record_replay_segment(replay_domain)
		return replay_domain
	var replay = ReplayVerifierScript.verify(domain.replay_record, replay_factory, domain.state.content_version)
	assert_true(replay.is_match(), "the modifier settlement event, state, and RNG replay deterministically", failures)

func test_tile_modifier_effect_resolves_for_complete_hand(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	var domain: RunDomainScript = _prepared_complete_hand_modifier_domain("build-effects.complete", 7826, registry)
	var interpretations: Array = domain.current_battle.complete_hand_interpretations()
	if interpretations.is_empty():
		assert_true(false, "the Complete Hand modifier fixture prepares an authored winning hand", failures)
		return
	var interpretation = interpretations[0]
	var battle = domain.current_battle
	var tp_before: int = battle.combat_state.tp
	var result = domain.execute(SettleCompleteHandCommandScript.new(
		"build-effects.complete.settle",
		interpretation.interpretation_id,
	))
	assert_true(result.accepted, "a Complete Hand containing a modified TileInstance is accepted", failures)
	assert_true(battle.combat_state.tp == tp_before + 1, "the owning Tile Modifier resolves at the Complete Hand settlement boundary", failures)
	assert_true(_has_effect_event(result.events, DomainEventScript.TP_CHANGED, "content.base.modifier.flexible_identity"), "Complete Hand returns the modifier's factual typed-effect event", failures)

	var replay_factory := func(replay_seed: int, _replay_content_version: String):
		return _prepared_complete_hand_modifier_domain("build-effects.complete", replay_seed, registry)
	var replay = ReplayVerifierScript.verify(domain.replay_record, replay_factory, domain.state.content_version)
	assert_true(replay.is_match(), "Complete Hand modifier effects replay with identical state and RNG", failures)

func test_invalid_owned_entry_effect_rejects_map_entry_atomically(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	var domain := _prepared_domain("build-effects.invalid", 7824, registry)
	var relic = registry.resolve("base.relic.open_hand")
	relic.effects[0].operations = [ModifyRunCurrencyOperationScript.new(RunEconomyScript.GOLD, -100, "test.invalid_owned_effect")]
	var before: Dictionary = domain.checkpoint()
	var rng_before: Dictionary = domain.rng_snapshot()
	var result = domain.execute(SelectMapNodeCommandScript.new("build-effects.invalid.enter", "base.map_node.normal.left"))
	assert_true(not result.accepted, "an owned build effect with invalid operation data rejects battle entry", failures)
	assert_true(result.validation.code == "BUILD_EFFECT_REJECTED", "battle-entry effect validation exposes a stable rejection code", failures)
	assert_true(result.events.is_empty(), "a rejected battle-entry effect emits no accepted map events", failures)
	assert_true(domain.checkpoint() == before, "a rejected battle-entry effect leaves the Run and map checkpoint unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "a rejected battle-entry effect restores every RNG stream", failures)

func test_invalid_tile_modifier_rejects_settlement_atomically(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	var domain: RunDomainScript = _prepared_modifier_domain("build-effects.invalid-modifier", 7825, registry)
	var candidates: Array = domain.current_battle.settlement_window.candidates()
	if candidates.is_empty():
		assert_true(false, "the invalid modifier fixture prepares a legal settlement candidate", failures)
		return
	var candidate = candidates[0]
	domain.state.build_ownership.persistent_tile_modifier_state[candidate.tile_instances[0].instance_id] = ["base.modifier.flexible_identity"]
	var definition = registry.resolve("base.modifier.flexible_identity")
	definition.effects[0].operations = [ModifyRunCurrencyOperationScript.new(RunEconomyScript.GOLD, -100, "test.invalid_tile_modifier")]
	domain.state.current_battle_snapshot = preload("res://src/domain/run/run_battle_snapshot.gd").new(domain.current_battle.checkpoint())
	var before: Dictionary = domain.checkpoint()
	var rng_before: Dictionary = domain.rng_snapshot()
	var result = domain.execute(SettlePatternCommandScript.new(
		"build-effects.invalid-modifier.settle",
		[],
		"",
		"",
		false,
		candidate.candidate_id,
	))
	assert_true(not result.accepted and result.validation.code == "BUILD_EFFECT_REJECTED", "a selected Tile Modifier with an invalid typed effect is rejected by command validation", failures)
	assert_true(result.events.is_empty(), "the rejected Tile Modifier settlement returns no effect or settlement events", failures)
	assert_true(domain.checkpoint() == before, "the rejected Tile Modifier settlement leaves Battle and Run state unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "the rejected Tile Modifier settlement does not advance any RNG stream", failures)

func _prepared_act_two_domain(run_id: String, seed: int, registry, own_rule_breaker: bool) -> RunDomainScript:
	var domain: RunDomainScript = RunDomainScript.new_alpha_run(run_id, seed, registry)
	domain.execute(ChooseCharacterCommandScript.new("%s.character" % run_id, Phase2CatalogScript.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommandScript.new("%s.contract" % run_id, Phase2CatalogScript.CONTRACT_IDS[0]))
	domain.map_definition = MiniActMapCatalogScript.act_two_definition()
	domain.state.act_index = 2
	domain.state.map_state.initialize(domain.map_definition, domain.rng_streams.map)
	if own_rule_breaker:
		domain.state.build_ownership.acquired_rule_breaker_ids.append(AlphaActTwoCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_IDS[0])
	_record_replay_segment(domain)
	return domain

func _record_replay_segment(domain) -> void:
	domain.replay_record = ReplayRecordScript.new(domain.state.seed, domain.state.content_version, domain.state.run_id)
	domain.replay_record.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), domain.state.terminal_summary.outcome)

func _alpha_registry() -> ContentRegistryScript:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	AlphaActTwoCatalogScript.register_all(registry)
	AlphaScaleCatalogScript.register_all(registry)
	return registry

func _prepared_domain(run_id: String, seed: int, registry) -> RunDomainScript:
	var domain := RunDomainScript.new(run_id, seed, registry)
	domain.execute(ChooseCharacterCommandScript.new("%s.character" % run_id, Phase2CatalogScript.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommandScript.new("%s.contract" % run_id, Phase2CatalogScript.CONTRACT_IDS[0]))
	return domain

func _prepared_modifier_domain(run_id: String, seed: int, registry) -> RunDomainScript:
	var domain := _prepared_domain(run_id, seed, registry)
	var selected = domain.execute(SelectMapNodeCommandScript.new("%s.enter" % run_id, "base.map_node.normal.left"))
	if not selected.accepted:
		return domain
	var battle = domain.current_battle
	for _draw_index in range(12):
		if battle.settlement_window.open():
			break
		var draw_result = battle.tile_actions.draw()
		if not draw_result.is_accepted():
			break
	if not battle.settlement_window.is_open():
		battle.settlement_window.open()
	domain.state.current_battle_snapshot = preload("res://src/domain/run/run_battle_snapshot.gd").new(battle.checkpoint())
	_record_replay_segment(domain)
	return domain

func _prepared_complete_hand_modifier_domain(run_id: String, seed: int, registry) -> RunDomainScript:
	var domain := _prepared_domain(run_id, seed, registry)
	var selected = domain.execute(SelectMapNodeCommandScript.new("%s.enter" % run_id, "base.map_node.normal.left"))
	if not selected.accepted:
		return domain
	var battle = domain.current_battle
	for _draw_index in range(20):
		if battle.complete_hand_interpretations().size() > 0:
			break
		var draw_result = battle.tile_actions.draw()
		if not draw_result.is_accepted():
			break
	var interpretations: Array = battle.complete_hand_interpretations()
	if not interpretations.is_empty() and not interpretations[0].tile_instances.is_empty():
		domain.state.build_ownership.persistent_tile_modifier_state[interpretations[0].tile_instances[0].instance_id] = ["base.modifier.flexible_identity"]
	domain.state.current_battle_snapshot = preload("res://src/domain/run/run_battle_snapshot.gd").new(battle.checkpoint())
	_record_replay_segment(domain)
	return domain

func _assign_modifier_to_candidate_and_other_tile(domain: RunDomainScript, candidate) -> Dictionary:
	var candidate_instance_ids: Array[String] = []
	for tile in candidate.tile_instances:
		candidate_instance_ids.append(tile.instance_id)
	var unrelated_owner_id := ""
	for tile in domain.current_battle.zones.contents(TileZoneScript.HAND):
		if not candidate_instance_ids.has(tile.instance_id):
			unrelated_owner_id = tile.instance_id
			break
	if candidate.tile_instances.size() > 0 and not unrelated_owner_id.is_empty():
		domain.state.build_ownership.persistent_tile_modifier_state[candidate.tile_instances[0].instance_id] = ["base.modifier.flexible_identity", "base.modifier.clean_surface"]
		domain.state.build_ownership.persistent_tile_modifier_state[unrelated_owner_id] = ["base.modifier.flexible_identity"]
	return {"unrelated_instance_id": unrelated_owner_id}

func _has_effect_event(events: Array, event_type: String, effect_id: String) -> bool:
	for event in events:
		if event != null and event.event_type == event_type and str(event.data.get("effect_id", "")) == effect_id:
			return true
	return false

func _has_capacity_event(events: Array, capacity: String, value: int) -> bool:
	for event in events:
		if event != null and event.event_type == DomainEventScript.CAPACITY_CHANGED and event.data.get("capacity", "") == capacity and int(event.data.get("value", -1)) == value:
			return true
	return false

func _event_count(events: Array, event_type: String) -> int:
	var count := 0
	for event in events:
		if event != null and event.event_type == event_type:
			count += 1
	return count

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
