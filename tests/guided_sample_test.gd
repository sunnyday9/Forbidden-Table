extends RefCounted

const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const GuidedSampleSessionScript = preload("res://src/presentation/run/guided_sample_session.gd")
const GuidedSampleMapCatalogScript = preload("res://src/presentation/run/guided_sample_map_catalog.gd")
const LocalizationScript = preload("res://src/presentation/localization/localization.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const RunJourneyViewScript = preload("res://src/presentation/ui/run_journey_view.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunSceneScript = preload("res://scenes/run/run_scene.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_sample_uses_an_isolated_one_act_controller(failures)
	test_sample_replay_reconstructs_its_authored_map(failures)
	test_sample_map_is_a_short_reachable_slice(failures)
	test_only_accepted_instructed_actions_advance_the_sample(failures)
	test_complete_hand_does_not_satisfy_the_pattern_step(failures)
	test_refinement_token_service_teaches_and_creates_an_extra_copy(failures)
	test_refinement_token_workshop_preview_shows_copy_outcome(failures)
	test_real_actions_can_complete_the_full_sample_sequence(failures)
	test_skip_restart_and_exit_are_isolated(failures)
	await test_run_scene_entry_restart_skip_and_cancel_preserve_campaign(failures)
	return failures

func test_sample_uses_an_isolated_one_act_controller(failures: Array[String]) -> void:
	var registry_builder = RunSceneScript.new()
	var registry_result: Dictionary = registry_builder._validated_content_registry()
	registry_builder.free()
	assert_true(registry_result.get("accepted", false), "Guided Sample receives the same validated game content registry", failures)
	if not registry_result.get("accepted", false):
		return
	var session = GuidedSampleSessionScript.new()
	var started: Dictionary = session.start(registry_result.registry, 53005)
	assert_true(started.get("accepted", false), "a validated content registry starts a Guided Sample", failures)
	assert_true(session.status == GuidedSampleSessionScript.STATUS_ACTIVE, "the started sample is active", failures)
	assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_CHARACTER, "the sample begins at Character selection", failures)
	assert_true(session.controller != null and session.controller.domain.state.phase == RunPhaseScript.CHARACTER_SELECT, "the sample enters the real Character selection screen", failures)
	assert_true(session.controller != null and session.controller.domain.state.act_count == 1, "the curated sample is a one-Act slice", failures)
	assert_true(session.controller != null and session.controller.meta_progress_coordinator == null, "the sample controller has no campaign meta-progression adapter", failures)
	assert_true(session.controller != null and session.controller.suspend_store == null, "the sample controller has no campaign suspend-save adapter", failures)
	assert_true(session.controller != null and session.controller.domain.state.run_id.begins_with("guided-sample."), "the isolated domain uses a separate Guided Sample identity", failures)
	assert_true(session.controller != null and session.controller.domain.state.gold >= 7, "the sample includes isolated Gold for practicing an affordable Workshop service", failures)
	var sample_registry = session.controller.domain.content_registry
	var practice_enemy = sample_registry.resolve(GuidedSampleMapCatalogScript.PRACTICE_ENEMY)
	var action_enemy = sample_registry.resolve(GuidedSampleMapCatalogScript.ACTION_PRACTICE_ENEMY)
	var action_encounter = sample_registry.resolve(GuidedSampleMapCatalogScript.PRACTICE_ENCOUNTER)
	assert_true(sample_registry != registry_result.registry and practice_enemy != null and practice_enemy.max_hp == 60 and int(practice_enemy.battle_values.get("pressure_limit", 0)) == 60, "the sample gets its own forgiving practice encounter", failures)
	assert_true(action_encounter != null and action_enemy != null and action_enemy.max_hp == 1 and int(action_enemy.battle_values.get("pressure_limit", 0)) == 999, "the second practice encounter leaves room to learn before the guided battle ends", failures)
	assert_true(session.step_descriptors().size() >= 12, "the guided sequence covers onboarding, core battle actions, and the service stops", failures)
	assert_true(not session.highlighted_action_ids(session.controller.action_descriptors()).is_empty(), "the current instruction can emphasize an available Character action", failures)

