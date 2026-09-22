class_name RunPhase
extends RefCounted

const CHARACTER_SELECT := "CHARACTER_SELECT"
const CONTRACT_SELECT := "CONTRACT_SELECT"
const MAP_CHOICE := "MAP_CHOICE"
const BATTLE := "BATTLE"
const REWARD_CHOICE := "REWARD_CHOICE"
const SHOP := "SHOP"
const WORKSHOP := "WORKSHOP"
const EVENT := "EVENT"
const ELITE_REWARD := "ELITE_REWARD"
const BOSS_REWARD := "BOSS_REWARD"
const RUN_SUMMARY := "RUN_SUMMARY"
const RUN_COMPLETE := "RUN_COMPLETE"

static func all() -> Array[String]:
	return [
		CHARACTER_SELECT,
		CONTRACT_SELECT,
		MAP_CHOICE,
		BATTLE,
		REWARD_CHOICE,
		SHOP,
		WORKSHOP,
		EVENT,
		ELITE_REWARD,
		BOSS_REWARD,
		RUN_SUMMARY,
		RUN_COMPLETE,
	]

static func is_terminal(phase: String) -> bool:
	return phase == RUN_SUMMARY or phase == RUN_COMPLETE
