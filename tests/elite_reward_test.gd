class_name EliteRewardTest
extends RefCounted

const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const ChooseRewardCommand = preload("res://src/domain/commands/choose_reward_command.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const EncounterDefinition = preload("res://src/content/definitions/encounter_definition.gd")
const DeterministicSerializer = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RelicDefinition = preload("res://src/content/definitions/relic_definition.gd")
const ReplayRecord = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifier = preload("res://src/infrastructure/replay/replay_verifier.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunPresentationController = preload("res://src/presentation/run/run_presentation_controller.gd")
const SaveCoordinator = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")

const ELITE_NODE_ID := "base.map_node.elite"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_elite_victory_presents_three_distinct_acquisitions_plus_skip(failures)
	test_relic_and_technique_choices_apply_one_build_acquisition(failures)
	test_skip_applies_only_ten_gold_and_returns_to_map(failures)
	test_stale_and_foreign_reward_ids_are_atomic(failures)
	test_pending_draft_survives_suspend_resume(failures)
	test_reward_selection_replays_from_the_elite_boundary(failures)
	return failures

func test_elite_victory_presents_three_distinct_acquisitions_plus_skip(failures: Array[String]) -> void:
	var first := _elite_reward_domain("elite.reward.options", 5301)
	var second := _elite_reward_domain("elite.reward.options", 5301)
	var reward_before: Dictionary = _elite_battle_domain("elite.reward.options.initial", 5301).rng_streams.reward.snapshot()
	var draft = first.state.reward_draft

	assert_true(first.state.phase == RunPhase.ELITE_REWARD, "Elite victory enters the Elite reward phase", failures)
	assert_true(draft != null and draft.options.size() == 4, "Elite victory presents three acquisitions plus Skip", failures)
	if draft == null or draft.options.size() != 4:
		return
	assert_true(draft.draft_kind == "ELITE_BUILD", "the Elite reward uses its stable draft kind", failures)
	assert_true(draft.encounter_kind == EncounterDefinition.ELITE, "the draft identifies an Elite encounter", failures)
	assert_true(draft.draft_id.begins_with("reward.elite.") and not draft.options[0].option_id.is_empty(), "Elite drafts and options have stable non-empty IDs", failures)
	assert_true(first.state.content_version == "content.slice.v2", "Elite rewards remain part of the pending Phase 2 v2 bundle", failures)
	assert_true(draft.to_dictionary() == second.state.reward_draft.to_dictionary(), "the same seed reproduces the ordered Elite draft", failures)
	assert_true(draft.reward_rng_state == first.rng_streams.reward.snapshot(), "the draft records the post-generation Reward RNG state", failures)
	assert_true(first.rng_streams.reward.snapshot() != reward_before, "Elite candidate selection advances the existing Reward RNG stream", failures)

	var option_ids: Dictionary = {}
	var acquisition_ids: Dictionary = {}
	var relic_count := 0
	var technique_count := 0
	var skip_count := 0
	for option in draft.options:
		assert_true(not option_ids.has(option.option_id), "Elite option IDs are unique", failures)
		option_ids[option.option_id] = true
		match option.kind:
			"RELIC":
				relic_count += 1
				var relic = first.content_registry.resolve(option.content_id)
				assert_true(relic is RelicDefinition, "a Relic acquisition resolves to a Relic definition", failures)
				assert_true(not first.state.build_ownership.owned_relic_ids.has(option.content_id), "the draft excludes Relics already owned by this Run", failures)
				assert_true(not acquisition_ids.has(option.content_id), "Elite acquisitions have distinct content IDs", failures)
				acquisition_ids[option.content_id] = true
			"RUN_TECHNIQUE":
				technique_count += 1
				var technique = first.content_registry.resolve(option.content_id)
				assert_true(technique is TechniqueDefinition and technique.technique_kind != TechniqueDefinition.CORE, "a Technique acquisition resolves to a Run Technique, not a Core Technique", failures)
				assert_true(not first.state.build_ownership.run_technique_ids.has(option.content_id), "the draft excludes Run Techniques already owned", failures)
				assert_true(not acquisition_ids.has(option.content_id), "Elite acquisitions have distinct content IDs", failures)
				acquisition_ids[option.content_id] = true
			"SKIP":
				skip_count += 1
				assert_true(option.gold_delta == 10, "Elite Skip grants the configured 10 Gold", failures)
				assert_true(option.refinement_token_delta == 0, "Elite Skip does not require or grant Refinement Tokens", failures)
			_:
				assert_true(false, "the Elite draft contains only Relic, Run Technique, or Skip options", failures)
	assert_true(relic_count >= 1 and technique_count >= 1, "the Elite choices include at least one Relic and one Run Technique", failures)
	assert_true(acquisition_ids.size() == 3, "all three Elite acquisitions are distinct", failures)
	assert_true(skip_count == 1, "the Elite draft contains exactly one Skip", failures)
	var controller := RunPresentationController.new(first)
	var actions: Array = controller.action_descriptors()
	assert_true(actions.size() == 4, "the Elite presentation exposes every draft option", failures)
	for action in actions:
		assert_true(action.get("draft_id", "") == draft.draft_id, "presentation actions carry the stable Elite draft ID", failures)
		assert_true(draft.option_by_id(str(action.get("target_id", ""))) != null, "presentation actions dispatch stable option IDs from the draft", failures)

func test_relic_and_technique_choices_apply_one_build_acquisition(failures: Array[String]) -> void:
	var relic_domain := _elite_reward_domain("elite.reward.apply.relic", 5302)
	var relic_draft = relic_domain.state.reward_draft
	var relic_option = _find_option(relic_draft, "RELIC")
	assert_true(relic_option != null, "the Elite draft offers a Relic to apply", failures)
	if relic_option == null:
		return
	var relic_controller := RunPresentationController.new(relic_domain)
	var relic_result = relic_controller.confirm("reward:%s" % relic_option.option_id)
	assert_true(relic_result.accepted and relic_result.replayable, "Relic selection is accepted as a replayable typed command", failures)
	assert_true(relic_domain.state.build_ownership.owned_relic_ids.count(relic_option.content_id) == 1, "Relic selection adds exactly the selected Relic", failures)
	assert_true(relic_domain.state.build_ownership.run_technique_ids.is_empty(), "Relic selection does not grant a Run Technique", failures)
	assert_true(relic_domain.state.gold == 0 and relic_domain.state.refinement_tokens == 0, "Relic selection applies no currency transaction", failures)
	assert_true(relic_domain.state.reward_draft == null and relic_domain.state.phase == RunPhase.MAP_CHOICE, "Relic selection clears the draft and advances once to Map Choice", failures)
	assert_true(relic_domain.replay_record.commands.back().command_type == "ChooseReward", "the accepted choice is recorded as ChooseReward", failures)
	assert_true(_phase_transition_count(relic_result.events) == 1, "Relic selection emits exactly one phase transition", failures)
	var duplicate_choice = relic_domain.execute(ChooseRewardCommand.new("elite.reward.apply.relic.again", relic_option.option_id, relic_draft.draft_id))
	assert_true(not duplicate_choice.accepted and relic_domain.state.phase == RunPhase.MAP_CHOICE, "a second choice cannot advance the reward boundary again", failures)

	var technique_domain := _elite_reward_domain("elite.reward.apply.technique", 5303)
	var technique_draft = technique_domain.state.reward_draft
	var technique_option = _find_option(technique_draft, "RUN_TECHNIQUE")
	assert_true(technique_option != null, "the Elite draft offers a Run Technique to apply", failures)
	if technique_option == null:
		return
	var relics_before: Array = technique_domain.state.build_ownership.owned_relic_ids.duplicate()
	var technique_result = technique_domain.execute(ChooseRewardCommand.new("elite.reward.apply.technique", technique_option.option_id, technique_draft.draft_id))
	assert_true(technique_result.accepted and technique_result.replayable, "Run Technique selection is accepted", failures)
	assert_true(technique_domain.state.build_ownership.run_technique_ids == [technique_option.content_id], "Run Technique selection adds exactly the selected Technique", failures)
	assert_true(technique_domain.state.build_ownership.owned_relic_ids == relics_before, "Run Technique selection does not change Relic ownership", failures)
	assert_true(technique_domain.state.gold == 0 and technique_domain.state.refinement_tokens == 0, "Run Technique selection applies no currency transaction", failures)
	assert_true(technique_domain.state.phase == RunPhase.MAP_CHOICE, "Run Technique selection returns to Map Choice", failures)
	assert_true(_phase_transition_count(technique_result.events) == 1, "Run Technique selection emits exactly one phase transition", failures)

func test_skip_applies_only_ten_gold_and_returns_to_map(failures: Array[String]) -> void:
	var domain := _elite_reward_domain("elite.reward.skip", 5304)
	var draft = domain.state.reward_draft
	var skip = _find_option(draft, "SKIP")
	assert_true(skip != null, "the Elite draft includes Skip", failures)
	if skip == null:
		return
	var relics_before: Array = domain.state.build_ownership.owned_relic_ids.duplicate()
	var techniques_before: Array = domain.state.build_ownership.run_technique_ids.duplicate()
	var tokens_before: int = domain.state.refinement_tokens
	var gold_before: int = domain.state.gold
	var result = domain.execute(ChooseRewardCommand.new("elite.reward.skip", skip.option_id, draft.draft_id))
	assert_true(result.accepted and result.replayable, "Elite Skip is a replayable typed choice", failures)
	assert_true(domain.state.gold == gold_before + 10, "Elite Skip grants exactly 10 Gold", failures)
	assert_true(domain.state.refinement_tokens == tokens_before, "Elite Skip leaves Refinement Tokens unchanged", failures)
	assert_true(domain.state.build_ownership.owned_relic_ids == relics_before and domain.state.build_ownership.run_technique_ids == techniques_before, "Elite Skip grants no build acquisition", failures)
	assert_true(result.data.currency_transactions.size() == 1 and result.data.currency_transactions[0].currency == "GOLD" and result.data.currency_transactions[0].amount == 10, "Skip applies exactly one Gold transaction", failures)
	assert_true(result.data.currency_transactions[0].source_id == "ELITE_REWARD", "Skip records the Elite reward source", failures)
	assert_true(domain.state.reward_draft == null and domain.state.phase == RunPhase.MAP_CHOICE, "Skip clears the draft and returns to Map Choice", failures)
	assert_true(domain.state.map_state.current_node_id == ELITE_NODE_ID, "Skip does not move or bypass the current Map node", failures)
	assert_true(not domain.state.shop_state.active and not domain.state.workshop_state.active, "Skip does not bypass future Shop or Workshop choices", failures)
	assert_true(_phase_transition_count(result.events) == 1, "Skip emits exactly one phase transition", failures)

func test_stale_and_foreign_reward_ids_are_atomic(failures: Array[String]) -> void:
	var domain := _elite_reward_domain("elite.reward.invalid", 5305)
	var draft = domain.state.reward_draft
	var option = draft.options[0]
	var checkpoint: Dictionary = domain.checkpoint()
	var rng_before: Dictionary = domain.rng_snapshot()
	var command_count: int = domain.replay_record.commands.size()
	var foreign_draft = domain.execute(ChooseRewardCommand.new("elite.reward.foreign.draft", option.option_id, "reward.elite.foreign.0"))
	assert_true(not foreign_draft.accepted and foreign_draft.validation.code == "INVALID_REWARD_DRAFT", "a foreign draft ID is rejected", failures)
	assert_true(domain.checkpoint() == checkpoint and domain.rng_snapshot() == rng_before, "foreign draft rejection leaves state and all RNG streams unchanged", failures)
	var stale_option = domain.execute(ChooseRewardCommand.new("elite.reward.stale.option", "reward.elite.stale.0.option.0", draft.draft_id))
	assert_true(not stale_option.accepted and stale_option.validation.code == "INVALID_REWARD_OPTION", "an option outside the active draft is rejected", failures)
	assert_true(domain.checkpoint() == checkpoint and domain.rng_snapshot() == rng_before, "stale option rejection leaves state and all RNG streams unchanged", failures)
	assert_true(domain.replay_record.commands.size() == command_count, "rejected reward commands are excluded from Replay", failures)

func test_pending_draft_survives_suspend_resume(failures: Array[String]) -> void:
	var source := _elite_reward_domain("elite.reward.resume", 5306)
	var save = SaveCoordinator.new().save(source)
	assert_true(save.accepted and save.checkpoint_metadata.stable_boundary == "REWARD", "ELITE_REWARD is a stable Suspend boundary", failures)
	if not save.accepted:
		return
	var loaded = SaveMapper.load_into_domain(save.snapshot.to_dictionary(), source.content_registry)
	assert_true(loaded.accepted, "a pending Elite reward loads through the normal Resume pipeline: %s %s" % [loaded.get("code", ""), loaded.get("errors", [])], failures)
	if not loaded.accepted:
		return
	assert_true(loaded.domain.state.reward_draft.to_dictionary() == source.state.reward_draft.to_dictionary(), "Suspend/Resume preserves the exact Elite draft and stable IDs", failures)
	assert_true(loaded.domain.rng_snapshot() == source.rng_snapshot(), "Suspend/Resume preserves the Reward and future RNG states", failures)
	var option = source.state.reward_draft.options[1]
	var original_result = source.execute(ChooseRewardCommand.new("elite.reward.resume.choice", option.option_id, source.state.reward_draft.draft_id))
	var resumed_result = loaded.domain.execute(ChooseRewardCommand.new("elite.reward.resume.choice", option.option_id, loaded.domain.state.reward_draft.draft_id))
	assert_true(original_result.accepted and resumed_result.accepted, "the same stable choice remains legal after Resume", failures)
	assert_true(source.checkpoint().state_hash == loaded.domain.checkpoint().state_hash, "Resume produces the same post-choice state hash", failures)
	assert_true(source.rng_snapshot() == loaded.domain.rng_snapshot(), "Resume preserves identical future RNG outcomes", failures)
	assert_true(_event_dictionaries(original_result.events) == _event_dictionaries(resumed_result.events), "Resume reproduces the same factual reward events", failures)
	var invalid_snapshot: Dictionary = save.snapshot.to_dictionary()
	invalid_snapshot.authoritative_state.reward_draft.options.pop_back()
	invalid_snapshot.run_state = invalid_snapshot.authoritative_state.duplicate(true)
	invalid_snapshot.checkpoint_metadata.state_hash = DeterministicSerializer.hash(invalid_snapshot.authoritative_state)
	var invalid_load = SaveMapper.load_into_domain(invalid_snapshot, source.content_registry)
	assert_true(not invalid_load.accepted, "LoadValidator rejects an incomplete Elite reward draft", failures)
	assert_true(_has_error_code(invalid_load.get("errors", []), "INVALID_ELITE_REWARD_CHOICES"), "the invalid draft is rejected at the Elite stable boundary", failures)

func test_reward_selection_replays_from_the_elite_boundary(failures: Array[String]) -> void:
	var domain := _elite_reward_domain("elite.reward.replay", 5307)
	_reset_replay_at_current_state(domain)
	var option = domain.state.reward_draft.options[2]
	var result = domain.execute(ChooseRewardCommand.new("elite.reward.replay.choice", option.option_id, domain.state.reward_draft.draft_id))
	assert_true(result.accepted and result.replayable, "Elite reward selection is accepted into Run Replay", failures)
	var replay_factory: Callable = func(seed: int, _content_version: String):
		var replay_domain := _elite_reward_domain("elite.reward.replay", seed)
		_reset_replay_at_current_state(replay_domain)
		return replay_domain
	var report = ReplayVerifier.verify(domain.replay_record, replay_factory, domain.state.content_version)
	assert_true(report.status == "MATCH", "Replay verifies Elite-boundary hashes, events, RNG, and outcome: %s %s" % [report.status, report.reason], failures)

func _find_option(draft, kind: String):
	if draft == null:
		return null
	for option in draft.options:
		if option.kind == kind:
			return option
	return null

func _phase_transition_count(events: Array) -> int:
	var count := 0
	for event in events:
		if event.event_type == DomainEvent.RUN_PHASE_CHANGED:
			count += 1
	return count

func _event_dictionaries(events: Array) -> Array:
	var result: Array = []
	for event in events:
		result.append(event.to_dictionary())
	return result

func _has_error_code(errors: Array, code: String) -> bool:
	for error in errors:
		if error is Dictionary and str(error.get("code", "")) == code:
			return true
	return false

func _reset_replay_at_current_state(domain: RunDomain) -> void:
	domain.replay_record = ReplayRecord.new(domain.state.seed, domain.state.content_version, domain.state.run_id)
	domain.replay_record.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), domain.state.terminal_summary.outcome)

