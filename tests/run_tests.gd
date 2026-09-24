extends SceneTree

const SmokeTest = preload("res://tests/domain_smoke_test.gd")
const ContentRegistryTest = preload("res://tests/content_registry_test.gd")
const RngStreamTest = preload("res://tests/rng_stream_test.gd")
const TileZoneTest = preload("res://tests/tile_zone_test.gd")
const DrawActionTest = preload("res://tests/draw_action_test.gd")
const PatternEvaluatorTest = preload("res://tests/pattern_evaluator_test.gd")
const CompleteHandEvaluatorTest = preload("res://tests/complete_hand_evaluator_test.gd")
const SettlementTest = preload("res://tests/settlement_test.gd")
const MahjongScoreResolverTest = preload("res://tests/mahjong_score_resolver_test.gd")
const CombatConversionTest = preload("res://tests/combat_conversion_test.gd")
const SettlementTurnTest = preload("res://tests/settlement_turn_test.gd")
const CombatStateTest = preload("res://tests/combat_state_test.gd")
const Stage0ExitReviewTest = preload("res://tests/stage0_exit_review_test.gd")
const DomainCommandTest = preload("res://tests/domain_command_test.gd")
const ResolutionQueueTest = preload("res://tests/resolution_queue_test.gd")
const EffectFrameworkTest = preload("res://tests/effect_framework_test.gd")
const EffectLifecycleTest = preload("res://tests/effect_lifecycle_test.gd")
const ReserveIntegrityTest = preload("res://tests/reserve_integrity_test.gd")
const CompleteHandSettlementTest = preload("res://tests/complete_hand_settlement_test.gd")
const YakuProgressTest = preload("res://tests/yaku_progress_test.gd")
const DrawResolverTest = preload("res://tests/draw_resolver_test.gd")
const IntentGraphTest = preload("res://tests/intent_graph_test.gd")
const ReplayTest = preload("res://tests/replay_test.gd")
const Phase2FoundationsTest = preload("res://tests/phase_2_foundations_test.gd")
const RunDomainTest = preload("res://tests/run_domain_test.gd")
const MapNavigationTest = preload("res://tests/map_navigation_test.gd")
const BattleIntegrationTest = preload("res://tests/battle_integration_test.gd")
const BossRuleBreakerRewardTest = preload("res://tests/boss_rule_breaker_reward_test.gd")
const EliteRewardTest = preload("res://tests/elite_reward_test.gd")
const RewardEconomyTest = preload("res://tests/reward_economy_test.gd")
const ShopWorkshopTest = preload("res://tests/shop_workshop_test.gd")
const EventsTest = preload("res://tests/events_test.gd")
const ContaminationTest = preload("res://tests/contamination_test.gd")
const ContentCatalogTest = preload("res://tests/content_catalog_test.gd")
const PersistenceTest = preload("res://tests/persistence_test.gd")
const Stage2ExitReviewTest = preload("res://tests/stage2_exit_review_test.gd")
const AlphaSimulationTest = preload("res://tests/alpha_simulation_test.gd")
const AlphaSimulationCoverageTest = preload("res://tests/alpha_simulation_coverage_test.gd")
const AlphaFixedRunBenchmarkTest = preload("res://tests/alpha_fixed_run_benchmark_test.gd")

