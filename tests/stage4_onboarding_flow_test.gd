class_name Stage4OnboardingFlowTest
extends RefCounted

const RunScene = preload("res://scenes/run/run_scene.tscn")
const MetaProgressCoordinator = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStore = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const AlphaScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ContentVersionMigration = preload("res://src/infrastructure/persistence/content_version_migration.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const TutorialProgress = preload("res://src/presentation/run/tutorial_progress.gd")
const ScriptedContentRegistry = preload("res://tests/fixtures/stage4_onboarding_content_registry.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_new_profile_tutorial_two_act_flow_and_unlocked_roster(failures)
	return failures

func test_new_profile_tutorial_two_act_flow_and_unlocked_roster(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_onboarding_profile_%s.json" % suffix
	var suspend_path := "user://stage4_onboarding_suspend_%s.json" % suffix
	var scene = RunScene.instantiate()
	scene.content_registry_factory = func(): return ScriptedContentRegistry.new()
	scene.meta_progress_coordinator = MetaProgressCoordinator.new(MetaProgressStore.new(profile_path))
	scene.suspend_file_path = suspend_path
	scene._ready()
	assert_true(scene.find_child("TutorialPrompt", true, false) is Label, "RunScene exposes a player-visible tutorial prompt", failures)
	assert_true(scene.find_child("TutorialToggleButton", true, false) is Button, "RunScene exposes a tutorial enable or disable action", failures)
	assert_true(scene.find_child("TutorialResetButton", true, false) is Button, "RunScene exposes a tutorial reset action", failures)
	var reset_button: Button = find_named_node(scene, "TutorialResetButton")
	assert_true(reset_button != null and reset_button.disabled, "Reset is disabled before tutorial progress exists", failures)
	var new_run_at_start: Button = find_named_node(scene, "NewRunButton")
	assert_true(new_run_at_start != null and new_run_at_start.disabled, "New Run is disabled while the first Run is in progress", failures)
	assert_true(scene.controller != null, "a new profile starts through the normal RunScene launch path", failures)
	if scene.controller == null:
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	var state = scene.controller.domain.state
	var run_id := str(state.run_id)
	var build_info: Dictionary = Engine.get_version_info()
	var engine_version := str(build_info.get("string", "unknown"))
	var content_version := str(state.content_version)
	var game_version := str(scene.controller.domain.replay_record.game_version)
	assert_true(engine_version.begins_with("4.7.2"), "the scripted flow reports the pinned Godot engine version", failures)
	assert_true(content_version == ContentVersionMigration.ACT_TWO_SCALE_V13, "the scripted flow uses the pinned Stage 4 Beta content bundle", failures)
	assert_true(scene.controller.domain.state.act_count == 2, "a new profile starts one continuous two-Act Run", failures)
	assert_actions_visible_and_enabled(scene, "CHARACTER", Phase2Catalog.CHARACTER_IDS, failures)
	assert_help_prompt(scene, "CHARACTER_SELECT", "Choose a Character", failures)

	press_action(scene, "character:%s" % Phase2Catalog.CHARACTER_IDS[0], RunPhase.CONTRACT_SELECT, failures)
	assert_actions_visible_and_enabled(scene, "CONTRACT", Phase2Catalog.CONTRACT_IDS, failures)
	assert_help_prompt(scene, "CONTRACT_SELECT", "Choose a Contract", failures)
	press_action(scene, "contract:%s" % Phase2Catalog.CONTRACT_IDS[0], RunPhase.MAP_CHOICE, failures)
	assert_help_prompt(scene, "MAP_CHOICE", "adjacent node", failures)
	press_action(scene, "map:%s" % scene.controller.domain.map_definition.start_node_id, RunPhase.BATTLE, failures)
	assert_help_prompt(scene, "BATTLE", "Draw tiles", failures)
	var tutorial_prompt: Label = find_named_node(scene, "TutorialPrompt")
	var tutorial_toggle: Button = find_named_node(scene, "TutorialToggleButton")
	var tutorial_reset: Button = find_named_node(scene, "TutorialResetButton")
	assert_true(tutorial_prompt.visible and not tutorial_prompt.text.is_empty(), "the first Run presents tutorial guidance during Battle", failures)
	var step_before_disable: String = scene.controller.tutorial_progress.current_step_id
	tutorial_toggle.emit_signal("pressed")
	assert_true(not scene.controller.tutorial_progress.enabled and not tutorial_prompt.visible, "disabling tutorial guidance hides its prompt", failures)
	press_action(scene, "battle.draw", RunPhase.BATTLE, failures)
	assert_true(scene.controller.tutorial_progress.current_step_id == step_before_disable, "a disabled tutorial does not advance on a real Draw event", failures)
	assert_true(not tutorial_reset.disabled, "Reset remains available while tutorial guidance is disabled", failures)
	tutorial_reset.emit_signal("pressed")
	assert_true(scene.controller.tutorial_progress.enabled and scene.controller.tutorial_progress.current_step_id == TutorialProgress.DRAW_PATTERN_PARTIAL, "Reset reenables tutorial guidance at the first step", failures)
	assert_true(tutorial_prompt.visible and tutorial_prompt.text.contains("draw a tile"), "Reset restores the first visible tutorial prompt", failures)
	press_action(scene, "battle.draw", RunPhase.BATTLE, failures)
	assert_true(scene.controller.tutorial_progress.current_step_id == TutorialProgress.TP_CORE_TECHNIQUE, "an enabled tutorial advances from the authoritative Draw event", failures)
	assert_true(tutorial_prompt.text.contains("Core Technique"), "the next tutorial step displays its matching prompt", failures)
	win_active_battle(scene, failures)
	assert_phase(scene, RunPhase.REWARD_CHOICE, "winning the intro encounter opens its Normal reward", failures)
	choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	assert_phase(scene, RunPhase.MAP_CHOICE, "choosing a Normal reward returns to the map", failures)

	for act_index in [1, 2]:
		if not complete_remaining_act_path(scene, act_index, failures):
			scene.free()
			_clear_test_file(profile_path)
			_clear_test_file(suspend_path)
			return
		if act_index == 1:
			assert_true(scene.controller.domain.state.act_index == 2 and scene.controller.domain.state.phase == RunPhase.MAP_CHOICE, "the Act 1 Boss reward crosses the boundary into the same Run's Act 2 map", failures)
			assert_true(find_named_node(scene, "RunPhaseLabel").text.contains("Act 2 of 2"), "the Act 1 reward presents the Act 2 destination", failures)
		else:
			assert_phase(scene, RunPhase.RUN_SUMMARY, "the Act 2 Boss reward reaches the Normal Ending Run Summary", failures)
			assert_true(find_named_node(scene, "RunSummaryPanel").visible and find_named_node(scene, "RunSummaryText").text.contains("Result: Victory (Boss Defeated)"), "Run Summary visibly presents the Normal Ending", failures)
			var finish_button: Button = find_named_node(scene, "FinishRunButton")
			assert_true(finish_button.visible and not finish_button.disabled, "Run Summary exposes an enabled Finish Run action", failures)
			finish_button.emit_signal("pressed")
			assert_phase(scene, RunPhase.RUN_COMPLETE, "acknowledging Run Summary finishes the Run", failures)
	var new_run_button: Button = find_named_node(scene, "NewRunButton")
	assert_true(new_run_button.visible and not new_run_button.disabled, "New Run is enabled only after Run completion", failures)
	assert_true(scene.meta_progress_coordinator.state.unlocked_character_ids.size() == 3, "the completed first Run unlocks the third Character", failures)
	assert_true(scene.meta_progress_coordinator.state.unlocked_contract_ids.size() == 8, "the completed first Run unlocks the full eight-Contract roster", failures)
	var completed_summary = scene.controller.domain.state.terminal_summary
	assert_true(completed_summary.outcome == "VICTORY" and completed_summary.reason == "BOSS_DEFEATED", "the authoritative ending records the normal Act 2 Boss victory", failures)
	new_run_button.emit_signal("pressed")
	assert_true(scene.controller != null and scene.controller.domain.state.run_id != run_id, "New Run starts a new Run through the normal selection flow", failures)
	var all_character_ids: Array = Phase2Catalog.CHARACTER_IDS.duplicate()
	all_character_ids.append(AlphaScaleCatalog.CHARACTER_ID)
	assert_actions_visible_and_enabled(scene, "CHARACTER", all_character_ids, failures)
	assert_help_prompt(scene, "CHARACTER_SELECT", "Choose a Character", failures)
	press_action(scene, "character:%s" % AlphaScaleCatalog.CHARACTER_ID, RunPhase.CONTRACT_SELECT, failures)
	var all_contract_ids: Array = Phase2Catalog.CONTRACT_IDS.duplicate()
	all_contract_ids.append_array(AlphaScaleCatalog.CONTRACT_IDS)
	assert_actions_visible_and_enabled(scene, "CONTRACT", all_contract_ids, failures)
	assert_help_prompt(scene, "CONTRACT_SELECT", "Choose a Contract", failures)
	press_action(scene, "contract:%s" % AlphaScaleCatalog.CONTRACT_IDS[-1], RunPhase.MAP_CHOICE, failures)
	assert_true(scene.controller.domain.state.character_id == AlphaScaleCatalog.CHARACTER_ID and scene.controller.domain.state.contract_id == AlphaScaleCatalog.CONTRACT_IDS[-1], "the newly unlocked Character and Contract both start through normal selection", failures)
	assert_true(scene.controller.snapshot().authoritative_snapshot == scene.controller.domain.checkpoint(), "the final selection screen mirrors the authoritative Run checkpoint", failures)

	var mechanical_status := "PASS" if failures.is_empty() else "FAIL"
	print("STAGE4_ONBOARDING_FLOW_REPORT script=res://tests/stage4_onboarding_flow_test.gd focused_command='./scripts/test.sh --stage4-onboarding-flow' full_command='./scripts/test.sh' build_version=%s engine=%s production_content_baseline=%s fixture=stage4-scripted-combat(enemy_hp=1,pressure_limit=1000,core_technique=DealDamage:1,test_only) seed=%d mechanical_flow=%s human_comprehension_or_clarity=NOT_EVALUATED" % [
		game_version, engine_version, content_version, int(scene.controller.domain.state.seed), mechanical_status,
	])
	scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)

func complete_remaining_act_path(scene, act_index: int, failures: Array[String]) -> bool:
	var domain = scene.controller.domain
	var prefix := "base.map_node.act_two." if act_index == 2 else "base.map_node."
	if act_index == 2:
		press_map_target(scene, prefix + "intro", RunPhase.BATTLE, failures)
		if not win_active_battle(scene, failures):
			return false
		choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	var normal_left_id := prefix + "normal.left"
	press_map_target(scene, normal_left_id, RunPhase.BATTLE, failures)
	if not win_active_battle(scene, failures):
		return false
	choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	var event_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "MAP_NODE" and action.get("node_kind", "") == "EVENT")
	assert_true(event_actions.size() == 1, "Act %d branch presents one selectable Event route" % act_index, failures)
	if event_actions.is_empty():
		return false
	press_action(scene, str(event_actions[0].get("id", "")), RunPhase.MAP_CHOICE, failures)
	assert_true(str(domain.state.map_state.current_node_id).contains("event.left"), "the Event route updates the authoritative current Map node", failures)
	var enter_event = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "ENTER_EVENT")
	assert_true(enter_event.size() == 1, "the visited Event node enables its Enter Event action", failures)
	if enter_event.is_empty():
		return false
	press_action(scene, str(enter_event[0].get("id", "")), RunPhase.EVENT, failures)
	var event_options = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "EVENT_OPTION" and action.get("target_id", "") == "leave")
	assert_true(not event_options.is_empty(), "Event presentation exposes the safe Leave choice", failures)
	if event_options.is_empty():
		return false
	press_action(scene, str(event_options[0].get("id", "")), RunPhase.MAP_CHOICE, failures)
	assert_true(domain.state.event_state.completed and not domain.state.event_state.selected_choice_id.is_empty(), "the selected Event choice updates authoritative Event state", failures)
	press_map_target(scene, prefix + "normal.mid", RunPhase.BATTLE, failures)
	if not win_active_battle(scene, failures):
		return false
	choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	press_map_kind(scene, "ELITE", RunPhase.BATTLE, failures)
	if not win_active_battle(scene, failures):
		return false
	assert_phase(scene, RunPhase.ELITE_REWARD, "the Act %d Elite win opens its reward choices" % act_index, failures)
	choose_first_reward(scene, RunPhase.MAP_CHOICE, failures)
	press_map_kind(scene, "BOSS", RunPhase.BATTLE, failures)
	if not win_active_battle(scene, failures):
		return false
	assert_phase(scene, RunPhase.BOSS_REWARD, "the Act %d Boss win opens its three-choice Rule Breaker draft" % act_index, failures)
	var boss_rewards: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "BOSS_REWARD")
	assert_true(boss_rewards.size() == 3, "Act %d Boss reward visibly enables three choices" % act_index, failures)
	var boss_reward_choice_ids: Array = []
	for action in boss_rewards:
		boss_reward_choice_ids.append(str(action.get("target_id", "")))
	assert_actions_visible_and_enabled(scene, "BOSS_REWARD", boss_reward_choice_ids, failures)
	if boss_rewards.is_empty():
		return false
	var selected_content_id := str(boss_rewards[0].get("content_id", ""))
	press_action(scene, str(boss_rewards[0].get("id", "")), RunPhase.MAP_CHOICE if act_index == 1 else RunPhase.RUN_SUMMARY, failures)
	assert_true(domain.state.build_ownership.acquired_rule_breaker_ids.has(selected_content_id), "the selected Act %d Boss reward is applied to authoritative build ownership" % act_index, failures)
	assert_true(domain.state.reward_draft == null, "the selected Act %d Boss draft is consumed" % act_index, failures)
	return true

