extends RefCounted

const RunSceneScript = preload("res://scenes/run/run_scene.tscn")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const ShopOfferScript = preload("res://src/domain/run/shop_offer.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["Direct-choice regression requires an active SceneTree"]
	var original_locale := TranslationServer.get_locale()
	var original_window_size: Vector2i = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await _assert_character_mouse_press_executes_once(tree)
	await _assert_mapped_accept_executes_once(tree, "Enter", null)
	await _assert_mapped_accept_executes_once(tree, "A", JOY_BUTTON_A)
	await _assert_contract_and_map_buttons_execute_once(tree)
	await _assert_reward_choice_executes_once(tree)
	await _assert_shop_purchase_executes_once(tree)
	await _assert_workshop_service_executes_once(tree)
	await _assert_event_choice_executes_once(tree)
	await _assert_guided_sample_choice_executes_once(tree)
	await _assert_saved_continue_and_new_run_are_one_press(tree)
	await _assert_finish_run_executes_once(tree)
	await _assert_terminal_new_run_is_one_press(tree)
	await _assert_disabled_character_is_inert(tree)
	TranslationServer.set_locale(original_locale)
	tree.root.size = original_window_size
	return _failures


func _assert_character_mouse_press_executes_once(tree: SceneTree) -> void:
	var fixture: Dictionary = await _new_scene(tree, "character-mouse")
	var scene = fixture["scene"]
	var action_id := "character:base.character.sequence"
	var button: Button = scene._journey_view.action_button(action_id)
	_assert(button != null and button.is_visible_in_tree() and not button.disabled, "Character mouse fixture exposes its available action")
	if button != null and not button.disabled:
		var prior_count: int = scene.controller.domain.replay_record.commands.size()
		await _press_mouse(tree, button)
		_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.CONTRACT_SELECT, "one mouse activation advances directly from Character to Contract")
		_assert(scene.controller.domain.replay_record.commands.size() == prior_count + 1, "one Character activation records exactly one authoritative command")
		await tree.process_frame
		_assert(scene.controller.domain.replay_record.commands.size() == prior_count + 1, "a single Character activation does not execute again after the next frame")
	_close_scene(tree, fixture)


func _assert_mapped_accept_executes_once(tree: SceneTree, input_name: String, joy_button) -> void:
	var fixture: Dictionary = await _new_scene(tree, "character-%s" % input_name.to_lower())
	var scene = fixture["scene"]
	var action_id := "character:base.character.sequence"
	var button: Button = scene._journey_view.action_button(action_id)
	_assert(button != null and button.is_visible_in_tree() and not button.disabled, "%s fixture exposes its available Character action" % input_name)
	if button != null and not button.disabled:
		button.grab_focus()
		var prior_count: int = scene.controller.domain.replay_record.commands.size()
		if joy_button == null:
			await _press_key(KEY_ENTER)
		else:
			await _press_joypad_button(int(joy_button))
		_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.CONTRACT_SELECT, "%s activates the focused Character directly" % input_name)
		_assert(scene.controller.domain.replay_record.commands.size() == prior_count + 1, "%s records exactly one Character command" % input_name)
		await tree.process_frame
		_assert(scene.controller.domain.replay_record.commands.size() == prior_count + 1, "%s does not repeat the Character command on a later frame" % input_name)
	_close_scene(tree, fixture)


func _assert_contract_and_map_buttons_execute_once(tree: SceneTree) -> void:
	var fixture: Dictionary = await _new_scene(tree, "contract-map")
	var scene = fixture["scene"]
	var character_result = scene.controller.confirm("character:base.character.sequence")
	_assert(character_result != null and character_result.accepted, "Contract fixture enters the real Contract phase")
	await tree.process_frame
	var contract_id := "contract:base.contract.pressure"
	var contract_button: Button = _action_button(scene, contract_id)
	_assert(contract_button != null and not contract_button.disabled, "Contract choice has an enabled control")
	if contract_button != null and not contract_button.disabled:
		var prior_count: int = scene.controller.domain.replay_record.commands.size()
		await _press_mouse(tree, contract_button)
		_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.MAP_CHOICE, "one Contract activation advances directly to the map")
		_assert(scene.controller.domain.replay_record.commands.size() == prior_count + 1, "one Contract activation records exactly one command")
	if str(scene.controller.domain.state.phase) != RunPhaseScript.MAP_CHOICE:
		var setup_contract = scene.controller.confirm("contract:base.contract.pressure")
		_assert(setup_contract != null and setup_contract.accepted, "Map fixture enters the real Map phase independently of its direct-action assertion")
		await tree.process_frame
	var map_action: Dictionary = {}
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) == "MAP_NODE":
			map_action = action
			break
	var map_id := str(map_action.get("id", ""))
	var map_button := _action_button(scene, map_id)
	_assert(not map_id.is_empty() and map_button != null and not map_button.disabled, "Map choice has an enabled map-node control")
	if map_button != null and not map_button.disabled:
		var prior_map_count: int = scene.controller.domain.replay_record.commands.size()
		await _press_mouse(tree, map_button)
		_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.BATTLE, "preview followed by Travel enters Battle")
		_assert(scene.controller.domain.replay_record.commands.size() == prior_map_count + 1, "one Map activation records exactly one command")
	_close_scene(tree, fixture)


