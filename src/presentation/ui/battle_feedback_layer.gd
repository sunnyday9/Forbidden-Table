class_name BattleFeedbackLayer
extends Control

signal cue_started(cue: Dictionary)
signal playback_finished

const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const FeedbackInkScript = preload("res://src/presentation/ui/battle_feedback_ink.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const NORMAL := "NORMAL"
const FAST := "FAST"
const INSTANT := "INSTANT"
const FAST_DURATION_SCALE := 0.4

const CUE_DURATIONS := {
	"DRAW": 0.60,
	"DISCARD": 0.50,
	"BURST": 1.00,
	"SETTLE": 0.55,
	"COMPLETE": 0.70,
	"ATTACK": 0.60,
	"RELIEF": 0.52,
	"PRESSURE": 0.68,
	"ENEMY_EFFECT": 0.70,
	"STABILITY": 0.48,
	"STRESS": 0.48,
	"PHASE": 0.66,
	"VICTORY": 0.88,
	"DEFEAT": 0.88,
}

const JADE := Color("#80D8AF")
const BRASS := Color("#E7B65A")
const VERMILION := Color("#E56B50")
const IVORY := Color("#FFF1D5")

var presentation_mode: String = NORMAL
var reduced_motion: bool = false

var _queue: Array[Dictionary] = []
var _queue_index := 0
var _anchors: Dictionary = {}
var _current: Dictionary = {}
var _playing := false
var _generation := 0
var _active_tween: Tween
var _visual_nodes: Array[Node] = []
var _duration := 0.0
var _batch_duration_scale := 1.0
var _has_tween_track := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)


func configure(mode: String = NORMAL, reduced: bool = false) -> void:
	var normalized_mode := _normalize_mode(mode)
	var changed := presentation_mode != normalized_mode or reduced_motion != reduced
	presentation_mode = normalized_mode
	reduced_motion = reduced
	if changed:
		cancel()


func play(cues: Array, anchors: Dictionary) -> void:
	# Superseded cosmetics stop at once. Domain state and the already-rendered
	# board are never touched by this module.
	cancel()
	_anchors = anchors.duplicate(true)
	_queue.clear()
	for raw_cue in cues:
		if raw_cue is Dictionary:
			_queue.append(raw_cue.duplicate(true))
	_queue = _aggregate_motion(_queue)
	_queue_index = 0
	if _queue.is_empty():
		_clear_visuals()
		_current.clear()
		return
	var total_seconds := 0.0
	for cue in _queue:
		total_seconds += _cue_duration(str(cue.get("kind", "")))
	_batch_duration_scale = minf(1.0, 4.0 / maxf(total_seconds, 0.01))
	_generation += 1
	_playing = true
	if _animations_disabled() or not is_inside_tree() or not is_visible_in_tree():
		_play_without_motion()
		return
	_start_next_cue(_generation)


func _aggregate_motion(cues: Array[Dictionary]) -> Array[Dictionary]:
	# Only adjacent same-source bursts share cosmetics. Receipts retain the exact
	# original order and values; a different action/source ends the burst.
	if _animations_disabled():
		return cues
	var groups: Array[Dictionary] = []
	for cue in cues:
		var kind := str(cue.get("kind", ""))
		var source := str(cue.get("source" if kind == "DRAW" else "source_id", ""))
		var previous: Dictionary = groups.back() if not groups.is_empty() else {}
		var previous_source := str(previous.get("source" if kind == "DRAW" else "source_id", ""))
		if kind in ["DRAW", "ATTACK"] and str(previous.get("kind", "")) == kind and previous_source == source:
			if not previous.has("members"):
				previous["members"] = [previous.duplicate(true)]
			previous.members.append(cue.duplicate(true))
			previous["count"] = previous.members.size()
			if kind == "ATTACK":
				previous["amount"] = int(previous.get("amount", 0)) + int(cue.get("amount", 0))
				previous["text"] = LocalizationCatalogScript.format("BATTLE_CUE_ATTACK_GROUP", [previous.amount, previous.count])
				var source_name := str(previous.get("source_name", ""))
				if not source_name.is_empty():
					previous["text"] = source_name + " · " + str(previous.text)
			else:
				previous["text"] = LocalizationCatalogScript.format("BATTLE_CUE_DRAW_GROUP", [previous.count])
		else:
			groups.append(cue.duplicate(true))
	var nominal_seconds := 0.0
	for cue in groups:
		nominal_seconds += _cue_duration(str(cue.get("kind", "")))
	if nominal_seconds <= 4.0:
		return groups
	return _summarize_low_priority_runs(groups)


