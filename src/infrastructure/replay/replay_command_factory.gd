class_name ReplayCommandFactory
extends RefCounted

const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const EndTurnCommandScript = preload("res://src/domain/commands/end_turn_command.gd")
const ResolveEnemyIntentCommandScript = preload("res://src/domain/commands/resolve_enemy_intent_command.gd")
const SettlePatternCommandScript = preload("res://src/domain/commands/settle_pattern_command.gd")
const SettleCompleteHandCommandScript = preload("res://src/domain/commands/settle_complete_hand_command.gd")
const StoreTileCommandScript = preload("res://src/domain/commands/store_tile_command.gd")
const SwapReserveTileCommandScript = preload("res://src/domain/commands/swap_reserve_tile_command.gd")

static func from_record(record):
	var payload: Dictionary = record.payload
	match record.command_type:
		"Draw":
			return DrawCommandScript.new(record.command_id, record.actor_id, record.target_id, record.preview)
		"EndTurn":
			return EndTurnCommandScript.new(record.command_id, record.actor_id, record.target_id, record.preview)
		"ResolveEnemyIntent":
			return ResolveEnemyIntentCommandScript.new(record.command_id, record.actor_id, record.target_id, record.preview)
		"SettlePattern":
			return SettlePatternCommandScript.new(
				record.command_id,
				payload.get("instance_ids", []),
				record.actor_id,
				record.target_id,
				record.preview,
				str(payload.get("candidate_id", "")),
			)
		"SettleCompleteHand":
			return SettleCompleteHandCommandScript.new(
				record.command_id,
				str(payload.get("interpretation_id", "")),
				record.actor_id,
				record.target_id,
				record.preview,
			)
		"StoreTile":
			return StoreTileCommandScript.new(
				record.command_id,
				str(payload.get("instance_id", "")),
				record.actor_id,
				record.target_id,
				record.preview,
			)
		"SwapReserveTile":
			return SwapReserveTileCommandScript.new(
				record.command_id,
				str(payload.get("hand_instance_id", "")),
				str(payload.get("reserve_instance_id", "")),
				record.actor_id,
				record.target_id,
				record.preview,
			)
	return null
