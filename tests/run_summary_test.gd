class_name RunSummaryTest
extends RefCounted

const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunStateScript = preload("res://src/domain/run/run_state.gd")
const RunSummaryPresenterScript = preload("res://src/presentation/run/run_summary_presenter.gd")
const YakuDefinitionScript = preload("res://src/content/definitions/yaku_definition.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_build_story_contains_tracked_run_data(failures)
	test_complete_yaku_score_hooks_are_counted_by_yaku(failures)
	test_settlement_events_are_tracked_without_score_data(failures)
	test_legacy_summary_does_not_invent_untracked_metrics(failures)
	return failures

func test_complete_yaku_score_hooks_are_counted_by_yaku(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	AlphaActTwoCatalogScript.register_all(registry)
	AlphaScaleCatalogScript.register_all(registry)
	var complete_yaku = null
	for definition in registry.enumerate():
		if definition is YakuDefinitionScript and str(definition.complete_score.get("source_id", "")).ends_with(".complete"):
			complete_yaku = definition
			break
	assert_true(complete_yaku != null, "the content registry has a Complete Hand Yaku with a distinct score source ID", failures)
	if complete_yaku == null:
		return
	var domain = RunDomainScript.new_alpha_run("summary.complete-yaku", 5503, registry, "", null, null, MetaProgressStateScript.all_unlocked_test_profile())
	var complete_source_id := str(complete_yaku.complete_score.get("source_id", ""))
	domain._record_run_summary_metrics({"score": {"total": 42, "contributions": [{"source_id": complete_source_id}]}}, [])
	assert_true(domain.state.yaku_counts.get(complete_yaku.content_id, 0) == 1, "Complete Hand score hooks are attributed to their registered Yaku in Run Summary", failures)

func test_build_story_contains_tracked_run_data(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	AlphaActTwoCatalogScript.register_all(registry)
	AlphaScaleCatalogScript.register_all(registry)
	var domain = RunDomainScript.new_alpha_run("summary.build-story", 5501, registry, "", null, null, MetaProgressStateScript.all_unlocked_test_profile())
	domain.execute(ChooseCharacterCommandScript.new("summary.character", Phase2CatalogScript.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommandScript.new("summary.contract", Phase2CatalogScript.CONTRACT_IDS[0]))
	var tracked_yaku_id: String = Phase2CatalogScript.PRODUCTION_YAKU_IDS[0]
	domain._record_run_summary_metrics({"score": {"total": 72, "contributions": [{"source_id": tracked_yaku_id}]}}, [])
	assert_true(domain.state.yaku_counts.get(tracked_yaku_id, 0) == 1, "the Run counts only registered Yaku score contributions", failures)
	domain.state.act_index = 2
	domain.state.boss_progress.append({"act_index": 1, "encounter_id": "alpha.encounter.act_one_boss"})
	domain.state.pattern_counts = {"SEQUENCE": 3, "TRIPLET": 1}
	domain.state.complete_hand_count = 2
	domain.state.maximum_mahjong_score = 180
	domain.state.milestones.append_array(["first_complete_hand", "act_2_reached"])
	domain.state.build_ownership.run_technique_ids.append(Phase2CatalogScript.RUN_TECHNIQUE_IDS[0])
	domain.state.build_ownership.acquired_rule_breaker_ids.append(Phase2CatalogScript.BOSS_RULE_BREAKER_IDS[0])
	domain.state.run_started_at_unix_seconds = 4000
	domain.enter_run_summary("VICTORY", "BOSS_DEFEATED", {"seed": 9999, "core_yaku": {"fake.yaku": 900}, "elapsed": 1000})
	var summary: Dictionary = domain.state.terminal_summary.summary_data
	for key in ["outcome", "character_id", "contract_id", "act_progress", "final_tile_pool", "final_build", "core_yaku", "relics", "techniques", "rule_breakers", "common_patterns", "complete_hand_count", "maximum_mahjong_score", "milestones", "seed"]:
		assert_true(summary.has(key), "Run Summary Build Story includes %s" % key, failures)
	assert_true(summary.outcome == "VICTORY" and summary.character_id == Phase2CatalogScript.CHARACTER_IDS[0] and summary.contract_id == Phase2CatalogScript.CONTRACT_IDS[0], "summary records the actual result, Character and Contract", failures)
	assert_true(summary.act_progress.bosses_defeated.size() == 1, "summary records the tracked Boss progress", failures)
	assert_true(summary.final_tile_pool.size() == 68, "summary includes all 68 tiles in the Sequence Run's final pool", failures)
	assert_true(summary.core_yaku.get(tracked_yaku_id, 0) == 1 and summary.relics.has("base.relic.open_hand"), "summary includes tracked Yaku and Relic ownership", failures)
	assert_true(summary.techniques.has(Phase2CatalogScript.RUN_TECHNIQUE_IDS[0]) and summary.rule_breakers.has(Phase2CatalogScript.BOSS_RULE_BREAKER_IDS[0]), "summary includes owned Techniques and Rule Breakers", failures)
	assert_true(summary.complete_hand_count == 2 and summary.maximum_mahjong_score == 180 and summary.seed == 5501, "summary reports tracked counters and the actual Run seed", failures)
	assert_true(not summary.core_yaku.has("fake.yaku") and not summary.has("elapsed"), "caller extras cannot replace authoritative Build Story fields or invent untracked values", failures)
	var text := RunSummaryPresenterScript.format(domain.state, 5000)
	for heading in ["Build Story", "Final Tile Pool:", "Core Yaku:", "Common Patterns:", "Complete Hands:", "Maximum Mahjong Score:", "Milestones:", "Seed:", "Duration: 00:16:40"]:
		assert_true(text.contains(heading), "player-facing summary displays %s" % heading, failures)
	assert_true(text.contains("Characters: 1×2") and text.contains("9×2") and text.contains("East ×2"), "compact final pool retains numbered suit/rank copy counts and full honor identities", failures)
	assert_true(not summary.has("duration_seconds"), "elapsed wall time is added by the presentation layer and does not make replay state nondeterministic", failures)
	domain.state.run_started_at_unix_seconds = 0
	assert_true(RunSummaryPresenterScript.format(domain.state, 5000).contains("Duration: Not tracked for this Run"), "legacy saves with no recorded start time do not receive an invented duration", failures)

func test_legacy_summary_does_not_invent_untracked_metrics(failures: Array[String]) -> void:
	var legacy_state = RunStateScript.new("summary.legacy", 5502, "phase2.v1")
	legacy_state.act_index = 2
	legacy_state.act_count = 2
	legacy_state.run_started_at_unix_seconds = 0
	legacy_state.terminal_summary.outcome = "DEFEAT"
	legacy_state.terminal_summary.reason = "BATTLE_DEFEAT"
	var text := RunSummaryPresenterScript.format(legacy_state, 5000)
	for field in ["Core Yaku:", "Common Patterns:", "Complete Hands:", "Maximum Mahjong Score:", "Milestones:"]:
		assert_true(text.contains("%s Not tracked for this Run" % field), "older terminal summary marks missing %s data as untracked" % field, failures)
	assert_true(text.contains("Acts / Bosses: Act 2 of 2; Boss progress not tracked for this Run"), "older terminal summary uses the saved Act and does not invent Boss progress", failures)
	assert_true(text.contains("Seed: 5502") and text.contains("Duration: Not tracked for this Run"), "older terminal summary keeps the actual Seed and leaves absent duration untracked", failures)

func test_settlement_events_are_tracked_without_score_data(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	AlphaActTwoCatalogScript.register_all(registry)
	AlphaScaleCatalogScript.register_all(registry)
	var domain = RunDomainScript.new_alpha_run("summary.event-metrics", 5504, registry)
	var events: Array = [
		DomainEventScript.new(DomainEventScript.PATTERN_SETTLED, {"pattern_type": "SEQUENCE"}),
		DomainEventScript.new(DomainEventScript.COMPLETE_HAND_SETTLED, {
			"score": 57,
			"pattern_types": ["SEQUENCE", "TRIPLET"],
		}),
	]
	domain._record_run_summary_metrics({}, events)
	assert_true(domain.state.pattern_counts == {"SEQUENCE": 2, "TRIPLET": 1}, "settlement events update pattern metrics when the command has no score data", failures)
	assert_true(domain.state.complete_hand_count == 1 and domain.state.maximum_mahjong_score == 57, "complete-hand events update Run Summary counters without score data", failures)
	assert_true(domain.state.milestones == ["first_complete_hand"], "the first complete-hand event records its Run milestone", failures)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
