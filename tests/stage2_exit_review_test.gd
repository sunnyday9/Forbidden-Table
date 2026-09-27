class_name Stage2ExitReviewTest
extends RefCounted

const BattleIntegrationTest = preload("res://tests/battle_integration_test.gd")
const BossRuleBreakerRewardTest = preload("res://tests/boss_rule_breaker_reward_test.gd")
const EliteRewardTest = preload("res://tests/elite_reward_test.gd")
const ContentCatalogTest = preload("res://tests/content_catalog_test.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const CompleteHandSettlementTest = preload("res://tests/complete_hand_settlement_test.gd")
const DrawCommand = preload("res://src/domain/commands/draw_command.gd")
const MapNavigationTest = preload("res://tests/map_navigation_test.gd")
const MiniActMapCatalog = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunPresentationController = preload("res://src/presentation/run/run_presentation_controller.gd")
const RunPresentationTest = preload("res://tests/run_presentation_test.gd")
const Stage0ExitReviewTest = preload("res://tests/stage0_exit_review_test.gd")
const RewardEconomyTest = preload("res://tests/reward_economy_test.gd")
const SettleCompleteHandCommand = preload("res://src/domain/commands/settle_complete_hand_command.gd")
const SettlePatternCommand = preload("res://src/domain/commands/settle_pattern_command.gd")
const ShopWorkshopTest = preload("res://tests/shop_workshop_test.gd")
const PersistenceTest = preload("res://tests/persistence_test.gd")
const ReplayTest = preload("res://tests/replay_test.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_bounded_controller_entry_evidence(failures)
	_record_evidence("onboarding, focus, and main-loop controller", RunPresentationTest.new().run(), failures)
	_record_evidence("Partial and Complete strategy loop", Stage0ExitReviewTest.new().run(), failures)
	_record_evidence("Complete Hand settlement and Recovery", CompleteHandSettlementTest.new().run(), failures)
	var hybrid_failures: Array[String] = []
	test_complete_hand_recovery_allows_hybrid_partial_settlement(hybrid_failures)
	_record_evidence("Complete Hand Recovery permits Hybrid Partial Settlement", hybrid_failures, failures)
	_record_evidence("Characters, Contracts, Boss phases, and No-Core-Code content", ContentCatalogTest.new().run(), failures)
	_record_evidence("bounded map choices and Boss reachability", MapNavigationTest.new().run(), failures)
	_record_evidence("rewards and Elite progression", RewardEconomyTest.new().run(), failures)
	_record_evidence("Shop and Workshop Gold decisions", ShopWorkshopTest.new().run(), failures)
	_record_evidence("data-driven battle and Boss progression", BattleIntegrationTest.new().run(), failures)
	_record_evidence("three-choice Boss Rule Breaker reward, application, Suspend/Resume, and Replay", BossRuleBreakerRewardTest.new().run(), failures)
	_record_evidence("Elite Relic/Run Technique reward, Skip compensation, Suspend/Resume, and Replay", EliteRewardTest.new().run(), failures)
	_record_evidence("Suspend/Resume checkpoint evidence", PersistenceTest.new().run(), failures)
	_record_evidence("run Replay no-divergence evidence", ReplayTest.new().run_run_replay(), failures)
	return failures

func test_bounded_controller_entry_evidence(failures: Array[String]) -> void:
	var map_definition = MiniActMapCatalog.definition()
	assert_true(map_definition.graph_issues().is_empty(), "the exit review uses a valid authored map", failures)
	assert_true(map_definition.node_ids.size() == 10, "the exit review remains bounded to the authored Mini-Act", failures)

	var registry := ContentRegistry.new()
	assert_true(Phase2Catalog.register_all(registry).is_valid(), "the exit review uses the validated Phase 2 catalog", failures)
	var domain := RunDomain.new("stage2.exit.review", 2039, registry)
	var controller := RunPresentationController.new(domain)
	assert_true(controller.action_descriptors().size() == Phase2Catalog.CHARACTER_IDS.size(), "Character focus exposes every catalog Character", failures)
	var character_result = controller.confirm("character:%s" % Phase2Catalog.CHARACTER_IDS[0])
	assert_true(character_result.accepted, "the real controller accepts Character selection", failures)
	var contract_result = controller.confirm("contract:%s" % Phase2Catalog.CONTRACT_IDS[0])
	assert_true(contract_result.accepted and domain.state.phase == RunPhase.MAP_CHOICE, "the real controller independently reaches Map Choice", failures)
	var intro_id: String = domain.map_definition.start_node_id
	var intro = domain.map_definition.node_definition(intro_id)
	var intro_actions: Array = controller.action_descriptors().filter(func(action): return action.get("kind") == "MAP_NODE")
	assert_true(intro_actions.size() == 1 and intro_actions[0].get("target_id", "") == intro_id, "Map Choice exposes only the mandatory introductory Normal", failures)
	var map_result = controller.confirm(str(intro_actions[0].get("id", ""))) if not intro_actions.is_empty() else null
	assert_true(map_result != null and map_result.accepted and domain.state.phase == RunPhase.BATTLE, "a focused entry action starts the real main-loop battle", failures)
	assert_true(domain.replay_record.commands.size() == 3, "the bounded controller smoke records only accepted entry commands", failures)
	if domain.current_battle == null:
		return
	domain.current_battle.combat_state.enemy_hp = 1
	var victory = domain.current_battle.combat_resolver.resolve_player_action(domain.current_battle.combat_state, 17)
	assert_true(victory.terminal_outcome == "VICTORY", "the bounded intro encounter is resolved as a real Battle", failures)
	var outcome_events: Array = domain.apply_battle_outcome()
	controller._refresh(outcome_events)
	var reward_actions: Array = controller.action_descriptors().filter(func(action): return action.get("kind") == "REWARD")
	assert_true(not reward_actions.is_empty(), "the mandatory Normal exposes its usual Reward Choice", failures)
	if reward_actions.is_empty():
		return
	var reward_result = controller.confirm(str(reward_actions[0].get("id", "")))
	assert_true(reward_result.accepted and domain.state.phase == RunPhase.MAP_CHOICE, "accepting the intro reward returns to Map Choice", failures)
	var branch_actions: Array = controller.action_descriptors().filter(func(action): return action.get("kind") == "MAP_NODE")
	assert_true(branch_actions.size() == 2 and branch_actions.all(func(action): return intro.next_node_ids.has(str(action.get("target_id", "")))), "Map Choice exposes the authored branch nodes after the intro victory and reward", failures)
	assert_true(domain.replay_record.commands.size() == 4, "the intro reward choice remains in accepted-command replay", failures)

func test_complete_hand_recovery_allows_hybrid_partial_settlement(failures: Array[String]) -> void:
	var fixture := CompleteHandSettlementTest.new()._fixture(6, 5, 3, TileZone.DISCARD)
	var domain = fixture["domain"]
	var interpretation = fixture["evaluator"].evaluate(fixture["zones"].contents(TileZone.HAND))[0]
	var complete = domain.execute(SettleCompleteHandCommand.new("stage2.hybrid.complete", interpretation.interpretation_id))
	assert_true(complete.accepted, "the seeded Hybrid fixture completes a Complete Hand", failures)
	assert_true(domain.is_recovering(), "the Complete Hand enters active Recovery", failures)
	assert_true(fixture["zones"].size(TileZone.HAND) == 3, "Recovery starts at the fixture's Recovery Baseline", failures)

	var draw = domain.execute(DrawCommand.new("stage2.hybrid.recovery.draw"))
	assert_true(draw.accepted, "normal Draw remains legal during Recovery", failures)
	assert_true(domain.is_recovering(), "Recovery remains active after the normal Draw", failures)
	assert_true(domain.can_settle(), "the recovered hand exposes a legal Partial Settlement", failures)
	var candidates: Array = domain.settlement_window.candidates()
	assert_true(not candidates.is_empty(), "the seeded recovered hand has a Partial Settlement candidate", failures)
	if candidates.is_empty():
		return

	var candidate = candidates[0]
	var partial = domain.execute(SettlePatternCommand.new(
		"stage2.hybrid.partial",
		[],
		"",
		"",
		false,
		candidate.candidate_id,
	))
	assert_true(partial.accepted, "Partial Settlement succeeds during Complete Hand Recovery", failures)
	assert_true(partial.replayable, "the Hybrid Partial Settlement is an accepted replayable Command", failures)
	assert_true(partial.data.get("settlement", {}).get("settled_instance_ids", []).size() == candidate.tile_instances.size(), "Hybrid settlement records the selected Pattern", failures)
	assert_true(partial.data.get("combat_output", {}).get("damage", -1) >= 0, "Hybrid Partial Settlement reaches combat conversion", failures)
	assert_true(domain.is_recovering(), "a legal Hybrid Partial Settlement does not end Recovery implicitly", failures)

func _record_evidence(label: String, group_failures: Array[String], failures: Array[String]) -> void:
	if group_failures.is_empty():
		print("EVIDENCE PASS: %s" % label)
	else:
		failures.append_array(group_failures)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
