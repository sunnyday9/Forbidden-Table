class_name BossRuleBreakerRewardTest
extends RefCounted

const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const ChooseRewardCommand = preload("res://src/domain/commands/choose_reward_command.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const EncounterDefinition = preload("res://src/content/definitions/encounter_definition.gd")
const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const ReplayRecord = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifier = preload("res://src/infrastructure/replay/replay_verifier.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunPresentationController = preload("res://src/presentation/run/run_presentation_controller.gd")
const SaveCoordinator = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_boss_victory_creates_three_deterministic_choices(failures)
	test_choice_validates_applies_and_enters_summary(failures)
	test_pending_choices_survive_suspend_resume(failures)
	test_reward_selection_replays_from_the_boss_boundary(failures)
	test_act_two_boss_offers_three_choices_after_each_act_one_choice(failures)
	test_each_act_two_choice_applies_and_rejected_duplicates_do_not_mutate(failures)
	test_act_two_reward_survives_suspend_resume_and_replay(failures)
	return failures

func test_boss_victory_creates_three_deterministic_choices(failures: Array[String]) -> void:
	var first := _boss_reward_domain("boss.reward.deterministic", 4901)
	var second := _boss_reward_domain("boss.reward.deterministic", 4901)
	var initial := _domain("boss.reward.initial.rng", 4901)
	var first_draft = first.state.reward_draft
	var second_draft = second.state.reward_draft
	assert_true(first.state.phase == RunPhase.BOSS_REWARD, "Boss victory enters the Boss reward phase", failures)
	assert_true(first_draft != null and first_draft.options.size() == 3, "Boss victory presents exactly three Rule Breaker choices", failures)
	if first_draft == null or second_draft == null or first_draft.options.size() != 3:
		return
	assert_true(first_draft.draft_kind == "BOSS_RULE_BREAKER", "the Boss draft has an explicit stable kind", failures)
	assert_true(first_draft.encounter_kind == EncounterDefinition.BOSS, "the Boss draft identifies its encounter kind", failures)
	assert_true(first_draft.to_dictionary() == second_draft.to_dictionary(), "the same seed reproduces the same ordered Boss choices", failures)
	assert_true(first_draft.reward_rng_state == first.rng_streams.reward.snapshot(), "the draft records its post-generation Reward RNG checkpoint", failures)
	assert_true(first.rng_snapshot().streams.reward != initial.rng_snapshot().streams.reward, "choice generation uses the existing Reward RNG stream", failures)
	var option_ids: Dictionary = {}
	var content_ids: Dictionary = {}
	for option in first_draft.options:
		assert_true(option.kind == "RULE_BREAKER", "each Boss option is a Rule Breaker reward", failures)
		assert_true(first.content_registry.resolve(option.content_id) != null, "each Boss option resolves through the content registry", failures)
		assert_true(not option_ids.has(option.option_id), "Boss option IDs are unique within the draft", failures)
		assert_true(not content_ids.has(option.content_id), "Boss draft does not offer duplicate Rule Breakers", failures)
		option_ids[option.option_id] = true
		content_ids[option.content_id] = true
	assert_true(content_ids.size() == Phase2Catalog.BOSS_RULE_BREAKER_IDS.size(), "the draft covers the three eligible Phase 2 definitions", failures)

func test_choice_validates_applies_and_enters_summary(failures: Array[String]) -> void:
	var domain := _boss_reward_domain("boss.reward.command", 4902)
	var draft = domain.state.reward_draft
	if draft == null or draft.options.size() != 3:
		assert_true(false, "Boss command fixture has three options", failures)
		return
	var initial_checkpoint: Dictionary = domain.checkpoint()
	var initial_rng: Dictionary = domain.rng_snapshot()
	var initial_command_count: int = domain.replay_record.commands.size()
	var rejected = domain.execute(ChooseRewardCommand.new("boss.reward.invalid", "reward.missing", draft.draft_id))
	assert_true(not rejected.accepted, "a Rule Breaker outside the active draft is rejected", failures)
	assert_true(domain.checkpoint() == initial_checkpoint and domain.rng_snapshot() == initial_rng, "a rejected Boss choice changes neither RunState nor RNG", failures)
	assert_true(domain.replay_record.commands.size() == initial_command_count, "a rejected Boss choice is excluded from Replay", failures)

	var controller := RunPresentationController.new(domain)
	var actions: Array = controller.action_descriptors()
	assert_true(actions.size() == 3, "the presentation controller exposes all three Boss choices", failures)
	if actions.is_empty():
		return
	var selected_action: Dictionary = actions[0]
	var selected_option = draft.option_by_id(str(selected_action.get("target_id", "")))
	var selected_result = controller.confirm(str(selected_action.get("id", "")))
	assert_true(selected_result.accepted and selected_result.replayable, "Boss selection travels through ChooseRewardCommand", failures)
	assert_true(selected_option != null and domain.state.build_ownership.acquired_rule_breaker_ids == [selected_option.content_id], "the selected Rule Breaker is recorded in RunState", failures)
	assert_true(domain.state.reward_draft == null and domain.state.phase == RunPhase.RUN_SUMMARY, "choosing a Boss reward clears its draft and completes the Phase 2 Run", failures)
	assert_true(domain.state.terminal_summary.summary_data.get("rule_breaker_id", "") == selected_option.content_id, "Run Summary records the chosen stable Rule Breaker ID", failures)
	var selected_event_found := false
	for event in selected_result.events:
		if event.event_type == "RewardSelected" and event.data.get("content_id", "") == selected_option.content_id:
			selected_event_found = true
	assert_true(selected_event_found, "Boss selection emits a factual RewardSelected event with the stable content ID", failures)

func test_pending_choices_survive_suspend_resume(failures: Array[String]) -> void:
	var source := _boss_reward_domain("boss.reward.save", 4903)
	var save = SaveCoordinator.new().save(source)
	assert_true(save.accepted, "the pending Boss reward is a stable Suspend checkpoint", failures)
	if not save.accepted:
		return
	var loaded = SaveMapper.load_into_domain(save.snapshot.to_dictionary(), source.content_registry)
	assert_true(loaded.accepted, "a pending Boss reward loads through the normal save pipeline", failures)
	if not loaded.accepted:
		return
	assert_true(loaded.domain.state.reward_draft.to_dictionary() == source.state.reward_draft.to_dictionary(), "Suspend/Resume preserves the exact three options and draft IDs", failures)
	assert_true(loaded.domain.rng_snapshot() == source.rng_snapshot(), "Suspend/Resume preserves every RNG stream at the Boss reward boundary", failures)
	var option_id: String = source.state.reward_draft.options[1].option_id
	var source_result = source.execute(ChooseRewardCommand.new("boss.reward.resume.choice", option_id, source.state.reward_draft.draft_id))
	var loaded_result = loaded.domain.execute(ChooseRewardCommand.new("boss.reward.resume.choice", option_id, loaded.domain.state.reward_draft.draft_id))
	assert_true(source_result.accepted and loaded_result.accepted, "the same Boss choice remains legal after Resume", failures)
	assert_true(source.checkpoint().state_hash == loaded.domain.checkpoint().state_hash, "resumed selection produces the identical authoritative state", failures)
	assert_true(source.rng_snapshot() == loaded.domain.rng_snapshot(), "resumed selection preserves identical RNG state", failures)

func test_reward_selection_replays_from_the_boss_boundary(failures: Array[String]) -> void:
	var domain := _boss_reward_domain("boss.reward.replay", 4904)
	if domain.state.reward_draft == null or domain.state.reward_draft.options.size() != 3:
		assert_true(false, "Boss replay fixture has three options", failures)
		return
	_reset_replay_at_current_state(domain)
	var option = domain.state.reward_draft.options[0]
	var selected = domain.execute(ChooseRewardCommand.new("boss.reward.replay.choice", option.option_id, domain.state.reward_draft.draft_id))
	assert_true(selected.accepted and selected.replayable, "the Boss choice is accepted into Run Replay", failures)
	var replay_factory: Callable = func(seed: int, _content_version: String):
		var replay_domain := _boss_reward_domain("boss.reward.replay", seed)
		_reset_replay_at_current_state(replay_domain)
		return replay_domain
	var report = ReplayVerifier.verify(domain.replay_record, replay_factory, domain.state.content_version)
	assert_true(report.is_match(), "Boss choice and terminal Run Summary replay without divergence (%s)" % report.reason, failures)

func test_act_two_boss_offers_three_choices_after_each_act_one_choice(failures: Array[String]) -> void:
	var expected_act_two_ids: Array = AlphaActTwoCatalog.ACT_TWO_BOSS_RULE_BREAKER_IDS.duplicate()
	expected_act_two_ids.sort()
	var first_draft_dictionary: Dictionary = {}
	for index in Phase2Catalog.BOSS_RULE_BREAKER_IDS.size():
		var act_one_id: String = Phase2Catalog.BOSS_RULE_BREAKER_IDS[index]
		var domain := _act_two_boss_reward_domain("boss.reward.act2.%d" % index, 4910, act_one_id)
		var draft = domain.state.reward_draft
		assert_true(domain.state.act_count == 2 and domain.state.act_index == 2, "the Act 1 Boss reward advances the same Run into Act 2", failures)
		assert_true(domain.state.phase == RunPhase.BOSS_REWARD, "the Act 2 Boss victory enters the real Boss reward phase", failures)
		assert_true(draft != null and draft.options.size() == 3, "an Act 1 acquisition still leaves exactly three Act 2 Boss choices", failures)
		if draft == null or draft.options.size() != 3:
			continue
		var offered_ids: Array[String] = []
		var option_ids: Dictionary = {}
		for option in draft.options:
			offered_ids.append(option.content_id)
			var unique_option_id := not str(option.option_id).is_empty() and not option_ids.has(option.option_id)
			assert_true(unique_option_id, "Act 2 option identities are non-empty and unique", failures)
			option_ids[option.option_id] = true
			assert_true(option.kind == "RULE_BREAKER", "every Act 2 Boss option is a Rule Breaker", failures)
			assert_true(option.content_id in expected_act_two_ids, "Act 2 only offers definitions from its dedicated eligibility pool", failures)
			assert_true(not domain.state.build_ownership.acquired_rule_breaker_ids.has(option.content_id), "Act 2 does not offer an already acquired Rule Breaker", failures)
		offered_ids.sort()
		assert_true(offered_ids == expected_act_two_ids, "the Act 2 pool presents its exact three unique eligible definitions", failures)
		if index == 0:
			first_draft_dictionary = draft.to_dictionary()
		else:
			assert_true(draft.to_dictionary() == first_draft_dictionary, "Act 2 choice generation is deterministic after any Act 1 choice", failures)

func test_each_act_two_choice_applies_and_rejected_duplicates_do_not_mutate(failures: Array[String]) -> void:
	var act_one_id: String = Phase2Catalog.BOSS_RULE_BREAKER_IDS[0]
	var seed := 4920
	for act_two_id in AlphaActTwoCatalog.ACT_TWO_BOSS_RULE_BREAKER_IDS:
		var domain := _act_two_boss_reward_domain("boss.reward.act2.apply.%d" % seed, seed, act_one_id)
		var draft = domain.state.reward_draft
		var selected_option = _option_for_content_id(draft, act_two_id)
		assert_true(selected_option != null, "%s is a selectable Act 2 Boss option" % act_two_id, failures)
		if selected_option != null:
			var selected = domain.execute(ChooseRewardCommand.new("boss.reward.act2.select.%d" % seed, selected_option.option_id, draft.draft_id))
			assert_true(selected.accepted, "%s can be applied through ChooseRewardCommand" % act_two_id, failures)
			assert_true(domain.state.build_ownership.acquired_rule_breaker_ids == [act_one_id, act_two_id], "%s applies and records only its own stable content ID" % act_two_id, failures)
			var selected_definition = domain.content_registry.resolve(act_two_id)
			assert_true(selected.data.get("content_id", "") == act_two_id and selected.data.get("rule_key", "") == selected_definition.rule_key, "%s selection records the exact Act 2 definition and rule key" % act_two_id, failures)
			assert_true(domain.state.terminal_summary.summary_data.get("rule_breaker_id", "") == act_two_id, "the Act 2 ending identifies its selected Rule Breaker", failures)
		seed += 1

	var invalid_domain := _act_two_boss_reward_domain("boss.reward.act2.invalid", 4930, act_one_id)
	var invalid_draft = invalid_domain.state.reward_draft
	if invalid_draft == null:
		assert_true(false, "invalid-choice fixture has an Act 2 reward draft", failures)
		return
	var checkpoint_before_invalid: Dictionary = invalid_domain.checkpoint()
	var rng_before_invalid: Dictionary = invalid_domain.rng_snapshot()
	var replay_count_before_invalid: int = invalid_domain.replay_record.commands.size()
	var invalid = invalid_domain.execute(ChooseRewardCommand.new("boss.reward.act2.invalid.choice", "missing.option", invalid_draft.draft_id))
	assert_true(not invalid.accepted, "an option outside the active Act 2 draft is rejected", failures)
	assert_true(invalid_domain.checkpoint() == checkpoint_before_invalid, "an invalid Act 2 choice leaves RunState unchanged", failures)
	assert_true(invalid_domain.rng_snapshot() == rng_before_invalid, "an invalid Act 2 choice leaves RNG unchanged", failures)
	assert_true(invalid_domain.replay_record.commands.size() == replay_count_before_invalid, "an invalid Act 2 choice is excluded from replay", failures)

	var duplicate_domain := _act_two_boss_reward_domain("boss.reward.act2.duplicate", 4931, act_one_id)
	var duplicate_draft = duplicate_domain.state.reward_draft
	if duplicate_draft == null:
		assert_true(false, "duplicate-choice fixture has an Act 2 reward draft", failures)
		return
	var duplicate_option = duplicate_draft.options[0]
	duplicate_domain.state.build_ownership.acquired_rule_breaker_ids.append(duplicate_option.content_id)
	var checkpoint_before_duplicate: Dictionary = duplicate_domain.checkpoint()
	var rng_before_duplicate: Dictionary = duplicate_domain.rng_snapshot()
	var replay_count_before_duplicate: int = duplicate_domain.replay_record.commands.size()
	var duplicate = duplicate_domain.execute(ChooseRewardCommand.new("boss.reward.act2.duplicate.choice", duplicate_option.option_id, duplicate_draft.draft_id))
	assert_true(not duplicate.accepted and duplicate.validation.code == "DUPLICATE_RULE_BREAKER", "an already acquired Act 2 Rule Breaker is rejected as a duplicate", failures)
	assert_true(duplicate_domain.checkpoint() == checkpoint_before_duplicate, "a duplicate Act 2 choice leaves RunState unchanged", failures)
	assert_true(duplicate_domain.rng_snapshot() == rng_before_duplicate, "a duplicate Act 2 choice leaves RNG unchanged", failures)
	assert_true(duplicate_domain.replay_record.commands.size() == replay_count_before_duplicate, "a duplicate Act 2 choice is excluded from replay", failures)

func test_act_two_reward_survives_suspend_resume_and_replay(failures: Array[String]) -> void:
	var source := _act_two_boss_reward_domain("boss.reward.act2.save", 4940, Phase2Catalog.BOSS_RULE_BREAKER_IDS[1])
	if source.state.reward_draft == null:
		assert_true(false, "save/replay fixture has an Act 2 reward draft", failures)
		return
	var save = SaveCoordinator.new().save(source)
	assert_true(save.accepted, "an Act 2 Boss reward is a stable Suspend checkpoint", failures)
	if not save.accepted:
		return
	var loaded = SaveMapper.load_into_domain(save.snapshot.to_dictionary(), source.content_registry)
	assert_true(loaded.accepted, "an Act 2 Boss reward loads through the normal save pipeline", failures)
	if not loaded.accepted:
		return
	assert_true(loaded.domain.state.act_index == 2 and loaded.domain.state.act_count == 2, "Suspend/Resume preserves the Act 2 Run position", failures)
	assert_true(loaded.domain.state.reward_draft.to_dictionary() == source.state.reward_draft.to_dictionary(), "Suspend/Resume preserves the exact Act 2 options and draft ID", failures)
	assert_true(loaded.domain.rng_snapshot() == source.rng_snapshot(), "Suspend/Resume preserves Reward RNG at the Act 2 Boss boundary", failures)
	_reset_replay_at_current_state(source)
	var selected_option = source.state.reward_draft.options[2]
	var source_result = source.execute(ChooseRewardCommand.new("boss.reward.act2.resume.choice", selected_option.option_id, source.state.reward_draft.draft_id))
	var loaded_result = loaded.domain.execute(ChooseRewardCommand.new("boss.reward.act2.resume.choice", selected_option.option_id, loaded.domain.state.reward_draft.draft_id))
	assert_true(source_result.accepted and loaded_result.accepted, "the same Act 2 choice remains legal after Resume", failures)
	assert_true(source.checkpoint().state_hash == loaded.domain.checkpoint().state_hash, "resumed Act 2 selection produces the identical authoritative state", failures)
	assert_true(source.rng_snapshot() == loaded.domain.rng_snapshot(), "resumed Act 2 selection preserves identical RNG state", failures)
	var replay_factory: Callable = func(seed: int, _content_version: String):
		var replay_domain := _act_two_boss_reward_domain("boss.reward.act2.save", seed, Phase2Catalog.BOSS_RULE_BREAKER_IDS[1])
		_reset_replay_at_current_state(replay_domain)
		return replay_domain
	var replay_report = ReplayVerifier.verify(source.replay_record, replay_factory, source.state.content_version)
	assert_true(replay_report.is_match(), "Act 2 Boss selection replays without divergence (%s)" % replay_report.reason, failures)

func _boss_reward_domain(run_id: String, seed: int) -> RunDomain:
	var domain := _domain(run_id, seed)
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, Phase2Catalog.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, Phase2Catalog.CONTRACT_IDS[0]))
	var battle = domain.encounter_factory.create(domain.state, "base.encounter.boss", domain.rng_streams, EncounterDefinition.BOSS)
	if battle == null:
		return domain
	domain.current_battle = battle
	domain.state.phase = RunPhase.BATTLE
	for _index in range(3):
		battle.combat_state.enemy_hp = 1
		battle.combat_resolver.resolve_player_action(battle.combat_state, 2)
	domain.apply_battle_outcome()
	return domain

