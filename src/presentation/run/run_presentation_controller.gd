class_name RunPresentationController
extends RefCounted

signal presentation_changed

const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
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
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")
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
var _command_sequence := 0
var _selected_workshop_service_id := ""
var _selected_workshop_instance_id := ""

func _init(run_domain, initial_tutorial_progress = null, initial_meta_progress_coordinator = null) -> void:
	assert(run_domain is RunDomainScript)
	domain = run_domain
	state = RunPresentationStateScript.new()
	tutorial_progress = initial_tutorial_progress if initial_tutorial_progress != null else TutorialProgressScript.new()
	meta_progress_coordinator = initial_meta_progress_coordinator
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
	_refresh(events)
	if unlock_result.get("changed", false) and unlock_result.get("persisted", false):
		state.feedback = "Act 2 Normal Ending recorded. Character 3 and Contracts 4–6 are now available for later Runs."
		presentation_changed.emit()
	elif unlock_result.has("code") and not unlock_result.get("persisted", false):
		state.feedback = "Unlock progress could not be saved. The game will retry the next time this Run is recorded."
		presentation_changed.emit()
	return result

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
		state.feedback = "No action is focused."
		presentation_changed.emit()
		return _rejected_presentation_input("No action is focused.")
	var action := _find_action(action_id)
	if not action.is_empty():
		match action.get("kind", ""):
			"WORKSHOP_SELECT_SERVICE":
				_selected_workshop_service_id = str(action.get("service_id", ""))
				_selected_workshop_instance_id = ""
				return _workshop_selection_result("Choose a TileInstance for %s." % _pretty_service_name(_selected_workshop_service_id))
			"WORKSHOP_SELECT_TARGET":
				_selected_workshop_instance_id = str(action.get("instance_id", ""))
				return _workshop_selection_result("Choose the result for the selected TileInstance.")
			"WORKSHOP_BACK":
				return _step_back_workshop_selection()
	var command = _command_for_action(action_id)
	if command == null:
		return _rejected_presentation_input("The focused action is not available.")
	return submit(command)

func cancel() -> bool:
	state.clear_details()
	state.feedback = "Cancelled."
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
	state.feedback = "Details are unavailable for that action."
	presentation_changed.emit()
	return {}

func set_mode(mode: String) -> bool:
	var accepted: bool = state.set_mode(mode)
	if not accepted:
		state.feedback = "Unknown presentation mode."
	presentation_changed.emit()
	return accepted

func snapshot() -> Dictionary:
	return state.to_dictionary()

func action_descriptors() -> Array:
	return _action_descriptors().duplicate(true)

func _refresh(events: Array) -> void:
	var previous_focus: String = state.focused_action_id()
	state.phase = str(domain.state.phase)
	state.screen = "run.%s" % state.phase.to_lower()
	state.authoritative_snapshot = domain.checkpoint().duplicate(true)
	state.last_domain_event_types = []
	for event in events:
		if event != null:
			state.last_domain_event_types.append(str(event.event_type))
	state.set_focus_actions(_action_ids(), previous_focus)
	if not events.is_empty():
		state.feedback = _feedback_for_events(events)
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
			actions.append({"id": prefix + definition.content_id, "kind": kind, "target_id": definition.content_id, "details": {"content_id": definition.content_id}})
	return actions

func _map_actions() -> Array:
	var actions: Array = []
	var map_state = domain.state.map_state
	var definition = domain.map_definition
	var current = definition.node_definition(map_state.current_node_id)
	if current != null:
		for node_id in current.next_node_ids:
			actions.append({
				"id": ACTION_PREFIX_MAP + node_id,
				"kind": "MAP_NODE",
				"target_id": node_id,
				"node_kind": definition.node_definition(node_id).node_kind,
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
	var battle_state: Dictionary = domain.current_battle.public_state()
	for pattern in battle_state.get("pattern_highlights", []):
		actions.append({"id": "battle.settle:" + str(pattern.get("candidate_id", "")), "kind": "PARTIAL_SETTLEMENT", "target_id": str(pattern.get("candidate_id", "")), "details": pattern.duplicate(true)})
	for tile in domain.current_battle.zones.contents(TileZoneScript.HAND):
		actions.append({"id": "battle.store:" + str(tile.instance_id), "kind": "RESERVE", "target_id": str(tile.instance_id), "details": {"tile_id": tile.definition_id, "instance_id": tile.instance_id}})
	if domain.current_battle.can_complete_hand():
		for interpretation in domain.current_battle.complete_hand_interpretations():
			actions.append({"id": "battle.complete:" + str(interpretation.interpretation_id), "kind": "COMPLETE_HAND", "target_id": str(interpretation.interpretation_id), "details": interpretation.to_dictionary()})
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
	state.feedback = message
	_refresh([])
	return {"accepted": true, "status": "PRESENTATION_SELECTION", "events": []}

func _step_back_workshop_selection() -> Dictionary:
	if not _selected_workshop_instance_id.is_empty():
		_selected_workshop_instance_id = ""
		return _workshop_selection_result("Choose a TileInstance.")
	_selected_workshop_service_id = ""
	return _workshop_selection_result("Choose a Workshop service.")

func _pretty_service_name(service_id: String) -> String:
	return service_id.to_lower().replace("_", " ").capitalize()

func _event_actions() -> Array:
	var actions: Array = []
	for option_id in domain.state.event_state.legal_choice_ids():
		actions.append({"id": ACTION_PREFIX_EVENT + option_id, "kind": "EVENT_OPTION", "target_id": option_id, "event_id": domain.state.event_state.event_id, "entry_id": domain.state.event_state.entry_id})
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
	state.feedback = message
	_refresh([])
	return result

func _feedback_for_events(events: Array) -> String:
	var last_event = events[events.size() - 1]
	match last_event.event_type:
		DomainEventScript.CHARACTER_SELECTED: return "Character selected."
		DomainEventScript.CONTRACT_SELECTED: return "Contract selected."
		DomainEventScript.MAP_NODE_SELECTED: return "Map node selected."
		DomainEventScript.BATTLE_STARTED: return "Battle started."
		DomainEventScript.REWARD_DRAFT_CREATED: return "Choose a reward."
		DomainEventScript.SHOP_ENTERED: return "Shop opened."
		DomainEventScript.WORKSHOP_ENTERED: return "Workshop opened."
		DomainEventScript.EVENT_ENTERED: return "Choose an Event option."
		DomainEventScript.RUN_SUMMARY_REACHED: return "Run Summary reached."
		DomainEventScript.CHARACTER_PASSIVE_TRIGGERED:
			var passive = domain.content_registry.resolve(str(last_event.data.get("passive_id", "")))
			return "%s: %s" % [str(passive.get("display_name")), str(passive.get("description"))] if passive != null else "Character Passive triggered."
	return str(last_event.event_type)