func _summarize_low_priority_runs(cues: Array[Dictionary]) -> Array[Dictionary]:
	var summarized: Array[Dictionary] = []
	var low_priority_run: Array[Dictionary] = []
	for cue in cues:
		if _is_high_priority_cue(str(cue.get("kind", ""))):
			if not low_priority_run.is_empty():
				summarized.append(_make_burst_cue(low_priority_run))
				low_priority_run.clear()
			summarized.append(cue.duplicate(true))
		else:
			low_priority_run.append(cue)
	if not low_priority_run.is_empty():
		summarized.append(_make_burst_cue(low_priority_run))
	return summarized


func _is_high_priority_cue(kind: String) -> bool:
	return kind.to_upper() in ["SETTLE", "COMPLETE", "PHASE", "VICTORY", "DEFEAT"]


func _make_burst_cue(cues: Array[Dictionary]) -> Dictionary:
	var receipts: Array[Dictionary] = []
	for cue in cues:
		_flatten_receipts(cue, receipts)
	var damage := 0
	var attack_count := 0
	var attack_sources: Dictionary = {}
	var attack_origin := ""
	var pressure_added := 0
	var enemy_pressure_added := 0
	var pressure_relieved := 0
	var stability_net := 0
	var draw_count := 0
	var discard_count := 0
	var enemy_effect_count := 0
	for cue in receipts:
		match str(cue.get("kind", "")).to_upper():
			"ATTACK":
				damage += int(cue.get("amount", 0))
				attack_count += 1
				var source_id := str(cue.get("source_id", ""))
				if not source_id.is_empty():
					attack_sources[source_id] = true
				if attack_origin.is_empty():
					attack_origin = str(cue.get("origin", "player"))
			"PRESSURE":
				var pressure_amount := maxi(0, int(cue.get("amount", 0)))
				pressure_added += pressure_amount
				enemy_pressure_added += pressure_amount
			"STRESS": pressure_added += maxi(0, int(cue.get("amount", 0)))
			"RELIEF": pressure_relieved += maxi(0, int(cue.get("amount", 0)))
			"STABILITY": stability_net += int(cue.get("amount", 0))
			"DRAW": draw_count += 1
			"DISCARD": discard_count += 1
			"ENEMY_EFFECT": enemy_effect_count += 1
	if attack_sources.size() > 1 or (attack_count > 1 and attack_sources.is_empty()) or attack_origin.is_empty():
		attack_origin = "player"
	var summary_lines := PackedStringArray()
	summary_lines.append(LocalizationCatalogScript.format("BATTLE_CUE_BURST_HEADER", [receipts.size()]))
	if attack_count > 0:
		summary_lines.append(LocalizationCatalogScript.format("BATTLE_CUE_ATTACK_GROUP", [damage, attack_count]))
	var pressure_lines := PackedStringArray()
	if pressure_added > 0:
		pressure_lines.append(LocalizationCatalogScript.format("BATTLE_CUE_PRESSURE_GENERIC", [pressure_added]))
	if pressure_relieved > 0:
		pressure_lines.append(LocalizationCatalogScript.format("BATTLE_CUE_RELIEF", [pressure_relieved]))
	if not pressure_lines.is_empty():
		summary_lines.append(" · ".join(pressure_lines))
	if stability_net != 0:
		var stability_text := "+%d" % stability_net if stability_net > 0 else str(stability_net)
		summary_lines.append(LocalizationCatalogScript.format("BATTLE_CUE_STABILITY", [stability_text]))
	var movement_lines := PackedStringArray()
	if draw_count > 0:
		movement_lines.append("%s ×%d" % [LocalizationCatalogScript.word_text("DRAW"), draw_count])
	if discard_count > 0:
		movement_lines.append("%s ×%d" % [LocalizationCatalogScript.word_text("DISCARD"), discard_count])
	if not movement_lines.is_empty():
		summary_lines.append(" · ".join(movement_lines))
	if enemy_effect_count > 0:
		summary_lines.append(LocalizationCatalogScript.format("BATTLE_CUE_BURST_EFFECTS", [enemy_effect_count]))
	return {
		"kind": "BURST",
		"members": receipts,
		"count": receipts.size(),
		"text": "\n".join(summary_lines),
		"summary_lines": summary_lines,
		"damage": damage,
		"attack_count": attack_count,
		"attack_origin": attack_origin,
		"attack_source_count": attack_sources.size(),
		"pressure_added": pressure_added,
		"enemy_pressure_added": enemy_pressure_added,
		"incoming_pressure": enemy_pressure_added > 0,
		"pressure_relieved": pressure_relieved,
		"stability_net": stability_net,
		"draw_count": draw_count,
		"discard_count": discard_count,
		"enemy_effect_count": enemy_effect_count,
	}


