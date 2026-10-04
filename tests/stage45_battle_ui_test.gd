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
const RunSceneScript = preload("res://scenes/run/run_scene.gd")
const TileFaceButtonScript = preload("res://src/presentation/ui/tile_face_button.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const YakuProgressTextScript = preload("res://src/presentation/ui/yaku_progress_text.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	test_yaku_progress_text_contract(failures)
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "Battle UI test runs inside SceneTree", failures)
	if tree == null:
		return failures
	var controller: Object = _battle_controller("stage45.battle-ui", failures)
	if controller == null:
		return failures
	_prepare_review_finding_fixtures(controller, failures)
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
	await test_wide_viewport_places_table_and_actions_side_by_side(view, tree, failures)
	await test_critical_battle_rails_stay_pinned_while_table_scrolls(view, tree, failures)

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
	assert_true(view.find_child("BattleYakuProgress", true, false) != null, "Battle exposes detailed Yaku progress alongside its aggregate count", failures)
	var local_yaku_progress := view.find_child("YakuLocalProgress_prototype_yaku_sequence_path", true, false) as Label
	var local_yaku_name := view.find_child("YakuName_prototype_yaku_sequence_path", true, false) as Label
	var hand_yaku_progress := view.find_child("YakuHandProgress_base_yaku_bamboo_concentration", true, false) as Label
	assert_true(local_yaku_progress != null, "Yaku progress distinguishes Local Settlement progress", failures)
	assert_true(local_yaku_progress != null and local_yaku_progress.text == "1/3", "Local Yaku shows formal Hand-only progress", failures)
	assert_true(local_yaku_name != null and local_yaku_name.text == LocalizationCatalogScript.content_text("prototype.yaku.sequence_path") and local_yaku_name.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "full Yaku names remain available without hover through visible wrapping", failures)
	assert_true(hand_yaku_progress != null, "Yaku progress distinguishes formal Hand progress", failures)
	assert_true(hand_yaku_progress != null and hand_yaku_progress.text == "3/9", "Hand Yaku reports its formal progress value", failures)
	var reserve_yaku_potential := view.find_child("YakuReservePotential_prototype_yaku_sequence_path", true, false) as Label
	assert_true(reserve_yaku_potential != null and reserve_yaku_potential.visible, "Yaku progress shows Reserve potential separately from formal Hand progress", failures)
	assert_true(reserve_yaku_potential != null and reserve_yaku_potential.text.contains("2/3"), "Reserve Yaku cue shows the distinct potential progress value", failures)
	assert_true(view.find_child("BattleHandHeading", true, false) != null, "the current Hand is rendered", failures)
	assert_true(view.find_child("BattleUnavailableTechnique_base_technique_settlement_focus", true, false) != null, "an owned Technique with unavailable timing remains visible for inspection", failures)
	var unavailable_technique_reason := view.find_child("BattleTechniqueReason_base_technique_settlement_focus", true, false) as Label
	var unavailable_technique_title := view.find_child("BattleTechniqueTitle_base_technique_settlement_focus", true, false) as Label
	assert_true(unavailable_technique_reason != null and unavailable_technique_reason.text == LocalizationCatalogScript.text("UI_BATTLE_VIEW_0057"), "the Settlement Technique displays a localized timing reason", failures)
	var settlement_technique_cost := "2 %s" % LocalizationCatalogScript.word_text("TP")
	assert_true(unavailable_technique_title != null and unavailable_technique_title.text.contains(LocalizationCatalogScript.word_text("SETTLEMENT")) and unavailable_technique_title.text.contains(LocalizationCatalogScript.word_text("RUN")) and unavailable_technique_title.text.contains(settlement_technique_cost), "Technique inspection shows its timing, owned source, and TP cost", failures)
	var core_technique_title := view.find_child("BattleTechniqueTitle_base_technique_core_sequence_line", true, false) as Label
	var core_technique_reason := view.find_child("BattleTechniqueReason_base_technique_core_sequence_line", true, false) as Label
	var core_technique_cost := "0 %s" % LocalizationCatalogScript.word_text("TP")
	assert_true(core_technique_title != null and core_technique_title.text.contains(LocalizationCatalogScript.word_text("CORE")) and core_technique_title.text.contains(LocalizationCatalogScript.word_text("CHARACTER")) and core_technique_title.text.contains(core_technique_cost), "Core Technique inspection distinguishes its kind, Character source, and TP cost", failures)
	assert_true(core_technique_reason != null and core_technique_reason.text == LocalizationCatalogScript.text("UI_BATTLE_VIEW_0061"), "an already-used Core Technique explains why it cannot be activated again", failures)
	var technique_inspections: Array = controller.call("technique_inspection_descriptors") if controller.has_method("technique_inspection_descriptors") else []
	var settlement_inspection: Dictionary = {}
	for inspection in technique_inspections:
		if str(inspection.get("id", "")) == "base.technique.settlement_focus":
			settlement_inspection = inspection
			break
	assert_true(not settlement_inspection.is_empty(), "owned Techniques have presentation-only inspection descriptors", failures)
	assert_true(not bool(settlement_inspection.get("available", true)) and str(settlement_inspection.get("reason_code", "")) == "TECHNIQUE_TIMING_UNAVAILABLE", "the Technique inspector explains that Settlement timing is unavailable", failures)
	assert_true(not controller.action_descriptors().any(func(action): return str(action.get("kind", "")) == "TECHNIQUE" and str(action.get("target_id", "")) == "base.technique.settlement_focus"), "unavailable Technique inspection never becomes a committable action", failures)
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
	assert_true(view.action_button("battle.draw") != null and view.action_button("battle.end_turn") != null, "turn actions remain available without tile selection", failures)
	assert_true(view.find_child("BattleSelectionHint", true, false) != null, "the table explains tile-first selection", failures)

	var initial_hand: Array = controller.domain.current_battle.zones.contents(TileZoneScript.HAND)
	assert_true(not initial_hand.is_empty(), "the real battle starts with physical Hand instances", failures)
	if initial_hand.is_empty():
		view.queue_free()
		await tree.process_frame
		return failures
	var first_tile = initial_hand[0]
	var first_face: TileFaceButton = view.tile_button(str(first_tile.instance_id))
	assert_true(first_face != null, "each Hand tile keeps its exact instance id in the rendered face", failures)
	if first_face != null:
		assert_true(first_face.tile_definition_id == str(first_tile.definition_id), "tile face uses the same registered tile definition", failures)
		assert_true(first_face.face_rect.texture != null, "tile face loads its exact Chinese tile PNG", failures)
		assert_true(first_face.tooltip_text.find(str(first_tile.instance_id)) < 0, "tile inspection uses player-facing names while exact copy identity stays in metadata", failures)

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
		var drawn_face := view.tile_button(drawn_ids[0])
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
	var tile_face: TileFaceButton = view.tile_button(instance_id)
	assert_true(tile_face != null, "Reserve choice points to the exact physical tile face", failures)
	var checkpoint_before_selection: Dictionary = controller.domain.checkpoint()
	if tile_face != null:
		tile_face.pressed.emit()
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

	view.tile_button(instance_id).pressed.emit()
	action_choice = view.action_button(str(reserve_action.id))
	if action_choice != null:
		action_choice.emit_signal("pressed")
	var selected_action_id := str(reserve_action.get("id", ""))
	var pending_checkpoint: Dictionary = controller.domain.checkpoint()
	var pending_replay: Dictionary = controller.domain.rng_snapshot()
	TranslationServer.set_locale("zh_CN")
	assert_true(view.set_presentation_preferences("zh_CN", 1.25, "FAST", false, false), "changed locale, scale, and presentation mode update presentation settings", failures)
	view.render()
	assert_true(view.selected_action_id == selected_action_id, "locale and scale refresh preserve the pending selection", failures)
	var chinese_local_yaku_heading := view.find_child("YakuLocalHeading", true, false) as Label
	assert_true(chinese_local_yaku_heading != null and chinese_local_yaku_heading.text == "局部结算", "the Local Settlement scope label uses the precise Chinese wording", failures)
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
	var reserved_face := view.tile_button(instance_id)
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
	await test_duplicate_tile_inspection_has_localized_labels_and_context(view, controller, geometry_battle, tree, failures)
	test_settlement_action_inspection_preserves_exact_instances(controller, failures)
	var complete_action_id := ""
	var complete_action: Dictionary = {}
	for action in controller.action_descriptors():
		if str(action.get("kind", "")) == "COMPLETE_HAND":
			complete_action = action
			complete_action_id = str(action.get("id", ""))
			break
	(view.find_child("SelectHandButton", true, false) as Button).pressed.emit()
	await tree.process_frame
	var complete_button := view.action_button(complete_action_id)
	assert_true(not complete_action_id.is_empty() and complete_button != null, "the long Complete Hand fixture exposes a selectable action", failures)
	var stale_discard_tiles: Array = geometry_battle.zones.contents(TileZoneScript.DISCARD)
	var stale_tile_button: TileFaceButton = view.tile_button(str(stale_discard_tiles[0].instance_id)) if not stale_discard_tiles.is_empty() else null
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
	assert_true(wide_action_count >= 3, "turn actions and the chosen complete hand are covered by width checks (%d controls)" % wide_action_count, failures)
	assert_true(view.selected_tile_ids().size() == 14, "Complete Hand action requires the selected full physical Hand", failures)
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


