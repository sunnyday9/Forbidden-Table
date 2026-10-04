extends RefCounted

const EnemyArenaScript = preload("res://src/presentation/ui/enemy_arena.gd")
const LocalizationScript = preload("res://src/presentation/localization/localization.gd")
const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	var original_root_size: Vector2i = tree.root.size
	_failures.clear()
	TranslationServer.set_locale("en")
	var arena = EnemyArenaScript.new()
	if arena == null or not arena is Control:
		push_error("EnemyArena failed to instantiate")
		return ["EnemyArena failed to instantiate"]
	arena.name = "EnemyArenaTest"
	arena.theme = ForbiddenThemeScript.create_theme("en", 1.5)
	tree.root.add_child(arena)
	arena.size = Vector2(960.0, 540.0)
	var model := {
		"enemy_id": "base.enemy.veiled_auditor",
		"enemy_name": "The Veiled Auditor",
		"hp": 34,
		"max_hp": 41,
		"hp_text": "The Veiled Auditor · HP 34 / 41",
		"intent_name": "Intent · Ledger Cut · Audit",
		"intent_detail": "Fatigue gained · 2",
		"intent_type": "AUDIT",
		"pressure": 7,
		"pressure_limit": 12,
		"stability": 2,
		"wall_count": 19,
		"locale": "en",
		"ui_scale": 1.5,
		"presentation_mode": "INSTANT",
	}
	var untouched_model := model.duplicate(true)
	arena.configure(model)
	await tree.process_frame
	await tree.process_frame

	var hp_label := arena.find_child("BattleEnemyHP", true, false) as Label
	var intent_label := arena.find_child("BattleIntentType", true, false) as Label
	var effect_label := arena.find_child("BattleIntentDetail", true, false) as Label
	var enemy_bar := arena.find_child("EnemyHealthBar", true, false) as ProgressBar
	var pressure_bar := arena.find_child("PlayerPressureBar", true, false) as ProgressBar
	var avatar := arena.find_child("EnemyAvatar", true, false) as Control
	var player_mark := arena.find_child("PlayerAnchorMark", true, false) as Control
	var wall_source := arena.find_child("DrawWallSource", true, false) as Control

	_check(hp_label != null and hp_label.text == model.hp_text, "legacy HP text stays visible and unchanged")
	_check(intent_label != null and intent_label.text == model.intent_name, "localized current intent title is preserved")
	_check(effect_label != null and effect_label.text == model.intent_detail, "localized intent effect remains the supplied authoritative description")
	_check(enemy_bar != null and enemy_bar.value == 34.0 and enemy_bar.max_value == 41.0, "enemy bar reflects exact current and maximum HP")
	_check(pressure_bar != null and pressure_bar.value == 7.0 and pressure_bar.max_value == 12.0, "pressure meter reflects its exact current value and limit")
	_check(str(arena.find_child("PlayerPressureValue", true, false).text).contains("7 / 12"), "pressure label includes the current value and limit")
	_check(str(arena.find_child("PlayerStabilityValue", true, false).text).contains("2"), "stability is shown as its real value without an invented cap")
	_check(str(arena.find_child("DrawWallCount", true, false).text).contains("19"), "the physical wall source displays the real wall count")
	_check(str(arena.find_child("IntentTiming", true, false).text) == LocalizationScript.text("UI_ENEMY_ARENA_0001"), "intent timing uses localized end-turn copy")
	_check(avatar != null and player_mark != null and wall_source != null, "enemy, player, and wall choreography anchors exist")
	_check(arena.enemy_anchor().distance_to(avatar.get_global_rect().get_center()) < 0.5, "enemy anchor targets the visible masked spirit")
	_check(arena.player_anchor().distance_to(player_mark.get_global_rect().get_center()) < 0.5, "player anchor targets the player-side seat mark")
	_check(arena.wall_anchor().distance_to(arena.find_child("WallStackMark", true, false).get_global_rect().get_center()) < 0.5, "wall anchor targets the visible Draw Wall stack")
	_check(model == untouched_model, "presentation configuration does not mutate its input snapshot")
	_check(_child_fits(arena, "BattleEnemyHP"), "legacy HP text remains inside the 960 px arena")
	_check(_child_fits(arena, "BattleIntentDetail"), "intent effect remains inside the 960 px arena")
	_check(_child_fits(arena, "IntentTiming"), "timing cue remains inside the 960 px arena")
	_check(_child_fits(arena, "PlayerPressureBar"), "pressure meter remains inside the 960 px arena")
	_check(_child_fits(arena, "PlayerStabilityValue"), "stability value remains inside the 960 px arena")
	_check(_child_fits(arena, "DrawWallSource"), "wall count remains inside the 960 px arena")

	var receipt_lines := PackedStringArray()
	for cue_index in range(14):
		receipt_lines.append("Receipt %02d: draw and intent resolved" % cue_index)
	var full_receipt := "\n".join(receipt_lines)
	arena.recent_action(full_receipt)
	await tree.process_frame
	var compact_height := arena.get_combined_minimum_size().y
	var recent_action := arena.find_child("RecentAction", true, false) as Label
	var receipt_scroll := arena.find_child("RecentActionScroll", true, false) as ScrollContainer
	_check(recent_action != null and recent_action.text == full_receipt, "the persistent receipt retains all supplied cues")
	_check(receipt_scroll != null and receipt_scroll.size.y <= 42.0, "a multi-event receipt scrolls within its 28–42 px 150% slot")
	_check(is_equal_approx(compact_height, arena.get_combined_minimum_size().y), "receipt history does not grow the fixed arena layout")
	var receipt_reading_position := 0
	if receipt_scroll != null:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.factor = 3.0
		wheel.position = receipt_scroll.get_global_rect().get_center()
		wheel.global_position = wheel.position
		Input.parse_input_event(wheel)
		Input.flush_buffered_events()
		await tree.process_frame
		await tree.process_frame
		_check(receipt_scroll.scroll_vertical > 0, "Mouse wheel reveals later action receipts without taking battle focus")

		receipt_reading_position = receipt_scroll.scroll_vertical
		arena.recent_action(full_receipt)
		await tree.process_frame
		_check(receipt_scroll.scroll_vertical == receipt_reading_position, "An unchanged receipt preserves its reading position during focus redraw")
		arena.recent_action(full_receipt + "\nNew action")
		await tree.process_frame
		_check(receipt_scroll.scroll_vertical == 0, "A changed receipt resets to the latest batch start")
		_check(is_equal_approx(compact_height, arena.get_combined_minimum_size().y), "receipt history scrolls without growing its reserved slot")

	arena.recent_action("")
	_check(not arena.find_child("RecentAction", true, false).visible, "an empty receipt collapses its scroll slot")
	TranslationServer.set_locale("zh_CN")
	var chinese_model := model.duplicate(true)
	chinese_model.locale = "zh_CN"
	chinese_model.ui_scale = 1.5
	arena.configure(chinese_model)
	_check(arena.find_child("IntentTiming", true, false).text == "回合结束时结算", "end-turn timing is present in the Chinese localization")
	_check(arena.find_child("PlayerPressureValue", true, false).text == "压力 · 7 / 12", "pressure readout is localized in Chinese")
	_check(arena.find_child("PlayerStabilityValue", true, false).text == "稳定度 · 2", "stability cue is localized in Chinese")
	_check(arena.find_child("DrawWallCount", true, false).text == "牌墙 · 19", "Draw Wall source is localized in Chinese")
	TranslationServer.set_locale("en")

	var initial_status := _status_signature(arena)
	model.presentation_mode = "NORMAL"
	model.ui_scale = 1.0
	arena.configure(model)
	await tree.process_frame
	_check(initial_status == _status_signature(arena), "presentation mode metadata cannot alter the authoritative display values")

	model.presentation_mode = "FAST"
	model.ui_scale = 1.0
	tree.root.size = Vector2i(maxi(original_root_size.x, 1400), maxi(original_root_size.y, 900))
	await tree.process_frame
	arena.size = Vector2(1400.0, 900.0)
	arena.configure(model)
	await tree.process_frame
	_check(arena.size.x == 1400.0 and arena.size.y == 900.0, "arena expands cleanly at the larger supported viewport")
	var wide_avatar := arena.find_child("EnemyAvatar", true, false) as Control
	_check(wide_avatar.custom_minimum_size == Vector2(88.0, 64.0), "the opponent keeps a compact silhouette in the wide viewport")
	_check(arena.enemy_anchor().distance_to(wide_avatar.get_global_rect().get_center()) < 0.5, "enemy anchor remains attached after reconfiguration")

	# Allocate the arena from a deliberately sized parent. This keeps the layout
	# contract independent of the test runner's root viewport or monitor size.
	var resize_root := Control.new()
	resize_root.name = "EnemyArenaResizeTestRoot"
	tree.root.add_child(resize_root)
	resize_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout_host := Control.new()
	layout_host.name = "EnemyArenaResizeHost"
	resize_root.add_child(layout_host)
	layout_host.position = Vector2.ZERO
	layout_host.size = Vector2(1200.0, 900.0)
	arena.reparent(layout_host)
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena.recent_action(full_receipt)
	await tree.process_frame
	receipt_scroll.scroll_vertical = receipt_reading_position
	await tree.process_frame
	var wide_minimum_heights: Dictionary = {}
	for reference_scale in [1.0, 1.25, 1.5]:
		layout_host.size.x = 1200.0
		var wide_model := model.duplicate(true)
		wide_model.ui_scale = reference_scale
		arena.configure(wide_model)
		await tree.process_frame
		await tree.process_frame
		var wide_minimum_height := arena.get_combined_minimum_size().y
		wide_minimum_heights[int(reference_scale * 100.0)] = wide_minimum_height
		_check(
			wide_minimum_height <= 176.0 * reference_scale + 1.0,
			"wide strip stays compact with its receipt slot at %d%% (allocated %s, combined minimum %s)"
			% [int(reference_scale * 100.0), str(arena.size), str(arena.get_combined_minimum_size())]
		)
		if is_equal_approx(reference_scale, 1.0):
			var reference_avatar := arena.find_child("EnemyAvatar", true, false) as Control
			_check(reference_avatar.custom_minimum_size == Vector2(88.0, 64.0), "the 100% wide strip uses an 88 × 64 portrait")
	for test_width in [260.0, 360.0, 600.0, 800.0]:
		for test_scale in [1.0, 1.25, 1.5]:
			layout_host.size.x = test_width
			var responsive_model := model.duplicate(true)
			responsive_model.ui_scale = test_scale
			arena.configure(responsive_model)
			await tree.process_frame
			await tree.process_frame
			var arena_rect := arena.get_global_rect()
			var case_name := "%d px / %d%%" % [int(test_width), int(test_scale * 100.0)]
			_check(is_equal_approx(arena.size.x, layout_host.size.x), "arena follows its parent allocation at " + case_name)
			_check(arena.get_combined_minimum_size().x <= test_width + 0.5, "responsive minimum width fits " + case_name)
			_check(_responsive_readouts_fit(arena, arena_rect), "all readouts and receipt remain inside " + case_name + " arena")
			var horizontal_overflows := _responsive_horizontal_overflows(arena, arena_rect)
			_check(
				horizontal_overflows.is_empty(),
				"readouts fit the allocated horizontal bounds at %s (arena %s, minimum %s; overflow: %s)"
				% [case_name, str(arena.size), str(arena.get_combined_minimum_size()), ", ".join(horizontal_overflows)]
			)
			if test_width == 360.0:
				_check(
					arena.get_combined_minimum_size().y > wide_minimum_heights[int(test_scale * 100.0)],
					"the stacked arena uses more natural height than the compact wide strip at " + case_name
				)
			var narrow_avatar := arena.find_child("EnemyAvatar", true, false) as Control
			var narrow_identity := arena.find_child("EnemyIdentity", true, false) as Control
			var narrow_intent := arena.find_child("EnemyIntentCard", true, false) as Control
			var opponent_strip := arena.find_child("OpponentStrip", true, false) as BoxContainer
			if test_width == 260.0:
				_check(opponent_strip != null and opponent_strip.vertical, "the narrow opponent strip stacks portrait and identity at " + case_name)
			if test_width == 800.0 and is_equal_approx(test_scale, 1.0):
				_check(narrow_avatar.custom_minimum_size == Vector2(74.0, 56.0), "the normal-scale portrait remains compact on narrow allocations")
			var opponent_strip_bottom := maxf(
				narrow_avatar.get_global_rect().end.y,
				narrow_identity.get_global_rect().end.y
			)
			_check(
				narrow_intent.get_global_rect().position.y >= opponent_strip_bottom - 0.5,
				"opponent and intent stack at " + case_name
			)
			var player_mark_after_resize := arena.find_child("PlayerAnchorMark", true, false) as Control
			var wall_mark_after_resize := arena.find_child("WallStackMark", true, false) as Control
			_check(arena.enemy_anchor().distance_to(narrow_avatar.get_global_rect().get_center()) < 0.5, "enemy anchor follows its portrait at " + case_name)
			_check(arena.player_anchor().distance_to(player_mark_after_resize.get_global_rect().get_center()) < 0.5, "player anchor follows its seat at " + case_name)
			_check(arena.wall_anchor().distance_to(wall_mark_after_resize.get_global_rect().get_center()) < 0.5, "wall anchor follows its stack at " + case_name)
			arena.recent_action(full_receipt)
			await tree.process_frame
			_check(receipt_scroll.scroll_vertical == receipt_reading_position, "same receipt keeps its wheel reading after resize at " + case_name)

	layout_host.size.x = 360.0
	await tree.process_frame
	await tree.process_frame
	var resize_only_avatar := arena.find_child("EnemyAvatar", true, false) as Control
	var resize_only_identity := arena.find_child("EnemyIdentity", true, false) as Control
	var resize_only_intent := arena.find_child("EnemyIntentCard", true, false) as Control
	var resize_only_strip_bottom := maxf(
		resize_only_avatar.get_global_rect().end.y,
		resize_only_identity.get_global_rect().end.y
	)
	_check(is_equal_approx(arena.size.x, layout_host.size.x), "arena follows a parent-only resize without reconfiguration")
	_check(resize_only_intent.get_global_rect().position.y >= resize_only_strip_bottom - 0.5, "parent-only resize switches back to the narrow stacked layout")
	layout_host.size.x = 1200.0
	await tree.process_frame
	await tree.process_frame
	var resize_only_wide_intent := arena.find_child("EnemyIntentCard", true, false) as Control
	var resize_only_wide_bottom := maxf(
		resize_only_avatar.get_global_rect().end.y,
		resize_only_identity.get_global_rect().end.y
	)
	_check(resize_only_wide_intent.get_global_rect().position.y < resize_only_wide_bottom - 0.5, "parent-only resize restores the compact strip layout")
	await tree.process_frame
	var wide_layout_model := model.duplicate(true)
	wide_layout_model.ui_scale = 1.0
	arena.configure(wide_layout_model)
	await tree.process_frame
	await tree.process_frame
	var wide_layout_avatar := arena.find_child("EnemyAvatar", true, false) as Control
	var wide_layout_identity := arena.find_child("EnemyIdentity", true, false) as Control
	var wide_layout_intent := arena.find_child("EnemyIntentCard", true, false) as Control
	_check(wide_layout_avatar.custom_minimum_size == Vector2(88.0, 64.0), "the 100% wide strip uses its compact portrait size")
	var wide_opponent_strip_bottom := maxf(
		wide_layout_avatar.get_global_rect().end.y,
		wide_layout_identity.get_global_rect().end.y
	)
	_check(
		wide_layout_intent.get_global_rect().position.y < wide_opponent_strip_bottom - 0.5,
		"opponent portrait, identity, and intent share a compact strip on a wide 100% allocation"
	)

	resize_root.free()
	tree.root.size = original_root_size
	await tree.process_frame
	TranslationServer.set_locale("en")
	return _failures


