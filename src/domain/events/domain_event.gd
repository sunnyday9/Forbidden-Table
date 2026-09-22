class_name DomainEvent
extends RefCounted

const TILE_DRAWN := "TileDrawn"
const TILE_DISCARDED := "TileDiscarded"
const TILE_MOVED := "TileMoved"
const TILE_EXHAUSTED := "TileExhausted"
const PATTERN_SETTLED := "PatternSettled"
const TP_CHANGED := "TPChanged"
const STABILITY_CHANGED := "StabilityChanged"
const PRESSURE_CHANGED := "PressureChanged"
const CAPACITY_CHANGED := "CapacityChanged"
const EFFECT_APPLIED := "EffectApplied"
const EFFECT_REMOVED := "EffectRemoved"
const EFFECT_REJECTED := "EffectRejected"
const ENEMY_HP_CHANGED := "EnemyHpChanged"
const ENEMY_INTENT_RESOLVED := "EnemyIntentResolved"
const PENDING_DEFEAT := "PendingDefeat"
const PENDING_DEATH := "PendingDeath"
const BATTLE_WON := "BattleWon"
const BATTLE_LOST := "BattleLost"
const REACTION_WINDOW_OPENED := "ReactionWindowOpened"
const REACTION_WINDOW_CLOSED := "ReactionWindowClosed"
const INFINITE_LOOP_GUARD := "InfiniteLoopGuard"

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
