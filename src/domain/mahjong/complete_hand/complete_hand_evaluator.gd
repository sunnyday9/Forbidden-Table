class_name CompleteHandEvaluator
extends RefCounted

const CompleteHandInterpretationScript = preload("res://src/domain/mahjong/complete_hand/complete_hand_interpretation.gd")
const PatternCandidateScript = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const CombinationEnumeratorScript = preload("res://src/domain/mahjong/combination_enumerator.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")

var _content_registry

func _init(content_registry) -> void:
	_content_registry = content_registry

func evaluate(hand: Array) -> Array:
	var definitions: Array = []
	var seen_instance_ids: Dictionary = {}
	for tile_instance in hand:
		if not tile_instance is TileInstanceScript or not tile_instance.is_valid():
			return []
		if seen_instance_ids.has(tile_instance.instance_id):
			return []
		seen_instance_ids[tile_instance.instance_id] = true
		var definition = _resolve_definition(tile_instance)
		if definition == null:
			return []
		definitions.append(definition)

	var interpretations: Array = []
	interpretations.append_array(_evaluate_standard(hand, definitions))
	var seven_pairs = _evaluate_seven_pairs(hand, definitions)
	if seven_pairs != null:
		interpretations.append(seven_pairs)
	return interpretations

func _evaluate_standard(hand: Array, definitions: Array) -> Array:
	if hand.is_empty():
		return []
	var results: Array = []
	_search_standard(hand, definitions, _all_indices(hand.size()), [], null, results)
	return results

func _search_standard(
	hand: Array,
	definitions: Array,
	unused_indices: Array,
	groups: Array,
	pair_candidate,
	results: Array,
) -> void:
	if unused_indices.is_empty():
		if groups.size() == 4 and pair_candidate != null:
			results.append(CompleteHandInterpretationScript.new(
				CompleteHandInterpretationScript.STANDARD,
				groups,
				pair_candidate,
				hand,
			))
		return
	if groups.size() > 4:
		return

	var first_index: int = unused_indices[0]
	var first_definition = definitions[first_index]
	if pair_candidate == null:
		for pair_indices in _matching_combinations(unused_indices, definitions, first_index, first_definition, 2):
			var pair_tiles: Array = _tiles_at_indices(hand, pair_indices)
			_search_standard(
				hand,
				definitions,
				_remove_indices(unused_indices, pair_indices),
				groups,
				PatternCandidateScript.new(PatternCandidateScript.PAIR, pair_tiles),
				results,
			)

	if groups.size() == 4:
		return

	for group_indices in _matching_combinations(unused_indices, definitions, first_index, first_definition, 3):
		_search_standard(
			hand,
			definitions,
			_remove_indices(unused_indices, group_indices),
			groups + [PatternCandidateScript.new(PatternCandidateScript.TRIPLET, _tiles_at_indices(hand, group_indices))],
			pair_candidate,
			results,
		)

	for group_indices in _matching_combinations(unused_indices, definitions, first_index, first_definition, 4):
		_search_standard(
			hand,
			definitions,
			_remove_indices(unused_indices, group_indices),
			groups + [PatternCandidateScript.new(PatternCandidateScript.QUAD, _tiles_at_indices(hand, group_indices))],
			pair_candidate,
			results,
		)

	for sequence_indices in _sequence_combinations(unused_indices, definitions, first_index, first_definition):
		var sequence_tiles: Array = _tiles_at_indices(hand, sequence_indices)
		sequence_tiles.sort_custom(_compare_tile_instances_by_rank)
		_search_standard(
			hand,
			definitions,
			_remove_indices(unused_indices, sequence_indices),
			groups + [PatternCandidateScript.new(PatternCandidateScript.SEQUENCE, sequence_tiles)],
			pair_candidate,
			results,
		)

func _evaluate_seven_pairs(hand: Array, definitions: Array):
	var tiles_by_definition: Dictionary = {}
	for index in range(hand.size()):
		var definition_id: String = hand[index].definition_id
		if not tiles_by_definition.has(definition_id):
			tiles_by_definition[definition_id] = []
		tiles_by_definition[definition_id].append(hand[index])
	if tiles_by_definition.size() != 7:
		return null

	var definition_ids: Array = tiles_by_definition.keys()
	definition_ids.sort()
	var pairs: Array = []
	for definition_id in definition_ids:
		var identical_tiles: Array = tiles_by_definition[definition_id]
		if identical_tiles.size() != 2 and identical_tiles.size() != 4:
			return null
		pairs.append(PatternCandidateScript.new(PatternCandidateScript.PAIR, identical_tiles))
	return CompleteHandInterpretationScript.new(
		CompleteHandInterpretationScript.SEVEN_PAIRS,
		pairs,
		null,
		hand,
	)

func _matching_combinations(unused_indices: Array, definitions: Array, first_index: int, first_definition, required_count: int) -> Array:
	var matching_indices: Array = [first_index]
	for index in unused_indices:
		if index != first_index and definitions[index].content_id == first_definition.content_id:
			matching_indices.append(index)
	return CombinationEnumeratorScript.combinations(matching_indices, required_count)

func _sequence_combinations(unused_indices: Array, definitions: Array, first_index: int, first_definition) -> Array:
	if not ["characters", "bamboo", "dots"].has(first_definition.suit):
		return []
	var sequences: Array = []
	for start_rank in range(first_definition.rank - 2, first_definition.rank + 1):
		if start_rank < 1 or start_rank + 2 > 9:
			continue
		var required_ranks: Array = [start_rank, start_rank + 1, start_rank + 2]
		var choices: Array = [[first_index]]
		var possible: bool = true
		for required_rank in required_ranks:
			if required_rank == first_definition.rank:
				continue
			var matching: Array = []
			for index in unused_indices:
				var definition = definitions[index]
				if definition.suit == first_definition.suit and definition.rank == required_rank:
					matching.append(index)
			if matching.is_empty():
				possible = false
				break
			var next_choices: Array = []
			for choice in choices:
				for matching_index in matching:
					if matching_index not in choice:
						var extended_choice: Array = choice.duplicate()
						extended_choice.append(matching_index)
						next_choices.append(extended_choice)
			choices = next_choices
		if possible:
			sequences.append_array(choices)
	return sequences

func _resolve_definition(tile_instance):
	if _content_registry == null:
		return null
	var definition = _content_registry.resolve(tile_instance.definition_id)
	if not definition is TileDefinitionScript:
		return null
	return definition

func _all_indices(count: int) -> Array:
	var indices: Array = []
	for index in range(count):
		indices.append(index)
	return indices

func _tiles_at_indices(hand: Array, indices: Array) -> Array:
	var tiles: Array = []
	for index in indices:
		tiles.append(hand[index])
	return tiles

func _remove_indices(indices: Array, removed: Array) -> Array:
	var remaining: Array = []
	for index in indices:
		if index not in removed:
			remaining.append(index)
	return remaining

func _compare_tile_instances_by_rank(first, second) -> bool:
	var first_definition = _resolve_definition(first)
	var second_definition = _resolve_definition(second)
	return first_definition.rank < second_definition.rank