func _flatten_receipts(cue: Dictionary, receipts: Array[Dictionary]) -> void:
	var raw_members: Variant = cue.get("members", [])
	if raw_members is Array and not raw_members.is_empty():
		for member in raw_members:
			if member is Dictionary:
				_flatten_receipts(member, receipts)
		return
	receipts.append(cue.duplicate(true))


func cancel() -> void:
	var was_playing := _playing
	_generation += 1
	_playing = false
	if _active_tween != null and _active_tween.is_running():
		_active_tween.kill()
	_active_tween = null
	_queue.clear()
	_queue_index = 0
	_current.clear()
	_clear_visuals()
	if was_playing:
		playback_finished.emit()


func is_playing() -> bool:
	return _playing


func current_cue() -> Dictionary:
	return _current.duplicate(true)


func _play_without_motion() -> void:
	# Receipt signals remain useful to the persistent battle log even when the
	# presentation policy forbids constructing a visual or waiting on a frame.
	var generation := _generation
	var receipt_queue := _queue.duplicate(true)
	for cue in receipt_queue:
		if generation != _generation or not _playing:
			return
		_current = cue.duplicate(true)
		cue_started.emit(_current.duplicate(true))
		if generation != _generation or not _playing:
			return
	_current.clear()
	_queue.clear()
	_queue_index = 0
	_playing = false
	playback_finished.emit()


func _start_next_cue(generation: int) -> void:
	if generation != _generation or not _playing:
		return
	if _queue_index >= _queue.size():
		_finish_batch(generation)
		return
	_clear_visuals()
	_current = _queue[_queue_index].duplicate(true)
	var members: Array = _current.get("members", [])
	if members.is_empty():
		cue_started.emit(_current.duplicate(true))
	else:
		for member in members:
			cue_started.emit(member.duplicate(true))
			if generation != _generation or not _playing:
				return
	if generation != _generation or not _playing:
		return
	_duration = _cue_duration(str(_current.get("kind", ""))) * _duration_scale() * _batch_duration_scale
	_has_tween_track = false
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_LINEAR)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_build_cue_visuals(_active_tween)
	if not _has_tween_track:
		_active_tween.tween_interval(_duration)
	_active_tween.finished.connect(_complete_current_cue.bind(generation), CONNECT_ONE_SHOT)


func _complete_current_cue(generation: int) -> void:
	if generation != _generation or not _playing:
		return
	_active_tween = null
	_clear_visuals()
	_current.clear()
	_queue_index += 1
	_start_next_cue(generation)


func _finish_batch(generation: int) -> void:
	if generation != _generation or not _playing:
		return
	_clear_visuals()
	_active_tween = null
	_current.clear()
	_queue.clear()
	_queue_index = 0
	_playing = false
	playback_finished.emit()


