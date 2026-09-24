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
const RunTileInstanceRecord = preload("res://src/domain/run/run_tile_instance_record.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const ResolveEnemyIntentCommand = preload("res://src/domain/commands/resolve_enemy_intent_command.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")

const LEFT := "base.map_node.normal.left"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_normal_node_creates_isolated_data_driven_battle(failures)
	test_battle_outcome_transfer_opens_reward_or_terminates(failures)
	test_boss_phases_are_explicit_and_deterministic(failures)
	test_factory_rejects_invalid_enemy_without_mutation(failures)
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

	var result = domain.execute(SelectMapNodeCommand.new("battle.entry.select", LEFT))
	var battle = domain.get("current_battle")
	var combat_state = _property(battle, "combat_state")
	var context = _property(battle, "context")
	var enemy_definition = _property(battle, "enemy_definition")

	assert_true(result.accepted, "a configured Normal node is accepted", failures)
	assert_true(domain.state.phase == RunPhase.BATTLE, "a configured Normal node enters BATTLE", failures)
	assert_true(_has_event(result.events, DomainEvent.BATTLE_STARTED), "battle entry emits an explicit BattleStarted event", failures)
	assert_true(battle != null, "RunDomain creates a BattleDomain child", failures)
	assert_true(_property(battle, "encounter_id", "") == "base.encounter.normal.left", "the battle uses the authored encounter identity", failures)
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
	assert_true(domain.state.tile_pool.to_dictionary()["tile_instances"].size() == 1, "child battle state does not mutate the Run Tile Pool before outcome", failures)

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

func _registry() -> ContentRegistry:
	var registry := ContentRegistry.new()
	registry.register(TileDefinition.new("base.tile.characters.1", "characters", 1))
	registry.register(RelicDefinition.new("base.relic.open_hand"))
	registry.register(TechniqueDefinition.new("base.technique.core.sequence_line", TechniqueDefinition.CORE, 1))
	registry.register(ContentDefinition.new("base.passive.sequence"))
	registry.register(CharacterDefinition.new(
		"base.character.sequence",
		["base.tile.characters.1"],
		"base.relic.open_hand",
		"base.technique.core.sequence_line",
		"base.passive.sequence",
	))
	registry.register(ContractDefinition.new("base.contract.pressure", ContractDefinition.PRESSURE, {"pressure": 1}, {"draw_actions": 1}))
	var graph := IntentGraph.new("pressure", [
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

func _property(instance, property_name: String, default_value = null):
	if instance == null or not instance.has_method("get"):
		return default_value
	var value = instance.get(property_name)
	return default_value if value == null else value

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