func _status_signature(arena: Control) -> String:
	return "%s|%s|%s|%s|%s" % [
		str(arena.find_child("BattleEnemyHP", true, false).text),
		str(arena.find_child("BattleIntentType", true, false).text),
		str(arena.find_child("BattleIntentDetail", true, false).text),
		str(arena.find_child("EnemyHealthBar", true, false).value),
		str(arena.find_child("PlayerPressureBar", true, false).value),
	]


func _child_fits(arena: Control, path: String) -> bool:
	var child := arena.find_child(path, true, false) as Control
	if child == null:
		return false
	var arena_rect := arena.get_global_rect()
	var child_rect := child.get_global_rect()
	return (
		child_rect.position.x >= arena_rect.position.x - 0.5
		and child_rect.position.y >= arena_rect.position.y - 0.5
		and child_rect.end.x <= arena_rect.end.x + 0.5
		and child_rect.end.y <= arena_rect.end.y + 0.5
	)


func _responsive_readouts_fit(arena: Control, arena_rect: Rect2) -> bool:
	for path in [
		"EnemyAvatar",
		"EnemyIdentity",
		"EnemyName",
		"EnemyHealthBar",
		"EnemyIntentCard",
		"BattleEnemyHP",
		"BattleIntentType",
		"BattleIntentDetail",
		"IntentTiming",
		"PlayerStateCue",
		"PlayerPressureCue",
		"PlayerPressureValue",
		"PlayerPressureBar",
		"PlayerStabilityValue",
		"DrawWallSource",
		"DrawWallCount",
		"RecentActionScroll",
	]:
		var control := arena.find_child(path, true, false) as Control
		if control == null or not _rect_inside(control.get_global_rect(), arena_rect):
			return false
		if control is Label:
			var label := control as Label
			if label.clip_text or label.autowrap_mode == TextServer.AUTOWRAP_OFF or label.text.contains("base."):
				return false
	return true