func _build_cue_visuals(tween: Tween) -> void:
	var kind := str(_current.get("kind", "")).to_upper()
	match kind:
		"DRAW":
			var members: Array = _current.get("members", [])
			if members.is_empty():
				_build_tile_flight(tween, false)
			else:
				for member in members:
					_build_tile_flight(tween, false, member)
			_add_caption_track(tween, _cue_text(), _point("hand"), BRASS, "secondary", Vector2(0.0, -68.0))
		"DISCARD":
			_build_tile_flight(tween, true)
			_add_caption_track(tween, _cue_text(), _point("discard"), IVORY, "secondary", Vector2(0.0, 62.0))
		"SETTLE", "COMPLETE":
			_build_settlement_fan(tween)
			_add_caption_track(tween, _cue_text(), _point("discard"), BRASS, "secondary", Vector2(0.0, 66.0))
		"ATTACK":
			var enemy := _point("enemy")
			var origin := _point(str(_current.get("origin", "player")))
			_add_ink_track(tween, "flight", origin + Vector2(0.0, -16.0), enemy, VERMILION)
			_add_ink_track(tween, "impact", enemy, enemy, BRASS)
			_add_amount_track(tween, "−%d" % int(_current.get("amount", 0)), _cue_text(), enemy, VERMILION, BRASS, 0.65)
		"BURST":
			_build_burst_summary(tween)
		"RELIEF":
			var player := _point("player")
			_add_ink_track(tween, "ward", player, player, JADE)
			_add_amount_track(tween, "−%d %s" % [int(_current.get("amount", 0)), LocalizationCatalogScript.word_text("PRESSURE")], _cue_text(), player, JADE, IVORY)
		"PRESSURE":
			var enemy := _point("enemy")
			var player := _point("player")
			_add_ink_track(tween, "pressure", enemy, player, VERMILION)
			_add_amount_track(tween, "+%d %s" % [int(_current.get("amount", 0)), LocalizationCatalogScript.word_text("PRESSURE")], _cue_text(), player, VERMILION, IVORY)
		"ENEMY_EFFECT":
			var enemy := _point("enemy")
			var target := _enemy_effect_target()
			_add_ink_track(tween, "effect", enemy, target, VERMILION)
			_add_caption_track(tween, _cue_text(), target, IVORY, "secondary", Vector2(0.0, 40.0))
		"STABILITY":
			var player := _point("player")
			var amount := int(_current.get("amount", 0))
			var sign := "+" if amount >= 0 else "−"
			_add_ink_track(tween, "stability", player, player, JADE)
			_add_amount_track(tween, "%s%d %s" % [sign, absi(amount), LocalizationCatalogScript.text("UI_BATTLE_VIEW_0032")], _cue_text(), player, JADE, IVORY)
		"STRESS":
			var player := _point("player")
			_add_ink_track(tween, "stability", player, player, VERMILION)
			_add_amount_track(tween, "+%d %s" % [int(_current.get("amount", 0)), LocalizationCatalogScript.word_text("PRESSURE")], _cue_text(), player, VERMILION, IVORY)
		"PHASE":
			var enemy := _point("enemy")
			_add_ink_track(tween, "phase", enemy, enemy, BRASS)
			_add_caption_track(tween, _cue_text(), enemy, BRASS, "heading", Vector2(0.0, -84.0))
		"VICTORY":
			var enemy := _point("enemy")
			_add_ink_track(tween, "victory", enemy, enemy, BRASS)
			_add_caption_track(tween, _cue_text(), enemy, BRASS, "title", Vector2(0.0, -24.0))
		_:
			_add_caption_track(tween, _cue_text(), _point("player"), IVORY, "secondary", Vector2.ZERO)


func _build_burst_summary(tween: Tween) -> void:
	var enemy := _point("enemy")
	var player := _point("player")
	var damage := int(_current.get("damage", 0))
	var pressure_added := int(_current.get("enemy_pressure_added", 0))
	var pressure_relieved := int(_current.get("pressure_relieved", 0))
	var stability_net := int(_current.get("stability_net", 0))
	if damage > 0:
		var origin := _point(str(_current.get("attack_origin", "player")))
		_add_ink_track(tween, "flight", origin + Vector2(0.0, -16.0), enemy, VERMILION)
		_add_ink_track(tween, "impact", enemy, enemy, BRASS)
	if pressure_added > 0:
		_add_ink_track(tween, "pressure", enemy, player, VERMILION)
	if pressure_relieved > 0:
		_add_ink_track(tween, "ward", player, player, JADE)
	if stability_net != 0:
		_add_ink_track(tween, "stability", player, player, JADE if stability_net > 0 else VERMILION)
	var draw_cue := _first_burst_member("DRAW")
	if not draw_cue.is_empty():
		_build_tile_flight(tween, false, draw_cue)
	var discard_cue := _first_burst_member("DISCARD")
	if not discard_cue.is_empty():
		_build_tile_flight(tween, true, discard_cue)
	var effect_cue := _first_burst_member("ENEMY_EFFECT")
	if not effect_cue.is_empty():
		_add_ink_track(tween, "effect", enemy, _enemy_effect_target(effect_cue), VERMILION)
	_build_burst_card()


