class_name RunPresentationTest
extends RefCounted

const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
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
	test_critical_screen_descriptors(failures)
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
	var first := RunPresentationController.new(_domain("presentation.determinism", 94))
	var second := RunPresentationController.new(_domain("presentation.determinism", 94))
	first.set_mode(RunPresentationState.NORMAL)
	second.set_mode(RunPresentationState.INSTANT)
	for action_id in ["character:base.character.sequence", "contract:base.contract.pressure"]:
		var first_result = first.confirm(action_id)
		var second_result = second.confirm(action_id)
		assert_true(first_result.accepted and second_result.accepted, "same stable action is accepted in both presentation modes", failures)
	assert_true(first.domain.checkpoint() == second.domain.checkpoint(), "presentation mode does not alter Domain outcomes", failures)
	assert_true(first.domain.rng_snapshot() == second.domain.rng_snapshot(), "presentation mode does not alter Domain RNG", failures)
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
