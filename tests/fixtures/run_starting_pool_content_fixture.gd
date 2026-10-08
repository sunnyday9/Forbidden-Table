extends RefCounted

const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")

static func register_character_starting_pool_tiles(registry) -> void:
	# New Sequence pools contain every traditional definition. This helper
	# supports custom test registries without duplicating existing registrations.
	for suit in ["characters", "bamboo", "dots"]:
		for rank in range(1, 10):
			var definition_id := "base.tile.%s.%d" % [suit, rank]
			if registry.resolve(definition_id) == null:
				registry.register(TileDefinitionScript.new(definition_id, suit, rank))
	for honor in ["east", "south", "west", "north", "red", "green", "white"]:
		var definition_id := "base.tile.honors.%s" % honor
		if registry.resolve(definition_id) == null:
			registry.register(TileDefinitionScript.new(definition_id, "honors", 0))

static func character_tile_pool_bias() -> Array[String]:
	return [
		"base.tile.characters.1",
		"base.tile.characters.2",
		"base.tile.characters.3",
	]
