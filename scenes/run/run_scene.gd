extends Control
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const TutorialProgressScript = preload("res://src/presentation/run/tutorial_progress.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const RunSummaryPresenterScript = preload("res://src/presentation/run/run_summary_presenter.gd")
const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const ContentVersionMigrationScript = preload("res://src/infrastructure/persistence/content_version_migration.gd")
const JsonIntegerCodecScript = preload("res://src/infrastructure/serialization/json_integer_codec.gd")
const SuspendSaveStoreScript = preload("res://src/infrastructure/persistence/suspend_save_store.gd")

var controller
var meta_progress_coordinator
var content_registry_factory: Callable
var suspend_file_path := "user://alpha_suspend.json"
var suspend_store
var _content_registry
var _pending_resume_domain
var _suspend_rejected_copy_path := ""
var _startup_error := ""
var _meta_progress_load_warning := ""
var _phase_value: Label
var _run_value: Label
var _battle_value: Label
var _hand_value: Label
var _help_value: Label
var _tutorial_prompt: Label
var _tutorial_toggle_button: Button
var _tutorial_reset_button: Button
var _overview_scroll: ScrollContainer
var _feedback_value: Label
var _profile_status: Label
var _reset_profile_button: Button
var _new_run_button: Button
var _suspend_choice_panel: VBoxContainer
var _suspend_status: Label
var _resume_run_button: Button
var _new_run_from_suspend_button: Button
var _actions_column: VBoxContainer
var _action_details_value: Label
var _run_columns: HBoxContainer
var _summary_panel: PanelContainer
var _summary_value: Label
var _summary_acknowledge_button: Button

func _ready() -> void:
	_register_controller_input_mappings()
	if suspend_store == null:
		suspend_store = SuspendSaveStoreScript.new(suspend_file_path)
	if meta_progress_coordinator == null:
		meta_progress_coordinator = MetaProgressCoordinatorScript.new()
	var meta_load: Dictionary = meta_progress_coordinator.load_profile()
	if not meta_load.get("accepted", false):
		var recovery_path := str(meta_load.get("preserved_path", ""))
		var preservation_text := LocalizationCatalogScript.template("UI_RUN_SCENE_0001") % recovery_path if not recovery_path.is_empty() else LocalizationCatalogScript.text("UI_RUN_SCENE_0002")
		_meta_progress_load_warning = LocalizationCatalogScript.template("UI_RUN_SCENE_0003") % [str(meta_load.get("code", "LOAD_FAILED")), preservation_text]
	_build_interface()
	var registry_result := _validated_content_registry()
	if not registry_result.get("accepted", false):
		_startup_error = str(registry_result.get("message", LocalizationCatalogScript.text("UI_RUN_SCENE_0004")))
	else:
		_content_registry = registry_result.registry
		_load_suspend_or_start_new(_content_registry)
	_render()

func _input(event: InputEvent) -> void:
	var action := _mapped_ui_action(event)
	if action.is_empty():
		return
	match action:
		"ui_accept":
			_confirm_focused_control()
			_render()
		"ui_cancel":
			if controller != null:
				controller.back()
				_render()
		"ui_focus_next":
			_move_control_focus(1)
		"ui_focus_prev":
			_move_control_focus(-1)
		"ui_down", "ui_right":
			_move_directional_focus(1)
		"ui_up", "ui_left":
			_move_directional_focus(-1)
	get_viewport().set_input_as_handled()

func _mapped_ui_action(event: InputEvent) -> String:
	var actions := ["ui_accept", "ui_cancel", "ui_focus_next", "ui_focus_prev", "ui_down", "ui_up", "ui_left", "ui_right"]
	for action in actions:
		if event.is_action_pressed(action):
			return action
	if event is InputEventAction and event.pressed:
		return str(event.action) if actions.has(str(event.action)) else ""
	return ""

func _register_controller_input_mappings() -> void:
	var bindings := {
		"ui_accept": JOY_BUTTON_A,
		"ui_cancel": JOY_BUTTON_B,
		"ui_up": JOY_BUTTON_DPAD_UP,
		"ui_down": JOY_BUTTON_DPAD_DOWN,
		"ui_left": JOY_BUTTON_DPAD_LEFT,
		"ui_right": JOY_BUTTON_DPAD_RIGHT,
		"ui_focus_prev": JOY_BUTTON_LEFT_SHOULDER,
		"ui_focus_next": JOY_BUTTON_RIGHT_SHOULDER,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			continue
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = bindings[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)

func _move_directional_focus(direction: int) -> void:
	if _overview_scroll != null and get_viewport().gui_get_focus_owner() == _overview_scroll:
		_scroll_overview(direction)
		return
	if controller == null:
		_move_control_focus(direction)
		return
	var focused_button := get_viewport().gui_get_focus_owner() as Button
	if focused_button != null and focused_button.has_meta("run_action_id"):
		if direction > 0:
			controller.focus_next()
		else:
			controller.focus_previous()
		_render()
		return
	_move_control_focus(direction)

func _move_control_focus(direction: int) -> void:
	var focusable: Array[Control] = []
	for candidate in find_children("*", "Control", true, false):
		if not (candidate is Button or candidate == _overview_scroll):
			continue
		var control := candidate as Control
		if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
			continue
		if control is Button and control.disabled:
			continue
		focusable.append(control)
	if focusable.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner() as Control
	var index := focusable.find(current)
	if index < 0:
		index = 0 if direction > 0 else focusable.size() - 1
	else:
		index = (index + direction + focusable.size()) % focusable.size()
	focusable[index].grab_focus()

func _scroll_overview(direction: int) -> void:
	if _overview_scroll == null:
		return
	var scrollbar := _overview_scroll.get_v_scroll_bar()
	var maximum := maxi(0, int(scrollbar.max_value - scrollbar.page))
	var step := maxi(72, int(scrollbar.page * 0.75))
	_overview_scroll.scroll_vertical = clampi(_overview_scroll.scroll_vertical + direction * step, 0, maximum)

func _confirm_focused_control() -> void:
	var focused_button := get_viewport().gui_get_focus_owner() as Button
	if focused_button == null or not focused_button.is_visible_in_tree() or focused_button.disabled:
		return
	if controller != null and focused_button.has_meta("run_action_id"):
		controller.confirm(str(focused_button.get_meta("run_action_id")))
		return
	focused_button.emit_signal("pressed")

func _validated_content_registry() -> Dictionary:
	var registry = ContentRegistryScript.new()
	if content_registry_factory.is_valid():
		registry = content_registry_factory.call()
	if not registry is ContentRegistryScript:
		return {"accepted": false, "message": LocalizationCatalogScript.text("UI_RUN_SCENE_0005")}
	var registration_reports: Array = [
		{"catalog": LocalizationCatalogScript.text("UI_RUN_SCENE_0006"), "report": Phase2CatalogScript.register_all(registry)},
		{"catalog": LocalizationCatalogScript.text("UI_RUN_SCENE_0007"), "report": AlphaActTwoCatalogScript.register_all(registry)},
		{"catalog": LocalizationCatalogScript.text("UI_RUN_SCENE_0008"), "report": AlphaScaleCatalogScript.register_all(registry)},
	]
	var validation_errors: Array[String] = []
	for registration in registration_reports:
		_append_content_validation_errors(
			validation_errors,
			LocalizationCatalogScript.template("UI_RUN_SCENE_0009") % str(registration.get("catalog", "Catalog")),
			registration.get("report"),
		)
	_append_content_validation_errors(validation_errors, LocalizationCatalogScript.text("UI_RUN_SCENE_0010"), registry.validate())
	if not validation_errors.is_empty():
		return {"accepted": false, "message": LocalizationCatalogScript.template("UI_RUN_SCENE_0011") % "\n".join(validation_errors)}
	return {"accepted": true, "registry": registry}

func _load_suspend_or_start_new(registry) -> void:
	var stored: Dictionary = suspend_store.read_source()
	if not stored.get("accepted", false):
		if stored.get("preserve_required", false):
			var interrupted_preservation: Dictionary = suspend_store.preserve_source()
			if interrupted_preservation.get("accepted", false):
				_suspend_rejected_copy_path = str(interrupted_preservation.get("path", ""))
				_show_suspend_recovery_required(
					LocalizationCatalogScript.template("UI_RUN_SCENE_0012") % [str(stored.get("code", "SUSPEND_COMMIT_INTERRUPTED")), _suspend_rejected_copy_path],
					true,
				)
			else:
				_show_suspend_recovery_required(
					LocalizationCatalogScript.template("UI_RUN_SCENE_0013") % [str(stored.get("code", "SUSPEND_COMMIT_INTERRUPTED")), str(interrupted_preservation.get("code", "SUSPEND_PRESERVE_FAILED"))],
					false,
				)
			return
		_show_suspend_recovery_required(
			LocalizationCatalogScript.template("UI_RUN_SCENE_0014") % str(stored.get("code", "SUSPEND_READ_FAILED")),
			false,
		)
		return
	if not stored.get("exists", false):
		_start_new_run(registry)
		return
	var loaded: Dictionary = _load_suspend_contents(str(stored.get("contents", "")), registry)
	if not loaded.get("accepted", false):
		var preservation: Dictionary = suspend_store.preserve_source()
		if preservation.get("accepted", false):
			_suspend_rejected_copy_path = str(preservation.get("path", ""))
			var explanation := _suspend_load_error(loaded)
			_show_suspend_recovery_required(
				LocalizationCatalogScript.template("UI_RUN_SCENE_0015") % [explanation, _suspend_rejected_copy_path],
				true,
			)
		else:
			_show_suspend_recovery_required(
				LocalizationCatalogScript.template("UI_RUN_SCENE_0016") % [_suspend_load_error(loaded), str(preservation.get("code", "SUSPEND_PRESERVE_FAILED"))],
				false,
			)
		return
	var saved_domain = loaded.domain
	var finalized: Dictionary = suspend_store.finalize_load(stored, str(saved_domain.state.run_id))
	if not finalized.get("accepted", false):
		var preservation: Dictionary = suspend_store.preserve_source()
		var recovery_path := str(preservation.get("path", "")) if preservation.get("accepted", false) else ""
		var suffix := LocalizationCatalogScript.template("UI_RUN_SCENE_0017") % recovery_path if not recovery_path.is_empty() else LocalizationCatalogScript.text("UI_RUN_SCENE_0018")
		_show_suspend_recovery_required(
			LocalizationCatalogScript.template("UI_RUN_SCENE_0019") % [str(finalized.get("code", "SUSPEND_RECOVERY_FAILED")), suffix],
			preservation.get("accepted", false),
		)
		if preservation.get("accepted", false):
			_suspend_rejected_copy_path = recovery_path
		return
	if str(saved_domain.state.phase) == RunPhaseScript.RUN_COMPLETE:
		var unlock_retry: Dictionary = meta_progress_coordinator.observe_run_state(saved_domain.state)
		var progression_pending: bool = unlock_retry.has("persisted") and not bool(unlock_retry.get("persisted", false))
		var cleared: Dictionary = suspend_store.clear() if not progression_pending else {"accepted": false, "code": str(unlock_retry.get("code", "META_PROGRESS_SAVE_FAILED"))}
		if cleared.get("accepted", false):
			_start_new_run(registry)
		else:
			_pending_resume_domain = saved_domain
			var prefix := LocalizationCatalogScript.template("UI_RUN_SCENE_0020") % str(cleared.get("code", "META_PROGRESS_SAVE_FAILED")) if progression_pending else LocalizationCatalogScript.template("UI_RUN_SCENE_0021") % str(cleared.get("code", "SUSPEND_CLEAR_FAILED"))
			_show_valid_suspend_choice(saved_domain, prefix, not progression_pending, str(loaded.snapshot.checkpoint_metadata.get("stable_boundary", "")))
		return
	_pending_resume_domain = saved_domain
	var cleanup_prefix := ""
	if finalized.has("cleanup_warning"):
		cleanup_prefix = LocalizationCatalogScript.template("UI_RUN_SCENE_0022") % str(finalized.get("cleanup_warning"))
	_show_valid_suspend_choice(saved_domain, cleanup_prefix, true, str(loaded.snapshot.checkpoint_metadata.get("stable_boundary", "")))

func _load_suspend_contents(contents: String, registry) -> Dictionary:
	# Current content identities always use the exact-version generic loader.
	var loaded: Dictionary = SaveMapperScript.load_into_domain(contents, registry)
	if loaded.get("accepted", false) or not _has_load_validation_error(loaded, "UNSUPPORTED_CONTENT_VERSION"):
		return loaded
	var parsed: Dictionary = JsonIntegerCodecScript.parse(contents)
	if not parsed.get("accepted", false) or not parsed.get("data") is Dictionary:
		return loaded
	var source_version := str(parsed.data.get("content_version", ""))
	match source_version:
		ContentVersionMigrationScript.PHASE2_V1:
			return SaveMapperScript.load_phase2_v1_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.PHASE2_V2, ContentVersionMigrationScript.ACT_TWO_V2, ContentVersionMigrationScript.ACT_TWO_SCALE_V2:
			return SaveMapperScript.load_phase2_v2_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_SCALE_V4:
			return SaveMapperScript.load_full_v4_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_SCALE_V5:
			return SaveMapperScript.load_full_v5_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_SCALE_V6:
			return SaveMapperScript.load_full_v6_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_SCALE_V7:
			return SaveMapperScript.load_full_v7_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_SCALE_V8:
			return SaveMapperScript.load_full_v8_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_SCALE_V9:
			return SaveMapperScript.load_full_v9_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_SCALE_V10:
			return SaveMapperScript.load_full_v10_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_SCALE_V11:
			return SaveMapperScript.load_full_v11_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_SCALE_V12:
			return SaveMapperScript.load_full_v12_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_BUNDLE_V4:
			return SaveMapperScript.load_act_two_v4_suspend_snapshot_into_domain(contents, registry)
		ContentVersionMigrationScript.ACT_TWO_SCALE_V3:
			return SaveMapperScript.load_full_v3_suspend_snapshot_into_domain(contents, registry)
		_:
			return loaded

func _has_load_validation_error(loaded: Dictionary, code: String) -> bool:
	for issue in loaded.get("errors", []):
		if issue is Dictionary and str(issue.get("code", "")) == code:
			return true
	return false

func _suspend_load_error(loaded: Dictionary) -> String:
	for issue in loaded.get("errors", []):
		var code := str(issue.get("code", "")) if issue is Dictionary else ""
		if code == "UNSUPPORTED_CONTENT_VERSION":
			return LocalizationCatalogScript.text("UI_RUN_SCENE_0023")
		if code == "UNSUPPORTED_GAME_VERSION":
			return LocalizationCatalogScript.text("UI_RUN_SCENE_0024")
	return LocalizationCatalogScript.template("UI_RUN_SCENE_0025") % str(loaded.get("code", "SUSPEND_LOAD_FAILED"))

func _show_valid_suspend_choice(saved_domain, prefix: String = "", can_start_new: bool = true, saved_boundary: String = "") -> void:
	var checkpoint: Dictionary = saved_domain.checkpoint()
	var message := LocalizationCatalogScript.template("UI_RUN_SCENE_0026") % str(saved_domain.state.run_id)
	var boundary := saved_boundary if not saved_boundary.is_empty() else str(checkpoint.get("stable_boundary", ""))
	if not boundary.is_empty():
		message += LocalizationCatalogScript.template("UI_RUN_SCENE_0027") % _pretty_words(boundary)
	if not prefix.is_empty():
		message = "%s\n%s" % [prefix, message]
	_show_suspend_choice(message, true, LocalizationCatalogScript.text("UI_RUN_SCENE_0028"), can_start_new)

func _show_suspend_recovery_required(message: String, can_start_new: bool) -> void:
	_show_suspend_choice(message, false, LocalizationCatalogScript.text("UI_RUN_SCENE_0029"), can_start_new)

func _show_suspend_choice(message: String, can_resume: bool, new_run_label: String, can_start_new: bool) -> void:
	_suspend_choice_panel.visible = true
	_set_wrapped_label_text(_suspend_status, message)
	_resume_run_button.visible = can_resume
	_resume_run_button.disabled = not can_resume
	_new_run_from_suspend_button.text = new_run_label
	_new_run_from_suspend_button.visible = true
	_new_run_from_suspend_button.disabled = not can_start_new
	_run_columns.visible = false
	_summary_panel.visible = false
	_new_run_button.disabled = true
	var initial_choice: Button = _resume_run_button if _resume_run_button.visible and not _resume_run_button.disabled else _new_run_from_suspend_button
	if initial_choice.visible and not initial_choice.disabled and initial_choice.is_inside_tree():
		initial_choice.grab_focus()

func _start_new_run(registry) -> void:
	var seed := int(Time.get_ticks_usec() % 2147483647)
	var run_id := "alpha.%d.%d" % [Time.get_unix_time_from_system(), seed]
	_attach_controller(RunDomainScript.new_alpha_run(run_id, seed, registry, "", null, null, meta_progress_coordinator.state))

func _attach_controller(run_domain) -> void:
	controller = RunPresentationControllerScript.new(run_domain, null, meta_progress_coordinator, suspend_store)
	controller.presentation_changed.connect(_render)

func _on_resume_run_pressed() -> void:
	if _pending_resume_domain == null:
		return
	var resumed_domain = _pending_resume_domain
	_pending_resume_domain = null
	if str(resumed_domain.state.phase) == RunPhaseScript.RUN_COMPLETE:
		var unlock_retry: Dictionary = meta_progress_coordinator.observe_run_state(resumed_domain.state)
		if unlock_retry.has("persisted") and not unlock_retry.get("persisted", false):
			_set_wrapped_label_text(_suspend_status, LocalizationCatalogScript.template("UI_RUN_SCENE_0030") % str(unlock_retry.get("code", "META_PROGRESS_SAVE_FAILED")))
			_pending_resume_domain = resumed_domain
			return
		var clear_result: Dictionary = suspend_store.clear()
		if not clear_result.get("accepted", false):
			_set_wrapped_label_text(_suspend_status, LocalizationCatalogScript.template("UI_RUN_SCENE_0031") % str(clear_result.get("code", "SUSPEND_CLEAR_FAILED")))
			_pending_resume_domain = resumed_domain
			return
	_suspend_choice_panel.visible = false
	_attach_controller(resumed_domain)
	_render()

func _on_new_run_from_suspend_pressed() -> void:
	if _new_run_from_suspend_button.disabled:
		return
	if _pending_resume_domain == null and _suspend_rejected_copy_path.is_empty():
		return
	var cleared: Dictionary = suspend_store.clear()
	if not cleared.get("accepted", false):
		_suspend_status.text += LocalizationCatalogScript.template("UI_RUN_SCENE_0032") % str(cleared.get("code", "SUSPEND_CLEAR_FAILED"))
		return
	_pending_resume_domain = null
	_suspend_rejected_copy_path = ""
	_suspend_choice_panel.visible = false
	_start_new_run(_content_registry)
	_render()

func _append_content_validation_errors(errors: Array[String], source: String, report) -> void:
	if report == null or not report.has_method("is_valid") or not report.has_method("get"):
		errors.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0033") % source)
		return
	if report.is_valid():
		return
	var issues: Variant = report.get("issues")
	if not issues is Array or issues.is_empty():
		errors.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0034") % source)
		return
	for issue in issues:
		if issue == null or not issue.has_method("get"):
			errors.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0035") % source)
			continue
		var code := str(issue.get("code"))
		var content_id := str(issue.get("content_id"))
		var reference_id := str(issue.get("reference_id"))
		var message := str(issue.get("message"))
		var location := content_id
		if not reference_id.is_empty():
			location += LocalizationCatalogScript.template("UI_RUN_SCENE_0036") % reference_id
		errors.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0037") % [source, code, location, message])

func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	page.add_child(header)
	var title := Label.new()
	title.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0038")
	title.add_theme_font_size_override("font_size", 23)
	_configure_wrapped_label(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var tutorial_controls := HBoxContainer.new()
	tutorial_controls.name = "TutorialControls"
	tutorial_controls.add_theme_constant_override("separation", 8)
	_tutorial_toggle_button = Button.new()
	_tutorial_toggle_button.name = "TutorialToggleButton"
	_tutorial_toggle_button.pressed.connect(_on_tutorial_toggle_pressed)
	tutorial_controls.add_child(_tutorial_toggle_button)
	_tutorial_reset_button = Button.new()
	_tutorial_reset_button.name = "TutorialResetButton"
	_tutorial_reset_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0039")
	_tutorial_reset_button.pressed.connect(_on_tutorial_reset_pressed)
	tutorial_controls.add_child(_tutorial_reset_button)
	header.add_child(tutorial_controls)
	_new_run_button = Button.new()
	_new_run_button.name = "NewRunButton"
	_new_run_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0040")
	_new_run_button.disabled = true
	_new_run_button.pressed.connect(_on_new_run_pressed)
	header.add_child(_new_run_button)

	_phase_value = Label.new()
	_phase_value.name = "RunPhaseLabel"
	_phase_value.add_theme_font_size_override("font_size", 17)
	page.add_child(_phase_value)
	_profile_status = Label.new()
	_configure_wrapped_label(_profile_status)
	_profile_status.text = _meta_progress_load_warning
	_profile_status.visible = not _meta_progress_load_warning.is_empty()
	page.add_child(_profile_status)
	_reset_profile_button = Button.new()
	_reset_profile_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0041")
	_reset_profile_button.tooltip_text = LocalizationCatalogScript.text("UI_RUN_SCENE_0042")
	_reset_profile_button.visible = meta_progress_coordinator.recovery_required
	_reset_profile_button.pressed.connect(_on_reset_profile_pressed)
	page.add_child(_reset_profile_button)
	_suspend_choice_panel = VBoxContainer.new()
	_suspend_choice_panel.name = "SuspendChoicePanel"
	_suspend_choice_panel.visible = false
	_suspend_choice_panel.add_theme_constant_override("separation", 8)
	page.add_child(_suspend_choice_panel)
	_suspend_status = Label.new()
	_suspend_status.name = "SuspendStatus"
	_configure_wrapped_label(_suspend_status)
	_suspend_choice_panel.add_child(_suspend_status)
	_resume_run_button = Button.new()
	_resume_run_button.name = "ResumeRunButton"
	_resume_run_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0043")
	_resume_run_button.pressed.connect(_on_resume_run_pressed)
	_suspend_choice_panel.add_child(_resume_run_button)
	_new_run_from_suspend_button = Button.new()
	_new_run_from_suspend_button.name = "NewRunFromSuspendButton"
	_new_run_from_suspend_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0044")
	_new_run_from_suspend_button.pressed.connect(_on_new_run_from_suspend_pressed)
	_suspend_choice_panel.add_child(_new_run_from_suspend_button)

	var columns := HBoxContainer.new()
	_run_columns = columns
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var overview_panel := PanelContainer.new()
	overview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview_panel.size_flags_stretch_ratio = 1.0
	columns.add_child(overview_panel)
	var overview_layout := VBoxContainer.new()
	overview_layout.add_theme_constant_override("separation", 8)
	overview_panel.add_child(overview_layout)
	var overview_header := HBoxContainer.new()
	overview_header.add_theme_constant_override("separation", 6)
	overview_layout.add_child(overview_header)
	var overview_heading := Label.new()
	overview_heading.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0045")
	overview_heading.add_theme_font_size_override("font_size", 16)
	overview_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_header.add_child(overview_heading)
	var overview_scroll_up_button := Button.new()
	overview_scroll_up_button.name = "OverviewScrollUpButton"
	overview_scroll_up_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0046")
	overview_scroll_up_button.tooltip_text = LocalizationCatalogScript.text("UI_RUN_SCENE_0047")
	overview_scroll_up_button.pressed.connect(_scroll_overview.bind(-1))
	overview_header.add_child(overview_scroll_up_button)
	var overview_scroll_down_button := Button.new()
	overview_scroll_down_button.name = "OverviewScrollDownButton"
	overview_scroll_down_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0048")
	overview_scroll_down_button.tooltip_text = LocalizationCatalogScript.text("UI_RUN_SCENE_0049")
	overview_scroll_down_button.pressed.connect(_scroll_overview.bind(1))
	overview_header.add_child(overview_scroll_down_button)
	_overview_scroll = ScrollContainer.new()
	_overview_scroll.name = "RunOverviewScroll"
	_overview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_overview_scroll.follow_focus = true
	_overview_scroll.focus_mode = Control.FOCUS_ALL
	_overview_scroll.tooltip_text = LocalizationCatalogScript.text("UI_RUN_SCENE_0050")
	overview_layout.add_child(_overview_scroll)
	var overview := VBoxContainer.new()
	overview.add_theme_constant_override("separation", 12)
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_scroll.add_child(overview)
	_run_value = _add_wrapped_label(overview)
	_add_section_heading(overview, LocalizationCatalogScript.text("UI_RUN_SCENE_0149"))
	_battle_value = _add_wrapped_label(overview)
	_add_section_heading(overview, LocalizationCatalogScript.text("UI_RUN_SCENE_0051"))
	_hand_value = _add_wrapped_label(overview)
	_help_value = _add_wrapped_label(overview)
	_help_value.name = "RunHelpPrompt"
	_help_value.modulate = Color(0.78, 0.82, 0.9)
	_help_value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tutorial_prompt = _add_wrapped_label(overview)
	_tutorial_prompt.name = "TutorialPrompt"
	_tutorial_prompt.modulate = Color(0.95, 0.86, 0.62)
	_tutorial_prompt.visible = false

	var actions_panel := PanelContainer.new()
	actions_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions_panel.size_flags_stretch_ratio = 1.0
	columns.add_child(actions_panel)
	var action_layout := VBoxContainer.new()
	action_layout.add_theme_constant_override("separation", 8)
	actions_panel.add_child(action_layout)
	_add_section_heading(action_layout, LocalizationCatalogScript.text("UI_RUN_SCENE_0052"))
	var scroll := ScrollContainer.new()
	scroll.name = "AvailableActionsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_action_details_value = Label.new()
	_action_details_value.name = "SelectedActionDetails"
	_configure_wrapped_label(_action_details_value)
	_action_details_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_details_value.visible = false
	action_layout.add_child(_action_details_value)
	action_layout.add_child(scroll)
	_actions_column = VBoxContainer.new()
	_actions_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_column.add_theme_constant_override("separation", 7)
	scroll.add_child(_actions_column)

	_summary_panel = PanelContainer.new()
	_summary_panel.name = "RunSummaryPanel"
	_summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_panel.visible = false
	page.add_child(_summary_panel)
	var summary_layout := VBoxContainer.new()
	summary_layout.add_theme_constant_override("separation", 10)
	_summary_panel.add_child(summary_layout)
	var summary_scroll := ScrollContainer.new()
	summary_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_layout.add_child(summary_scroll)
	_summary_value = Label.new()
	_summary_value.name = "RunSummaryText"
	_configure_wrapped_label(_summary_value)
	_summary_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_scroll.add_child(_summary_value)
	_summary_acknowledge_button = Button.new()
	_summary_acknowledge_button.name = "FinishRunButton"
	_summary_acknowledge_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0053")
	_summary_acknowledge_button.pressed.connect(_on_action_pressed.bind("run.summary.acknowledge"))
	summary_layout.add_child(_summary_acknowledge_button)

	_feedback_value = Label.new()
	_configure_wrapped_label(_feedback_value)
	page.add_child(_feedback_value)

func _render() -> void:
	if controller == null:
		if _phase_value != null:
			_phase_value.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0054")
		if _profile_status != null:
			_set_wrapped_label_text(_profile_status, _meta_progress_load_warning)
			_profile_status.visible = not _meta_progress_load_warning.is_empty()
		if _reset_profile_button != null:
			_reset_profile_button.visible = meta_progress_coordinator.recovery_required
		if _run_columns != null:
			_run_columns.visible = false
		if _tutorial_prompt != null:
			_tutorial_prompt.visible = false
		if _tutorial_toggle_button != null:
			_tutorial_toggle_button.disabled = true
		if _tutorial_reset_button != null:
			_tutorial_reset_button.disabled = true
		if _summary_panel != null:
			_summary_panel.visible = false
		if _new_run_button != null:
			_new_run_button.disabled = true
		if _feedback_value != null:
			_set_wrapped_label_text(_feedback_value, _startup_error)
		return
	_suspend_choice_panel.visible = false
	var state = controller.domain.state
	var phase := str(state.phase)
	_phase_value.text = LocalizationCatalogScript.template("UI_RUN_SCENE_0055") % [state.act_index, state.act_count, _pretty_words(phase)]
	_set_wrapped_label_text(_run_value, LocalizationCatalogScript.template("UI_RUN_SCENE_0056") % [
		state.run_id,
		_pretty_id(state.character_id),
		_pretty_id(state.contract_id),
		state.gold,
		state.refinement_tokens,
		_pretty_id(state.map_state.current_node_id),
	])
	_set_wrapped_label_text(_battle_value, _battle_summary())
	_set_wrapped_label_text(_hand_value, _hand_summary())
	_set_wrapped_label_text(_help_value, _help_text(phase))
	_render_tutorial(phase)
	_set_wrapped_label_text(_feedback_value, str(controller.snapshot().get("feedback", "")))
	_set_wrapped_label_text(_profile_status, _meta_progress_load_warning)
	_profile_status.visible = not _meta_progress_load_warning.is_empty()
	_reset_profile_button.visible = meta_progress_coordinator.recovery_required
	var showing_summary := phase in [RunPhaseScript.RUN_SUMMARY, RunPhaseScript.RUN_COMPLETE]
	_run_columns.visible = not showing_summary
	_summary_panel.visible = showing_summary
	_set_wrapped_label_text(_summary_value, RunSummaryPresenterScript.format(state))
	_summary_acknowledge_button.visible = phase == RunPhaseScript.RUN_SUMMARY
	_new_run_button.disabled = phase != RunPhaseScript.RUN_COMPLETE
	_render_actions()
	if phase == RunPhaseScript.RUN_SUMMARY and _summary_acknowledge_button.visible and not _summary_acknowledge_button.disabled:
		_summary_acknowledge_button.grab_focus()
	elif phase == RunPhaseScript.RUN_COMPLETE and not _new_run_button.disabled and _new_run_button.is_inside_tree():
		_new_run_button.grab_focus()

func _render_actions() -> void:
	for child in _actions_column.get_children():
		_actions_column.remove_child(child)
		child.queue_free()
	var descriptors: Array = controller.action_descriptors()
	if descriptors.is_empty():
		_set_wrapped_label_text(_action_details_value, "")
		_action_details_value.visible = false
		var empty_label := Label.new()
		empty_label.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0057")
		_configure_wrapped_label(empty_label)
		_actions_column.add_child(empty_label)
		return
	var focused_id := str(controller.snapshot().get("focused_action_id", ""))
	var focused_button: Button
	var focused_action: Dictionary = {}
	for action in descriptors:
		var action_id := str(action.get("id", ""))
		var button := Button.new()
		button.text = _compact_action_label(action)
		button.set_meta("run_action_id", action_id)
		button.tooltip_text = _action_tooltip(action)
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_action_pressed.bind(action_id))
		button.focus_entered.connect(_on_action_focus_entered.bind(action_id))
		_actions_column.add_child(button)
		if focused_button == null or action_id == focused_id:
			focused_button = button
			focused_action = action
	_set_wrapped_label_text(_action_details_value, _action_details_text(focused_action))
	_action_details_value.visible = not _action_details_value.text.is_empty() and focused_button != null and _action_details_value.text != focused_button.text
	if focused_button != null and focused_button.is_inside_tree() and not _reset_profile_button.has_focus():
		focused_button.grab_focus()

func _on_action_focus_entered(action_id: String) -> void:
	if controller == null or _action_details_value == null:
		return
	for action in controller.action_descriptors():
		if str(action.get("id", "")) == action_id:
			_set_wrapped_label_text(_action_details_value, _action_details_text(action))
			var focused_button := get_viewport().gui_get_focus_owner() as Button
			_action_details_value.visible = not _action_details_value.text.is_empty() and focused_button != null and _action_details_value.text != focused_button.text
			return

func _on_action_pressed(action_id: String):
	var result = controller.confirm(action_id)
	_render()
	return result

func _on_tutorial_toggle_pressed() -> void:
	if controller == null:
		return
	if controller.tutorial_progress.enabled:
		controller.tutorial_progress.disable()
	else:
		controller.tutorial_progress.enable()
	_render()

func _on_tutorial_reset_pressed() -> void:
	if controller == null:
		return
	controller.tutorial_progress.reset()
	_render()

func _render_tutorial(phase: String) -> void:
	var progress = controller.tutorial_progress
	var active_step := str(progress.current_step_id)
	var complete: bool = progress.is_complete()
	_tutorial_toggle_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0058") if complete else (LocalizationCatalogScript.text("UI_RUN_SCENE_0059") if progress.enabled else LocalizationCatalogScript.text("UI_RUN_SCENE_0060"))
	_tutorial_toggle_button.disabled = complete
	_tutorial_reset_button.disabled = progress.enabled and progress.completed_step_ids.is_empty()
	_set_wrapped_label_text(_tutorial_prompt, _tutorial_prompt_for_step(active_step))
	_tutorial_prompt.visible = phase == RunPhaseScript.BATTLE and progress.enabled and not active_step.is_empty()

func _tutorial_prompt_for_step(step_id: String) -> String:
	match step_id:
		TutorialProgressScript.DRAW_PATTERN_PARTIAL:
			return LocalizationCatalogScript.text("UI_RUN_SCENE_0061")
		TutorialProgressScript.TP_CORE_TECHNIQUE:
			return LocalizationCatalogScript.text("UI_RUN_SCENE_0062")
		TutorialProgressScript.RESERVE_INTEGRITY:
			return LocalizationCatalogScript.text("UI_RUN_SCENE_0063")
		TutorialProgressScript.YAKU_COMPLETE_HAND:
			return LocalizationCatalogScript.text("UI_RUN_SCENE_0064")
		TutorialProgressScript.CONTAMINATION_INTENT:
			return LocalizationCatalogScript.text("UI_RUN_SCENE_0065")
	return ""

func _on_new_run_pressed() -> void:
	if controller == null or str(controller.domain.state.phase) != RunPhaseScript.RUN_COMPLETE:
		return
	var registry_result := _validated_content_registry()
	if not registry_result.get("accepted", false):
		_startup_error = str(registry_result.get("message", LocalizationCatalogScript.text("UI_RUN_SCENE_0066")))
		_render()
		return
	if controller != null and str(controller.domain.state.phase) == RunPhaseScript.RUN_COMPLETE:
		var unlock_retry: Dictionary = meta_progress_coordinator.observe_run_state(controller.domain.state)
		if unlock_retry.has("persisted") and not unlock_retry.get("persisted", false):
			controller.state.feedback = LocalizationCatalogScript.template("UI_RUN_SCENE_0067") % str(unlock_retry.get("code", "META_PROGRESS_SAVE_FAILED"))
			_render()
			return
	var cleared: Dictionary = suspend_store.clear()
	if not cleared.get("accepted", false):
		controller.state.feedback = LocalizationCatalogScript.template("UI_RUN_SCENE_0068") % str(cleared.get("code", "SUSPEND_CLEAR_FAILED"))
		_render()
		return
	if controller != null and controller.presentation_changed.is_connected(_render):
		controller.presentation_changed.disconnect(_render)
	controller = null
	_content_registry = registry_result.registry
	_start_new_run(_content_registry)
	_render()

func _on_reset_profile_pressed() -> void:
	var result: Dictionary = meta_progress_coordinator.reset_profile()
	if result.get("accepted", false):
		_meta_progress_load_warning = LocalizationCatalogScript.template("UI_RUN_SCENE_0069") % str(result.get("preserved_path", LocalizationCatalogScript.text("UI_RUN_SCENE_0070")))
	else:
		_meta_progress_load_warning = LocalizationCatalogScript.template("UI_RUN_SCENE_0071") % str(result.get("code", "RESET_FAILED"))
	_render()

func _battle_summary() -> String:
	var battle = controller.domain.current_battle
	if battle == null:
		var summary = controller.domain.state.terminal_summary
		if controller.domain.state.phase in [RunPhaseScript.RUN_SUMMARY, RunPhaseScript.RUN_COMPLETE]:
			return LocalizationCatalogScript.template("UI_RUN_SCENE_0072") % [
				LocalizationCatalogScript.word_text(str(summary.outcome)),
				LocalizationCatalogScript.word_text(str(summary.reason)),
			]
		return LocalizationCatalogScript.text("UI_RUN_SCENE_0073")
	var battle_state: Dictionary = battle.public_state()
	var intent = battle.combat_state.current_intent
	var intent_text := LocalizationCatalogScript.text("WORD_NONE")
	if intent != null:
		intent_text = LocalizationCatalogScript.template("UI_RUN_SCENE_0074") % [intent.display_name, intent.pressure_amount]
	var outcome := str(battle_state.get("terminal_outcome", "ONGOING"))
	var pattern_count: int = battle.settlement_window.candidates().size() if battle.settlement_window != null else 0
	return LocalizationCatalogScript.template("UI_RUN_SCENE_0075") % [
		_pretty_words(str(battle_state.get("encounter_kind", "Battle"))),
		int(battle_state.get("enemy_hp", 0)),
		int(battle_state.get("enemy_max_hp", 0)),
		intent_text,
		int(battle_state.get("pressure", 0)),
		int(battle_state.get("pressure_limit", 0)),
		int(battle_state.get("tp", 0)),
		int(battle_state.get("stability", 0)),
		pattern_count,
		_pretty_words(outcome),
	]

func _hand_summary() -> String:
	var battle = controller.domain.current_battle
	if battle == null:
		var run_tiles: Array = []
		for tile in controller.domain.state.tile_pool.tile_instances:
			run_tiles.append(_pretty_tile_id(tile.definition_id))
		return LocalizationCatalogScript.template("UI_RUN_SCENE_0076") % [run_tiles.size(), _join_strings(run_tiles)]
	var hand: Array = []
	var reserve: Array = []
	for tile in battle.zones.contents(TileZoneScript.HAND):
		hand.append(_pretty_tile_id(tile.definition_id))
	for tile in battle.zones.contents(TileZoneScript.RESERVE):
		reserve.append(_pretty_tile_id(tile.definition_id))
	return LocalizationCatalogScript.template("UI_RUN_SCENE_0077") % [
		hand.size(), _join_strings(hand) if not hand.is_empty() else LocalizationCatalogScript.text("WORD_EMPTY"),
		reserve.size(), _join_strings(reserve) if not reserve.is_empty() else LocalizationCatalogScript.text("WORD_EMPTY"),
	]

func _action_label(action: Dictionary) -> String:
	var kind := str(action.get("kind", "ACTION"))
	var target := str(action.get("target_id", ""))
	var details: Dictionary = action.get("details", {}) if action.get("details", {}) is Dictionary else {}
	match kind:
		"CHARACTER": return LocalizationCatalogScript.template("UI_RUN_SCENE_0078") % _pretty_id(target)
		"CONTRACT": return _contract_action_label(details, target)
		"MAP_NODE": return LocalizationCatalogScript.template("UI_RUN_SCENE_0079") % [_pretty_words(str(action.get("node_kind", "Map"))), _pretty_id(target)]
		"DRAW": return LocalizationCatalogScript.text("UI_RUN_SCENE_0080")
		"END_TURN": return LocalizationCatalogScript.text("UI_RUN_SCENE_0081")
		"TECHNIQUE":
			var technique_kind := str(details.get("technique_kind", "Technique"))
			var cost := int(details.get("tp_cost", 0))
			var target_label := _pretty_tile_id(str(details.get("effect_target_id", "")))
			var suffix := LocalizationCatalogScript.template("UI_RUN_SCENE_0082") % target_label if not target_label.is_empty() else ""
			var timing_label := LocalizationCatalogScript.text("UI_RUN_SCENE_0083") if technique_kind == "REACTION" else _pretty_words(technique_kind)
			return LocalizationCatalogScript.template("UI_RUN_SCENE_0084") % [timing_label, _pretty_id(target), suffix, cost]
		"PARTIAL_SETTLEMENT": return LocalizationCatalogScript.template("UI_RUN_SCENE_0085") % [
			_pretty_words(str(details.get("pattern_type", "pattern"))),
			_join_strings(details.get("labels", [])),
		]
		"COMPLETE_HAND": return LocalizationCatalogScript.template("UI_RUN_SCENE_0086") % _pretty_words(str(details.get("hand_type", "hand")))
		"RESERVE": return LocalizationCatalogScript.template("UI_RUN_SCENE_0087") % _pretty_tile_id(str(details.get("tile_id", target)))
		"DISCARD": return LocalizationCatalogScript.template("UI_RUN_SCENE_0088") % _pretty_tile_id(str(details.get("tile_id", target)))
		"RESERVE_SWAP": return LocalizationCatalogScript.template("UI_RUN_SCENE_0089") % [
			_pretty_tile_id(str(details.get("hand_tile_id", ""))),
			_pretty_tile_id(str(details.get("reserve_tile_id", ""))),
		]
		"REWARD", "ELITE_REWARD", "BOSS_REWARD":
			var content_id := str(action.get("content_id", details.get("content_id", target)))
			return LocalizationCatalogScript.template("UI_RUN_SCENE_0090") % _pretty_id(content_id)
		"ENTER_SHOP": return LocalizationCatalogScript.text("UI_RUN_SCENE_0091")
		"SHOP_OFFER":
			var content_id := str(details.get("content_id", details.get("offer_id", target)))
			var price := int(details.get("cost", details.get("price", 0)))
			return LocalizationCatalogScript.template("UI_RUN_SCENE_0092") % [_pretty_id(content_id), price]
		"SHOP_REFRESH": return LocalizationCatalogScript.text("UI_RUN_SCENE_0093")
		"SHOP_EXIT": return LocalizationCatalogScript.text("UI_RUN_SCENE_0094")
		"ENTER_WORKSHOP": return LocalizationCatalogScript.text("UI_RUN_SCENE_0095")
		"WORKSHOP_SELECT_SERVICE": return LocalizationCatalogScript.template("UI_RUN_SCENE_0096") % _pretty_words(str(action.get("service_id", target)))
		"WORKSHOP_SELECT_TARGET": return LocalizationCatalogScript.template("UI_RUN_SCENE_0097") % _pretty_tile_id(str(details.get("tile_definition_id", "")))
		"WORKSHOP_BACK": return LocalizationCatalogScript.text("UI_RUN_SCENE_0098")
		"WORKSHOP_SERVICE": return _workshop_action_label(action, details)
		"WORKSHOP_EXIT": return LocalizationCatalogScript.text("UI_RUN_SCENE_0099")
		"ENTER_EVENT": return LocalizationCatalogScript.text("UI_RUN_SCENE_0100")
		"EVENT_OPTION": return str(details.get("label", LocalizationCatalogScript.template("UI_RUN_SCENE_0101") % _pretty_id(target)))
		"RUN_SUMMARY": return LocalizationCatalogScript.text("UI_RUN_SCENE_0102")
	return LocalizationCatalogScript.template("UI_RUN_SCENE_0103") % [_pretty_words(kind), _pretty_id(target)]

func _compact_action_label(action: Dictionary) -> String:
	var kind := str(action.get("kind", "ACTION"))
	var target := str(action.get("target_id", ""))
	var details: Dictionary = action.get("details", {}) if action.get("details", {}) is Dictionary else {}
	match kind:
		"CHARACTER": return LocalizationCatalogScript.template("UI_RUN_SCENE_0104") % _pretty_id(target)
		"CONTRACT": return LocalizationCatalogScript.template("UI_RUN_SCENE_0105") % str(details.get("name", _pretty_id(target)))
		"TECHNIQUE": return LocalizationCatalogScript.template("UI_RUN_SCENE_0106") % _pretty_words(str(details.get("technique_kind", "Core")))
		"PARTIAL_SETTLEMENT": return LocalizationCatalogScript.template("UI_RUN_SCENE_0107") % _pretty_words(str(details.get("pattern_type", "Pattern")))
		"COMPLETE_HAND": return LocalizationCatalogScript.text("UI_RUN_SCENE_0108")
		"RESERVE": return LocalizationCatalogScript.text("UI_RUN_SCENE_0109")
		"DISCARD": return LocalizationCatalogScript.text("UI_RUN_SCENE_0110")
		"RESERVE_SWAP": return LocalizationCatalogScript.text("UI_RUN_SCENE_0111")
		"REWARD", "ELITE_REWARD", "BOSS_REWARD": return LocalizationCatalogScript.text("UI_RUN_SCENE_0112")
		"SHOP_OFFER": return LocalizationCatalogScript.text("UI_RUN_SCENE_0113")
		"EVENT_OPTION": return LocalizationCatalogScript.text("UI_RUN_SCENE_0114")
		"WORKSHOP_SELECT_TARGET": return LocalizationCatalogScript.text("UI_RUN_SCENE_0115")
		"WORKSHOP_SERVICE": return _pretty_words(str(action.get("service_id", target)))
	var full_label := _action_label(action)
	return _pretty_words(kind) if full_label.length() > 38 else full_label

func _action_details_text(action: Dictionary) -> String:
	if action.is_empty():
		return ""
	var kind := str(action.get("kind", ""))
	var details: Dictionary = action.get("details", {}) if action.get("details", {}) is Dictionary else {}
	if kind == "CONTRACT":
		return _contract_action_details_text(details, str(action.get("target_id", "")))
	if kind == "WORKSHOP_SERVICE":
		return _action_label(action)
	return _action_label(action)

func _help_text(phase: String) -> String:
	var phase_help := ""
	match phase:
		RunPhaseScript.CHARACTER_SELECT: phase_help = LocalizationCatalogScript.text("UI_RUN_SCENE_0116")
		RunPhaseScript.CONTRACT_SELECT: phase_help = LocalizationCatalogScript.text("UI_RUN_SCENE_0117")
		RunPhaseScript.MAP_CHOICE: phase_help = LocalizationCatalogScript.text("UI_RUN_SCENE_0118")
		RunPhaseScript.BATTLE: phase_help = LocalizationCatalogScript.text("UI_RUN_SCENE_0119")
		RunPhaseScript.RUN_SUMMARY: phase_help = LocalizationCatalogScript.text("UI_RUN_SCENE_0120")
		RunPhaseScript.RUN_COMPLETE: phase_help = LocalizationCatalogScript.text("UI_RUN_SCENE_0121")
		_: phase_help = LocalizationCatalogScript.text("UI_RUN_SCENE_0122")
	return LocalizationCatalogScript.template("UI_RUN_SCENE_0123") % phase_help

func _action_label_for_target(kind: String, target_id: String) -> String:
	return LocalizationCatalogScript.template("UI_RUN_SCENE_0124") % [_pretty_words(kind), _pretty_id(target_id)]

func _workshop_action_label(action: Dictionary, details: Dictionary) -> String:
	var service_id := str(action.get("service_id", action.get("target_id", "")))
	var tile_label := _pretty_tile_id(str(details.get("tile_definition_id", "")))
	var price := int(details.get("price", 0))
	match service_id:
		"TRANSFORM":
			return LocalizationCatalogScript.template("UI_RUN_SCENE_0125") % [tile_label, _pretty_tile_id(str(action.get("value_id", ""))), price]
		"ADD_MODIFIER":
			return LocalizationCatalogScript.template("UI_RUN_SCENE_0126") % [_pretty_id(str(action.get("modifier_id", ""))), tile_label, price]
		"REPLACE_MODIFIER":
			return LocalizationCatalogScript.template("UI_RUN_SCENE_0127") % [tile_label, _pretty_id(str(action.get("modifier_id", ""))), price]
		"REMOVE":
			return LocalizationCatalogScript.template("UI_RUN_SCENE_0128") % [tile_label, price]
		"DUPLICATE":
			return LocalizationCatalogScript.template("UI_RUN_SCENE_0129") % [tile_label, price]
		"REFINEMENT_TOKEN":
			return LocalizationCatalogScript.template("UI_RUN_SCENE_0130") % [tile_label, price]
	return LocalizationCatalogScript.template("UI_RUN_SCENE_0131") % _pretty_words(service_id)

func _action_tooltip(action: Dictionary) -> String:
	var details: Dictionary = action.get("details", {}) if action.get("details", {}) is Dictionary else {}
	if action.get("kind", "") == "CONTRACT":
		return _contract_action_details_text(details, str(action.get("target_id", "")))
	if action.get("kind", "") != "WORKSHOP_SERVICE":
		return JSON.stringify(action.get("details", {}))
	var service_id := str(action.get("service_id", action.get("target_id", "")))
	var tile_definition_id := str(details.get("tile_definition_id", ""))
	var lines := PackedStringArray()
	lines.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0132") % str(action.get("instance_id", "")))
	lines.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0133") % [_pretty_tile_id(tile_definition_id), tile_definition_id])
	match service_id:
		"TRANSFORM":
			var value_id := str(action.get("value_id", ""))
			lines.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0134") % [_pretty_tile_id(value_id), value_id])
		"ADD_MODIFIER":
			lines.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0135") % str(action.get("modifier_id", "")))
		"REPLACE_MODIFIER":
			lines.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0136") % [_join_strings(details.get("existing_modifier_ids", [])), str(action.get("modifier_id", ""))])
	lines.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0137") % int(details.get("price", 0)))
	if service_id == "REFINEMENT_TOKEN":
		lines.append(LocalizationCatalogScript.text("UI_RUN_SCENE_0138"))
	return "\n".join(lines)

func _contract_action_label(details: Dictionary, target_id: String) -> String:
	var contract_name := str(details.get("name", _pretty_id(target_id)))
	var risk := str(details.get("risk_summary", LocalizationCatalogScript.text("UI_RUN_SCENE_0139")))
	var reward := str(details.get("reward_summary", LocalizationCatalogScript.text("UI_RUN_SCENE_0140")))
	return LocalizationCatalogScript.template("UI_RUN_SCENE_0141") % [contract_name, risk, reward]

func _contract_action_details_text(details: Dictionary, target_id: String) -> String:
	var contract_name := str(details.get("name", _pretty_id(target_id)))
	var risk := str(details.get("risk_summary", LocalizationCatalogScript.text("UI_RUN_SCENE_0142")))
	var reward := str(details.get("reward_summary", LocalizationCatalogScript.text("UI_RUN_SCENE_0143")))
	var build_bias := str(details.get("build_bias_summary", LocalizationCatalogScript.text("UI_RUN_SCENE_0144")))
	var yaku_signal := str(details.get("yaku_signal_summary", LocalizationCatalogScript.text("UI_RUN_SCENE_0145")))
	return LocalizationCatalogScript.template("UI_RUN_SCENE_0146") % [contract_name, risk, reward, build_bias, yaku_signal]

func _join_strings(values: Array) -> String:
	var result := PackedStringArray()
	for value in values:
		result.append(str(value))
	return ", ".join(result)

func _pretty_tile_id(definition_id: String) -> String:
	return _pretty_id(definition_id)

func _pretty_id(identifier: String) -> String:
	if identifier.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_SCENE_0148")
	if "." in identifier:
		return LocalizationCatalogScript.content_text(identifier)
	return _pretty_words(identifier)

func _pretty_words(value: String) -> String:
	return LocalizationCatalogScript.word_text(value)

func _add_section_heading(parent: Control, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 16)
	parent.add_child(heading)

func _add_wrapped_label(parent: Control) -> Label:
	var label := Label.new()
	_configure_wrapped_label(label)
	parent.add_child(label)
	return label

func _configure_wrapped_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.resized.connect(_defer_wrapped_label_height_update.bind(label))

func _set_wrapped_label_text(label: Label, value: String) -> void:
	label.text = value
	_update_wrapped_label_height(label)
	_defer_wrapped_label_height_update(label)

func _defer_wrapped_label_height_update(label: Label) -> void:
	if label == null or not is_instance_valid(label) or label.is_queued_for_deletion():
		return
	# Containers assign final widths during layout. Re-measure after that pass so
	# wrapped text can raise its minimum height before the next container sort.
	call_deferred("_update_wrapped_label_height", label)

func _update_wrapped_label_height(label: Label) -> void:
	if label == null or not is_instance_valid(label) or label.size.x <= 0.0:
		return
	var required_height := 0.0
	if not label.text.is_empty():
		required_height = float(maxi(1, label.get_line_count()) * label.get_line_height() + 4)
	if absf(label.custom_minimum_size.y - required_height) > 0.5:
		label.custom_minimum_size.y = required_height
