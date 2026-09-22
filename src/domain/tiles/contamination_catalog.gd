class_name ContaminationCatalog
extends RefCounted

const ContaminationDefinitionScript = preload("res://src/domain/tiles/contamination_definition.gd")
const TileLifetimeScript = preload("res://src/domain/tiles/tile_lifetime.gd")
const TileOriginScript = preload("res://src/domain/tiles/tile_origin.gd")

static func all() -> Array:
	return [
		ContaminationDefinitionScript.new(
			"base.contamination.clutter",
			{"kind": "HAND_SPACE", "amount": 1},
			TileOriginScript.ENEMY,
			TileLifetimeScript.BATTLE,
			true,
			true,
		),
		ContaminationDefinitionScript.new(
			"base.contamination.pressure_dross",
			{"kind": "PRESSURE", "amount": 2},
			TileOriginScript.ENEMY,
			TileLifetimeScript.BATTLE,
			true,
			true,
		),
		ContaminationDefinitionScript.new(
			"base.contamination.fatigue_mold",
			{"kind": "FATIGUE", "amount": 1},
			TileOriginScript.ENEMY,
			TileLifetimeScript.BATTLE,
			false,
			true,
		),
	]

static func by_id(contamination_id: String):
	for definition in all():
		if definition.contamination_id == contamination_id:
			return definition
	return null