func _assert_reward_choice_executes_once(tree: SceneTree) -> void:
	var fixture: Dictionary = await _new_scene(tree, "reward")
	var scene = fixture["scene"]
	scene.controller.confirm("character:base.character.sequence")
	scene.controller.confirm("contract:base.contract.pressure")
	await tree.process_frame
	var map_action: Dictionary = {}
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) == "MAP_NODE":
			map_action = action
			break
	var map_button := _action_button(scene, str(map_action.get("id", "")))
	_assert(map_button != null and not map_button.disabled, "Reward fixture reaches a real Battle through its map choice")
	if map_button != null and not map_button.disabled:
		await _press_mouse(tree, map_button)
		var battle = scene.controller.domain.current_battle
		_assert(battle != null, "Reward fixture uses the real encounter selected on the authored Map")
		if battle != null:
			scene.controller.domain.reward_flow.create_draft("NORMAL", str(battle.encounter_id), RunPhaseScript.BATTLE)
			scene._render()
		_assert(str(scene.controller.domain.state.phase) in [RunPhaseScript.REWARD_CHOICE, RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD], "real Battle fixture reaches a Reward choice")
		var reward_action: Dictionary = {}
		for action in scene.controller.action_descriptors():
			if str(action.get("kind", "")) in ["REWARD", "ELITE_REWARD", "BOSS_REWARD"]:
				reward_action = action
				break
		var reward_id := str(reward_action.get("id", ""))
		var reward_button := _action_button(scene, reward_id)
		_assert(not reward_id.is_empty() and reward_button != null and not reward_button.disabled, "Reward choice is a visible, enabled journey control")
		if reward_button != null and not reward_button.disabled:
			var prior_count: int = scene.controller.domain.replay_record.commands.size()
			await _press_mouse(tree, reward_button)
			_assert(scene.controller.domain.replay_record.commands.size() == prior_count + 1, "one Reward activation records exactly one accepted command")
			_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.MAP_CHOICE, "one Reward activation returns directly to the Map")
	_close_scene(tree, fixture)


func _assert_shop_purchase_executes_once(tree: SceneTree) -> void:
	var fixture: Dictionary = await _new_scene(tree, "shop")
	var scene = fixture["scene"]
	var reached := await _enter_map_service(tree, scene, "SHOP", "shop")
	_assert(reached, "Shop fixture reaches the real authored Shop through a RunMap node")
	if reached:
		_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.SHOP, "one Shop-entry activation enters Shop")
		scene.controller.domain.state.gold = 1000
		scene._render()
		var offer: Dictionary = {}
		for action in scene.controller.action_descriptors():
			if str(action.get("kind", "")) == "SHOP_OFFER":
				offer = action
				break
		var offer_id := str(offer.get("id", ""))
		var offer_button := _action_button(scene, offer_id)
		_assert(not offer_id.is_empty() and offer_button != null and not offer_button.disabled, "Shop exposes a purchasable offer control")
		if offer_button != null and not offer_button.disabled:
			var offer_target := str(offer.get("target_id", ""))
			var prior_count: int = scene.controller.domain.replay_record.commands.size()
			await _press_mouse(tree, offer_button)
			var sold_offer = scene.controller.domain.state.shop_state.offer_by_id(offer_target)
			_assert(scene.controller.domain.replay_record.commands.size() == prior_count + 1, "one offer activation records exactly one purchase command")
			_assert(sold_offer != null and sold_offer.status == ShopOfferScript.SOLD, "one offer activation completes the purchase immediately")
			_assert(scene._journey_view.find_child("RunChoiceConfirmation", true, false) == null, "Shop has no confirmation overlay")
	_close_scene(tree, fixture)


