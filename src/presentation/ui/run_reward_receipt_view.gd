extends PanelContainer

signal receipt_visibility_changed(is_visible: bool)

const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

class ReceiptKindIcon extends Control:
	var kind := ""
	var accent := Color.WHITE
	var secondary := Color.WHITE

	func configure(initial_kind: String, primary_color: Color, secondary_color: Color, ui_scale: float) -> void:
		kind = initial_kind
		accent = primary_color
		secondary = secondary_color
		custom_minimum_size = Vector2(40.0, 40.0) * ui_scale
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.34
		match kind:
			"RELIC":
				var diamond := PackedVector2Array([center + Vector2(0.0, -radius), center + Vector2(radius * 0.72, 0.0), center + Vector2(0.0, radius), center + Vector2(-radius * 0.72, 0.0)])
				draw_colored_polygon(diamond, accent)
				draw_circle(center, radius * 0.16, secondary)
			"SPECIAL":
				draw_circle(center, radius, accent)
				draw_circle(center, radius * 0.67, secondary)
				draw_circle(center, radius * 0.22, accent)
			"RUN_TECHNIQUE", "TECHNIQUE":
				var bolt := PackedVector2Array([center + Vector2(radius * 0.1, -radius), center + Vector2(-radius * 0.52, radius * 0.05), center + Vector2(-radius * 0.08, radius * 0.05), center + Vector2(-radius * 0.24, radius), center + Vector2(radius * 0.56, -radius * 0.08), center + Vector2(radius * 0.12, -radius * 0.08)])
				draw_colored_polygon(bolt, accent)
			"RULE_BREAKER":
				draw_arc(center, radius, 0.28, TAU - 0.28, 32, accent, maxf(2.0, size.x * 0.055), true)
				draw_line(center + Vector2(-radius * 0.64, radius * 0.55), center + Vector2(radius * 0.65, -radius * 0.58), secondary, maxf(2.0, size.x * 0.07), true)
			"REMOVE":
				draw_arc(center, radius, 0.0, TAU, 32, accent, maxf(2.0, size.x * 0.065), true)
				draw_line(center + Vector2(-radius * 0.55, 0.0), center + Vector2(radius * 0.55, 0.0), accent, maxf(2.0, size.x * 0.09), true)
			"SKIP":
				draw_circle(center, radius, accent)
				draw_arc(center, radius * 0.62, 0.0, TAU, 32, secondary, maxf(1.5, size.x * 0.045), true)
			_:
				draw_rect(Rect2(center - Vector2(radius * 0.62, radius * 0.82), Vector2(radius * 1.24, radius * 1.64)), accent, false, maxf(2.0, size.x * 0.05), true)
				draw_circle(center, radius * 0.2, secondary)

var _locale := "en"
var _ui_scale := 1.0
var _last_result: Dictionary = {}
var _last_before_state: Dictionary = {}
var _last_after_state: Dictionary = {}
var _last_content_registry
var _compact_layout := false


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("margin_left", 12)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_right", 12)
	add_theme_constant_override("margin_bottom", 8)
	ForbiddenThemeScript.style_panel(self, "raised")


func _ready() -> void:
	set_presentation_preferences(_locale, _ui_scale)
	resized.connect(_refresh_layout_for_viewport)


func set_presentation_preferences(locale: String, ui_scale: float) -> void:
	_locale = "zh_CN" if locale.to_lower().begins_with("zh") else "en"
	_ui_scale = clampf(ui_scale, 1.0, 1.5)
	theme = ForbiddenThemeScript.create_theme(_locale, _ui_scale)
	if not _last_result.is_empty():
		_render_result(_last_result, _last_before_state, _last_after_state, _last_content_registry)


