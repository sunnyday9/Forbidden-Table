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

const LEFT := "base.map_node.normal.left"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_normal_victory_creates_a_three_option_draft(failures)
	test_same_seed_repeats_the_normal_draft(failures)
	test_skip_is_legal_and_pays_configured_compensation(failures)
	test_add_tile_selection_updates_the_run_build_and_returns_to_map(failures)
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

func _victorious_domain(run_id: String) -> RunDomain:
	var domain := RunDomain.new(run_id, 8128, _registry())
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
		"%s.starting-tile" % run_id,
		"base.tile.characters.1",
		"RUN",
		"RUN",
	))
	domain.execute(SelectMapNodeCommand.new("%s.select" % run_id, LEFT))
	var battle = domain.current_battle
	battle.combat_resolver.resolve_player_action(battle.combat_state, 17)
	domain.apply_battle_outcome()
	return domain

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
