class_name ReplayCommandFactory
extends RefCounted

const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const EndTurnCommandScript = preload("res://src/domain/commands/end_turn_command.gd")
const ResolveEnemyIntentCommandScript = preload("res://src/domain/commands/resolve_enemy_intent_command.gd")
const SettlePatternCommandScript = preload("res://src/domain/commands/settle_pattern_command.gd")
const SettleCompleteHandCommandScript = preload("res://src/domain/commands/settle_complete_hand_command.gd")
const StoreTileCommandScript = preload("res://src/domain/commands/store_tile_command.gd")
const SwapReserveTileCommandScript = preload("res://src/domain/commands/swap_reserve_tile_command.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const SelectMapNodeCommandScript = preload("res://src/domain/commands/select_map_node_command.gd")
const ChooseRewardCommandScript = preload("res://src/domain/commands/choose_reward_command.gd")
const BuyShopOfferCommandScript = preload("res://src/domain/commands/buy_shop_offer_command.gd")
const RefreshShopCommandScript = preload("res://src/domain/commands/refresh_shop_command.gd")
const UseWorkshopServiceCommandScript = preload("res://src/domain/commands/use_workshop_service_command.gd")
const EnterEventCommandScript = preload("res://src/domain/commands/enter_event_command.gd")
const ChooseEventOptionCommandScript = preload("res://src/domain/commands/choose_event_option_command.gd")
const EnterShopCommandScript = preload("res://src/domain/commands/enter_shop_command.gd")
const ExitShopCommandScript = preload("res://src/domain/commands/exit_shop_command.gd")
const EnterWorkshopCommandScript = preload("res://src/domain/commands/enter_workshop_command.gd")
const ExitWorkshopCommandScript = preload("res://src/domain/commands/exit_workshop_command.gd")
const AcknowledgeRunSummaryCommandScript = preload("res://src/domain/commands/acknowledge_run_summary_command.gd")

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
		"ChooseCharacter":
			return ChooseCharacterCommandScript.new(record.command_id, str(payload.get("character_id", "")), record.actor_id, record.target_id, record.preview)
		"ChooseContract":
			return ChooseContractCommandScript.new(record.command_id, str(payload.get("contract_id", "")), record.actor_id, record.target_id, record.preview)
		"SelectMapNode":
			return SelectMapNodeCommandScript.new(record.command_id, str(payload.get("node_id", "")), record.actor_id, record.target_id, record.preview)
		"ChooseReward":
			return ChooseRewardCommandScript.new(record.command_id, str(payload.get("option_id", "")), str(payload.get("draft_id", "")), record.actor_id, record.target_id, record.preview)
		"BuyShopOffer":
			return BuyShopOfferCommandScript.new(record.command_id, str(payload.get("offer_id", "")), str(payload.get("entry_id", "")), record.actor_id, record.target_id, record.preview)
		"RefreshShop":
			return RefreshShopCommandScript.new(record.command_id, str(payload.get("entry_id", "")), record.actor_id, record.target_id, record.preview)
		"UseWorkshopService":
			return UseWorkshopServiceCommandScript.new(
				record.command_id,
				str(payload.get("service_id", "")),
				str(payload.get("instance_id", "")),
				str(payload.get("value_id", "")),
				str(payload.get("modifier_id", "")),
				bool(payload.get("replace_existing", false)),
				record.actor_id,
				record.target_id,
				record.preview,
			)
		"EnterEvent":
			return EnterEventCommandScript.new(record.command_id, str(payload.get("event_id", "")), record.actor_id, record.target_id, record.preview)
		"ChooseEventOption":
			return ChooseEventOptionCommandScript.new(
				record.command_id,
				str(payload.get("option_id", "")),
				str(payload.get("event_id", "")),
				str(payload.get("entry_id", "")),
				record.actor_id,
				record.target_id,
				record.preview,
			)
		"EnterShop":
			return EnterShopCommandScript.new(record.command_id, record.actor_id, record.target_id, record.preview)
		"ExitShop":
			return ExitShopCommandScript.new(record.command_id, record.actor_id, record.target_id, record.preview)
		"EnterWorkshop":
			return EnterWorkshopCommandScript.new(record.command_id, record.actor_id, record.target_id, record.preview)
		"ExitWorkshop":
			return ExitWorkshopCommandScript.new(record.command_id, record.actor_id, record.target_id, record.preview)
		"AcknowledgeRunSummary":
			return AcknowledgeRunSummaryCommandScript.new(record.command_id, record.actor_id, record.target_id, record.preview)
	return null
