class_name DomainEvent
extends RefCounted

const TILE_DRAWN := "TileDrawn"
const DRAW_WALL_RESHUFFLED := "DrawWallReshuffled"
const FATIGUE_CHANGED := "FatigueChanged"
const STARVATION_ENTERED := "StarvationEntered"
const STARVATION_ESCALATED := "StarvationEscalated"
const TILE_DISCARDED := "TileDiscarded"
const TILE_MOVED := "TileMoved"
const TILE_EXHAUSTED := "TileExhausted"
const RESERVE_STORED := "ReserveStored"
const RESERVE_SWAPPED := "ReserveSwapped"
const INTEGRITY_CHANGED := "IntegrityChanged"
const INTEGRITY_BROKEN := "IntegrityBroken"
const INTEGRITY_REPAIRED := "IntegrityRepaired"
const BATTLE_RUNTIME_RESET := "BattleRuntimeReset"
const PATTERN_SETTLED := "PatternSettled"
const SETTLEMENT_TRIGGERS_RESOLVED := "SettlementTriggersResolved"
const TP_CHANGED := "TPChanged"
const STABILITY_CHANGED := "StabilityChanged"
const PRESSURE_CHANGED := "PressureChanged"
const CAPACITY_CHANGED := "CapacityChanged"
const EFFECT_APPLIED := "EffectApplied"
const EFFECT_REMOVED := "EffectRemoved"
const EFFECT_REJECTED := "EffectRejected"
const EFFECT_REFRESHED := "EffectRefreshed"
const EFFECT_STACKED := "EffectStacked"
const EFFECT_CONSUMED := "EffectConsumed"
const EFFECT_DURATION_DECREMENTED := "EffectDurationDecremented"
const EFFECT_EXPIRED := "EffectExpired"
const ENEMY_HP_CHANGED := "EnemyHpChanged"
const ENEMY_INTENT_RESOLVED := "EnemyIntentResolved"
const ENEMY_INTENT_FAILED := "EnemyIntentFailed"
const PENDING_DEFEAT := "PendingDefeat"
const PENDING_DEATH := "PendingDeath"
const BATTLE_WON := "BattleWon"
const BATTLE_LOST := "BattleLost"
const BATTLE_STARTED := "BattleStarted"
const BATTLE_OUTCOME_TRANSFERRED := "BattleOutcomeTransferred"
const BOSS_PHASE_CHANGED := "BossPhaseChanged"
const REACTION_WINDOW_OPENED := "ReactionWindowOpened"
const REACTION_WINDOW_CLOSED := "ReactionWindowClosed"
const INFINITE_LOOP_GUARD := "InfiniteLoopGuard"
const COMPLETE_HAND_SETTLED := "CompleteHandSettled"
const COMPLETE_HAND_REBUILD_STARTED := "CompleteHandRebuildStarted"
const RECOVERY_STARTED := "RecoveryStarted"
const RECOVERY_TURN_ELAPSED := "RecoveryTurnElapsed"
const RECOVERY_ENDED := "RecoveryEnded"
const CHARACTER_SELECTED := "CharacterSelected"
const CONTRACT_SELECTED := "ContractSelected"
const MAP_NODE_SELECTED := "MapNodeSelected"
const REWARD_DRAFT_CREATED := "RewardDraftCreated"
const REWARD_SELECTED := "RewardSelected"
const GOLD_CHANGED := "GoldChanged"
const REFINEMENT_TOKENS_CHANGED := "RefinementTokensChanged"
const SHOP_ENTERED := "ShopEntered"
const SHOP_OFFER_PURCHASED := "ShopOfferPurchased"
const SHOP_REFRESHED := "ShopRefreshed"
const SHOP_EXITED := "ShopExited"
const WORKSHOP_ENTERED := "WorkshopEntered"
const WORKSHOP_SERVICE_USED := "WorkshopServiceUsed"
const WORKSHOP_EXITED := "WorkshopExited"
const RUN_PHASE_CHANGED := "RunPhaseChanged"
const RUN_SUMMARY_REACHED := "RunSummaryReached"
const RUN_COMPLETED := "RunCompleted"

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
