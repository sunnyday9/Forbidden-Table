class_name DiscardTileScorerTest
extends RefCounted

const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const PatternEvaluatorScript = preload("res://src/domain/mahjong/pattern/pattern_evaluator.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")

const SCORER_PATH := "res://src/domain/tiles/discard_tile_scorer.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var scorer_script = load(SCORER_PATH)
	assert_true(scorer_script != null, "the shared public-information Discard scorer is available", failures)
	if scorer_script == null:
		return failures
	var scorer = scorer_script.new()
	var registry = _registry()
	test_ready_legal_groups_are_protected(scorer, registry, failures)
	test_character_weights_connectors_and_reserve_pairs_differently(scorer, registry, failures)
	test_reserve_triplet_prospects_are_retained(scorer, registry, failures)
	test_honor_pairs_are_preserved_and_physical_ties_are_deterministic(scorer, registry, failures)
	test_unknown_hand_definitions_remain_rankable_without_hidden_data(scorer, registry, failures)
	return failures

func test_ready_legal_groups_are_protected(scorer, registry, failures: Array[String]) -> void:
	var hand: Array = [
		_tile("ready.sequence.03", "base.tile.characters.3"),
		_tile("ready.sequence.04", "base.tile.characters.4"),
		_tile("ready.sequence.05", "base.tile.characters.5"),
		_tile("ready.isolated.east", "base.tile.honors.east"),
	]
	var all_candidates: Array = PatternEvaluatorScript.new(registry).evaluate(hand)
	var ready_candidates: Array = []
	for candidate in all_candidates:
		if candidate.pattern_type == "Sequence":
			ready_candidates.append(candidate)
	var ranked: Array = scorer.ranked_candidates(hand, "base.character.sequence", registry, ready_candidates)
	var ready_entry := _entry_for(ranked, "ready.sequence.03")
	var isolated_entry := _entry_for(ranked, "ready.isolated.east")
	assert_true(ready_candidates.size() == 1, "the fixture contains one actual legal Sequence candidate", failures)
	assert_true(not ranked.is_empty() and str(ranked[0].get("instance_id", "")) == "ready.isolated.east", "a ready group is protected before the isolated tile is selected", failures)
	assert_true(ready_entry.get("score", -999) > isolated_entry.get("score", 999), "legal candidate membership raises retention score", failures)
	assert_true(str(ready_entry.get("rationale_key", "")) == "ready_group", "the public hint rationale identifies a ready scoring group", failures)

func test_character_weights_connectors_and_reserve_pairs_differently(scorer, registry, failures: Array[String]) -> void:
	var hand: Array = [
		_tile("shape.characters.04", "base.tile.characters.4"),
		_tile("shape.characters.05", "base.tile.characters.5"),
		_tile("shape.bamboo.pair.a", "base.tile.bamboo.8"),
		_tile("shape.bamboo.pair.z", "base.tile.bamboo.8"),
		_tile("shape.isolated.white", "base.tile.honors.white"),
	]
	var sequence_ranked: Array = scorer.ranked_candidates(hand, "base.character.sequence", registry)
	var reserve_ranked: Array = scorer.ranked_candidates(hand, "base.character.reserve", registry)
	var sequence_connector: Dictionary = _entry_for(sequence_ranked, "shape.characters.04")
	var sequence_pair: Dictionary = _entry_for(sequence_ranked, "shape.bamboo.pair.a")
	var reserve_connector: Dictionary = _entry_for(reserve_ranked, "shape.characters.04")
	var reserve_pair: Dictionary = _entry_for(reserve_ranked, "shape.bamboo.pair.a")
	assert_true(sequence_connector.get("score", -999) > sequence_pair.get("score", 999), "Sequence values useful adjacent ranks above an unconnected pair", failures)
	assert_true(reserve_pair.get("score", -999) > reserve_connector.get("score", 999), "Reserve values an identical pair and its Triplet prospect above a lone Sequence connector", failures)
	assert_true(str(reserve_pair.get("rationale_key", "")) == "reserve_pair", "Reserve pair retention exposes a character-aware rationale", failures)

