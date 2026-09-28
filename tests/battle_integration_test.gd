class_name BattleIntegrationTest
extends RefCounted

const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const EnemyDefinition = preload("res://src/content/definitions/enemy_definition.gd")
const EnemyIntent = preload("res://src/domain/combat/enemy_intent.gd")
const EncounterDefinition = preload("res://src/content/definitions/encounter_definition.gd")
const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const IntentGraph = preload("res://src/domain/combat/intent_graph.gd")
const IntentTransition = preload("res://src/domain/combat/intent_transition.gd")
const PublicStateCondition = preload("res://src/domain/combat/public_state_condition.gd")
const RelicDefinition = preload("res://src/content/definitions/relic_definition.gd")
const RewardPoolDefinition = preload("res://src/content/definitions/reward_pool_definition.gd")
const RuleBreakerDefinition = preload("res://src/content/definitions/rule_breaker_definition.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunStartingPoolContentFixture = preload("res://tests/fixtures/run_starting_pool_content_fixture.gd")
const RunTileInstanceRecord = preload("res://src/domain/run/run_tile_instance_record.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const DrawCommand = preload("res://src/domain/commands/draw_command.gd")
const EndTurnCommand = preload("res://src/domain/commands/end_turn_command.gd")
const ResolveEnemyIntentCommand = preload("res://src/domain/commands/resolve_enemy_intent_command.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const UseTechniqueCommand = preload("res://src/domain/commands/use_technique_command.gd")
const DrawSource = preload("res://src/domain/tiles/draw_source.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const SaveCoordinator = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const ReplayRecord = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifier = preload("res://src/infrastructure/replay/replay_verifier.gd")
const RunBattleSnapshot = preload("res://src/domain/run/run_battle_snapshot.gd")
const RunPresentationController = preload("res://src/presentation/run/run_presentation_controller.gd")

const LEFT := "base.map_node.intro"
const STAGE_FOUR_RUN_TECHNIQUE_IDS := [
	"alpha.technique.draw_capacity",
	"alpha.technique.pressure_dividend",
	"alpha.technique.harbor_strike",
	"alpha.technique.tide_draw",
	"alpha.technique.ledger_wind",
	"alpha.technique.refinement_practice",
	"alpha.technique.first_measure",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	test_normal_node_creates_isolated_data_driven_battle(failures)
	test_battle_outcome_transfer_opens_reward_or_terminates(failures)
	test_reward_tax_survives_save_replay_and_taxes_victory_once(failures)
	test_authored_intent_types_resolve_for_normal_elite_and_boss(failures)
	test_stage_four_enemy_encounters_resolve_through_catalog_path(failures)
	test_owned_passive_technique_applies_once_on_battle_entry(failures)
	test_stage_four_run_techniques_resolve_through_existing_commands_and_resume_replay(failures)
	test_reaction_techniques_resolve_only_in_matching_windows(failures)
	test_boss_phases_are_explicit_and_deterministic(failures)
	test_factory_rejects_invalid_enemy_without_mutation(failures)
	test_draw_actions_are_limited_and_reset_each_turn(failures)
	test_draw_capacity_changes_preserve_remaining_actions(failures)
	return failures

func test_normal_node_creates_isolated_data_driven_battle(failures: Array[String]) -> void:
	var domain := RunDomain.new("run.battle.entry", 1234, _registry())
	domain.execute(ChooseCharacterCommand.new("battle.entry.character", "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("battle.entry.contract", "base.contract.pressure"))
	domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
		"run.battle.tile.1",
		"base.tile.characters.1",
		"RUN",
		"RUN",
	))
	var gold_before: int = domain.state.gold
	var build_before: Dictionary = domain.state.build_ownership.to_dictionary()
	var tile_pool_before: Dictionary = domain.state.tile_pool.to_dictionary()

	var result = domain.execute(SelectMapNodeCommand.new("battle.entry.select", LEFT))
	var battle = domain.get("current_battle")
	var combat_state = _property(battle, "combat_state")
	var context = _property(battle, "context")
	var enemy_definition = _property(battle, "enemy_definition")

	assert_true(result.accepted, "a configured Normal node is accepted", failures)
	assert_true(domain.state.phase == RunPhase.BATTLE, "a configured Normal node enters BATTLE", failures)
	assert_true(_has_event(result.events, DomainEvent.BATTLE_STARTED), "battle entry emits an explicit BattleStarted event", failures)
	assert_true(battle != null, "RunDomain creates a BattleDomain child", failures)
	assert_true(_property(battle, "encounter_id", "") == "base.encounter.intro", "the battle uses the authored intro encounter identity", failures)
	assert_true(_property(enemy_definition, "content_id", "") == "base.enemy.wall_taxer", "the factory resolves the authored EnemyDefinition", failures)
	assert_true(_property(combat_state, "enemy_max_hp", -1) == 17, "the factory applies data-driven enemy HP", failures)
	assert_true(_property(combat_state, "pressure_limit", -1) == 9, "the factory applies data-driven Pressure limit", failures)
	assert_true(_property(context, "character_id", "") == "base.character.sequence", "battle context carries Character identity", failures)
	assert_true(_property(context, "contract_id", "") == "base.contract.pressure", "battle context carries Contract identity", failures)
	assert_true(_property(context, "build_state", {}) == build_before, "battle context snapshots build ownership", failures)
	assert_true(_property(context, "contamination_config", {}).get("kind", "") == "wall_tax", "battle context carries contamination configuration", failures)
	assert_true(_property(context, "rng_streams") == domain.rng_streams, "battle context uses the existing domain RNG streams", failures)
	assert_true(_property(battle, "zones") != null and _property(battle, "zones").contains("run.battle.tile.1"), "the child receives a runtime copy of the Run Tile Pool", failures)
	var public_state: Dictionary = battle.public_state()
	assert_true(public_state.get("enemy_identity", "") == "base.enemy.wall_taxer", "the BattleDomain exposes authored enemy identity", failures)
	assert_true(public_state.get("intent_graph", {}).get("start_intent_id", "") == "pressure", "the BattleDomain exposes the authored public Intent Graph", failures)
	assert_true(PublicStateCondition.new("boss_phase_index", PublicStateCondition.GREATER_THAN_OR_EQUAL, -1).is_valid(), "Intent conditions remain restricted to public battle state", failures)
	assert_true(PublicStateCondition.new("pressure", PublicStateCondition.LESS_THAN, 9).evaluate(public_state), "Intent conditions evaluate only the exposed public battle state", failures)
	var intent_result = domain.execute(ResolveEnemyIntentCommand.new("battle.entry.intent"))
	assert_true(intent_result.accepted, "RunDomain dispatches BattleCommand instances to the child BattleDomain", failures)
	assert_true(intent_result.state_checkpoint["run_state"]["current_battle_snapshot"]["combat_state"]["pressure"] == 1, "RunDomain refreshes the current battle snapshot after a child command", failures)

	combat_state.set("pressure", _property(combat_state, "pressure_limit", 0))
	combat_state.set("tp", 99)
	assert_true(domain.state.gold == gold_before, "child battle state cannot award run currency before outcome", failures)
	assert_true(domain.state.build_ownership.to_dictionary() == build_before, "child battle state cannot mutate persistent build state before outcome", failures)
	assert_true(domain.state.tile_pool.to_dictionary() == tile_pool_before, "child battle state does not mutate the Run Tile Pool before outcome", failures)

func test_battle_outcome_transfer_opens_reward_or_terminates(failures: Array[String]) -> void:
	var victory_domain := _prepared_domain("run.battle.victory")
	var victory_selection = victory_domain.execute(SelectMapNodeCommand.new("battle.victory.select", LEFT))
	var victory_battle = victory_domain.get("current_battle")
	var victory_resolution = victory_battle.combat_resolver.resolve_player_action(victory_battle.combat_state, 17)
	var victory_events = victory_domain.apply_battle_outcome()

	assert_true(victory_selection.accepted, "victory setup selects the configured Normal node", failures)
	assert_true(victory_resolution.terminal_outcome == CombatState.VICTORY, "the BattleDomain exposes a queue-boundary victory", failures)
	assert_true(victory_domain.state.phase == RunPhase.REWARD_CHOICE, "Normal victory opens the normal reward phase", failures)
	assert_true(victory_domain.get("current_battle") == null, "victory disposes the BattleDomain child at the outcome boundary", failures)
	assert_true(victory_domain.state.map_state.current_node_id == LEFT, "victory does not advance the map", failures)
	assert_true(victory_domain.state.gold == 0, "victory transfer does not award run currency", failures)
	assert_true(_has_event(victory_events, DomainEvent.BATTLE_OUTCOME_TRANSFERRED), "victory transfer emits an explicit outcome event", failures)

	var defeat_domain := _prepared_domain("run.battle.defeat")
	defeat_domain.execute(SelectMapNodeCommand.new("battle.defeat.select", LEFT))
	var defeat_battle = defeat_domain.get("current_battle")
	var defeat_resolution = defeat_battle.combat_resolver.resolve_player_action(defeat_battle.combat_state, 0, defeat_battle.combat_state.pressure_limit)
	defeat_domain.apply_battle_outcome()

	assert_true(defeat_resolution.terminal_outcome == CombatState.DEFEAT, "the BattleDomain exposes a queue-boundary defeat", failures)
	assert_true(defeat_domain.state.phase == RunPhase.RUN_SUMMARY, "defeat terminates the run in Run Summary", failures)
	assert_true(defeat_domain.state.terminal_summary.outcome == "DEFEAT", "defeat transfer records the terminal run outcome", failures)
	assert_true(defeat_domain.get("current_battle") == null, "defeat disposes the BattleDomain child at the outcome boundary", failures)

	var elite_domain := _prepared_domain("run.battle.elite")
	var elite_battle = elite_domain.encounter_factory.create(elite_domain.state, "base.encounter.elite", elite_domain.rng_streams, EncounterDefinition.ELITE)
	assert_true(elite_battle != null, "the factory creates an Elite BattleDomain without a per-enemy branch", failures)
	if elite_battle == null:
		return
	elite_domain.current_battle = elite_battle
	elite_domain.state.phase = RunPhase.BATTLE
	var elite_resolution = elite_battle.combat_resolver.resolve_player_action(elite_battle.combat_state, 13)
	elite_domain.apply_battle_outcome()

	assert_true(elite_resolution.terminal_outcome == CombatState.VICTORY, "the Elite BattleDomain exposes Victory", failures)
	assert_true(elite_domain.state.phase == RunPhase.ELITE_REWARD, "Elite victory opens the Elite reward phase", failures)
	assert_true(elite_domain.state.gold == 0, "Elite victory does not award run currency in BattleDomain", failures)

func test_reward_tax_survives_save_replay_and_taxes_victory_once(failures: Array[String]) -> void:
	var graph := IntentGraph.new("reward_tax", [
		EnemyIntent.new("reward_tax", "Collect the Ledger", 2, EnemyIntent.REWARD_TAX, [IntentTransition.fixed("reward_tax.loop", "reward_tax")]),
	])
	var registry := _registry(graph)
	var domain := _prepared_domain_with_registry("run.reward.tax", registry)
	var selection = domain.execute(SelectMapNodeCommand.new("reward.tax.select", LEFT))
	var intent_result = domain.execute(ResolveEnemyIntentCommand.new("reward.tax.intent"))
	var tax_snapshot: Dictionary = domain.current_battle.checkpoint()

	assert_true(selection.is_accepted(), "Reward Tax setup enters the authored Normal encounter", failures)
	assert_true(intent_result.is_accepted(), "Reward Tax resolves through the RunDomain child command path", failures)
	assert_true(domain.current_battle.combat_state.reward_tax == 2, "the resolved tax is retained in battle-local runtime state", failures)
	assert_true(tax_snapshot.get("combat_state", {}).get("reward_tax", -1) == 2, "the battle checkpoint serializes the tax marker", failures)
	if not intent_result.is_accepted():
		return

	var saved = SaveCoordinator.new().save(domain)
	assert_true(saved.get("accepted", false), "a battle with Reward Tax can be saved at an accepted Intent boundary", failures)
	if not saved.get("accepted", false):
		return
	var loaded = SaveMapper.load_into_domain(saved.snapshot.to_dictionary(), registry)
	assert_true(loaded.get("accepted", false), "the saved Reward Tax battle can be resumed", failures)
	if not loaded.get("accepted", false):
		return
	var resumed: RunDomain = loaded.domain
	assert_true(resumed.current_battle.combat_state.reward_tax == 2, "resume restores the battle-local tax marker", failures)
	assert_true(resumed.checkpoint() == domain.checkpoint(), "resume preserves the full run and battle checkpoints", failures)
	assert_true(resumed.verify_replay().is_match(), "the accepted typed Intent is deterministic under replay after resume", failures)

	# Set the post-checkpoint purse after replay verification so this test isolates
	# outcome transfer; the battle tax itself remains the state restored above.
	resumed.state.gold = 1
	var victory = resumed.current_battle.combat_resolver.resolve_player_action(resumed.current_battle.combat_state, 17)
	var outcome_events: Array = resumed.apply_battle_outcome()
	var tax_event = _event_of_type(outcome_events, DomainEvent.ENEMY_REWARD_TAX_APPLIED)
	assert_true(victory.terminal_outcome == CombatState.VICTORY, "the saved Normal battle reaches Victory", failures)
	assert_true(resumed.state.gold == 0, "Reward Tax removes no more Gold than the Run owns", failures)
	assert_true(tax_event != null and tax_event.data.get("requested_amount", -1) == 2 and tax_event.data.get("amount", -1) == 1, "the factual tax event records requested and capped amounts", failures)
	assert_true(_has_event(outcome_events, DomainEvent.GOLD_CHANGED), "the tax sink emits a factual currency change", failures)
	assert_true(resumed.state.phase == RunPhase.REWARD_CHOICE and resumed.state.reward_draft != null, "taxing Gold preserves the normal reward draft", failures)
	var second_outcome: Array = resumed.apply_battle_outcome()
	assert_true(second_outcome.is_empty() and resumed.state.gold == 0, "the battle tax cannot be consumed twice", failures)

func test_authored_intent_types_resolve_for_normal_elite_and_boss(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	var catalog_result = Phase2Catalog.register_all(registry)
	assert_true(catalog_result.is_valid(), "the typed-intent catalog is valid for integration coverage", failures)
	if not catalog_result.is_valid():
		return
	var domain := RunDomain.new("run.typed.roles", 7214, registry)
	domain.execute(ChooseCharacterCommand.new("typed.roles.character", Phase2Catalog.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommand.new("typed.roles.contract", Phase2Catalog.CONTRACT_IDS[0]))

	var normal_battle = domain.encounter_factory.create(domain.state, "base.encounter.normal.left", domain.rng_streams, EncounterDefinition.NORMAL)
	assert_true(normal_battle != null, "the authored Normal typed-intent encounter is constructible", failures)
	if normal_battle != null:
		var capacity_before: int = normal_battle.combat_state.draw_capacity
		var normal_result = normal_battle.combat_resolver.resolve_enemy_intent(normal_battle.combat_state)
		assert_true(normal_result.is_resolved(), "the Normal Wall Tax intent resolves", failures)
		assert_true(normal_battle.combat_state.draw_capacity == capacity_before - 1, "the Normal Wall Taxer changes Draw Capacity instead of adding Pressure", failures)
		assert_true(normal_battle.combat_state.pressure == 0, "the typed Normal action does not fall through to generic Pressure", failures)

	var elite_battle = domain.encounter_factory.create(domain.state, "base.encounter.elite", domain.rng_streams, EncounterDefinition.ELITE)
	assert_true(elite_battle != null, "the authored Elite typed-intent encounter is constructible", failures)
	if elite_battle != null:
		var fatigue_before: int = elite_battle.combat_state.fatigue
		var audit_result = elite_battle.combat_resolver.resolve_enemy_intent(elite_battle.combat_state)
		assert_true(audit_result.is_resolved(), "the Elite Audit intent resolves", failures)
		assert_true(elite_battle.combat_state.fatigue == fatigue_before + 1, "the Elite Audit changes Fatigue", failures)
		var reward_tax_result = elite_battle.combat_resolver.resolve_enemy_intent(elite_battle.combat_state)
		assert_true(reward_tax_result.is_resolved() and elite_battle.combat_state.reward_tax == 1, "the Elite conditional route can resolve its Reward Tax action", failures)

	var boss_battle = domain.encounter_factory.create(domain.state, "base.encounter.boss", domain.rng_streams, EncounterDefinition.BOSS)
	assert_true(boss_battle != null, "the authored Boss typed-intent encounter is constructible", failures)
	if boss_battle != null:
		var phase_result = boss_battle.combat_resolver.resolve_player_action(boss_battle.combat_state, boss_battle.combat_state.enemy_hp)
		assert_true(phase_result.terminal_outcome == CombatState.ONGOING and boss_battle.combat_state.boss_phase_id == "table_interference", "the authored Boss advances to its typed interference phase", failures)
		boss_battle.combat_state.stability = 2
		var boss_result = boss_battle.combat_resolver.resolve_enemy_intent(boss_battle.combat_state)
		assert_true(boss_result.is_resolved(), "the Boss Table Interference intent resolves", failures)
		assert_true(boss_battle.combat_state.stability == 0 and boss_battle.combat_state.pressure == 0, "the Boss typed phase applies Stability loss rather than Pressure", failures)

func test_stage_four_enemy_encounters_resolve_through_catalog_path(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	var phase2_registration = Phase2Catalog.register_all(registry)
	var act_two_registration = AlphaActTwoCatalog.register_all(registry)
	var scale_registration = AlphaScaleCatalog.register_all(registry)
	assert_true(phase2_registration.is_valid() and act_two_registration.is_valid() and scale_registration.is_valid(), "the full catalogs register the Stage 4 encounter roster", failures)
	if not phase2_registration.is_valid() or not act_two_registration.is_valid() or not scale_registration.is_valid():
		return
	var domain := RunDomain.new("run.stage4.enemy.encounters", 8410, registry)
	domain.execute(ChooseCharacterCommand.new("stage4.enemy.character", Phase2Catalog.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommand.new("stage4.enemy.contract", Phase2Catalog.CONTRACT_IDS[0]))
	var new_normal_encounter_ids: Array = AlphaScaleCatalog.ACT_ONE_NORMAL_ENCOUNTER_IDS + AlphaScaleCatalog.ACT_TWO_NORMAL_ENCOUNTER_IDS
	var new_elite_encounter_ids: Array = AlphaScaleCatalog.ACT_ONE_ELITE_ENCOUNTER_IDS + AlphaScaleCatalog.ACT_TWO_ELITE_ENCOUNTER_IDS
	for encounter_id in new_normal_encounter_ids + new_elite_encounter_ids:
		var encounter = registry.resolve(encounter_id)
		var expected_kind := EncounterDefinition.ELITE if new_elite_encounter_ids.has(encounter_id) else EncounterDefinition.NORMAL
		assert_true(encounter is EncounterDefinition and encounter.encounter_kind == expected_kind, "%s resolves to its authored encounter kind" % encounter_id, failures)
		if not encounter is EncounterDefinition:
			continue
		var battle = domain.encounter_factory.create(domain.state, encounter_id, domain.rng_streams, expected_kind)
		assert_true(battle != null, "%s creates a BattleDomain through EncounterFactory" % encounter_id, failures)
		if battle == null:
			continue
		assert_true(battle.encounter_id == encounter_id and battle.enemy_definition.content_id == encounter.enemy_ids[0], "%s resolves its authored EnemyDefinition into combat" % encounter_id, failures)
		var starting_intent = battle.combat_state.current_intent
		var pressure_before: int = battle.combat_state.pressure
		var draw_capacity_before: int = battle.combat_state.draw_capacity
		var fatigue_before: int = battle.combat_state.fatigue
		var reward_tax_before: int = battle.combat_state.reward_tax
		var draw_wall_before: int = battle.zones.size(TileZone.DRAW_WALL)
		if starting_intent != null and starting_intent.action_type in [EnemyIntent.INTEGRITY, EnemyIntent.HUNT]:
			battle.zones.add(TileInstance.new("stage4.reserve.%s" % encounter_id, "base.tile.characters.1"), TileZone.RESERVE)
		var intent_result = battle.combat_resolver.resolve_enemy_intent(battle.combat_state)
		assert_true(intent_result.is_resolved(), "%s resolves its starting authored enemy intent" % encounter_id, failures)
		if starting_intent == null:
			continue
		match starting_intent.action_type:
			EnemyIntent.PRESSURE:
				assert_true(battle.combat_state.pressure > pressure_before, "%s applies its authored Pressure action" % encounter_id, failures)
			EnemyIntent.WALL_TAX:
				assert_true(battle.combat_state.draw_capacity < draw_capacity_before, "%s applies its authored Wall Tax action" % encounter_id, failures)
			EnemyIntent.CONTAMINATION:
				assert_true(battle.zones.size(TileZone.DRAW_WALL) > draw_wall_before, "%s adds authored contamination to the Draw Wall" % encounter_id, failures)
				var contamination_applied = _event_of_type(intent_result.events, DomainEvent.CONTAMINATION_APPLIED)
				assert_true(contamination_applied != null and contamination_applied.data.get("contamination_id", "") == "base.contamination.clutter", "%s applies the supported Clutter contamination" % encounter_id, failures)
			EnemyIntent.AUDIT:
				assert_true(battle.combat_state.fatigue > fatigue_before, "%s applies its authored Audit action" % encounter_id, failures)
			EnemyIntent.REWARD_TAX:
				assert_true(battle.combat_state.reward_tax > reward_tax_before, "%s applies its authored Reward Tax action" % encounter_id, failures)
			EnemyIntent.INTEGRITY, EnemyIntent.HUNT:
				assert_true(_event_of_type(intent_result.events, DomainEvent.INTEGRITY_CHANGED) != null, "%s applies its authored Reserve Integrity action" % encounter_id, failures)

	var persisted_domain := RunDomain.new("run.stage4.enemy.resume", 8411, registry)
	persisted_domain.execute(ChooseCharacterCommand.new("stage4.enemy.resume.character", Phase2Catalog.CHARACTER_IDS[0]))
	persisted_domain.execute(ChooseContractCommand.new("stage4.enemy.resume.contract", Phase2Catalog.CONTRACT_IDS[0]))
	var selected_encounter_id: String = AlphaScaleCatalog.ACT_ONE_NORMAL_ENCOUNTER_IDS[0]
	var intro_node_id: String = persisted_domain.map_definition.start_node_id
	persisted_domain.state.map_state.payload_ids[intro_node_id] = selected_encounter_id
	var selected = persisted_domain.execute(SelectMapNodeCommand.new("stage4.enemy.resume.select", intro_node_id))
	assert_true(selected.is_accepted() and persisted_domain.current_battle.encounter_id == selected_encounter_id, "a new Act 1 Normal is selectable through the RunDomain map path", failures)
	if not selected.is_accepted():
		return
	var saved = SaveCoordinator.new().save(persisted_domain)
	assert_true(saved.get("accepted", false), "a new-enemy battle saves through the existing Suspend path", failures)
	if not saved.get("accepted", false):
		return
	var loaded: Dictionary = SaveMapper.load_into_domain(saved.snapshot.to_dictionary(), registry)
	assert_true(loaded.get("accepted", false), "a new-enemy battle resumes through the existing persistence path", failures)
	if loaded.get("accepted", false):
		assert_true(loaded.domain.current_battle.encounter_id == selected_encounter_id, "Resume restores the exact selected Stage 4 encounter", failures)
		assert_true(loaded.domain.current_battle.enemy_definition.content_id == AlphaScaleCatalog.ACT_ONE_NORMAL_ENEMY_IDS[0], "Resume restores its authored enemy definition", failures)

func test_owned_passive_technique_applies_once_on_battle_entry(failures: Array[String]) -> void:
	var registry := _registry()
	var passive := TechniqueDefinition.new(
		"alpha.technique.reserve_survey",
		TechniqueDefinition.PASSIVE,
		0,
		[Phase2Catalog.typed_effect("content.alpha.technique.reserve_survey", "ModifyReserveCapacity", 1)],
	)
	assert_true(registry.register(passive).is_valid(), "Reserve Survey is valid passive Technique content", failures)

	var unowned_domain := _prepared_domain_with_registry("run.passive.unowned", registry)
	var unowned_selection = unowned_domain.execute(SelectMapNodeCommand.new("passive.unowned.select", LEFT))
	assert_true(unowned_selection.is_accepted(), "the unowned comparison enters a Battle", failures)
	if unowned_selection.is_accepted():
		assert_true(unowned_domain.current_battle.combat_state.reserve_capacity == 3, "a Run without Reserve Survey keeps baseline Reserve Capacity", failures)

	var owned_domain := _prepared_domain_with_registry("run.passive.owned", registry)
	owned_domain.state.build_ownership.run_technique_ids.append("alpha.technique.reserve_survey")
	var owned_selection = owned_domain.execute(SelectMapNodeCommand.new("passive.owned.select", LEFT))
	assert_true(owned_selection.is_accepted(), "the owned passive enters a Battle", failures)
	if not owned_selection.is_accepted():
		return
	var battle = owned_domain.current_battle
	assert_true(battle.combat_state.reserve_capacity == 4, "Reserve Survey grants one extra Reserve slot on entry", failures)
	assert_true(battle.reserve_service.reserve_capacity == 4 and battle.zones.reserve_capacity == 4, "battle-entry passive capacity is synchronized to ReserveService and tile zones", failures)
	assert_true(owned_selection.events.any(func(event): return event.event_type == DomainEvent.CAPACITY_CHANGED and event.data.get("capacity", "") == "reserve_capacity" and event.data.get("effect_id", "") == "content.alpha.technique.reserve_survey"), "battle entry reports the passive capacity change as a factual event", failures)

	var snapshot = SaveMapper.suspend_snapshot(owned_domain)
	var first_resume: Dictionary = SaveMapper.load_into_domain(snapshot.to_dictionary(), registry)
	assert_true(first_resume.get("accepted", false), "the passive battle resumes from a stable BattleStart checkpoint", failures)
	if not first_resume.get("accepted", false):
		return
	assert_true(first_resume.domain.current_battle.combat_state.reserve_capacity == 4, "save reconstruction restores the passive capacity without reapplying it", failures)
	var second_snapshot = SaveMapper.suspend_snapshot(first_resume.domain)
	var second_resume: Dictionary = SaveMapper.load_into_domain(second_snapshot.to_dictionary(), registry)
	assert_true(second_resume.get("accepted", false), "a second passive battle reconstruction remains valid", failures)
	if second_resume.get("accepted", false):
		assert_true(second_resume.domain.current_battle.combat_state.reserve_capacity == 4, "repeated reconstruction never double-applies the passive", failures)

func test_stage_four_run_techniques_resolve_through_existing_commands_and_resume_replay(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	var phase2_registration = Phase2Catalog.register_all(registry)
	var act_two_registration = AlphaActTwoCatalog.register_all(registry)
	var scale_registration = AlphaScaleCatalog.register_all(registry)
	assert_true(phase2_registration.is_valid() and act_two_registration.is_valid() and scale_registration.is_valid(), "the full production catalogs register for Run Technique interaction coverage", failures)
	if not phase2_registration.is_valid() or not act_two_registration.is_valid() or not scale_registration.is_valid():
		return
	for technique_id in STAGE_FOUR_RUN_TECHNIQUE_IDS:
		var definition = registry.resolve(technique_id)
		assert_true(definition is TechniqueDefinition and not definition.effects.is_empty(), "%s is registered as typed production Technique content" % technique_id, failures)
	if STAGE_FOUR_RUN_TECHNIQUE_IDS.any(func(technique_id): return not registry.resolve(technique_id) is TechniqueDefinition):
		return

	var control := _stage_four_technique_domain("run.stage4.technique.control", 8321, registry, false)
	var domain := _stage_four_technique_domain("run.stage4.technique.effects", 8321, registry, true)
	var control_entry = control.execute(SelectMapNodeCommand.new("stage4.control.enter", control.map_definition.start_node_id))
	var entry = domain.execute(SelectMapNodeCommand.new("stage4.techniques.enter", domain.map_definition.start_node_id))
	assert_true(control_entry.is_accepted() and entry.is_accepted(), "the control and owned-Technique Runs enter the same authored Battle", failures)
	if not entry.is_accepted() or not control_entry.is_accepted():
		return
	var battle = domain.current_battle
	var control_battle = control.current_battle
	var unowned_before: Dictionary = control.checkpoint()
	var unowned_rng_before: Dictionary = control.rng_snapshot()
	var unowned_result = control.execute(UseTechniqueCommand.new("stage4.technique.unowned", STAGE_FOUR_RUN_TECHNIQUE_IDS[0]))
	assert_true(not unowned_result.is_accepted() and unowned_result.validation.code == "TECHNIQUE_NOT_OWNED", "a registered new Run Technique remains unavailable until owned", failures)
	assert_true(control.checkpoint() == unowned_before and control.rng_snapshot() == unowned_rng_before, "rejecting an unowned new Technique preserves Run state and every RNG stream", failures)
	assert_true(domain.state.gold == control.state.gold + 1, "Ledger Wind grants one Gold through the existing battle-entry passive path", failures)
	assert_true(domain.state.refinement_tokens == control.state.refinement_tokens + 1, "Refinement Practice grants one Refinement Token through the existing battle-entry passive path", failures)
	assert_true(battle.combat_state.tp == control_battle.combat_state.tp + 1, "First Measure grants one TP through the existing battle-entry passive path", failures)

	battle.combat_state.tp = 20
	domain.state.current_battle_snapshot = RunBattleSnapshot.new(battle.checkpoint())
	domain.replay_record = ReplayRecord.new(domain.state.seed, domain.state.content_version, domain.state.run_id)
	domain.replay_record.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), "ONGOING")
	var capacity_before: int = battle.combat_state.draw_capacity
	var draw_capacity_result = domain.execute(UseTechniqueCommand.new("stage4.technique.draw_capacity", "alpha.technique.draw_capacity"))
	assert_true(draw_capacity_result.is_accepted() and battle.combat_state.draw_capacity == capacity_before + 1, "Draw Capacity grants one existing Draw Action through UseTechniqueCommand", failures)

	var pressure_before: int = battle.combat_state.pressure
	var pressure_tp_before: int = battle.combat_state.tp
	var pressure_result = domain.execute(UseTechniqueCommand.new("stage4.technique.pressure_dividend", "alpha.technique.pressure_dividend"))
	assert_true(pressure_result.is_accepted() and battle.combat_state.pressure == pressure_before + 1, "Pressure Dividend applies its authored Pressure tradeoff", failures)
	assert_true(pressure_result.is_accepted() and battle.combat_state.tp == pressure_tp_before + 1, "Pressure Dividend grants three TP after paying its two-TP activation cost", failures)

	var enemy_hp_before: int = battle.combat_state.enemy_hp
	var strike_result = domain.execute(UseTechniqueCommand.new("stage4.technique.harbor_strike", "alpha.technique.harbor_strike"))
	assert_true(strike_result.is_accepted() and battle.combat_state.enemy_hp == enemy_hp_before - 4, "Harbor Strike deals four direct enemy damage", failures)

	var hand_before: int = battle.zones.size(TileZone.HAND)
	var stability_before: int = battle.combat_state.stability
	var draw_result = domain.execute(UseTechniqueCommand.new("stage4.technique.tide_draw", "alpha.technique.tide_draw"))
	assert_true(draw_result.is_accepted() and battle.zones.size(TileZone.HAND) == hand_before + 1, "Tide Draw adds one Tile to the Hand", failures)
	assert_true(draw_result.is_accepted() and battle.combat_state.stability == stability_before + 1, "Tide Draw also restores one Stability", failures)

	var save = SaveMapper.suspend_snapshot(domain)
	var resumed: Dictionary = SaveMapper.load_into_domain(save.to_dictionary(), registry)
	assert_true(resumed.get("accepted", false), "the updated Technique Run resumes through the existing Suspend pipeline", failures)
	if resumed.get("accepted", false):
		assert_true(resumed.domain.checkpoint() == domain.checkpoint(), "Suspend/Resume preserves every Technique effect and the Battle snapshot", failures)
		assert_true(resumed.domain.rng_snapshot() == domain.rng_snapshot(), "Suspend/Resume preserves the post-Technique RNG state", failures)

	var replay_factory := func(replay_seed: int, _replay_content_version: String):
		return _stage_four_technique_domain("run.stage4.technique.effects", replay_seed, registry, true, true)
	var replay_report = ReplayVerifier.verify(domain.replay_record, replay_factory, domain.state.content_version)
	assert_true(replay_report.is_match(), "the seven new Technique effects and accepted commands replay deterministically (%s)" % replay_report.reason, failures)

func _stage_four_technique_domain(run_id: String, seed: int, registry: ContentRegistry, own_stage_four_techniques: bool, enter_battle: bool = false) -> RunDomain:
	var domain := RunDomain.new(run_id, seed, registry)
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	if own_stage_four_techniques:
		for technique_id in STAGE_FOUR_RUN_TECHNIQUE_IDS:
			domain.state.build_ownership.run_technique_ids.append(technique_id)
	if enter_battle:
		var entry = domain.execute(SelectMapNodeCommand.new("%s.enter" % run_id, domain.map_definition.start_node_id))
		if entry.is_accepted():
			domain.current_battle.combat_state.tp = 20
			domain.state.current_battle_snapshot = RunBattleSnapshot.new(domain.current_battle.checkpoint())
			domain.replay_record = ReplayRecord.new(seed, domain.state.content_version, run_id)
			domain.replay_record.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), "ONGOING")
	return domain

func test_reaction_techniques_resolve_only_in_matching_windows(failures: Array[String]) -> void:
	var contamination_graph := IntentGraph.new("contamination", [
		EnemyIntent.new("contamination", "Contamination", 1, EnemyIntent.CONTAMINATION, [IntentTransition.fixed("contamination.loop", "contamination")]),
	])
	var clean_registry := _reaction_registry(contamination_graph, "base.technique.clean_table", TechniqueDefinition.REACTION_ENEMY_CONTAMINATION_ADDED, TechniqueDefinition.REACTION, 1, "PurgeContamination")
	var clean_domain := _prepared_domain_with_registry("run.reaction.clean", clean_registry)
	clean_domain.state.build_ownership.run_technique_ids.append("base.technique.clean_table")
	clean_domain.state.build_ownership.run_technique_ids.append("base.technique.tp_stability_support")
	var clean_entry = clean_domain.execute(SelectMapNodeCommand.new("reaction.clean.select", LEFT))
	assert_true(clean_entry.is_accepted(), "a contamination reaction enters a real Battle (%s: %s)" % [clean_entry.status, clean_entry.message], failures)
	if not clean_entry.is_accepted():
		return
	var tp_setup = clean_domain.execute(UseTechniqueCommand.new("reaction.clean.setup_tp", "base.technique.tp_stability_support"))
	assert_true(tp_setup.is_accepted() and clean_domain.current_battle.combat_state.tp == 3, "an accepted setup Technique supplies enough TP for a Reaction (%s: %s; TP=%d)" % [tp_setup.status, tp_setup.message, clean_domain.current_battle.combat_state.tp], failures)
	if not tp_setup.is_accepted():
		return
	var clean_snapshot = SaveMapper.suspend_snapshot(clean_domain)
	var clean_resume: Dictionary = SaveMapper.load_into_domain(clean_snapshot.to_dictionary(), clean_registry)
	assert_true(clean_resume.get("accepted", false), "a saved Battle reconstructs before its Reaction window", failures)
	if not clean_resume.get("accepted", false):
		return
	var clean_resumed: RunDomain = clean_resume.domain
	var clean_turn = clean_resumed.execute(EndTurnCommand.new("reaction.clean.end_turn"))
	assert_true(clean_turn.is_accepted(), "the matching enemy Contamination intent completes", failures)
	var clean_used = _event_of_type(clean_turn.events, DomainEvent.TECHNIQUE_USED)
	assert_true(clean_used != null and clean_used.data.get("technique_id", "") == "base.technique.clean_table", "Clean Table responds to the matching Contamination intent", failures)
	assert_true(clean_used != null and clean_used.data.get("reaction_trigger_id", "") == TechniqueDefinition.REACTION_ENEMY_CONTAMINATION_ADDED and clean_used.data.get("reaction_trigger_label", "") == "enemy Contamination is added", "the factual TechniqueUsed event names the declared trigger clearly", failures)
	var reaction_feedback: String = RunPresentationController.new(clean_resumed)._feedback_for_events(clean_turn.events)
	assert_true(reaction_feedback == "Clean Table responded when enemy Contamination is added.", "player-facing feedback explains when the Reaction responded (%s)" % reaction_feedback, failures)
	assert_true(_has_event(clean_turn.events, DomainEvent.REACTION_WINDOW_OPENED) and _has_event(clean_turn.events, DomainEvent.REACTION_WINDOW_CLOSED), "the matching Reaction resolves inside a bounded opened and closed window", failures)
	assert_true(_has_event(clean_turn.events, DomainEvent.TILE_PURGED), "Clean Table purges the newly added Contamination", failures)
	var reaction_sequence_indexes: Array[int] = []
	for event in clean_turn.events:
		if event.event_type not in [DomainEvent.REACTION_WINDOW_OPENED, DomainEvent.TP_CHANGED, DomainEvent.TECHNIQUE_USED, DomainEvent.TILE_PURGED, DomainEvent.REACTION_WINDOW_CLOSED]:
			continue
		reaction_sequence_indexes.append(int(event.data.get("sequence_index", -1)))
	var indexes_are_monotonic := reaction_sequence_indexes.size() >= 5
	for index in range(1, reaction_sequence_indexes.size()):
		indexes_are_monotonic = indexes_are_monotonic and reaction_sequence_indexes[index] > reaction_sequence_indexes[index - 1]
	assert_true(indexes_are_monotonic, "Reaction event indexes increase monotonically from open through cost, effect, and close", failures)
	assert_true(clean_resumed.current_battle.combat_state.tp == 2, "a resolving Reaction spends exactly its TP cost", failures)
	assert_true(clean_resumed.verify_replay().is_match(), "the accepted Reaction after resume reproduces deterministically", failures)

	var cleansing_registry := _reaction_registry(contamination_graph, "alpha.technique.cleansing_call", TechniqueDefinition.REACTION_ENEMY_CONTAMINATION_ADDED, TechniqueDefinition.REACTION, 2, "PurgeContamination")
	var cleansing_domain := _prepared_domain_with_registry("run.reaction.cleansing", cleansing_registry)
	cleansing_domain.state.build_ownership.run_technique_ids.append("alpha.technique.cleansing_call")
	cleansing_domain.state.build_ownership.run_technique_ids.append("base.technique.tp_stability_support")
	var cleansing_entry = cleansing_domain.execute(SelectMapNodeCommand.new("reaction.cleansing.select", LEFT))
	if cleansing_entry.is_accepted():
		cleansing_domain.execute(UseTechniqueCommand.new("reaction.cleansing.setup_tp", "base.technique.tp_stability_support"))
		var cleansing_turn = cleansing_domain.execute(EndTurnCommand.new("reaction.cleansing.end_turn"))
		var cleansing_used = _event_of_type(cleansing_turn.events, DomainEvent.TECHNIQUE_USED)
		assert_true(cleansing_turn.is_accepted() and cleansing_used != null and cleansing_used.data.get("technique_id", "") == "alpha.technique.cleansing_call", "Cleansing Call also responds to added enemy Contamination", failures)
		assert_true(cleansing_domain.current_battle.combat_state.tp == 1, "Cleansing Call pays its own declared TP cost", failures)
	else:
		assert_true(false, "Cleansing Call enters a Battle for matching-trigger coverage", failures)

	var nonmatching_registry := _reaction_registry(contamination_graph, "base.technique.reaction_guard", TechniqueDefinition.REACTION_ENEMY_STABILITY_LOST, TechniqueDefinition.REACTION, 2, "GainStability")
	var nonmatching_domain := _prepared_domain_with_registry("run.reaction.nonmatching", nonmatching_registry)
	nonmatching_domain.state.build_ownership.run_technique_ids.append("base.technique.reaction_guard")
	nonmatching_domain.state.build_ownership.run_technique_ids.append("base.technique.tp_stability_support")
	var nonmatching_entry = nonmatching_domain.execute(SelectMapNodeCommand.new("reaction.nonmatching.select", LEFT))
	if nonmatching_entry.is_accepted():
		nonmatching_domain.execute(UseTechniqueCommand.new("reaction.nonmatching.setup_tp", "base.technique.tp_stability_support"))
		var nonmatching_turn = nonmatching_domain.execute(EndTurnCommand.new("reaction.nonmatching.end_turn"))
		assert_true(nonmatching_turn.is_accepted() and not _has_event(nonmatching_turn.events, DomainEvent.TECHNIQUE_USED), "a Stability-loss Reaction does not answer a Contamination intent", failures)
		assert_true(not _has_event(nonmatching_turn.events, DomainEvent.REACTION_WINDOW_OPENED) and not _has_event(nonmatching_turn.events, DomainEvent.TECHNIQUE_REACTION_SKIPPED), "a nonmatching intent opens no Reaction window and reports no attempted response", failures)
		assert_true(nonmatching_domain.current_battle.combat_state.tp == 3, "a nonmatching Reaction spends no TP", failures)
	else:
		assert_true(false, "the nonmatching Reaction enters a Battle for trigger coverage", failures)

	var insufficient_registry := _reaction_registry(contamination_graph, "base.technique.clean_table", TechniqueDefinition.REACTION_ENEMY_CONTAMINATION_ADDED, TechniqueDefinition.REACTION, 1, "PurgeContamination")
	var insufficient_domain := _prepared_domain_with_registry("run.reaction.insufficient", insufficient_registry)
	insufficient_domain.state.build_ownership.run_technique_ids.append("base.technique.clean_table")
	var insufficient_entry = insufficient_domain.execute(SelectMapNodeCommand.new("reaction.insufficient.select", LEFT))
	if insufficient_entry.is_accepted():
		var insufficient_turn = insufficient_domain.execute(EndTurnCommand.new("reaction.insufficient.end_turn"))
		var skipped = _event_of_type(insufficient_turn.events, DomainEvent.TECHNIQUE_REACTION_SKIPPED)
		assert_true(insufficient_turn.is_accepted() and skipped != null and skipped.data.get("reason", "") == "INSUFFICIENT_TP", "a matching Reaction with insufficient TP reports why it could not fire", failures)
		var skipped_feedback: String = RunPresentationController.new(insufficient_domain)._feedback_for_events(insufficient_turn.events)
		assert_true(skipped_feedback.contains("enemy Contamination is added") and skipped_feedback.contains("INSUFFICIENT_TP"), "player-facing feedback explains an unaffordable Reaction", failures)
		assert_true(not _has_event(insufficient_turn.events, DomainEvent.TECHNIQUE_USED) and not _has_event(insufficient_turn.events, DomainEvent.REACTION_WINDOW_OPENED), "insufficient TP does not spend cost or open a response window", failures)
		assert_true(insufficient_domain.current_battle.combat_state.tp == 0 and not _has_event(insufficient_turn.events, DomainEvent.TILE_PURGED), "an unaffordable Reaction leaves its effect unapplied and TP unchanged", failures)
	else:
		assert_true(false, "the unaffordable Reaction enters a Battle for TP coverage", failures)

	var interference_graph := IntentGraph.new("interference", [
		EnemyIntent.new("interference", "Table Interference", 1, EnemyIntent.TABLE_INTERFERENCE, [IntentTransition.fixed("interference.loop", "interference")]),
	])
	var guard_registry := _reaction_registry(interference_graph, "base.technique.reaction_guard", TechniqueDefinition.REACTION_ENEMY_STABILITY_LOST, TechniqueDefinition.REACTION, 2, "GainStability")
	var guard_domain := _prepared_domain_with_registry("run.reaction.guard", guard_registry)
	guard_domain.state.build_ownership.run_technique_ids.append("base.technique.reaction_guard")
	guard_domain.state.build_ownership.run_technique_ids.append("base.technique.tp_stability_support")
	var guard_entry = guard_domain.execute(SelectMapNodeCommand.new("reaction.guard.select", LEFT))
	if guard_entry.is_accepted():
		guard_domain.execute(UseTechniqueCommand.new("reaction.guard.setup_tp", "base.technique.tp_stability_support"))
		var stability_before: int = guard_domain.current_battle.combat_state.stability
		var guard_snapshot = SaveMapper.suspend_snapshot(guard_domain)
		var guard_resume: Dictionary = SaveMapper.load_into_domain(guard_snapshot.to_dictionary(), guard_registry)
		assert_true(guard_resume.get("accepted", false), "the Table Interference Battle resumes before its Reaction window", failures)
		if not guard_resume.get("accepted", false):
			return
		guard_domain = guard_resume.domain
		var guard_turn = guard_domain.execute(EndTurnCommand.new("reaction.guard.end_turn"))
		var guard_used = _event_of_type(guard_turn.events, DomainEvent.TECHNIQUE_USED)
		assert_true(guard_turn.is_accepted() and guard_used != null and guard_used.data.get("reaction_trigger_id", "") == TechniqueDefinition.REACTION_ENEMY_STABILITY_LOST, "Reaction Guard answers Stability loss caused by Table Interference", failures)
		assert_true(guard_domain.current_battle.combat_state.stability == stability_before, "Reaction Guard restores the Stability lost by the matching intent", failures)
		assert_true(guard_domain.current_battle.combat_state.tp == 1, "Table Interference Reaction spends the declared TP", failures)
		assert_true(guard_domain.verify_replay().is_match(), "the accepted Table Interference Reaction reproduces deterministically", failures)
	else:
		assert_true(false, "Reaction Guard enters an interference Battle", failures)

func test_boss_phases_are_explicit_and_deterministic(failures: Array[String]) -> void:
	var first_domain := _prepared_domain("run.boss.first")
	var first_battle = first_domain.encounter_factory.create(first_domain.state, "base.encounter.boss", first_domain.rng_streams, EncounterDefinition.BOSS)
	assert_true(first_battle != null, "the Boss encounter factory creates a BattleDomain", failures)
	if first_battle == null:
		return
	first_domain.current_battle = first_battle
	first_domain.state.phase = RunPhase.BATTLE
	var first_state = first_battle.combat_state
	var preserved_tp: int = first_state.tp
	var first_phase_result = first_battle.combat_resolver.resolve_player_action(first_state, 2)

	assert_true(first_phase_result.terminal_outcome == CombatState.ONGOING, "a non-final Boss phase does not terminate the battle", failures)
	assert_true(first_state.boss_phase_index == 1, "Boss phase index advances at a queue boundary", failures)
	assert_true(first_state.boss_phase_id == "table_interference", "Boss phase identity is explicit domain state", failures)
	assert_true(first_state.enemy_hp == 2 and first_state.enemy_max_hp == 2 and first_state.pressure_limit == 8, "the next Boss phase loads its own battle values", failures)
	assert_true(first_state.current_intent.intent_id == "interference", "Boss phase transition resets the public Intent Graph", failures)
	assert_true(first_state.tp == preserved_tp, "Boss phase transition preserves the continuous battle context", failures)
	assert_true(_has_event(first_phase_result.events, DomainEvent.BOSS_PHASE_CHANGED), "Boss phase transition emits a factual Domain event", failures)

	var second_domain := _prepared_domain("run.boss.second")
	var second_battle = second_domain.encounter_factory.create(second_domain.state, "base.encounter.boss", second_domain.rng_streams, EncounterDefinition.BOSS)
	assert_true(second_battle != null, "the Boss encounter factory creates a repeatable BattleDomain", failures)
	if second_battle == null:
		return
	second_domain.current_battle = second_battle
	second_domain.state.phase = RunPhase.BATTLE
	var second_phase_result = second_battle.combat_resolver.resolve_player_action(second_battle.combat_state, 2)
	assert_true(first_phase_result.to_dictionary() == second_phase_result.to_dictionary(), "same seed and Boss input reproduce the phase transition", failures)

	var final_phase_result = first_battle.combat_resolver.resolve_player_action(first_state, 2)
	var final_phase_result_2 = first_battle.combat_resolver.resolve_player_action(first_state, 2)
	assert_true(final_phase_result.terminal_outcome == CombatState.ONGOING, "the second Boss phase also remains non-terminal", failures)
	assert_true(final_phase_result_2.terminal_outcome == CombatState.VICTORY, "only the final Boss phase produces Victory", failures)
	first_domain.apply_battle_outcome()
	assert_true(first_domain.state.phase == RunPhase.BOSS_REWARD, "Boss victory opens BOSS_REWARD", failures)
	assert_true(first_domain.state.reward_draft != null and first_domain.state.reward_draft.options.size() == 3, "Boss victory creates a three-choice Rule Breaker draft", failures)

func test_factory_rejects_invalid_enemy_without_mutation(failures: Array[String]) -> void:
	var registry := _registry()
	registry.register(EncounterDefinition.new(
		"base.encounter.invalid.enemy",
		["base.enemy.missing"],
		EncounterDefinition.NORMAL,
	))
	var domain := _prepared_domain_with_registry("run.invalid.encounter", registry)
	var checkpoint_before: Dictionary = domain.checkpoint()
	var rng_before: Dictionary = domain.rng_snapshot()
	var battle = domain.encounter_factory.create(domain.state, "base.encounter.invalid.enemy", domain.rng_streams, EncounterDefinition.NORMAL)

	assert_true(battle == null, "an encounter with a missing EnemyDefinition is rejected", failures)
	assert_true(domain.encounter_factory.last_error.get("status", "") == "INVALID_ENEMY_ID", "factory rejection reports the missing EnemyDefinition", failures)
	assert_true(domain.checkpoint() == checkpoint_before, "factory rejection leaves RunState unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "factory rejection leaves every RNG stream unchanged", failures)

func test_draw_actions_are_limited_and_reset_each_turn(failures: Array[String]) -> void:
	var first_domain: RunDomain = _prepared_domain("run.draw.budget")
	var second_domain := _prepared_domain("run.draw.budget")
	var replacement_domain := _prepared_domain("run.draw.replacement")
	var first_selection = first_domain.execute(SelectMapNodeCommand.new("draw.budget.select", LEFT))
	var second_selection = second_domain.execute(SelectMapNodeCommand.new("draw.budget.select", LEFT))
	var replacement_selection = replacement_domain.execute(SelectMapNodeCommand.new("draw.replacement.select", LEFT))
	assert_true(first_selection.is_accepted() and second_selection.is_accepted(), "Draw budget setup enters equivalent Battles", failures)
	assert_true(replacement_selection.is_accepted(), "replacement draw setup enters a Battle", failures)
	if not first_selection.is_accepted() or not second_selection.is_accepted() or not replacement_selection.is_accepted():
		return
	var capacity := int(first_domain.current_battle.combat_state.draw_capacity)
	assert_true(capacity >= 2, "the fixture Battle has multiple Draw Actions to spend", failures)
	if capacity < 2:
		return
	var replacement = replacement_domain.current_battle.tile_actions.draw(DrawSource.SETTLEMENT_REPLACEMENT)
	assert_true(replacement.is_accepted(), "a settlement replacement draw is available in the fixture", failures)
	assert_true(replacement_domain.current_battle.combat_state.draw_actions_used_this_turn == 0, "a replacement draw does not spend a normal Draw Action", failures)

	for turn_index in 2:
		for draw_index in capacity:
			var command_id := "draw.budget.turn.%d.draw.%d" % [turn_index, draw_index]
			var first_draw = first_domain.execute(DrawCommand.new(command_id))
			var second_draw = second_domain.execute(DrawCommand.new(command_id))
			assert_true(first_draw.is_accepted() and second_draw.is_accepted(), "a Draw Action within capacity is accepted", failures)
			assert_true(
				first_domain.checkpoint().get("state_hash", "") == second_domain.checkpoint().get("state_hash", ""),
				"identical seeded Draw Actions produce identical checkpoints",
				failures,
			)
			if turn_index == 0 and draw_index == capacity - 2:
				var saved = SaveCoordinator.new().save(first_domain)
				assert_true(saved.get("accepted", false), "a partially spent Draw Action budget can be saved", failures)
				if saved.get("accepted", false):
					var loaded = SaveMapper.load_into_domain(saved.snapshot.to_dictionary(), first_domain.content_registry)
					assert_true(loaded.accepted, "a mid-turn save restores (%s)" % loaded.get("code", ""), failures)
					if loaded.accepted:
						assert_true(
							loaded.domain.current_battle.combat_state.draw_actions_used_this_turn == draw_index + 1,
							"Suspend/Resume preserves Draw Actions already spent this turn",
							failures,
						)
						assert_true(loaded.domain.checkpoint() == first_domain.checkpoint(), "Suspend/Resume preserves the authoritative battle checkpoint", failures)
						first_domain = loaded.domain
		var checkpoint_before_rejected_draw: Dictionary = first_domain.checkpoint()
		var replay_count_before_rejected_draw: int = first_domain.replay_record.commands.size()
		var rejected_command_id := "draw.budget.turn.%d.exhausted" % turn_index
		var first_rejected = first_domain.execute(DrawCommand.new(rejected_command_id))
		var second_rejected = second_domain.execute(DrawCommand.new(rejected_command_id))
		assert_true(not first_rejected.is_accepted() and not second_rejected.is_accepted(), "a Draw Action beyond capacity is rejected", failures)
		assert_true(first_rejected.validation.code == "DRAW_ACTION_BUDGET_EXHAUSTED", "exhaustion reports the authoritative Draw Action budget", failures)
		assert_true(first_domain.checkpoint() == checkpoint_before_rejected_draw, "rejected Draw Actions leave the checkpoint unchanged", failures)
		assert_true(first_domain.replay_record.commands.size() == replay_count_before_rejected_draw, "rejected Draw Actions are omitted from replay", failures)
		assert_true(
			first_domain.checkpoint().get("state_hash", "") == second_domain.checkpoint().get("state_hash", ""),
			"identical seeded rejection decisions preserve deterministic checkpoints",
			failures,
		)
		if turn_index == 0:
			var first_end_turn = first_domain.execute(EndTurnCommand.new("draw.budget.turn.end"))
			var second_end_turn = second_domain.execute(EndTurnCommand.new("draw.budget.turn.end"))
			assert_true(first_end_turn.is_accepted() and second_end_turn.is_accepted(), "End Turn is accepted after Draw Action exhaustion", failures)
			assert_true(
				first_domain.checkpoint().get("state_hash", "") == second_domain.checkpoint().get("state_hash", ""),
				"identical seeded End Turns produce identical checkpoints",
				failures,
			)
	assert_true(second_domain.verify_replay().is_match(), "accepted Draw Actions and End Turn replay deterministically", failures)

func test_draw_capacity_changes_preserve_remaining_actions(failures: Array[String]) -> void:
	var domain := _prepared_domain("run.draw.capacity")
	var selection = domain.execute(SelectMapNodeCommand.new("draw.capacity.select", LEFT))
	assert_true(selection.is_accepted(), "Draw capacity setup enters a Battle", failures)
	if not selection.is_accepted():
		return
	var initial_capacity := int(domain.current_battle.combat_state.draw_capacity)
	var first_draw = domain.execute(DrawCommand.new("draw.capacity.first"))
	assert_true(first_draw.is_accepted(), "an initial Draw Action is accepted before a capacity change", failures)
	domain.current_battle.combat_state.draw_capacity += 1
	assert_true(
		domain.current_battle.combat_state.draw_actions_remaining() == initial_capacity,
		"increasing Draw Capacity grants one remaining action without refunding a spent action",
		failures,
	)
	for index in initial_capacity:
		var result = domain.execute(DrawCommand.new("draw.capacity.modified.%d" % index))
		assert_true(result.is_accepted(), "a Draw Action granted by changed capacity is accepted", failures)
	var rejected = domain.execute(DrawCommand.new("draw.capacity.modified.exhausted"))
	assert_true(not rejected.is_accepted() and rejected.validation.code == "DRAW_ACTION_BUDGET_EXHAUSTED", "changed capacity remains subject to authoritative exhaustion", failures)

func _registry(normal_intent_graph = null) -> ContentRegistry:
	var registry := ContentRegistry.new()
	RunStartingPoolContentFixture.register_character_starting_pool_tiles(registry)
	registry.register(RelicDefinition.new("base.relic.open_hand"))
	registry.register(TechniqueDefinition.new("base.technique.core.sequence_line", TechniqueDefinition.CORE, 1))
	registry.register(ContentDefinition.new("base.passive.sequence"))
	registry.register(CharacterDefinition.new(
		"base.character.sequence",
		RunStartingPoolContentFixture.character_tile_pool_bias(),
		"base.relic.open_hand",
		"base.technique.core.sequence_line",
		"base.passive.sequence",
	))
	registry.register(ContractDefinition.new("base.contract.pressure", ContractDefinition.PRESSURE, {"pressure": 1}, {"draw_actions": 1}))
	var graph = normal_intent_graph
	if graph == null:
		graph = IntentGraph.new("pressure", [
			EnemyIntent.new("pressure", "Pressure", 1, EnemyIntent.PRESSURE, [IntentTransition.fixed("pressure.loop", "pressure")]),
		])
	var enemy := EnemyDefinition.new(
		"base.enemy.wall_taxer",
		graph,
		EnemyDefinition.NORMAL,
		17,
		{"pressure_limit": 9},
		{"kind": "wall_tax"},
	)
	registry.register(enemy)
	registry.register(EncounterDefinition.new(
		"base.encounter.intro",
		["base.enemy.wall_taxer"],
		EncounterDefinition.NORMAL,
	))
	registry.register(EncounterDefinition.new(
		"base.encounter.normal.left",
		["base.enemy.wall_taxer"],
		EncounterDefinition.NORMAL,
	))
	var elite := EnemyDefinition.new(
		"base.enemy.ledger_hunter",
		graph,
		EnemyDefinition.ELITE,
		13,
		{"pressure_limit": 8},
	)
	registry.register(elite)
	registry.register(EncounterDefinition.new(
		"base.encounter.elite",
		["base.enemy.ledger_hunter"],
		EncounterDefinition.ELITE,
	))
	var tempo_graph := IntentGraph.new("tempo", [
		EnemyIntent.new("tempo", "Tempo", 1, EnemyIntent.PRESSURE, [IntentTransition.fixed("tempo.loop", "tempo")]),
	])
	var interference_graph := IntentGraph.new("interference", [
		EnemyIntent.new("interference", "Table Interference", 2, EnemyIntent.PRESSURE, [IntentTransition.fixed("interference.loop", "interference")]),
	])
	var rule_graph := IntentGraph.new("rule_breaker", [
		EnemyIntent.new("rule_breaker", "Rule Breaker", 3, EnemyIntent.PRESSURE, [IntentTransition.fixed("rule_breaker.loop", "rule_breaker")]),
	])
	var boss_phases: Array = [
		{"phase_id": "tempo", "intent_graph": tempo_graph, "max_hp": 2, "pressure_limit": 9, "pressure_relief": 1},
		{"phase_id": "table_interference", "intent_graph": interference_graph, "max_hp": 2, "pressure_limit": 9, "pressure_relief": 1, "battle_values": {"pressure_limit": 8}},
		{"phase_id": "rule_breaker", "intent_graph": rule_graph, "max_hp": 2, "pressure_limit": 9, "pressure_relief": 1},
	]
	var boss := EnemyDefinition.new("base.boss.table_breaker", tempo_graph, EnemyDefinition.BOSS, 2, {}, {}, boss_phases)
	registry.register(boss)
	registry.register(EncounterDefinition.new(
		"base.encounter.boss",
		["base.boss.table_breaker"],
		EncounterDefinition.BOSS,
	))
	var boss_reward_entries: Array = []
	for index in Phase2Catalog.BOSS_RULE_BREAKER_IDS.size():
		var rule_breaker_id: String = Phase2Catalog.BOSS_RULE_BREAKER_IDS[index]
		registry.register(RuleBreakerDefinition.new(rule_breaker_id, "TEST_RULE_%d" % index, 1))
		boss_reward_entries.append({"content_id": rule_breaker_id, "weight": 1})
	registry.register(RewardPoolDefinition.new(
		Phase2Catalog.BOSS_RULE_BREAKER_POOL_ID,
		boss_reward_entries,
		[],
		RewardPoolDefinition.REWARD,
	))
	return registry

func _prepared_domain(run_id: String) -> RunDomain:
	return _prepared_domain_with_registry(run_id, _registry())

func _prepared_domain_with_registry(run_id: String, registry: ContentRegistry) -> RunDomain:
	var domain := RunDomain.new(run_id, 1234, registry)
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	return domain

func _reaction_registry(graph, technique_id: String, trigger_id: String, kind: String, tp_cost: int, operation_id: String) -> ContentRegistry:
	var registry := _registry(graph)
	var effect_amount: int = 1 if operation_id == "GainStability" else 0
	var reaction_effect: Variant = Phase2Catalog.typed_effect("content.%s" % technique_id, operation_id, effect_amount)
	var reaction = TechniqueDefinition.new(technique_id, kind, tp_cost, [reaction_effect], [], trigger_id)
	registry.register(reaction)
	var support_effects: Array = [
		Phase2Catalog.typed_effect("content.base.technique.tp_stability_support.tp", "GainTP", 3),
		Phase2Catalog.typed_effect("content.base.technique.tp_stability_support.stability", "GainStability", 1),
	]
	registry.register(TechniqueDefinition.new("base.technique.tp_stability_support", TechniqueDefinition.ACTIVE, 0, support_effects))
	return registry

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func _event_of_type(events: Array, event_type: String):
	for event in events:
		if event.event_type == event_type:
			return event
	return null

func _property(instance, property_name: String, default_value = null):
	if instance == null or not instance.has_method("get"):
		return default_value
	var value = instance.get(property_name)
	return default_value if value == null else value

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
