class_name RewardEconomyTest
extends RefCounted

const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const EnemyDefinition = preload("res://src/content/definitions/enemy_definition.gd")
const EncounterDefinition = preload("res://src/content/definitions/encounter_definition.gd")
const EnemyIntent = preload("res://src/domain/combat/enemy_intent.gd")
const IntentGraph = preload("res://src/domain/combat/intent_graph.gd")
const IntentTransition = preload("res://src/domain/combat/intent_transition.gd")
const RelicDefinition = preload("res://src/content/definitions/relic_definition.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RewardDraftSelector = preload("res://src/domain/run/reward_draft_selector.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunStartingPoolContentFixture = preload("res://tests/fixtures/run_starting_pool_content_fixture.gd")
const RunTileInstanceRecord = preload("res://src/domain/run/run_tile_instance_record.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinition = preload("res://src/content/definitions/tile_modifier_definition.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const ChooseRewardCommand = preload("res://src/domain/commands/choose_reward_command.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const RewardOption = preload("res://src/domain/run/reward_option.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")

const LEFT := "base.map_node.normal.left"
const INTRO := "base.map_node.intro"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_normal_victory_creates_a_three_option_draft(failures)
	test_same_seed_repeats_the_normal_draft(failures)
	test_normal_draft_excludes_tiles_at_the_copy_limit(failures)
	test_skip_is_legal_and_pays_configured_compensation(failures)
	test_reward_flow_rebinds_after_resume(failures)
	test_add_tile_selection_updates_the_run_build_and_returns_to_map(failures)
	test_stale_add_tile_option_is_rejected_at_the_copy_limit(failures)
	test_forged_add_tile_option_is_rejected_at_the_copy_limit(failures)
	test_modified_tile_selection_updates_persistent_modifier_state(failures)
	test_invalid_selection_is_atomic(failures)
	return failures

func test_normal_victory_creates_a_three_option_draft(failures: Array[String]) -> void:
	var domain := _victorious_domain("reward.victory")
	var draft = domain.state.reward_draft

	assert_true(domain.state.phase == RunPhase.REWARD_CHOICE, "Normal victory enters Reward Choice", failures)
	assert_true(draft != null, "Normal victory creates an authoritative reward draft", failures)
	if draft == null:
		return
	assert_true(draft.options.size() == 3, "Normal victory creates exactly three conceptual options", failures)
	assert_true(_find_option(draft, RewardOption.SKIP) != null, "every Normal draft includes Skip", failures)
	assert_true(_has_acquisition_option(draft), "Normal draft includes an acquisition option", failures)
	assert_true(not draft.draft_id.is_empty(), "the draft has a stable ID", failures)
	for option in draft.options:
		assert_true(not option.option_id.is_empty(), "every reward option has a stable selection ID", failures)
		assert_true(option.kind != RewardOption.SKIP or option.gold_delta > 0, "Skip carries configured compensation", failures)
	assert_true(_has_event(domain.state.map_state.last_events, DomainEvent.REWARD_DRAFT_CREATED), "draft creation is a factual domain event", failures)

func test_same_seed_repeats_the_normal_draft(failures: Array[String]) -> void:
	var first := _victorious_domain("reward.same-seed")
	var second := _victorious_domain("reward.same-seed")
	assert_true(first.state.reward_draft != null and second.state.reward_draft != null, "same-seed fixtures both create drafts", failures)
	if first.state.reward_draft == null or second.state.reward_draft == null:
		return
	assert_true(first.state.reward_draft.to_dictionary() == second.state.reward_draft.to_dictionary(), "same seed and accepted inputs repeat the reward draft", failures)
	assert_true(first.rng_snapshot()["streams"]["reward"] == second.rng_snapshot()["streams"]["reward"], "same seed repeats the Reward RNG checkpoint", failures)

func test_normal_draft_excludes_tiles_at_the_copy_limit(failures: Array[String]) -> void:
	var domain := _victorious_domain("reward.copy-limit.filter", 3)
	var repeat := _victorious_domain("reward.copy-limit.filter", 3)
	var generated_draft = domain.state.reward_draft
	assert_true(generated_draft != null, "a full-copy Run still creates a Normal reward draft", failures)
	if generated_draft == null:
		return
	assert_true(_find_option(generated_draft, RewardOption.MODIFIED_TILE) != null, "a full-copy Run preserves its generated Modified Tile option", failures)
	assert_true(_find_option(generated_draft, RewardOption.SKIP) != null, "a full-copy Run preserves its generated Skip option", failures)
	var available_add_tile_count := 0
	for option in generated_draft.options:
		if option.kind != RewardOption.ADD_TILE:
			continue
		available_add_tile_count += 1
		assert_true(_tile_definition_count(domain, option.tile_id) < domain.economy.tile_copy_limit, "the generated full-copy draft never offers a capped TileDefinition", failures)
	assert_true(available_add_tile_count > 0, "other TileDefinitions remain selectable when one definition is full", failures)
	var full_only_registry := ContentRegistry.new()
	full_only_registry.register(TileDefinition.new("base.tile.characters.1", "characters", 1))
	full_only_registry.register(TileModifierDefinition.new("base.modifier.ritual_mark", "RITUAL_MARK", 1))
	var selector := RewardDraftSelector.new()
	var draft = selector.create_normal_draft(domain.state, full_only_registry, domain.rng_streams.reward, "reward.copy-limit.only-full", 0)
	var repeat_draft = selector.create_normal_draft(repeat.state, full_only_registry, repeat.rng_streams.reward, "reward.copy-limit.only-full", 0)
	assert_true(draft != null, "a Run at the tile copy limit still receives a Normal reward draft", failures)
	if draft == null:
		return
	var add_tile_count := 0
	for option in draft.options:
		if option.kind != RewardOption.ADD_TILE:
			continue
		add_tile_count += 1
		assert_true(_tile_definition_count(domain, option.tile_id) < domain.economy.tile_copy_limit, "Normal drafts omit Add Tile options for TileDefinitions at the copy limit", failures)
	assert_true(add_tile_count == 0, "Normal drafts omit a full-copy TileDefinition even when it is the only candidate", failures)
	assert_true(_find_option(draft, RewardOption.SKIP) != null, "reaching a TileDefinition copy limit preserves Skip", failures)
	assert_true(repeat_draft != null, "the repeated same-seed selector call creates a draft", failures)
	if repeat_draft == null:
		return
	assert_true(repeat_draft.to_dictionary() == draft.to_dictionary(), "copy-limit filtering preserves same-seed draft determinism", failures)
	assert_true(repeat.rng_snapshot()["streams"]["reward"] == domain.rng_snapshot()["streams"]["reward"], "copy-limit filtering preserves same-seed Reward RNG state", failures)

func test_skip_is_legal_and_pays_configured_compensation(failures: Array[String]) -> void:
	var domain := _victorious_domain("reward.skip")
	var draft = domain.state.reward_draft
	var skip = _find_option(draft, RewardOption.SKIP)
	assert_true(skip != null, "the Skip option is available to select", failures)
	if skip == null:
		return
	var result = domain.execute(ChooseRewardCommand.new("reward.skip.choose", skip.option_id, draft.draft_id))

	assert_true(result.accepted, "Skip is accepted during Reward Choice", failures)
	assert_true(result.replayable, "an accepted reward selection is replayable", failures)
	assert_true(domain.state.gold == skip.gold_delta, "Skip applies its configured Gold compensation", failures)
	assert_true(domain.state.refinement_tokens == 0, "Skip does not create Refinement Tokens", failures)
	assert_true(domain.state.reward_draft == null, "accepted Skip clears the active draft", failures)
	assert_true(domain.state.phase == RunPhase.MAP_CHOICE, "accepted Skip returns the run to Map Choice", failures)
	assert_true(_has_event(result.events, DomainEvent.REWARD_SELECTED), "reward selection emits a factual domain event", failures)
	assert_true(result.data.get("option_id", "") == skip.option_id, "the result records the selected stable option ID", failures)

func test_reward_flow_rebinds_after_resume(failures: Array[String]) -> void:
	var source := _victorious_domain("reward.resume")
	var draft = source.state.reward_draft
	var skip = _find_option(draft, RewardOption.SKIP)
	assert_true(skip != null, "a reward checkpoint has a Skip choice to resolve after resume", failures)
	if skip == null:
		return
	var snapshot = SaveMapper.suspend_snapshot(source)
	var restored = SaveMapper.load_into_domain(snapshot.to_dictionary(), source.content_registry)
	assert_true(restored.accepted, "a pending Normal reward draft restores", failures)
	if not restored.accepted:
		return
	var restored_domain = restored.domain
	var gold_before: int = restored_domain.state.gold
	var result = restored_domain.execute(ChooseRewardCommand.new("reward.resume.choose", skip.option_id, draft.draft_id))
	assert_true(result.accepted, "the restored domain accepts the reward choice", failures)
	assert_true(restored_domain.state.gold == gold_before + skip.gold_delta, "the Reward flow applies Gold to the restored RunState", failures)
	assert_true(restored_domain.state.reward_draft == null and restored_domain.state.phase == RunPhase.MAP_CHOICE, "the restored Reward flow clears its draft and returns to Map Choice", failures)
	assert_true(source.state.gold == 0 and source.state.reward_draft != null, "the post-resume Reward choice leaves the pre-load RunState untouched", failures)

func test_add_tile_selection_updates_the_run_build_and_returns_to_map(failures: Array[String]) -> void:
	var domain := _victorious_domain("reward.add-tile")
	var draft = domain.state.reward_draft
	var add_tile = _find_option(draft, RewardOption.ADD_TILE)
	assert_true(add_tile != null, "the Normal draft includes Add Tile", failures)
	if add_tile == null:
		return
	var pool_before: int = domain.state.tile_pool.tile_instances.size()
	var result = domain.execute(ChooseRewardCommand.new("reward.add-tile.choose", add_tile.option_id, draft.draft_id))

	assert_true(result.accepted, "Add Tile is accepted during Reward Choice", failures)
	assert_true(domain.state.tile_pool.tile_instances.size() == pool_before + 1, "Add Tile adds one owned TileInstance", failures)
	assert_true(domain.state.tile_pool.tile_instances.back().definition_id == add_tile.tile_id, "Add Tile uses the stable tile content ID in the option", failures)
	assert_true(domain.state.phase == RunPhase.MAP_CHOICE, "accepted Add Tile returns the run to Map Choice", failures)
	assert_true(domain.state.gold == 0, "Add Tile has no implicit Gold source", failures)

func test_stale_add_tile_option_is_rejected_at_the_copy_limit(failures: Array[String]) -> void:
	var domain := _victorious_domain("reward.copy-limit.stale")
	var draft = domain.state.reward_draft
	var add_tile = _find_option(draft, RewardOption.ADD_TILE)
	assert_true(add_tile != null, "an under-limit draft offers a valid Add Tile before the Run changes", failures)
	if add_tile == null:
		return
	var copies_to_add: int = domain.economy.tile_copy_limit - _tile_definition_count(domain, add_tile.tile_id)
	for index in range(copies_to_add):
		domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
			"reward.copy-limit.stale.extra.%d" % index,
			add_tile.tile_id,
			"RUN",
			"RUN",
		))
	assert_true(_tile_definition_count(domain, add_tile.tile_id) == domain.economy.tile_copy_limit, "the stale-option fixture reaches exactly the configured copy limit", failures)
	var before := domain.checkpoint()
	var rng_before := domain.rng_snapshot()
	var replay_before: Dictionary = domain.replay_record.to_dictionary()
	var result: Dictionary = domain.execute_choose_reward(draft.draft_id, add_tile.option_id)

	assert_true(not result.get("accepted", false) and result.get("status", "") == "COPY_LIMIT", "the Add Tile application path rejects a stale option at the copy limit", failures)
	assert_true(domain.checkpoint() == before, "a stale Add Tile rejection leaves RunState unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "a stale Add Tile rejection leaves every RNG stream unchanged", failures)
	assert_true(domain.replay_record.to_dictionary() == replay_before, "a stale Add Tile rejection leaves the replay record unchanged", failures)

func test_forged_add_tile_option_is_rejected_at_the_copy_limit(failures: Array[String]) -> void:
	var domain := _victorious_domain("reward.copy-limit.forged", 3)
	var draft = domain.state.reward_draft
	var skip = _find_option(draft, RewardOption.SKIP)
	assert_true(skip != null, "a full-copy Run still has a draft option slot for a forged-option regression", failures)
	if skip == null:
		return
	var skip_index: int = draft.options.find(skip)
	draft.options[skip_index] = RewardOption.new(
		skip.option_id,
		RewardOption.ADD_TILE,
		"base.tile.characters.1",
		"base.tile.characters.1",
	)
	var before := domain.checkpoint()
	var rng_before := domain.rng_snapshot()
	var replay_before: Dictionary = domain.replay_record.to_dictionary()
	var result = domain.execute(ChooseRewardCommand.new("reward.copy-limit.forged.choose", skip.option_id, draft.draft_id))

	assert_true(not result.accepted and result.validation.code == "COPY_LIMIT", "a forged Add Tile option cannot exceed the TileDefinition copy limit", failures)
	assert_true(not result.replayable, "a forged copy-limit rejection is not replayable", failures)
	assert_true(domain.checkpoint() == before, "a forged Add Tile rejection leaves RunState unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "a forged Add Tile rejection leaves every RNG stream unchanged", failures)
	assert_true(domain.replay_record.to_dictionary() == replay_before, "a forged Add Tile rejection leaves the replay record unchanged", failures)

func test_modified_tile_selection_updates_persistent_modifier_state(failures: Array[String]) -> void:
	var domain := _victorious_domain("reward.modified-tile")
	var draft = domain.state.reward_draft
	var modified_tile = _find_option(draft, RewardOption.MODIFIED_TILE)
	assert_true(modified_tile != null, "a run with a Tile Pool and modifier content can draft Modified Tile", failures)
	if modified_tile == null:
		return
	var result = domain.execute(ChooseRewardCommand.new("reward.modified-tile.choose", modified_tile.option_id, draft.draft_id))

	assert_true(result.accepted, "Modified Tile is accepted during Reward Choice", failures)
	assert_true(domain.state.build_ownership.persistent_tile_modifier_state.get(modified_tile.target_instance_id, []).has(modified_tile.modifier_id), "Modified Tile records the stable modifier ID on the target instance", failures)
	assert_true(domain.state.phase == RunPhase.MAP_CHOICE, "accepted Modified Tile returns the run to Map Choice", failures)

func test_invalid_selection_is_atomic(failures: Array[String]) -> void:
	var domain := _victorious_domain("reward.invalid")
	var before := domain.checkpoint()
	var rng_before := domain.rng_snapshot()
	var result = domain.execute(ChooseRewardCommand.new("reward.invalid.choose", "reward.option.missing", domain.state.reward_draft.draft_id))

	assert_true(not result.accepted, "an unknown reward option is rejected", failures)
	assert_true(result.validation.code == "INVALID_REWARD_OPTION", "invalid reward selection reports a stable validation code", failures)
	assert_true(domain.checkpoint() == before, "invalid reward selection leaves RunState unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "invalid reward selection leaves every RNG stream unchanged", failures)
	assert_true(domain.state.phase == RunPhase.REWARD_CHOICE, "invalid reward selection leaves the reward phase open", failures)

func _victorious_domain(run_id: String, extra_starting_tile_copies: int = 0) -> RunDomain:
	var domain := RunDomain.new(run_id, 8128, _registry())
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
		"%s.starting-tile" % run_id,
		"base.tile.characters.1",
		"RUN",
		"RUN",
	))
	for index in range(extra_starting_tile_copies):
		domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
			"%s.starting-tile.extra.%d" % [run_id, index],
			"base.tile.characters.1",
			"RUN",
			"RUN",
		))
	domain.execute(SelectMapNodeCommand.new("%s.intro" % run_id, INTRO))
	var intro_battle = domain.current_battle
	if intro_battle != null:
		intro_battle.combat_resolver.resolve_player_action(intro_battle.combat_state, 17)
		domain.apply_battle_outcome()
		var intro_skip = _find_option(domain.state.reward_draft, RewardOption.SKIP)
		if intro_skip != null:
			domain.execute(ChooseRewardCommand.new("%s.intro.skip" % run_id, intro_skip.option_id, domain.state.reward_draft.draft_id))
	domain.state.gold = 0
	domain.execute(SelectMapNodeCommand.new("%s.select" % run_id, LEFT))
	var battle = domain.current_battle
	battle.combat_resolver.resolve_player_action(battle.combat_state, 17)
	domain.apply_battle_outcome()
	return domain

