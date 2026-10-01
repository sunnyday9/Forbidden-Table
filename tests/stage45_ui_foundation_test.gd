class_name Stage45UiFoundationTest
extends RefCounted

const ForbiddenTheme = preload("res://src/presentation/ui/forbidden_theme.gd")
const TileFaceButton = preload("res://src/presentation/ui/tile_face_button.gd")
const TableBackdrop = preload("res://src/presentation/ui/table_backdrop.gd")
const MotionFeedback = preload("res://src/presentation/ui/motion_feedback.gd")
const TILE_MANIFEST_PATH := "res://assets/ui/tiles/chinese-tiles/manifest.json"


func run() -> Array[String]:
	var failures: Array[String] = []
	test_theme_roles_and_shared_styles(failures)
	test_every_face_matches_the_pinned_manifest(failures)
	await test_tile_identity_selection_and_focus(failures)
	await test_backdrop_readability_and_motion_preferences(failures)
	await test_feedback_cancellation_and_immediate_modes(failures)
	return failures


func test_theme_roles_and_shared_styles(failures: Array[String]) -> void:
	var theme := ForbiddenTheme.create_theme("en", 1.25)
	assert_true(theme != null and theme.default_font != null, "English theme loads its licensed regular font", failures)
	assert_true(theme.default_font_size == 20, "125% theme scales the base type size", failures)
	assert_true(theme.get_meta("forbidden_table_ui_scale") == 1.25, "theme publishes its scale to descendant controls", failures)
	assert_true(ForbiddenTheme.color("brass") == Color("#E7B65A"), "theme exposes the approved brass token", failures)

	var themed_root := Control.new()
	themed_root.theme = theme
	var first_panel := PanelContainer.new()
	var second_panel := PanelContainer.new()
	themed_root.add_child(first_panel)
	themed_root.add_child(second_panel)
	ForbiddenTheme.style_panel(first_panel, "lacquer")
	ForbiddenTheme.style_panel(second_panel, "lacquer")
	var first_panel_style := first_panel.get_theme_stylebox("panel")
	var second_panel_style := second_panel.get_theme_stylebox("panel")
	assert_true(first_panel_style is StyleBoxFlat, "lacquer panel uses a reusable StyleBoxFlat", failures)
	assert_true(first_panel_style == second_panel_style, "matching panels share one immutable style resource", failures)

	var button := Button.new()
	themed_root.add_child(button)
	ForbiddenTheme.style_button(button, true)
	assert_true(button.custom_minimum_size.y >= 55.0, "125% buttons retain the 44 px hit height after scaling", failures)
	assert_true(button.get_theme_font_size("font_size") == 20, "button helper inherits scale from an ancestor theme", failures)
	var button_font := button.get_theme_font("font")
	for glyph in ["简", "体", "中", "文"]:
		assert_true(button_font != null and button_font.has_char(glyph.unicode_at(0)), "English settings font covers the Chinese autonym glyph %s" % glyph, failures)
	var title_label := Label.new()
	themed_root.add_child(title_label)
	ForbiddenTheme.title(title_label, "en")
	var title_font := title_label.get_theme_font("font")
	assert_true(title_font != null and title_font.has_char("简".unicode_at(0)), "English title font keeps the Simplified Chinese autonym visible", failures)
	var chinese_theme := ForbiddenTheme.create_theme("zh_CN")
	assert_true(chinese_theme.default_font != null and chinese_theme.default_font.has_char("简".unicode_at(0)), "Simplified Chinese theme uses a font with CJK coverage", failures)
	themed_root.free()


