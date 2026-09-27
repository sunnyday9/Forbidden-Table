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
const DrawSource = preload("res://src/domain/tiles/draw_source.gd")
const SaveCoordinator = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")

const LEFT := "base.map_node.intro"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_normal_node_creates_isolated_data_driven_battle(failures)
	test_battle_outcome_transfer_opens_reward_or_terminates(failures)
	test_reward_tax_survives_save_replay_and_taxes_victory_once(failures)
	test_authored_intent_types_resolve_for_normal_elite_and_boss(failures)
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