func test_sample_map_is_a_short_reachable_slice(failures: Array[String]) -> void:
	var map = GuidedSampleMapCatalogScript.definition()
	assert_true(map.graph_issues().is_empty(), "the sample's authored map has no dead ends or unreachable tutorial stops", failures)
	assert_true(map.count_nodes_of_kind("EVENT") == 2, "the post-Battle map choice offers a readable and a risky Event route", failures)
	assert_true(map.count_nodes_of_kind("BATTLE") == 2, "the compact sample separates full-hand and core-action practice across two short battles", failures)
	assert_true(map.count_nodes_of_kind("SHOP") == 1 and map.count_nodes_of_kind("WORKSHOP") == 1, "the sample reaches one Shop and one Workshop stop", failures)
	assert_true(map.branch_decision_count_before(GuidedSampleMapCatalogScript.SHOP_NODE) == 1, "the route shows a real choice before the shared service stops", failures)
	assert_true(map.has_route_through([GuidedSampleMapCatalogScript.EVENT_BARGAIN_NODE, GuidedSampleMapCatalogScript.SHOP_NODE, GuidedSampleMapCatalogScript.WORKSHOP_NODE], GuidedSampleMapCatalogScript.BOSS_NODE), "the risk route rejoins the short Event, Shop, Workshop path", failures)

func test_sample_replay_reconstructs_its_authored_map(failures: Array[String]) -> void:
	var session = _new_session(failures)
	if session == null:
		return
	var attempts := 0
	while session.current_step_id != GuidedSampleSessionScript.STEP_INTENT and attempts < 4:
		attempts += 1
		var highlighted: Array[String] = session.highlighted_action_ids(session.controller.action_descriptors())
		if highlighted.is_empty():
			assert_true(false, "the sample has a legal action while reaching its first Battle", failures)
			return
		var result = session.controller.confirm(highlighted[0])
		if result == null or not result.accepted:
			assert_true(false, "the sample accepts each action before its first Battle", failures)
			return
	assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_INTENT, "the sample reaches its first Battle through Character, Contract, and map Commands", failures)
	var replay_report = session.controller.domain.verify_replay()
	assert_true(replay_report.is_match(), "accepted Guided Sample actions replay with the authored sample map (%s: %s)" % [replay_report.status, replay_report.reason], failures)

func test_only_accepted_instructed_actions_advance_the_sample(failures: Array[String]) -> void:
	var session = _new_session(failures)
	if session == null:
		return
	var character_action: Dictionary = _first_action(session.controller.action_descriptors(), "CHARACTER")
	assert_true(not character_action.is_empty(), "the sample presents real Character actions", failures)
	var rejected = session.controller.submit(ChooseCharacterCommandScript.new("sample.invalid.character", "missing.character"))
	assert_true(not rejected.accepted, "an invalid Character choice is rejected by the normal Run command rules", failures)
	assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_CHARACTER, "a rejected or loosely related change cannot complete Character selection", failures)
	var accepted = session.controller.submit(ChooseCharacterCommandScript.new("sample.character", str(character_action.get("target_id", ""))))
	assert_true(accepted.accepted, "the instructed Character choice is an accepted Run command (%s)" % str(accepted.validation.code), failures)
	assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_CONTRACT, "only that accepted Character command advances to Contract selection", failures)
	var contract_action: Dictionary = _first_action(session.controller.action_descriptors(), "CONTRACT")
	var contract_result = session.controller.submit(ChooseContractCommandScript.new("sample.contract", str(contract_action.get("target_id", ""))))
	assert_true(contract_result.accepted, "the instructed Contract choice is accepted", failures)
	assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_INTRO_ROUTE, "a Contract side effect cannot skip the next map instruction", failures)
	var unrelated_result = session.controller.submit(DrawCommandScript.new("sample.out_of_phase.draw"))
	assert_true(not unrelated_result.accepted, "a command from another phase stays rejected by the domain", failures)
	assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_INTRO_ROUTE, "an unrelated command does not skip the map step", failures)