func show_result(result: Dictionary, before_state: Dictionary, after_state: Dictionary, content_registry, ui_scale: float = 1.0) -> bool:
	if not bool(result.get("accepted", false)) or bool(result.get("preview", false)):
		return false
	var normalized_events: Variant = result.get("events", [])
	if not normalized_events is Array:
		return false
	var presentation := _presentation_for_events(normalized_events, before_state, after_state, content_registry)
	if presentation.is_empty():
		return false
	_ui_scale = clampf(ui_scale, 1.0, 1.5)
	theme = ForbiddenThemeScript.create_theme(_locale, _ui_scale)
	_last_result = result.duplicate(true)
	_last_before_state = before_state.duplicate(true)
	_last_after_state = after_state.duplicate(true)
	_last_content_registry = content_registry
	_render_presentation(presentation)
	visible = true
	update_minimum_size()
	receipt_visibility_changed.emit(true)
	return true


func clear_receipt() -> void:
	_last_result.clear()
	_last_before_state.clear()
	_last_after_state.clear()
	_last_content_registry = null
	_clear_children()
	var was_visible := visible
	visible = false
	custom_minimum_size.y = 0.0
	update_minimum_size()
	if was_visible:
		receipt_visibility_changed.emit(false)


func _presentation_for_events(events: Array, before_state: Dictionary, after_state: Dictionary, content_registry) -> Dictionary:
	var workshop_data: Dictionary = {}
	for event in events:
		var event_type := str(event.get("event_type", "")) if event is Dictionary else ""
		var data: Dictionary = event.get("data", {}) if event is Dictionary and event.get("data", {}) is Dictionary else {}
		match event_type:
			"RewardSelected":
				return _reward_presentation(data, before_state, after_state, content_registry)
			"ShopOfferPurchased":
				return _shop_presentation(data, content_registry)
			"WorkshopServiceUsed":
				workshop_data = data
			"TileRemoved":
				if workshop_data.is_empty():
					workshop_data = {"service_id": "REMOVE", "instance_id": str(data.get("instance_id", ""))}
	if not workshop_data.is_empty():
		return _workshop_presentation(workshop_data, before_state, after_state, content_registry)
	return {}


