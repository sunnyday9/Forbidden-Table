class_name RunPresentationTest
extends RefCounted

const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const SettleCompleteHandCommand = preload("res://src/domain/commands/settle_complete_hand_command.gd")
const SuspendSaveStore = preload("res://src/infrastructure/persistence/suspend_save_store.gd")
const PublicActRouteFixture = preload("res://tests/fixtures/public_act_route_fixture.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const Localization = preload("res://src/presentation/localization/localization.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunPresentationController = preload("res://src/presentation/run/run_presentation_controller.gd")
const RunPresentationState = preload("res://src/presentation/run/run_presentation_state.gd")
const TutorialProgress = preload("res://src/presentation/run/tutorial_progress.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_real_character_contract_map_and_battle_flow(failures)
	test_rejected_input_focus_details_and_modes(failures)
	test_phase_change_feedback_is_player_facing(failures)
	test_critical_battle_feedback_preserves_domain_event_order_in_all_modes(failures)
	test_actual_boss_cue_path_is_immediate_and_ordered_in_all_modes(failures)
	test_critical_screen_descriptors(failures)
	test_event_descriptors_filter_ineligible_choices_and_leave_saves(failures)
	test_onboarding_progress_is_independent_and_resettable(failures)
	test_same_seed_commands_match_across_modes_and_domain_is_presentation_free(failures)
	return failures

func test_real_character_contract_map_and_battle_flow(failures: Array[String]) -> void:
	var domain := _domain("presentation.flow", 91)
	var controller := RunPresentationController.new(domain)
	assert_true(controller.snapshot().screen == "run.character_select", "presentation starts at Character Select", failures)
	assert_true(controller.action_descriptors().size() == 2, "Character selection exposes stable content actions", failures)
	var character = controller.confirm("character:base.character.sequence")
	assert_true(character.accepted and domain.state.phase == RunPhase.CONTRACT_SELECT, "focused Character action delegates to RunDomain", failures)
	var contract = controller.confirm("contract:base.contract.pressure")
	assert_true(contract.accepted and domain.state.phase == RunPhase.MAP_CHOICE, "focused Contract action delegates to RunDomain", failures)
	var map_actions := controller.action_descriptors()
	assert_true(map_actions.size() == 1 and map_actions[0].get("kind") == "MAP_NODE" and map_actions[0].get("target_id") == domain.map_definition.start_node_id, "Map exposes only its mandatory introductory Normal before branching", failures)
	var battle = controller.confirm(map_actions[0]["id"])
	assert_true(battle.accepted and domain.state.phase == RunPhase.BATTLE, "Map action starts a real BattleDomain", failures)
	assert_true(controller.snapshot().authoritative_snapshot.has("run_state"), "presentation keeps a copied authoritative checkpoint", failures)
	assert_true(controller.snapshot().last_domain_event_types.has(DomainEvent.BATTLE_STARTED), "presentation consumes factual BattleStarted event", failures)

func test_rejected_input_focus_details_and_modes(failures: Array[String]) -> void:
	var domain := _domain("presentation.reject", 92)
	var controller := RunPresentationController.new(domain)
	var before := domain.checkpoint()
	var rejected = controller.confirm("character:missing")
	assert_true(not rejected.accepted, "unknown focused action is rejected by the real Domain", failures)
	assert_true(domain.checkpoint() == before, "rejected presentation input does not mutate Domain state", failures)
	assert_true(not controller.snapshot().feedback.is_empty(), "rejected input produces feedback", failures)
	var first_id: String = controller.snapshot().get("focused_action_id", "")
	controller.focus_next()
	assert_true(controller.snapshot().focused_action_id != first_id, "focus navigation uses stable action IDs", failures)
	var detail := controller.details()
	assert_true(detail.get("id", "") == controller.snapshot().details_action_id, "details opens for the focused action", failures)
	assert_true(controller.cancel() and controller.snapshot().details_action_id.is_empty(), "cancel closes presentation details without touching Domain", failures)
	assert_true(controller.set_mode(RunPresentationState.FAST) and controller.set_mode(RunPresentationState.INSTANT), "Normal/Fast/Instant modes are selectable", failures)

func test_phase_change_feedback_is_player_facing(failures: Array[String]) -> void:
	var controller := RunPresentationController.new(_domain("presentation.phase_feedback", 95))
	var feedback := controller._feedback_for_events([_event(DomainEvent.RUN_PHASE_CHANGED)])
	assert_true(feedback == "Run advanced.", "phase-change feedback uses player-facing copy instead of the internal event name", failures)

func test_critical_battle_feedback_preserves_domain_event_order_in_all_modes(failures: Array[String]) -> void:
	var controller := RunPresentationController.new(_domain("presentation.critical_feedback", 96))
	var events := [
		_event(DomainEvent.COMPLETE_HAND_SETTLED),
		DomainEvent.new(DomainEvent.BOSS_PHASE_CHANGED, {"phase_index": 1}),
		_event(DomainEvent.BATTLE_WON),
	]
	var expected_feedback := "%s %s %s" % [
		Localization.text("UI_RUN_CONTROLLER_0075"),
		Localization.template("UI_RUN_CONTROLLER_0076") % 2,
		Localization.text("UI_RUN_CONTROLLER_0077"),
	]
	for mode in RunPresentationState.MODES:
		assert_true(controller.set_mode(str(mode)), "critical feedback test selects %s mode" % str(mode), failures)
		var feedback := controller._feedback_for_events(events)
		assert_true(feedback == expected_feedback, "%s retains Complete Hand, Boss phase, and Victory cues in event order" % str(mode), failures)
		assert_true(not feedback.contains(DomainEvent.COMPLETE_HAND_SETTLED) and not feedback.contains(DomainEvent.BOSS_PHASE_CHANGED) and not feedback.contains(DomainEvent.BATTLE_WON), "%s cues are player-facing rather than internal event identifiers" % str(mode), failures)

func test_actual_boss_cue_path_is_immediate_and_ordered_in_all_modes(failures: Array[String]) -> void:
	for mode in RunPresentationState.MODES:
		var registry := ContentRegistry.new()
		assert_true(Phase2Catalog.register_all(registry).is_valid(), "%s registers the Stage 4 Phase 2 catalog" % str(mode), failures)
		assert_true(AlphaActTwoCatalog.register_all(registry).is_valid(), "%s registers the Stage 4 Act 2 catalog" % str(mode), failures)
		assert_true(AlphaScaleCatalog.register_all(registry).is_valid(), "%s registers the Stage 4 Scale catalog" % str(mode), failures)
		var domain = RunDomain.new_alpha_run("presentation.actual_boss_cues.%s" % str(mode).to_lower(), 9701, registry)
		assert_true(domain.execute(ChooseCharacterCommand.new("actual-cues.character", "base.character.sequence")).accepted, "%s accepts the production Character selection" % str(mode), failures)
		assert_true(domain.execute(ChooseContractCommand.new("actual-cues.contract", "base.contract.pressure")).accepted, "%s accepts the production Contract selection" % str(mode), failures)
		var battle = domain.encounter_factory.create(domain.state, AlphaScaleCatalog.ACT_ONE_BOSS_ENCOUNTER_ID, domain.rng_streams, "BOSS")
		assert_true(battle != null, "%s creates the authored Act 1 Boss through EncounterFactory" % str(mode), failures)
		if battle == null:
			continue
		domain.current_battle = battle
		domain.state.phase = RunPhase.BATTLE
		_prepare_complete_hand(battle, failures)
		battle.combat_state.enemy_hp = 1
		battle.combat_state.enemy_max_hp = maxi(1, battle.combat_state.enemy_max_hp)
		var controller := RunPresentationController.new(domain)
		assert_true(controller.set_mode(str(mode)), "%s mode is accepted for the actual Boss cue path" % str(mode), failures)
		var complete_actions: Array = controller.action_descriptors().filter(func(action): return action.get("kind", "") == "COMPLETE_HAND")
		assert_true(not complete_actions.is_empty(), "%s exposes a legal production Complete Hand action" % str(mode), failures)
		if complete_actions.is_empty():
			continue
		var before_checkpoint: Dictionary = domain.checkpoint()
		var complete_action: Dictionary = complete_actions[0]
		var complete_result = domain.execute(SettleCompleteHandCommand.new(
			"actual-cues.complete.%s" % str(mode).to_lower(),
			str(complete_action.get("target_id", "")),
		))
		assert_true(complete_result.accepted, "%s production Complete Hand returns synchronously accepted" % str(mode), failures)
		assert_true(complete_result.state_checkpoint == domain.checkpoint() and domain.checkpoint() != before_checkpoint, "%s authoritative state and result checkpoint are available before presentation feedback is rendered" % str(mode), failures)
		var actual_events: Array = complete_result.events.duplicate()
		controller._refresh(complete_result.events)
		var complete_feedback := str(controller.snapshot().get("feedback", ""))
		assert_true(complete_feedback.contains(Localization.text("UI_RUN_CONTROLLER_0075")), "%s displays the Complete Hand cue after the real settlement result" % str(mode), failures)
		var guard := 0
		while battle.combat_state.boss_phase_index < battle.combat_state.boss_phase_count - 1 and guard < battle.combat_state.boss_phase_count:
			guard += 1
			battle.combat_state.enemy_hp = 1
			var phase_result = battle.combat_resolver.resolve_player_action(battle.combat_state, 1)
			actual_events.append_array(phase_result.events)
			controller._refresh(phase_result.events)
			var phase_feedback := str(controller.snapshot().get("feedback", ""))
			assert_true(phase_result.terminal_outcome == "ONGOING" and phase_result.events.any(func(event): return event.event_type == DomainEvent.BOSS_PHASE_CHANGED), "%s real Boss resolution exposes the next phase event without waiting for presentation" % str(mode), failures)
			assert_true(phase_feedback.contains("The Boss enters phase "), "%s displays the localized Boss phase cue" % str(mode), failures)
			assert_true(domain.state.phase == RunPhase.BATTLE and domain.current_battle == battle, "%s keeps the authoritative Run in Battle while its phase cue is rendered" % str(mode), failures)
		battle.combat_state.enemy_hp = 1
		var victory_result = battle.combat_resolver.resolve_player_action(battle.combat_state, 1)
		actual_events.append_array(victory_result.events)
		assert_true(victory_result.terminal_outcome == "VICTORY" and victory_result.events.any(func(event): return event.event_type == DomainEvent.BATTLE_WON), "%s real Boss resolver returns Victory and BattleWon before any cue rendering" % str(mode), failures)
		controller._refresh(victory_result.events)
		var victory_feedback := str(controller.snapshot().get("feedback", ""))
		assert_true(victory_feedback == Localization.text("UI_RUN_CONTROLLER_0077"), "%s displays the localized Victory cue" % str(mode), failures)
		var critical_event_types: Array[String] = []
		for event in actual_events:
			if event != null and event.event_type in [DomainEvent.COMPLETE_HAND_SETTLED, DomainEvent.BOSS_PHASE_CHANGED, DomainEvent.BATTLE_WON]:
				critical_event_types.append(event.event_type)
		assert_true(
			critical_event_types.size() >= 3
			and critical_event_types.find(DomainEvent.COMPLETE_HAND_SETTLED) < critical_event_types.find(DomainEvent.BOSS_PHASE_CHANGED)
			and critical_event_types.find(DomainEvent.BOSS_PHASE_CHANGED) < critical_event_types.find(DomainEvent.BATTLE_WON),
			"%s actual Domain results preserve Complete Hand → Boss phase → BattleWon order" % str(mode),
			failures,
		)
		var scene_source := FileAccess.get_file_as_string("res://scenes/run/run_scene.gd")
		assert_true(scene_source.contains("_set_wrapped_label_text(_feedback_value, str(controller.snapshot().get(\"feedback\", \"\")))"), "%s RunScene renders presentation feedback as visible text" % str(mode), failures)

func _prepare_complete_hand(battle, failures: Array[String]) -> void:
	for tile in battle.zones.contents(TileZone.HAND).duplicate():
		assert_true(battle.zones.transfer(str(tile.instance_id), TileZone.HAND, TileZone.DISCARD), "the test fixture moves the previous Boss Hand out of play", failures)
	var definition_ids := [
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3",
		"base.tile.characters.4", "base.tile.characters.5", "base.tile.characters.6",
		"base.tile.characters.7", "base.tile.characters.7",
	]
	for index in definition_ids.size():
		var tile := TileInstance.new("actual-cues.hand.%02d" % index, str(definition_ids[index]))
		assert_true(battle.zones.add(tile, TileZone.HAND), "the test fixture installs Complete Hand tile %d" % index, failures)

func test_critical_screen_descriptors(failures: Array[String]) -> void:
	var domain := _domain("presentation.screens", 93)
	var controller := RunPresentationController.new(domain)
	for expected_kind in ["CHARACTER", "CONTRACT"]:
		var has_kind := false
		for action in controller.action_descriptors():
			if action.get("kind") == expected_kind:
				has_kind = true
		assert_true(has_kind, "%s screen has an action descriptor" % expected_kind, failures)
		domain.execute(ChooseCharacterCommand.new("screens.character", "base.character.sequence"))
		break
	for expected_kind in ["CONTRACT"]:
		var has_kind := false
		for action in controller.action_descriptors():
			if action.get("kind") == expected_kind:
				has_kind = true
		assert_true(has_kind, "%s screen has an action descriptor" % expected_kind, failures)
	controller._refresh([])
	domain.execute(ChooseContractCommand.new("screens.contract", "base.contract.pressure"))
	controller._refresh([])
	assert_true(controller.action_descriptors().any(func(action): return action.get("kind") == "MAP_NODE"), "Map screen has action descriptors", failures)
	for phase in [RunPhase.REWARD_CHOICE, RunPhase.ELITE_REWARD, RunPhase.BOSS_REWARD, RunPhase.SHOP, RunPhase.WORKSHOP, RunPhase.EVENT, RunPhase.RUN_SUMMARY]:
		domain.state.phase = phase
		controller._refresh([])
		assert_true(controller.action_descriptors() is Array, "%s screen exposes a descriptor collection" % phase, failures)

func test_event_descriptors_filter_ineligible_choices_and_leave_saves(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"event_id": "alpha.event.act_two.rule_memory", "choice_id": "study_yaku", "seed": 0},
		{"event_id": "alpha.event.act_two.rule_memory.cross_reference", "choice_id": "cross_reference", "seed": 18},
	]
	for case_index in cases.size():
		var event_case: Dictionary = cases[case_index]
		var setup: Dictionary = PublicActRouteFixture.two_act_rule_memory_domain(
			"presentation.event.eligibility.%d" % case_index,
			int(event_case["seed"]),
			str(event_case["event_id"]),
			failures,
		)
		assert_true(bool(setup.get("accepted", false)), "controller fixture traverses the authored two-Act Rule Memory route through public Commands", failures)
		if not bool(setup.get("accepted", false)):
			continue
		var domain: RunDomain = setup["domain"]
		var expected_act_one_path := [
			"base.map_node.intro",
			"base.map_node.normal.right",
			"base.map_node.event.right",
			"base.map_node.normal.mid",
			"base.map_node.elite",
			"base.map_node.boss",
		]
		var expected_act_two_path := [
			"base.map_node.act_two.intro",
			"base.map_node.act_two.normal.right",
			"base.map_node.act_two.event.right",
		]
		assert_true(setup.get("act_one_path", []) == expected_act_one_path, "controller fixture's actual Act 1 ordered_path reaches the Boss", failures)
		assert_true(str(setup.get("act_one_boss_reward_command_type", "")) == "ChooseReward" and bool(setup.get("act_one_boss_transition_emitted", false)), "Act 1 Boss reward uses ChooseRewardCommand and emits the natural Act transition", failures)
		assert_true(setup.get("act_two_path", []) == expected_act_two_path, "controller fixture's actual Act 2 ordered_path reaches the Rule Memory Event", failures)
		var suspend_path := "user://presentation_event_leave_suspend_%d.json" % Time.get_ticks_usec()
		var store := SuspendSaveStore.new(suspend_path)
		var controller := RunPresentationController.new(domain, null, null, store)
		var before := domain.checkpoint()
		var rng_before := domain.rng_snapshot()
		var replay_count: int = domain.replay_record.commands.size()
		var descriptors := controller.action_descriptors()
		var action_ids: Array = descriptors.map(func(action): return str(action.get("id", "")))
		var advertised_choice_ids: Array = descriptors.filter(func(action): return action.get("kind", "") == "EVENT_OPTION").map(func(action): return str(action.get("target_id", "")))
		assert_true(not action_ids.has("event:study_yaku") and not action_ids.has("event:cross_reference"), "the controller hides both unavailable Act 2 Rule Memory choices", failures)
		assert_true(not advertised_choice_ids.has(str(event_case["choice_id"])), "%s is not advertised by the Act 2 Event controller" % str(event_case["choice_id"]), failures)
		assert_true(advertised_choice_ids == ["leave"], "Leave is the only advertised choice for the active Rule Memory Event", failures)
		assert_true(action_ids.has("event:leave"), "the Act 2 Event controller continues to advertise Leave", failures)
		assert_true(domain.checkpoint() == before and domain.rng_snapshot() == rng_before, "building Event descriptors does not change Run state or RNG", failures)
		assert_true(domain.replay_record.commands.size() == replay_count, "building Event descriptors does not append an accepted Replay command", failures)
		var untouched_source := store.read_source()
		assert_true(untouched_source.accepted and not untouched_source.exists, "Event eligibility preview does not write a suspend checkpoint", failures)

		var leave = controller.confirm("event:leave")
		assert_true(leave.accepted and domain.state.phase == RunPhase.MAP_CHOICE, "the advertised Leave choice returns to Map Choice", failures)
		var saved_source := store.read_source()
		assert_true(saved_source.accepted and saved_source.exists, "accepted Leave writes a suspend snapshot from Event back to the Map", failures)
		if saved_source.accepted and saved_source.exists:
			var loaded := SaveMapper.load_into_domain(str(saved_source.get("contents", "")), domain.content_registry)
			assert_true(loaded.get("accepted", false), "the immediately reloaded Event-exit suspend snapshot is valid", failures)
			if loaded.get("accepted", false):
				assert_true(loaded.domain.checkpoint() == domain.checkpoint(), "the Event-exit snapshot reload exactly matches the live Run checkpoint", failures)
		var cleared := store.clear()
		assert_true(cleared.accepted, "the isolated Event-exit suspend fixture is cleaned up", failures)

func test_onboarding_progress_is_independent_and_resettable(failures: Array[String]) -> void:
	var progress := TutorialProgress.new()
	progress.observe([_event(DomainEvent.TILE_DRAWN)])
	progress.observe([_event(DomainEvent.TP_CHANGED)])
	assert_true(progress.completed_step_ids == [TutorialProgress.DRAW_PATTERN_PARTIAL, TutorialProgress.TP_CORE_TECHNIQUE], "onboarding progresses in the ordered real-event sequence", failures)
	var persisted := progress.to_dictionary()
	assert_true(not persisted.has("assist_level") and not persisted.has("run_state"), "onboarding persistence is separate from Assist Level and RunState", failures)
	var restored = TutorialProgress.from_dictionary(persisted)
	assert_true(restored.to_dictionary() == persisted, "onboarding progress round-trips independently", failures)
	progress.disable()
	progress.observe([_event(DomainEvent.RESERVE_STORED)])
	assert_true(progress.completed_step_ids.size() == 2 and not progress.enabled, "disabled onboarding stops progression", failures)
	progress.reset()
	assert_true(progress.enabled and progress.current_step_id == TutorialProgress.DRAW_PATTERN_PARTIAL and progress.completed_step_ids.is_empty(), "reset restores first-run onboarding", failures)

func test_same_seed_commands_match_across_modes_and_domain_is_presentation_free(failures: Array[String]) -> void:
	var controllers: Array = []
	for mode in RunPresentationState.MODES:
		var controller := RunPresentationController.new(_domain("presentation.determinism", 94))
		controller.set_mode(str(mode))
		controllers.append(controller)
	for action_id in ["character:base.character.sequence", "contract:base.contract.pressure"]:
		for controller in controllers:
			var result = controller.confirm(action_id)
			assert_true(result.accepted, "%s accepts the same authoritative action" % str(controller.snapshot().get("presentation_mode", "")), failures)
	for index in range(1, controllers.size()):
		assert_true(controllers[0].domain.checkpoint() == controllers[index].domain.checkpoint(), "%s mode preserves identical Domain outcomes" % str(controllers[index].snapshot().get("presentation_mode", "")), failures)
		assert_true(controllers[0].domain.rng_snapshot() == controllers[index].domain.rng_snapshot(), "%s mode preserves identical Domain RNG" % str(controllers[index].snapshot().get("presentation_mode", "")), failures)
	var domain_source := FileAccess.get_file_as_string("res://src/domain/run/run_domain.gd")
	assert_true(not domain_source.contains("src/presentation/") and not domain_source.contains("presentation/"), "RunDomain has no presentation dependency", failures)
	var battle_source := FileAccess.get_file_as_string("res://src/domain/battle/battle_domain.gd")
	assert_true(not battle_source.contains("src/presentation/") and not battle_source.contains("presentation/"), "BattleDomain has no presentation dependency", failures)

func _domain(run_id: String, seed: int) -> RunDomain:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	return RunDomain.new(run_id, seed, registry)

func _event(event_type: String):
	return DomainEvent.new(event_type)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