func test_complete_hand_does_not_satisfy_the_pattern_step(failures: Array[String]) -> void:
	var session = _new_session(failures)
	if session == null:
		return
	var attempts := 0
	while session.current_step_id != GuidedSampleSessionScript.STEP_PATTERN and attempts < 100:
		attempts += 1
		var highlighted: Array[String] = session.highlighted_action_ids(session.controller.action_descriptors())
		if highlighted.is_empty():
			assert_true(false, "the sample can reach its Pattern instruction using legal actions", failures)
			return
		var result = session.controller.confirm(highlighted[0])
		if result == null or not result.accepted:
			assert_true(false, "the sample accepts its legal setup action before Pattern", failures)
			return
	assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_PATTERN, "the sample reaches the distinct Pattern instruction", failures)
	if session.current_step_id != GuidedSampleSessionScript.STEP_PATTERN:
		return
	var complete_hand_action := {"id": "sample.complete_hand.substitute", "kind": "COMPLETE_HAND"}
	assert_true(session.highlighted_action_ids([complete_hand_action]).is_empty(), "Complete Hand is not offered as a substitute for Pattern settlement", failures)
	var battle_phase: String = session.controller.domain.state.phase
	session.controller.domain.state.phase = RunPhaseScript.REWARD_CHOICE
	session.controller.command_processed.emit(SampleCompleteHandCommand.new(), SampleAcceptedResult.new())
	assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_PATTERN, "an accepted Complete Hand result cannot advance the Pattern instruction", failures)
	session.controller.domain.state.phase = battle_phase