func test_honor_pairs_are_preserved_and_physical_ties_are_deterministic(scorer, registry, failures: Array[String]) -> void:
	var hand: Array = [
		_tile("honor.east.a", "base.tile.honors.east"),
		_tile("honor.east.z", "base.tile.honors.east"),
		_tile("honor.white.single", "base.tile.honors.white"),
		_tile("honor.characters.single", "base.tile.characters.1"),
	]
	for character_id in ["base.character.sequence", "base.character.reserve"]:
		var ranked: Array = scorer.ranked_candidates(hand, character_id, registry)
		var pair_a: Dictionary = _entry_for(ranked, "honor.east.a")
		var pair_z: Dictionary = _entry_for(ranked, "honor.east.z")
		var white_single: Dictionary = _entry_for(ranked, "honor.white.single")
		assert_true(pair_a.get("score", -999) > white_single.get("score", 999), "%s preserves a useful honor pair over an honor singleton" % character_id, failures)
		assert_true(str(pair_a.get("rationale_key", "")) == "honor_pair", "%s reports the honor-pair rationale" % character_id, failures)
		assert_true(pair_a.get("score", -1) == pair_z.get("score", -2), "physical copies of one definition receive equal scores", failures)
		var pair_a_index := _index_of(ranked, "honor.east.a")
		var pair_z_index := _index_of(ranked, "honor.east.z")
		assert_true(pair_a_index >= 0 and pair_z_index > pair_a_index, "equal-score physical copies use stable instance-ID ordering", failures)

func test_reserve_triplet_prospects_are_retained(scorer, registry, failures: Array[String]) -> void:
	var hand: Array = [
		_tile("reserve.triplet.a", "base.tile.dots.6"),
		_tile("reserve.triplet.b", "base.tile.dots.6"),
		_tile("reserve.triplet.c", "base.tile.dots.6"),
		_tile("reserve.isolated", "base.tile.characters.9"),
	]
	var ranked: Array = scorer.ranked_candidates(hand, "base.character.reserve", registry)
	assert_true(_entry_for(ranked, "reserve.triplet.a").get("score", -999) > _entry_for(ranked, "reserve.isolated").get("score", 999), "Reserve keeps visible Triplet prospects above an isolated tile", failures)
	assert_true(str(_entry_for(ranked, "reserve.triplet.a").get("rationale_key", "")) == "reserve_triplet", "the hint rationale identifies Reserve Triplet prospects", failures)

func test_unknown_hand_definitions_remain_rankable_without_hidden_data(scorer, registry, failures: Array[String]) -> void:
	var hand: Array = [
		_tile("unknown.legacy", "missing.tile.definition"),
		_tile("known.isolated", "base.tile.characters.9"),
	]
	var ranked: Array = scorer.ranked_candidates(hand, "legacy.character.unknown", registry)
	assert_true(ranked.size() == hand.size(), "legacy or unresolved visible Hand entries remain rankable", failures)
	assert_true(_index_of(ranked, "unknown.legacy") >= 0, "the scorer never drops a physical Hand TileInstance", failures)
	assert_true(str(_entry_for(ranked, "unknown.legacy").get("rationale_key", "")) == "unknown_definition", "unknown content receives a defensive neutral rationale", failures)

func _entry_for(ranked: Array, instance_id: String) -> Dictionary:
	for entry in ranked:
		if entry is Dictionary and str(entry.get("instance_id", "")) == instance_id:
			return entry
	return {}

func _index_of(ranked: Array, instance_id: String) -> int:
	for index in range(ranked.size()):
		if str(ranked[index].get("instance_id", "")) == instance_id:
			return index
	return -1

func _tile(instance_id: String, definition_id: String):
	return TileInstanceScript.new(instance_id, definition_id)

func _registry():
	var registry = ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	return registry

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
