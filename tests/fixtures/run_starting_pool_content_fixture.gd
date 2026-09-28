extends RefCounted

const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")

static func register_character_starting_pool_tiles(registry) -> void:
	# These are the unique definitions emitted by RunStartingPoolFactory for this bias.
	for tile_definition in [
		TileDefinitionScript.new("base.tile.characters.1", "characters", 1),
		TileDefinitionScript.new("base.tile.characters.2", "characters", 2),
		TileDefinitionScript.new("base.tile.characters.3", "characters", 3),
		TileDefinitionScript.new("base.tile.bamboo.4", "bamboo", 4),
		TileDefinitionScript.new("base.tile.bamboo.5", "bamboo", 5),
		TileDefinitionScript.new("base.tile.bamboo.6", "bamboo", 6),
		TileDefinitionScript.new("base.tile.dots.7", "dots", 7),
		TileDefinitionScript.new("base.tile.dots.8", "dots", 8),
		TileDefinitionScript.new("base.tile.dots.9", "dots", 9),
		TileDefinitionScript.new("base.tile.honors.east", "honors", 0),
		TileDefinitionScript.new("base.tile.honors.white", "honors", 0),
	]:
		registry.register(tile_definition)

static func character_tile_pool_bias() -> Array[String]:
	return [
		"base.tile.characters.1",
		"base.tile.characters.2",
		"base.tile.characters.3",
	]