func test_refinement_token_service_teaches_and_creates_an_extra_copy(failures: Array[String]) -> void:
	var session = _new_session(failures)
	if session == null:
		return
	var attempts := 0
	while session.is_active() and session.current_step_id != GuidedSampleSessionScript.STEP_WORKSHOP_SERVICE and attempts < 180:
		attempts += 1
		var actions: Array = session.controller.action_descriptors()
		var highlighted: Array[String] = session.highlighted_action_ids(actions)
		if highlighted.is_empty():
			assert_true(false, "the sample reaches its Refinement Token Workshop lesson using legal actions", failures)
			return
		var result = session.controller.confirm(highlighted[0])
		if not _result_accepted(result):
			assert_true(false, "the sample accepts each action before the Refinement Token Workshop lesson", failures)
			return
	assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_WORKSHOP_SERVICE, "the sample reaches the dedicated Workshop service instruction", failures)
	if session.current_step_id != GuidedSampleSessionScript.STEP_WORKSHOP_SERVICE:
		return

	var prompt_key: String = session.current_prompt_key()
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var english_prompt := LocalizationScript.text(prompt_key)
	TranslationServer.set_locale("zh_CN")
	var chinese_prompt := LocalizationScript.text(prompt_key)
	TranslationServer.set_locale(previous_locale)
	assert_true(english_prompt.contains("1 Refinement Token") and english_prompt.contains("Gold") and english_prompt.contains("extra copy of the chosen tile"), "the English lesson explains the token and Gold cost and the extra copy effect", failures)
	assert_true(chinese_prompt.contains("1 枚精炼代币") and chinese_prompt.contains("金币") and chinese_prompt.contains("额外副本"), "the Chinese lesson explains the token and Gold cost and the extra copy effect", failures)

	var domain = session.controller.domain
	assert_true(domain.state.refinement_tokens >= 1, "the isolated Workshop sample guarantees a Refinement Token", failures)
	var workshop_actions: Array = session.controller.action_descriptors()
	var emphasized_ids: Array[String] = session.highlighted_action_ids(workshop_actions)
	assert_true(not emphasized_ids.is_empty(), "the Refinement Token lesson highlights an available service", failures)
	if emphasized_ids.is_empty():
		return
	var emphasized_action := _action_by_id(workshop_actions, emphasized_ids[0])
	assert_true(str(emphasized_action.get("kind", "")) == "WORKSHOP_SELECT_SERVICE" and str(emphasized_action.get("service_id", "")) == "REFINEMENT_TOKEN", "the lesson emphasizes the Refinement Token service", failures)
	if str(emphasized_action.get("service_id", "")) != "REFINEMENT_TOKEN":
		return

	var copied_tile_id := ""
	var gold_before := 0
	var tokens_before := 0
	var copy_count_before := 0
	var service_completed := false
	var service_attempts := 0
	while session.current_step_id == GuidedSampleSessionScript.STEP_WORKSHOP_SERVICE and service_attempts < 4:
		service_attempts += 1
		workshop_actions = session.controller.action_descriptors()
		emphasized_ids = session.highlighted_action_ids(workshop_actions)
		if emphasized_ids.is_empty():
			assert_true(false, "each Refinement Token tutorial substep has a legal emphasized action", failures)
			return
		emphasized_action = _action_by_id(workshop_actions, emphasized_ids[0])
		if str(emphasized_action.get("kind", "")) == "WORKSHOP_SERVICE":
			copied_tile_id = str(emphasized_action.get("details", {}).get("tile_definition_id", ""))
			gold_before = int(domain.state.gold)
			tokens_before = int(domain.state.refinement_tokens)
			copy_count_before = _tile_definition_count(domain, copied_tile_id)
		var result = session.controller.confirm(emphasized_ids[0])
		if not _result_accepted(result):
			assert_true(false, "the real controller accepts the emphasized Refinement Token action", failures)
			return
		if str(emphasized_action.get("kind", "")) == "WORKSHOP_SERVICE":
			service_completed = true
			var price := int(emphasized_action.get("details", {}).get("price", 0))
			assert_true(price > 0 and gold_before - int(domain.state.gold) == price, "the real Refinement Token service spends its displayed Gold price", failures)
			assert_true(tokens_before == int(domain.state.refinement_tokens) + 1, "the real Refinement Token service spends exactly one token", failures)
			assert_true(_tile_definition_count(domain, copied_tile_id) == copy_count_before + 1, "the special service creates one extra copy of the selected tile", failures)
			var copy_limit_break_recorded := false
			for event in result.events:
				if event is DomainEventScript and event.event_type == DomainEventScript.WORKSHOP_SERVICE_USED and str(event.data.get("refinement", "")) == "COPY_LIMIT_BREAK":
					copy_limit_break_recorded = true
			assert_true(copy_limit_break_recorded, "the real Refinement Token action retains its dedicated copy-limit behavior", failures)
			assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_EXIT_WORKSHOP, "using the actual Refinement Token service completes the Workshop lesson", failures)
	assert_true(service_completed, "the sample executes the Refinement Token service instead of only mentioning it", failures)
	var replay_report = domain.verify_replay()
	assert_true(replay_report.is_match(), "the initial sample token and its Workshop use replay from the constructor baseline (%s: %s)" % [replay_report.status, replay_report.reason], failures)

