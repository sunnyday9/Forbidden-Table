class_name TileLifetime
extends RefCounted

const UNKNOWN := "UNKNOWN"
const RUN := "RUN"
const BATTLE := "BATTLE"
const BATTLE_ONLY := BATTLE
const ACT := "ACT"
const PERMANENT := "PERMANENT"

const ALL_LIFETIMES: Array[String] = [UNKNOWN, RUN, BATTLE, ACT, PERMANENT]

static func is_valid(lifetime: String) -> bool:
	return ALL_LIFETIMES.has(lifetime)

static func is_battle_only(lifetime: String) -> bool:
	return lifetime == BATTLE