func _elite_reward_domain(run_id: String, seed: int) -> RunDomain:
	var domain := _elite_battle_domain(run_id, seed)
	var battle = domain.current_battle
	if battle == null:
		return domain
	battle.combat_state.enemy_hp = 1
	battle.combat_resolver.resolve_player_action(battle.combat_state, 2)
	domain.apply_battle_outcome()
	return domain

func _elite_battle_domain(run_id: String, seed: int) -> RunDomain:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var domain := RunDomain.new(run_id, seed, registry)
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, Phase2Catalog.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, Phase2Catalog.CONTRACT_IDS[0]))
	domain.state.map_state.current_node_id = ELITE_NODE_ID
	var elite_path: Array[String] = [
		"base.map_node.intro",
		"base.map_node.normal.left",
		"base.map_node.shop",
		"base.map_node.workshop",
		"base.map_node.normal.mid",
		ELITE_NODE_ID,
	]
	domain.state.map_state.ordered_path = elite_path.duplicate()
	domain.state.map_state.visited_node_ids = elite_path.duplicate()
	var elite_path_edges: Array[String] = [
		"edge.intro.left",
		"edge.left.shop",
		"edge.shop.workshop",
		"edge.workshop.mid",
		"edge.mid.elite",
	]
	domain.state.map_state.path_edge_ids = elite_path_edges
	var encounter_id := str(domain.state.map_state.payload_ids.get(ELITE_NODE_ID, "base.encounter.elite"))
	domain.current_battle = domain.encounter_factory.create(domain.state, encounter_id, domain.rng_streams, EncounterDefinition.ELITE)
	domain.state.phase = RunPhase.BATTLE
	return domain

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