func _tile_definition_count(domain: RunDomain, definition_id: String) -> int:
	var count := 0
	for tile_instance in domain.state.tile_pool.tile_instances:
		if tile_instance.definition_id == definition_id:
			count += 1
	return count

func _registry() -> ContentRegistry:
	var registry := ContentRegistry.new()
	RunStartingPoolContentFixture.register_character_starting_pool_tiles(registry)
	registry.register(TileDefinition.new("base.tile.bamboo.1", "bamboo", 1))
	registry.register(TileDefinition.new("base.tile.dots.1", "dots", 1))
	registry.register(TileModifierDefinition.new("base.modifier.ritual_mark", "RITUAL_MARK", 1))
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
	var graph := IntentGraph.new("pressure", [
		EnemyIntent.new("pressure", "Pressure", 1, EnemyIntent.PRESSURE, [IntentTransition.fixed("pressure.loop", "pressure")]),
	])
	registry.register(EnemyDefinition.new(
		"base.enemy.wall_taxer",
		graph,
		EnemyDefinition.NORMAL,
		17,
		{"pressure_limit": 9},
		{"kind": "wall_tax"},
	))
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
	return registry

func _find_option(draft, kind: String):
	if draft == null:
		return null
	for option in draft.options:
		if option.kind == kind:
			return option
	return null

func _has_acquisition_option(draft) -> bool:
	return _find_option(draft, RewardOption.ADD_TILE) != null or _find_option(draft, RewardOption.MODIFIED_TILE) != null

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
