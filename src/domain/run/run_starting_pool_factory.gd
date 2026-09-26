class_name RunStartingPoolFactory
extends RefCounted

const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")

const TILE_COUNT := 14

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
	if preferred_suit not in ["characters", "bamboo", "dots"]:
		return []
	var other_suits: Array[String] = []
	for suit in ["characters", "bamboo", "dots"]:
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

static func create(character_id: String, character_tile_bias_ids: Array) -> Array:
	var ordered_definition_ids := tile_definition_ids(character_tile_bias_ids)
	if ordered_definition_ids.size() != TILE_COUNT:
		return []
	var records: Array = []
	for index in range(ordered_definition_ids.size()):
		records.append(RunTileInstanceRecordScript.new(
			"simulation.start.%s.%03d" % [character_id.replace(".", "_"), index + 1],
			ordered_definition_ids[index],
			"RUN",
			"RUN",
		))
	return records
