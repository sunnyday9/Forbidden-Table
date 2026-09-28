class_name PatternEvaluator
extends RefCounted

const PatternCandidateScript = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const CombinationEnumeratorScript = preload("res://src/domain/mahjong/combination_enumerator.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")

var _content_registry

func _init(content_registry) -> void:
	_content_registry = content_registry

func evaluate(hand: Array) -> Array:
	var candidates: Array = []
	for first_index in range(hand.size()):
		for second_index in range(first_index + 1, hand.size()):
			for third_index in range(second_index + 1, hand.size()):
				var first = hand[first_index]
				var second = hand[second_index]
				var third = hand[third_index]
				var first_definition = _resolve_definition(first)
				var second_definition = _resolve_definition(second)
				var third_definition = _resolve_definition(third)
				if first_definition == null or second_definition == null or third_definition == null:
					continue
				if _is_sequence(first_definition, second_definition, third_definition):
					var sequence_tiles := [first, second, third]
					sequence_tiles.sort_custom(_compare_tile_instances_by_rank)
					candidates.append(PatternCandidateScript.new(PatternCandidateScript.SEQUENCE, sequence_tiles))
	var identical_tiles_by_definition: Dictionary = {}
	for tile_instance in hand:
		var definition = _resolve_definition(tile_instance)
		if definition == null:
			continue
		if not identical_tiles_by_definition.has(tile_instance.definition_id):
			identical_tiles_by_definition[tile_instance.definition_id] = []
		identical_tiles_by_definition[tile_instance.definition_id].append(tile_instance)
	var definition_ids: Array = identical_tiles_by_definition.keys()
	definition_ids.sort()
	for definition_id in definition_ids:
		var identical_tiles: Array = identical_tiles_by_definition[definition_id]
		_append_identical_candidates(candidates, identical_tiles, 3, PatternCandidateScript.TRIPLET)
		_append_identical_candidates(candidates, identical_tiles, 4, PatternCandidateScript.QUAD)
		_append_identical_candidates(candidates, identical_tiles, 2, PatternCandidateScript.PAIR)
	return candidates

func _resolve_definition(tile_instance):
	if not tile_instance is TileInstanceScript or not tile_instance.is_valid() or _content_registry == null:
		return null
	var definition = _content_registry.resolve(tile_instance.definition_id)
	if not definition is TileDefinitionScript:
		return null
	return definition

func _append_identical_candidates(
	candidates: Array,
	identical_tiles: Array,
	required_count: int,
	pattern_type: String,
) -> void:
	for tile_combination in CombinationEnumeratorScript.combinations(identical_tiles, required_count):
		candidates.append(PatternCandidateScript.new(pattern_type, tile_combination))

func _is_sequence(first_definition, second_definition, third_definition) -> bool:
	var definitions: Array = [first_definition, second_definition, third_definition]
	for definition in definitions:
		if not ["characters", "bamboo", "dots"].has(definition.suit) or definition.rank < 1 or definition.rank > 9:
			return false
	if first_definition.suit != second_definition.suit or first_definition.suit != third_definition.suit:
		return false
	var ranks: Array[int] = [first_definition.rank, second_definition.rank, third_definition.rank]
	ranks.sort()
	return ranks[0] + 1 == ranks[1] and ranks[1] + 1 == ranks[2]

func _compare_tile_instances_by_rank(first, second) -> bool:
	var first_definition = _resolve_definition(first)
	var second_definition = _resolve_definition(second)
	return first_definition.rank < second_definition.rank