func test_yaku_progress_text_contract(failures: Array[String]) -> void:
	assert_true(YakuProgressTextScript.format([], "IN_PROGRESS") == "0", "Yaku progress with no display token uses the neutral fallback", failures)
	assert_true(YakuProgressTextScript.format(["1"], "IN_PROGRESS") == "0", "Yaku progress without a fraction does not expose an internal stage token", failures)
	assert_true(YakuProgressTextScript.format(["1/3"], "IN_PROGRESS") == "1/3", "Yaku progress displays the final localized fraction token", failures)
	assert_true(YakuProgressTextScript.format(["3/3"], "COMPLETE") == "✓", "completed Yaku progress uses the completion mark", failures)


func test_wide_viewport_places_table_and_actions_side_by_side(view: Control, tree: SceneTree, failures: Array[String]) -> void:
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view.position = Vector2.ZERO
	view.size = Vector2(960.0, 540.0)
	await tree.process_frame
	await tree.process_frame
	var table := view.find_child("BattleBoardSurface", true, false) as Control
	var action_panel := view.find_child("BattleActions", true, false) as Control
	var table_rect := table.get_global_rect() if table != null else Rect2()
	var action_rect := action_panel.get_global_rect() if action_panel != null else Rect2()
	var side_by_side := (
		table != null and action_panel != null
		and table_rect.position.x < action_rect.position.x
		and table_rect.end.x <= action_rect.position.x + 2.0
		and table_rect.position.y < action_rect.end.y
		and table_rect.end.y > action_rect.position.y
		and table_rect.size.x > action_rect.size.x
	)
	assert_true(
		side_by_side,
		"960x540 viewport places the wider Battle tile area beside BattleActions (table=%s, actions=%s)" % [str(table_rect), str(action_rect)],
		failures,
	)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame


func test_critical_battle_rails_stay_pinned_while_table_scrolls(view: Control, tree: SceneTree, failures: Array[String]) -> void:
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view.position = Vector2.ZERO
	view.size = Vector2(960.0, 540.0)
	await tree.process_frame
	await tree.process_frame
	var table_scroll := view.find_child("BattleViewportScroll", true, false) as ScrollContainer
	var enemy_intent := view.find_child("BattleEnemyIntentBanner", true, false) as Control
	var receipt := view.find_child("BattleCriticalReceipt", true, false) as Label
	var receipt_scroll := view.find_child("BattleCriticalReceiptScroll", true, false) as ScrollContainer
	var commit_button := view.find_child("CommitSelectedButton", true, false) as Control
	var view_rect := view.get_global_rect()
	assert_true(table_scroll != null and enemy_intent != null and receipt != null and receipt_scroll != null and commit_button != null, "pinned battle intent, receipt, table scroll, and commit rail are present", failures)
	if table_scroll == null or enemy_intent == null or receipt == null or receipt_scroll == null or commit_button == null:
		return
	assert_true(not table_scroll.is_ancestor_of(enemy_intent) and not table_scroll.is_ancestor_of(receipt) and not table_scroll.is_ancestor_of(commit_button), "critical Battle context and commit controls sit outside the scrollable table", failures)
	var previous_receipt_text := receipt.text
	var previous_receipt_visible := receipt.visible
	var previous_scroll_visible := receipt_scroll.visible
	receipt.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0046")
	receipt.visible = true
	receipt_scroll.visible = true
	view.call("_queue_table_layout")
	await tree.process_frame
	await tree.process_frame
	var intent_before := enemy_intent.get_global_rect()
	var receipt_before := receipt_scroll.get_global_rect()
	var commit_before := commit_button.get_global_rect()
	var scrollbar := table_scroll.get_v_scroll_bar()
	var maximum_scroll := int(maxf(0.0, scrollbar.max_value - scrollbar.page))
	assert_true(maximum_scroll > 0, "the table has independently scrollable decision content at 960x540", failures)
	table_scroll.scroll_vertical = maximum_scroll
	await tree.process_frame
	await tree.process_frame
	assert_true(enemy_intent.get_global_rect().is_equal_approx(intent_before), "enemy intent stays pinned while the table scrolls", failures)
	assert_true(receipt_scroll.get_global_rect().is_equal_approx(receipt_before), "critical settlement receipt stays pinned while the table scrolls", failures)
	assert_true(commit_button.get_global_rect().is_equal_approx(commit_before), "the only Battle commit control stays pinned while the table scrolls", failures)
	assert_true(commit_before.position.y >= view_rect.position.y and commit_before.end.y <= view_rect.end.y, "pinned commit control stays inside the visible Battle window", failures)
	assert_true(intent_before.position.y >= view_rect.position.y and intent_before.end.y <= view_rect.end.y, "pinned enemy intent stays inside the visible Battle window", failures)
	receipt.text = previous_receipt_text
	receipt.visible = previous_receipt_visible
	receipt_scroll.visible = previous_scroll_visible
	view.call("_queue_table_layout")
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame


func test_duplicate_tile_inspection_has_localized_labels_and_context(
	view: BattleView,
	controller: Object,
	battle,
	tree: SceneTree,
	failures: Array[String],
) -> void:
	var duplicate_tiles: Array = battle.zones.contents(TileZoneScript.HAND).filter(
		func(tile): return str(tile.definition_id) == "base.tile.characters.7"
	)
	assert_true(duplicate_tiles.size() == 2, "Complete Hand fixture has two physical copies of Characters 7 in Hand", failures)
	if duplicate_tiles.size() != 2:
		return

	var expected_instance_ids: Array[String] = []
	for tile in duplicate_tiles:
		expected_instance_ids.append(str(tile.instance_id))
	expected_instance_ids.sort()
	var matching_interpretation := false
	for action in controller.action_descriptors():
		if str(action.get("kind", "")) != "COMPLETE_HAND":
			continue
		var details: Dictionary = action.get("details", {})
		var pair_instance_ids: Array[String] = []
		for instance_id in details.get("pair_instance_ids", []):
			pair_instance_ids.append(str(instance_id))
		pair_instance_ids.sort()
		if str(details.get("hand_type", "")) == "Standard" and pair_instance_ids == expected_instance_ids:
			matching_interpretation = true
			break
	assert_true(matching_interpretation, "fixture identifies both copies as the Standard Complete Hand pair", failures)
	if not matching_interpretation:
		return

	var expected_tile_name := LocalizationCatalogScript.content_text("base.tile.characters.7")
	var copy_token := "__COPY_INDEX__"
	var localized_copy_prefix := LocalizationCatalogScript.format("UI_BATTLE_VIEW_0026", [expected_tile_name, copy_token]).replace(copy_token, "")
	var localized_zone := LocalizationCatalogScript.word_text("HAND")
	var localized_interpretation := LocalizationCatalogScript.word_text("STANDARD")
	var localized_group := LocalizationCatalogScript.word_text("PAIR")
	var copy_labels: Array[String] = []
	for tile in duplicate_tiles:
		var instance_id := str(tile.instance_id)
		var face: TileFaceButton = view.tile_button(instance_id)
		assert_true(face != null, "each duplicate instance remains available through the public tile control", failures)
		if face == null:
			continue
		copy_labels.append(face.tile_copy_label)
		assert_true(
			face.tile_copy_label.begins_with(localized_copy_prefix) and face.tile_copy_label != expected_tile_name,
			"duplicate copy label uses the localized tile name and copy format (%s)" % face.tile_copy_label,
			failures,
		)
		assert_true(not face.tile_copy_label.contains(instance_id), "player-facing copy label does not expose the raw instance id", failures)
		face.grab_focus()
		await tree.process_frame
		var inspection: Label = view.inspection_label()
		var inspection_text: String = inspection.text if inspection != null else ""
		assert_true(inspection_text.contains(face.tile_copy_label), "tile inspection identifies the selected physical copy", failures)
		assert_true(inspection_text.contains(localized_zone), "tile inspection identifies the current Hand zone", failures)
		assert_true(
			inspection_text.contains(localized_interpretation) and inspection_text.contains(localized_group),
			"tile inspection identifies its Standard Complete Hand Pair interpretation",
			failures,
		)
		assert_true(not inspection_text.contains(instance_id), "tile inspection does not expose the raw instance id", failures)
	assert_true(copy_labels.size() == 2 and copy_labels[0] != copy_labels[1], "duplicate tile instances have distinct localized player-facing copy labels", failures)