func _assert_workshop_service_executes_once(tree: SceneTree) -> void:
	var fixture: Dictionary = await _new_scene(tree, "workshop")
	var scene = fixture["scene"]
	var reached := await _enter_map_service(tree, scene, "WORKSHOP", "workshop")
	_assert(reached, "Workshop fixture reaches the real authored Workshop through a RunMap node")
	if reached:
		_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.WORKSHOP, "one Workshop-entry activation enters Workshop")
		scene.controller.domain.state.gold = 1000
		scene.controller.domain.state.refinement_tokens = maxi(2, int(scene.controller.domain.state.refinement_tokens))
		scene._render()
		var service: Dictionary = {}
		for action in scene.controller.action_descriptors():
			if str(action.get("kind", "")) == "WORKSHOP_SELECT_SERVICE" and str(action.get("service_id", "")) == "TRANSFORM":
				service = action
				break
		var service_id := str(service.get("id", ""))
		var service_button := _action_button(scene, service_id)
		_assert(not service_id.is_empty() and service_button != null and not service_button.disabled, "Workshop exposes an available service selection")
		var prior_selection_count: int = scene.controller.domain.replay_record.commands.size()
		var final_action: Dictionary = {}
		if service_button != null and not service_button.disabled:
			await _press_mouse(tree, service_button)
			_assert(scene.controller.domain.replay_record.commands.size() == prior_selection_count, "selecting a Workshop service only advances the service choice")
			final_action = _first_action_of_kind(scene, "WORKSHOP_SERVICE")
		var target_action := _first_action_of_kind(scene, "WORKSHOP_SELECT_TARGET")
		var target_button := _action_button(scene, str(target_action.get("id", "")))
		_assert(final_action.is_empty(), "a value-requiring Workshop service first asks for its exact target")
		_assert(not target_action.is_empty() and target_button != null and not target_button.disabled, "Workshop exposes a specific target for the chosen service")
		if target_button != null and not target_button.disabled:
			await _press_mouse(tree, target_button)
			_assert(scene.controller.domain.replay_record.commands.size() == prior_selection_count, "choosing a Workshop target does not require or record a separate commit")
			_assert(str(scene.controller._selected_workshop_instance_id) == str(target_action.get("instance_id", "")), "one tile activation selects the requested Workshop target")
			final_action = _first_action_of_kind(scene, "WORKSHOP_SERVICE")
		var final_id := str(final_action.get("id", ""))
		var final_button := _action_button(scene, final_id)
		_assert(not final_id.is_empty() and final_button != null and not final_button.disabled, "Workshop exposes a legal, exact service result")
		if final_button != null and not final_button.disabled:
			await _press_mouse(tree, final_button)
			_assert(scene.controller.domain.replay_record.commands.size() == prior_selection_count + 1, "one Workshop service-result activation executes exactly one command")
			_assert(scene._journey_view.find_child("RunChoiceConfirmation", true, false) == null, "Workshop has no confirmation overlay")
	_close_scene(tree, fixture)


func _assert_event_choice_executes_once(tree: SceneTree) -> void:
	var fixture: Dictionary = await _new_scene(tree, "event")
	var scene = fixture["scene"]
	var reached := await _enter_map_service(tree, scene, "EVENT", "event")
	_assert(reached, "Event fixture reaches the real authored Event through a RunMap node")
	if reached:
		_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.EVENT, "one Event-entry activation enters the Event directly")
		var option := _first_action_of_kind(scene, "EVENT_OPTION")
		var option_button := _action_button(scene, str(option.get("id", "")))
		_assert(not option.is_empty() and option_button != null and not option_button.disabled, "Event exposes a legal option control")
		if option_button != null and not option_button.disabled:
			var prior_count: int = scene.controller.domain.replay_record.commands.size()
			await _press_mouse(tree, option_button)
			_assert(scene.controller.domain.replay_record.commands.size() == prior_count + 1, "one Event option activation records exactly one command")
			_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.MAP_CHOICE, "one Event option activation resolves directly to the Map")
	_close_scene(tree, fixture)