func test_every_face_matches_the_pinned_manifest(failures: Array[String]) -> void:
	var manifest_file := FileAccess.open(TILE_MANIFEST_PATH, FileAccess.READ)
	assert_true(manifest_file != null, "runtime face manifest is present beside the licensed assets", failures)
	if manifest_file == null:
		return
	var manifest: Variant = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	assert_true(manifest is Dictionary and manifest.get("assets", []).size() == 34, "manifest pins all 34 existing tile faces", failures)
	if not manifest is Dictionary:
		return
	var seen_ids: Dictionary = {}
	for asset in manifest.get("assets", []):
		var definition_id := str(asset.get("definitionId", ""))
		var face_path := "res://assets/ui/tiles/chinese-tiles/%s" % str(asset.get("file", ""))
		var texture := ForbiddenTheme.tile_texture(definition_id)
		assert_true(not seen_ids.has(definition_id), "manifest does not duplicate TileDefinition %s" % definition_id, failures)
		seen_ids[definition_id] = true
		assert_true(texture != null, "exact face texture resolves for %s" % definition_id, failures)
		if texture == null:
			continue
		var expected_size: Array = asset.get("size", [])
		assert_true(
			texture.get_size() == Vector2(expected_size[0], expected_size[1]),
			"source dimensions remain intact for %s" % definition_id,
			failures,
		)
		assert_true(_sha256(face_path) == str(asset.get("sha256", "")), "runtime copy remains byte-identical for %s" % definition_id, failures)
		assert_true(texture.resource_path == face_path, "definition maps to its exact Chinese face file for %s" % definition_id, failures)

	var west := ForbiddenTheme.tile_texture("base.tile.honors.west")
	var white_dragon := ForbiddenTheme.tile_texture("base.tile.honors.white")
	assert_true(west != null and west.resource_path.ends_with("z3.png"), "West wind uses its distinct 西 asset", failures)
	assert_true(white_dragon != null and white_dragon.resource_path.ends_with("z7.png"), "White dragon uses its framed 白板 asset", failures)
	assert_true(ForbiddenTheme.tile_texture("base.tile.honors.flower") == null, "unsupported identities do not borrow another tile face", failures)


