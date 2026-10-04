class_name YakuProgressTest
extends RefCounted

const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const CompleteHandEvaluator = preload("res://src/domain/mahjong/complete_hand/complete_hand_evaluator.gd")
const MahjongScoreResolver = preload("res://src/domain/mahjong/scoring/mahjong_score_resolver.gd")
const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const PatternCandidate = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const SettledPattern = preload("res://src/domain/mahjong/settlement/settled_pattern.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")
const YakuCatalog = preload("res://src/content/catalogs/yaku_catalog.gd")
const YakuDefinition = preload("res://src/content/definitions/yaku_definition.gd")
const YakuEvaluator = preload("res://src/domain/mahjong/yaku/yaku_evaluator.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_catalog_has_representative_scopes_and_families(failures)
	test_progress_uses_hand_only_and_reports_reserve_potential(failures)
	test_progress_recomputes_after_partial_settlement(failures)
	test_complete_hand_progress_uses_structural_interpretation(failures)
	test_progress_is_deterministic_and_non_mutating(failures)
	test_local_and_complete_yaku_expose_typed_score_hooks(failures)
	test_stage_four_yaku_use_registered_content_and_score_hooks(failures)
	test_stage_four_yaku_resolve_deterministically_in_both_acts(failures)
	return failures

func test_catalog_has_representative_scopes_and_families(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	var definitions := YakuCatalog.register_representative(registry)
	assert_true(definitions.size() == 8, "the prototype catalog contains eight representative Yaku", failures)
	var scopes: Dictionary = {}
	var families: Dictionary = {}
	for definition in definitions:
		scopes[definition.scope] = true
		families[definition.family] = true
	assert_true(scopes.has("LOCAL_SETTLEMENT"), "the catalog includes Local Settlement Yaku", failures)
	assert_true(scopes.has("COMPLETE_HAND"), "the catalog includes Complete Hand Yaku", failures)
	assert_true(scopes.has("BOTH"), "the catalog includes Yaku with both scopes", failures)
	assert_true(families.has("STRUCTURAL"), "the catalog includes structural Yaku", failures)
	assert_true(families.has("SUIT_HONOR"), "the catalog includes suit and honor Yaku", failures)
	assert_true(families.has("COMPLETE_HAND"), "the catalog includes Complete Hand Yaku", failures)
	assert_true(families.has("ROGUELIKE_STRUCTURAL"), "the catalog includes roguelike structural Yaku", failures)
	assert_true(registry.validate().is_valid(), "the representative catalog passes content validation", failures)

func test_progress_uses_hand_only_and_reports_reserve_potential(failures: Array[String]) -> void:
	var fixture := _fixture()
	var hand: Array = []
	hand.append_array(_instances("run.yaku.sequence.hand.1", "base.tile.characters.1", 1))
	hand.append_array(_instances("run.yaku.sequence.hand.2", "base.tile.characters.2", 1))
	hand.append_array(_instances("run.yaku.sequence.hand.3", "base.tile.characters.3", 1))
	hand.append_array(_instances("run.yaku.sequence.hand.4", "base.tile.characters.4", 1))
	hand.append_array(_instances("run.yaku.sequence.hand.5", "base.tile.characters.5", 1))
	var reserve := _instances("run.yaku.sequence.reserve", "base.tile.characters.6", 1)
	var result = fixture.evaluator.get_progress("prototype.yaku.sequence_path", {"hand": hand, "reserve": reserve})

	assert_true(result.stage == "ADVANCING", "Sequence Path reports its current discrete stage", failures)
	assert_true(result.satisfied_conditions == ["1 sequence"], "progress reports satisfied structural conditions", failures)
	assert_true(result.missing_conditions == ["2 more sequences"], "progress reports the remaining structural gap", failures)
	assert_true(result.blockers.is_empty(), "a viable structural path has no blockers", failures)
	assert_true(result.reserve_potential != null, "progress exposes optional Reserve potential", failures)
	assert_true(result.reserve_potential["missing_conditions"] == ["1 more sequence"], "Reserve potential is reported separately from formal progress", failures)
	assert_true(is_equal_approx(float(result.reserve_potential.get("normalized_score", 0.0)), 2.0 / 3.0), "Reserve potential exposes a comparable normalized progress value", failures)
	assert_true(result.display_tokens == ["SEQUENCE", "1/3"], "progress exposes stable display tokens", failures)

func test_progress_recomputes_after_partial_settlement(failures: Array[String]) -> void:
	var fixture := _fixture()
	var zones := TileZoneContainer.new()
	var tiles := _instances("run.yaku.settlement", "base.tile.characters.1", 3)
	for tile in tiles:
		zones.add(tile, TileZone.HAND)
	var before = fixture.evaluator.get_progress("prototype.yaku.triplet_foundation", {"hand": zones.contents(TileZone.HAND), "reserve": zones.contents(TileZone.RESERVE)})
	zones.transfer(tiles[0].instance_id, TileZone.HAND, TileZone.DISCARD)
	zones.transfer(tiles[1].instance_id, TileZone.HAND, TileZone.DISCARD)
	zones.transfer(tiles[2].instance_id, TileZone.HAND, TileZone.DISCARD)
	var after = fixture.evaluator.get_progress("prototype.yaku.triplet_foundation", {"hand": zones.contents(TileZone.HAND), "reserve": zones.contents(TileZone.RESERVE)})

	assert_true(before.stage == "ADVANCING", "a current triplet is visible before Partial Settlement", failures)
	assert_true(after.stage == "STARTING", "consuming the triplet lowers current-state progress", failures)
	assert_true(after.satisfied_conditions.is_empty(), "consumed tiles are absent from recomputed progress", failures)
	assert_true(zones.size(TileZone.DISCARD) == 3, "progress evaluation does not perform settlement mutations", failures)

func test_complete_hand_progress_uses_structural_interpretation(failures: Array[String]) -> void:
	var fixture := _fixture()
	var hand := _standard_hand("run.yaku.complete")
	var result = fixture.evaluator.get_progress("prototype.yaku.standard_complete_hand", {"hand": hand, "reserve": []})
	assert_true(result.stage == "COMPLETE", "Standard Complete Hand progress reaches Complete from a structural interpretation", failures)
	assert_true(result.satisfied_conditions == ["standard complete hand"], "Complete Hand progress names its satisfied condition", failures)
	assert_true(result.blockers.is_empty(), "a valid Complete Hand has no blockers", failures)

func test_progress_is_deterministic_and_non_mutating(failures: Array[String]) -> void:
	var fixture := _fixture()
	var hand := _standard_hand("run.yaku.determinism")
	var reserve := _instances("run.yaku.determinism.reserve", "base.tile.honors.1", 1)
	var hand_ids_before := _instance_ids(hand)
	var reserve_ids_before := _instance_ids(reserve)
	var first = fixture.evaluator.get_progress("prototype.yaku.mixed_table", {"hand": hand, "reserve": reserve})
	var second = fixture.evaluator.get_progress("prototype.yaku.mixed_table", {"hand": hand, "reserve": reserve})
	assert_true(first.to_dictionary() == second.to_dictionary(), "repeated progress evaluation is deterministic", failures)
	assert_true(_instance_ids(hand) == hand_ids_before, "progress evaluation preserves Hand order and instances", failures)
	assert_true(_instance_ids(reserve) == reserve_ids_before, "progress evaluation preserves Reserve order and instances", failures)

func test_local_and_complete_yaku_expose_typed_score_hooks(failures: Array[String]) -> void:
	var fixture := _fixture()
	var sequence := SettledPattern.new(PatternCandidate.SEQUENCE, _instances("run.yaku.hook.sequence", "base.tile.characters.1", 3))
	var local_contributions: Array = fixture.evaluator.resolve_local(sequence)
	assert_true(local_contributions.size() > 0, "a Local Yaku can contribute to Partial Settlement", failures)
	if not local_contributions.is_empty():
		assert_true(local_contributions[0].source_id == "prototype.yaku.sequence_path", "Local Yaku uses a typed ScoreContribution hook", failures)
	assert_true(not _has_source(local_contributions, "prototype.yaku.mixed_table"), "a single Sequence does not satisfy the unrelated Mixed Table Group Shape Yaku", failures)
	var local_score = MahjongScoreResolver.new().resolve(sequence, fixture.evaluator)
	assert_true(_has_source(local_score.contributions, "prototype.yaku.sequence_path"), "Partial Settlement score resolution consumes the Local Yaku hook", failures)
	var interpretations: Array = CompleteHandEvaluator.new(fixture.registry).evaluate(_standard_hand("run.yaku.hook.complete"))
	var complete_contributions: Array = fixture.evaluator.resolve_complete(interpretations[0] if not interpretations.is_empty() else null)
	assert_true(complete_contributions.size() > 0, "a Hand Yaku can contribute to Complete Hand", failures)
	if not complete_contributions.is_empty():
		assert_true(complete_contributions[0].source_id == "prototype.yaku.standard_complete_hand", "Complete Hand Yaku uses a typed ScoreContribution hook", failures)
	var complete_score = MahjongScoreResolver.new().resolve_complete_hand(interpretations[0] if not interpretations.is_empty() else null, fixture.evaluator)
	assert_true(_has_source(complete_score.contributions, "prototype.yaku.standard_complete_hand"), "Complete Hand score resolution consumes the Hand Yaku hook", failures)

func test_stage_four_yaku_use_registered_content_and_score_hooks(failures: Array[String]) -> void:
	var fixture := _stage_four_fixture()
	assert_true(fixture.scale_registration.is_valid(), "Stage 4 Scale Yaku register through the existing content bundle", failures)
	assert_true(fixture.registry.validate().is_valid(), "the expanded shared content registry remains valid", failures)
	for index in range(8, AlphaScaleCatalog.YAKU_IDS.size()):
		var identifier: String = AlphaScaleCatalog.YAKU_IDS[index]
		var definition = fixture.registry.resolve(identifier)
		assert_true(definition is YakuDefinition, "%s resolves to a production YakuDefinition" % identifier, failures)
		if not definition is YakuDefinition:
			continue
		assert_true(not definition.local_score.is_empty() or not definition.complete_score.is_empty(), "%s has an intended score path" % identifier, failures)
		if not definition.local_score.is_empty():
			assert_true(definition.local_score.get("source_id", "") == identifier, "%s retains its stable local score-source ID" % identifier, failures)
		if not definition.complete_score.is_empty():
			assert_true(definition.complete_score.get("source_id", "") == "%s.complete" % identifier, "%s retains its stable Complete Hand score-source ID" % identifier, failures)

func test_stage_four_yaku_resolve_deterministically_in_both_acts(failures: Array[String]) -> void:
	var fixture := _stage_four_fixture()
	var evaluator = fixture.evaluator
	var resolver := MahjongScoreResolver.new()
	var sequence_tiles := _instances("run.yaku.stage4.local.sequence", "base.tile.characters.1", 1)
	sequence_tiles.append_array(_instances("run.yaku.stage4.local.sequence.middle", "base.tile.characters.2", 1))
	sequence_tiles.append_array(_instances("run.yaku.stage4.local.sequence.end", "base.tile.characters.3", 1))
	var settled := SettledPattern.new(PatternCandidate.SEQUENCE, sequence_tiles)
	var supporting_hand := _instances("run.yaku.stage4.local.triplet", "base.tile.dots.5", 3)
	var local_state := {"hand": supporting_hand, "act_index": 1}
	var act_two_local_state := {"hand": supporting_hand, "act_index": 2}
	var first_local = resolver.resolve(settled, evaluator, local_state)
	var repeated_local = resolver.resolve(settled, evaluator, local_state)
	var act_two_local = resolver.resolve(settled, evaluator, act_two_local_state)
	assert_true(_has_source(first_local.contributions, "alpha.yaku.sequence_triplet"), "a new structural Yaku contributes through Partial Settlement scoring", failures)
	assert_true(first_local.to_dictionary() == repeated_local.to_dictionary(), "the new Partial Settlement Yaku score is deterministic", failures)
	assert_true(first_local.to_dictionary() == act_two_local.to_dictionary(), "the shared Partial Settlement Yaku behaves the same in either Act", failures)

	var pair_tiles := _instances("run.yaku.stage4.local.pair", "base.tile.dots.6", 2)
	var pair_selection := SettledPattern.new(PatternCandidate.PAIR, pair_tiles)
	var pair_support := _instances("run.yaku.stage4.local.pair.triplet", "base.tile.dots.5", 3)
	pair_support.append_array(_instances("run.yaku.stage4.local.pair.sequence.1", "base.tile.characters.1", 1))
	pair_support.append_array(_instances("run.yaku.stage4.local.pair.sequence.2", "base.tile.characters.2", 1))
	pair_support.append_array(_instances("run.yaku.stage4.local.pair.sequence.3", "base.tile.characters.3", 1))
	var pair_score = resolver.resolve(pair_selection, evaluator, {"hand": pair_support})
	assert_true(_has_source(pair_score.contributions, "alpha.yaku.pair_triad"), "a new Pair Yaku resolves through Partial Settlement scoring", failures)
	assert_true(_has_source(pair_score.contributions, "alpha.yaku.triplet_pair"), "a pair-shaped Local Yaku resolves through the existing settlement seam", failures)
	assert_true(_has_source(pair_score.contributions, "alpha.yaku.sequence_triplet_pair"), "a three-pattern Local Yaku resolves through the existing settlement seam", failures)

	var quad_tiles := _instances("run.yaku.stage4.local.quad", "base.tile.characters.1", 4)
	var quad_selection := SettledPattern.new(PatternCandidate.QUAD, quad_tiles)
	var quad_support := _instances("run.yaku.stage4.local.quad.pair", "base.tile.dots.6", 2)
	var quad_score = resolver.resolve(quad_selection, evaluator, {"hand": quad_support})
	assert_true(_has_source(quad_score.contributions, "alpha.yaku.quad_duet"), "a new Quad Yaku resolves through Partial Settlement scoring", failures)
	assert_true(_has_source(quad_score.contributions, "alpha.yaku.quad_pair"), "a quad-and-pair Local Yaku resolves through the existing settlement seam", failures)

	var complete_cases: Array[Dictionary] = [
		{
			"label": "standard",
			"hand": _standard_hand("run.yaku.stage4.complete.standard"),
			"sources": ["alpha.yaku.sequence_cascade.complete", "alpha.yaku.sequence_triplet.complete"],
		},
		{
			"label": "honor",
			"hand": _honor_complete_hand("run.yaku.stage4.complete.honor"),
			"sources": ["alpha.yaku.triplet_duet.complete", "alpha.yaku.honor_beacon.complete", "alpha.yaku.honor_gathering.complete"],
		},
		{
			"label": "quad",
			"hand": _quad_complete_hand("run.yaku.stage4.complete.quad"),
			"sources": ["alpha.yaku.sequence_quad.complete", "alpha.yaku.triplet_quad.complete"],
		},
		{
			"label": "characters",
			"hand": _single_suit_complete_hand("run.yaku.stage4.complete.characters", "characters"),
			"sources": ["alpha.yaku.character_majority.complete"],
		},
		{
			"label": "dots",
			"hand": _single_suit_complete_hand("run.yaku.stage4.complete.dots", "dots"),
			"sources": ["alpha.yaku.dot_majority.complete"],
		},
	]
	var complete_evaluator := CompleteHandEvaluator.new(fixture.registry)
	for complete_case in complete_cases:
		var interpretations: Array = complete_evaluator.evaluate(complete_case.hand)
		assert_true(not interpretations.is_empty(), "%s fixture resolves through the existing Complete Hand evaluator" % complete_case.label, failures)
		if interpretations.is_empty():
			continue
		var interpretation = interpretations[0]
		var first_complete = resolver.resolve_complete_hand(interpretation, evaluator, {"act_index": 1})
		var repeated_complete = resolver.resolve_complete_hand(interpretation, evaluator, {"act_index": 1})
		var act_two_complete = resolver.resolve_complete_hand(interpretation, evaluator, {"act_index": 2})
		for source_id in complete_case.sources:
			assert_true(_has_source(first_complete.contributions, source_id), "%s fixture resolves %s through Complete Hand scoring" % [complete_case.label, source_id], failures)
		assert_true(first_complete.to_dictionary() == repeated_complete.to_dictionary(), "%s Complete Hand Yaku scoring is deterministic" % complete_case.label, failures)
		assert_true(first_complete.to_dictionary() == act_two_complete.to_dictionary(), "%s Complete Hand Yaku is shared across both Acts" % complete_case.label, failures)

func _stage_four_fixture() -> Dictionary:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	var scale_registration = AlphaScaleCatalog.register_all(registry)
	return {"registry": registry, "evaluator": YakuEvaluator.new(registry), "scale_registration": scale_registration}

func _honor_complete_hand(prefix: String) -> Array:
	var hand: Array = []
	hand.append_array(_instances(prefix + ".east", "base.tile.honors.east", 3))
	hand.append_array(_instances(prefix + ".red", "base.tile.honors.red", 3))
	hand.append_array(_instances(prefix + ".white", "base.tile.honors.white", 2))
	hand.append_array(_instances(prefix + ".characters.1", "base.tile.characters.1", 1))
	hand.append_array(_instances(prefix + ".characters.2", "base.tile.characters.2", 1))
	hand.append_array(_instances(prefix + ".characters.3", "base.tile.characters.3", 1))
	hand.append_array(_instances(prefix + ".bamboo.1", "base.tile.bamboo.1", 1))
	hand.append_array(_instances(prefix + ".bamboo.2", "base.tile.bamboo.2", 1))
	hand.append_array(_instances(prefix + ".bamboo.3", "base.tile.bamboo.3", 1))
	return hand

func _quad_complete_hand(prefix: String) -> Array:
	var hand: Array = []
	hand.append_array(_instances(prefix + ".quad", "base.tile.characters.1", 4))
	hand.append_array(_instances(prefix + ".sequence.one.1", "base.tile.bamboo.1", 1))
	hand.append_array(_instances(prefix + ".sequence.one.2", "base.tile.bamboo.2", 1))
	hand.append_array(_instances(prefix + ".sequence.one.3", "base.tile.bamboo.3", 1))
	hand.append_array(_instances(prefix + ".triplet", "base.tile.dots.5", 3))
	hand.append_array(_instances(prefix + ".sequence.two.1", "base.tile.characters.7", 1))
	hand.append_array(_instances(prefix + ".sequence.two.2", "base.tile.characters.8", 1))
	hand.append_array(_instances(prefix + ".sequence.two.3", "base.tile.characters.9", 1))
	hand.append_array(_instances(prefix + ".pair", "base.tile.dots.6", 2))
	return hand

func _single_suit_complete_hand(prefix: String, suit: String) -> Array:
	var hand: Array = []
	hand.append_array(_instances(prefix + ".quad", "base.tile.%s.1" % suit, 4))
	hand.append_array(_instances(prefix + ".sequence.one.1", "base.tile.%s.2" % suit, 1))
	hand.append_array(_instances(prefix + ".sequence.one.2", "base.tile.%s.3" % suit, 1))
	hand.append_array(_instances(prefix + ".sequence.one.3", "base.tile.%s.4" % suit, 1))
	hand.append_array(_instances(prefix + ".triplet", "base.tile.%s.5" % suit, 3))
	hand.append_array(_instances(prefix + ".sequence.two.1", "base.tile.%s.6" % suit, 1))
	hand.append_array(_instances(prefix + ".sequence.two.2", "base.tile.%s.7" % suit, 1))
	hand.append_array(_instances(prefix + ".sequence.two.3", "base.tile.%s.8" % suit, 1))
	hand.append_array(_instances(prefix + ".pair", "base.tile.%s.9" % suit, 2))
	return hand

func _fixture() -> Dictionary:
	var registry := ContentRegistry.new()
	YakuCatalog.register_representative(registry)
	for suit in ["characters", "bamboo", "dots"]:
		for rank in range(1, 10):
			registry.register(TileDefinition.new("base.tile.%s.%d" % [suit, rank], suit, rank))
	for honor_rank in range(1, 4):
		registry.register(TileDefinition.new("base.tile.honors.%d" % honor_rank, "honors", 0))
	return {"evaluator": YakuEvaluator.new(registry), "registry": registry}

func _standard_hand(prefix: String) -> Array:
	var hand: Array = []
	hand.append_array(_instances(prefix + ".sequence.one.1", "base.tile.characters.1", 1))
	hand.append_array(_instances(prefix + ".sequence.one.2", "base.tile.characters.2", 1))
	hand.append_array(_instances(prefix + ".sequence.one.3", "base.tile.characters.3", 1))
	hand.append_array(_instances(prefix + ".sequence.two.1", "base.tile.characters.4", 1))
	hand.append_array(_instances(prefix + ".sequence.two.2", "base.tile.characters.5", 1))
	hand.append_array(_instances(prefix + ".sequence.two.3", "base.tile.characters.6", 1))
	hand.append_array(_instances(prefix + ".sequence.three.1", "base.tile.characters.7", 1))
	hand.append_array(_instances(prefix + ".sequence.three.2", "base.tile.characters.8", 1))
	hand.append_array(_instances(prefix + ".sequence.three.3", "base.tile.characters.9", 1))
	hand.append_array(_instances(prefix + ".triplet", "base.tile.dots.5", 3))
	hand.append_array(_instances(prefix + ".pair", "base.tile.dots.6", 2))
	return hand

func _instances(prefix: String, definition_id: String, count: int) -> Array:
	var tiles: Array = []
	for index in range(count):
		tiles.append(TileInstance.new("%s.%03d" % [prefix, index + 1], definition_id))
	return tiles

func _instance_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile in tiles:
		ids.append(tile.instance_id)
	return ids

func _has_source(contributions: Array, source_id: String) -> bool:
	for contribution in contributions:
		if contribution.source_id == source_id:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
