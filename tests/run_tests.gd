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
const BattleSceneTest = preload("res://tests/battle_scene_test.gd")
const Stage0ExitReviewTest = preload("res://tests/stage0_exit_review_test.gd")
const DomainCommandTest = preload("res://tests/domain_command_test.gd")
const ResolutionQueueTest = preload("res://tests/resolution_queue_test.gd")
const EffectFrameworkTest = preload("res://tests/effect_framework_test.gd")
const EffectLifecycleTest = preload("res://tests/effect_lifecycle_test.gd")

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
	var focused_test_requested := (
		content_registry_only or rng_only or tile_zones_only or draw_actions_only or patterns_only
		or complete_hands_only or settlements_only or scores_only or combat_conversion_only
		or settlement_turn_only or combat_state_only or battle_scene_only or stage0_exit_review_only
		or domain_commands_only or resolution_queue_only or effects_only or lifecycle_only
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
		failures.append_array(BattleSceneTest.new().run())
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
		else:
			print("PASS: domain smoke scenario, content registry, RNG stream, tile zone, draw action, pattern evaluator, complete hand evaluator, settlement, Mahjong score resolver, CombatConversion, settlement turn, combat state, battle scene, and Stage 0 exit review tests")
		quit(0)
		return

	for failure in failures:
		print("FAIL: " + failure)
	quit(1)