func _first_burst_member(kind: String) -> Dictionary:
	var raw_members: Variant = _current.get("members", [])
	if not raw_members is Array:
		return {}
	for member in raw_members:
		if member is Dictionary and str(member.get("kind", "")).to_upper() == kind:
			return member
	return {}


func _build_burst_card() -> void:
	var extent := size
	if extent.x <= 0.0 or extent.y <= 0.0:
		extent = get_viewport_rect().size if get_viewport() != null else Vector2(960.0, 540.0)
	var card_size := Vector2(minf(480.0, maxf(1.0, extent.x - 32.0)), minf(236.0, maxf(1.0, extent.y - 72.0)))
	var card := PanelContainer.new()
	card.name = "BattleFeedbackBurstCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.focus_mode = Control.FOCUS_NONE
	card.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	card.custom_minimum_size = card_size
	card.size = card_size
	card.position = _caption_position((extent - card_size) * 0.5, card_size)
	card.z_index = 41
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17201F")
	style.bg_color.a = 0.96
	style.border_color = Color("#E7B65A")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 5.0)
	card.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.focus_mode = Control.FOCUS_NONE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.focus_mode = Control.FOCUS_NONE
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var summary_lines: PackedStringArray = _current.get("summary_lines", PackedStringArray())
	var headline := Label.new()
	headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headline.focus_mode = Control.FOCUS_NONE
	headline.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.text = str(summary_lines[0]) if not summary_lines.is_empty() else _cue_text()
	headline.add_theme_font_size_override("font_size", ForbiddenThemeScript.font_size_for("body", ForbiddenThemeScript.ui_scale_for(self)))
	headline.add_theme_color_override("font_color", BRASS)
	headline.add_theme_color_override("font_outline_color", ForbiddenThemeScript.color("ink"))
	headline.add_theme_constant_override("outline_size", 3)
	stack.add_child(headline)
	var details := Label.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.focus_mode = Control.FOCUS_NONE
	details.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail_text := "\n".join(summary_lines.slice(1)) if summary_lines.size() > 1 else ""
	details.text = detail_text
	details.add_theme_font_size_override("font_size", ForbiddenThemeScript.font_size_for("secondary", ForbiddenThemeScript.ui_scale_for(self)))
	details.add_theme_color_override("font_color", IVORY)
	details.add_theme_color_override("font_outline_color", ForbiddenThemeScript.color("ink"))
	details.add_theme_constant_override("outline_size", 2)
	stack.add_child(details)
	add_child(card)
	_visual_nodes.append(card)


func _build_tile_flight(tween: Tween, is_discard: bool, member: Dictionary = {}) -> void:
	var cue := _current if member.is_empty() else member
	var instance_id := str(cue.get("instance_id", ""))
	var tile_rect := _tile_rect(instance_id, is_discard)
	var destination := _rect_local(tile_rect).position
	var size := _tile_size(tile_rect)
	var source: Vector2
	var target: Vector2
	if is_discard:
		source = destination
		target = _point("discard") - size * 0.5
	else:
		source = _point("wall") - size * 0.5
		target = destination
	var ghost := _create_tile_ghost(str(cue.get("definition_id", "")), size)
	ghost.position = source
	ghost.scale = Vector2(0.74, 0.74)
	ghost.rotation = -0.16 if not is_discard else 0.10
	_animate_tile(tween, ghost, source, target, 52.0, -0.16 if not is_discard else 0.10, 0.0 if is_discard else 1.0)