func _assert_guided_sample_choice_executes_once(tree: SceneTree) -> void:
	var fixture: Dictionary = await _new_scene(tree, "guided-sample")
	var scene = fixture["scene"]
	scene._on_guided_sample_pressed()
	await tree.process_frame
	var action_id := "character:base.character.sequence"
	var button: Button = scene._journey_view.action_button(action_id)
	_assert(button != null and not button.disabled, "Guided Sample exposes the same available Character action")
	if button != null and not button.disabled:
		var prior_commands: int = scene.controller.domain.replay_record.commands.size()
		await _press_mouse(tree, button)
		_assert(scene.controller.domain.replay_record.commands.size() == prior_commands + 1, "one Guided Sample choice records one sample-local command")
		_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.CONTRACT_SELECT, "one Guided Sample choice advances directly to its Contract step")
		_assert(int(scene._guided_sample_session.completed_step_count()) == 1, "Guided Sample advances exactly one instruction step")
	_close_scene(tree, fixture)


func _assert_finish_run_executes_once(tree: SceneTree) -> void:
	var fixture: Dictionary = await _new_scene(tree, "finish-run")
	var scene = fixture["scene"]
	scene.controller.domain.state.phase = RunPhaseScript.RUN_SUMMARY
	scene.controller.domain.state.terminal_summary.outcome = "DEFEAT"
	scene.controller.domain.state.terminal_summary.reason = ""
	scene._render()
	var finish_button: Button = scene._summary_acknowledge_button
	_assert(finish_button != null and finish_button.visible and not finish_button.disabled, "Run Summary exposes one direct Finish Run control")
	if finish_button != null and finish_button.visible and not finish_button.disabled:
		var prior_count: int = scene.controller.domain.replay_record.commands.size()
		await _press_mouse(tree, finish_button)
		_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.RUN_COMPLETE, "one Finish Run activation ends the summary")
		_assert(scene.controller.domain.replay_record.commands.size() == prior_count + 1, "one Finish Run activation records exactly one acknowledgement command")
	_close_scene(tree, fixture)


func _assert_saved_continue_and_new_run_are_one_press(tree: SceneTree) -> void:
	var continue_fixture: Dictionary = await _new_scene(tree, "saved-continue")
	var continue_scene = continue_fixture["scene"]
	var continued_domain = _saved_domain(continue_scene, "direct-continue")
	continue_scene._set_active_controller(null)
	continue_scene._pending_resume_domain = continued_domain
	continue_scene._show_valid_suspend_choice(continued_domain, {}, true, "MAP_NODE")
	continue_scene._render()
	continue_scene._resume_run_button.grab_focus()
	await _press_key(KEY_ENTER)
	_assert(continue_scene.controller != null and str(continue_scene.controller.domain.state.run_id) == str(continued_domain.state.run_id), "one Continue activation attaches the saved Run")
	_assert(not continue_scene._suspend_choice_panel.visible, "Continue closes the saved-run opening without an extra step")
	_close_scene(tree, continue_fixture)

	var new_fixture: Dictionary = await _new_scene(tree, "saved-new-run")
	var new_scene = new_fixture["scene"]
	var pending_domain = _saved_domain(new_scene, "direct-new-run")
	new_scene._set_active_controller(null)
	new_scene._pending_resume_domain = pending_domain
	new_scene._show_valid_suspend_choice(pending_domain, {}, true, "MAP_NODE")
	new_scene._render()
	new_scene._new_run_from_suspend_button.grab_focus()
	await _press_key(KEY_ENTER)
	_assert(new_scene.controller != null, "one New Run activation starts a fresh Run from the saved-run opening")
	_assert(new_scene.controller == null or str(new_scene.controller.domain.state.run_id) != str(pending_domain.state.run_id), "New Run does not resume the previous Run")
	_assert(new_scene.find_child("NewRunConfirmation", true, false) == null, "saved-opening New Run does not create a second confirmation")
	_assert(new_scene._journey_view.find_child("RunChoiceConfirmation", true, false) == null, "saved-opening choices have no hidden purchase/Workshop confirmation surface")
	_close_scene(tree, new_fixture)


func _assert_terminal_new_run_is_one_press(tree: SceneTree) -> void:
	var fixture: Dictionary = await _new_scene(tree, "terminal-new-run")
	var scene = fixture["scene"]
	var prior_run_id := str(scene.controller.domain.state.run_id)
	scene.controller.domain.state.phase = RunPhaseScript.RUN_COMPLETE
	scene._render()
	_assert(scene._new_run_button.visible and not scene._new_run_button.disabled, "terminal fixture exposes the New Run action")
	scene._new_run_button.grab_focus()
	await _press_key(KEY_ENTER)
	_assert(scene.controller != null and str(scene.controller.domain.state.run_id) != prior_run_id, "one terminal New Run activation starts a new Run")
	_assert(scene.find_child("NewRunConfirmation", true, false) == null, "terminal New Run does not create a second confirmation")
	_close_scene(tree, fixture)


