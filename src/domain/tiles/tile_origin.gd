class_name TileOrigin
extends RefCounted

const UNKNOWN := "UNKNOWN"
const RUN_POOL := "RUN_POOL"
const RUN := RUN_POOL
const ENEMY := "ENEMY"
const ENEMY_INJECTION := ENEMY
const PLAYER_EFFECT := "PLAYER_EFFECT"
const EFFECT := PLAYER_EFFECT
const EVENT := "EVENT"
const REWARD := "REWARD"

const ALL_ORIGINS: Array[String] = [UNKNOWN, RUN_POOL, ENEMY, PLAYER_EFFECT, EVENT, REWARD]

static func is_valid(origin: String) -> bool:
	return ALL_ORIGINS.has(origin)