func test_tile_identity_selection_and_focus(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		failures.append("tile focus test needs the SceneTree main loop")
		return
	var host := Control.new()
	host.name = "TileFoundationTestHost"
	tree.root.add_child(host)
	var first := TileFaceButton.new()
	var second := TileFaceButton.new()
	host.add_child(first)
	host.add_child(second)
	first.configure({
		"definition_id": "base.tile.characters.1",
		"instance_id": "stage45.face.copy.1",
		"copy_label": "Characters 1 · first copy",
		"annotations": ["Integrity 2"],
		"status_marker": "2",
	}, true)
	second.configure({
		"definition_id": "base.tile.characters.1",
		"instance_id": "stage45.face.copy.2",
		"copy_label": "Characters 1 · second copy",
	}, false)
	await tree.process_frame

	assert_true(first.tile_definition_id == second.tile_definition_id, "duplicate TileInstances retain the same exact face identity", failures)
	assert_true(first.tile_instance_id != second.tile_instance_id, "duplicate face controls preserve separate TileInstance IDs", failures)
	assert_true(first.get_meta("tile_instance_id") == "stage45.face.copy.1", "instance identity is explicit on the tile control", failures)
	assert_true(first.face_rect.texture == second.face_rect.texture and first.face_rect.texture != null, "duplicate instances render the same exact standard face", failures)
	assert_true(first.custom_minimum_size.x >= 44.0, "small tile hit target is at least 44 px wide", failures)
	assert_true(first.face_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "tile artwork uses contain scaling without cropping", failures)
	assert_true(first.selected and first.selected_outline.visible, "selection has its own brass state", failures)
	assert_true(first.tooltip_text.contains("first copy") and first.tooltip_text.contains("Integrity 2"), "copy and rule annotations remain available in inspection text", failures)
	assert_true(first.status_badge.visible and first.status_badge.text == "2", "tile status has a visible non-color mark", failures)
	assert_true(first.face_rect.get_rect().end.y <= first.status_badge.position.y + 1.0, "status marks sit below the unchanged contained Mahjong face", failures)
	assert_true(not second.status_badge.visible, "unannotated copies have no stale status badge", failures)

	first.set_selected(false)
	first.grab_focus()
	await tree.process_frame
	assert_true(first.has_focus() and first.focus_outline.visible, "keyboard focus remains visible when selection is off", failures)
	assert_true(not first.selected and not first.selected_outline.visible, "focus does not implicitly select a tile", failures)
	first.set_selected(true)
	assert_true(first.focus_outline.visible and first.selected_outline.visible, "selection and focus remain visible together", failures)
	first.release_focus()
	await tree.process_frame
	assert_true(first.selected_outline.visible and not first.focus_outline.visible, "moving focus away preserves independent selection", failures)
	host.queue_free()
	await tree.process_frame


func test_backdrop_readability_and_motion_preferences(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		failures.append("backdrop test needs the SceneTree main loop")
		return
	var backdrop := TableBackdrop.new()
	backdrop.name = "TableBackdropFoundationTest"
	tree.root.add_child(backdrop)
	await tree.process_frame
	assert_true(backdrop.background_rect.texture != null, "approved salon artwork is the backdrop source", failures)
	assert_true(backdrop.background_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "salon artwork is cosmetic and non-interactive", failures)
	assert_true(backdrop.scrim.mouse_filter == Control.MOUSE_FILTER_IGNORE, "readability scrim does not intercept input", failures)
	assert_true(backdrop.scrim.color.a >= 0.40, "backdrop applies a visible protective scrim", failures)
	assert_true(backdrop.glow_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "optional light effect does not intercept input", failures)

	backdrop.configure("NORMAL", false, true)
	assert_true(backdrop.is_ambient_glow_active(), "optional salon glow runs in Normal mode", failures)
	backdrop.set_motion_preferences("FAST", false)
	assert_true(backdrop.is_ambient_glow_active(), "ambient breathing remains gentle in Fast mode", failures)
	backdrop.set_motion_preferences("INSTANT", false)
	assert_true(not backdrop.is_ambient_glow_active() and not backdrop.glow_layer.visible, "Instant mode stops and hides ambient motion", failures)
	backdrop.configure("NORMAL", true, true)
	assert_true(not backdrop.is_ambient_glow_active(), "reduced motion keeps ambient glow off", failures)
	backdrop.queue_free()
	await tree.process_frame


func test_feedback_cancellation_and_immediate_modes(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		failures.append("motion test needs the SceneTree main loop")
		return
	var feedback := MotionFeedback.new()
	feedback.name = "MotionFeedbackFoundationTest"
	var target := Button.new()
	target.name = "MotionTarget"
	target.custom_minimum_size = Vector2(44.0, 44.0)
	tree.root.add_child(feedback)
	tree.root.add_child(target)
	await tree.process_frame

	feedback.configure("NORMAL", false)
	var final_position := Vector2(140.0, 64.0)
	target.position = final_position
	assert_true(feedback.play_property(target, NodePath("position"), Vector2(0.0, 0.0), final_position, 5.0), "Normal mode starts a cosmetic tween on a valid property", failures)
	assert_true(target.position == Vector2.ZERO, "cosmetic tween starts from its requested visual offset", failures)
	feedback.set_presentation_mode("FAST")
	assert_true(target.position == final_position, "changing from Normal to Fast cancels playback at its final state", failures)
	assert_true(not target.disabled and target.focus_mode == Control.FOCUS_ALL and target.is_visible_in_tree(), "motion never disables input, removes focus, or hides the target", failures)
	await tree.create_timer(0.08).timeout
	assert_true(target.position == final_position, "a canceled tween cannot later alter the next screen state", failures)

	feedback.play_property(target, NodePath("position"), Vector2.ZERO, final_position, 5.0)
	feedback.cancel()
	assert_true(target.position == final_position, "explicit cancellation restores the final layout immediately", failures)
	feedback.configure("INSTANT", false)
	var instant_position := Vector2(24.0, 48.0)
	assert_true(feedback.play_property(target, NodePath("position"), Vector2.ZERO, instant_position, 5.0), "Instant mode accepts feedback without a tween", failures)
	assert_true(target.position == instant_position, "Instant mode displays the final layout immediately", failures)
	feedback.configure("NORMAL", true)
	var reduced_position := Vector2(36.0, 72.0)
	feedback.play_property(target, NodePath("position"), Vector2.ZERO, reduced_position, 5.0)
	assert_true(target.position == reduced_position, "reduced motion also displays the final layout immediately", failures)
	feedback.queue_free()
	target.queue_free()
	await tree.process_frame


func _sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		file.close()
		return ""
	hashing.update(file.get_buffer(file.get_length()))
	file.close()
	return hashing.finish().hex_encode()


func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