func _init() -> void:
	var content_registry_only := "--content-registry" in OS.get_cmdline_args()
	var rng_only := "--rng" in OS.get_cmdline_args()
	var tile_zones_only := "--tile-zones" in OS.get_cmdline_args()
	var draw_actions_only := "--draw-actions" in OS.get_cmdline_args()
	var patterns_only := "--patterns" in OS.get_cmdline_args()
	var complete_hands_only := "--complete-hands" in OS.get_cmdline_args()
	var settlements_only := "--settlements" in OS.get_cmdline_args()
	var scores_only := "--scores" in OS.get_cmdline_args()
	var combat_conversion_only := "--combat-conversion" in OS.get_cmdline_args()
	var settlement_turn_only := "--settlement-turn" in OS.get_cmdline_args()
	var combat_state_only := "--combat-state" in OS.get_cmdline_args()
	var battle_scene_only := "--battle-scene" in OS.get_cmdline_args()
	var stage0_exit_review_only := "--stage0-exit-review" in OS.get_cmdline_args()
	var domain_commands_only := "--domain-commands" in OS.get_cmdline_args()
	var resolution_queue_only := "--resolution-queue" in OS.get_cmdline_args()
	var effects_only := "--effects" in OS.get_cmdline_args()
	var lifecycle_only := "--effect-lifecycle" in OS.get_cmdline_args()
	var reserve_integrity_only := "--reserve-integrity" in OS.get_cmdline_args()
	var complete_hand_settlement_only := "--complete-hand-settlement" in OS.get_cmdline_args()
	var yaku_progress_only := "--yaku-progress" in OS.get_cmdline_args()
	var draw_resolver_only := "--draw-resolver" in OS.get_cmdline_args()
	var intent_graph_only := "--intent-graph" in OS.get_cmdline_args()
	var replay_only := "--replay" in OS.get_cmdline_args()
	var run_replay_only := "--run-replay" in OS.get_cmdline_args() or "--replay-run" in OS.get_cmdline_args()
	var phase_2_foundations_only := "--phase-2-foundations" in OS.get_cmdline_args() or "--foundations" in OS.get_cmdline_args()
	var run_domain_only := "--run-domain" in OS.get_cmdline_args()
	var map_only := "--map" in OS.get_cmdline_args()
	var battle_integration_only := "--battle-integration" in OS.get_cmdline_args()
	var boss_rule_breaker_reward_only := "--boss-rule-breaker-reward" in OS.get_cmdline_args()
	var elite_reward_only := "--elite-reward" in OS.get_cmdline_args()
	var reward_economy_only := "--reward-economy" in OS.get_cmdline_args()
	var shop_workshop_only := "--shop-workshop" in OS.get_cmdline_args()
	var events_only := "--events" in OS.get_cmdline_args()
	var contamination_only := "--contamination" in OS.get_cmdline_args()
	var content_catalog_only := "--content-catalog" in OS.get_cmdline_args() or "--catalog" in OS.get_cmdline_args()
	var persistence_only := "--persistence" in OS.get_cmdline_args()
	var presentation_only := "--presentation" in OS.get_cmdline_args()
	var onboarding_only := "--onboarding" in OS.get_cmdline_args()
	var stage2_exit_review_only := "--stage2-exit-review" in OS.get_cmdline_args()
	var alpha_simulation_only := "--alpha-simulation" in OS.get_cmdline_args()
	var alpha_fixed_benchmark_only := "--alpha-fixed-run-benchmark" in OS.get_cmdline_args()
	var focused_test_requested := (
		content_registry_only or rng_only or tile_zones_only or draw_actions_only or patterns_only
		or complete_hands_only or settlements_only or scores_only or combat_conversion_only
		or settlement_turn_only or combat_state_only or battle_scene_only or stage0_exit_review_only
		or domain_commands_only or resolution_queue_only or effects_only or lifecycle_only or reserve_integrity_only or complete_hand_settlement_only or yaku_progress_only or draw_resolver_only or intent_graph_only or replay_only or run_replay_only or phase_2_foundations_only or run_domain_only or map_only or battle_integration_only or boss_rule_breaker_reward_only or elite_reward_only or reward_economy_only or shop_workshop_only or events_only or contamination_only or content_catalog_only or persistence_only or presentation_only or onboarding_only or stage2_exit_review_only or alpha_simulation_only or alpha_fixed_benchmark_only
	)
	var failures: Array[String] = []
	if not focused_test_requested:
		failures.append_array(SmokeTest.new().run())
	if not focused_test_requested or content_registry_only:
		failures.append_array(ContentRegistryTest.new().run())
	if not focused_test_requested or rng_only:
		failures.append_array(RngStreamTest.new().run())
	if not focused_test_requested or tile_zones_only:
		failures.append_array(TileZoneTest.new().run())
	if not focused_test_requested or draw_actions_only:
		failures.append_array(DrawActionTest.new().run())
	if not focused_test_requested or patterns_only:
		failures.append_array(PatternEvaluatorTest.new().run())
	if not focused_test_requested or complete_hands_only:
		failures.append_array(CompleteHandEvaluatorTest.new().run())
	if not focused_test_requested or settlements_only:
		failures.append_array(SettlementTest.new().run())
	if not focused_test_requested or scores_only:
		failures.append_array(MahjongScoreResolverTest.new().run())
	if not focused_test_requested or combat_conversion_only:
		failures.append_array(CombatConversionTest.new().run())
	if not focused_test_requested or settlement_turn_only:
		failures.append_array(SettlementTurnTest.new().run())
	if not focused_test_requested or combat_state_only:
		failures.append_array(CombatStateTest.new().run())
	if not focused_test_requested or battle_scene_only:
		failures.append_array(_run_test("res://tests/battle_scene_test.gd"))
	if not focused_test_requested or stage0_exit_review_only:
		failures.append_array(Stage0ExitReviewTest.new().run())
	if not focused_test_requested or domain_commands_only:
		failures.append_array(DomainCommandTest.new().run())
	if not focused_test_requested or resolution_queue_only:
		failures.append_array(ResolutionQueueTest.new().run())
	if not focused_test_requested or effects_only:
		failures.append_array(EffectFrameworkTest.new().run())
	if not focused_test_requested or lifecycle_only:
		failures.append_array(EffectLifecycleTest.new().run())
	if not focused_test_requested or reserve_integrity_only:
		failures.append_array(ReserveIntegrityTest.new().run())
	if not focused_test_requested or complete_hand_settlement_only:
		failures.append_array(CompleteHandSettlementTest.new().run())
	if not focused_test_requested or yaku_progress_only:
		failures.append_array(YakuProgressTest.new().run())
	if not focused_test_requested or draw_resolver_only:
		failures.append_array(DrawResolverTest.new().run())
	if not focused_test_requested or intent_graph_only:
		failures.append_array(IntentGraphTest.new().run())
	if not focused_test_requested or replay_only:
		failures.append_array(ReplayTest.new().run())
	if run_replay_only:
		failures.append_array(ReplayTest.new().run_run_replay())
	if not focused_test_requested or phase_2_foundations_only:
		failures.append_array(Phase2FoundationsTest.new().run())
	if not focused_test_requested or run_domain_only:
		failures.append_array(RunDomainTest.new().run())
	if not focused_test_requested or map_only:
		failures.append_array(MapNavigationTest.new().run())
	if not focused_test_requested or battle_integration_only:
		failures.append_array(BattleIntegrationTest.new().run())
	if not focused_test_requested or boss_rule_breaker_reward_only:
		failures.append_array(BossRuleBreakerRewardTest.new().run())
	if not focused_test_requested or elite_reward_only:
		failures.append_array(EliteRewardTest.new().run())
	if not focused_test_requested or reward_economy_only:
		failures.append_array(RewardEconomyTest.new().run())
	if not focused_test_requested or shop_workshop_only:
		failures.append_array(ShopWorkshopTest.new().run())
	if not focused_test_requested or events_only:
		failures.append_array(EventsTest.new().run())
	if not focused_test_requested or contamination_only:
		failures.append_array(ContaminationTest.new().run())
	if not focused_test_requested or content_catalog_only:
		failures.append_array(ContentCatalogTest.new().run())
	if not focused_test_requested or persistence_only:
		failures.append_array(PersistenceTest.new().run())
	if stage2_exit_review_only:
		failures.append_array(Stage2ExitReviewTest.new().run())
	if alpha_simulation_only:
		failures.append_array(AlphaSimulationTest.new().run())
		failures.append_array(AlphaSimulationCoverageTest.new().run())
	if alpha_fixed_benchmark_only or not focused_test_requested:
		failures.append_array(AlphaFixedRunBenchmarkTest.new().run())
	if not focused_test_requested or presentation_only or onboarding_only:
		var presentation_test_script = load("res://tests/run_presentation_test.gd")
		if presentation_test_script == null or not presentation_test_script.can_instantiate():
			failures.append("PRESENTATION TEST LOAD FAILED")
		else:
			failures.append_array(presentation_test_script.new().run())
	if "--fail" in OS.get_cmdline_args():
		failures.append("ASSERTION FAILED: forced failure probe")
		push_error("ASSERTION FAILED: forced failure probe")

	if failures.is_empty():
		if content_registry_only:
			print("PASS: content registry tests")
		elif rng_only:
			print("PASS: RNG stream tests")
		elif tile_zones_only:
			print("PASS: tile zone tests")
		elif draw_actions_only:
			print("PASS: draw action tests")
		elif patterns_only:
			print("PASS: pattern evaluator tests")
		elif complete_hands_only:
			print("PASS: complete hand evaluator tests")
		elif settlements_only:
			print("PASS: settlement tests")
		elif scores_only:
			print("PASS: Mahjong score resolver tests")
		elif combat_conversion_only:
			print("PASS: combat conversion tests")
		elif settlement_turn_only:
			print("PASS: settlement turn tests")
		elif combat_state_only:
			print("PASS: combat state tests")
		elif battle_scene_only:
			print("PASS: battle scene tests")
		elif stage0_exit_review_only:
			print("PASS: Stage 0 exit review evidence")
		elif domain_commands_only:
			print("PASS: domain command tests")
		elif resolution_queue_only:
			print("PASS: resolution queue tests")
		elif effects_only:
			print("PASS: Effect framework tests")
		elif lifecycle_only:
			print("PASS: Effect lifecycle tests")
		elif reserve_integrity_only:
			print("PASS: Reserve and Integrity tests")
		elif complete_hand_settlement_only:
			print("PASS: Complete Hand settlement and Recovery tests")
		elif yaku_progress_only:
			print("PASS: Yaku Progress tests")
		elif draw_resolver_only:
			print("PASS: Draw Resolver tests")
		elif intent_graph_only:
			print("PASS: Intent Graph tests")
		elif replay_only:
			print("PASS: replay tests")
		elif run_replay_only:
			print("PASS: RunDomain replay tests")
		elif phase_2_foundations_only:
			print("PASS: Phase 2 foundations tests")
		elif run_domain_only:
			print("PASS: Run domain tests")
		elif map_only:
			print("PASS: map navigation tests")
		elif battle_integration_only:
			print("PASS: battle integration tests")
		elif elite_reward_only:
			print("PASS: Elite reward tests")
		elif reward_economy_only:
			print("PASS: reward and economy tests")
		elif shop_workshop_only:
			print("PASS: shop and workshop tests")
		elif events_only:
			print("PASS: Event tests")
		elif contamination_only:
			print("PASS: Contamination tests")
		elif content_catalog_only:
			print("PASS: lower-bound content catalog tests")
		elif persistence_only:
			print("PASS: persistence tests")
		elif presentation_only:
			print("PASS: run presentation tests")
		elif onboarding_only:
			print("PASS: onboarding tests")
		elif stage2_exit_review_only:
			print("PASS: Stage 2 exit review evidence")
		elif alpha_simulation_only:
			print("PASS: deterministic Alpha simulation harness tests")
		elif alpha_fixed_benchmark_only:
			print("PASS: fixed Alpha complete-Run benchmark tests")
		else:
			print("PASS: full domain, presentation, and Intent Graph test suite")
		quit(0)
		return

	for failure in failures:
		print("FAIL: " + failure)
	quit(1)

func _run_test(script_path: String) -> Array[String]:
	var test_script = load(script_path)
	return test_script.new().run()
