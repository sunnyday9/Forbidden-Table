class_name Stage45BattleUiTest
extends RefCounted

const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const BattleSceneScript = preload("res://scenes/battle/battle_scene.tscn")
const BattleViewScript = preload("res://src/presentation/ui/battle_view.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const EnemyIntentScript = preload("res://src/domain/combat/enemy_intent.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const TileFaceButtonScript = preload("res://src/presentation/ui/tile_face_button.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "Battle UI test runs inside SceneTree", failures)
	if tree == null:
		return failures
	var controller: Object = _battle_controller("stage45.battle-ui", failures)
	if controller == null:
		return failures
	var label_callable := func(action: Dictionary) -> String: return str(action.get("id", ""))
	var tooltip_callable := func(action: Dictionary) -> String: return str(action.get("kind", ""))
	var details_callable := func(action: Dictionary) -> String: return str(action.get("target_id", ""))
	var view := BattleViewScript.new()
	view.set_external_preferences_owner()
	view.configure(controller, label_callable, tooltip_callable, details_callable)
	tree.root.add_child(view)
	await tree.process_frame
	view.render()
	await tree.process_frame

	assert_true(controller.domain.state.phase == RunPhaseScript.BATTLE, "BattleView is attached to the live Run battle", failures)
	var initial_draw_button := view.action_button("battle.draw")
	var action_panel := view.find_child("BattleActions", true, false) as Control
	assert_true(
		initial_draw_button != null and initial_draw_button.size.x >= 200.0,
		"Battle action choices retain a readable width (button=%s, action_panel=%s)" % [str(initial_draw_button.size if initial_draw_button != null else Vector2.ZERO), str(action_panel.size if action_panel != null else Vector2.ZERO)],
		failures,
	)
	assert_true(view.find_child("BattleEnemyHP", true, false) != null, "enemy HP is rendered as an explicit battle fact", failures)
	assert_true(view.find_child("BattleIntentType", true, false) != null, "typed enemy Intent is rendered", failures)
	assert_true(view.find_child("BattleResources", true, false) != null, "battle resources are rendered", failures)
	assert_true(view.find_child("BattleHandHeading", true, false) != null, "the current Hand is rendered", failures)
	var live_battle = controller.domain.current_battle
	var intent_checkpoint_before: Dictionary = controller.domain.checkpoint()
	var original_intent = live_battle.combat_state.current_intent
	var canonical_intent_name := LocalizationCatalogScript.canonical_text("CONTENT_PHASE2_0019")
	live_battle.combat_state.current_intent = EnemyIntentScript.new(
		"stage45.test.table-interference",
		canonical_intent_name,
		2,
		EnemyIntentScript.TABLE_INTERFERENCE,
	)
	view.render()
	var typed_intent_label := view.find_child("BattleIntentType", true, false) as Label
	var typed_intent_detail := view.find_child("BattleIntentDetail", true, false) as Label
	assert_true(
		typed_intent_label != null and typed_intent_label.text == LocalizationCatalogScript.format("UI_BATTLE_VIEW_0048", [LocalizationCatalogScript.display_text(canonical_intent_name), LocalizationCatalogScript.text("UI_BATTLE_VIEW_0039")]),
		"non-Pressure intent keeps its canonical localized display name and translated type",
		failures,
	)
	assert_true(
		typed_intent_detail != null and typed_intent_detail.text == LocalizationCatalogScript.format("UI_BATTLE_VIEW_0053", [2]),
		"non-Pressure intent displays its resolver effect amount with the correct effect semantics",
		failures,
	)
	live_battle.combat_state.current_intent = original_intent
	view.render()
	assert_true(controller.domain.checkpoint() == intent_checkpoint_before, "typed intent presentation leaves the authoritative Run unchanged", failures)
	controller.domain.current_battle = {
		"encounter_id": str(live_battle.encounter_id),
		"combat_state": {"boss_phase_index": 1, "boss_phase_count": 3},
	}
	controller.state.last_domain_event_types = ["CompleteHandSettled", "BossPhaseChanged"]
	var completion_receipt := view.sync_persistent_receipt()
	var completion_marker := LocalizationCatalogScript.text("UI_BATTLE_VIEW_0046")
	var phase_marker := LocalizationCatalogScript.format("UI_BATTLE_VIEW_0007", [LocalizationCatalogScript.text("UI_BATTLE_VIEW_0035"), 2, 3])
	assert_true(completion_receipt.find(completion_marker) >= 0 and completion_receipt.find(phase_marker) > completion_receipt.find(completion_marker), "critical feedback preserves Complete Hand before Boss Phase: %s" % completion_receipt, failures)
	controller.domain.current_battle = null
	controller.state.last_domain_event_types = ["BattleWon"]
	var reward_receipt := view.sync_persistent_receipt()
	var victory_marker := LocalizationCatalogScript.text("UI_BATTLE_VIEW_0047")
	assert_true(reward_receipt.find(phase_marker) > reward_receipt.find(completion_marker) and reward_receipt.find(victory_marker) > reward_receipt.find(phase_marker), "the ordered completion receipt persists and appends Victory when current_battle is cleared: %s" % reward_receipt, failures)
	var saved_translation_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var chinese_receipt := view.persistent_receipt_text()
	var chinese_completion_marker := LocalizationCatalogScript.text("UI_BATTLE_VIEW_0046")
	var chinese_phase_marker := LocalizationCatalogScript.format("UI_BATTLE_VIEW_0007", [LocalizationCatalogScript.text("UI_BATTLE_VIEW_0035"), 2, 3])
	var chinese_victory_marker := LocalizationCatalogScript.text("UI_BATTLE_VIEW_0047")
	assert_true(chinese_receipt.find(chinese_completion_marker) >= 0 and chinese_receipt.find(chinese_phase_marker) > chinese_receipt.find(chinese_completion_marker) and chinese_receipt.find(chinese_victory_marker) > chinese_receipt.find(chinese_phase_marker), "the persistent Battle receipt localizes every ordered cue when language changes", failures)
	TranslationServer.set_locale(saved_translation_locale)
	assert_true(view.persistent_receipt_text() == reward_receipt, "the persistent Battle receipt returns to the current language without mixed-language values", failures)
	controller.domain.current_battle = live_battle
	controller.state.last_domain_event_types = []
	for action in controller.action_descriptors():
		assert_true(view.action_button(str(action.get("id", ""))) != null, "every legal Run battle action has a matching choice control", failures)
	assert_true(view.find_child("BattleSection_UI_BATTLE_VIEW_0013", true, false) != null, "Partial Settlement retains a visible Pattern choice section", failures)
	assert_true(view.find_child("BattleSection_UI_BATTLE_VIEW_0014", true, false) != null, "Complete Hand retains a visible full-hand choice section", failures)
	assert_true(view.find_child("BattleSection_UI_BATTLE_VIEW_0016", true, false) != null, "Technique retains a visible choice or empty-state section", failures)

	var initial_hand: Array = controller.domain.current_battle.zones.contents(TileZoneScript.HAND)
	assert_true(not initial_hand.is_empty(), "the real battle starts with physical Hand instances", failures)
	if initial_hand.is_empty():
		view.queue_free()
		await tree.process_frame
		return failures
	var first_tile = initial_hand[0]
	var first_face: TileFaceButton = view._tile_button(str(first_tile.instance_id))
	assert_true(first_face != null, "each Hand tile keeps its exact instance id in the rendered face", failures)
	if first_face != null:
		assert_true(first_face.tile_definition_id == str(first_tile.definition_id), "tile face uses the same registered tile definition", failures)
		assert_true(first_face.face_rect.texture != null, "tile face loads its exact Chinese tile PNG", failures)
		assert_true(first_face.tooltip_text.find(str(first_tile.instance_id)) >= 0, "tile inspection exposes the exact copy label", failures)

	var focused_ids: Array[String] = []
	view.focus_requested.connect(func(action_id: String) -> void: focused_ids.append(action_id))
	var draw_button := view.action_button("battle.draw")
	var before_focus: Dictionary = controller.domain.checkpoint()
	if draw_button != null:
		draw_button.grab_focus()
		await tree.process_frame
		assert_true(focused_ids.has("battle.draw"), "keyboard focus requests details for the focused action", failures)
		assert_true(view.selected_action_id.is_empty(), "focus inspection does not select the action", failures)
		assert_true(controller.domain.checkpoint() == before_focus, "focus inspection issues no command", failures)

	var same_draw_button := draw_button
	assert_true(not view.set_presentation_preferences("en", 1.0, "NORMAL", false, false), "unchanged presentation preferences are a no-op", failures)
	assert_true(view.action_button("battle.draw") == same_draw_button, "unchanged preferences do not rebuild battle controls", failures)
	assert_true(view.set_presentation_preferences("en", 1.0, "NORMAL", false, false) == false, "Draw uses Normal presentation mode", failures)
	var initial_hand_ids: Array[String] = []
	for tile in initial_hand:
		initial_hand_ids.append(str(tile.instance_id))
	var requested_ids: Array[String] = []
	var root_render_count: Array[int] = [0]
	view.action_requested.connect(func(action_id: String) -> void:
		requested_ids.append(action_id)
		controller.confirm(action_id)
	)
	controller.presentation_changed.connect(func() -> void:
		root_render_count[0] += 1
		view.render()
	)
	if draw_button != null:
		draw_button.emit_signal("pressed")
	view.commit_button().emit_signal("pressed")
	assert_true(requested_ids == ["battle.draw"], "the root Draw action submits exactly one selected battle command", failures)
	assert_true(root_render_count[0] == 1, "the root renders BattleView once after Draw (count=%d)" % root_render_count[0], failures)
	assert_true(controller.domain.state.phase == RunPhaseScript.BATTLE, "the accepted Draw keeps the actual Run in Battle", failures)
	var after_draw_hand: Array = controller.domain.current_battle.zones.contents(TileZoneScript.HAND)
	var drawn_ids: Array[String] = []
	for tile in after_draw_hand:
		if not initial_hand_ids.has(str(tile.instance_id)):
			drawn_ids.append(str(tile.instance_id))
	assert_true(not drawn_ids.is_empty(), "Draw adds a new physical tile instance to Hand", failures)
	if not drawn_ids.is_empty():
		var drawn_face := view._tile_button(drawn_ids[0])
		var tween_target = view.motion_feedback()._active_target.get_ref() if view.motion_feedback()._active_target != null else null
		assert_true(drawn_face != null and is_instance_valid(drawn_face), "the new Draw tile remains attached after the root render", failures)
		assert_true(tween_target == drawn_face, "Normal Draw feedback targets the newly rendered tile instance", failures)
	var reserve_actions: Array = controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "RESERVE")
	assert_true(not reserve_actions.is_empty(), "after Draw the real Run controller offers legal Reserve choices", failures)
	if reserve_actions.is_empty():
		view.queue_free()
		await tree.process_frame
		return failures
	var reserve_action: Dictionary = reserve_actions[0]
	var instance_id := str(reserve_action.get("target_id", ""))
	var tile_face: TileFaceButton = view._tile_button(instance_id)
	assert_true(tile_face != null, "Reserve choice points to the exact physical tile face", failures)
	var checkpoint_before_selection: Dictionary = controller.domain.checkpoint()
	var action_choice := view.action_button(str(reserve_action.get("id", "")))
	assert_true(action_choice != null, "the physical tile's Reserve choice is actionable", failures)
	if action_choice != null:
		action_choice.emit_signal("pressed")
		assert_true(view.selected_action_id == str(reserve_action.get("id", "")), "selecting a choice records presentation selection", failures)
		assert_true(not view.commit_button().disabled, "selected legal choice enables the explicit commit button", failures)
		assert_true(controller.domain.checkpoint() == checkpoint_before_selection, "selecting a choice does not mutate RunDomain", failures)
		assert_true(str(action_choice.get_meta("run_action_id", "")) == str(reserve_action.get("id", "")), "choice controls expose the original action id", failures)

	assert_true(view.cancel(), "Back cancels a pending action selection", failures)
	assert_true(view.selected_action_id.is_empty() and view.commit_button().disabled, "cancelling clears selection without committing", failures)
	assert_true(controller.domain.checkpoint() == checkpoint_before_selection, "cancelling selection preserves the authoritative checkpoint", failures)

	if action_choice != null:
		action_choice.emit_signal("pressed")
	var selected_action_id := str(reserve_action.get("id", ""))
	var pending_checkpoint: Dictionary = controller.domain.checkpoint()
	var pending_replay: Dictionary = controller.domain.rng_snapshot()
	TranslationServer.set_locale("zh_CN")
	assert_true(view.set_presentation_preferences("zh_CN", 1.25, "FAST", false, false), "changed locale, scale, and presentation mode update presentation settings", failures)
	view.render()
	assert_true(view.selected_action_id == selected_action_id, "locale and scale refresh preserve the pending selection", failures)
	assert_true(controller.domain.checkpoint() == pending_checkpoint, "locale and scale refresh preserve the authoritative checkpoint", failures)
	assert_true(controller.domain.rng_snapshot() == pending_replay, "locale and scale refresh preserve authoritative RNG state", failures)
	assert_true(view.set_presentation_preferences("en", 1.5, "INSTANT", true, false), "mode and reduced-motion settings apply", failures)
	view.render()
	assert_true(view.selected_action_id == selected_action_id, "mode and reduced-motion refresh preserve the pending selection", failures)
	assert_true(controller.domain.checkpoint() == pending_checkpoint, "mode and reduced-motion refresh preserve the authoritative checkpoint", failures)

	assert_true(str(view.commit_button().get_meta("run_commit_action_id", "")) == selected_action_id, "commit rail carries the selected stable action id", failures)
	view.commit_button().emit_signal("pressed")
	assert_true(requested_ids == ["battle.draw", selected_action_id], "each explicit commit emits exactly one action request", failures)
	assert_true(root_render_count[0] == 2, "the root renders BattleView once after the tile command (count=%d)" % root_render_count[0], failures)
	var reserve_ids: Array = controller.domain.current_battle.zones.contents(TileZoneScript.RESERVE).map(func(tile): return str(tile.instance_id))
	assert_true(reserve_ids.has(instance_id), "accepted commit moves the exact selected copy into Reserve", failures)
	var reserved_face := view._tile_button(instance_id)
	var reserved_tile = view._find_tile(instance_id)
	assert_true(reserved_face != null and reserved_face.status_badge != null and reserved_face.status_badge.visible, "integrity status has a visible badge outside the Reserve tile face", failures)
	assert_true(reserved_tile != null and reserved_face != null and reserved_face.status_marker == str(reserved_tile.integrity), "the Reserve badge exposes current integrity numerically", failures)
	assert_true(not controller.domain.current_battle.zones.contents(TileZoneScript.HAND).any(func(tile): return str(tile.instance_id) == instance_id), "accepted commit removes that copy from Hand", failures)
	assert_true(view.selected_action_id.is_empty(), "accepted Domain transition clears the stale action selection", failures)

	var geometry_battle = controller.domain.current_battle
	var end_turn_result = controller.confirm("battle.end_turn")
	assert_true(end_turn_result != null and end_turn_result.accepted, "layout fixture advances to a fresh Draw", failures)
	_replace_test_hand(geometry_battle, [
		"base.tile.characters.1", "base.tile.characters.1", "base.tile.characters.1",
		"base.tile.characters.2", "base.tile.characters.3", "base.tile.characters.4",
		"base.tile.characters.5", "base.tile.characters.6", "base.tile.characters.7",
		"base.tile.characters.2", "base.tile.characters.3", "base.tile.characters.8", "base.tile.characters.9",
	], "partial", failures)
	var layout_draw_result = controller.confirm("battle.draw")
	assert_true(layout_draw_result != null and layout_draw_result.accepted, "layout fixture refreshes the complete Run action set through Draw", failures)
	var geometry_hand := [
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3",
		"base.tile.characters.4", "base.tile.characters.5", "base.tile.characters.6",
		"base.tile.characters.7", "base.tile.characters.7",
	]
	_replace_test_hand(geometry_battle, geometry_hand, "complete", failures)
	view.set_presentation_preferences("en", 1.0, "NORMAL", false, true)
	view.render()
	await tree.process_frame
	var complete_action_id := ""
	var complete_action: Dictionary = {}
	for action in controller.action_descriptors():
		if str(action.get("kind", "")) == "COMPLETE_HAND":
			complete_action = action
			complete_action_id = str(action.get("id", ""))
			break
	var complete_button := view.action_button(complete_action_id)
	assert_true(not complete_action_id.is_empty() and complete_button != null, "the long Complete Hand fixture exposes a selectable action", failures)
	var stale_discard_tiles: Array = geometry_battle.zones.contents(TileZoneScript.DISCARD)
	var stale_tile_button: TileFaceButton = view._tile_button(str(stale_discard_tiles[0].instance_id)) if not stale_discard_tiles.is_empty() else null
	assert_true(stale_tile_button != null, "focus-race fixture exposes a physical tile in the action-panel zones", failures)
	if stale_tile_button != null:
		stale_tile_button.grab_focus()
		await tree.process_frame
	var race_checkpoint: Dictionary = controller.domain.checkpoint()
	var race_command_count: int = controller.domain.replay_record.commands.size()
	view.render()
	view.render()
	complete_button = view.action_button(complete_action_id)
	assert_true(complete_button != null, "render rebuilds the focused Complete Hand action control", failures)
	if complete_button != null:
		complete_button.grab_focus()
		complete_button.emit_signal("pressed")
		await tree.process_frame
		await tree.process_frame
		await tree.process_frame
		var focus_scroll := view.find_child("BattleChoiceScroll", true, false) as ScrollContainer
		assert_true(focus_scroll != null and focus_scroll.get_global_rect().intersects(complete_button.get_global_rect()), "new Complete Hand focus scrolls into view after layout, despite selection revision changes", failures)
		var race_inspection := view.find_child("BattleInspectionValue", true, false) as Label
		assert_true(tree.root.gui_get_focus_owner() == complete_button, "a deferred old-tile restore cannot steal newer Complete Hand focus", failures)
		assert_true(view.selected_action_id == complete_action_id and str(view.commit_button().get_meta("run_commit_action_id", "")) == complete_action_id, "the pending Complete Hand choice and commit target survive deferred restoration", failures)
		assert_true(race_inspection != null and race_inspection.text == str(complete_action.get("target_id", "")), "the inspector stays on the newly focused Complete Hand choice", failures)
		assert_true(controller.domain.checkpoint() == race_checkpoint and controller.domain.replay_record.commands.size() == race_command_count, "focus restoration and pending selection issue no Run command before Commit", failures)
	var wide_action_count := 0
	for action in controller.action_descriptors():
		var button := view.action_button(str(action.get("id", "")))
		if button == null:
			continue
		wide_action_count += 1
		assert_true(button.size.x >= 200.0, "every action kind retains a readable choice width (%s: %s)" % [str(action.get("kind", "")), str(button.size)], failures)
	assert_true(wide_action_count >= 20, "Complete Hand, Pattern, exact-tile, and Technique actions are covered by width checks (%d controls)" % wide_action_count, failures)
	var choice_cards := view.find_children("BattleChoiceCard_*", "PanelContainer", true, false)
	assert_true(not choice_cards.is_empty(), "choice sections materialize their card controls", failures)
	for choice_card in choice_cards:
		assert_true((choice_card as Control).size.x >= 200.0, "choice cards fill the action column (%s: %s)" % [choice_card.name, str((choice_card as Control).size)], failures)
	var empty_zone_labels := view.find_children("EmptyZone", "Label", true, false)
	assert_true(not empty_zone_labels.is_empty(), "the layout fixture includes empty-zone guidance", failures)
	for empty_zone in empty_zone_labels:
		assert_true((empty_zone as Label).size.x >= 140.0 and not (empty_zone.get_parent() is HFlowContainer), "empty-zone copy wraps in the zone VBox rather than at a one-pixel HFlow width (%s parent=%s size=%s)" % [empty_zone.name, empty_zone.get_parent().get_class(), str((empty_zone as Label).size)], failures)
	if complete_button != null:
		view.commit_button().emit_signal("pressed")
		assert_true(requested_ids.size() == 3 and requested_ids.back() == complete_action_id, "the focused Complete Hand choice submits only after explicit Commit", failures)
		assert_true(controller.domain.replay_record.commands.size() == race_command_count + 1, "explicit Complete Hand Commit adds exactly one Run command", failures)

	var embedded := BattleSceneScript.instantiate()
	embedded.configure_run(controller, label_callable, tooltip_callable, details_callable)
	tree.root.add_child(embedded)
	await tree.process_frame
	assert_true(embedded.battle_view != null and embedded.battle_view.is_visible_in_tree(), "legacy BattleScene can host the shared Run BattleView", failures)
	assert_true(not embedded.get_node("DrawButton").visible, "Run mode hides the legacy command buttons", failures)
	embedded.queue_free()
	view.queue_free()
	await tree.process_frame
	TranslationServer.set_locale("en")
	return failures


