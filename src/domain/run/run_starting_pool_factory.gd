class_name RunStartingPoolFactory
extends RefCounted

const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")

const LEGACY_TILE_COUNT := 14
const TILE_COUNT := LEGACY_TILE_COUNT # Stable v1 simulation-fixture count.
const SEQUENCE_CHARACTER_ID := "base.character.sequence"
const RESERVE_CHARACTER_ID := "base.character.reserve"
const DEFAULT_RESERVE_EXCLUDED_SUIT := "characters"
const RESERVE_SUIT_IDS := ["characters", "dots", "bamboo"]
const SUIT_IDS := ["characters", "bamboo", "dots"]
const HONOR_IDS := ["east", "south", "west", "north", "red", "green", "white"]
const SEQUENCE_TILE_COUNT := 68
const RESERVE_TILE_COUNT := 72

# The legacy biased list remains available for archived simulation fixtures and
# for the locked Harbor Reader Character. New Sequence/Reserve selections use
# the character-specific rules below.
static func tile_definition_ids(character_tile_bias_ids: Array) -> Array[String]:
	if character_tile_bias_ids.size() < 3:
		return []
	var preferred_suit := str(character_tile_bias_ids[0]).get_slice(".", 2)
	if preferred_suit == "honors":
		return [
			"base.tile.honors.east", "base.tile.honors.east", "base.tile.honors.east",
			"base.tile.honors.south", "base.tile.honors.south", "base.tile.honors.south",
			"base.tile.honors.west", "base.tile.honors.west", "base.tile.honors.west",
			"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
			"base.tile.dots.5", "base.tile.dots.5",
		]
	if preferred_suit not in SUIT_IDS:
		return []
	var other_suits: Array[String] = []
	for suit in SUIT_IDS:
		if suit != preferred_suit:
			other_suits.append(suit)
	other_suits.sort()
	var result: Array[String] = [
		str(character_tile_bias_ids[0]),
		str(character_tile_bias_ids[1]),
		str(character_tile_bias_ids[2]),
	]
	for rank in range(4, 7):
		result.append("base.tile.%s.%d" % [other_suits[0], rank])
	for rank in range(7, 10):
		result.append("base.tile.%s.%d" % [other_suits[1], rank])
	for _triplet_index in range(3):
		result.append("base.tile.honors.east")
	for _pair_index in range(2):
		result.append("base.tile.honors.white")
	return result

static func starting_tile_definition_ids(
	character_id: String,
	character_tile_bias_ids: Array,
	excluded_suit: String = "",
) -> Array[String]:
	if character_id == SEQUENCE_CHARACTER_ID:
		if not excluded_suit.is_empty():
			return []
		return _sequence_tile_definition_ids()
	if character_id == RESERVE_CHARACTER_ID:
		var resolved_excluded_suit := excluded_suit if not excluded_suit.is_empty() else DEFAULT_RESERVE_EXCLUDED_SUIT
		if resolved_excluded_suit not in RESERVE_SUIT_IDS:
			return []
		return _reserve_tile_definition_ids(resolved_excluded_suit)
	if not excluded_suit.is_empty():
		return []
	return tile_definition_ids(character_tile_bias_ids)

static func create(character_id: String, character_tile_bias_ids: Array) -> Array:
	var ordered_definition_ids := tile_definition_ids(character_tile_bias_ids)
	if ordered_definition_ids.size() != LEGACY_TILE_COUNT:
		return []
	return _create_records("simulation.start", character_id, ordered_definition_ids)

static func create_for_character(
	character_id: String,
	character_tile_bias_ids: Array,
	excluded_suit: String = "",
) -> Array:
	var ordered_definition_ids := starting_tile_definition_ids(character_id, character_tile_bias_ids, excluded_suit)
	if ordered_definition_ids.is_empty():
		return []
	return _create_records("run.start", character_id, ordered_definition_ids)

static func _sequence_tile_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for suit in SUIT_IDS:
		for rank in range(1, 10):
			var definition_id := "base.tile.%s.%d" % [suit, rank]
			result.append(definition_id)
			result.append(definition_id)
	for honor in HONOR_IDS:
		var definition_id := "base.tile.honors.%s" % honor
		result.append(definition_id)
		result.append(definition_id)
	return result

static func _reserve_tile_definition_ids(excluded_suit: String) -> Array[String]:
	var result: Array[String] = []
	for suit in SUIT_IDS:
		if suit == excluded_suit:
			continue
		for rank in range(1, 10):
			var definition_id := "base.tile.%s.%d" % [suit, rank]
			for _copy_index in range(4):
				result.append(definition_id)
	return result

static func _create_records(id_prefix: String, character_id: String, definition_ids: Array[String]) -> Array:
	var records: Array = []
	for index in range(definition_ids.size()):
		records.append(RunTileInstanceRecordScript.new(
			"%s.%s.%03d" % [id_prefix, character_id.replace(".", "_"), index + 1],
			definition_ids[index],
			"RUN",
			"RUN",
		))
	return records