func press_map_target(scene, target_id: String, expected_phase: String, failures: Array[String]) -> void:
	press_action(scene, "map:%s" % target_id, expected_phase, failures)

func press_map_kind(scene, node_kind: String, expected_phase: String, failures: Array[String]) -> void:
	var actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "MAP_NODE" and action.get("node_kind", "") == node_kind)
	assert_true(actions.size() == 1, "%s route is visible and unambiguous" % node_kind, failures)
	if actions.is_empty():
		return
	press_action(scene, str(actions[0].get("id", "")), expected_phase, failures)

func choose_first_reward(scene, expected_phase: String, failures: Array[String]) -> void:
	var rewards: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") in ["REWARD", "ELITE_REWARD"])
	assert_true(not rewards.is_empty(), "the active reward screen exposes an enabled reward choice", failures)
	if rewards.is_empty():
		return
	press_action(scene, str(rewards[0].get("id", "")), expected_phase, failures)
	assert_true(scene.controller.domain.state.reward_draft == null, "the selected reward draft is consumed", failures)

func win_active_battle(scene, failures: Array[String]) -> bool:
	var domain = scene.controller.domain
	assert_true(domain.current_battle != null, "the selected encounter creates an authoritative BattleDomain", failures)
	if domain.current_battle == null:
		return false
	# The fixture exposes one-damage Core Techniques; actions still resolve through the player-facing controls.
	var action_count := 0
	while str(domain.state.phase) == RunPhase.BATTLE and action_count < 16:
		var technique_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "TECHNIQUE")
		if not technique_actions.is_empty():
			press_battle_action(scene, str(technique_actions[0].get("id", "")), failures)
		else:
			press_action(scene, "battle.end_turn", RunPhase.BATTLE, failures)
		action_count += 1
	var victory := str(domain.state.phase) in [RunPhase.REWARD_CHOICE, RunPhase.ELITE_REWARD, RunPhase.BOSS_REWARD, RunPhase.RUN_SUMMARY]
	assert_true(victory, "the visible Core Technique action resolves the encounter to its next Run destination", failures)
	return victory