func _assert_disabled_character_is_inert(tree: SceneTree) -> void:
	var fixture: Dictionary = await _new_scene(tree, "disabled-character")
	var scene = fixture["scene"]
	var button: Button = scene._journey_view.action_button("character:base.character.sequence")
	_assert(button != null and button.is_visible_in_tree(), "disabled-action fixture exposes a real Character action control")
	if button != null:
		button.disabled = true
		var prior_count: int = scene.controller.domain.replay_record.commands.size()
		await _press_mouse(tree, button)
		_assert(str(scene.controller.domain.state.phase) == RunPhaseScript.CHARACTER_SELECT, "a disabled Character action does not advance the Run")
		_assert(scene.controller.domain.replay_record.commands.size() == prior_count, "a disabled Character action records no command")
	_close_scene(tree, fixture)


func _enter_map_service(tree: SceneTree, scene, node_kind: String, suffix: String) -> bool:
	var character_result = scene.controller.confirm("character:base.character.sequence")
	var contract_result = scene.controller.confirm("contract:base.contract.pressure")
	_assert(character_result != null and character_result.accepted, "%s fixture creates a real Run character" % suffix)
	_assert(contract_result != null and contract_result.accepted, "%s fixture enters the real authored Map" % suffix)
	var definition = scene.controller.domain.map_definition
	var route: Array[String] = _find_map_route(definition, str(definition.start_node_id), node_kind, {})
	if route.size() < 2:
		_assert(false, "production map contains a reachable %s node" % node_kind)
		return false
	var map_state = scene.controller.domain.state.map_state
	for index in range(route.size() - 1):
		map_state.select_node(route[index], definition)
	scene._render()
	for _frame in 2:
		await tree.process_frame
	var target_node_id: String = route.back()
	var map_button := _action_button(scene, "map:%s" % target_node_id)
	_assert(map_button != null and not map_button.disabled and map_button.is_visible_in_tree(), "%s target is a real adjacent Map button" % suffix)
	if map_button == null or map_button.disabled:
		return false
	var before_map_command_count: int = scene.controller.domain.replay_record.commands.size()
	await _press_mouse(tree, map_button)
	_assert(scene.controller.domain.replay_record.commands.size() == before_map_command_count + 2, "Travel records a Map command and room entry for %s" % suffix)
	_assert(str(map_state.current_node_id) == target_node_id, "one %s node activation selects the requested node" % suffix)
	return str(map_state.current_node_id) == target_node_id


func _find_map_route(definition, node_id: String, desired_kind: String, visited: Dictionary) -> Array[String]:
	if visited.has(node_id):
		return []
	visited[node_id] = true
	var node = definition.node_definition(node_id)
	if node == null:
		return []
	if str(node.node_kind) == desired_kind:
		return [node_id]
	for next_node_id in node.next_node_ids:
		var remainder: Array[String] = _find_map_route(definition, str(next_node_id), desired_kind, visited.duplicate())
		if not remainder.is_empty():
			remainder.push_front(node_id)
			return remainder
	return []


func _first_action_of_kind(scene, kind: String) -> Dictionary:
	if kind == "CHARACTER":
		for action in scene.controller.action_descriptors():
			if str(action.get("target_id", "")) == "base.character.sequence":
				return action
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) == kind:
			return action
	return {}


func _new_scene(tree: SceneTree, label: String) -> Dictionary:
	var suffix := "%s-%d" % [label, Time.get_ticks_usec()]
	var suspend_path := "user://rc3_direct_choices_%s_suspend.json" % suffix
	var profile_path := "user://rc3_direct_choices_%s_profile.json" % suffix
	var scene = RunSceneScript.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	tree.root.add_child(scene)
	for _frame in 3:
		await tree.process_frame
	scene._apply_presentation_preferences({
		"locale": "en",
		"ui_scale": 1.0,
		"presentation_mode": "NORMAL",
		"reduced_motion": true,
		"ambient_glow": false,
	}, true)
	return {"scene": scene, "suspend_path": suspend_path, "profile_path": profile_path}