func _build_settlement_fan(tween: Tween) -> void:
	var raw_ids: Variant = _current.get("instance_ids", [])
	var ids: Array = raw_ids if raw_ids is Array else []
	var raw_definitions: Variant = _current.get("definition_ids", [])
	var definitions: Array = raw_definitions if raw_definitions is Array else []
	var visual_count := mini(ids.size(), 7)
	var table_center := _point("discard")
	if str(_current.get("kind", "")) == "COMPLETE":
		match str(_current.get("destination", "Discard")):
			"Draw Wall": table_center = _point("wall")
			"Exhaust": table_center = _point("exhaust")
	for index in range(visual_count):
		var instance_id := str(ids[index])
		var definition_id := str(definitions[index]) if index < definitions.size() else ""
		if definition_id.is_empty():
			var tile_definitions: Variant = _anchors.get("tile_definitions", {})
			if tile_definitions is Dictionary:
				definition_id = str(tile_definitions.get(instance_id, ""))
		var rect := _tile_rect(instance_id, true)
		var tile_size := _tile_size(rect) * 0.90
		var source := _rect_local(rect).position
		var fan_offset := Vector2((float(index) - float(visual_count - 1) * 0.5) * 22.0, (float(index % 2) - 0.5) * 9.0)
		var destination := table_center + fan_offset - tile_size * 0.5
		var ghost := _create_tile_ghost(definition_id, tile_size)
		ghost.position = source
		ghost.scale = Vector2(0.84, 0.84)
		ghost.rotation = (float(index) - float(visual_count - 1) * 0.5) * 0.055
		_animate_tile(tween, ghost, source, destination, 44.0, ghost.rotation, 1.0)
	if visual_count > 0:
		_add_ink_track(tween, "stability", table_center, table_center, BRASS)


func _animate_tile(tween: Tween, ghost: Control, from: Vector2, to: Vector2, lift: float, turn: float, end_scale: float) -> void:
	var start_scale := ghost.scale.x
	var callable := Callable(self, "_set_tile_flight").bind(ghost, from, to, lift, turn, start_scale, end_scale)
	_add_method_track(tween, callable)


func _set_tile_flight(progress: float, ghost: Control, from: Vector2, to: Vector2, lift: float, turn: float, start_scale: float, end_scale: float) -> void:
	if not is_instance_valid(ghost):
		return
	var eased := _ease_out_cubic(progress)
	ghost.position = from.lerp(to, eased) + Vector2(0.0, -sin(PI * progress) * lift)
	ghost.rotation = turn * (1.0 - eased)
	var scale_value := lerpf(start_scale, end_scale, eased)
	ghost.scale = Vector2(scale_value, scale_value)


func _add_ink_track(tween: Tween, kind: String, from: Vector2, to: Vector2, color: Color) -> void:
	var ink: Control = FeedbackInkScript.new()
	ink.configure(kind, from, to, color)
	ink.z_index = 20
	add_child(ink)
	_visual_nodes.append(ink)
	var property_tween: PropertyTweener
	if _has_tween_track:
		property_tween = tween.parallel().tween_property(ink, "progress", 1.0, _duration)
	else:
		property_tween = tween.tween_property(ink, "progress", 1.0, _duration)
		_has_tween_track = true
	property_tween.set_trans(Tween.TRANS_LINEAR)
	property_tween.set_ease(Tween.EASE_IN_OUT)


func _add_method_track(tween: Tween, callable: Callable) -> void:
	var method_tween: MethodTweener
	if _has_tween_track:
		method_tween = tween.parallel().tween_method(callable, 0.0, 1.0, _duration)
	else:
		method_tween = tween.tween_method(callable, 0.0, 1.0, _duration)
		_has_tween_track = true
	# Spatial callbacks provide their own easing; avoid applying it twice.
	method_tween.set_trans(Tween.TRANS_LINEAR)
	method_tween.set_ease(Tween.EASE_IN_OUT)


