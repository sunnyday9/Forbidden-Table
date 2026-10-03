class_name RunPresentationController
extends RefCounted
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

signal presentation_changed

const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const SuspendCheckpointPolicyScript = preload("res://src/domain/run/suspend_checkpoint_policy.gd")
const RunPresentationStateScript = preload("res://src/presentation/run/run_presentation_state.gd")
const TutorialProgressScript = preload("res://src/presentation/run/tutorial_progress.gd")
const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const SelectMapNodeCommandScript = preload("res://src/domain/commands/select_map_node_command.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const EndTurnCommandScript = preload("res://src/domain/commands/end_turn_command.gd")
const SettlePatternCommandScript = preload("res://src/domain/commands/settle_pattern_command.gd")
const SettleCompleteHandCommandScript = preload("res://src/domain/commands/settle_complete_hand_command.gd")
const StoreTileCommandScript = preload("res://src/domain/commands/store_tile_command.gd")
const DiscardTileCommandScript = preload("res://src/domain/commands/discard_tile_command.gd")
const SwapReserveTileCommandScript = preload("res://src/domain/commands/swap_reserve_tile_command.gd")
const UseTechniqueCommandScript = preload("res://src/domain/commands/use_technique_command.gd")
const ChooseRewardCommandScript = preload("res://src/domain/commands/choose_reward_command.gd")
const EnterShopCommandScript = preload("res://src/domain/commands/enter_shop_command.gd")
const ExitShopCommandScript = preload("res://src/domain/commands/exit_shop_command.gd")
const RefreshShopCommandScript = preload("res://src/domain/commands/refresh_shop_command.gd")
const BuyShopOfferCommandScript = preload("res://src/domain/commands/buy_shop_offer_command.gd")
const EnterWorkshopCommandScript = preload("res://src/domain/commands/enter_workshop_command.gd")
const ExitWorkshopCommandScript = preload("res://src/domain/commands/exit_workshop_command.gd")
const UseWorkshopServiceCommandScript = preload("res://src/domain/commands/use_workshop_service_command.gd")
const EnterEventCommandScript = preload("res://src/domain/commands/enter_event_command.gd")
const ChooseEventOptionCommandScript = preload("res://src/domain/commands/choose_event_option_command.gd")
const AcknowledgeRunSummaryCommandScript = preload("res://src/domain/commands/acknowledge_run_summary_command.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const SaveCoordinatorScript = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const WorkshopStateScript = preload("res://src/domain/run/workshop_state.gd")

const ACTION_PREFIX_CHARACTER := "character:"
const ACTION_PREFIX_CONTRACT := "contract:"
const ACTION_PREFIX_MAP := "map:"
const ACTION_PREFIX_REWARD := "reward:"
const ACTION_PREFIX_SHOP_BUY := "shop:buy:"
const ACTION_PREFIX_WORKSHOP := "workshop:"
const ACTION_PREFIX_EVENT := "event:"

var domain
var state
var tutorial_progress
var meta_progress_coordinator
var suspend_store
var save_coordinator
var _command_sequence := 0
var _selected_workshop_service_id := ""
var _selected_workshop_instance_id := ""
var _last_feedback_events: Array = []
var _last_localized_event_feedback := ""
var _event_feedback_is_current := false
var _localized_feedback_key := ""
var _localized_feedback_args: Array = []

func _init(run_domain, initial_tutorial_progress = null, initial_meta_progress_coordinator = null, initial_suspend_store = null) -> void:
	assert(run_domain is RunDomainScript)
	domain = run_domain
	state = RunPresentationStateScript.new()
	tutorial_progress = initial_tutorial_progress if initial_tutorial_progress != null else TutorialProgressScript.new()
	meta_progress_coordinator = initial_meta_progress_coordinator
	suspend_store = initial_suspend_store
	save_coordinator = SaveCoordinatorScript.new()
	if meta_progress_coordinator != null and meta_progress_coordinator.state != null:
		# The application owns the trusted profile; the domain enforces its policy.
		domain.unlock_policy = meta_progress_coordinator.state
	_refresh([])

func submit(command):
	var result = domain.execute(command)
	if result != null and result.accepted and command is UseWorkshopServiceCommandScript:
		_selected_workshop_service_id = ""
		_selected_workshop_instance_id = ""
	var events: Array = result.events if result != null and result.events is Array else []
	tutorial_progress.observe(events)
	var unlock_result: Dictionary = {}
	if result != null and result.accepted and meta_progress_coordinator != null:
		unlock_result = meta_progress_coordinator.observe_run_state(domain.state)
	var suspend_feedback_key := ""
	var suspend_feedback_args: Array = []
	var stable_boundary := ""
	if result != null and result.accepted:
		var requested_boundary := _suspend_boundary_for(command)
		if not requested_boundary.is_empty():
			stable_boundary = SuspendCheckpointPolicyScript.resolve_result_boundary(
				requested_boundary,
				str(domain.state.phase),
				save_coordinator.boundary_for(domain),
			)
	if result != null and result.accepted and suspend_store != null and not stable_boundary.is_empty():
		var save_result: Dictionary = save_coordinator.save(domain, stable_boundary)
		if save_result.get("accepted", false):
			var write_result: Dictionary = suspend_store.write_snapshot(save_result.snapshot)
			if not write_result.get("accepted", false):
				suspend_feedback_key = "UI_RUN_CONTROLLER_0001"
				suspend_feedback_args = [str(write_result.get("code", "SUSPEND_WRITE_FAILED"))]
			elif write_result.has("cleanup_warning"):
				suspend_feedback_key = "UI_RUN_CONTROLLER_0002"
				suspend_feedback_args = [str(write_result.get("cleanup_warning", "SUSPEND_CLEANUP_FAILED"))]
			if write_result.get("accepted", false) and str(domain.state.phase) == RunPhaseScript.RUN_COMPLETE:
				var progression_pending: bool = unlock_result.has("persisted") and not bool(unlock_result.get("persisted", false))
				if progression_pending:
					suspend_feedback_key = "UI_RUN_CONTROLLER_0003"
					suspend_feedback_args = [str(unlock_result.get("code", "META_PROGRESS_SAVE_FAILED"))]
				else:
					var clear_result: Dictionary = suspend_store.clear()
					if not clear_result.get("accepted", false):
						suspend_feedback_key = "UI_RUN_CONTROLLER_0004"
						suspend_feedback_args = [str(clear_result.get("code", "SUSPEND_CLEAR_FAILED"))]
		elif str(save_result.get("code", "")) not in ["UNSUPPORTED_CHECKPOINT", "UNSTABLE_CHECKPOINT"]:
			suspend_feedback_key = "UI_RUN_CONTROLLER_0005"
			suspend_feedback_args = [str(save_result.get("code", "SUSPEND_SAVE_FAILED"))]
	_refresh(events)
	if unlock_result.get("changed", false) and unlock_result.get("persisted", false):
		_set_feedback(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0006"))
		presentation_changed.emit()
	elif unlock_result.has("code") and not unlock_result.get("persisted", false):
		_set_feedback(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0007"))
		presentation_changed.emit()
	if not suspend_feedback_key.is_empty():
		_set_formatted_feedback(suspend_feedback_key, suspend_feedback_args)
		presentation_changed.emit()
	return result

func _suspend_boundary_for(command) -> String:
	if command is SelectMapNodeCommandScript or command is ChooseContractCommandScript:
		return "MAP_NODE"
	if command is DrawCommandScript:
		return "DRAW_ACTION"
	if command is EndTurnCommandScript:
		return "ENEMY_INTENT_COMPLETE"
	if command is SettlePatternCommandScript or command is SettleCompleteHandCommandScript:
		return "SETTLEMENT_COMPLETE"
	if command is StoreTileCommandScript or command is DiscardTileCommandScript or command is SwapReserveTileCommandScript or command is UseTechniqueCommandScript:
		return "BATTLE_ACTION"
	if command is EnterShopCommandScript or command is BuyShopOfferCommandScript or command is RefreshShopCommandScript or command is ExitShopCommandScript:
		return "SHOP"
	if command is EnterWorkshopCommandScript or command is UseWorkshopServiceCommandScript or command is ExitWorkshopCommandScript:
		return "WORKSHOP"
	if command is EnterEventCommandScript:
		return "EVENT_CHOICE_BEFORE"
	if command is ChooseEventOptionCommandScript:
		return "EVENT_CHOICE_AFTER"
	if command is ChooseRewardCommandScript:
		return "REWARD"
	if command is AcknowledgeRunSummaryCommandScript:
		return "RUN_COMPLETE"
	return ""

func focus_next() -> String:
	var focused: String = state.focus_next()
	presentation_changed.emit()
	return focused

func focus_previous() -> String:
	var focused: String = state.focus_previous()
	presentation_changed.emit()
	return focused

func confirm(command_or_action = null):
	if command_or_action is Object and command_or_action.has_method("execute"):
		return submit(command_or_action)
	var action_id: String = str(command_or_action) if command_or_action != null else state.focused_action_id()
	if action_id.is_empty():
		_set_feedback(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0008"))
		presentation_changed.emit()
		return _rejected_presentation_input(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0009"))
	var action := _find_action(action_id)
	if not action.is_empty():
		match action.get("kind", ""):
			"WORKSHOP_SELECT_SERVICE":
				_selected_workshop_service_id = str(action.get("service_id", ""))
				_selected_workshop_instance_id = ""
				return _workshop_selection_result(LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0010") % _pretty_service_name(_selected_workshop_service_id))
			"WORKSHOP_SELECT_TARGET":
				_selected_workshop_instance_id = str(action.get("instance_id", ""))
				return _workshop_selection_result(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0011"))
			"WORKSHOP_BACK":
				return _step_back_workshop_selection()
	var command = _command_for_action(action_id)
	if command == null:
		return _rejected_presentation_input(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0012"))
	return submit(command)

func cancel() -> bool:
	state.clear_details()
	_set_feedback(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0073"))
	presentation_changed.emit()
	return true

func back():
	if state.phase == RunPhaseScript.SHOP:
		return submit(ExitShopCommandScript.new(_next_command_id("shop.back")))
	if state.phase == RunPhaseScript.WORKSHOP:
		if not _selected_workshop_service_id.is_empty():
			return _step_back_workshop_selection()
		return submit(ExitWorkshopCommandScript.new(_next_command_id("workshop.back")))
	return cancel()

func details(action_id: String = "") -> Dictionary:
	var selected_id: String = action_id if not action_id.is_empty() else state.focused_action_id()
	for action in _action_descriptors():
		if action.get("id", "") == selected_id:
			state.details_action_id = selected_id
			state.details_payload = action.duplicate(true)
			presentation_changed.emit()
			return state.details_payload.duplicate(true)
	_set_feedback(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0013"))
	presentation_changed.emit()
	return {}

func set_mode(mode: String) -> bool:
	var accepted: bool = state.set_mode(mode)
	if not accepted:
		_set_feedback(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0014"))
	presentation_changed.emit()
	return accepted

func refresh_localized_presentation() -> void:
	if not _localized_feedback_key.is_empty():
		state.feedback = LocalizationCatalogScript.format(_localized_feedback_key, _localized_feedback_args)
	elif _event_feedback_is_current and not _last_feedback_events.is_empty():
		_last_localized_event_feedback = _feedback_for_events(_last_feedback_events)
		state.feedback = _last_localized_event_feedback
	else:
		state.feedback = LocalizationCatalogScript.retranslate_exact_text(state.feedback)
	_refresh([])

func snapshot() -> Dictionary:
	return state.to_dictionary()

func action_descriptors() -> Array:
	return _action_descriptors().duplicate(true)

func _refresh(events: Array) -> void:
	var previous_focus: String = state.focused_action_id()
	var next_phase := str(domain.state.phase)
	if state.phase == RunPhaseScript.WORKSHOP and next_phase != RunPhaseScript.WORKSHOP:
		_selected_workshop_service_id = ""
		_selected_workshop_instance_id = ""
	state.phase = next_phase
	state.screen = "run.%s" % state.phase.to_lower()
	state.authoritative_snapshot = domain.checkpoint().duplicate(true)
	state.last_domain_event_types = []
	for event in events:
		if event != null:
			state.last_domain_event_types.append(str(event.event_type))
	state.set_focus_actions(_action_ids(), previous_focus)
	if not events.is_empty():
		_localized_feedback_key = ""
		_localized_feedback_args.clear()
		_last_feedback_events = events.duplicate()
		_last_localized_event_feedback = _feedback_for_events(_last_feedback_events)
		_event_feedback_is_current = true
		state.feedback = _last_localized_event_feedback
	presentation_changed.emit()

func _action_descriptors() -> Array:
	var phase := str(domain.state.phase)
	match phase:
		RunPhaseScript.CHARACTER_SELECT:
			return _character_actions()
		RunPhaseScript.CONTRACT_SELECT:
			return _contract_actions()
		RunPhaseScript.MAP_CHOICE:
			return _map_actions()
		RunPhaseScript.BATTLE:
			return _battle_actions()
		RunPhaseScript.REWARD_CHOICE, RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD:
			return _reward_actions()
		RunPhaseScript.SHOP:
			return _shop_actions()
		RunPhaseScript.WORKSHOP:
			return _workshop_actions()
		RunPhaseScript.EVENT:
			return _event_actions()
		RunPhaseScript.RUN_SUMMARY:
			return [{"id": "run.summary.acknowledge", "kind": "RUN_SUMMARY", "details": domain.state.terminal_summary.to_dictionary()}]
	return []

func _action_ids() -> Array:
	var ids: Array = []
	for action in _action_descriptors():
		ids.append(str(action.get("id", "")))
	return ids

func _character_actions() -> Array:
	return _typed_content_actions(CharacterDefinitionScript, ACTION_PREFIX_CHARACTER, "CHARACTER")

func _contract_actions() -> Array:
	return _typed_content_actions(ContractDefinitionScript, ACTION_PREFIX_CONTRACT, "CONTRACT")

func _typed_content_actions(definition_script: Script, prefix: String, kind: String) -> Array:
	var actions: Array = []
	for definition in domain.content_registry.enumerate():
		if definition.get_script() == definition_script:
			if meta_progress_coordinator != null and not meta_progress_coordinator.is_unlocked(kind, definition.content_id):
				continue
			var details := {"content_id": definition.content_id}
			if definition is ContractDefinitionScript:
				details = _contract_action_details(definition)
			actions.append({"id": prefix + definition.content_id, "kind": kind, "target_id": definition.content_id, "details": details})
	return actions

func _contract_action_details(definition: ContractDefinitionScript) -> Dictionary:
	var contract_name := LocalizationCatalogScript.content_text(str(definition.content_id))
	var yaku_signal: Variant = definition.reward.get("yaku_signal", "")
	return {
		"content_id": definition.content_id,
		"contract_id": definition.content_id,
		"name": contract_name,
		"tradeoff_family": definition.tradeoff_family,
		"risk": definition.risk.duplicate(true),
		"reward": definition.reward.duplicate(true),
		"build_bias": definition.build_bias.duplicate(true),
		"risk_summary": _contract_effect_summary(definition.risk, "risk"),
		"reward_summary": _contract_effect_summary(definition.reward, "reward"),
		"build_bias_summary": _contract_build_bias_summary(definition.build_bias),
		"yaku_signal": yaku_signal,
		"yaku_signal_summary": _contract_yaku_signal_summary(yaku_signal),
	}

func _contract_effect_summary(values: Dictionary, category: String) -> String:
	var entries := PackedStringArray()
	var keys: Array = values.keys()
	keys.sort()
	for key in keys:
		var field := str(key)
		var value: Variant = values[key]
		if category == "risk" and field == "visible":
			continue
		if category == "reward" and field == "yaku_signal":
			continue
		var summary := _contract_effect_entry(field, value, category)
		if not summary.is_empty():
			entries.append(summary)
	if entries.is_empty():
		return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0015") % category
	return "; ".join(entries)

func _contract_effect_entry(field: String, value: Variant, category: String) -> String:
	if category == "risk":
		match field:
			"pressure_per_battle": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0016") % str(value)
			"initial_pressure_per_battle": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0017") % str(value)
			"normal_reward_off_suit_choice_cap":
				return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0018") if int(value) == 0 else LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0019") % str(value)
			"elite_skip_gold_penalty": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0020") % str(value)
			"workshop_refinement_gold_surcharge": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0021") % str(value)
			"off_suit_pool_weight": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0022") % str(value)
			"composition_cost": return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0023") if bool(value) else ""
			"gold": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0024") % str(value)
			"route_cost": return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0025") if bool(value) else ""
	else:
		match field:
			"starting_tp_per_battle": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0026") % str(value)
			"refinement_tokens_on_elite_skip": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0027") % _counted_name(value, LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0028"), LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0029"))
			"reward_tile_suit_bias": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0030") % _pretty_service_name(str(value))
			"tp": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0031") % str(value)
			"tempo": return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0032") if bool(value) else ""
			"starting_bias": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0033") % _pretty_service_name(str(value))
			"refinement_tokens": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0034") % _counted_name(value, LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0035"), LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0036"))
			"map_opportunity": return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0037") if bool(value) else ""
			"refinement_tokens_on_contract_selection": return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0038") % _counted_name(value, LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0039"), LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0040"))
			"extra_modified_tile_choice": return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0041") if bool(value) else ""
	return _contract_generic_effect_entry(field, value)

func _contract_generic_effect_entry(field: String, value: Variant) -> String:
	var label := _pretty_service_name(field)
	if typeof(value) == TYPE_BOOL:
		return label if bool(value) else ""
	if value is Array:
		var readable_values := PackedStringArray()
		for item in value:
			readable_values.append(_pretty_service_name(str(item)))
		return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0042") % [label, ", ".join(readable_values)]
	return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0043") % [label, str(value)]

func _counted_name(value: Variant, singular: String, plural: String) -> String:
	var count := int(value)
	return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0044") % [count, singular if count == 1 else plural]

func _contract_build_bias_summary(build_bias: Dictionary) -> String:
	var entries := PackedStringArray()
	var path := str(build_bias.get("path", ""))
	if not path.is_empty():
		entries.append(LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0045") % _pretty_service_name(path))
	var flexibility := str(build_bias.get("flexibility", ""))
	if not flexibility.is_empty():
		entries.append(LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0046") % _pretty_service_name(flexibility))
	var preferred_tile_ids: Variant = build_bias.get("preferred_tile_ids", [])
	if preferred_tile_ids is Array and not preferred_tile_ids.is_empty():
		var preferred_tiles := PackedStringArray()
		for tile_id in preferred_tile_ids:
			preferred_tiles.append(_contract_preferred_tile_name(str(tile_id)))
		entries.append(LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0047") % ", ".join(preferred_tiles))
	return "; ".join(entries) if not entries.is_empty() else LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0048")

func _contract_preferred_tile_name(tile_id: String) -> String:
	var definition = domain.content_registry.resolve(tile_id)
	if definition is TileDefinitionScript:
		if definition.suit == "honors":
			return _pretty_service_name(tile_id.get_slice(".", tile_id.get_slice_count(".") - 1))
		return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0049") % [_pretty_service_name(definition.suit), int(definition.rank)]
	return _pretty_service_name(tile_id.get_slice(".", tile_id.get_slice_count(".") - 1))

func _contract_yaku_signal_summary(signal_value: Variant) -> String:
	if typeof(signal_value) == TYPE_STRING and not str(signal_value).is_empty():
		return _pretty_service_name(str(signal_value))
	if typeof(signal_value) == TYPE_BOOL and bool(signal_value):
		return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0050")
	return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0051")

func _map_actions() -> Array:
	var actions: Array = []
	var map_state = domain.state.map_state
	var definition = domain.map_definition
	var current = definition.node_definition(map_state.current_node_id)
	for node_id in map_state.selectable_node_ids(definition):
		var node = definition.node_definition(node_id)
		actions.append({
			"id": ACTION_PREFIX_MAP + node_id,
			"kind": "MAP_NODE",
			"target_id": node_id,
			"node_kind": node.node_kind,
			"payload_id": map_state.visible_payload_id(node_id),
		})
	if current != null and current.node_kind == "SHOP":
		actions.append({"id": "run.enter.shop", "kind": "ENTER_SHOP", "target_id": map_state.current_node_id})
	if current != null and current.node_kind == "WORKSHOP":
		actions.append({"id": "run.enter.workshop", "kind": "ENTER_WORKSHOP", "target_id": map_state.current_node_id})
	if current != null and current.node_kind == "EVENT":
		actions.append({"id": "run.enter.event", "kind": "ENTER_EVENT", "target_id": map_state.current_node_id})
	return actions

func _battle_actions() -> Array:
	var actions: Array = [
		{"id": "battle.draw", "kind": "DRAW"},
		{"id": "battle.end_turn", "kind": "END_TURN"},
	]
	if domain.current_battle == null:
		return actions
	if domain.current_battle.can_settle():
		for candidate in domain.current_battle.settlement_window.candidates():
			var instance_ids: Array[String] = []
			var labels: Array[String] = []
			for tile_instance in candidate.tile_instances:
				instance_ids.append(str(tile_instance.instance_id))
				var definition = domain.content_registry.resolve(str(tile_instance.definition_id))
				labels.append(
					LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0052") % [_pretty_service_name(str(definition.suit)), int(definition.rank)]
					if definition is TileDefinitionScript
					else _pretty_service_name(str(tile_instance.definition_id))
				)
			var candidate_id := str(candidate.candidate_id)
			actions.append({
				"id": "battle.settle:" + candidate_id,
				"kind": "PARTIAL_SETTLEMENT",
				"target_id": candidate_id,
				"details": {
					"candidate_id": candidate_id,
					"pattern_type": str(candidate.pattern_type),
					"instance_ids": instance_ids,
					"labels": labels,
				},
			})
	var combat_state = domain.current_battle.combat_state
	var can_manipulate_tiles: bool = combat_state.draw_actions_used_this_turn > 0 and not combat_state.tile_manipulation_used_this_draw
	if can_manipulate_tiles:
		for tile in domain.current_battle.zones.contents(TileZoneScript.HAND):
			var tile_details := {"tile_id": tile.definition_id, "instance_id": tile.instance_id}
			if domain.current_battle.validate_store_tile(str(tile.instance_id)).is_valid():
				actions.append({"id": "battle.store:" + str(tile.instance_id), "kind": "RESERVE", "target_id": str(tile.instance_id), "details": tile_details.duplicate(true)})
			if domain.current_battle.validate_discard_tile(str(tile.instance_id)).is_valid():
				actions.append({"id": "battle.discard:" + str(tile.instance_id), "kind": "DISCARD", "target_id": str(tile.instance_id), "details": tile_details.duplicate(true)})
		for hand_tile in domain.current_battle.zones.contents(TileZoneScript.HAND):
			for reserve_tile in domain.current_battle.zones.contents(TileZoneScript.RESERVE):
				if not domain.current_battle.validate_swap_reserve_tiles(str(hand_tile.instance_id), str(reserve_tile.instance_id)).is_valid():
					continue
				actions.append({
					"id": "battle.swap:%s:%s" % [str(hand_tile.instance_id), str(reserve_tile.instance_id)],
					"kind": "RESERVE_SWAP",
					"target_id": str(hand_tile.instance_id),
					"hand_instance_id": str(hand_tile.instance_id),
					"reserve_instance_id": str(reserve_tile.instance_id),
					"details": {
						"hand_tile_id": str(hand_tile.definition_id),
						"reserve_tile_id": str(reserve_tile.definition_id),
					},
				})
	actions.append_array(_battle_technique_actions(domain.current_battle))
	if domain.current_battle.can_complete_hand():
		for interpretation in domain.current_battle.complete_hand_interpretations():
			actions.append({"id": "battle.complete:" + str(interpretation.interpretation_id), "kind": "COMPLETE_HAND", "target_id": str(interpretation.interpretation_id), "details": interpretation.to_dictionary()})
	return actions

func _battle_technique_actions(battle) -> Array:
	var actions: Array = []
	if battle == null or battle.context == null or battle.context.content_registry == null:
		return actions
	var build_state: Dictionary = battle.context.build_state if battle.context.build_state is Dictionary else {}
	var owned_technique_ids: Variant = build_state.get("run_technique_ids", [])
	if not owned_technique_ids is Array:
		return actions
	var sorted_ids: Array[String] = []
	for technique_id in owned_technique_ids:
		var id := str(technique_id)
		if not id.is_empty() and not sorted_ids.has(id):
			sorted_ids.append(id)
	var core_technique_id := str(build_state.get("character_core_technique_id", ""))
	if not core_technique_id.is_empty() and not sorted_ids.has(core_technique_id):
		sorted_ids.append(core_technique_id)
	sorted_ids.sort()
	for technique_id in sorted_ids:
		var definition = battle.context.content_registry.resolve(technique_id)
		if definition == null or definition.get_script() != TechniqueDefinitionScript:
			continue
		var validation = battle.validate_use_technique(technique_id)
		if validation == null or not validation.is_valid():
			continue
		var uses_per_turn: int = 1 if definition.technique_kind == TechniqueDefinitionScript.CORE else -1
		var uses_remaining: int = 1 if uses_per_turn > 0 else -1
		if definition.technique_kind == TechniqueDefinitionScript.CORE and battle.combat_state.core_technique_used_this_turn:
			uses_remaining = 0
		actions.append({
			"id": "battle.technique:%s" % technique_id,
			"kind": "TECHNIQUE",
			"target_id": technique_id,
			"details": {
				"technique_kind": definition.technique_kind,
				"tp_cost": definition.tp_cost,
				"effect_count": definition.effects.size(),
				"uses_per_turn": uses_per_turn,
				"uses_remaining_this_turn": uses_remaining,
			},
		})
	return actions

func _reward_actions() -> Array:
	var actions: Array = []
	if domain.state.phase == RunPhaseScript.REWARD_CHOICE and domain.state.reward_draft != null:
		for option in domain.state.reward_draft.options:
			actions.append({"id": ACTION_PREFIX_REWARD + option.option_id, "kind": "REWARD", "target_id": option.option_id, "draft_id": domain.state.reward_draft.draft_id, "details": option.to_dictionary()})
	elif domain.state.phase == RunPhaseScript.ELITE_REWARD and domain.state.reward_draft != null:
		for option in domain.state.reward_draft.options:
			actions.append({"id": ACTION_PREFIX_REWARD + option.option_id, "kind": "ELITE_REWARD", "target_id": option.option_id, "draft_id": domain.state.reward_draft.draft_id, "details": option.to_dictionary()})
	elif domain.state.phase == RunPhaseScript.BOSS_REWARD and domain.state.reward_draft != null:
		for option in domain.state.reward_draft.options:
			var details: Dictionary = option.to_dictionary()
			var definition = domain.content_registry.resolve(option.content_id)
			if definition != null:
				details["rule_key"] = str(definition.get("rule_key"))
				details["permission_level"] = int(definition.get("permission_level"))
			actions.append({
				"id": ACTION_PREFIX_REWARD + option.option_id,
				"kind": "BOSS_REWARD",
				"target_id": option.option_id,
				"draft_id": domain.state.reward_draft.draft_id,
				"content_id": option.content_id,
				"details": details,
			})
	return actions

func _shop_actions() -> Array:
	var actions: Array = []
	for offer in domain.state.shop_state.offers:
		actions.append({"id": ACTION_PREFIX_SHOP_BUY + offer.offer_id, "kind": "SHOP_OFFER", "target_id": offer.offer_id, "entry_id": domain.state.shop_state.entry_id, "details": offer.to_dictionary()})
	if domain.state.shop_state.refreshes_remaining > 0:
		actions.append({"id": "shop.refresh", "kind": "SHOP_REFRESH", "entry_id": domain.state.shop_state.entry_id})
	actions.append({"id": "shop.back", "kind": "SHOP_EXIT"})
	return actions

func _workshop_actions() -> Array:
	var actions: Array = []
	var workshop_state = domain.state.workshop_state
	if _selected_workshop_service_id.is_empty():
		for service_id in workshop_state.available_service_ids:
			if not workshop_state.is_service_available(service_id):
				continue
			if service_id == WorkshopStateScript.MODIFIER:
				_append_workshop_service_choice(actions, UseWorkshopServiceCommandScript.ADD_MODIFIER)
				_append_workshop_service_choice(actions, UseWorkshopServiceCommandScript.REPLACE_MODIFIER)
			else:
				_append_workshop_service_choice(actions, service_id)
		actions.append({"id": "workshop.back", "kind": "WORKSHOP_EXIT"})
		return actions
	if _selected_workshop_instance_id.is_empty():
		if _requires_workshop_value(_selected_workshop_service_id):
			for tile_instance in domain.state.tile_pool.tile_instances:
				if _workshop_target_has_legal_choice(_selected_workshop_service_id, tile_instance):
					_append_workshop_target_choice(actions, _selected_workshop_service_id, tile_instance)
		else:
			for tile_instance in domain.state.tile_pool.tile_instances:
				_append_workshop_command_action(actions, _selected_workshop_service_id, tile_instance)
		_append_workshop_back_action(actions)
		return actions
	_append_workshop_value_choices(actions, _selected_workshop_service_id, _selected_workshop_instance_id)
	_append_workshop_back_action(actions)
	return actions

func _append_workshop_service_choice(actions: Array, service_id: String) -> void:
	if not _workshop_service_has_legal_choice(service_id):
		return
	actions.append({
		"id": "%sservice:%s" % [ACTION_PREFIX_WORKSHOP, service_id],
		"kind": "WORKSHOP_SELECT_SERVICE",
		"target_id": service_id,
		"service_id": service_id,
		"details": {"service_id": service_id},
	})

func _workshop_service_has_legal_choice(service_id: String) -> bool:
	for tile_instance in domain.state.tile_pool.tile_instances:
		if _requires_workshop_value(service_id):
			if _workshop_target_has_legal_choice(service_id, tile_instance):
				return true
		elif _workshop_action_is_valid(service_id, tile_instance.instance_id):
			return true
	return false

func _requires_workshop_value(service_id: String) -> bool:
	return service_id in [
		UseWorkshopServiceCommandScript.TRANSFORM,
		UseWorkshopServiceCommandScript.ADD_MODIFIER,
		UseWorkshopServiceCommandScript.REPLACE_MODIFIER,
	]

func _workshop_target_has_legal_choice(service_id: String, tile_instance) -> bool:
	if service_id == UseWorkshopServiceCommandScript.TRANSFORM:
		for definition in domain.content_registry.enumerate():
			if definition is TileDefinitionScript and definition.content_id != tile_instance.definition_id:
				if _workshop_action_is_valid(service_id, tile_instance.instance_id, definition.content_id):
					return true
		return false
	for definition in domain.content_registry.enumerate():
		if not definition is TileModifierDefinitionScript:
			continue
		if _workshop_action_is_valid(service_id, tile_instance.instance_id, "", definition.content_id, service_id == UseWorkshopServiceCommandScript.REPLACE_MODIFIER):
			return true
	return false

func _workshop_action_is_valid(service_id: String, instance_id: String, value_id: String = "", modifier_id: String = "", replace_existing: bool = false) -> bool:
	var validation = domain.validate_use_workshop_service(service_id, instance_id, value_id, modifier_id, replace_existing)
	return validation != null and validation.is_valid()

func _append_workshop_target_choice(actions: Array, service_id: String, tile_instance) -> void:
	actions.append({
		"id": "%starget:%s:%s" % [ACTION_PREFIX_WORKSHOP, service_id, tile_instance.instance_id],
		"kind": "WORKSHOP_SELECT_TARGET",
		"target_id": str(tile_instance.instance_id),
		"service_id": service_id,
		"instance_id": str(tile_instance.instance_id),
		"details": _workshop_details(service_id, tile_instance),
	})

func _append_workshop_value_choices(actions: Array, service_id: String, instance_id: String) -> void:
	var tile_instance = _workshop_tile_instance(instance_id)
	if tile_instance == null:
		return
	if service_id == UseWorkshopServiceCommandScript.TRANSFORM:
		for definition in domain.content_registry.enumerate():
			if definition is TileDefinitionScript and definition.content_id != tile_instance.definition_id:
				_append_workshop_command_action(actions, service_id, tile_instance, definition.content_id)
		return
	for definition in domain.content_registry.enumerate():
		if definition is TileModifierDefinitionScript:
			_append_workshop_command_action(
				actions,
				service_id,
				tile_instance,
				"",
				definition.content_id,
				service_id == UseWorkshopServiceCommandScript.REPLACE_MODIFIER,
			)

func _append_workshop_command_action(
	actions: Array,
	service_id: String,
	tile_instance,
	value_id: String = "",
	modifier_id: String = "",
	replace_existing: bool = false,
) -> void:
	var validation = domain.validate_use_workshop_service(
		service_id,
		str(tile_instance.instance_id),
		value_id,
		modifier_id,
		replace_existing,
	)
	if validation == null or not validation.is_valid():
		return
	var action_id := "%scommand:%s:%s" % [ACTION_PREFIX_WORKSHOP, service_id, str(tile_instance.instance_id)]
	if not value_id.is_empty():
		action_id += ":" + value_id
	elif not modifier_id.is_empty():
		action_id += ":" + modifier_id
	actions.append({
		"id": action_id,
		"kind": "WORKSHOP_SERVICE",
		"target_id": service_id,
		"service_id": service_id,
		"instance_id": str(tile_instance.instance_id),
		"value_id": value_id,
		"modifier_id": modifier_id,
		"replace_existing": replace_existing,
		"entry_id": domain.state.workshop_state.entry_id,
		"details": _workshop_details(service_id, tile_instance, value_id, modifier_id, replace_existing, validation),
	})

func _workshop_details(service_id: String, tile_instance, value_id: String = "", modifier_id: String = "", replace_existing: bool = false, validation = null) -> Dictionary:
	var result := {
		"service_id": service_id,
		"tile_instance_id": str(tile_instance.instance_id),
		"tile_definition_id": str(tile_instance.definition_id),
		"value_id": value_id,
		"modifier_id": modifier_id,
		"existing_modifier_ids": domain.state.build_ownership.persistent_tile_modifier_state.get(tile_instance.instance_id, []).duplicate(),
		"replace_existing": replace_existing,
	}
	if validation != null:
		result["price"] = int(validation.details.get("price", 0))
	return result

func _append_workshop_back_action(actions: Array) -> void:
	actions.append({"id": "workshop:selection:back", "kind": "WORKSHOP_BACK"})

func _workshop_tile_instance(instance_id: String):
	for tile_instance in domain.state.tile_pool.tile_instances:
		if tile_instance.instance_id == instance_id:
			return tile_instance
	return null

func _workshop_selection_result(message: String) -> Dictionary:
	_set_feedback(message)
	_refresh([])
	return {"accepted": true, "status": "PRESENTATION_SELECTION", "events": []}

func _step_back_workshop_selection() -> Dictionary:
	if not _selected_workshop_instance_id.is_empty():
		_selected_workshop_instance_id = ""
		return _workshop_selection_result(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0053"))
	_selected_workshop_service_id = ""
	return _workshop_selection_result(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0054"))

func _pretty_service_name(service_id: String) -> String:
	if "." in service_id:
		return LocalizationCatalogScript.content_text(service_id)
	return LocalizationCatalogScript.word_text(service_id)

func _event_actions() -> Array:
	var actions: Array = []
	var event_id: String = domain.state.event_state.event_id
	var entry_id: String = domain.state.event_state.entry_id
	for option_id in domain.state.event_state.legal_choice_ids():
		var validation: RefCounted = domain.validate_choose_event_option(event_id, entry_id, option_id)
		if validation == null or not validation.is_valid():
			continue
		actions.append({"id": ACTION_PREFIX_EVENT + option_id, "kind": "EVENT_OPTION", "target_id": option_id, "event_id": event_id, "entry_id": entry_id})
	return actions

func _command_for_action(action_id: String):
	var action = _find_action(action_id)
	if action.is_empty():
		return null
	var command_id := _next_command_id("presentation.%s" % action_id.replace(":", "."))
	var target_id := str(action.get("target_id", ""))
	match action.get("kind", ""):
		"CHARACTER": return ChooseCharacterCommandScript.new(command_id, target_id)
		"CONTRACT": return ChooseContractCommandScript.new(command_id, target_id)
		"MAP_NODE": return SelectMapNodeCommandScript.new(command_id, target_id)
		"DRAW": return DrawCommandScript.new(command_id)
		"END_TURN": return EndTurnCommandScript.new(command_id)
		"PARTIAL_SETTLEMENT": return SettlePatternCommandScript.new(command_id, [], "", "", false, target_id)
		"COMPLETE_HAND": return SettleCompleteHandCommandScript.new(command_id, target_id)
		"RESERVE": return StoreTileCommandScript.new(command_id, target_id)
		"DISCARD": return DiscardTileCommandScript.new(command_id, target_id)
		"RESERVE_SWAP": return SwapReserveTileCommandScript.new(command_id, str(action.get("hand_instance_id", "")), str(action.get("reserve_instance_id", "")))
		"TECHNIQUE": return UseTechniqueCommandScript.new(command_id, target_id)
		"REWARD", "ELITE_REWARD", "BOSS_REWARD": return ChooseRewardCommandScript.new(command_id, target_id if action.get("kind", "") != "REWARD" else target_id, str(action.get("draft_id", "")))
		"ENTER_SHOP": return EnterShopCommandScript.new(command_id)
		"SHOP_OFFER": return BuyShopOfferCommandScript.new(command_id, target_id, str(action.get("entry_id", "")))
		"SHOP_REFRESH": return RefreshShopCommandScript.new(command_id, str(action.get("entry_id", "")))
		"SHOP_EXIT": return ExitShopCommandScript.new(command_id)
		"ENTER_WORKSHOP": return EnterWorkshopCommandScript.new(command_id)
		"WORKSHOP_SERVICE": return _workshop_command(command_id, action)
		"WORKSHOP_EXIT": return ExitWorkshopCommandScript.new(command_id)
		"ENTER_EVENT": return EnterEventCommandScript.new(command_id)
		"EVENT_OPTION": return ChooseEventOptionCommandScript.new(command_id, target_id, str(action.get("event_id", "")), str(action.get("entry_id", "")))
		"RUN_SUMMARY": return AcknowledgeRunSummaryCommandScript.new(command_id)
	return null

func _workshop_command(command_id: String, action: Dictionary):
	return UseWorkshopServiceCommandScript.new(
		command_id,
		str(action.get("service_id", "")),
		str(action.get("instance_id", "")),
		str(action.get("value_id", "")),
		str(action.get("modifier_id", "")),
		bool(action.get("replace_existing", false)),
	)

func _find_action(action_id: String) -> Dictionary:
	for action in _action_descriptors():
		if str(action.get("id", "")) == action_id:
			return action
	return {}

func _next_command_id(prefix: String) -> String:
	_command_sequence += 1
	return "%s.%d" % [prefix, _command_sequence]

func _rejected_presentation_input(message: String):
	var result = domain.execute(null)
	_set_feedback(message)
	_refresh([])
	return result

func _set_feedback(message: String) -> void:
	state.feedback = message
	_event_feedback_is_current = false
	_localized_feedback_key = ""
	_localized_feedback_args.clear()

func _set_formatted_feedback(key: String, values: Array) -> void:
	_localized_feedback_key = key
	_localized_feedback_args = values.duplicate(true)
	state.feedback = LocalizationCatalogScript.format(key, _localized_feedback_args)
	_event_feedback_is_current = false

func _feedback_for_events(events: Array) -> String:
	var critical_feedback: Array[String] = []
	for event in events:
		if event == null:
			continue
		match event.event_type:
			DomainEventScript.COMPLETE_HAND_SETTLED:
				critical_feedback.append(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0075"))
			DomainEventScript.BOSS_PHASE_CHANGED:
				critical_feedback.append(LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0076") % (int(event.data.get("phase_index", 0)) + 1))
			DomainEventScript.BATTLE_WON:
				critical_feedback.append(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0077"))
			DomainEventScript.RUN_SUMMARY_REACHED:
				if str(event.data.get("outcome", "")) == "VICTORY":
					critical_feedback.append(LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0077"))
	if not critical_feedback.is_empty():
		return " ".join(PackedStringArray(critical_feedback))

	var last_reaction_used = null
	var last_reaction_skipped = null
	for event in events:
		if event == null:
			continue
		if event.event_type == DomainEventScript.TECHNIQUE_USED and (
			not str(event.data.get("reaction_trigger_id", "")).is_empty()
			or not str(event.data.get("reaction_trigger_label", "")).is_empty()
		):
			last_reaction_used = event
		elif event.event_type == DomainEventScript.TECHNIQUE_REACTION_SKIPPED:
			last_reaction_skipped = event
	if last_reaction_used != null:
		var used_trigger_label := _reaction_trigger_label(str(last_reaction_used.data.get("reaction_trigger_id", "")))
		if used_trigger_label.is_empty():
			used_trigger_label = LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0056")
		return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0055") % [
			_technique_label(str(last_reaction_used.data.get("technique_id", ""))),
			used_trigger_label,
		]
	if last_reaction_skipped != null:
		var skipped_trigger_label := _reaction_trigger_label(str(last_reaction_skipped.data.get("reaction_trigger_id", "")))
		if skipped_trigger_label.is_empty():
			skipped_trigger_label = LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0058")
		return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0057") % [
			_technique_label(str(last_reaction_skipped.data.get("technique_id", ""))),
			skipped_trigger_label,
			LocalizationCatalogScript.reaction_reason_text(str(last_reaction_skipped.data.get("reason", ""))),
		]
	var last_event = events[events.size() - 1]
	match last_event.event_type:
		DomainEventScript.CHARACTER_SELECTED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0059")
		DomainEventScript.CONTRACT_SELECTED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0060")
		DomainEventScript.MAP_NODE_SELECTED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0061")
		DomainEventScript.BATTLE_STARTED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0062")
		DomainEventScript.REWARD_DRAFT_CREATED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0063")
		DomainEventScript.SHOP_ENTERED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0064")
		DomainEventScript.WORKSHOP_ENTERED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0065")
		DomainEventScript.EVENT_ENTERED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0066")
		DomainEventScript.RUN_SUMMARY_REACHED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0067")
		DomainEventScript.CHARACTER_PASSIVE_TRIGGERED:
			var passive = domain.content_registry.resolve(str(last_event.data.get("passive_id", "")))
			return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0068") % [LocalizationCatalogScript.display_text(str(passive.get("display_name"))), LocalizationCatalogScript.display_text(str(passive.get("description")))] if passive != null else LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0069")
		DomainEventScript.TILE_DISCARDED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0070")
		DomainEventScript.TECHNIQUE_USED:
			return LocalizationCatalogScript.template("UI_RUN_CONTROLLER_0071") % _technique_label(str(last_event.data.get("technique_id", "")))
		DomainEventScript.RUN_PHASE_CHANGED: return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0072")
	return LocalizationCatalogScript.text("UI_RUN_CONTROLLER_0074")

func _technique_label(technique_id: String) -> String:
	return LocalizationCatalogScript.content_text(technique_id)

func _reaction_trigger_label(trigger_id: String) -> String:
	return LocalizationCatalogScript.display_text(TechniqueDefinitionScript.reaction_trigger_label(trigger_id)) if not trigger_id.is_empty() else ""