func press_battle_action(scene, action_id: String, failures: Array[String]) -> void:
	var button: Button = find_action_button(scene, action_id)
	assert_true(button != null and button.visible and not button.disabled, "Battle action %s is visibly enabled" % action_id, failures)
	if button == null or button.disabled:
		return
	var command_count_before: int = scene.controller.domain.replay_record.commands.size()
	button.emit_signal("pressed")
	assert_true(scene.controller.domain.replay_record.commands.size() == command_count_before + 1, "Battle action %s submits one accepted authoritative Command" % action_id, failures)
	var phase := str(scene.controller.domain.state.phase)
	assert_true(phase in [RunPhase.BATTLE, RunPhase.REWARD_CHOICE, RunPhase.ELITE_REWARD, RunPhase.BOSS_REWARD, RunPhase.RUN_SUMMARY], "Battle action %s reaches a valid encounter destination" % action_id, failures)
	assert_true(scene.controller.snapshot().authoritative_snapshot == scene.controller.domain.checkpoint(), "Battle action %s refreshes the presentation from authoritative state" % action_id, failures)
	if phase == RunPhase.BATTLE:
		assert_help_prompt_visible(scene, phase, failures)

func press_action(scene, action_id: String, expected_phase: String, failures: Array[String]) -> void:
	var actions: Array = scene.controller.action_descriptors()
	var action_index := -1
	for index in actions.size():
		if str(actions[index].get("id", "")) == action_id:
			action_index = index
			break
	assert_true(action_index >= 0, "action %s is available on the current screen" % action_id, failures)
	if action_index < 0:
		return
	var button: Button = find_action_button(scene, action_id)
	assert_true(button is Button and not button.disabled and button.visible, "action %s has an enabled visible RunScene button" % action_id, failures)
	if not (button is Button) or button.disabled:
		return
	var command_count_before: int = scene.controller.domain.replay_record.commands.size()
	button.emit_signal("pressed")
	assert_true(scene.controller.domain.replay_record.commands.size() == command_count_before + 1, "action %s submits one accepted authoritative Command" % action_id, failures)
	assert_phase(scene, expected_phase, "selecting %s reaches %s" % [action_id, expected_phase], failures)
	assert_true(scene.controller.snapshot().authoritative_snapshot == scene.controller.domain.checkpoint(), "action %s refreshes the presentation from authoritative state" % action_id, failures)

