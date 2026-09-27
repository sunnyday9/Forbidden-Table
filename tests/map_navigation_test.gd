class_name MapNavigationTest
extends RefCounted

const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const MiniActMapCatalog = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const RunStartingPoolContentFixture = preload("res://tests/fixtures/run_starting_pool_content_fixture.gd")
const Phase2V1BossRewardSuspendSnapshotFixture = preload("res://tests/fixtures/phase2_v1_boss_reward_suspend_snapshot.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunTileInstanceRecord = preload("res://src/domain/run/run_tile_instance_record.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const ChooseRewardCommand = preload("res://src/domain/commands/choose_reward_command.gd")
const SaveCoordinator = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const ReplayRecord = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifier = preload("res://src/infrastructure/replay/replay_verifier.gd")
const ActiveEffectInstance = preload("res://src/domain/effects/active_effect_instance.gd")
const DurationSpec = preload("res://src/domain/effects/duration_spec.gd")
const StackPolicy = preload("res://src/domain/effects/stack_policy.gd")
const RunEconomy = preload("res://src/domain/run/run_economy.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const RelicDefinition = preload("res://src/content/definitions/relic_definition.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")

const INTRO := "base.map_node.intro"
const LEFT := "base.map_node.normal.left"
const RIGHT := "base.map_node.normal.right"
const SHOP := "base.map_node.shop"
const WORKSHOP := "base.map_node.workshop"
const EVENT_LEFT := "base.map_node.event.left"
const EVENT_RIGHT := "base.map_node.event.right"
const MID := "base.map_node.normal.mid"
const ELITE := "base.map_node.elite"
const BOSS := "base.map_node.boss"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_authored_graph_is_bounded_and_route_safe(failures)
	test_act_two_authored_graph_meets_the_same_topology_contract(failures)
	test_act_two_map_payload_starts_its_authored_encounter(failures)
	test_contract_choice_initializes_visible_deterministic_map(failures)
	test_mandatory_intro_battle_is_played_and_resumeable_for_both_acts(failures)
	test_valid_route_reaches_boss_and_records_stable_edge_path(failures)
	test_every_authored_route_reaches_boss(failures)
	test_invalid_map_selection_is_atomic_and_does_not_consume_map_rng(failures)
	test_same_seed_and_accepted_map_commands_reproduce_checkpoint(failures)
	test_map_command_serializes_stable_node_id(failures)
	test_act_one_boss_reward_starts_a_fresh_act_two_map(failures)
	test_act_transition_carries_run_effects_and_clears_act_interactions(failures)
	test_act_two_map_identity_round_trips_at_stable_boundary(failures)
	test_act_two_boss_reward_selection_ends_run_without_act_three(failures)
	return failures

func test_act_one_boss_reward_starts_a_fresh_act_two_map(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var v1_snapshot = Phase2V1BossRewardSuspendSnapshotFixture.suspend_snapshot()
	var migrated = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(v1_snapshot, registry)
	if not migrated.accepted:
		assert_true(false, "the archived stable Boss boundary migrates through the public load pipeline", failures)
		return
	migrated.domain.state.act_count = 2
	migrated.domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
		"map.act-boundary.tile-1",
		"base.tile.characters.1",
		"RUN",
		"RUN",
	))
	migrated.domain.state.build_ownership.owned_relic_ids.append("base.relic.open_hand")
	migrated.domain.state.build_ownership.run_technique_ids.append("base.technique.draw_surge")
	var stable_save = SaveCoordinator.new().save(migrated.domain)
	if not stable_save.accepted:
		assert_true(false, "the Boss reward fixture is saved through the public stable-save seam", failures)
		return
	var resumed = SaveMapper.load_into_domain(stable_save.snapshot.to_dictionary(), registry)
	if not resumed.accepted:
		assert_true(false, "the stable Boss reward snapshot resumes through the public load pipeline", failures)
		return
	var domain = resumed.domain
	var run_id: String = domain.state.run_id
	var seed: int = domain.state.seed
	var content_version: String = domain.state.content_version
	var character_id: String = domain.state.character_id
	var contract_id: String = domain.state.contract_id
	var act_one_map_id: String = domain.map_definition.content_id
	var draft = domain.state.reward_draft
	var tile_pool_before: Dictionary = domain.state.tile_pool.to_dictionary()
	var build_before: Dictionary = domain.state.build_ownership.to_dictionary()
	assert_true(domain.state.act_index == 1 and domain.state.phase == RunPhase.BOSS_REWARD, "the pending Act 1 Boss reward cannot transition before selection", failures)
	if draft == null or draft.options.is_empty():
		assert_true(false, "Act 1 Boss victory creates a selectable reward", failures)
		return
	domain.replay_record = ReplayRecord.new(domain.state.seed, domain.state.content_version, domain.state.run_id)
	domain.replay_record.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), domain.state.terminal_summary.outcome)
	var result = domain.execute(ChooseRewardCommand.new(
		"map.act-boundary.reward",
		draft.options[0].option_id,
		draft.draft_id,
	))

	assert_true(result.accepted, "applying the Act 1 Boss reward is accepted", failures)
	assert_true(domain.state.run_id == run_id and domain.state.seed == seed, "the Act transition stays in the same seeded Run", failures)
	assert_true(domain.state.content_version == content_version and domain.state.character_id == character_id and domain.state.contract_id == contract_id, "the Act transition carries the Run's version, Character, and Contract", failures)
	assert_true(domain.state.act_index == 2, "the existing RunState advances to Act 2", failures)
	assert_true(domain.state.tile_pool.to_dictionary() == tile_pool_before, "the Run-owned Tile Pool carries unchanged across the Act boundary", failures)
	assert_true(domain.state.build_ownership.owned_relic_ids == build_before.owned_relic_ids, "owned Relics carry unchanged across the Act boundary", failures)
	assert_true(domain.state.build_ownership.run_technique_ids == build_before.run_technique_ids, "owned Run Techniques carry unchanged across the Act boundary", failures)
	assert_true(domain.state.build_ownership.acquired_rule_breaker_ids.size() == 1 and domain.state.build_ownership.acquired_rule_breaker_ids[0] == draft.options[0].content_id, "the selected Act 1 Boss Rule Breaker remains owned in Act 2", failures)
	assert_true(domain.state.phase == RunPhase.MAP_CHOICE, "applying the Act 1 Boss reward enters Act 2 instead of Run Summary", failures)
	assert_true(domain.map_definition.content_id == "base.map.act_two" and domain.map_definition.content_id != act_one_map_id, "the Act transition selects a distinct Act 2 map definition", failures)
	assert_true(domain.state.map_state.map_definition_id == "base.map.act_two", "the Run map state records the fresh Act 2 map", failures)
	assert_true(domain.state.map_state.current_node_id == "base.map_node.act_two.intro" and domain.state.map_state.ordered_path.is_empty(), "the Act 2 map starts with its own mandatory entry pending", failures)
	var replay_factory: Callable = func(replay_seed: int, replay_content_version: String):
		if replay_seed != seed or replay_content_version != content_version:
			return null
		var replayed = SaveMapper.load_into_domain(stable_save.snapshot.to_dictionary(), registry)
		return replayed.domain if replayed.accepted else null
	var replay_report = ReplayVerifier.verify(domain.replay_record, replay_factory, content_version)
	assert_true(replay_report.is_match(), "replaying the Act 1 Boss reward transition reproduces the fresh Act 2 map", failures)

