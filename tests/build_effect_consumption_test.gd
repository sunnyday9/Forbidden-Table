class_name BuildEffectConsumptionTest
extends RefCounted

const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const BuildEffectResolverScript = preload("res://src/domain/battle/build_effect_resolver.gd")
const ActiveEffectInstanceScript = preload("res://src/domain/effects/active_effect_instance.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const MiniActMapCatalogScript = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunModifierEffectResolverScript = preload("res://src/domain/run/run_modifier_effect_resolver.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifierScript = preload("res://src/infrastructure/replay/replay_verifier.gd")
const SaveCoordinatorScript = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const ModifyRunCurrencyOperationScript = preload("res://src/domain/effects/operations/modify_run_currency_operation.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")
const WorkshopStateScript = preload("res://src/domain/run/workshop_state.gd")
const SettlePatternCommandScript = preload("res://src/domain/commands/settle_pattern_command.gd")
const SelectMapNodeCommandScript = preload("res://src/domain/commands/select_map_node_command.gd")
const SettleCompleteHandCommandScript = preload("res://src/domain/commands/settle_complete_hand_command.gd")
const UseWorkshopServiceCommandScript = preload("res://src/domain/commands/use_workshop_service_command.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_owned_starting_relic_effect_replays_and_resumes_once(failures)
	test_act_two_rule_breaker_effect_applies_only_when_owned(failures)
	test_stage_four_rule_breakers_apply_distinct_existing_effects(failures)
	test_tile_modifier_effect_is_scoped_to_settled_instance_and_replays(failures)
	test_stage_four_tile_modifiers_apply_distinct_existing_effects_and_replay(failures)
	test_tile_modifier_effect_resolves_for_complete_hand(failures)
	test_invalid_tile_modifier_rejects_settlement_atomically(failures)
	test_invalid_owned_entry_effect_rejects_map_entry_atomically(failures)
	test_authored_run_modifiers_have_gameplay_effects_and_expire(failures)
	test_run_modifier_behavior_is_data_driven(failures)
	return failures

func test_owned_starting_relic_effect_replays_and_resumes_once(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	var domain := _prepared_domain("build-effects.relic", 7821, registry)
	var selected = domain.execute(SelectMapNodeCommandScript.new("build-effects.relic.enter", domain.map_definition.start_node_id))
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
	var unowned_selection = unowned_domain.execute(SelectMapNodeCommandScript.new("build-effects.act-two-unowned.enter", unowned_domain.map_definition.start_node_id))
	assert_true(unowned_selection.accepted, "the Act Two comparison run enters its authored battle", failures)
	if not unowned_selection.accepted:
		return
	var unowned_capacity: int = unowned_domain.current_battle.combat_state.settlement_capacity
	assert_true(not unowned_domain.state.build_ownership.acquired_rule_breaker_ids.has(rule_breaker_id), "the comparison run does not own the registered Rule Breaker", failures)

	var owned_domain := _prepared_act_two_domain("build-effects.act-two-owned", 7822, registry, true)
	var selection = owned_domain.execute(SelectMapNodeCommandScript.new("build-effects.act-two-owned.enter", owned_domain.map_definition.start_node_id))
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

func test_stage_four_rule_breakers_apply_distinct_existing_effects(failures: Array[String]) -> void:
	var effect_cases: Array[Dictionary] = [
		{"content_id": AlphaScaleCatalogScript.ACT_ONE_BOSS_RULE_BREAKER_IDS[3], "act_index": 1, "operation_id": "GainStability", "effect": "stability"},
		{"content_id": AlphaScaleCatalogScript.ACT_ONE_BOSS_RULE_BREAKER_IDS[4], "act_index": 1, "operation_id": "GainTP", "effect": "tp"},
		{"content_id": AlphaScaleCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_IDS[3], "act_index": 2, "operation_id": "ModifyRunCurrency", "effect": "gold"},
		{"content_id": AlphaScaleCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_IDS[4], "act_index": 2, "operation_id": "DrawTile", "effect": "draw"},
	]
	var observed_operation_ids: Dictionary = {}
	for index in effect_cases.size():
		var effect_case: Dictionary = effect_cases[index]
		var content_id := str(effect_case.content_id)
		var registry := _alpha_registry()
		var definition = registry.resolve(content_id)
		assert_true(definition != null and definition.effects.size() == 1, "%s has one authored Rule Breaker effect" % content_id, failures)
		if definition == null or definition.effects.size() != 1:
			continue
		var operation = definition.effects[0].operations[0]
		assert_true(operation.operation_id == effect_case.operation_id, "%s uses its distinct existing %s operation" % [content_id, effect_case.operation_id], failures)
		assert_true(not observed_operation_ids.has(operation.operation_id), "%s does not duplicate another new Rule Breaker's operation" % content_id, failures)
		observed_operation_ids[operation.operation_id] = true

		var domain = RunDomainScript.new_alpha_run("build-effects.stage-four.%d" % index, 7830 + index, registry)
		domain.execute(ChooseCharacterCommandScript.new("build-effects.stage-four.character.%d" % index, Phase2CatalogScript.CHARACTER_IDS[0]))
		domain.execute(ChooseContractCommandScript.new("build-effects.stage-four.contract.%d" % index, Phase2CatalogScript.CONTRACT_IDS[0]))
		domain.state.act_index = int(effect_case.act_index)
		domain.state.build_ownership.owned_relic_ids.clear()
		domain.state.build_ownership.acquired_rule_breaker_ids.append(content_id)
		var battle = domain.encounter_factory.create(domain.state, "base.encounter.boss", domain.rng_streams, EncounterDefinitionScript.BOSS)
		assert_true(battle != null, "%s test fixture creates a Boss battle through the existing factory" % content_id, failures)
		if battle == null:
			continue
		battle.combat_state.pressure = 2
		var stability_before: int = battle.combat_state.stability
		var pressure_before: int = battle.combat_state.pressure
		var tp_before: int = battle.combat_state.tp
		var gold_before: int = domain.state.gold
		var hand_before: int = battle.zones.size(TileZoneScript.HAND)
		var result := BuildEffectResolverScript.new(registry).resolve_battle_entry(domain.state, battle)
		assert_true(result.get("accepted", false), "%s resolves through the existing battle-entry effect seam" % content_id, failures)
		match str(effect_case.effect):
			"stability":
				assert_true(battle.combat_state.stability == stability_before + 1 and battle.combat_state.pressure == pressure_before - 1, "%s visibly changes Stability and Pressure" % content_id, failures)
			"tp":
				assert_true(battle.combat_state.tp == tp_before + 1, "%s visibly grants one battle TP" % content_id, failures)
			"gold":
				assert_true(domain.state.gold == gold_before + 1, "%s visibly grants one Run Gold" % content_id, failures)
			"draw":
				assert_true(battle.zones.size(TileZoneScript.HAND) == hand_before + 1, "%s visibly starts the battle with one extra tile" % content_id, failures)
	assert_true(observed_operation_ids.size() == effect_cases.size(), "all four additions use distinct existing operation types", failures)

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

func test_stage_four_tile_modifiers_apply_distinct_existing_effects_and_replay(failures: Array[String]) -> void:
	var effect_cases: Array[Dictionary] = [
		{"modifier_id": "alpha.modifier.wide_channel", "operation_ids": ["ModifyDrawCapacity"], "board_outcome": "draw_capacity", "resource_outcome": ""},
		{"modifier_id": "alpha.modifier.sharp_current", "operation_ids": ["DealDamage"], "board_outcome": "damage", "resource_outcome": ""},
		{"modifier_id": "alpha.modifier.trade_mark", "operation_ids": ["ModifyRunCurrency", "GainStability"], "board_outcome": "stability", "resource_outcome": "gold"},
		{"modifier_id": "alpha.modifier.refinement_trace", "operation_ids": ["ModifyRunCurrency", "GainTP"], "board_outcome": "tp", "resource_outcome": "refinement_tokens"},
	]
	var observed_board_outcomes: Dictionary = {}
	for index in effect_cases.size():
		var effect_case: Dictionary = effect_cases[index]
		var modifier_id := str(effect_case.modifier_id)
		var run_id := "build-effects.stage-four-modifier.%d" % index
		var registry := _alpha_registry()
		var definition = registry.resolve(modifier_id)
		var expected_operation_ids: Array = effect_case.operation_ids
		assert_true(definition != null and definition.effects.size() == expected_operation_ids.size(), "%s has the authored Modifier Effect set" % modifier_id, failures)
		if definition == null or definition.effects.size() != expected_operation_ids.size():
			continue
		for effect_index in expected_operation_ids.size():
			var effect = definition.effects[effect_index]
			assert_true(effect.operations.size() == 1, "%s keeps each operation in its own typed Effect" % modifier_id, failures)
			if effect.operations.size() != 1:
				continue
			var operation = effect.operations[0]
			assert_true(operation.operation_id == expected_operation_ids[effect_index], "%s uses its intended existing %s operation" % [modifier_id, expected_operation_ids[effect_index]], failures)
			if modifier_id == "alpha.modifier.trade_mark" and effect_index == 0:
				assert_true(operation.currency == RunEconomyScript.GOLD, "%s is authored to grant Run Gold" % modifier_id, failures)
			elif modifier_id == "alpha.modifier.refinement_trace" and effect_index == 0:
				assert_true(operation.currency == RunEconomyScript.REFINEMENT_TOKENS, "%s is authored to grant Refinement Tokens" % modifier_id, failures)

		var domain: RunDomainScript = _prepared_modifier_domain(run_id, 7840 + index, registry)
		var battle = domain.current_battle
		var candidates: Array = battle.settlement_window.candidates()
		assert_true(not candidates.is_empty(), "%s fixture has a legal settlement candidate" % modifier_id, failures)
		if candidates.is_empty() or candidates[0].tile_instances.is_empty():
			continue
		var candidate = candidates[0]
		var target_instance_id: String = candidate.tile_instances[0].instance_id
		domain.state.build_ownership.persistent_tile_modifier_state[target_instance_id] = [modifier_id]
		domain.state.current_battle_snapshot = preload("res://src/domain/run/run_battle_snapshot.gd").new(battle.checkpoint())
		_record_replay_segment(domain)

		var draw_capacity_before: int = battle.combat_state.draw_capacity
		var enemy_hp_before: int = battle.combat_state.enemy_hp
		var stability_before: int = battle.combat_state.stability
		var tp_before: int = battle.combat_state.tp
		var gold_before: int = domain.state.gold
		var tokens_before: int = domain.state.refinement_tokens
		var result = domain.execute(SettlePatternCommandScript.new(
			"%s.settle" % run_id,
			[],
			"",
			"",
			false,
			candidate.candidate_id,
		))
		assert_true(result.accepted, "%s is validated and resolves when its owning TileInstance settles" % modifier_id, failures)
		match str(effect_case.board_outcome):
			"draw_capacity":
				assert_true(battle.combat_state.draw_capacity == draw_capacity_before + 1, "%s visibly increases the battle Draw capacity" % modifier_id, failures)
			"damage":
				assert_true(battle.combat_state.enemy_hp == enemy_hp_before - 1, "%s visibly damages the current enemy" % modifier_id, failures)
			"stability":
				assert_true(battle.combat_state.stability == stability_before + 1, "%s visibly restores one battle Stability" % modifier_id, failures)
			"tp":
				assert_true(battle.combat_state.tp == tp_before + 1, "%s visibly grants one battle TP" % modifier_id, failures)
		match str(effect_case.resource_outcome):
			"gold":
				assert_true(domain.state.gold == gold_before + 1, "%s visibly grants one Run Gold" % modifier_id, failures)
			"refinement_tokens":
				assert_true(domain.state.refinement_tokens == tokens_before + 1, "%s visibly grants one Refinement Token" % modifier_id, failures)
		assert_true(not observed_board_outcomes.has(effect_case.board_outcome), "%s has a battle outcome distinct from the other additions" % modifier_id, failures)
		observed_board_outcomes[effect_case.board_outcome] = true

		var saved = SaveCoordinatorScript.new().save(domain)
		assert_true(saved.accepted, "%s settlement with persistent Modifier state saves" % modifier_id, failures)
		if saved.accepted:
			var resumed = SaveMapperScript.load_into_domain(saved.snapshot.to_dictionary(), registry)
			assert_true(resumed.accepted, "%s settlement resumes through the public save pipeline" % modifier_id, failures)
			if resumed.accepted:
				assert_true(resumed.domain.state.build_ownership.persistent_tile_modifier_state == domain.state.build_ownership.persistent_tile_modifier_state, "%s retains its exact TileInstance Modifier owner on resume" % modifier_id, failures)
				assert_true(resumed.domain.checkpoint() == domain.checkpoint(), "%s resume preserves its settled state without replaying the Modifier" % modifier_id, failures)

		var replay_factory := func(replay_seed: int, _replay_content_version: String):
			var replay_domain: RunDomainScript = _prepared_modifier_domain(run_id, replay_seed, registry)
			var replay_candidates: Array = replay_domain.current_battle.settlement_window.candidates()
			if replay_candidates.is_empty() or replay_candidates[0].tile_instances.is_empty():
				return replay_domain
			var replay_target_id: String = replay_candidates[0].tile_instances[0].instance_id
			replay_domain.state.build_ownership.persistent_tile_modifier_state[replay_target_id] = [modifier_id]
			replay_domain.state.current_battle_snapshot = preload("res://src/domain/run/run_battle_snapshot.gd").new(replay_domain.current_battle.checkpoint())
			_record_replay_segment(replay_domain)
			return replay_domain
		var replay = ReplayVerifierScript.verify(domain.replay_record, replay_factory, domain.state.content_version)
		assert_true(replay.is_match(), "%s's observable settlement effect reproduces through replay" % modifier_id, failures)
	assert_true(observed_board_outcomes.size() == effect_cases.size(), "all four additions produce distinct observable battle outcomes", failures)

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
	var result = domain.execute(SelectMapNodeCommandScript.new("build-effects.invalid.enter", domain.map_definition.start_node_id))
	assert_true(not result.accepted, "an owned build effect with invalid operation data rejects battle entry", failures)
	assert_true(result.validation.code == "BUILD_EFFECT_REJECTED", "battle-entry effect validation exposes a stable rejection code", failures)
	assert_true(result.events.is_empty(), "a rejected battle-entry effect emits no accepted map events", failures)
	assert_true(domain.checkpoint() == before, "a rejected battle-entry effect leaves the Run and map checkpoint unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "a rejected battle-entry effect restores every RNG stream", failures)

func test_authored_run_modifiers_have_gameplay_effects_and_expire(failures: Array[String]) -> void:
	test_workshop_kit_changes_workshop_prices_and_expires(failures)
	test_rule_memory_changes_battle_entry_tp_and_replays_once(failures)

func test_run_modifier_behavior_is_data_driven(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	var domain := _prepared_domain("build-effects.generic-modifier", 7830, registry)
	var modifier := ActiveEffectInstanceScript.new(
		"run.modifier.event.custom.training",
		DurationSpecScript.new(DurationSpecScript.RUN, 1),
		"UNIQUE",
		"test.custom.training",
		1,
		-1,
		-1,
		"run.modifier.event.custom.training",
		0,
		{
			"modifier_id": "event.custom.training",
			"workshop_price_discount": 4,
			"battle_entry_operations": [{"operation_id": "GainTP", "amount": 3}],
			"battle_victory_gold": 6,
		},
	)
	domain.state.active_effects[modifier.instance_id] = modifier
	var resolver = RunModifierEffectResolverScript.new()
	var workshop_price: Dictionary = resolver.workshop_price(domain.state, 10)
	assert_true(int(workshop_price.get("price", -1)) == 6, "a previously unknown modifier applies its authored Workshop discount", failures)
	var entry_effects: Array = resolver.battle_entry_effects(domain.state)
	assert_true(entry_effects.size() == 1 and entry_effects[0].operations[0].amount == 3, "a previously unknown modifier resolves its authored battle-entry operation", failures)
	assert_true(resolver.battle_victory_gold_bonus(domain.state) == 6, "a previously unknown modifier applies its authored victory Gold bonus", failures)

func test_workshop_kit_changes_workshop_prices_and_expires(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	var character = registry.resolve(Phase2CatalogScript.CHARACTER_IDS[0])
	character.starting_relic_id = "base.relic.workshop_kit"
	var owned_domain := _prepared_domain("build-effects.workshop-kit", 7827, registry)
	assert_true(owned_domain.state.build_ownership.owned_relic_ids.has("base.relic.workshop_kit"), "choosing a Character acquires its Workshop Kit starting Relic", failures)
	_record_replay_segment(owned_domain)
	var selection = owned_domain.execute(SelectMapNodeCommandScript.new("build-effects.workshop-kit.enter", owned_domain.map_definition.start_node_id))
	assert_true(selection.accepted, "the Workshop Kit run enters its first battle", failures)
	if not selection.accepted:
		return
	var modifier = owned_domain.state.active_modifier("content.base.relic.workshop_kit")
	assert_true(modifier != null, "the owned Workshop Kit installs its declared RUN modifier", failures)
	var save_result = SaveCoordinatorScript.new().save(owned_domain)
	assert_true(save_result.accepted, "the active Workshop Kit modifier can be saved during battle", failures)
	if save_result.accepted:
		var resumed = SaveMapperScript.load_into_domain(save_result.snapshot.to_dictionary(), registry)
		assert_true(resumed.accepted, "the saved Workshop Kit run resumes", failures)
		if resumed.accepted:
			assert_true(resumed.domain.state.active_modifier("content.base.relic.workshop_kit") != null, "resume preserves the active Workshop Kit modifier", failures)
			assert_true(resumed.domain.checkpoint() == owned_domain.checkpoint(), "resume preserves the checkpoint with the active Workshop Kit", failures)
			var resumed_price := _workshop_remove_price(resumed.domain, failures, "resumed owned")
			assert_true(resumed_price == maxi(0, resumed.domain.economy.workshop_remove_price - 1), "resume preserves the Workshop Kit's downstream price discount", failures)
	var replay_factory := func(replay_seed: int, _replay_content_version: String):
		var replay_registry := ContentRegistryScript.new()
		Phase2CatalogScript.register_all(replay_registry)
		replay_registry.resolve(Phase2CatalogScript.CHARACTER_IDS[0]).starting_relic_id = "base.relic.workshop_kit"
		var replay_domain := _prepared_domain("build-effects.workshop-kit", replay_seed, replay_registry)
		_record_replay_segment(replay_domain)
		return replay_domain
	var replay = ReplayVerifierScript.verify(owned_domain.replay_record, replay_factory, owned_domain.state.content_version)
	assert_true(replay.is_match(), "Workshop Kit acquisition and battle entry replay deterministically", failures)

	var unowned_registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(unowned_registry)
	var unowned_domain := _prepared_domain("build-effects.workshop-kit-unowned", 7827, unowned_registry)
	var unowned_selection = unowned_domain.execute(SelectMapNodeCommandScript.new("build-effects.workshop-kit-unowned.enter", unowned_domain.map_definition.start_node_id))
	assert_true(unowned_selection.accepted, "the comparison run enters the same battle without Workshop Kit", failures)
	assert_true(unowned_domain.state.active_modifier("content.base.relic.workshop_kit") == null, "a registered but unowned Workshop Kit does not install its modifier", failures)

	var owned_price := _workshop_remove_price(owned_domain, failures, "owned")
	var unowned_price := _workshop_remove_price(unowned_domain, failures, "unowned")
	assert_true(owned_price == maxi(0, unowned_price - 1), "Workshop Kit discounts a Workshop service by one Gold, bounded at zero", failures)
	var zero_price: Dictionary = RunModifierEffectResolverScript.new().workshop_price(owned_domain.state, 0)
	assert_true(int(zero_price.get("price", -1)) == 0, "Workshop Kit cannot reduce a zero-price service below zero", failures)
	for service_key in [WorkshopStateScript.REMOVE, WorkshopStateScript.TRANSFORM, WorkshopStateScript.MODIFIER, WorkshopStateScript.DUPLICATE, WorkshopStateScript.REFINEMENT_TOKEN]:
		assert_true(
			owned_domain._workshop_price(service_key) == maxi(0, unowned_domain._workshop_price(service_key) - 1),
			"Workshop Kit discounts the %s service by one Gold" % service_key,
			failures,
		)
	owned_domain.replay_record = ReplayRecordScript.new(owned_domain.state.seed, owned_domain.state.content_version, owned_domain.state.run_id)
	_record_replay_segment(owned_domain)
	var tile_instance_id: String = owned_domain.state.tile_pool.tile_instances[0].instance_id
	var gold_before: int = owned_domain.state.gold
	var service_result = owned_domain.execute(UseWorkshopServiceCommandScript.new(
		"build-effects.workshop-kit.use",
		UseWorkshopServiceCommandScript.REMOVE,
		tile_instance_id,
	))
	assert_true(service_result.accepted, "Workshop Kit permits an actual discounted Workshop service purchase", failures)
	var service_event = _find_event(service_result.events, DomainEventScript.WORKSHOP_SERVICE_USED)
	assert_true(service_event != null, "the accepted Workshop service returns its factual use event", failures)
	if service_event != null:
		assert_true(int(service_event.data.get("price", -1)) == owned_price, "the Workshop event records the discounted Gold price", failures)
		var adjustments: Array = service_event.data.get("price_adjustments", [])
		assert_true(adjustments.size() == 1 and adjustments[0].get("modifier_id", "") == "content.base.relic.workshop_kit" and int(adjustments[0].get("amount", 0)) == -1, "the Workshop event records the causal Workshop Kit price adjustment", failures)
	assert_true(owned_domain.state.gold == gold_before - owned_price, "the actual Workshop purchase spends the discounted price", failures)
	var service_replay_factory := func(replay_seed: int, _replay_content_version: String):
		var replay_registry := ContentRegistryScript.new()
		Phase2CatalogScript.register_all(replay_registry)
		replay_registry.resolve(Phase2CatalogScript.CHARACTER_IDS[0]).starting_relic_id = "base.relic.workshop_kit"
		var replay_domain := _prepared_domain("build-effects.workshop-kit", replay_seed, replay_registry)
		var replay_entry = replay_domain.execute(SelectMapNodeCommandScript.new("build-effects.workshop-kit.enter", replay_domain.map_definition.start_node_id))
		assert_true(replay_entry.accepted, "the Workshop service replay enters the same battle", failures)
		_workshop_remove_price(replay_domain, failures, "replay")
		replay_domain.replay_record = ReplayRecordScript.new(replay_domain.state.seed, replay_domain.state.content_version, replay_domain.state.run_id)
		_record_replay_segment(replay_domain)
		return replay_domain
	var service_replay = ReplayVerifierScript.verify(owned_domain.replay_record, service_replay_factory, owned_domain.state.content_version)
	assert_true(service_replay.is_match(), "the actual discounted Workshop purchase and price event replay deterministically", failures)
	var expired_events: Array = owned_domain.advance_run_boundary(DurationSpecScript.RUN)
	assert_true(owned_domain.state.active_modifier("content.base.relic.workshop_kit") == null, "Workshop Kit expires at its RUN boundary", failures)
	var expired_price := _workshop_remove_price(owned_domain, failures, "expired")
	assert_true(expired_price == unowned_price, "expired Workshop Kit no longer discounts Workshop services", failures)
	assert_true(_has_event_type(expired_events, DomainEventScript.EFFECT_EXPIRED), "Workshop Kit expiry emits the existing factual lifecycle event", failures)
	var unknown_domain := _prepared_domain("build-effects.unknown-modifier", 7829, registry)
	var unknown_modifier := ActiveEffectInstanceScript.new(
		"run.modifier.unknown",
		DurationSpecScript.new(DurationSpecScript.RUN, 1),
		"REPLACE",
		"test.unknown",
		1,
		-1,
		-1,
		"run.modifier.unknown",
		0,
		{"modifier_id": "content.example.unknown", "value": 50},
	)
	unknown_domain.state.active_effects[unknown_modifier.instance_id] = unknown_modifier
	var unknown_price := _workshop_remove_price(unknown_domain, failures, "unknown modifier")
	assert_true(unknown_price == unowned_price, "an unknown Run modifier ID receives no invented Workshop benefit", failures)

func test_rule_memory_changes_battle_entry_tp_and_replays_once(failures: Array[String]) -> void:
	var registry := _alpha_registry()
	var unowned_domain := _prepared_rule_memory_domain("build-effects.rule-memory-unowned", 7828, registry, false)
	var unknown_modifier := ActiveEffectInstanceScript.new(
		"run.modifier.unknown-battle-entry",
		DurationSpecScript.new(DurationSpecScript.RUN, 1),
		"REPLACE",
		"test.unknown",
		1,
		-1,
		-1,
		"run.modifier.unknown-battle-entry",
		0,
		{"modifier_id": "content.example.unknown", "value": 50},
	)
	unowned_domain.state.active_effects[unknown_modifier.instance_id] = unknown_modifier
	var unowned_selection = unowned_domain.execute(SelectMapNodeCommandScript.new("build-effects.rule-memory-unowned.enter", unowned_domain.map_definition.start_node_id))
	assert_true(unowned_selection.accepted, "the comparison run enters the same battle without Rule Memory", failures)
	if not unowned_selection.accepted:
		return
	var unowned_tp: int = unowned_domain.current_battle.combat_state.tp
	assert_true(unowned_domain.state.active_modifier("content.base.relic.rule_memory") == null, "a registered but unowned Rule Memory has no active Run modifier", failures)
	assert_true(not _has_effect_event(unowned_selection.events, DomainEventScript.TP_CHANGED, "run_modifier.content.base.relic.rule_memory"), "an unknown active modifier ID receives no invented battle-entry TP effect", failures)

	var owned_domain := _prepared_rule_memory_domain("build-effects.rule-memory", 7828, registry, true)
	assert_true(owned_domain.state.build_ownership.owned_relic_ids.has("base.relic.rule_memory"), "choosing a Character acquires its configured Rule Memory starting Relic", failures)
	_record_replay_segment(owned_domain)
	var selection = owned_domain.execute(SelectMapNodeCommandScript.new("build-effects.rule-memory.enter", owned_domain.map_definition.start_node_id))
	assert_true(selection.accepted, "the Rule Memory run enters its first battle", failures)
	if not selection.accepted:
		return
	var expected_tp: int = owned_domain.current_battle.combat_state.tp
	assert_true(expected_tp == unowned_tp + 1, "active Rule Memory grants one TP at the new battle boundary", failures)
	assert_true(_has_effect_event(selection.events, DomainEventScript.TP_CHANGED, "run_modifier.content.base.relic.rule_memory"), "Rule Memory exposes its causal TPChanged event", failures)
	assert_true(owned_domain.state.active_modifier("content.base.relic.rule_memory") != null, "Rule Memory remains a Run-scoped modifier after battle entry", failures)
	var checkpoint_after_entry: Dictionary = owned_domain.checkpoint()
	var rng_after_entry: Dictionary = owned_domain.rng_snapshot()
	var save_result = SaveCoordinatorScript.new().save(owned_domain)
	assert_true(save_result.accepted, "Rule Memory's active Run modifier can be saved during battle", failures)
	if save_result.accepted:
		var resumed = SaveMapperScript.load_into_domain(save_result.snapshot.to_dictionary(), registry)
		assert_true(resumed.accepted, "the saved Rule Memory run resumes", failures)
		if resumed.accepted:
			assert_true(resumed.domain.current_battle.combat_state.tp == expected_tp, "resume does not grant Rule Memory TP a second time", failures)
			assert_true(resumed.domain.checkpoint() == checkpoint_after_entry, "resume preserves Rule Memory's post-entry checkpoint", failures)
			assert_true(resumed.domain.rng_snapshot() == rng_after_entry, "resume does not advance RNG for Rule Memory", failures)

	var replay_factory := func(replay_seed: int, _replay_content_version: String):
		var replay_domain := _prepared_rule_memory_domain("build-effects.rule-memory", replay_seed, registry, true)
		_record_replay_segment(replay_domain)
		return replay_domain
	var replay = ReplayVerifierScript.verify(owned_domain.replay_record, replay_factory, owned_domain.state.content_version)
	assert_true(replay.is_match(), "Rule Memory battle-entry TP and events replay deterministically", failures)
	var expired_events: Array = owned_domain.advance_run_boundary(DurationSpecScript.RUN)
	assert_true(owned_domain.state.active_modifier("content.base.relic.rule_memory") == null, "Rule Memory expires at its RUN boundary", failures)
	assert_true(_has_event_type(expired_events, DomainEventScript.EFFECT_EXPIRED), "Rule Memory expiry emits the existing factual lifecycle event", failures)
	assert_true(not _has_effect_event(unowned_selection.events, DomainEventScript.TP_CHANGED, "run_modifier.content.base.relic.rule_memory"), "an unowned Rule Memory emits no TP event", failures)

func _workshop_remove_price(domain: RunDomainScript, failures: Array[String], label: String) -> int:
	_prepare_workshop_service(domain)
	var tile_instance_id: String = domain.state.tile_pool.tile_instances[0].instance_id
	var validation = domain.validate_use_workshop_service(UseWorkshopServiceCommandScript.REMOVE, tile_instance_id)
	assert_true(validation.is_valid(), "%s Workshop Remove service is valid" % label, failures)
	return int(validation.details.get("price", -1)) if validation.is_valid() else -1

func _prepare_workshop_service(domain: RunDomainScript) -> void:
	domain.state.phase = "WORKSHOP"
	domain.state.workshop_state.begin("build-effects.workshop-test", "build-effects.workshop-test.entry")
	domain.state.gold = 100

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

func _prepared_rule_memory_domain(run_id: String, seed: int, registry, owns_rule_memory: bool) -> RunDomainScript:
	var character = registry.resolve(Phase2CatalogScript.CHARACTER_IDS[0])
	character.starting_relic_id = "base.relic.rule_memory" if owns_rule_memory else "base.relic.open_hand"
	return _prepared_domain(run_id, seed, registry)

func _prepared_modifier_domain(run_id: String, seed: int, registry) -> RunDomainScript:
	var domain := _prepared_domain(run_id, seed, registry)
	var selected = domain.execute(SelectMapNodeCommandScript.new("%s.enter" % run_id, domain.map_definition.start_node_id))
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
	var selected = domain.execute(SelectMapNodeCommandScript.new("%s.enter" % run_id, domain.map_definition.start_node_id))
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

func _has_event_type(events: Array, event_type: String) -> bool:
	for event in events:
		if event != null and event.event_type == event_type:
			return true
	return false

func _find_event(events: Array, event_type: String):
	for event in events:
		if event != null and event.event_type == event_type:
			return event
	return null

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