func _reward_presentation(data: Dictionary, before_state: Dictionary, after_state: Dictionary, content_registry) -> Dictionary:
	var kind := str(data.get("kind", ""))
	var content_id := str(data.get("content_id", data.get("tile_id", "")))
	var presentation := {
		"heading_key": "UI_RUN_RECEIPT_REWARD",
		"kind": kind,
		"title": LocalizationCatalogScript.text("UI_RUN_REWARD_KIND_SKIP") if kind == "SKIP" else _content_name(content_id),
		"effect_lines": [],
		"tiles": [],
	}
	match kind:
		"ADD_TILE":
			presentation.heading_key = "UI_RUN_RECEIPT_TILE_ADDED"
			presentation.tiles = [_tile_visual(_tile_record(after_state, str(data.get("tile_instance_id", ""))), [])]
			presentation.effect_lines = [LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_ADD_TILE")]
		"MODIFIED_TILE":
			presentation.heading_key = "UI_RUN_RECEIPT_TILE_IMPROVED"
			var target_ids: Array = data.get("target_instance_ids", [])
			if not target_ids.is_empty():
				presentation["parallel_tiles"] = true
				var target_tile := _tile_record(after_state, str(target_ids[0]))
				presentation.title = _content_name(str(target_tile.get("definition_id", data.get("tile_id", ""))))
				for target_id in target_ids:
					presentation.tiles.append(_tile_visual(_tile_record(after_state, str(target_id)), _modifier_names(after_state, str(target_id), content_registry)))
				presentation.effect_lines = [LocalizationCatalogScript.format("UI_RC7_REWARD_TARGET_EFFECT", [presentation.title, target_ids.size(), _content_name(str(data.get("modifier_id", "")))])]
				return presentation
			var instance_id := _changed_modifier_instance(before_state, after_state)
			var tile := _tile_record(after_state, instance_id)
			var modifier_id := str(data.get("modifier_id", ""))
			var annotations := _modifier_names(after_state, instance_id, content_registry)
			presentation.title = _content_name(str(tile.get("definition_id", data.get("tile_id", ""))))
			presentation.tiles = [_tile_visual(_tile_record(before_state, instance_id), []), _tile_visual(tile, annotations)]
			presentation.effect_lines = [LocalizationCatalogScript.format("UI_RUN_REWARD_EFFECT_MODIFIER_TO_TILE", [presentation.title, _content_name(modifier_id)])]
		"SKIP":
			presentation.kind = "SKIP"
			presentation.title = LocalizationCatalogScript.text("UI_RUN_REWARD_KIND_SKIP")
			presentation.effect_lines = _transaction_lines(data.get("currency_transactions", []))
		"RELIC", "RUN_TECHNIQUE", "RULE_BREAKER":
			presentation.effect_lines = [LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_ACQUIRE")]
			presentation.effect_lines.append_array(_definition_effect_lines(content_registry, content_id))
		_:
			return {}
	return presentation


func _shop_presentation(data: Dictionary, content_registry) -> Dictionary:
	var offer: Dictionary = data.get("offer", {}) if data.get("offer", {}) is Dictionary else {}
	var kind := str(offer.get("kind", ""))
	var content_id := str(offer.get("content_id", ""))
	var metadata: Dictionary = offer.get("metadata", {}) if offer.get("metadata", {}) is Dictionary else {}
	var offer_definition = content_registry.resolve(content_id) if content_registry != null and not content_id.is_empty() else null
	var offer_title := _content_name(content_id) if offer_definition != null else _category_label(kind)
	var presentation := {
		"heading_key": "UI_RUN_RECEIPT_SHOP_PURCHASED",
		"kind": kind,
		"title": offer_title,
		"effect_lines": [] if kind == "SPECIAL" else [LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_ACQUIRE")],
		"tiles": [],
	}
	if kind == "TILE":
		presentation.kind = "ADD_TILE"
		presentation.tiles = [_tile_visual({"definition_id": content_id}, [])]
		presentation.effect_lines = [LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_ADD_TILE")]
	else:
		if kind == "TECHNIQUE":
			presentation.kind = "RUN_TECHNIQUE"
		if kind != "SPECIAL":
			presentation.effect_lines.append_array(_definition_effect_lines(content_registry, content_id))
	var transaction_lines := _transaction_lines(data.get("currency_transactions", []))
	if kind == "SPECIAL" and transaction_lines.is_empty():
		transaction_lines = _special_offer_effect_lines(str(metadata.get("special_action", "")))
	presentation.effect_lines.append_array(transaction_lines)
	return presentation


func _workshop_presentation(data: Dictionary, before_state: Dictionary, after_state: Dictionary, content_registry) -> Dictionary:
	var service_id := str(data.get("service_id", ""))
	var instance_id := str(data.get("instance_id", ""))
	var before_tile := _tile_record(before_state, instance_id)
	var after_tile := _tile_record(after_state, instance_id)
	var before_id := str(before_tile.get("definition_id", ""))
	var after_id := str(after_tile.get("definition_id", data.get("definition_id", before_id)))
	var new_instance_id := str(data.get("tile_instance_id", ""))
	var presentation := {
		"heading_key": "UI_RUN_RECEIPT_TILE_MODIFIED",
		"kind": "MODIFIED_TILE",
		"title": _content_name(after_id if not after_id.is_empty() else before_id),
		"effect_lines": [],
		"tiles": [],
	}
	match service_id:
		"REMOVE_PAIR":
			presentation["parallel_tiles"] = true
			presentation.heading_key = "UI_RUN_RECEIPT_TILE_REMOVED"
			presentation.kind = "REMOVE"
			presentation.title = _content_name(before_id)
			for removed_id in data.get("instance_ids", []):
				presentation.tiles.append(_tile_visual(_tile_record(before_state, str(removed_id)), _modifier_names(before_state, str(removed_id), content_registry)))
			presentation.effect_lines = [LocalizationCatalogScript.text("UI_RC7_REMOVE_PAIR_RECEIPT")]
		"REMOVE":
			presentation.heading_key = "UI_RUN_RECEIPT_TILE_REMOVED"
			presentation.kind = "REMOVE"
			presentation.title = _content_name(before_id)
			presentation.tiles = [_tile_visual(before_tile, _modifier_names(before_state, instance_id, content_registry))]
		"TRANSFORM":
			presentation.heading_key = "UI_RUN_RECEIPT_TILE_TRANSFORMED"
			presentation.kind = "TRANSFORM"
			presentation.title = _content_name(after_id)
			presentation.tiles = [_tile_visual(before_tile, _modifier_names(before_state, instance_id, content_registry)), _tile_visual(after_tile, _modifier_names(after_state, instance_id, content_registry))]
		"DUPLICATE", "REFINEMENT_TOKEN":
			presentation.heading_key = "UI_RUN_RECEIPT_TILE_DUPLICATED"
			presentation.kind = "ADD_TILE"
			var duplicate_record := _tile_record(after_state, new_instance_id)
			presentation.title = _content_name(str(duplicate_record.get("definition_id", before_id)))
			presentation.tiles = [_tile_visual(before_tile, _modifier_names(before_state, instance_id, content_registry)), _tile_visual(_tile_record(after_state, new_instance_id), _modifier_names(after_state, new_instance_id, content_registry))]
		"ADD_MODIFIER", "REPLACE_MODIFIER", "MODIFIER":
			presentation.heading_key = "UI_RUN_RECEIPT_TILE_MODIFIED"
			presentation.tiles = [_tile_visual(before_tile, _modifier_names(before_state, instance_id, content_registry)), _tile_visual(after_tile, _modifier_names(after_state, instance_id, content_registry))]
		_:
			return {}
	if not before_id.is_empty() and not after_id.is_empty() and before_id == after_id and service_id in ["ADD_MODIFIER", "REPLACE_MODIFIER", "MODIFIER"]:
		var modifier_id := str(data.get("modifier_id", ""))
		presentation.effect_lines = [LocalizationCatalogScript.format("UI_RUN_REWARD_EFFECT_MODIFIER_TO_TILE", [_content_name(before_id), _content_name(modifier_id)])]
	presentation.effect_lines.append_array(_transaction_lines(data.get("currency_transactions", [])))
	return presentation


func _render_result(result: Dictionary, before_state: Dictionary, after_state: Dictionary, content_registry) -> void:
	var presentation := _presentation_for_events(result.get("events", []), before_state, after_state, content_registry)
	if presentation.is_empty():
		clear_receipt()
		return
	_render_presentation(presentation)
	visible = true


func _render_presentation(presentation: Dictionary) -> void:
	_clear_children()
	custom_minimum_size = Vector2.ZERO
	_compact_layout = get_viewport_rect().size.x < 600.0
	var content := BoxContainer.new()
	content.vertical = _compact_layout
	content.name = "ReceiptContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.focus_mode = Control.FOCUS_NONE
	content.add_theme_constant_override("separation", 12)
	add_child(content)
	var kind := str(presentation.get("kind", ""))
	var visual_cluster := HBoxContainer.new()
	visual_cluster.name = "ReceiptVisualCluster"
	visual_cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	visual_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual_cluster.focus_mode = Control.FOCUS_NONE
	visual_cluster.add_theme_constant_override("separation", 8)
	content.add_child(visual_cluster)
	var icon := ReceiptKindIcon.new()
	icon.name = "ReceiptCategoryIcon"
	var icon_color := ForbiddenThemeScript.color("error") if kind == "REMOVE" else ForbiddenThemeScript.color("brass")
	icon.configure(kind, icon_color, ForbiddenThemeScript.color("focus"), _ui_scale * 0.9)
	visual_cluster.add_child(icon)
	var tile_visuals: Array = presentation.get("tiles", [])
	if not tile_visuals.is_empty():
		var tile_row := HBoxContainer.new()
		tile_row.name = "ReceiptTileVisuals"
		tile_row.alignment = BoxContainer.ALIGNMENT_CENTER
		tile_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_row.focus_mode = Control.FOCUS_NONE
		tile_row.add_theme_constant_override("separation", 4)
		visual_cluster.add_child(tile_row)
		for index in tile_visuals.size():
			if index > 0:
				var arrow := Label.new()
				arrow.text = LocalizationCatalogScript.text("UI_RC7_COPY_SEPARATOR" if bool(presentation.get("parallel_tiles", false)) else "UI_RUN_TILE_TRANSITION")
				arrow.name = "ReceiptTileTransition"
				arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				arrow.focus_mode = Control.FOCUS_NONE
				_style_label(arrow, "caption")
				tile_row.add_child(arrow)
			_add_receipt_tile(tile_row, tile_visuals[index], index)
	else:
		var category := Label.new()
		category.name = "ReceiptCategoryLabel"
		category.text = _category_label(kind)
		category.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		category.mouse_filter = Control.MOUSE_FILTER_IGNORE
		category.focus_mode = Control.FOCUS_NONE
		_style_label(category, "caption")
		visual_cluster.add_child(category)
	var title_stack := VBoxContainer.new()
	title_stack.name = "ReceiptText"
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_stack.focus_mode = Control.FOCUS_NONE
	title_stack.add_theme_constant_override("separation", 2)
	content.add_child(title_stack)
	var heading := Label.new()
	heading.name = "ReceiptHeading"
	heading.text = LocalizationCatalogScript.text(str(presentation.get("heading_key", "UI_RUN_RECEIPT_REWARD")))
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.focus_mode = Control.FOCUS_NONE
	_style_label(heading, "caption")
	heading.add_theme_color_override("font_color", ForbiddenThemeScript.color("brass"))
	title_stack.add_child(heading)
	var title := Label.new()
	title.name = "ReceiptTitle"
	title.text = str(presentation.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.focus_mode = Control.FOCUS_NONE
	_style_label(title, "body")
	title_stack.add_child(title)

	var effect_lines: Array = presentation.get("effect_lines", [])
	if not effect_lines.is_empty():
		var effects := Label.new()
		effects.name = "ReceiptEffectDetails"
		var localized_effect_lines := PackedStringArray(effect_lines)
		var localized_effect_text := "\n".join(localized_effect_lines)
		effects.text = localized_effect_text
		effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effects.focus_mode = Control.FOCUS_NONE
		_style_label(effects, "secondary")
		title_stack.add_child(effects)
	update_minimum_size()


func _add_receipt_tile(parent: Control, visual: Dictionary, index: int) -> void:
	var tile_id := str(visual.get("definition_id", ""))
	if tile_id.is_empty():
		return
	var stack := VBoxContainer.new()
	stack.name = "ReceiptTileVisual_%d" % index
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.focus_mode = Control.FOCUS_NONE
	parent.add_child(stack)
	var face := TextureRect.new()
	face.name = "ReceiptTileFace" if index == 0 else "ReceiptTileFace_%d" % index
	face.texture = ForbiddenThemeScript.tile_texture(tile_id)
	face.custom_minimum_size = Vector2(44.0, 62.0) * _ui_scale
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.tooltip_text = _content_name(tile_id)
	stack.add_child(face)
	var annotations: Array = visual.get("annotations", [])
	if not annotations.is_empty():
		var label := Label.new()
		label.name = "ReceiptTileModifier"
		var localized_annotations := PackedStringArray(annotations)
		var localized_annotation_text := ", ".join(localized_annotations)
		label.text = localized_annotation_text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.focus_mode = Control.FOCUS_NONE
		_style_label(label, "caption")
		stack.add_child(label)


func _style_label(label: Label, role: String) -> void:
	ForbiddenThemeScript.style_label(label, role, _locale)
	# Receipt labels are constructed before they join the themed scene tree. Use
	# the stored presentation scale directly so the role stays readable at 125/150%.
	label.add_theme_font_size_override("font_size", ForbiddenThemeScript.font_size_for(role, _ui_scale))


func _tile_visual(record: Dictionary, annotations: Array) -> Dictionary:
	return {"definition_id": str(record.get("definition_id", "")), "annotations": annotations.duplicate()}


func _tile_record(state_snapshot: Dictionary, instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	var tile_pool: Dictionary = state_snapshot.get("tile_pool", {}) if state_snapshot.get("tile_pool", {}) is Dictionary else {}
	var records: Array = tile_pool.get("tile_instances", []) if tile_pool.get("tile_instances", []) is Array else []
	for record in records:
		if record is Dictionary and str(record.get("instance_id", "")) == instance_id:
			return record
	return {}


func _changed_modifier_instance(before_state: Dictionary, after_state: Dictionary) -> String:
	var before_build: Dictionary = before_state.get("build_ownership", {}) if before_state.get("build_ownership", {}) is Dictionary else {}
	var after_build: Dictionary = after_state.get("build_ownership", {}) if after_state.get("build_ownership", {}) is Dictionary else {}
	var before_map: Dictionary = before_build.get("persistent_tile_modifier_state", {}) if before_build.get("persistent_tile_modifier_state", {}) is Dictionary else {}
	var after_map: Dictionary = after_build.get("persistent_tile_modifier_state", {}) if after_build.get("persistent_tile_modifier_state", {}) is Dictionary else {}
	for raw_id in after_map:
		var instance_id := str(raw_id)
		if before_map.get(raw_id, []) != after_map.get(raw_id, []):
			return instance_id
	return ""


func _modifier_names(state_snapshot: Dictionary, instance_id: String, content_registry) -> Array[String]:
	var build: Dictionary = state_snapshot.get("build_ownership", {}) if state_snapshot.get("build_ownership", {}) is Dictionary else {}
	var modifiers: Dictionary = build.get("persistent_tile_modifier_state", {}) if build.get("persistent_tile_modifier_state", {}) is Dictionary else {}
	var names: Array[String] = []
	for modifier_id in modifiers.get(instance_id, []):
		names.append(_content_name(str(modifier_id)))
	return names


func _transaction_lines(transactions: Variant) -> Array[String]:
	var lines: Array[String] = []
	if not transactions is Array:
		return lines
	for transaction in transactions:
		if not transaction is Dictionary:
			continue
		var amount := int(transaction.get("amount", 0))
		if amount == 0:
			continue
		var currency := str(transaction.get("currency", "GOLD"))
		var word := "REFINEMENT_TOKENS" if currency == "REFINEMENT_TOKENS" else "GOLD"
		lines.append(LocalizationCatalogScript.format("UI_RUN_REWARD_CHANGE_AMOUNT", [LocalizationCatalogScript.word_text(word), _signed_amount(amount)]))
	return lines


func _special_offer_effect_lines(special_action: String) -> Array[String]:
	match special_action:
		"GOLD_CACHE":
			return [_change(LocalizationCatalogScript.word_text("GOLD"), 3)]
		"REFINEMENT_TOKEN":
			return [_change(LocalizationCatalogScript.word_text("REFINEMENT_TOKENS"), 1)]
	return []


func _category_label(kind: String) -> String:
	var category := kind
	if category in ["TECHNIQUE", "RUN_TECHNIQUE"]:
		category = "TECHNIQUE"
	if category in ["REMOVE", "TRANSFORM", "MODIFIED_TILE"]:
		category = "MODIFIED_TILE"
	var key := "UI_RUN_REWARD_KIND_%s" % category
	var localized := LocalizationCatalogScript.text(key)
	if localized != key:
		return localized
	if category == "SPECIAL":
		return LocalizationCatalogScript.text("UI_RUN_RECEIPT_SHOP_PURCHASED")
	return LocalizationCatalogScript.text("UI_RUN_REWARD_KIND_TILE")


func _definition_effect_lines(content_registry, content_id: String) -> Array[String]:
	var lines: Array[String] = []
	if content_registry == null or content_id.is_empty():
		return lines
	var definition = content_registry.resolve(content_id)
	if definition == null or not definition.get("effects") is Array:
		return lines
	for effect in definition.get("effects"):
		if effect == null or not effect.get("operations") is Array:
			continue
		for operation in effect.get("operations"):
			var summary := _effect_operation_line(operation, content_id)
			if not summary.is_empty() and not lines.has(summary):
				lines.append(summary)
	return lines


func _effect_operation_line(operation, content_id: String) -> String:
	if operation == null or not operation.has_method("to_dictionary"):
		return ""
	var details: Dictionary = operation.to_dictionary()
	var operation_id := str(details.get("operation_id", operation.get("operation_id")))
	var amount := int(details.get("amount", 1))
	match operation_id:
		"GainTP": return _change(LocalizationCatalogScript.word_text("TP"), amount)
		"GainStability": return _change(LocalizationCatalogScript.word_text("STABILITY"), amount)
		"GainPressure": return _change(LocalizationCatalogScript.word_text("PRESSURE"), amount)
		"DealDamage": return _change(LocalizationCatalogScript.word_text("DAMAGE"), amount)
		"ModifyReserveCapacity": return _change(LocalizationCatalogScript.word_text("RESERVE_CAPACITY"), amount)
		"ModifySettlementCapacity": return _change(LocalizationCatalogScript.word_text("SETTLEMENT_CAPACITY"), amount)
		"ModifyDrawCapacity": return _change(LocalizationCatalogScript.word_text("DRAW_CAPACITY"), amount)
		"ModifyRunCurrency":
			var currency := str(details.get("currency", "GOLD"))
			return _change(LocalizationCatalogScript.word_text("REFINEMENT_TOKENS" if currency == "REFINEMENT_TOKENS" else "GOLD"), amount)
		"ModifyRefinementTokens": return _change(LocalizationCatalogScript.word_text("REFINEMENT_TOKENS"), amount)
		"DrawTile": return LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_DRAW_TILE")
		"PurgeContamination": return LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_PURGE_CONTAMINATION")
		"ApplyRunModifier":
			var parameters: Dictionary = details.get("parameters", {}) if details.get("parameters", {}) is Dictionary else {}
			var discount := int(parameters.get("workshop_price_discount", 0))
			if discount > 0:
				return LocalizationCatalogScript.format("UI_RUN_REWARD_EFFECT_WORKSHOP_DISCOUNT", [discount])
			return LocalizationCatalogScript.format("UI_RUN_REWARD_EFFECT_RUN_MODIFIER", [_content_name(content_id)])
	return ""


func _change(label: String, amount: int) -> String:
	return LocalizationCatalogScript.format("UI_RUN_REWARD_CHANGE_AMOUNT", [label, _signed_amount(amount)])


func _signed_amount(amount: int) -> String:
	return ("+" if amount > 0 else "−" if amount < 0 else "") + str(absi(amount))


func _content_name(content_id: String) -> String:
	return LocalizationCatalogScript.content_text(content_id) if not content_id.is_empty() else ""


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _refresh_layout_for_viewport() -> void:
	var compact := get_viewport_rect().size.x < 600.0
	if compact == _compact_layout or _last_result.is_empty():
		return
	_render_result(_last_result, _last_before_state, _last_after_state, _last_content_registry)
