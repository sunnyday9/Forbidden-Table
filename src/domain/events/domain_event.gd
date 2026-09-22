class_name DomainEvent
extends RefCounted

const TILE_DRAWN := "TileDrawn"
const TILE_DISCARDED := "TileDiscarded"
const PATTERN_SETTLED := "PatternSettled"
const PRESSURE_CHANGED := "PressureChanged"
const ENEMY_HP_CHANGED := "EnemyHpChanged"
const ENEMY_INTENT_RESOLVED := "EnemyIntentResolved"
const PENDING_DEFEAT := "PendingDefeat"
const PENDING_DEATH := "PendingDeath"
const BATTLE_WON := "BattleWon"
const BATTLE_LOST := "BattleLost"

var event_type: String
var data: Dictionary

func _init(type: String, event_data: Dictionary = {}) -> void:
	event_type = type
	data = event_data.duplicate(true)

func to_dictionary() -> Dictionary:
	return {
		"event_type": event_type,
		"data": data.duplicate(true),
	}