func test_refinement_token_workshop_preview_shows_copy_outcome(failures: Array[String]) -> void:
	var session = _new_session(failures)
	if session == null:
		return
	var attempts := 0
	while session.is_active() and session.current_step_id != GuidedSampleSessionScript.STEP_WORKSHOP_SERVICE and attempts < 180:
		attempts += 1
		var actions: Array = session.controller.action_descriptors()
		var highlighted: Array[String] = session.highlighted_action_ids(actions)
		if highlighted.is_empty():
			assert_true(false, "the sample reaches the token-preview regression using legal actions", failures)
			return
		var result = session.controller.confirm(highlighted[0])
		if not _result_accepted(result):
			assert_true(false, "the sample accepts actions before the token-preview regression", failures)
			return
	if session.current_step_id != GuidedSampleSessionScript.STEP_WORKSHOP_SERVICE:
		assert_true(false, "the token-preview regression reaches its Workshop instruction", failures)
		return

	var original_locale := TranslationServer.get_locale()
	var tree := Engine.get_main_loop() as SceneTree
	var attempts_to_result := 0
	while attempts_to_result < 4:
		attempts_to_result += 1
		var actions: Array = session.controller.action_descriptors()
		var highlighted: Array[String] = session.highlighted_action_ids(actions)
		if highlighted.is_empty():
			assert_true(false, "the token-preview regression has a legal Workshop action", failures)
			break
		var action := _action_by_id(actions, highlighted[0])
		if str(action.get("kind", "")) == "WORKSHOP_SERVICE":
			var price := int(action.get("details", {}).get("price", 0))
			var view = RunJourneyViewScript.new()
			tree.root.add_child(view)
			view.configure(Callable(), Callable(), Callable(), Callable(), Callable())
			TranslationServer.set_locale("en")
			view.set_presentation_preferences("en")
			view.render(session.controller, [action], str(action.get("id", "")))
			var english_preview := str((view.find_child("WorkshopBeforeAfter", true, false) as Label).text)
			TranslationServer.set_locale("zh_CN")
			view.set_presentation_preferences("zh_CN")
			view.render(session.controller, [action], str(action.get("id", "")))
			var chinese_preview := str((view.find_child("WorkshopBeforeAfter", true, false) as Label).text)
			view.free()
			TranslationServer.set_locale(original_locale)
			assert_true(english_preview.contains("gains 1 extra copy") and english_preview.contains("Cost: %d Gold" % price) and english_preview.contains("Also consumes: 1 Refinement Token") and not english_preview.contains("→ "), "the rendered English token-service preview names the extra-copy outcome and retains both costs", failures)
			assert_true(chinese_preview.contains("增加 1 份额外副本") and chinese_preview.contains("费用：%d 金币" % price) and chinese_preview.contains("还会消耗：1 枚精炼代币") and not chinese_preview.contains("→ "), "the rendered Chinese token-service preview names the extra-copy outcome and retains both costs", failures)
			return
		var result = session.controller.confirm(highlighted[0])
		if not _result_accepted(result):
			assert_true(false, "the token-preview regression accepts Workshop setup actions", failures)
			break
	TranslationServer.set_locale(original_locale)
	assert_true(false, "the token-preview regression sees a real Refinement Token service descriptor", failures)

func _tile_definition_count(domain, definition_id: String) -> int:
	var count := 0
	for tile_instance in domain.state.tile_pool.tile_instances:
		if str(tile_instance.definition_id) == definition_id:
			count += 1
	return count

func _result_accepted(result) -> bool:
	if result == null:
		return false
	return bool(result.get("accepted", false)) if result is Dictionary else bool(result.accepted)