func _add_caption_track(tween: Tween, caption_text: String, anchor: Vector2, color: Color, font_role: String, offset: Vector2, start_fraction: float = 0.0) -> void:
	if caption_text.strip_edges().is_empty():
		return
	var ui_scale := ForbiddenThemeScript.ui_scale_for(self)
	var font_size := ForbiddenThemeScript.font_size_for(font_role, ui_scale)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = caption_text
	label.visible = start_fraction <= 0.0
	label.size = Vector2(minf(360.0 * ui_scale, maxf(200.0, size.x - 16.0)), maxf(54.0 * ui_scale, font_size * 2.0 + 12.0 * ui_scale))
	label.position = _caption_position(anchor + offset - label.size * 0.5, label.size)
	label.z_index = 42
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", ForbiddenThemeScript.color("ink"))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(label)
	_visual_nodes.append(label)
	var from := label.position
	var to := from + Vector2(0.0, -34.0)
	_add_method_track(tween, Callable(self, "_set_caption_position").bind(label, from, to, start_fraction))


func _set_caption_position(progress: float, label: Control, from: Vector2, to: Vector2, start_fraction: float = 0.0) -> void:
	if is_instance_valid(label):
		label.visible = progress >= start_fraction
		var phase := clampf((progress - start_fraction) / maxf(0.01, 1.0 - start_fraction), 0.0, 1.0)
		label.position = from.lerp(to, _ease_out_cubic(phase))


func _add_amount_track(tween: Tween, amount_text: String, caption_text: String, anchor: Vector2, amount_color: Color, caption_color: Color, start_fraction: float = 0.0) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = amount_text
	label.visible = start_fraction <= 0.0
	var ui_scale := ForbiddenThemeScript.ui_scale_for(self)
	var amount_font_size := ForbiddenThemeScript.font_size_for("title", ui_scale)
	label.size = Vector2(minf(360.0 * ui_scale, maxf(200.0, size.x - 16.0)), maxf(60.0 * ui_scale, amount_font_size * 1.4 + 16.0 * ui_scale))
	label.position = _caption_position(anchor + Vector2(-label.size.x * 0.5, -70.0 * ui_scale), label.size)
	label.z_index = 43
	label.add_theme_font_size_override("font_size", amount_font_size)
	label.add_theme_color_override("font_color", amount_color)
	label.add_theme_color_override("font_outline_color", ForbiddenThemeScript.color("ink"))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
	_visual_nodes.append(label)
	var from := label.position
	_add_method_track(tween, Callable(self, "_set_caption_position").bind(label, from, from + Vector2(0.0, -38.0), start_fraction))
	_add_caption_track(tween, caption_text, anchor, caption_color, "secondary", Vector2(0.0, 15.0), start_fraction)


func _caption_position(desired: Vector2, caption_size: Vector2) -> Vector2:
	# Keep the upward float inside the visible battlefield, including actors
	# near its upper-left edge and the wall near its right edge.
	return Vector2(clampf(desired.x, 8.0, maxf(8.0, size.x - caption_size.x - 8.0)), clampf(desired.y, 44.0, maxf(44.0, size.y - caption_size.y - 8.0)))


func _create_tile_ghost(definition_id: String, tile_size: Vector2) -> Control:
	var ghost := Panel.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.focus_mode = Control.FOCUS_NONE
	ghost.size = tile_size
	ghost.pivot_offset = tile_size * 0.5
	ghost.z_index = 32
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#F5EBD4")
	style.border_color = BRASS
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 5.0)
	ghost.add_theme_stylebox_override("panel", style)
	var texture := ForbiddenThemeScript.tile_texture(definition_id)
	if texture != null:
		var art := TextureRect.new()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.focus_mode = Control.FOCUS_NONE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = texture
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 3.0
		art.offset_top = 3.0
		art.offset_right = -3.0
		art.offset_bottom = -3.0
		ghost.add_child(art)
	else:
		var fallback := Label.new()
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.text = definition_id.get_slice(".", definition_id.get_slice_count(".") - 1)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_color_override("font_color", ForbiddenThemeScript.color("ink"))
		ghost.add_child(fallback)
	add_child(ghost)
	_visual_nodes.append(ghost)
	return ghost