func test_settlement_action_inspection_preserves_exact_instances(controller: Object, failures: Array[String]) -> void:
	var run_scene = RunSceneScript.new()
	run_scene.controller = controller
	var same_type_first := {
		"id": "battle.complete.test-first",
		"kind": "COMPLETE_HAND",
		"target_id": "complete_hand.test-first",
		"details": {"hand_type": "Standard", "interpretation_index": 1, "interpretation_count": 2},
	}
	var same_type_second := {
		"id": "battle.complete.test-second",
		"kind": "COMPLETE_HAND",
		"target_id": "complete_hand.test-second",
		"details": {"hand_type": "Standard", "interpretation_index": 2, "interpretation_count": 2},
	}
	var first_label: String = run_scene.call("_action_label", same_type_first)
	var second_label: String = run_scene.call("_action_label", same_type_second)
	assert_true(first_label != second_label and first_label.contains("1/2") and second_label.contains("2/2"), "same-type Complete Hand interpretations have distinct visible labels", failures)
	var actions: Array = controller.action_descriptors()
	var partial_actions: Array = actions.filter(func(action): return str(action.get("kind", "")) == "PARTIAL_SETTLEMENT")
	assert_true(not partial_actions.is_empty(), "the Complete Hand fixture exposes inspectable Partial Settlement candidates", failures)
	if not partial_actions.is_empty():
		var partial_action: Dictionary = partial_actions[0]
		var partial_details: Dictionary = partial_action.get("details", {})
		var partial_text: String = run_scene.call("_action_details_text", partial_action)
		assert_true(partial_text.contains(LocalizationCatalogScript.word_text(str(partial_details.get("pattern_type", "PATTERN")))), "Partial Settlement inspector shows its localized pattern type", failures)
		for raw_instance_id in partial_details.get("instance_ids", []):
			var instance_id := str(raw_instance_id)
			var copy_label: String = controller.call("battle_tile_copy_label", instance_id)
			assert_true(partial_text.contains(copy_label), "Partial Settlement inspector identifies exact consumed copy %s" % copy_label, failures)
			assert_true(not partial_text.contains(instance_id), "Partial Settlement inspector does not expose internal instance IDs", failures)
	var complete_actions: Array = actions.filter(func(action): return str(action.get("kind", "")) == "COMPLETE_HAND")
	assert_true(not complete_actions.is_empty(), "the fixture exposes a legal Complete Hand interpretation", failures)
	if not complete_actions.is_empty():
		var complete_action: Dictionary = complete_actions[0]
		var complete_details: Dictionary = complete_action.get("details", {})
		var complete_text: String = run_scene.call("_action_details_text", complete_action)
		var pair_ids: Array = complete_details.get("pair_instance_ids", [])
		assert_true(complete_text.contains(LocalizationCatalogScript.word_text("PAIR")), "Complete Hand inspector identifies the structural Pair", failures)
		for group in complete_details.get("groups", []):
			var pattern_label := LocalizationCatalogScript.word_text(str(group.get("pattern_type", "PATTERN")))
			assert_true(complete_text.contains(pattern_label), "Complete Hand inspector names its %s group" % pattern_label, failures)
			for raw_instance_id in group.get("instance_ids", []):
				var instance_id := str(raw_instance_id)
				var copy_label: String = controller.call("battle_tile_copy_label", instance_id)
				assert_true(complete_text.contains(copy_label), "Complete Hand inspector distinguishes group member %s" % copy_label, failures)
				assert_true(not complete_text.contains(instance_id), "Complete Hand inspector does not expose internal group IDs", failures)
		for raw_instance_id in pair_ids:
			var instance_id := str(raw_instance_id)
			var copy_label: String = controller.call("battle_tile_copy_label", instance_id)
			assert_true(complete_text.contains(copy_label), "Complete Hand inspector names exact Pair copy %s" % copy_label, failures)
			assert_true(not complete_text.contains(instance_id), "Complete Hand inspector does not expose internal Pair IDs", failures)
		var has_hand_yaku := false
		for descriptor in controller.battle_yaku_progress_descriptors():
			if str(descriptor.get("scope", "")) == "LOCAL_SETTLEMENT":
				continue
			if float(descriptor.get("normalized_score", 0.0)) <= 0.0 and str(descriptor.get("stage", "")) != "COMPLETE":
				continue
			var yaku_name := LocalizationCatalogScript.content_text(str(descriptor.get("id", "")))
			if complete_text.contains(yaku_name):
				has_hand_yaku = true
				break
		assert_true(has_hand_yaku, "Complete Hand inspector carries an applicable current Hand Yaku signal", failures)
	run_scene.free()


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


func _prepare_review_finding_fixtures(controller, failures: Array[String]) -> void:
	var battle = controller.domain.current_battle
	var hand_definition_ids := [
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.characters.5", "base.tile.characters.7",
		"base.tile.bamboo.1", "base.tile.bamboo.3", "base.tile.bamboo.5",
		"base.tile.dots.2", "base.tile.dots.4", "base.tile.dots.6",
		"base.tile.honors.east", "base.tile.honors.east",
	]
	_replace_test_hand(battle, hand_definition_ids, "review-yaku", failures)
	var reserve_tile := TileInstanceScript.new("stage45.ui.review-yaku.reserve", "base.tile.characters.6")
	assert_true(battle.zones.add(reserve_tile, TileZoneScript.RESERVE), "review fixture adds an exact Reserve tile for potential progress", failures)
	var owned_technique_ids: Array = battle.context.build_state.get("run_technique_ids", []).duplicate()
	if not owned_technique_ids.has("base.technique.settlement_focus"):
		owned_technique_ids.append("base.technique.settlement_focus")
	battle.context.build_state["run_technique_ids"] = owned_technique_ids
	battle.combat_state.core_technique_used_this_turn = true


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