func test_real_actions_can_complete_the_full_sample_sequence(failures: Array[String]) -> void:
	var session = _new_session(failures)
	if session == null:
		return
	var completed_steps: Array[String] = []
	var executed_workshop_service := false
	var attempts := 0
	while session.is_active() and attempts < 240:
		attempts += 1
		var step_id: String = session.current_step_id
		var available_actions: Array = session.controller.action_descriptors()
		var highlighted: Array[String] = session.highlighted_action_ids(available_actions)
		var selected_action: Dictionary = _action_by_id(available_actions, highlighted[0]) if not highlighted.is_empty() else {}
		var phase := str(session.controller.domain.state.phase)
		var terminal_outcome := str(session.controller.domain.state.terminal_summary.outcome)
		var terminal_reason := str(session.controller.domain.state.terminal_summary.reason)
		assert_true(not highlighted.is_empty(), "sample step %s has a legal, emphasized action (phase %s, outcome %s: %s)" % [step_id, phase, terminal_outcome, terminal_reason], failures)
		if highlighted.is_empty():
			return
		var selected_kind := str(selected_action.get("kind", ""))
		if step_id == GuidedSampleSessionScript.STEP_PATTERN and selected_kind in ["COMPLETE_HAND", "PARTIAL_SETTLEMENT"]:
			assert_true(selected_kind == "PARTIAL_SETTLEMENT", "the Pattern lesson emphasizes tile-based Pattern settlement rather than repeating Complete Hand", failures)
		var result = session.controller.confirm(highlighted[0])
		var result_accepted := result != null and (bool(result.get("accepted", false)) if result is Dictionary else bool(result.get("accepted")))
		var result_code := str(result.get("validation", {}).get("code", "")) if result is Dictionary else (str(result.validation.code) if result != null else "NO_RESULT")
		var result_message := str(result.get("validation", {}).get("message", "")) if result is Dictionary else (str(result.validation.message) if result != null else "")
		assert_true(result_accepted, "the real controller accepts the guided %s action (%s: %s)" % [step_id, result_code, result_message], failures)
		if not result_accepted:
			return
		if step_id == GuidedSampleSessionScript.STEP_ENTER_WORKSHOP:
			assert_true(session.current_step_id == "guided_sample.workshop_service", "entering the Workshop opens a separate service instruction", failures)
			var service_actions: Array[String] = session.highlighted_action_ids(session.controller.action_descriptors())
			assert_true(not service_actions.is_empty(), "the Workshop instruction highlights a legal service choice", failures)
		elif step_id == "guided_sample.workshop_service" and selected_kind == "WORKSHOP_SERVICE":
			executed_workshop_service = true
			assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_EXIT_WORKSHOP, "the actual Workshop service completes before the exit instruction", failures)
		if session.completed_step_count() > completed_steps.size():
			assert_true(session.completed_step_count() == completed_steps.size() + 1, "the accepted %s action advances exactly one instructed stop" % step_id, failures)
			completed_steps.append(step_id)
			if step_id == GuidedSampleSessionScript.STEP_PATTERN:
				var victory_transferred := false
				for event in result.events:
					if event is DomainEventScript and event.event_type == DomainEventScript.BATTLE_OUTCOME_TRANSFERRED and str(event.data.get("outcome", "")) == "VICTORY":
						victory_transferred = true
				assert_true(victory_transferred and session.controller.domain.state.phase == RunPhaseScript.REWARD_CHOICE, "the taught Pattern resolves a real victory and enters the normal reward phase", failures)
		else:
			var expected_kinds: Array = session.current_step().get("action_kinds", [])
			var is_step_action: bool = expected_kinds.has(str(selected_action.get("kind", "")))
			var is_fallback_action: bool = GuidedSampleSessionScript.BATTLE_SETUP_FALLBACK_STEPS.has(step_id) and str(selected_action.get("kind", "")) in ["DRAW", "END_TURN"]
			var allowed_preparation: bool = (is_step_action or is_fallback_action) and session.current_step_id == step_id
			assert_true(allowed_preparation, "a preparatory Battle action can help form the guided action but cannot skip that step", failures)
	var remaining_battle = session.controller.domain.current_battle
	var battle_state := "%s/%s" % [str(remaining_battle.combat_state.enemy_hp), str(remaining_battle.combat_state.pressure)] if remaining_battle != null else "none"
	assert_true(session.status == GuidedSampleSessionScript.STATUS_COMPLETED, "the complete curated sequence reaches the sample-complete state at %s (%d/%d, %s)" % [session.current_step_id, completed_steps.size(), session.step_descriptors().size(), battle_state], failures)
	assert_true(completed_steps.size() == session.step_descriptors().size(), "the sample exercises every authored instruction once", failures)
	assert_true(executed_workshop_service, "the sample executes a real Workshop service before it finishes", failures)

func test_skip_restart_and_exit_are_isolated(failures: Array[String]) -> void:
	var session = _new_session(failures)
	if session == null:
		return
	var original_controller = session.controller
	assert_true(session.skip(), "the player can skip the optional sample", failures)
	assert_true(session.status == GuidedSampleSessionScript.STATUS_SKIPPED, "skip records only an in-memory sample status", failures)
	assert_true(session.restart(), "the player can restart the sample", failures)
	assert_true(session.status == GuidedSampleSessionScript.STATUS_ACTIVE, "restart reopens the sample", failures)
	assert_true(session.controller != original_controller, "restart creates a fresh isolated run controller", failures)
	assert_true(session.current_step_id == GuidedSampleSessionScript.STEP_CHARACTER, "restart returns to the first instruction", failures)
	assert_true(session.controller.meta_progress_coordinator == null and session.controller.suspend_store == null, "restart still has no campaign persistence adapters", failures)
	assert_true(session.exit(), "the player can exit the sample", failures)
	assert_true(session.status == GuidedSampleSessionScript.STATUS_EXITED, "exit leaves the sample without recording campaign progress", failures)

