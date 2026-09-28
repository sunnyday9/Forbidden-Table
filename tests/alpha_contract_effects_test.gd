class_name AlphaContractEffectsTest
extends RefCounted

const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const ChooseRewardCommand = preload("res://src/domain/commands/choose_reward_command.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const EncounterDefinition = preload("res://src/content/definitions/encounter_definition.gd")
const LoadValidator = preload("res://src/infrastructure/persistence/load_validator.gd")
const MetaProgressState = preload("res://src/domain/run/meta_progress_state.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RewardDraftSelector = preload("res://src/domain/run/reward_draft_selector.gd")
const RewardOption = preload("res://src/domain/run/reward_option.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunPresentationController = preload("res://src/presentation/run/run_presentation_controller.gd")
const RunState = preload("res://src/domain/run/run_state.gd")
const RunTileInstanceRecord = preload("res://src/domain/run/run_tile_instance_record.gd")
const RunTilePoolState = preload("res://src/domain/run/run_tile_pool_state.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinition = preload("res://src/content/definitions/tile_modifier_definition.gd")
const UseWorkshopServiceCommand = preload("res://src/domain/commands/use_workshop_service_command.gd")
const WorkshopState = preload("res://src/domain/run/workshop_state.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_long_current_is_selectable_and_changes_battle_start(failures)
	test_house_tithe_changes_elite_skip_economy(failures)
	test_contract_selection_effects_and_invalid_selection_are_atomic(failures)
	test_quiet_current_applies_battle_start_pressure_and_tp(failures)
	test_open_ledger_filters_and_biases_normal_tile_choices(failures)
	test_elite_skip_effects_and_saved_drafts(failures)
	test_brittle_compass_adds_distinct_modified_choice(failures)
	test_brittle_compass_omits_extra_when_only_one_pair_exists(failures)
	test_stale_contract_reward_options_are_rejected_atomically(failures)
	test_brittle_compass_workshop_refinement_surcharge(failures)
	test_phase_2_contract_defaults_remain_unchanged(failures)
	test_scale_version_rejects_inert_v1_snapshot(failures)
	return failures

func test_long_current_is_selectable_and_changes_battle_start(failures: Array[String]) -> void:
	var contract_id := "alpha.contract.long_current"
	var registry := _registry()
	var definition = registry.resolve(contract_id)
	assert_true(definition is ContractDefinition and definition.validate().is_valid(), "Long Current registers as a valid ContractDefinition", failures)
	var domain: RunDomain = RunDomain.new_alpha_run(
		"contract.long-current.run-start",
		151,
		registry,
		"",
		null,
		null,
		MetaProgressState.all_unlocked_test_profile(),
	)
	var controller := RunPresentationController.new(domain)
	var character_result = controller.confirm("character:%s" % Phase2Catalog.CHARACTER_IDS[0])
	assert_true(character_result.accepted, "the Run-start Contract fixture selects a Character", failures)
	var action_id := "contract:%s" % contract_id
	var offered_actions: Array = controller.action_descriptors().filter(func(action): return action.get("id", "") == action_id)
	assert_true(offered_actions.size() == 1, "Long Current is offered through the normal Run-start Contract selection", failures)
	var contract_result = controller.confirm(action_id)
	assert_true(contract_result.accepted and domain.state.contract_id == contract_id, "Long Current can be selected through its stable Run-start action", failures)
	var battle_result = domain.execute(SelectMapNodeCommand.new("contract.long-current.battle", domain.map_definition.start_node_id))
	assert_true(battle_result.accepted and domain.current_battle != null, "Long Current enters the first battle", failures)
	if domain.current_battle != null:
		assert_true(domain.current_battle.combat_state.pressure == 3, "Long Current starts each battle with three Pressure", failures)
		assert_true(domain.current_battle.combat_state.tp == 2, "Long Current grants two TP at each battle start", failures)

func test_house_tithe_changes_elite_skip_economy(failures: Array[String]) -> void:
	var contract_id := "alpha.contract.house_tithe"
	var registry := _registry()
	var definition = registry.resolve(contract_id)
	assert_true(definition is ContractDefinition and definition.validate().is_valid(), "House Tithe registers as a valid ContractDefinition", failures)
	var domain: RunDomain = RunDomain.new_alpha_run(
		"contract.house-tithe.run-start",
		152,
		registry,
		"",
		null,
		null,
		MetaProgressState.all_unlocked_test_profile(),
	)
	var controller := RunPresentationController.new(domain)
	var character_result = controller.confirm("character:%s" % Phase2Catalog.CHARACTER_IDS[0])
	assert_true(character_result.accepted, "the House Tithe fixture selects a Character", failures)
	var action_id := "contract:%s" % contract_id
	var offered_actions: Array = controller.action_descriptors().filter(func(action): return action.get("id", "") == action_id)
	assert_true(offered_actions.size() == 1, "House Tithe is offered through the normal Run-start Contract selection", failures)
	var contract_result = controller.confirm(action_id)
	assert_true(contract_result.accepted and domain.state.contract_id == contract_id, "House Tithe can be selected through its stable Run-start action", failures)
	if not contract_result.accepted:
		return
	_open_elite_reward(domain, "house-tithe")
	var skip_option = _option_by_kind(domain.state.reward_draft, RewardOption.SKIP)
	assert_true(skip_option != null and skip_option.gold_delta == 6 and skip_option.refinement_token_delta == 2, "House Tithe trades four Elite Skip Gold for two Refinement Tokens", failures)
	if skip_option != null:
		var skip_result = domain.execute(ChooseRewardCommand.new("contract.house-tithe.skip", skip_option.option_id, domain.state.reward_draft.draft_id))
		assert_true(skip_result.accepted, "House Tithe Elite Skip is accepted", failures)
		assert_true(domain.state.gold == 6 and domain.state.refinement_tokens == 2, "House Tithe applies the Elite Skip Gold and Token tradeoff", failures)

func test_contract_selection_effects_and_invalid_selection_are_atomic(failures: Array[String]) -> void:
	var hint_domain := _domain_with_character("contract.open-ledger.hint", _registry(), MetaProgressState.all_unlocked_test_profile())
	var hint_result = hint_domain.execute(ChooseContractCommand.new("contract.open-ledger.hint.choose", AlphaScaleCatalog.CONTRACT_IDS[1]))
	var hint_event = _event_of_type(hint_result.events, DomainEvent.CONTRACT_SELECTED)
	assert_true(hint_event != null and hint_event.data.get("yaku_hint", "") == "Sequence", "Open Ledger exposes its Sequence hint in authoritative ContractSelected data", failures)
	assert_true(hint_result.data.get("yaku_hint", "") == "Sequence", "Open Ledger reports its Sequence hint in the Contract selection result", failures)

	var brittle_registry := _registry()
	var brittle_domain := _domain_with_character("contract.brittle.selection", brittle_registry, MetaProgressState.all_unlocked_test_profile())
	var selection = brittle_domain.execute(ChooseContractCommand.new("contract.brittle.selection.choose", AlphaScaleCatalog.CONTRACT_IDS[2]))
	assert_true(selection.accepted and selection.replayable, "Brittle Compass selection is an accepted replayable command", failures)
	assert_true(brittle_domain.state.refinement_tokens == 1, "Brittle Compass grants one Refinement Token when selected", failures)
	assert_true(_has_event(selection.events, DomainEvent.REFINEMENT_TOKENS_CHANGED), "Contract selection emits the Refinement Token transaction", failures)
	var replay = brittle_domain.verify_replay()
	assert_true(replay.is_match(), "Contract selection replays with its deterministic token reward and event", failures)
	var saved = SaveMapper.suspend_snapshot(brittle_domain)
	var loaded = SaveMapper.load_into_domain(saved.to_dictionary(), brittle_registry)
	assert_true(loaded.accepted, "a selected Alpha Contract round-trips through the active save contract", failures)
	if loaded.accepted:
		assert_true(loaded.domain.state.refinement_tokens == 1 and loaded.domain.state.contract_id == AlphaScaleCatalog.CONTRACT_IDS[2], "save restoration preserves the selected Contract reward", failures)

	var locked_domain := _domain_with_character("contract.locked.invalid", brittle_registry, MetaProgressState.new())
	var before := locked_domain.checkpoint()
	var rng_before := locked_domain.rng_snapshot()
	var replay_command_count: int = locked_domain.replay_record.commands.size()
	var locked = locked_domain.execute(ChooseContractCommand.new("contract.locked.invalid.choose", AlphaScaleCatalog.CONTRACT_IDS[2]))
	assert_true(not locked.accepted and locked.validation.code == "CONTRACT_LOCKED", "a locked Alpha Contract is rejected", failures)
	assert_true(locked_domain.checkpoint() == before and locked_domain.rng_snapshot() == rng_before, "rejected Alpha Contract selection leaves state and RNG unchanged", failures)
	assert_true(locked_domain.replay_record.commands.size() == replay_command_count, "rejected Alpha Contract selection is absent from replay", failures)

func test_quiet_current_applies_battle_start_pressure_and_tp(failures: Array[String]) -> void:
	var normal_domain := _alpha_domain("contract.quiet.normal", AlphaScaleCatalog.CONTRACT_IDS[0])
	var normal_result = normal_domain.execute(SelectMapNodeCommand.new("contract.quiet.normal.battle", normal_domain.map_definition.start_node_id))
	assert_true(normal_result.accepted, "Quiet Current enters a normal battle", failures)
	if normal_domain.current_battle != null:
		assert_true(normal_domain.current_battle.combat_state.pressure == 2, "Quiet Current starts every battle with two additional Pressure", failures)
		assert_true(normal_domain.current_battle.combat_state.tp == 1, "Quiet Current starts every battle with one additional TP", failures)

	var elite_domain := _alpha_domain("contract.quiet.elite", AlphaScaleCatalog.CONTRACT_IDS[0])
	var elite = elite_domain.encounter_factory.create(elite_domain.state, "base.encounter.elite", elite_domain.rng_streams, EncounterDefinition.ELITE)
	assert_true(elite != null, "Quiet Current can create an Elite battle", failures)
	if elite != null:
		assert_true(elite.combat_state.pressure == 2 and elite.combat_state.tp == 1, "Quiet Current applies its battle-start values to Elite encounters too", failures)
	var reward_domain := _alpha_domain("contract.quiet.bias", AlphaScaleCatalog.CONTRACT_IDS[0])
	var reward_draft = _normal_draft(reward_domain, "quiet-current")
	var honor_preference_found := false
	for option in reward_draft.options:
		if option.kind == RewardOption.ADD_TILE and option.tile_id in ["base.tile.honors.east", "base.tile.honors.south"]:
			honor_preference_found = true
	assert_true(honor_preference_found, "Quiet Current biases Normal Add Tile choices toward East and South Honors", failures)

func test_open_ledger_filters_and_biases_normal_tile_choices(failures: Array[String]) -> void:
	var domain := _alpha_domain("contract.open-ledger.draft", AlphaScaleCatalog.CONTRACT_IDS[1])
	var first_draft = _normal_draft(domain, "open-ledger")
	var repeat_domain := _alpha_domain("contract.open-ledger.draft", AlphaScaleCatalog.CONTRACT_IDS[1])
	var repeat_draft = _normal_draft(repeat_domain, "open-ledger")
	assert_true(first_draft != null and repeat_draft != null, "Open Ledger creates repeatable normal reward drafts", failures)
	if first_draft == null or repeat_draft == null:
		return
	var preferred_found := false
	var modified_found := false
	for option in first_draft.options:
		if option.kind == RewardOption.ADD_TILE:
			var definition = domain.content_registry.resolve(option.tile_id)
			assert_true(definition != null and definition.suit == "characters", "Open Ledger never offers an off-suit Add Tile", failures)
			if option.tile_id in ["base.tile.characters.4", "base.tile.characters.5", "base.tile.characters.6"]:
				preferred_found = true
		elif option.kind == RewardOption.MODIFIED_TILE:
			modified_found = true
	assert_true(preferred_found, "Open Ledger biases Add Tile choices toward Characters 4–6", failures)
	assert_true(modified_found, "Open Ledger preserves Modified Tile choices", failures)
	assert_true(first_draft.to_dictionary() == repeat_draft.to_dictionary(), "Open Ledger reward selection remains deterministic for a fixed seed", failures)
	assert_true(domain.rng_snapshot()["streams"]["reward"] == repeat_domain.rng_snapshot()["streams"]["reward"], "Open Ledger repeats its Reward RNG checkpoint", failures)
	domain.state.phase = RunPhase.REWARD_CHOICE
	domain.state.reward_draft = first_draft
	var forged_add_tile = _option_by_kind(first_draft, RewardOption.ADD_TILE)
	if forged_add_tile != null:
		forged_add_tile.content_id = "base.tile.bamboo.4"
		forged_add_tile.tile_id = "base.tile.bamboo.4"
		var before := domain.checkpoint()
		var rng_before := domain.rng_snapshot()
		var replay_count: int = domain.replay_record.commands.size()
		var forged = domain.execute(ChooseRewardCommand.new("contract.open-ledger.forged", forged_add_tile.option_id, first_draft.draft_id))
		assert_true(not forged.accepted and forged.validation.code == "CONTRACT_RESTRICTION", "Open Ledger authoritatively rejects a forged off-suit Add Tile", failures)
		assert_true(domain.checkpoint() == before and domain.rng_snapshot() == rng_before, "forged Open Ledger option rejection leaves state and RNG unchanged", failures)
		assert_true(domain.replay_record.commands.size() == replay_count, "forged Open Ledger option rejection is absent from replay", failures)

func test_elite_skip_effects_and_saved_drafts(failures: Array[String]) -> void:
	var quiet_domain := _alpha_domain("contract.quiet.skip", AlphaScaleCatalog.CONTRACT_IDS[0])
	_open_elite_reward(quiet_domain, "quiet-skip")
	var quiet_skip = _option_by_kind(quiet_domain.state.reward_draft, RewardOption.SKIP)
	assert_true(quiet_skip != null and quiet_skip.gold_delta == 10 and quiet_skip.refinement_token_delta == 1, "Quiet Current Elite Skip grants default Gold and one Refinement Token", failures)
	if quiet_skip != null:
		var quiet_result = quiet_domain.execute(ChooseRewardCommand.new("contract.quiet.skip.choose", quiet_skip.option_id, quiet_domain.state.reward_draft.draft_id))
		assert_true(quiet_result.accepted and quiet_result.replayable, "Quiet Current Elite Skip is an accepted replayable reward", failures)
		assert_true(quiet_domain.state.gold == 10 and quiet_domain.state.refinement_tokens == 1, "Quiet Current Elite Skip applies both configured currencies", failures)

	var brittle_domain := _alpha_domain("contract.brittle.skip", AlphaScaleCatalog.CONTRACT_IDS[2])
	_open_elite_reward(brittle_domain, "brittle-skip")
	var brittle_skip = _option_by_kind(brittle_domain.state.reward_draft, RewardOption.SKIP)
	assert_true(brittle_skip != null and brittle_skip.gold_delta == 8 and brittle_skip.refinement_token_delta == 0, "Brittle Compass Elite Skip reduces the configured Gold by two", failures)
	var elite_snapshot = SaveMapper.suspend_snapshot(brittle_domain)
	var loaded_elite = SaveMapper.load_into_domain(elite_snapshot.to_dictionary(), brittle_domain.content_registry)
	assert_true(loaded_elite.accepted, "a Brittle Compass Elite draft passes authoritative save validation", failures)
	if loaded_elite.accepted:
		var loaded_skip = _option_by_kind(loaded_elite.domain.state.reward_draft, RewardOption.SKIP)
		assert_true(loaded_skip != null and loaded_skip.gold_delta == 8, "save restoration preserves Brittle Compass Elite Skip compensation", failures)

	if brittle_skip != null:
		brittle_skip.gold_delta = 10
		var before_forgery := brittle_domain.checkpoint()
		var rng_before_forgery := brittle_domain.rng_snapshot()
		var replay_count: int = brittle_domain.replay_record.commands.size()
		var forged = brittle_domain.execute(ChooseRewardCommand.new("contract.brittle.skip.forged", brittle_skip.option_id, brittle_domain.state.reward_draft.draft_id))
		assert_true(not forged.accepted and forged.validation.code == "INVALID_REWARD_OPTION", "a forged Elite Skip cannot restore the reduced Gold", failures)
		assert_true(brittle_domain.checkpoint() == before_forgery and brittle_domain.rng_snapshot() == rng_before_forgery, "forged Elite Skip rejection leaves state and RNG unchanged", failures)
		assert_true(brittle_domain.replay_record.commands.size() == replay_count, "forged Elite Skip rejection is absent from replay", failures)

func test_brittle_compass_adds_distinct_modified_choice(failures: Array[String]) -> void:
	var domain := _alpha_domain("contract.brittle.normal", AlphaScaleCatalog.CONTRACT_IDS[2])
	var draft = _normal_draft(domain, "brittle-compass")
	var repeat_domain := _alpha_domain("contract.brittle.normal", AlphaScaleCatalog.CONTRACT_IDS[2])
	var repeat_draft = _normal_draft(repeat_domain, "brittle-compass")
	assert_true(draft != null and repeat_draft != null, "Brittle Compass creates repeatable normal reward drafts", failures)
	if draft == null or repeat_draft == null:
		return
	var modified_options := _options_of_kind(draft, RewardOption.MODIFIED_TILE)
	assert_true(modified_options.size() == 2, "Brittle Compass adds a second Modified Tile choice when a valid pair exists", failures)
	assert_true(draft.options.size() == 4, "Brittle Compass keeps the normal choices and appends its extra choice", failures)
	var dots_preference_found := false
	for option in draft.options:
		if option.kind == RewardOption.ADD_TILE and option.tile_id in ["base.tile.dots.4", "base.tile.dots.5", "base.tile.dots.6"]:
			dots_preference_found = true
	assert_true(dots_preference_found, "Brittle Compass biases Normal Add Tile choices toward Dots 4–6", failures)
	if modified_options.size() == 2:
		var first_pair := "%s|%s" % [modified_options[0].target_instance_id, modified_options[0].modifier_id]
		var second_pair := "%s|%s" % [modified_options[1].target_instance_id, modified_options[1].modifier_id]
		assert_true(first_pair != second_pair, "Brittle Compass Modified Tile choices use distinct target-instance/modifier pairs", failures)
		domain.state.phase = RunPhase.REWARD_CHOICE
		domain.state.reward_draft = draft
		var validation = domain.validate_choose_reward(draft.draft_id, modified_options[1].option_id)
		assert_true(validation.is_valid(), "the extra Modified Tile pair is legal under authoritative validation", failures)
	assert_true(draft.to_dictionary() == repeat_draft.to_dictionary(), "Brittle Compass extra choice repeats exactly for a fixed seed", failures)
	assert_true(domain.rng_snapshot()["streams"]["reward"] == repeat_domain.rng_snapshot()["streams"]["reward"], "Brittle Compass extra choice preserves deterministic Reward RNG", failures)

func test_stale_contract_reward_options_are_rejected_atomically(failures: Array[String]) -> void:
	var domain := _alpha_domain("contract.brittle.stale", AlphaScaleCatalog.CONTRACT_IDS[2])
	var draft = _normal_draft(domain, "brittle-stale")
	if draft == null:
		assert_true(false, "Brittle Compass stale-option fixture creates a draft", failures)
		return
	domain.state.phase = RunPhase.REWARD_CHOICE
	domain.state.reward_draft = draft
	var modified = _option_by_kind(draft, RewardOption.MODIFIED_TILE)
	if modified == null:
		assert_true(false, "Brittle Compass stale-option fixture has a Modified Tile choice", failures)
		return
	modified.target_instance_id = "run.tile.no-longer-owned"
	var before := domain.checkpoint()
	var rng_before := domain.rng_snapshot()
	var replay_count: int = domain.replay_record.commands.size()
	var result = domain.execute(ChooseRewardCommand.new("contract.brittle.stale.choose", modified.option_id, draft.draft_id))
	assert_true(not result.accepted and result.validation.code == "INVALID_REWARD_TARGET", "a stale Brittle Compass Modified Tile target is rejected", failures)
	assert_true(domain.checkpoint() == before and domain.rng_snapshot() == rng_before, "stale Modified Tile rejection leaves state and RNG unchanged", failures)
	assert_true(domain.replay_record.commands.size() == replay_count, "stale Modified Tile rejection is absent from replay", failures)

func test_brittle_compass_omits_extra_when_only_one_pair_exists(failures: Array[String]) -> void:
	var tiny_registry := ContentRegistry.new()
	var brittle = null
	for definition in AlphaScaleCatalog.definitions():
		if definition is ContractDefinition and definition.content_id == AlphaScaleCatalog.CONTRACT_IDS[2]:
			brittle = definition
	tiny_registry.register(brittle)
	tiny_registry.register(TileDefinition.new("base.tile.characters.1", "characters", 1))
	tiny_registry.register(TileModifierDefinition.new("base.modifier.only", "ONLY", 1))
	var tile_pool := RunTilePoolState.new([RunTileInstanceRecord.new("one.valid.target", "base.tile.characters.1", "RUN", "RUN")])
	var state := RunState.new("contract.brittle.one-pair", 91, "", tile_pool, null, 1)
	state.contract_id = AlphaScaleCatalog.CONTRACT_IDS[2]
	var streams := DomainRngStreams.new(91)
	var draft = RewardDraftSelector.new().create_normal_draft(state, tiny_registry, streams.reward, "one.valid.pair", 0)
	assert_true(draft != null, "a one-pair Brittle Compass draft still exists", failures)
	if draft != null:
		assert_true(_options_of_kind(draft, RewardOption.MODIFIED_TILE).size() == 1, "Brittle Compass omits its extra choice when no second valid pair exists", failures)

func test_brittle_compass_workshop_refinement_surcharge(failures: Array[String]) -> void:
	var domain := _alpha_domain("contract.brittle.workshop", AlphaScaleCatalog.CONTRACT_IDS[2])
	domain.state.phase = RunPhase.WORKSHOP
	domain.state.workshop_state.begin("workshop.test", "workshop.contract.brittle")
	domain.state.gold = 100
	domain.state.refinement_tokens = 1
	var tile_id: String = domain.state.tile_pool.tile_instances[0].instance_id
	var result = domain.execute(UseWorkshopServiceCommand.new(
		"contract.brittle.workshop.refine",
		UseWorkshopServiceCommand.REFINEMENT_TOKEN,
		tile_id,
	))
	assert_true(result.accepted, "Brittle Compass can purchase Workshop Refinement Token service", failures)
	assert_true(domain.state.gold == 100 - domain.economy.workshop_refinement_price - 1, "Brittle Compass adds one Gold to Workshop Refinement Token service price", failures)

func test_phase_2_contract_defaults_remain_unchanged(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var domain := RunDomain.new("contract.phase2.defaults", 103, registry)
	domain.execute(ChooseCharacterCommand.new("contract.phase2.defaults.character", Phase2Catalog.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommand.new("contract.phase2.defaults.contract", Phase2Catalog.CONTRACT_IDS[0]))
	var result = domain.execute(SelectMapNodeCommand.new("contract.phase2.defaults.battle", domain.map_definition.start_node_id))
	assert_true(result.accepted, "the Phase 2 Contract still starts a normal battle", failures)
	if domain.current_battle != null:
		assert_true(domain.current_battle.combat_state.pressure == 0 and domain.current_battle.combat_state.tp == 0, "Phase 2 battle start Pressure and TP remain unchanged", failures)
	var draft = _normal_draft(domain, "phase2-defaults")
	assert_true(draft != null and draft.options.size() == 3, "Phase 2 normal reward keeps its three-choice contract", failures)
	assert_true(domain.state.refinement_tokens == 0, "Phase 2 Contract selection grants no Alpha Refinement Token", failures)

func test_scale_version_rejects_inert_v1_snapshot(failures: Array[String]) -> void:
	var registry := _registry()
	var active_version := registry.content_version()
	var old_scale_version := "content.bundle.v1.alpha.act_two@v1+alpha.scale@v1+phase2@v2"
	assert_true(active_version != old_scale_version and active_version.contains("alpha.scale@v7"), "the expanded Stage 4 content advances the Scale bundle identity", failures)
	var domain := _alpha_domain("contract.version.snapshot", AlphaScaleCatalog.CONTRACT_IDS[2])
	var snapshot = SaveMapper.suspend_snapshot(domain).to_dictionary()
	snapshot["content_version"] = old_scale_version
	snapshot["authoritative_state"]["content_version"] = old_scale_version
	var validation = LoadValidator.new().validate(snapshot, registry)
	var rejected_old_bundle := false
	for error in validation.errors:
		if error.get("code", "") == "UNSUPPORTED_CONTENT_VERSION":
			rejected_old_bundle = true
	assert_true(rejected_old_bundle, "Alpha Scale v1 saves are rejected rather than relabeled with the new Contract behavior", failures)

func _registry() -> ContentRegistry:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	AlphaScaleCatalog.register_all(registry)
	return registry

func _domain_with_character(run_id: String, registry: ContentRegistry, unlock_policy) -> RunDomain:
	var domain: RunDomain = RunDomain.new_alpha_run(run_id, 530, registry, "", null, null, unlock_policy)
	var character = domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, Phase2Catalog.CHARACTER_IDS[0]))
	return domain

func _alpha_domain(run_id: String, contract_id: String) -> RunDomain:
	var registry := _registry()
	var domain := _domain_with_character(run_id, registry, MetaProgressState.all_unlocked_test_profile())
	var selected = domain.execute(ChooseContractCommand.new("%s.contract" % run_id, contract_id))
	assert_true(selected.accepted, "Alpha effect fixture selects its Contract", [])
	return domain

func _normal_draft(domain: RunDomain, suffix: String):
	return domain.reward_draft_selector.create_normal_draft(
		domain.state,
		domain.content_registry,
		domain.rng_streams.reward,
		"%s.%s" % [domain.state.run_id, suffix],
		0,
		domain.economy.normal_skip_gold,
		domain.economy.tile_copy_limit,
	)

func _open_elite_reward(domain: RunDomain, suffix: String) -> void:
	var battle = domain.encounter_factory.create(domain.state, "base.encounter.elite", domain.rng_streams, EncounterDefinition.ELITE)
	if battle == null:
		return
	domain.current_battle = battle
	domain.state.phase = RunPhase.BATTLE
	battle.combat_resolver.resolve_player_action(battle.combat_state, 9999)
	domain.apply_battle_outcome()

func _event_of_type(events: Array, event_type: String):
	for event in events:
		if event.event_type == event_type:
			return event
	return null

func _has_event(events: Array, event_type: String) -> bool:
	return _event_of_type(events, event_type) != null

func _option_by_kind(draft, kind: String):
	if draft == null:
		return null
	for option in draft.options:
		if option.kind == kind:
			return option
	return null

func _options_of_kind(draft, kind: String) -> Array:
	var result: Array = []
	if draft == null:
		return result
	for option in draft.options:
		if option.kind == kind:
			result.append(option)
	return result

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
