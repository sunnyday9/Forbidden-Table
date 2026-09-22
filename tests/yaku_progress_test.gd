class_name YakuProgressTest
extends RefCounted

const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const CompleteHandEvaluator = preload("res://src/domain/mahjong/complete_hand/complete_hand_evaluator.gd")
const MahjongScoreResolver = preload("res://src/domain/mahjong/scoring/mahjong_score_resolver.gd")
const PatternCandidate = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const SettledPattern = preload("res://src/domain/mahjong/settlement/settled_pattern.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")
const YakuCatalog = preload("res://src/content/catalogs/yaku_catalog.gd")
const YakuEvaluator = preload("res://src/domain/mahjong/yaku/yaku_evaluator.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_catalog_has_representative_scopes_and_families(failures)
	test_progress_uses_hand_only_and_reports_reserve_potential(failures)
	test_progress_recomputes_after_partial_settlement(failures)
	test_complete_hand_progress_uses_structural_interpretation(failures)
	test_progress_is_deterministic_and_non_mutating(failures)
	test_local_and_complete_yaku_expose_typed_score_hooks(failures)
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