func _saved_domain(scene, suffix: String):
	var domain = RunDomainScript.new_alpha_run("rc3.direct.%s" % suffix, int(Time.get_ticks_usec() % 2147483647), scene._content_registry)
	domain.execute(ChooseCharacterCommandScript.new("rc3.direct.%s.character" % suffix, "base.character.sequence"))
	domain.execute(ChooseContractCommandScript.new("rc3.direct.%s.contract" % suffix, "base.contract.pressure"))
	return domain


func _action_button(scene, action_id: String) -> Button:
	for node in scene.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and str(button.get_meta("run_action_id", "")) == action_id:
			return button
	return null


func _press_mouse(tree: SceneTree, button: Button) -> void:
	var is_map_preview := button.has_meta("map_node_id")
	for _frame in 2:
		await tree.process_frame
	await _scroll_control_into_view(tree, button)
	var bounds := button.get_global_rect()
	var click_position := bounds.get_center()
	var viewport_bounds := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	var visible_bounds := _visible_control_rect(tree, button)
	var center_is_visible := viewport_bounds.has_point(click_position) and visible_bounds.has_point(click_position)
	_assert(bounds.size.x > 0.0 and bounds.size.y > 0.0 and center_is_visible and visible_bounds.encloses(bounds), "mouse fixture scrolls the target fully into the visible action area before clicking (button=%s visible=%s viewport=%s)" % [bounds, visible_bounds, viewport_bounds])
	if not center_is_visible:
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = click_position
	press.global_position = click_position
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await tree.process_frame
	if is_map_preview:
		var travel := tree.root.find_child("MapTravelButton", true, false) as Button
		_assert(travel != null and not travel.disabled, "map preview enables Travel")
		if travel != null and not travel.disabled:
			await _press_mouse(tree, travel)


func _scroll_control_into_view(tree: SceneTree, control: Control) -> void:
	var viewport_bounds := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	for _pass in 4:
		var changed := false
		var ancestor := control.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				var scroll := ancestor as ScrollContainer
				if scroll.is_visible_in_tree():
					var scroll_bounds := scroll.get_global_rect().intersection(viewport_bounds)
					var control_bounds := control.get_global_rect()
					var delta := 0.0
					if control_bounds.position.y < scroll_bounds.position.y:
						delta = control_bounds.position.y - scroll_bounds.position.y
					elif control_bounds.end.y > scroll_bounds.end.y:
						delta = control_bounds.end.y - scroll_bounds.end.y
					if not is_zero_approx(delta):
						var scrollbar := scroll.get_v_scroll_bar()
						var maximum := maxf(0.0, scrollbar.max_value - scrollbar.page)
						var next_position := clampf(float(scroll.scroll_vertical) + delta, 0.0, maximum)
						if not is_equal_approx(next_position, float(scroll.scroll_vertical)):
							scroll.scroll_vertical = roundi(next_position)
							changed = true
							await tree.process_frame
			ancestor = ancestor.get_parent()
		if not changed:
			break
		await tree.process_frame


func _visible_control_rect(tree: SceneTree, control: Control) -> Rect2:
	var visible_bounds := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			visible_bounds = visible_bounds.intersection((ancestor as ScrollContainer).get_global_rect())
		ancestor = ancestor.get_parent()
	return visible_bounds.intersection(control.get_global_rect())


func _press_key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _press_joypad_button(button_index: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = button_index
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := press.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _close_scene(tree: SceneTree, fixture: Dictionary) -> void:
	var scene = fixture.get("scene")
	if scene != null and is_instance_valid(scene):
		if scene.get_parent() == tree.root:
			tree.root.remove_child(scene)
		scene.free()
	var suspend_base: String = str(fixture.get("suspend_path", ""))
	var profile_base: String = str(fixture.get("profile_path", ""))
	for suffix in ["", ".tmp", ".bak"]:
		var suspend_path: String = suspend_base + str(suffix)
		var profile_path: String = profile_base + str(suffix)
		if not suspend_path.is_empty():
			var absolute_suspend := ProjectSettings.globalize_path(suspend_path)
			if FileAccess.file_exists(absolute_suspend):
				DirAccess.remove_absolute(absolute_suspend)
		if not profile_path.is_empty():
			var absolute_profile := ProjectSettings.globalize_path(profile_path)
			if FileAccess.file_exists(absolute_profile):
				DirAccess.remove_absolute(absolute_profile)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
