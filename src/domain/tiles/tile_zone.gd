class_name TileZone
extends RefCounted

const TILE_POOL := "Tile Pool"
const DRAW_WALL := "Draw Wall"
const HAND := "Hand"
const DISCARD := "Discard"
const RESERVE := "Reserve"
const EXHAUST := "Exhaust"
const ALL_ZONES: Array[String] = [TILE_POOL, DRAW_WALL, HAND, DISCARD, RESERVE, EXHAUST]

static func is_valid(zone: String) -> bool:
	return ALL_ZONES.has(zone)

static func all() -> Array[String]:
	return ALL_ZONES.duplicate()