func _responsive_horizontal_overflows(arena: Control, arena_rect: Rect2) -> PackedStringArray:
	var overflows := PackedStringArray()
	for path in [
		"EnemyAvatar",
		"EnemyIdentity",
		"EnemyName",
		"EnemyHealthBar",
		"EnemyIntentCard",
		"BattleEnemyHP",
		"BattleIntentType",
		"BattleIntentDetail",
		"IntentTiming",
		"PlayerStateCue",
		"PlayerPressureCue",
		"PlayerPressureValue",
		"PlayerPressureBar",
		"PlayerStabilityValue",
		"DrawWallSource",
		"DrawWallCount",
		"RecentActionScroll",
	]:
		var control := arena.find_child(path, true, false) as Control
		if control == null:
			continue
		var rect := control.get_global_rect()
		if rect.position.x < arena_rect.position.x - 0.5 or rect.end.x > arena_rect.end.x + 0.5:
			overflows.append("%s=%s" % [path, str(rect)])
	return overflows


func _rect_inside(rect: Rect2, bounds: Rect2) -> bool:
	return (
		rect.position.x >= bounds.position.x - 0.5
		and rect.position.y >= bounds.position.y - 0.5
		and rect.end.x <= bounds.end.x + 0.5
		and rect.end.y <= bounds.end.y + 0.5
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