func assert_actions_visible_and_enabled(scene, kind: String, expected_ids: Array, failures: Array[String]) -> void:
	var actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == kind)
	var actual_ids: Array[String] = []
	for action in actions:
		actual_ids.append(str(action.get("target_id", "")))
	actual_ids.sort()
	var sorted_expected: Array[String] = []
	for content_id in expected_ids:
		sorted_expected.append(str(content_id))
	sorted_expected.sort()
	assert_true(actual_ids == sorted_expected, "%s screen exposes the expected selectable content IDs" % kind, failures)
	for action in actions:
		var button: Button = find_action_button(scene, str(action.get("id", "")))
		assert_true(button != null and not button.disabled and button.visible, "%s choice %s is visibly enabled" % [kind, str(action.get("target_id", ""))], failures)
		if button != null:
			assert_true(not button.text.is_empty(), "%s choice has a visible label" % kind, failures)

func find_named_node(scene, node_name: String):
	return scene.find_child(node_name, true, false)

func find_action_button(scene, action_id: String) -> Button:
	for candidate in scene.find_children("*", "Button", true, false):
		if str(candidate.get_meta("run_action_id", "")) == action_id:
			return candidate
	return null

func assert_phase(scene, expected_phase: String, message: String, failures: Array[String]) -> void:
	assert_true(str(scene.controller.domain.state.phase) == expected_phase, message, failures)
	assert_true(str(scene.controller.snapshot().get("screen", "")) == "run.%s" % expected_phase.to_lower(), "presentation destination matches authoritative phase %s" % expected_phase, failures)
	if expected_phase in ["CHARACTER_SELECT", "CONTRACT_SELECT", "MAP_CHOICE", "BATTLE"]:
		assert_help_prompt_visible(scene, expected_phase, failures)

func assert_help_prompt(scene, phase: String, expected_text: String, failures: Array[String]) -> void:
	assert_help_prompt_visible(scene, phase, failures)
	var prompt = find_named_node(scene, "RunHelpPrompt")
	if prompt is Label:
		assert_true(prompt.text.contains(expected_text), "%s presents its expected visible next-step text" % phase, failures)

func assert_help_prompt_visible(scene, phase: String, failures: Array[String]) -> void:
	var prompt = find_named_node(scene, "RunHelpPrompt")
	assert_true(prompt is Label and prompt.visible, "RunHelpPrompt is visible at the %s destination" % phase, failures)

func _clear_test_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