func test_act_transition_carries_run_effects_and_clears_act_interactions(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var migrated = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(
		Phase2V1BossRewardSuspendSnapshotFixture.suspend_snapshot(),
		registry,
	)
	if not migrated.accepted:
		assert_true(false, "the effect-scope fixture starts from the archived stable Boss boundary", failures)
		return
	var source = migrated.domain
	source.state.act_count = 2
	source.economy.apply_source(source.state, RunEconomy.REFINEMENT_TOKENS, 7, RunEconomy.SOURCE_BOSS_REWARD)
	source.state.tutorial_state.active_step_id = "tutorial.act_one.complete"
	source.state.tutorial_state.completed_step_ids.append("tutorial.first_run")
	var run_effect := ActiveEffectInstance.new("fixture.effect.run", DurationSpec.new(DurationSpec.RUN, 3), StackPolicy.new(StackPolicy.UNIQUE), "fixture")
	var battle_effect := ActiveEffectInstance.new("fixture.effect.battle", DurationSpec.new(DurationSpec.BATTLE, 2), StackPolicy.new(StackPolicy.UNIQUE), "fixture")
	var act_effect := ActiveEffectInstance.new("fixture.effect.act", DurationSpec.new(DurationSpec.ACT, 2), StackPolicy.new(StackPolicy.UNIQUE), "fixture")
	source.state.active_effects = {
		run_effect.instance_id: run_effect,
		battle_effect.instance_id: battle_effect,
		act_effect.instance_id: act_effect,
	}
	source.state.shop_state.begin("base.map_node.shop", "fixture.shop", [], 1, {})
	source.state.workshop_state.begin("base.map_node.workshop", "fixture.workshop")
	var event_definition = registry.resolve("base.event.risk_bargain")
	source.state.event_state.begin("base.map_node.event.left", "fixture.event", event_definition, source.rng_streams.event.snapshot())
	var stable_save = SaveCoordinator.new().save(source)
	if not stable_save.accepted:
		assert_true(false, "the configured state is saved at the stable Boss reward boundary", failures)
		return
	var resumed = SaveMapper.load_into_domain(stable_save.snapshot.to_dictionary(), registry)
	if not resumed.accepted:
		assert_true(false, "the fixture resumes before the Act transition", failures)
		return
	var domain = resumed.domain
	var active_reward = domain.state.reward_draft
	var carried_run_effect = domain.state.active_effects[run_effect.instance_id].to_dictionary()
	var result = domain.execute(ChooseRewardCommand.new(
		"map.act-boundary.effects.reward",
		active_reward.options[0].option_id,
		active_reward.draft_id,
	))

	assert_true(result.accepted, "the Boss reward applies through the public command seam", failures)
	assert_true(domain.state.gold == 10 and domain.state.refinement_tokens == 7, "Gold and Refinement Tokens carry unchanged", failures)
	assert_true(domain.state.tutorial_state.to_dictionary() == {
		"active_step_id": "tutorial.act_one.complete",
		"completed_step_ids": ["tutorial.first_run"],
	}, "tutorial progress carries unchanged", failures)
	assert_true(domain.state.active_effects.keys() == [run_effect.instance_id], "only the Run-scoped effect remains active after the Act boundary", failures)
	assert_true(domain.state.active_effects[run_effect.instance_id].to_dictionary() == carried_run_effect, "the Run-scoped effect's exact duration and runtime state carry unchanged", failures)
	assert_true(not domain.state.shop_state.active and domain.state.shop_state.node_id.is_empty(), "the prior Shop interaction is discarded", failures)
	assert_true(not domain.state.workshop_state.active and domain.state.workshop_state.node_id.is_empty(), "the prior Workshop interaction is discarded", failures)
	assert_true(not domain.state.event_state.active and domain.state.event_state.event_id.is_empty(), "the prior Event interaction is discarded", failures)
	assert_true(domain.state.current_battle_snapshot == null and domain.current_battle == null, "no prior battle snapshot or BattleDomain crosses the Act boundary", failures)

func test_act_two_map_identity_round_trips_at_stable_boundary(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	_register_act_two_encounter_content(registry)
	var migrated = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(
		Phase2V1BossRewardSuspendSnapshotFixture.suspend_snapshot(),
		registry,
	)
	if not migrated.accepted:
		assert_true(false, "the resume fixture reaches an Act 1 Boss reward from the archived save", failures)
		return
	var domain = migrated.domain
	domain.state.act_count = 2
	var source_save = SaveCoordinator.new().save(domain)
	if not source_save.accepted:
		assert_true(false, "the Act 1 Boss reward is captured at a stable boundary", failures)
		return
	var source_resume = SaveMapper.load_into_domain(source_save.snapshot.to_dictionary(), registry)
	if not source_resume.accepted:
		assert_true(false, "the Act 1 Boss reward resumes before selection", failures)
		return
	domain = source_resume.domain
	var draft = domain.state.reward_draft
	var selected = domain.execute(ChooseRewardCommand.new(
		"map.act-two-resume.reward",
		draft.options[0].option_id,
		draft.draft_id,
	))
	if not selected.accepted:
		assert_true(false, "the Act 1 Boss reward applies before the Act 2 save boundary", failures)
		return
	var act_two_save = SaveCoordinator.new().save(domain)
	if not act_two_save.accepted:
		assert_true(false, "the fresh Act 2 map is a stable Suspend boundary", failures)
		return
	var act_two_resume = SaveMapper.load_into_domain(act_two_save.snapshot.to_dictionary(), registry)
	if not act_two_resume.accepted:
		assert_true(false, "an Act 2 map checkpoint resumes through the normal SaveMapper pipeline", failures)
		return
	var resumed_domain = act_two_resume.domain
	assert_true(resumed_domain.state.act_index == 2, "Suspend/Resume preserves the Act 2 index", failures)
	assert_true(resumed_domain.map_definition.content_id == "base.map.act_two", "Suspend/Resume reconstructs the Act 2 MapDefinition", failures)
	assert_true(resumed_domain.state.map_state.map_definition_id == "base.map.act_two", "Suspend/Resume preserves the Act 2 path identity", failures)
	assert_true(resumed_domain.state.map_state.current_node_id == "base.map_node.act_two.intro", "Suspend/Resume preserves the mandatory Act 2 entry node", failures)
	assert_true(not resumed_domain.state.map_state.is_visited(resumed_domain.map_definition.start_node_id), "Suspend/Resume keeps the Act 2 intro pending", failures)
	var intro = resumed_domain.execute(SelectMapNodeCommand.new("map.act-two-resume.intro", resumed_domain.map_definition.start_node_id))
	assert_true(intro.accepted and resumed_domain.state.phase == RunPhase.BATTLE, "the resumed Act 2 MapDefinition starts its mandatory intro battle", failures)

func test_act_two_boss_reward_selection_ends_run_without_act_three(failures: Array[String]) -> void:
	var domain = _act_two_boss_reward_boundary()
	if domain == null:
		assert_true(false, "the Act 2 Boss reward fixture resumes at a stable boundary", failures)
		return
	var draft = domain.state.reward_draft
	assert_true(domain.state.act_index == 2 and domain.state.phase == RunPhase.BOSS_REWARD, "the Act 2 Boss reward remains pending before selection", failures)
	assert_true(domain.state.map_state.current_node_id == "base.map_node.act_two.boss", "the pending reward belongs to the terminal Act 2 Boss", failures)
	if draft == null or draft.options.is_empty():
		assert_true(false, "the pending Act 2 Boss has a selectable reward", failures)
		return
	var pending_checkpoint: Dictionary = domain.checkpoint()
	var invalid = domain.execute(ChooseRewardCommand.new(
		"map.act-two-boss.invalid",
		"reward.missing",
		draft.draft_id,
	))
	assert_true(not invalid.accepted and domain.checkpoint() == pending_checkpoint, "an invalid choice leaves the Act 2 Boss reward pending without transitioning", failures)
	var selected = domain.execute(ChooseRewardCommand.new(
		"map.act-two-boss.selected",
		draft.options[0].option_id,
		draft.draft_id,
	))
	assert_true(selected.accepted, "the Act 2 Boss reward applies through ChooseRewardCommand", failures)
	assert_true(domain.state.phase == RunPhase.RUN_SUMMARY, "the selected Act 2 Boss reward reaches Normal Ending and Run Summary", failures)
	assert_true(domain.state.terminal_summary.outcome == "VICTORY" and domain.state.terminal_summary.reason == "BOSS_DEFEATED", "the Act 2 Boss outcome is a normal Run victory", failures)
	assert_true(domain.state.terminal_summary.summary_data.get("act_index", 0) == 2 and domain.state.act_index == 2, "the ending records Act 2 without advancing to an optional Act 3", failures)
	assert_true(domain.map_definition.content_id == "base.map.act_two" and domain.state.map_state.map_definition_id == "base.map.act_two", "Run Summary retains the completed Act 2 context and creates no Act 3 map", failures)
	assert_true(domain.state.reward_draft == null, "the selected Boss reward is consumed before the ending", failures)

func _act_two_boss_reward_boundary():
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var migrated = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(
		Phase2V1BossRewardSuspendSnapshotFixture.suspend_snapshot(),
		registry,
	)
	if not migrated.accepted:
		return null
	var domain = migrated.domain
	domain.state.act_count = 2
	domain.state.act_index = 2
	domain.map_definition = MiniActMapCatalog.definition_for_act(2)
	domain.state.map_state.initialize(domain.map_definition, domain.rng_streams.map)
	for node_id in [
		"base.map_node.act_two.intro",
		"base.map_node.act_two.normal.left",
		"base.map_node.act_two.shop",
		"base.map_node.act_two.workshop",
		"base.map_node.act_two.normal.mid",
		"base.map_node.act_two.elite",
		"base.map_node.act_two.boss",
	]:
		domain.state.map_state.select_node(node_id, domain.map_definition)
	var save = SaveCoordinator.new().save(domain)
	if not save.accepted:
		return null
	var resumed = SaveMapper.load_into_domain(save.snapshot.to_dictionary(), registry)
	return resumed.domain if resumed.accepted else null

func test_authored_graph_is_bounded_and_route_safe(failures: Array[String]) -> void:
	var definition = MiniActMapCatalog.definition()
	var issues: Array = definition.graph_issues()
	assert_true(issues.is_empty(), "the authored Mini-Act graph has no topology issues", failures)
	assert_true(definition.node_ids.size() == 10, "the Mini-Act graph has exactly ten authored nodes", failures)
	assert_true(definition.count_nodes_of_kind("BATTLE") == 4, "the graph has four Normal battle nodes", failures)
	assert_true(definition.count_nodes_of_kind("ELITE") == 1, "the graph has one Elite node", failures)
	assert_true(definition.count_nodes_of_kind("SHOP") == 1, "the graph has one Shop node", failures)
	assert_true(definition.count_nodes_of_kind("WORKSHOP") == 1, "the graph has one Workshop node", failures)
	assert_true(definition.count_nodes_of_kind("EVENT") == 2, "the graph has two Event opportunities", failures)
	assert_true(definition.count_nodes_of_kind("BOSS") == 1, "the graph has one Boss node", failures)
	assert_true(definition.start_node_id == INTRO, "the graph starts at the mandatory introductory Normal", failures)
	assert_true(definition.branch_decision_count_before(ELITE) >= 2, "at least two branch decisions precede the Elite", failures)
	assert_true(definition.has_route_through([SHOP, WORKSHOP], BOSS), "a valid route exposes both Shop and Workshop", failures)

func test_act_two_authored_graph_meets_the_same_topology_contract(failures: Array[String]) -> void:
	var definition = MiniActMapCatalog.definition_for_act(2)
	var act_one = MiniActMapCatalog.definition_for_act(1)
	assert_true(definition != null, "Act 2 has an authored MapDefinition", failures)
	if definition == null:
		return
	assert_true(definition.content_id == "base.map.act_two", "Act 2 uses its own stable map identity", failures)
	assert_true(definition.graph_issues().is_empty(), "every Act 2 node is reachable and every route can reach its terminal Boss", failures)
	assert_true(definition.node_ids.size() == 10, "Act 2 has the ten-node planning baseline", failures)
	assert_true(definition.count_nodes_of_kind("BATTLE") == 4, "Act 2 has four Normal nodes including its mandatory first battle", failures)
	assert_true(definition.count_nodes_of_kind("ELITE") == 1, "Act 2 has one Elite", failures)
	assert_true(definition.count_nodes_of_kind("SHOP") == 1, "Act 2 has one Shop", failures)
	assert_true(definition.count_nodes_of_kind("WORKSHOP") == 1, "Act 2 has one Workshop", failures)
	assert_true(definition.count_nodes_of_kind("EVENT") >= 2, "Act 2 has at least two Event opportunities", failures)
	assert_true(definition.count_nodes_of_kind("BOSS") == 1, "Act 2 has one terminal Boss", failures)
	assert_true(definition.start_node_id == "base.map_node.act_two.intro", "Act 2 starts at its own mandatory Normal node", failures)
	assert_true(definition.branch_decision_count_before("base.map_node.act_two.elite") >= 2, "Act 2 has meaningful branches before the Elite", failures)
	assert_true(definition.has_route_through(["base.map_node.act_two.shop", "base.map_node.act_two.workshop"], "base.map_node.act_two.boss"), "an Act 2 route exposes both services before the Boss", failures)
	assert_true(definition.node_ids.filter(func(node_id: String): return act_one.node_ids.has(node_id)).is_empty(), "Act 2 node IDs are distinct from the preserved Act 1 topology", failures)
	for node_id in definition.node_ids:
		var node = definition.node_definition(node_id)
		if node.node_kind in ["BATTLE", "ELITE", "BOSS"]:
			assert_true(node.content_reference_id.begins_with("alpha.encounter.act_two."), "%s binds an Act 2 encounter" % node_id, failures)
		if node.node_kind == "EVENT":
			assert_true(node.content_reference_id.begins_with("alpha.event.act_two."), "%s binds an Act 2 Event" % node_id, failures)

func test_act_two_map_payload_starts_its_authored_encounter(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	var domain := RunDomain.new("map.act-two.payload", 902, registry, "", null, 2)
	domain.execute(ChooseCharacterCommand.new("map.act-two.payload.character", "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("map.act-two.payload.contract", "base.contract.pressure"))
	domain.state.act_index = 2
	domain.map_definition = MiniActMapCatalog.act_two_definition()
	domain.state.map_state.initialize(domain.map_definition, domain.rng_streams.map)
	domain.state.phase = RunPhase.MAP_CHOICE
	var repeated_domain := RunDomain.new("map.act-two.payload.repeated", 902, registry, "", null, 2)
	repeated_domain.execute(ChooseCharacterCommand.new("map.act-two.payload.repeated.character", "base.character.sequence"))
	repeated_domain.execute(ChooseContractCommand.new("map.act-two.payload.repeated.contract", "base.contract.pressure"))
	repeated_domain.state.act_index = 2
	repeated_domain.map_definition = MiniActMapCatalog.act_two_definition()
	repeated_domain.state.map_state.initialize(repeated_domain.map_definition, repeated_domain.rng_streams.map)
	repeated_domain.state.phase = RunPhase.MAP_CHOICE
	assert_true(domain.state.map_state.payload_ids == repeated_domain.state.map_state.payload_ids, "same-seed Act 2 initialization selects identical encounter and Event payloads", failures)
	var intro_node_id: String = domain.map_definition.start_node_id
	assert_true(domain.state.map_state.current_node_id == intro_node_id, "the Act 2 mandatory entry starts at its authored node", failures)
	var selected_node_id := intro_node_id
	var encounter_id := str(domain.state.map_state.payload_ids[selected_node_id])
	var selected = domain.execute(SelectMapNodeCommand.new("map.act-two.payload.intro", selected_node_id))
	assert_true(selected.accepted, "the Act 2 mandatory intro battle is selectable through RunDomain (%s: %s)" % [selected.validation.code, selected.validation.message], failures)
	assert_true(encounter_id.begins_with("alpha.encounter.act_two."), "the visible Act 2 payload points to its authored encounter package", failures)
	assert_true(domain.current_battle != null, "selecting the Act 2 entry payload creates a Battle", failures)
	if domain.current_battle != null:
		assert_true(domain.current_battle.encounter_id == encounter_id, "the reached Battle uses the map's selected Act 2 encounter identity", failures)
		assert_true(domain.current_battle.enemy_definition.content_id == "alpha.enemy.act_two.tollkeeper", "the mandatory Act 2 intro encounter uses its authored Tollkeeper enemy", failures)
	var boss_node = domain.map_definition.node_definition("base.map_node.act_two.boss")
	var boss_encounter_id := str(boss_node.payload_options[0])
	var boss_validation: Dictionary = domain.encounter_factory.validate(domain.state, boss_encounter_id, "BOSS")
	assert_true(boss_validation.get("accepted", false), "the Act 2 Boss encounter passes EncounterFactory validation (%s: %s)" % [boss_validation.get("status", ""), boss_validation.get("message", "")], failures)
	var boss_battle = domain.encounter_factory.create(domain.state, boss_encounter_id, domain.rng_streams, "BOSS")
	assert_true(boss_battle != null, "the Act 2 Boss encounter creates through EncounterFactory", failures)
	if boss_battle != null:
		assert_true(boss_battle.enemy_definition.content_id == "alpha.boss.act_two.final_index", "the Act 2 Boss payload resolves to its own EnemyDefinition", failures)
		assert_true(boss_battle.combat_state.boss_phase_count >= 3, "the Act 2 Boss installs its multi-phase combat state", failures)

func test_contract_choice_initializes_visible_deterministic_map(failures: Array[String]) -> void:
	var domain := _prepared_domain("map.visibility", 101)
	var map_state = domain.state.map_state

	assert_true(domain.state.phase == RunPhase.MAP_CHOICE, "Contract choice enters Map Choice", failures)
	assert_true(map_state.current_node_id == INTRO, "the mandatory introductory Normal is the current node", failures)
	assert_true(map_state.ordered_path.is_empty() and map_state.visited_node_ids.is_empty(), "the introductory Normal is pending before its battle", failures)
	assert_true(map_state.selectable_node_ids(domain.map_definition) == [INTRO], "the pending entry is the only selectable Map Node", failures)
	assert_true(map_state.knowledge_state[INTRO] == "EXACT", "the current node identity is exact", failures)
	assert_true(map_state.knowledge_state[LEFT] == "EXACT", "an immediately selectable node is exact", failures)
	assert_true(map_state.knowledge_state[BOSS] == "PARTIAL", "a distant node keeps partial identity visibility", failures)
	assert_true(map_state.node_kinds[BOSS] == "BOSS", "topology exposes a distant node's kind", failures)
	assert_true(map_state.visible_payload_id(LEFT) == map_state.payload_ids[LEFT], "an adjacent node exposes its payload identity", failures)
	assert_true(map_state.visible_payload_id(BOSS).is_empty(), "a distant node hides its payload identity", failures)
	assert_true(map_state.payload_ids.size() == 10, "every authored node receives a deterministic payload ID", failures)
	assert_true(map_state.edge_ids.size() == 12, "every authored edge has a stable edge ID", failures)
	assert_true(not map_state.map_rng_state.is_empty(), "map state records the Map RNG checkpoint", failures)

func test_mandatory_intro_battle_is_played_and_resumeable_for_both_acts(failures: Array[String]) -> void:
	var domains: Array = [
		_prepared_alpha_domain("map.intro.act-one", 701),
		_transitioned_act_two_entry_domain("map.intro.act-two"),
	]
	for act_offset in domains.size():
		var domain = domains[act_offset]
		if domain == null:
			assert_true(false, "Act 2 enters its fresh map through the Boss reward transition", failures)
			continue
		var intro_id: String = domain.map_definition.start_node_id
		var intro = domain.map_definition.node_definition(intro_id)
		var branch_id := str(intro.next_node_ids[0])
		assert_true(domain.state.phase == RunPhase.MAP_CHOICE, "Act %d begins at Map Choice" % domain.state.act_index, failures)
		assert_true(domain.state.map_state.current_node_id == intro_id, "Act %d points at its authored introductory Normal" % domain.state.act_index, failures)
		assert_true(not domain.state.map_state.is_visited(intro_id), "Act %d leaves the mandatory intro pending until it is fought" % domain.state.act_index, failures)

		var entry_save = SaveCoordinator.new().save(domain)
		assert_true(entry_save.accepted, "Act %d can be saved before the intro battle" % domain.state.act_index, failures)
		if not entry_save.accepted:
			continue
		var resumed = SaveMapper.load_into_domain(entry_save.snapshot.to_dictionary(), domain.content_registry)
		assert_true(resumed.accepted, "Act %d resumes before the intro battle" % domain.state.act_index, failures)
		if not resumed.accepted:
			continue
		domain = resumed.domain
		assert_true(domain.state.map_state.payload_ids[intro_id] == entry_save.snapshot.authoritative_state.map_state.payload_ids[intro_id], "Act %d preserves the deterministic intro payload on resume" % domain.state.act_index, failures)
		var branch_before_entry = domain.validate_select_map_node(branch_id)
		assert_true(not branch_before_entry.is_valid(), "Act %d cannot select a branch before its intro battle" % domain.state.act_index, failures)

		var intro_payload_id: String = str(domain.state.map_state.payload_ids[intro_id])
		var intro_selection = domain.execute(SelectMapNodeCommand.new("%s.intro" % domain.state.run_id, intro_id))
		assert_true(intro_selection.accepted and domain.state.phase == RunPhase.BATTLE, "Act %d starts its mandatory intro battle through SelectMapNode" % domain.state.act_index, failures)
		assert_true(domain.current_battle != null and domain.current_battle.encounter_id == intro_payload_id, "Act %d fights the exact encounter selected by its deterministic intro payload" % domain.state.act_index, failures)
		assert_true(_has_event(intro_selection.events, DomainEvent.MAP_NODE_SELECTED) and _has_event(intro_selection.events, DomainEvent.BATTLE_STARTED) and _has_event(intro_selection.events, DomainEvent.RUN_PHASE_CHANGED), "Act %d intro entry emits map, battle, and phase facts" % domain.state.act_index, failures)
		assert_true(not domain.validate_select_map_node(branch_id).is_valid(), "Act %d cannot select a branch during its intro battle" % domain.state.act_index, failures)

		var battle_save = SaveCoordinator.new().save(domain)
		assert_true(battle_save.accepted, "Act %d can be saved at the intro battle start" % domain.state.act_index, failures)
		if not battle_save.accepted:
			continue
		var battle_resume = SaveMapper.load_into_domain(battle_save.snapshot.to_dictionary(), domain.content_registry)
		assert_true(battle_resume.accepted, "Act %d resumes at the same intro battle" % domain.state.act_index, failures)
		if not battle_resume.accepted:
			continue
		domain = battle_resume.domain
		assert_true(domain.current_battle != null and domain.current_battle.encounter_id == intro_payload_id, "Act %d resumes the intro encounter payload" % domain.state.act_index, failures)
		if domain.current_battle == null:
			continue
		domain.current_battle.combat_state.enemy_hp = 1
		var victory = domain.current_battle.combat_resolver.resolve_player_action(domain.current_battle.combat_state, 17)
		assert_true(victory.terminal_outcome == "VICTORY", "Act %d intro encounter is actually resolved as a battle" % domain.state.act_index, failures)
		domain.apply_battle_outcome()
		assert_true(domain.state.phase == RunPhase.REWARD_CHOICE, "Act %d intro victory reaches its normal Reward Choice" % domain.state.act_index, failures)
		if domain.state.reward_draft == null or domain.state.reward_draft.options.is_empty():
			assert_true(false, "Act %d intro victory creates its Normal reward draft" % domain.state.act_index, failures)
			continue
		var reward_option = domain.state.reward_draft.options[0]
		var reward_result = domain.execute(ChooseRewardCommand.new(
			"%s.intro.reward" % domain.state.run_id,
			reward_option.option_id,
			domain.state.reward_draft.draft_id,
		))
		assert_true(reward_result.accepted and domain.state.phase == RunPhase.MAP_CHOICE, "Act %d returns to Map Choice after the intro reward" % domain.state.act_index, failures)
		var available_branches: Array = domain.state.map_state.selectable_node_ids(domain.map_definition)
		assert_true(available_branches == intro.next_node_ids, "Act %d exposes its authored branch only after the intro battle and reward" % domain.state.act_index, failures)
		var branch_result = domain.execute(SelectMapNodeCommand.new("%s.branch" % domain.state.run_id, branch_id))
		assert_true(branch_result.accepted, "Act %d can progress from the intro to its selected branch" % domain.state.act_index, failures)

func _prepared_alpha_domain(run_id: String, seed: int) -> RunDomain:
	var registry := _phase2_registry()
	var domain = RunDomain.new_alpha_run(run_id, seed, registry)
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	return domain

func _transitioned_act_two_entry_domain(run_id: String):
	var registry := _phase2_registry()
	var migrated = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(
		Phase2V1BossRewardSuspendSnapshotFixture.suspend_snapshot(),
		registry,
	)
	if not migrated.accepted:
		return null
	var domain = migrated.domain
	_register_act_two_encounter_content(registry)
	domain.state.act_count = 2
	var saved = SaveCoordinator.new().save(domain)
	if not saved.accepted:
		return null
	var resumed = SaveMapper.load_into_domain(saved.snapshot.to_dictionary(), registry)
	if not resumed.accepted:
		return null
	domain = resumed.domain
	var draft = domain.state.reward_draft
	if draft == null or draft.options.is_empty():
		return null
	var selected = domain.execute(ChooseRewardCommand.new(
		"%s.act-one-boss-reward" % run_id,
		draft.options[0].option_id,
		draft.draft_id,
	))
	return domain if selected.accepted and domain.state.act_index == 2 and domain.state.phase == RunPhase.MAP_CHOICE else null

func _phase2_registry() -> ContentRegistry:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	return registry

func test_valid_route_reaches_boss_and_records_stable_edge_path(failures: Array[String]) -> void:
	var domain := _prepared_domain("map.route", 202)
	for node_id in [INTRO, LEFT, SHOP, WORKSHOP, MID, ELITE, BOSS]:
		var result = domain.execute(SelectMapNodeCommand.new("map.route.%s" % node_id, node_id))
		assert_true(result.accepted, "valid route accepts %s" % node_id, failures)

	assert_true(domain.state.map_state.current_node_id == BOSS, "the valid route reaches the Boss", failures)
	assert_true(domain.state.map_state.ordered_path == [INTRO, LEFT, SHOP, WORKSHOP, MID, ELITE, BOSS], "the map path records stable node IDs", failures)
	assert_true(domain.state.map_state.path_edge_ids.size() == 6, "the map path records one stable edge per transition", failures)
	assert_true(domain.state.map_state.to_dictionary().has("edge_ids"), "map serialization includes authored edge IDs", failures)
	assert_true(domain.state.map_state.to_dictionary().has("payload_ids"), "map serialization includes payload IDs", failures)
	assert_true(domain.state.map_state.to_dictionary().has("knowledge_state"), "map serialization includes knowledge state", failures)
	assert_true(_has_event(domain.state.map_state.last_events, DomainEvent.MAP_NODE_SELECTED), "map traversal emits a factual selection event", failures)

func test_every_authored_route_reaches_boss(failures: Array[String]) -> void:
	var route_choices := [[INTRO, LEFT, SHOP, WORKSHOP], [INTRO, LEFT, EVENT_LEFT], [INTRO, RIGHT, WORKSHOP], [INTRO, RIGHT, EVENT_RIGHT]]
	for route_index in route_choices.size():
		var domain := _prepared_domain("map.route.%d" % route_index, 250 + route_index)
		for node_id in route_choices[route_index] + [MID, ELITE, BOSS]:
			var result = domain.execute(SelectMapNodeCommand.new("map.route.%d.%s" % [route_index, node_id], node_id))
			assert_true(result.accepted, "authored route %d accepts %s" % [route_index, node_id], failures)
		assert_true(domain.state.map_state.current_node_id == BOSS, "authored route %d reaches the Boss" % route_index, failures)

func test_invalid_map_selection_is_atomic_and_does_not_consume_map_rng(failures: Array[String]) -> void:
	var domain := _prepared_domain("map.invalid", 303)
	var before := domain.checkpoint()
	var rng_before := domain.rng_snapshot()
	var unknown = domain.execute(SelectMapNodeCommand.new("map.invalid.unknown", "base.map_node.missing"))
	assert_true(not unknown.accepted, "an unknown node ID is rejected", failures)
	assert_true(unknown.validation.code == "INVALID_MAP_NODE_ID", "unknown node rejection is explicit", failures)
	assert_true(domain.checkpoint() == before, "unknown node selection leaves state unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "unknown node selection does not consume Map RNG", failures)

	var non_adjacent = domain.execute(SelectMapNodeCommand.new("map.invalid.far", WORKSHOP))
	assert_true(not non_adjacent.accepted, "a non-adjacent node is rejected", failures)
	assert_true(non_adjacent.validation.code == "NON_ADJACENT_NODE", "non-adjacent rejection is explicit", failures)
	assert_true(domain.checkpoint() == before, "non-adjacent selection leaves state unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "non-adjacent selection does not consume Map RNG", failures)

	domain.execute(SelectMapNodeCommand.new("map.invalid.intro", INTRO))
	domain.execute(SelectMapNodeCommand.new("map.invalid.left", LEFT))
	var visited_before := domain.checkpoint()
	var visited_rng_before := domain.rng_snapshot()
	var visited = domain.execute(SelectMapNodeCommand.new("map.invalid.visited", INTRO))
	assert_true(not visited.accepted and visited.validation.code == "VISITED_NODE", "a visited node is rejected", failures)
	assert_true(domain.checkpoint() == visited_before, "visited selection leaves state unchanged", failures)
	assert_true(domain.rng_snapshot() == visited_rng_before, "visited selection does not consume Map RNG", failures)

	for node_id in [SHOP, WORKSHOP, MID, ELITE, BOSS]:
		domain.execute(SelectMapNodeCommand.new("map.invalid.path.%s" % node_id, node_id))
	var terminal_before := domain.checkpoint()
	var terminal_rng_before := domain.rng_snapshot()
	var terminal = domain.execute(SelectMapNodeCommand.new("map.invalid.terminal", BOSS))
	assert_true(not terminal.accepted and terminal.validation.code == "TERMINAL_NODE", "a terminal-node selection is rejected", failures)
	assert_true(domain.checkpoint() == terminal_before, "terminal selection leaves state unchanged", failures)
	assert_true(domain.rng_snapshot() == terminal_rng_before, "terminal selection does not consume Map RNG", failures)

func test_same_seed_and_accepted_map_commands_reproduce_checkpoint(failures: Array[String]) -> void:
	var first := _prepared_domain("map.deterministic", 404)
	var second := _prepared_domain("map.deterministic", 404)
	for node_id in [INTRO, RIGHT, EVENT_RIGHT, MID, ELITE, BOSS]:
		first.execute(SelectMapNodeCommand.new("map.deterministic.%s" % node_id, node_id))
		second.execute(SelectMapNodeCommand.new("map.deterministic.%s" % node_id, node_id))
	assert_true(first.state.map_state.payload_ids == second.state.map_state.payload_ids, "same seed reproduces map payload IDs", failures)
	assert_true(first.state.map_state.knowledge_state == second.state.map_state.knowledge_state, "same seed reproduces reveal state", failures)
	assert_true(first.state.map_state.ordered_path == second.state.map_state.ordered_path, "same seed reproduces map path", failures)
	assert_true(first.checkpoint().state_hash == second.checkpoint().state_hash, "same seed and commands reproduce the checkpoint hash", failures)

func test_map_command_serializes_stable_node_id(failures: Array[String]) -> void:
	var command := SelectMapNodeCommand.new("map.ids.select", LEFT, "player.1")
	var data := command.to_dictionary()
	assert_true(data["command_type"] == "SelectMapNode", "map command has a stable command type", failures)
	assert_true(data["node_id"] == LEFT, "map command serializes a stable node ID", failures)
	assert_true(not data.has("node_index"), "map command does not serialize a UI index", failures)

func _prepared_domain(run_id: String, seed: int) -> RunDomain:
	var domain := RunDomain.new(run_id, seed, _registry())
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	return domain

func _registry() -> ContentRegistry:
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
	return registry

func _register_act_two_encounter_content(registry: ContentRegistry) -> void:
	for definition in AlphaActTwoCatalog.definitions():
		if definition.definition_type_name() in ["EnemyDefinition", "EncounterDefinition"]:
			registry.register(definition)

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