func _act_two_boss_reward_domain(run_id: String, seed: int, act_one_rule_breaker_id: String) -> RunDomain:
	var domain := _alpha_domain(run_id, seed)
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, Phase2Catalog.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, Phase2Catalog.CONTRACT_IDS[0]))
	_resolve_boss_victory(domain, "base.encounter.boss")
	var act_one_draft = domain.state.reward_draft
	var act_one_option = _option_for_content_id(act_one_draft, act_one_rule_breaker_id)
	if act_one_option == null:
		return domain
	domain.execute(ChooseRewardCommand.new("%s.act_one.reward" % run_id, act_one_option.option_id, act_one_draft.draft_id))
	if domain.state.act_index != 2:
		return domain
	_resolve_boss_victory(domain, "base.encounter.boss")
	return domain

func _resolve_boss_victory(domain: RunDomain, encounter_id: String) -> void:
	var battle = domain.encounter_factory.create(domain.state, encounter_id, domain.rng_streams, EncounterDefinition.BOSS)
	if battle == null:
		return
	domain.current_battle = battle
	domain.state.phase = RunPhase.BATTLE
	for _index in range(3):
		battle.combat_state.enemy_hp = 1
		battle.combat_resolver.resolve_player_action(battle.combat_state, 2)
	domain.apply_battle_outcome()

func _alpha_domain(run_id: String, seed: int) -> RunDomain:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	return RunDomain.new_alpha_run(run_id, seed, registry)

func _option_for_content_id(draft, content_id: String):
	if draft == null:
		return null
	for option in draft.options:
		if option.content_id == content_id:
			return option
	return null

func _domain(run_id: String, seed: int) -> RunDomain:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	return RunDomain.new(run_id, seed, registry)

func _reset_replay_at_current_state(domain: RunDomain) -> void:
	domain.replay_record = ReplayRecord.new(domain.state.seed, domain.state.content_version, domain.state.run_id)
	domain.replay_record.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), domain.state.terminal_summary.outcome)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