func _enemy_effect_target(cue: Dictionary = {}) -> Vector2:
	var effect_cue := _current if cue.is_empty() else cue
	var target_id := str(effect_cue.get("target_instance_id", ""))
	var target_rect := _lookup_rect(target_id, true)
	if target_rect.size != Vector2.ZERO:
		return _rect_local(target_rect).get_center()
	var channel := str(effect_cue.get("channel", "")).to_lower()
	match channel:
		"draw_wall", "draw_capacity":
			return _point("wall")
		"reserve_integrity":
			return _point("reserve") if _anchors.has("reserve") else _point("player")
		"stability", "tp", "fatigue", "reward_tax":
			return _point("player")
	var action_type := str(effect_cue.get("action_type", "")).to_upper()
	if action_type in ["WALL_TAX", "CONTAMINATION"]:
		return _point("wall")
	if action_type == "TABLE_INTERFERENCE":
		return _point("discard")
	return _point("player")


func _cue_text() -> String:
	return str(_current.get("text", ""))


func _point(anchor_name: String) -> Vector2:
	var fallback := _fallback_anchor(anchor_name)
	var raw_value: Variant = _anchors.get(anchor_name, fallback)
	var global_point := fallback
	if raw_value is Vector2:
		global_point = raw_value
	elif raw_value is Rect2:
		global_point = raw_value.get_center()
	return _global_to_local(global_point)


func _tile_rect(instance_id: String, departing_first: bool) -> Rect2:
	if departing_first:
		var departing := _lookup_rect(instance_id, true)
		if departing.size != Vector2.ZERO:
			return departing
	var final_rect := _lookup_rect(instance_id, false)
	if final_rect.size != Vector2.ZERO:
		return final_rect
	var center := get_global_transform() * _point("hand")
	return Rect2(center - Vector2(21.0, 32.0), Vector2(42.0, 64.0))


func _lookup_rect(instance_id: String, departing: bool) -> Rect2:
	if instance_id.is_empty():
		return Rect2()
	var map_key := "departing_tiles" if departing else "tiles"
	var tile_map: Variant = _anchors.get(map_key, {})
	if tile_map is Dictionary:
		var value: Variant = tile_map.get(instance_id, Rect2())
		if value is Rect2:
			return value
	return Rect2()


func _tile_size(global_rect: Rect2) -> Vector2:
	var local_rect := _rect_local(global_rect)
	return Vector2(maxf(36.0, local_rect.size.x), maxf(52.0, local_rect.size.y))


func _rect_local(global_rect: Rect2) -> Rect2:
	var first := _global_to_local(global_rect.position)
	var second := _global_to_local(global_rect.end)
	return Rect2(first, second - first)


func _global_to_local(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


func _fallback_anchor(anchor_name: String) -> Vector2:
	var extent := size
	if extent.x <= 0.0 or extent.y <= 0.0:
		extent = get_viewport_rect().size if get_viewport() != null else Vector2(960.0, 540.0)
	var ratio := Vector2(0.5, 0.5)
	match anchor_name:
		"enemy":
			ratio = Vector2(0.82, 0.29)
		"player":
			ratio = Vector2(0.16, 0.39)
		"wall":
			ratio = Vector2(0.79, 0.72)
		"hand":
			ratio = Vector2(0.31, 0.72)
		"discard":
			ratio = Vector2(0.55, 0.55)
	return extent * ratio


func _cue_duration(kind: String) -> float:
	return float(CUE_DURATIONS.get(kind.to_upper(), 0.45))


func _duration_scale() -> float:
	return FAST_DURATION_SCALE if presentation_mode == FAST else 1.0


func _animations_disabled() -> bool:
	return reduced_motion or presentation_mode == INSTANT


func _normalize_mode(mode: String) -> String:
	var normalized := mode.to_upper()
	return normalized if normalized in [NORMAL, FAST, INSTANT] else NORMAL


func _ease_out_cubic(progress: float) -> float:
	var remainder := 1.0 - clampf(progress, 0.0, 1.0)
	return 1.0 - remainder * remainder * remainder


func _clear_visuals() -> void:
	for node in _visual_nodes:
		if is_instance_valid(node):
			node.free()
	_visual_nodes.clear()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and _playing:
		cancel()


func _exit_tree() -> void:
	cancel()