func _battle_controller(run_id: String, failures: Array[String]):
	var registry = ContentRegistryScript.new()
	for report in [Phase2CatalogScript.register_all(registry), AlphaActTwoCatalogScript.register_all(registry), AlphaScaleCatalogScript.register_all(registry)]:
		assert_true(report.is_valid(), "test content catalogs register without errors", failures)
	var domain = RunDomainScript.new_alpha_run(run_id, 314159, registry)
	var controller = RunPresentationControllerScript.new(domain)
	var character_result = controller.confirm("character:base.character.sequence")
	assert_true(character_result.accepted, "test Run selects a real Character", failures)
	var contract_result = controller.confirm("contract:base.contract.pressure")
	assert_true(contract_result.accepted, "test Run selects a real Contract", failures)
	var map_actions: Array = controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "MAP_NODE")
	assert_true(not map_actions.is_empty(), "test Run exposes its real starting Map action", failures)
	if map_actions.is_empty():
		return null
	var map_result = controller.confirm(str(map_actions[0].get("id", "")))
	assert_true(map_result.accepted and domain.state.phase == RunPhaseScript.BATTLE, "test Run reaches its actual Battle phase", failures)
	return controller


func _replace_test_hand(battle, definition_ids: Array, fixture_name: String, failures: Array[String]) -> void:
	for tile in battle.zones.contents(TileZoneScript.HAND):
		assert_true(battle.zones.transfer(str(tile.instance_id), TileZoneScript.HAND, TileZoneScript.DISCARD), "%s layout fixture moves the previous Hand instance into Discard" % fixture_name, failures)
	for index in definition_ids.size():
		var fixture_tile = TileInstanceScript.new("stage45.ui.%s.%02d" % [fixture_name, index], str(definition_ids[index]))
		assert_true(battle.zones.add(fixture_tile, TileZoneScript.HAND), "%s layout fixture installs an exact physical Hand instance" % fixture_name, failures)


func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
