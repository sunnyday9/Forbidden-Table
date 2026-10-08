class_name DiscardTileScorer
extends RefCounted

const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")

const SEQUENCE_CHARACTER_ID := "base.character.sequence"
const RESERVE_CHARACTER_ID := "base.character.reserve"

## Rank visible Hand instances from the least useful to retain to the most useful.
## The scorer intentionally accepts no Draw Wall or unseen-pool state.
static func ranked_candidates(
	hand_tiles: Array,
	character_id: String,
	content_registry,
	ready_candidates: Array = [],
) -> Array[Dictionary]:
	var counts_by_definition: Dictionary = {}
	var definitions_by_instance: Dictionary = {}
	for tile in hand_tiles:
		var definition = _resolve_definition(tile, content_registry)
		if definition == null:
			continue
		definitions_by_instance[str(tile.instance_id)] = definition
		counts_by_definition[str(tile.definition_id)] = int(counts_by_definition.get(str(tile.definition_id), 0)) + 1

	var ready_bonus_by_instance: Dictionary = {}
	for candidate in ready_candidates:
		var candidate_bonus := _ready_candidate_bonus(_candidate_pattern_type(candidate))
		if candidate_bonus <= 0:
			continue
		for tile in _candidate_tiles(candidate):
			if tile == null:
				continue
			var instance_id := str(tile.instance_id) if tile is Object and _has_property(tile, "instance_id") else ""
			if instance_id.is_empty():
				continue
			ready_bonus_by_instance[instance_id] = maxi(candidate_bonus, int(ready_bonus_by_instance.get(instance_id, 0)))

	var ranked: Array[Dictionary] = []
	for hand_index in range(hand_tiles.size()):
		var tile = hand_tiles[hand_index]
		if tile == null:
			continue
		var instance_id := str(tile.instance_id) if tile is Object and _has_property(tile, "instance_id") else ""
		var definition = definitions_by_instance.get(instance_id)
		var retention_score := 0
		var rationale_key := "unknown_definition"
		if definition != null:
			var copies_in_hand := int(counts_by_definition.get(str(tile.definition_id), 0))
			var adjacency_score := _adjacency_score(tile, hand_tiles, definitions_by_instance, character_id)
			var group_score := _visible_group_score(definition, copies_in_hand, character_id)
			var ready_score := int(ready_bonus_by_instance.get(instance_id, 0))
			retention_score = group_score + adjacency_score + ready_score
			rationale_key = _rationale_key(definition, copies_in_hand, adjacency_score, ready_score, character_id)
		ranked.append({
			"instance_id": instance_id,
			"score": retention_score,
			"rationale_key": rationale_key,
			"hand_index": hand_index,
		})

	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := int(left.get("score", 0))
		var right_score := int(right.get("score", 0))
		if left_score != right_score:
			return left_score < right_score
		var left_id := str(left.get("instance_id", ""))
		var right_id := str(right.get("instance_id", ""))
		if left_id != right_id:
			return left_id < right_id
		return int(left.get("hand_index", 0)) < int(right.get("hand_index", 0))
	)
	for entry in ranked:
		entry.erase("hand_index")
	return ranked

static func _resolve_definition(tile, content_registry):
	if not tile is TileInstanceScript or not tile.is_valid() or content_registry == null:
		return null
	var definition = content_registry.resolve(tile.definition_id)
	return definition if definition is TileDefinitionScript else null

static func _visible_group_score(definition, copies_in_hand: int, character_id: String) -> int:
	if copies_in_hand >= 4:
		return 54
	if copies_in_hand >= 3:
		return 38 if character_id == RESERVE_CHARACTER_ID else 34
	if copies_in_hand < 2:
		return 0
	if definition.suit == "honors":
		return 42
	if character_id == RESERVE_CHARACTER_ID:
		return 30
	if character_id == SEQUENCE_CHARACTER_ID:
		return 14
	return 20

static func _adjacency_score(tile, hand_tiles: Array, definitions_by_instance: Dictionary, character_id: String) -> int:
	var definition = definitions_by_instance.get(str(tile.instance_id))
	if definition == null or definition.suit == "honors":
		return 0
	var total := 0
	for other in hand_tiles:
		if other == null or str(other.instance_id) == str(tile.instance_id):
			continue
		var other_definition = definitions_by_instance.get(str(other.instance_id))
		if other_definition == null or other_definition.suit != definition.suit:
			continue
		var distance := absi(int(other_definition.rank) - int(definition.rank))
		if distance == 1:
			total += 16 if character_id == SEQUENCE_CHARACTER_ID else 7 if character_id == RESERVE_CHARACTER_ID else 11
		elif distance == 2:
			total += 6 if character_id == SEQUENCE_CHARACTER_ID else 2 if character_id == RESERVE_CHARACTER_ID else 4
	return total

static func _ready_candidate_bonus(pattern_type: String) -> int:
	match pattern_type:
		"Quad": return 1200
		"Triplet": return 1150
		"Sequence": return 1100
		"Pair": return 1050
	return 0

static func _rationale_key(
	definition,
	copies_in_hand: int,
	adjacency_score: int,
	ready_score: int,
	character_id: String,
) -> String:
	if ready_score > 0:
		return "ready_group"
	if definition.suit == "honors" and copies_in_hand >= 2:
		return "honor_pair"
	if character_id == RESERVE_CHARACTER_ID and copies_in_hand >= 3:
		return "reserve_triplet"
	if character_id == RESERVE_CHARACTER_ID and copies_in_hand == 2:
		return "reserve_pair"
	if character_id == SEQUENCE_CHARACTER_ID and adjacency_score > 0:
		return "sequence_connector"
	if copies_in_hand >= 2:
		return "matching_group"
	if adjacency_score > 0:
		return "sequence_connector"
	return "unmatched"

static func _candidate_pattern_type(candidate) -> String:
	if candidate is Dictionary:
		return str(candidate.get("pattern_type", ""))
	return str(candidate.get("pattern_type")) if candidate is Object and _has_property(candidate, "pattern_type") else ""

static func _candidate_tiles(candidate) -> Array:
	if candidate is Dictionary:
		var tiles = candidate.get("tile_instances", [])
		return tiles if tiles is Array else []
	if candidate is Object:
		var tiles = candidate.get("tile_instances")
		return tiles if tiles is Array else []
	return []

static func _has_property(value: Object, property_name: String) -> bool:
	for property in value.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