func test_run_scene_entry_restart_skip_and_cancel_preserve_campaign(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var suspend_path := "user://guided_sample_suspend_%s.json" % suffix
	var profile_path := "user://guided_sample_profile_%s.json" % suffix
	var scene = RunSceneScript.new()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var campaign_controller = scene.controller
	var campaign_profile_before: Dictionary = scene.meta_progress_coordinator.state.to_dictionary()
	var campaign_phase_before := str(campaign_controller.domain.state.phase)
	var suspend_before := _file_snapshot(suspend_path)
	var profile_before := _file_snapshot(profile_path)
	var entry_button: Button = scene.find_child("GuidedSampleButton", true, false) as Button
	assert_true(entry_button != null and entry_button.visible and not entry_button.disabled, "the Run screen offers a separate Guided Sample entry", failures)
	if entry_button == null:
		scene.free()
		_clear_test_file(suspend_path)
		_clear_test_file(profile_path)
		return
	entry_button.emit_signal("pressed")
	var first_session = scene._guided_sample_session
	assert_true(first_session != null and first_session.is_active(), "the entry opens an active sample", failures)
	assert_true(scene.controller != campaign_controller and scene.controller.meta_progress_coordinator == null and scene.controller.suspend_store == null, "the sample swaps in an isolated controller without save adapters", failures)
	assert_true(scene._tutorial_prompt.visible and scene._tutorial_prompt.text == LocalizationScript.text(first_session.current_prompt_key()), "the active step presents its localized in-game instruction", failures)
	var first_sample_controller = scene.controller
	var character_action: Dictionary = _first_action(scene.controller.action_descriptors(), "CHARACTER")
	var character_button: Button = scene._journey_view.action_button(str(character_action.get("id", ""))) as Button
	assert_true(character_button != null, "the isolated sample shows its normal Character choice button", failures)
	assert_true(character_button != null and bool(character_button.get_meta("guided_sample_emphasis", false)), "the instructed action is visually emphasized", failures)
	if character_button != null:
		character_button.grab_focus()
		_send_key(scene, KEY_ENTER)
		assert_true(str(scene._journey_view.selected_action().get("id", "")) == str(character_action.get("id", "")), "keyboard accept selects the instructed Character action", failures)
		scene._commit_selected_button.grab_focus()
		_send_joypad_button(scene, JOY_BUTTON_A)
	assert_true(first_sample_controller.domain.state.character_id != "", "a player action changes the sample domain", failures)
	assert_true(campaign_controller.domain.state.phase == campaign_phase_before and campaign_controller.domain.state.character_id == "", "sample choices leave the suspended campaign controller unchanged", failures)
	assert_true(scene.meta_progress_coordinator.state.to_dictionary() == campaign_profile_before, "sample choices do not alter campaign unlocks", failures)
	assert_true(_file_snapshot(suspend_path) == suspend_before and _file_snapshot(profile_path) == profile_before, "sample choices do not write campaign saves or profile files", failures)
	var restart_button: Button = scene.find_child("GuidedSampleRestartButton", true, false) as Button
	assert_true(restart_button != null and restart_button.visible, "an active sample exposes Restart", failures)
	if restart_button != null:
		restart_button.emit_signal("pressed")
	assert_true(scene.controller != first_sample_controller and scene._guided_sample_session.current_step_id == GuidedSampleSessionScript.STEP_CHARACTER, "Restart creates a fresh sample at the first step", failures)
	var skip_button: Button = scene.find_child("GuidedSampleSkipButton", true, false) as Button
	assert_true(skip_button != null and skip_button.visible, "an active sample exposes Skip", failures)
	if skip_button != null:
		skip_button.emit_signal("pressed")
	assert_true(scene.controller == campaign_controller and first_session.status == GuidedSampleSessionScript.STATUS_SKIPPED, "Skip returns to the untouched campaign", failures)
	assert_true(entry_button.visible and not entry_button.disabled, "the optional sample remains available after skipping", failures)
	entry_button.emit_signal("pressed")
	assert_true(scene.controller != campaign_controller and scene._guided_sample_session != first_session and scene._guided_sample_session.is_active(), "the player can enter a fresh sample after skipping", failures)
	var exit_button: Button = scene.find_child("GuidedSampleExitButton", true, false) as Button
	assert_true(exit_button != null and exit_button.visible, "an active sample exposes Exit Sample", failures)
	_send_key(scene, KEY_ESCAPE)
	assert_true(scene.controller == campaign_controller, "Cancel exits the sample and restores the current Run", failures)
	assert_true(_file_snapshot(suspend_path) == suspend_before and _file_snapshot(profile_path) == profile_before, "Skip and Cancel leave campaign files unchanged", failures)
	entry_button.emit_signal("pressed")
	if exit_button != null:
		exit_button.emit_signal("pressed")
	assert_true(scene.controller == campaign_controller, "the Exit Sample button returns to the current Run", failures)
	scene._pending_resume_domain = campaign_controller.domain
	scene._show_valid_suspend_choice(campaign_controller.domain)
	scene._set_active_controller(null)
	scene._render()
	assert_true(scene._suspend_choice_panel.visible, "the saved-run recovery choice is visible before entering the sample", failures)
	scene._on_guided_sample_pressed()
	assert_true(scene._guided_sample_session != null and not scene._suspend_choice_panel.visible, "the sample can open above a saved-run recovery choice", failures)
	_send_joypad_button(scene, JOY_BUTTON_B)
	assert_true(scene.controller == null and scene._suspend_choice_panel.visible and scene._resume_run_button.visible, "exiting the sample restores the saved-run recovery choice", failures)
	if scene._suspend_choice_panel.visible and scene._resume_run_button.visible:
		scene._resume_run_button.emit_signal("pressed")
	assert_true(scene.controller != null and scene.controller.domain == campaign_controller.domain and not scene._suspend_choice_panel.visible, "the saved Run remains resumable after leaving the sample", failures)
	scene.queue_free()
	await tree.process_frame
	_clear_test_file(suspend_path)
	_clear_test_file(profile_path)

func _new_session(failures: Array[String]):
	var registry_builder = RunSceneScript.new()
	var registry_result: Dictionary = registry_builder._validated_content_registry()
	registry_builder.free()
	if not registry_result.get("accepted", false):
		assert_true(false, "Guided Sample test registry validates", failures)
		return null
	var session = GuidedSampleSessionScript.new()
	var started: Dictionary = session.start(registry_result.registry, 53005)
	if not started.get("accepted", false):
		assert_true(false, "Guided Sample test session starts", failures)
		return null
	return session

func _first_action(actions: Array, kind: String) -> Dictionary:
	for action in actions:
		if action is Dictionary and str(action.get("kind", "")) == kind:
			return action
	return {}

func _action_by_id(actions: Array, action_id: String) -> Dictionary:
	for action in actions:
		if action is Dictionary and str(action.get("id", "")) == action_id:
			return action
	return {}

func _file_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "contents": ""}
	return {"exists": true, "contents": FileAccess.get_file_as_string(path)}

func _send_key(scene, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	scene._input(event)
	var release_event := event.duplicate() as InputEventKey
	release_event.pressed = false
	scene._input(release_event)

func _send_joypad_button(scene, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = true
	scene._input(event)
	var release_event := event.duplicate() as InputEventJoypadButton
	release_event.pressed = false
	scene._input(release_event)

func _clear_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

class SampleCompleteHandCommand:
	extends RefCounted

	func command_type() -> String:
		return "SettleCompleteHand"

class SampleAcceptedResult:
	extends RefCounted

	var accepted := true

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
