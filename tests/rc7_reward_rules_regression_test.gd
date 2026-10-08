extends RefCounted

const ChooseRewardCommandScript = preload("res://src/domain/commands/choose_reward_command.gd")
const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const ContentDefinitionScript = preload("res://src/content/definitions/content_definition.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const RewardDraftScript = preload("res://src/domain/run/reward_draft.gd")
const RewardDraftSelectorScript = preload("res://src/domain/run/reward_draft_selector.gd")
const RewardOptionScript = preload("res://src/domain/run/reward_option.gd")
const RewardPoolDefinitionScript = preload("res://src/content/definitions/reward_pool_definition.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")
const ReplayCommandFactoryScript = preload("res://src/infrastructure/replay/replay_command_factory.gd")
const ReplayDivergenceReportScript = preload("res://src/infrastructure/replay/replay_divergence_report.gd")
const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")

const RESERVE_ID := "base.character.reserve"
const NORMAL_DRAFT := "NORMAL"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_reserve_drafts_preserve_each_excluded_suit_boundary(failures)
	test_normal_pivot_bias_cannot_authorize_an_excluded_tile(failures)
	test_normal_modified_reward_lets_the_player_choose_a_type(failures)
	test_targeted_modifier_applies_two_sorted_eligible_copies_and_round_trips(failures)
	test_targeted_reward_rejects_non_run_scope_targets(failures)
	test_legacy_fixed_modifier_still_targets_one_instance(failures)
	test_full_reserve_draft_has_distinct_modifier_choices(failures)
	test_elite_pivot_is_explicit_and_accepted(failures)
	test_sequence_tied_suit_counts_stay_neutral(failures)
	return failures

func test_reserve_drafts_preserve_each_excluded_suit_boundary(failures: Array[String]) -> void:
	for excluded_suit in ["characters", "dots", "bamboo"]:
		var domain: Variant = _reserve_domain("rc7.reserve.boundary.%s" % excluded_suit, excluded_suit, true)
		var draft = domain.reward_draft_selector.create_normal_draft(
			domain.state,
			domain.content_registry,
			domain.rng_streams.reward,
			"rc7.boundary.%s" % excluded_suit,
			0,
			domain.economy.normal_skip_gold,
			domain.economy.tile_copy_limit,
		)
		_assert(draft != null, "Reserve creates an ordinary reward draft for excluded suit %s" % excluded_suit, failures)
		if draft == null:
			continue
		var add_count := 0
		for option in draft.options:
			if option.kind != RewardOptionScript.ADD_TILE:
				continue
			add_count += 1
			var tile_definition = domain.content_registry.resolve(option.tile_id)
			_assert(tile_definition != null and tile_definition.suit != excluded_suit, "ordinary Reserve Add Tile never reintroduces excluded suit %s" % excluded_suit, failures)
			_assert(tile_definition != null and tile_definition.suit != "honors", "ordinary Reserve Add Tile never introduces honors", failures)
			_assert(not bool(option.metadata.get("special_pivot", false)), "ordinary Reserve Add Tile is never mislabeled as a special pivot", failures)
		_assert(add_count == 0, "Reserve with four copies of every retained type has no ordinary Add Tile candidates", failures)

func test_normal_pivot_bias_cannot_authorize_an_excluded_tile(failures: Array[String]) -> void:
	var domain: Variant = _reserve_domain("rc7.pivot.forgery", "characters", true)
	domain.state.phase = RunPhaseScript.REWARD_CHOICE
	var draft_id := "reward.normal.rc7.forged-pivot.0"
	var forged_pivot := RewardOptionScript.new(
		"%s.option.0" % draft_id,
		RewardOptionScript.ADD_TILE,
		"base.tile.characters.1",
		"base.tile.characters.1",
		"",
		"",
		RewardOptionScript.PIVOT,
		0,
		0,
		{"special_pivot": true},
	)
	var skip: Variant = _skip_option("%s.option.1" % draft_id)
	domain.state.reward_draft = RewardDraftScript.new(draft_id, NORMAL_DRAFT, "rc7.forged-pivot", "NORMAL", [forged_pivot, skip])
	var validation = domain.validate_choose_reward(draft_id, forged_pivot.option_id)
	_assert(not validation.is_valid(), "PIVOT context and a forged special_pivot flag cannot authorize a normal Reserve excluded tile", failures)
	_assert(validation.code == "PIVOT_PROVENANCE_REQUIRED", "a normal excluded-tile Add Tile reports missing special pivot provenance", failures)
	var checkpoint_before: Dictionary = domain.checkpoint()
	var forged_result = domain.execute(ChooseRewardCommandScript.new("rc7.normal.pivot.forged", forged_pivot.option_id, draft_id))
	_assert(not forged_result.accepted, "the forged normal Pivot cannot be executed", failures)
	_assert(domain.checkpoint() == checkpoint_before, "a rejected forged normal Pivot leaves state unchanged", failures)
	var forged_snapshot = SaveMapperScript.suspend_snapshot(domain)
	var forged_load = SaveMapperScript.load_into_domain(forged_snapshot.to_dictionary(), domain.content_registry)
	_assert(not bool(forged_load.get("accepted", false)) and _has_error_code(forged_load.get("errors", []), "NORMAL_REWARD_CANNOT_PIVOT"), "LoadValidator rejects Pivot provenance attached to a normal reward draft", failures)

func test_normal_modified_reward_lets_the_player_choose_a_type(failures: Array[String]) -> void:
	var domain: Variant = _reserve_domain("rc7.targeted.modifier", "characters", false)
	for tile_index in range(3):
		domain.state.tile_pool.add_tile_instance(RunTileInstanceRecordScript.new(
			"rc7.targeted.dots.%d" % tile_index,
			"base.tile.dots.1",
			"RUN",
			"RUN",
		))
	domain.state.phase = RunPhaseScript.REWARD_CHOICE
	var draft = domain.reward_draft_selector.create_normal_draft(domain.state, domain.content_registry, domain.rng_streams.reward, "rc7.targeted", 0)
	domain.state.reward_draft = draft
	var modified = _find_option(draft, RewardOptionScript.MODIFIED_TILE)
	_assert(modified != null, "a normal reward draft offers a build modifier", failures)
	if modified == null:
		return
	_assert(str(modified.metadata.get("target_mode", "")) == "CHOOSE_TYPE", "a new Modified Tile reward asks the player to choose an owned tile type", failures)
	_assert(int(modified.metadata.get("target_limit", 0)) == 2, "a targeted modifier can affect at most two owned physical copies", failures)
	_assert(modified.target_instance_id.is_empty(), "a new targeted modifier does not silently select one random physical instance", failures)

func test_targeted_modifier_applies_two_sorted_eligible_copies_and_round_trips(failures: Array[String]) -> void:
	var domain: Variant = _reserve_domain("rc7.targeted.apply", "characters", false)
	for tile_index in range(3):
		domain.state.tile_pool.add_tile_instance(RunTileInstanceRecordScript.new(
			"rc7.apply.dots.%d" % tile_index,
			"base.tile.dots.1",
			"RUN",
			"RUN",
		))
	domain.state.phase = RunPhaseScript.REWARD_CHOICE
	var draft = domain.reward_draft_selector.create_normal_draft(domain.state, domain.content_registry, domain.rng_streams.reward, "rc7.targeted.apply", 0)
	domain.state.reward_draft = draft
	var modified = _find_option(draft, RewardOptionScript.MODIFIED_TILE)
	_assert(modified != null, "the targeted reward fixture has a Modified Tile choice", failures)
	if modified == null:
		return
	domain.state.build_ownership.persistent_tile_modifier_state["rc7.apply.dots.0"] = [modified.modifier_id, modified.modifier_id]
	var choices: Dictionary = domain.reward_target_choices(modified.option_id)
	_assert(bool(choices.get("accepted", false)), "the active targeted option exposes eligible owned tile types", failures)
	var chosen_group: Dictionary = {}
	for group in choices.get("choices", []):
		if str(group.get("tile_id", "")) == "base.tile.dots.1":
			chosen_group = group
	_assert(chosen_group.get("eligible_instance_ids", []) == ["rc7.apply.dots.1", "rc7.apply.dots.2"], "target choice excludes the copy at modifier cap and sorts the remaining physical instances", failures)
	_assert(int(chosen_group.get("count", 0)) == 2 and int(chosen_group.get("target_limit", 0)) == 2, "the target UI receives the exact two-copy effect count", failures)
	var snapshot = SaveMapperScript.suspend_snapshot(domain)
	var restored = SaveMapperScript.load_into_domain(snapshot.to_dictionary(), domain.content_registry)
	_assert(bool(restored.get("accepted", false)), "a pending target-type reward draft survives save restoration", failures)
	if not bool(restored.get("accepted", false)):
		return
	var restored_domain = restored.domain
	var restored_option = restored_domain.state.reward_draft.option_by_id(modified.option_id)
	_assert(restored_option != null and str(restored_option.metadata.get("target_mode", "")) == "CHOOSE_TYPE", "save restoration preserves targeted modifier metadata", failures)
	var restored_choices: Dictionary = restored_domain.reward_target_choices(modified.option_id)
	var restored_group: Dictionary = {}
	for group in restored_choices.get("choices", []):
		if str(group.get("tile_id", "")) == "base.tile.dots.1":
			restored_group = group
	_assert(restored_group == chosen_group, "save restoration preserves sorted target IDs and effect count", failures)
	_assert(restored_domain.reward_target_choices(modified.option_id) == choices, "a generated targeted reward preserves the same target choices across SaveMapper restoration", failures)
	var missing_target = restored_domain.execute(ChooseRewardCommandScript.new("rc7.targeted.missing", modified.option_id, draft.draft_id))
	_assert(not missing_target.accepted and missing_target.validation.code == "TARGET_TILE_TYPE_REQUIRED", "a targeted modifier cannot execute until the player chooses a type", failures)
	var result = restored_domain.execute(ChooseRewardCommandScript.new("rc7.targeted.apply", modified.option_id, draft.draft_id, "", "", false, "base.tile.dots.1"))
	_assert(result.accepted, "the chosen tile type is accepted through the public reward command", failures)
	var expected_ids: Array[String] = ["rc7.apply.dots.1", "rc7.apply.dots.2"]
	_assert(result.data.get("target_instance_ids", []) == expected_ids, "the accepted reward reports exact sorted physical target IDs", failures)
	_assert(int(result.data.get("target_count", 0)) == 2, "the accepted reward reports the number of affected copies", failures)
	for instance_id in expected_ids:
		_assert(restored_domain.state.build_ownership.persistent_tile_modifier_state.get(instance_id, []).has(modified.modifier_id), "the selected modifier applies to both chosen copies", failures)
	var recorded_command = restored_domain.replay_record.commands.back()
	_assert(str(recorded_command.payload.get("target_tile_id", "")) == "base.tile.dots.1", "the replay command persists the selected target type", failures)
	var replayed_command = ReplayCommandFactoryScript.from_record(recorded_command)
	_assert(str(replayed_command.target_tile_id) == "base.tile.dots.1", "replay decoding preserves the selected target type", failures)
	var replay_report = restored_domain.verify_replay()
	_assert(replay_report.status == ReplayDivergenceReportScript.MATCH, "the restored targeted reward command replays to an exact checkpoint match (%s: %s)" % [replay_report.status, replay_report.reason], failures)
	var legacy_command := ChooseRewardCommandScript.new("rc7.targeted.legacy-payload", "option", "draft")
	_assert(not legacy_command.to_dictionary().has("target_tile_id"), "legacy ChooseReward command payloads omit an empty target field", failures)

func test_targeted_reward_rejects_non_run_scope_targets(failures: Array[String]) -> void:
	var domain: Variant = _reserve_domain("rc7.targeted.scope-filter", "", false)
	domain.state.tile_pool.add_tile_instance(RunTileInstanceRecordScript.new(
		"rc7.scope.battle-owned",
		"base.tile.honors.east",
		"BATTLE",
		"RUN",
	))
	domain.state.tile_pool.add_tile_instance(RunTileInstanceRecordScript.new(
		"rc7.scope.battle-lifetime",
		"base.tile.honors.red",
		"RUN",
		"BATTLE",
	))
	domain.state.phase = RunPhaseScript.REWARD_CHOICE
	var generated_draft = domain.reward_draft_selector.create_normal_draft(
		domain.state,
		domain.content_registry,
		domain.rng_streams.reward,
		"scope-filter",
		0,
	)
	_assert(_find_option(generated_draft, RewardOptionScript.MODIFIED_TILE) == null, "reward generation does not offer modifiers whose only targets have non-RUN ownership or lifetime", failures)
	var draft_id := "reward.rc7.scope-filter"
	var targeted_option := RewardOptionScript.new(
		"%s.option.0" % draft_id,
		RewardOptionScript.MODIFIED_TILE,
		"base.modifier.ritual_mark",
		"",
		"base.modifier.ritual_mark",
		"",
		RewardOptionScript.NEUTRAL,
		0,
		0,
		{"target_mode": "CHOOSE_TYPE", "target_limit": 2},
	)
	domain.state.reward_draft = RewardDraftScript.new(draft_id, NORMAL_DRAFT, "scope-filter", "NORMAL", [targeted_option, _skip_option("%s.option.1" % draft_id)])
	var target_choices: Dictionary = domain.reward_target_choices(targeted_option.option_id)
	_assert(not bool(target_choices.get("accepted", false)) and target_choices.get("choices", []).is_empty(), "target type choices exclude RUN-owned tiles with non-RUN lifetime and non-RUN-owned tiles with RUN lifetime", failures)
	for tile_id in ["base.tile.honors.east", "base.tile.honors.red"]:
		var result = domain.execute(ChooseRewardCommandScript.new(
			"rc7.scope.reject.%s" % tile_id.get_slice(".", -1),
			targeted_option.option_id,
			draft_id,
			"",
			"",
			false,
			tile_id,
		))
		_assert(not result.accepted and result.validation.code == "INVALID_REWARD_TARGET", "authoritative choice rejects non-persistent target type %s" % tile_id, failures)

func test_legacy_fixed_modifier_still_targets_one_instance(failures: Array[String]) -> void:
	var domain: Variant = _reserve_domain("rc7.targeted.legacy-fixed", "characters", false)
	var instance_id := "rc7.legacy.fixed.dots"
	domain.state.tile_pool.add_tile_instance(RunTileInstanceRecordScript.new(instance_id, "base.tile.dots.1", "RUN", "RUN"))
	domain.state.phase = RunPhaseScript.REWARD_CHOICE
	var option := RewardOptionScript.new("rc7.legacy.fixed.option", RewardOptionScript.MODIFIED_TILE, "base.modifier.ritual_mark", "base.tile.dots.1", "base.modifier.ritual_mark", instance_id)
	domain.state.reward_draft = RewardDraftScript.new("rc7.legacy.fixed.draft", NORMAL_DRAFT, "legacy", "NORMAL", [option, _skip_option("rc7.legacy.fixed.skip")])
	var result = domain.execute(ChooseRewardCommandScript.new("rc7.legacy.fixed.choose", option.option_id, domain.state.reward_draft.draft_id))
	_assert(result.accepted, "a legacy fixed-target Modified Tile remains selectable without a type argument", failures)
	_assert(result.data.get("target_instance_ids", []) == [instance_id], "a legacy Modified Tile still affects exactly its saved target", failures)

func test_full_reserve_draft_has_distinct_modifier_choices(failures: Array[String]) -> void:
	var domain: Variant = _reserve_domain("rc7.reserve.modifier-options", "dots", true)
	var draft = domain.reward_draft_selector.create_normal_draft(domain.state, domain.content_registry, domain.rng_streams.reward, "rc7.reserve.modifier-options", 0)
	var modifier_ids: Array[String] = []
	var add_count := 0
	for option in draft.options:
		if option.kind == RewardOptionScript.MODIFIED_TILE:
			modifier_ids.append(option.modifier_id)
		elif option.kind == RewardOptionScript.ADD_TILE:
			add_count += 1
	modifier_ids.sort()
	_assert(add_count == 0, "a full retained Reserve build is not pushed toward excluded Add Tile rewards", failures)
	_assert(modifier_ids.size() >= 2, "Reserve receives two meaningful modifier choices when no retained Add Tile is available", failures)
	var unique_modifier_ids: Dictionary = {}
	for modifier_id in modifier_ids:
		unique_modifier_ids[modifier_id] = true
	_assert(modifier_ids.size() == unique_modifier_ids.size(), "Reserve modifier choices are distinct rather than duplicate cards", failures)
	_assert(_find_option(draft, RewardOptionScript.SKIP) != null, "the full Reserve draft still includes Skip", failures)

func test_elite_pivot_is_explicit_and_accepted(failures: Array[String]) -> void:
	var domain: Variant = _reserve_domain("rc7.elite.pivot", "bamboo", true)
	var pool_id := "base.reward_pool.rc7_elite"
	var pivot_pool := RewardPoolDefinitionScript.new(pool_id, [
		{"content_id": "base.relic.open_hand", "weight": 1},
		{"content_id": "base.relic.steady_hand", "weight": 1},
		{"content_id": "base.relic.clear_sight", "weight": 1},
		{"content_id": "base.technique.draw_surge", "weight": 1},
		{"content_id": "base.technique.pressure_break", "weight": 1},
	])
	domain.content_registry.register(pivot_pool)
	var draft = domain.reward_draft_selector.create_elite_build_draft(domain.state, domain.content_registry, domain.rng_streams.reward, "rc7.elite", 0, pool_id)
	_assert(draft != null and draft.options.size() == 5, "Reserve Elite drafts retain their four build/Skip offers and append one eligible explicit pivot", failures)
	if draft == null:
		return
	var pivot = null
	for option in draft.options:
		if option.kind == RewardOptionScript.ADD_TILE and bool(option.metadata.get("special_pivot", false)):
			pivot = option
	_assert(pivot != null, "the Elite tile introduction is labeled with special_pivot provenance", failures)
	if pivot == null:
		return
	var tile_definition = domain.content_registry.resolve(pivot.tile_id)
	_assert(tile_definition != null and tile_definition.suit in ["bamboo", "honors"], "the Elite special pivot introduces only the excluded suit or honors", failures)
	domain.state.phase = RunPhaseScript.ELITE_REWARD
	domain.state.reward_draft = draft
	var pending_elite_snapshot = SaveMapperScript.suspend_snapshot(domain)
	var pending_elite_load = SaveMapperScript.load_into_domain(pending_elite_snapshot.to_dictionary(), domain.content_registry)
	_assert(bool(pending_elite_load.get("accepted", false)), "LoadValidator accepts a generated five-option Elite draft with an explicit Pivot", failures)
	var restored_pivot = null
	if bool(pending_elite_load.get("accepted", false)):
		var restored_elite_domain = pending_elite_load.domain
		var restored_elite_draft = restored_elite_domain.state.reward_draft
		_assert(restored_elite_draft != null and restored_elite_draft.options.size() == 5, "SaveMapper restores all five explicit Elite offers", failures)
		for option in restored_elite_draft.options:
			if option.kind == RewardOptionScript.ADD_TILE and bool(option.metadata.get("special_pivot", false)):
				restored_pivot = option
	if bool(pending_elite_load.get("accepted", false)):
		var forged_snapshot: Dictionary = pending_elite_snapshot.to_dictionary()
		var forged_options: Array = forged_snapshot.authoritative_state.reward_draft.options
		for option_data in forged_options:
			if option_data.get("kind", "") == RewardOptionScript.ADD_TILE:
				option_data.metadata["pivot_kind"] = "NOT_A_PIVOT"
		forged_snapshot.run_state = forged_snapshot.authoritative_state.duplicate(true)
		var forged_load = SaveMapperScript.load_into_domain(forged_snapshot, domain.content_registry)
		_assert(not bool(forged_load.get("accepted", false)) and _has_error_code(forged_load.get("errors", []), "INVALID_ELITE_PIVOT_PROVENANCE"), "LoadValidator rejects a forged or mislabeled Elite Pivot", failures)
	var validation = domain.reward_flow.validate_choice(draft.draft_id, pivot.option_id)
	_assert(validation.is_valid(), "a generated explicitly labeled Elite pivot passes authoritative validation", failures)
	var result = domain.execute(ChooseRewardCommandScript.new("rc7.elite.pivot.choose", pivot.option_id, draft.draft_id))
	_assert(result.accepted, "the valid Elite pivot executes through ChooseRewardCommand", failures)
	_assert(domain.state.tile_pool.tile_instances.size() == 73, "the explicit Elite pivot adds exactly one owned tile", failures)
	if pending_elite_load.get("accepted", false) and restored_pivot != null:
		var restored_elite_domain = pending_elite_load.domain
		var restored_elite_draft = restored_elite_domain.state.reward_draft
		var restored_result = restored_elite_domain.execute(ChooseRewardCommandScript.new(
			"rc7.elite.pivot.restored-choose",
			restored_pivot.option_id,
			restored_elite_draft.draft_id,
		))
		_assert(restored_result.accepted, "the restored explicit Elite Pivot remains executable after SaveMapper round-trip", failures)
		_assert(restored_elite_domain.state.tile_pool.tile_instances.size() == 73, "the restored Elite Pivot adds exactly one tile", failures)
		var replay_report = restored_elite_domain.verify_replay()
		_assert(replay_report.status == ReplayDivergenceReportScript.MATCH, "the restored Elite Pivot command replays to an exact checkpoint match", failures)

func test_sequence_tied_suit_counts_stay_neutral(failures: Array[String]) -> void:
	var domain: Variant = _reserve_domain("rc7.sequence.neutral", "", false)
	domain.state.character_id = "base.character.sequence"
	for suit in ["characters", "dots", "bamboo"]:
		for rank in range(1, 10):
			for copy_index in range(2):
				domain.state.tile_pool.add_tile_instance(RunTileInstanceRecordScript.new(
					"rc7.sequence.%s.%d.%d" % [suit, rank, copy_index],
					"base.tile.%s.%d" % [suit, rank],
					"RUN",
					"RUN",
				))
	for honor in ["east", "south", "west", "north", "red", "green", "white"]:
		for copy_index in range(2):
			domain.state.tile_pool.add_tile_instance(RunTileInstanceRecordScript.new(
				"rc7.sequence.honors.%s.%d" % [honor, copy_index],
				"base.tile.honors.%s" % honor,
				"RUN",
				"RUN",
			))
	var draft = domain.reward_draft_selector.create_normal_draft(domain.state, domain.content_registry, domain.rng_streams.reward, "rc7.sequence.neutral", 0)
	for option in draft.options:
		if option.kind == RewardOptionScript.ADD_TILE:
			_assert(option.context_bias == RewardOptionScript.NEUTRAL, "Sequence with tied actual suit counts does not receive a lexical dominant-suit bias", failures)

func _reserve_domain(run_id: String, excluded_suit: String, fill_retained_suits: bool):
	var registry: Variant = _content_registry()
	var domain := RunDomainScript.new(run_id, 73911, registry)
	domain.state.character_id = RESERVE_ID
	domain.state.excluded_suit = excluded_suit
	domain.state.phase = RunPhaseScript.REWARD_CHOICE
	if fill_retained_suits:
		for suit in ["characters", "dots", "bamboo"]:
			if suit == excluded_suit:
				continue
			for rank in range(1, 10):
				for copy_index in range(4):
					domain.state.tile_pool.add_tile_instance(RunTileInstanceRecordScript.new(
						"%s.%s.%d.%d" % [run_id, suit, rank, copy_index],
						"base.tile.%s.%d" % [suit, rank],
						"RUN",
						"RUN",
					))
	return domain

func _content_registry():
	var registry := ContentRegistryScript.new()
	for suit in ["characters", "dots", "bamboo"]:
		for rank in range(1, 10):
			registry.register(TileDefinitionScript.new("base.tile.%s.%d" % [suit, rank], suit, rank))
	for honor in ["east", "south", "west", "north", "red", "green", "white"]:
		registry.register(TileDefinitionScript.new("base.tile.honors.%s" % honor, "honors", 0))
	registry.register(TileModifierDefinitionScript.new("base.modifier.ritual_mark", "RITUAL_MARK", 2))
	registry.register(TileModifierDefinitionScript.new("base.modifier.flexible_identity", "FLEXIBLE_IDENTITY", 2))
	registry.register(TileModifierDefinitionScript.new("base.modifier.second_mark", "SECOND_MARK", 2))
	registry.register(RelicDefinitionScript.new("base.relic.open_hand"))
	registry.register(RelicDefinitionScript.new("base.relic.steady_hand"))
	registry.register(RelicDefinitionScript.new("base.relic.clear_sight"))
	registry.register(TechniqueDefinitionScript.new("base.technique.draw_surge", TechniqueDefinitionScript.ACTIVE, 0))
	registry.register(TechniqueDefinitionScript.new("base.technique.pressure_break", TechniqueDefinitionScript.PASSIVE, 0))
	registry.register(TechniqueDefinitionScript.new("base.technique.core.sequence_line", TechniqueDefinitionScript.CORE, 1))
	registry.register(ContentDefinitionScript.new("base.passive.sequence"))
	registry.register(CharacterDefinitionScript.new(RESERVE_ID, ["base.tile.characters.1"], "base.relic.open_hand", "base.technique.core.sequence_line", "base.passive.sequence"))
	registry.register(CharacterDefinitionScript.new("base.character.sequence", ["base.tile.characters.1"], "base.relic.open_hand", "base.technique.core.sequence_line", "base.passive.sequence"))
	return registry

func _skip_option(option_id: String):
	return RewardOptionScript.new(option_id, RewardOptionScript.SKIP, RewardOptionScript.SKIP_CONTENT_ID, "", "", "", RewardOptionScript.NEUTRAL, 5)

func _find_option(draft, kind: String):
	if draft == null:
		return null
	for option in draft.options:
		if option.kind == kind:
			return option
	return null

func _has_error_code(errors: Array, expected_code: String) -> bool:
	for error in errors:
		if error is Dictionary and str(error.get("code", "")) == expected_code:
			return true
	return false

func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
