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
const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const TableBackdropScript = preload("res://src/presentation/ui/table_backdrop.gd")
const RunJourneyViewScript = preload("res://src/presentation/ui/run_journey_view.gd")
const RunSummaryViewScript = preload("res://src/presentation/ui/run_summary_view.gd")
const PreferencesOverlayScript = preload("res://src/presentation/ui/preferences_overlay.gd")
const BattleViewPath := "res://src/presentation/ui/battle_view.gd"

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
var _profile_recovery_scroll: ScrollContainer
var _profile_recovery_content: VBoxContainer
var _profile_details_button: Button
var _profile_details_scroll: ScrollContainer
var _profile_details_value: Label
var _profile_technical_details: Dictionary = {}
var _profile_details_expanded := false
var _reset_profile_button: Button
var _new_run_button: Button
var _suspend_choice_panel: VBoxContainer
var _suspend_status_scroll: ScrollContainer
var _suspend_status: Label
var _suspend_details_button: Button
var _suspend_details_scroll: ScrollContainer
var _suspend_details_value: Label
var _resume_run_button: Button
var _new_run_from_suspend_button: Button
var _suspend_message_parts: Array[Dictionary] = []
var _suspend_technical_details: Dictionary = {}
var _suspend_details_expanded := false
var _suspend_new_run_label_key := "UI_RUN_SCENE_0044"
var _suspend_resume_visible := false
var _suspend_can_start_new := false
var _meta_progress_warning_parts: Array[Dictionary] = []
var _actions_column: VBoxContainer
var _action_details_value: Label
var _run_columns: Control
var _summary_panel: PanelContainer
var _summary_value: Label
var _summary_acknowledge_button: Button
var _table_backdrop
var _page: VBoxContainer
var _journey_host: Control
var _journey_view
var _summary_view
var _battle_view
var _run_status_panel: PanelContainer
var _settings_button: Button
var _commit_selected_button: Button
var _back_button: Button
var _preferences_overlay: Control
var _confirmation_overlay: Control
var _confirmation_message: Label
var _confirm_new_run_button: Button
var _cancel_new_run_button: Button
var _new_run_from_suspend_pending := false
var _new_run_confirmation_origin: Control
var _applied_preferences: Dictionary = {}
var _battle_focus_action_id := ""
var _battle_configured_controller
var _suppress_controller_render := false
var _last_rendered_phase := ""
var _summary_duration_identity := ""
var _summary_duration_anchor_unix_seconds := -1

func _init() -> void:
	# Copy is already resolved through Localization; controls must not translate
	# it a second time (which also doubles pseudo-localization expansion).
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	_register_controller_input_mappings()
	if suspend_store == null:
		suspend_store = SuspendSaveStoreScript.new(suspend_file_path)
	if meta_progress_coordinator == null:
		meta_progress_coordinator = MetaProgressCoordinatorScript.new()
	var meta_load: Dictionary = meta_progress_coordinator.load_profile()
	if not meta_load.get("accepted", false):
		var recovery_path := str(meta_load.get("preserved_path", ""))
		var profile_path := ProjectSettings.globalize_path(str(meta_progress_coordinator.store.file_path))
		var error_codes: Array[String] = [str(meta_load.get("code", "LOAD_FAILED"))]
		var source_preserved := bool(meta_load.get("rejected_source_preserved", false))
		if not source_preserved:
			error_codes.append(str(meta_load.get("preservation_error", "META_PROGRESS_PRESERVE_FAILED")))
		_profile_technical_details = {"profile_path": profile_path, "recovery_path": recovery_path, "codes": error_codes, "manual_recovery_required": not source_preserved}
		var warning_key := "UI_PROFILE_RECOVERY_PRESERVED" if source_preserved else "UI_PROFILE_RECOVERY_UNPRESERVED"
		_meta_progress_warning_parts = [_localized_message_part(warning_key)]
		_meta_progress_load_warning = _message_parts_text(_meta_progress_warning_parts)
	_build_interface()
	_connect_presentation_preferences()
	var registry_result := _validated_content_registry()
	if not registry_result.get("accepted", false):
		_startup_error = str(registry_result.get("message", LocalizationCatalogScript.text("UI_RUN_SCENE_0004")))
	else:
		_content_registry = registry_result.registry
		_load_suspend_or_start_new(_content_registry)
	_render()

func _input(event: InputEvent) -> void:
	if _preferences_overlay != null and _preferences_overlay.visible:
		_preferences_overlay.call("_input", event)
		return
	if _confirmation_overlay != null and _confirmation_overlay.visible:
		var modal_action := _mapped_ui_action(event)
		if modal_action == "ui_cancel":
			_close_new_run_confirmation(true)
			get_viewport().set_input_as_handled()
		elif modal_action == "ui_accept":
			_confirm_focused_control()
			get_viewport().set_input_as_handled()
		elif modal_action == "ui_focus_next":
			_move_control_focus(1)
			get_viewport().set_input_as_handled()
		elif modal_action == "ui_focus_prev":
			_move_control_focus(-1)
			get_viewport().set_input_as_handled()
		return
	var action := _mapped_ui_action(event)
	if action.is_empty():
		return
	match action:
		"ui_accept":
			_confirm_focused_control()
		"ui_cancel":
			if _journey_view != null and _journey_view.has_method("cancel_local_state") and _journey_view.cancel_local_state():
				_refresh_action_rail()
			elif _battle_view != null and _battle_view.visible and _battle_view.has_method("cancel") and _battle_view.cancel():
				pass
			elif controller != null:
				controller.back()
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
	if _preferences_overlay != null and _preferences_overlay.visible:
		return
	if _confirmation_overlay != null and _confirmation_overlay.visible:
		_move_control_focus(direction)
		return
	if _journey_view != null and bool(_journey_view.get("is_confirmation_open")):
		_move_control_focus(direction)
		return
	var viewport := get_viewport()
	if viewport != null and _suspend_status_scroll != null and viewport.gui_get_focus_owner() == _suspend_status_scroll:
		_scroll_suspend_text(_suspend_status_scroll, direction)
		return
	if viewport != null and _suspend_details_scroll != null and viewport.gui_get_focus_owner() == _suspend_details_scroll:
		_scroll_suspend_text(_suspend_details_scroll, direction)
		return
	if viewport != null and _profile_details_scroll != null and viewport.gui_get_focus_owner() == _profile_details_scroll:
		_scroll_suspend_text(_profile_details_scroll, direction)
		return
	if viewport != null and _overview_scroll != null and viewport.gui_get_focus_owner() == _overview_scroll:
		_scroll_overview(direction)
		return
	_move_control_focus(direction)

func _move_control_focus(direction: int) -> void:
	var focusable: Array[Control] = []
	if _confirmation_overlay != null and _confirmation_overlay.visible:
		focusable = [_cancel_new_run_button, _confirm_new_run_button]
	elif _journey_view != null and bool(_journey_view.get("is_confirmation_open")):
		focusable = [_back_button, _commit_selected_button]
	else:
		for candidate in find_children("*", "Control", true, false):
			if not (candidate is BaseButton or candidate == _overview_scroll or candidate == _suspend_status_scroll or candidate == _suspend_details_scroll or candidate == _profile_details_scroll):
				continue
			var control := candidate as Control
			if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
				continue
			if control is BaseButton and (control as BaseButton).disabled:
				continue
			if control == _commit_selected_button and str(control.get_meta("run_commit_action_id", "")).is_empty():
				continue
			focusable.append(control)
	if focusable.is_empty():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var current := viewport.gui_get_focus_owner() as Control
	var index := focusable.find(current)
	if index < 0:
		index = 0 if direction > 0 else focusable.size() - 1
	else:
		index = (index + direction + focusable.size()) % focusable.size()
	_grab_focus_if_available(focusable[index])

func _scroll_overview(direction: int) -> void:
	if _overview_scroll == null:
		return
	var scrollbar := _overview_scroll.get_v_scroll_bar()
	var maximum := maxi(0, int(scrollbar.max_value - scrollbar.page))
	var step := maxi(72, int(scrollbar.page * 0.75))
	_overview_scroll.scroll_vertical = clampi(_overview_scroll.scroll_vertical + direction * step, 0, maximum)


func _scroll_suspend_text(scroll: ScrollContainer, direction: int) -> void:
	var scrollbar := scroll.get_v_scroll_bar()
	var maximum := maxi(0, int(scrollbar.max_value - scrollbar.page))
	var step := maxi(48, int(scrollbar.page * 0.75))
	scroll.scroll_vertical = clampi(scroll.scroll_vertical + direction * step, 0, maximum)


func _grab_focus_if_available(control: Control) -> void:
	if control != null and is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
		control.grab_focus()

func _confirm_focused_control() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var focused_control := viewport.gui_get_focus_owner() as Control
	if focused_control == null or not focused_control.is_visible_in_tree():
		return
	if focused_control == _commit_selected_button:
		if str(_commit_selected_button.get_meta("run_commit_action_id", "")).is_empty() or _commit_selected_button.disabled:
			return
		_commit_selected_button.emit_signal("pressed")
		return
	if not focused_control is BaseButton or (focused_control as BaseButton).disabled:
		return
	var focused_button := focused_control as Button
	if focused_button.has_meta("run_action_id"):
		# Action cards only change selected presentation state. The action rail is the command seam.
		focused_button.emit_signal("pressed")
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
					_localized_message_part("UI_RUN_RECOVERY_INTERRUPTED_PRESERVED"),
					true,
					_suspend_details([str(stored.get("code", "SUSPEND_COMMIT_INTERRUPTED"))], _suspend_rejected_copy_path),
				)
			else:
				_show_suspend_recovery_required(
					_localized_message_part("UI_RUN_RECOVERY_INTERRUPTED_MANUAL_COPY"),
					false,
					_suspend_details([str(stored.get("code", "SUSPEND_COMMIT_INTERRUPTED")), str(interrupted_preservation.get("code", "SUSPEND_PRESERVE_FAILED"))]),
				)
			return
		_show_suspend_recovery_required(
			_localized_message_part("UI_RUN_RECOVERY_MANUAL_COPY"),
			false,
			_suspend_details([str(stored.get("code", "SUSPEND_READ_FAILED"))]),
		)
		return
	if not stored.get("exists", false):
		_start_new_run(registry)
		return
	var loaded: Dictionary = _load_suspend_contents(str(stored.get("contents", "")), registry)
	if not loaded.get("accepted", false):
		var preservation: Dictionary = suspend_store.preserve_source()
		var unsupported_version := _has_load_validation_error(loaded, "UNSUPPORTED_CONTENT_VERSION") or _has_load_validation_error(loaded, "UNSUPPORTED_GAME_VERSION")
		if preservation.get("accepted", false):
			_suspend_rejected_copy_path = str(preservation.get("path", ""))
			var preserved_message: Array[Dictionary] = [_localized_message_part("UI_RUN_RECOVERY_PRESERVED")]
			if unsupported_version:
				var version_detail := _suspend_load_error_part(loaded)
				version_detail["separator_before"] = ""
				preserved_message = [version_detail, _localized_message_part("UI_RUN_RECOVERY_PRESERVED")]
				preserved_message[1]["separator_before"] = "\n"
			_show_suspend_recovery_required(
				preserved_message,
				true,
				_suspend_details([str(loaded.get("code", "SUSPEND_LOAD_FAILED"))], _suspend_rejected_copy_path),
			)
		else:
			var preserve_code := str(preservation.get("code", "SUSPEND_PRESERVE_FAILED"))
			var manual_copy_message: Array[Dictionary] = [_localized_message_part("UI_RUN_RECOVERY_MANUAL_COPY")]
			if unsupported_version:
				var version_detail := _suspend_load_error_part(loaded)
				manual_copy_message = [version_detail, _localized_message_part("UI_RUN_RECOVERY_MANUAL_COPY")]
				manual_copy_message[1]["separator_before"] = "\n"
			_show_suspend_recovery_required(
				manual_copy_message,
				false,
				_suspend_details([str(loaded.get("code", "SUSPEND_LOAD_FAILED")), preserve_code]),
			)
		return
	var saved_domain = loaded.domain
	var finalized: Dictionary = suspend_store.finalize_load(stored, str(saved_domain.state.run_id))
	if not finalized.get("accepted", false):
		var preservation: Dictionary = suspend_store.preserve_source()
		var recovery_path := str(preservation.get("path", "")) if preservation.get("accepted", false) else ""
		var suffix_part := _localized_message_part("UI_RUN_SCENE_0017", [recovery_path]) if not recovery_path.is_empty() else _localized_message_part("UI_RUN_SCENE_0018")
		var finalized_code := str(finalized.get("code", "SUSPEND_RECOVERY_FAILED"))
		_show_suspend_recovery_required(
			_localized_message_part("UI_RUN_SCENE_0019", [finalized_code, suffix_part]),
			preservation.get("accepted", false),
			_suspend_details([finalized_code], recovery_path, str(saved_domain.state.run_id), str(loaded.snapshot.checkpoint_metadata.get("stable_boundary", ""))),
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
			var error_code := str(cleared.get("code", "META_PROGRESS_SAVE_FAILED")) if progression_pending else str(cleared.get("code", "SUSPEND_CLEAR_FAILED"))
			var prefix := _localized_message_part("UI_RUN_SCENE_0020", [error_code]) if progression_pending else _localized_message_part("UI_RUN_SCENE_0021", [error_code])
			_show_valid_suspend_choice(saved_domain, prefix, not progression_pending, str(loaded.snapshot.checkpoint_metadata.get("stable_boundary", "")))
		return
	_pending_resume_domain = saved_domain
	var cleanup_prefix: Dictionary = {}
	if finalized.has("cleanup_warning"):
		cleanup_prefix = _localized_message_part("UI_RUN_SCENE_0022", [str(finalized.get("cleanup_warning"))])
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

func _suspend_load_error_part(loaded: Dictionary) -> Dictionary:
	for issue in loaded.get("errors", []):
		var code := str(issue.get("code", "")) if issue is Dictionary else ""
		if code == "UNSUPPORTED_CONTENT_VERSION":
			return _localized_message_part("UI_RUN_SCENE_0023")
		if code == "UNSUPPORTED_GAME_VERSION":
			return _localized_message_part("UI_RUN_SCENE_0024")
	return _localized_message_part("UI_RUN_SCENE_0025", [str(loaded.get("code", "SUSPEND_LOAD_FAILED"))])

func _show_valid_suspend_choice(saved_domain, prefix: Dictionary = {}, can_start_new: bool = true, saved_boundary: String = "") -> void:
	var checkpoint: Dictionary = saved_domain.checkpoint()
	var message_parts: Array[Dictionary] = []
	if not prefix.is_empty():
		message_parts.append(prefix)
	var run_id := str(saved_domain.state.run_id)
	var boundary := saved_boundary if not saved_boundary.is_empty() else str(checkpoint.get("stable_boundary", ""))
	if prefix.is_empty():
		message_parts.append(_localized_message_part("UI_RUN_RECOVERY_READY"))
	else:
		message_parts.append(_localized_message_part("UI_RUN_SCENE_0026", [run_id]))
	var codes: Array[String] = []
	if not prefix.is_empty():
		codes.append(str(prefix.get("args", [""])[0]))
	_show_suspend_choice_parts(
		message_parts,
		true,
		"UI_RUN_SCENE_0028",
		can_start_new,
		_suspend_details(codes, suspend_file_path, run_id, boundary),
	)

func _show_suspend_recovery_required(message: Variant, can_start_new: bool, technical_details: Dictionary = {}) -> void:
	var message_parts: Array[Dictionary] = []
	if message is Array:
		for part in message:
			if part is Dictionary:
				message_parts.append(part)
	elif message is Dictionary:
		message_parts.append(message)
	_show_suspend_choice_parts(message_parts, false, "UI_RUN_SCENE_0029", can_start_new, technical_details)

func _show_suspend_choice_parts(message_parts: Array[Dictionary], can_resume: bool, new_run_label_key: String, can_start_new: bool, technical_details: Dictionary = {}) -> void:
	_suspend_message_parts = message_parts.duplicate(true)
	_suspend_resume_visible = can_resume
	_suspend_new_run_label_key = new_run_label_key
	_suspend_can_start_new = can_start_new
	_suspend_technical_details = technical_details.duplicate(true)
	_suspend_details_expanded = false
	_suspend_choice_panel.visible = true
	_refresh_suspend_presentation()
	_run_columns.visible = false
	_summary_panel.visible = false
	_new_run_button.disabled = true
	var initial_choice: Button = _resume_run_button if _resume_run_button.visible and not _resume_run_button.disabled else _new_run_from_suspend_button
	if initial_choice.visible and not initial_choice.disabled and initial_choice.is_inside_tree():
		initial_choice.grab_focus()


func _localized_message_part(key: String, args: Array = []) -> Dictionary:
	return {"key": key, "args": args.duplicate(true)}


func _message_part_text(part: Dictionary) -> String:
	if part.has("raw"):
		return str(part.get("raw", ""))
	var values: Array = []
	for value in part.get("args", []):
		values.append(_message_part_text(value) if value is Dictionary and value.has("key") else value)
	var result := LocalizationCatalogScript.format(str(part.get("key", "")), values)
	for suffix in part.get("append", []):
		if suffix is Dictionary:
			result += _message_part_text(suffix)
	return result


func _message_parts_text(parts: Array[Dictionary]) -> String:
	var result := ""
	for index in parts.size():
		var part: Dictionary = parts[index]
		var separator := str(part.get("separator_before", "\n" if index > 0 else ""))
		result += separator + _message_part_text(part)
	return result


func _suspend_details(codes: Array, recovery_path: String = "", run_id: String = "", boundary: String = "") -> Dictionary:
	return {
		"source_path": ProjectSettings.globalize_path(suspend_file_path),
		"recovery_path": recovery_path,
		"run_id": run_id,
		"boundary": _pretty_words(boundary) if not boundary.is_empty() else "",
		"codes": codes.duplicate(),
	}


func _refresh_suspend_presentation() -> void:
	var scale := float(_applied_preferences.get("ui_scale", 1.0))
	if _suspend_status_scroll != null:
		_suspend_status_scroll.custom_minimum_size.y = 80.0 * scale
	if _suspend_status != null:
		_set_wrapped_label_text(_suspend_status, _message_parts_text(_suspend_message_parts))
	if _resume_run_button != null:
		_resume_run_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0043")
		_resume_run_button.visible = _suspend_resume_visible
		_resume_run_button.disabled = not _suspend_resume_visible
	if _new_run_from_suspend_button != null:
		_new_run_from_suspend_button.text = LocalizationCatalogScript.text(_suspend_new_run_label_key)
		_new_run_from_suspend_button.visible = true
		_new_run_from_suspend_button.disabled = not _suspend_can_start_new
	if _suspend_details_button != null:
		var has_details := not _suspend_technical_details.is_empty()
		_suspend_details_button.visible = has_details
		_suspend_details_button.text = LocalizationCatalogScript.text("UI_RUN_RECOVERY_DETAILS_HIDE" if _suspend_details_expanded else "UI_RUN_RECOVERY_DETAILS_SHOW")
	if _suspend_details_value != null:
		var codes: Array = _suspend_technical_details.get("codes", [])
		_suspend_details_value.text = LocalizationCatalogScript.format("UI_RUN_RECOVERY_DETAILS_BODY", [
			str(_suspend_technical_details.get("source_path", "")),
			str(_suspend_technical_details.get("recovery_path", "")),
			str(_suspend_technical_details.get("run_id", "")),
			str(_suspend_technical_details.get("boundary", "")),
			", ".join(PackedStringArray(codes)),
		]) if not _suspend_technical_details.is_empty() else ""
		_suspend_details_value.visible = not _suspend_technical_details.is_empty() and _suspend_details_expanded
	if _suspend_details_scroll != null:
		_suspend_details_scroll.visible = not _suspend_technical_details.is_empty() and _suspend_details_expanded
		# Long translated headers leave less space at the minimum viewport.
		# Technical details remain scrollable without displacing the action rail.
		var viewport_height := get_viewport_rect().size.y if is_inside_tree() else 540.0
		_suspend_details_scroll.custom_minimum_size.y = minf(72.0 * scale, viewport_height * 0.13) if _suspend_details_scroll.visible else 0.0


func _on_suspend_details_pressed() -> void:
	_suspend_details_expanded = not _suspend_details_expanded
	_refresh_suspend_presentation()

func _start_new_run(registry) -> void:
	var seed := int(Time.get_ticks_usec() % 2147483647)
	var run_id := "alpha.%d.%d" % [Time.get_unix_time_from_system(), seed]
	_attach_controller(RunDomainScript.new_alpha_run(run_id, seed, registry, "", null, null, meta_progress_coordinator.state))

func _attach_controller(run_domain) -> void:
	controller = RunPresentationControllerScript.new(run_domain, null, meta_progress_coordinator, suspend_store)
	_summary_duration_identity = ""
	_summary_duration_anchor_unix_seconds = -1
	controller.set_mode(str(_applied_preferences.get("presentation_mode", "NORMAL")))
	controller.presentation_changed.connect(_on_controller_presentation_changed)


func _on_controller_presentation_changed() -> void:
	if not _suppress_controller_render:
		_render()

func _on_resume_run_pressed() -> void:
	if _pending_resume_domain == null:
		return
	var resumed_domain = _pending_resume_domain
	_pending_resume_domain = null
	if str(resumed_domain.state.phase) == RunPhaseScript.RUN_COMPLETE:
		var unlock_retry: Dictionary = meta_progress_coordinator.observe_run_state(resumed_domain.state)
		if unlock_retry.has("persisted") and not unlock_retry.get("persisted", false):
			var progression_code := str(unlock_retry.get("code", "META_PROGRESS_SAVE_FAILED"))
			_suspend_message_parts = [_localized_message_part("UI_RUN_SCENE_0030", [progression_code])]
			_suspend_technical_details["codes"] = [progression_code]
			_refresh_suspend_presentation()
			_pending_resume_domain = resumed_domain
			return
		var clear_result: Dictionary = suspend_store.clear()
		if not clear_result.get("accepted", false):
			var clear_code := str(clear_result.get("code", "SUSPEND_CLEAR_FAILED"))
			_suspend_message_parts = [_localized_message_part("UI_RUN_SCENE_0031", [clear_code])]
			_suspend_technical_details["codes"] = [clear_code]
			_refresh_suspend_presentation()
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
	_open_new_run_confirmation(true)


func _perform_new_run_from_suspend() -> void:
	var cleared: Dictionary = suspend_store.clear()
	if not cleared.get("accepted", false):
		var clear_code := str(cleared.get("code", "SUSPEND_CLEAR_FAILED"))
		_suspend_message_parts.append({
			"key": "UI_RUN_SCENE_0032",
			"args": [clear_code],
			"separator_before": "",
		})
		var existing_codes: Array = _suspend_technical_details.get("codes", [])
		existing_codes.append(clear_code)
		_suspend_technical_details["codes"] = existing_codes
		_refresh_suspend_presentation()
		_refresh_action_rail()
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
	var preference_service = _preferences_service()
	var initial_preferences: Dictionary = preference_service.call("snapshot") if preference_service != null else {"locale": "en", "ui_scale": 1.0, "presentation_mode": "NORMAL", "reduced_motion": false, "ambient_glow": true}
	var initial_locale := str(initial_preferences.get("locale", "en"))
	var initial_scale := float(initial_preferences.get("ui_scale", 1.0))
	theme = ForbiddenThemeScript.create_theme(initial_locale, initial_scale)
	_applied_preferences = initial_preferences.duplicate(true)
	_table_backdrop = TableBackdropScript.new()
	_table_backdrop.name = "TableBackdrop"
	_table_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_table_backdrop.z_index = -20
	add_child(_table_backdrop)
	_table_backdrop.call("configure", str(initial_preferences.get("presentation_mode", "NORMAL")), bool(initial_preferences.get("reduced_motion", false)), bool(initial_preferences.get("ambient_glow", true)))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	_page = VBoxContainer.new()
	_page.name = "RunJourneyPage"
	_page.add_theme_constant_override("separation", 5)
	margin.add_child(_page)

	var header := HBoxContainer.new()
	header.name = "RunHeader"
	header.add_theme_constant_override("separation", 10)
	header.custom_minimum_size.y = 38.0 * initial_scale
	_page.add_child(header)
	var title := Label.new()
	title.name = "GameTitle"
	title.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0038")
	ForbiddenThemeScript.title(title, initial_locale)
	title.add_theme_font_size_override("font_size", roundi(25.0 * initial_scale))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size.y = 38.0 * initial_scale
	header.add_child(title)
	_phase_value = Label.new()
	_phase_value.name = "RunPhaseLabel"
	_phase_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phase_value.add_theme_color_override("font_color", ForbiddenThemeScript.color("brass"))
	header.add_child(_phase_value)
	_settings_button = Button.new()
	_settings_button.name = "SettingsButton"
	_settings_button.text = LocalizationCatalogScript.text("UI_PREFS_TAB_SETTINGS")
	_settings_button.pressed.connect(_on_settings_pressed)
	ForbiddenThemeScript.style_button(_settings_button)
	header.add_child(_settings_button)
	_new_run_button = Button.new()
	_new_run_button.name = "NewRunButton"
	_new_run_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0040")
	_new_run_button.disabled = true
	_new_run_button.visible = false
	_new_run_button.pressed.connect(_on_new_run_pressed)
	header.add_child(_new_run_button)

	_profile_recovery_scroll = ScrollContainer.new()
	_profile_recovery_scroll.name = "ProfileRecoveryScroll"
	_profile_recovery_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_profile_recovery_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_profile_recovery_scroll.follow_focus = true
	_profile_recovery_scroll.focus_mode = Control.FOCUS_ALL
	_profile_recovery_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_profile_recovery_scroll)
	_profile_recovery_content = VBoxContainer.new()
	_profile_recovery_content.name = "ProfileRecoveryContent"
	_profile_recovery_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_recovery_content.add_theme_constant_override("separation", 5)
	_profile_recovery_scroll.add_child(_profile_recovery_content)
	_profile_status = Label.new()
	_profile_status.name = "ProfileRecoveryStatus"
	_configure_wrapped_label(_profile_status)
	_profile_status.text = _meta_progress_load_warning
	_profile_status.visible = not _meta_progress_load_warning.is_empty()
	_profile_recovery_content.add_child(_profile_status)
	_profile_details_button = Button.new()
	_profile_details_button.name = "ProfileDetailsButton"
	_profile_details_button.text = LocalizationCatalogScript.text("UI_RUN_RECOVERY_DETAILS_SHOW")
	_profile_details_button.visible = not _profile_technical_details.is_empty()
	_profile_details_button.pressed.connect(_on_profile_details_pressed)
	ForbiddenThemeScript.style_button(_profile_details_button)
	_profile_recovery_content.add_child(_profile_details_button)
	_profile_details_scroll = ScrollContainer.new()
	_profile_details_scroll.name = "ProfileDetailsScroll"
	_profile_details_scroll.visible = false
	_profile_details_scroll.custom_minimum_size.y = 0.0
	_profile_details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_profile_details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_profile_details_scroll.follow_focus = true
	_profile_details_scroll.focus_mode = Control.FOCUS_ALL
	_profile_recovery_content.add_child(_profile_details_scroll)
	_profile_details_value = Label.new()
	_profile_details_value.name = "ProfileDetailsValue"
	_configure_wrapped_label(_profile_details_value)
	_profile_details_value.visible = false
	_profile_details_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_details_scroll.add_child(_profile_details_value)
	_reset_profile_button = Button.new()
	_reset_profile_button.name = "ResetProfileButton"
	_reset_profile_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0041")
	_reset_profile_button.tooltip_text = LocalizationCatalogScript.text("UI_RUN_SCENE_0042")
	_reset_profile_button.visible = meta_progress_coordinator.recovery_required
	_reset_profile_button.disabled = _profile_reset_unavailable()
	_reset_profile_button.pressed.connect(_on_reset_profile_pressed)
	_profile_recovery_content.add_child(_reset_profile_button)
	_suspend_choice_panel = VBoxContainer.new()
	_suspend_choice_panel.name = "SuspendChoicePanel"
	_suspend_choice_panel.visible = false
	_suspend_choice_panel.add_theme_constant_override("separation", 8)
	_page.add_child(_suspend_choice_panel)
	_suspend_status_scroll = ScrollContainer.new()
	_suspend_status_scroll.name = "SuspendMessageScroll"
	_suspend_status_scroll.custom_minimum_size.y = 80.0 * initial_scale
	_suspend_status_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suspend_status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_suspend_status_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_suspend_status_scroll.follow_focus = true
	_suspend_status_scroll.focus_mode = Control.FOCUS_ALL
	_suspend_choice_panel.add_child(_suspend_status_scroll)
	_suspend_status = Label.new()
	_suspend_status.name = "SuspendStatus"
	_configure_wrapped_label(_suspend_status)
	_suspend_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suspend_status_scroll.add_child(_suspend_status)
	_suspend_details_button = Button.new()
	_suspend_details_button.name = "SuspendDetailsButton"
	_suspend_details_button.text = LocalizationCatalogScript.text("UI_RUN_RECOVERY_DETAILS_SHOW")
	_suspend_details_button.visible = false
	_suspend_details_button.pressed.connect(_on_suspend_details_pressed)
	ForbiddenThemeScript.style_button(_suspend_details_button)
	_suspend_choice_panel.add_child(_suspend_details_button)
	_suspend_details_scroll = ScrollContainer.new()
	_suspend_details_scroll.name = "SuspendDetailsScroll"
	_suspend_details_scroll.visible = false
	_suspend_details_scroll.custom_minimum_size.y = 0.0
	_suspend_details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suspend_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_suspend_details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_suspend_details_scroll.follow_focus = true
	_suspend_details_scroll.focus_mode = Control.FOCUS_ALL
	_suspend_choice_panel.add_child(_suspend_details_scroll)
	_suspend_details_value = Label.new()
	_suspend_details_value.name = "SuspendDetailsValue"
	_configure_wrapped_label(_suspend_details_value)
	_suspend_details_value.visible = false
	_suspend_details_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suspend_details_scroll.add_child(_suspend_details_value)
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

	_run_status_panel = PanelContainer.new()
	_run_status_panel.name = "RunStatusRail"
	_run_status_panel.custom_minimum_size.y = 54.0 * initial_scale
	ForbiddenThemeScript.style_panel(_run_status_panel, "raised")
	_page.add_child(_run_status_panel)
	_overview_scroll = ScrollContainer.new()
	_overview_scroll.name = "RunOverviewScroll"
	_overview_scroll.custom_minimum_size.y = 42.0 * initial_scale
	_overview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_overview_scroll.follow_focus = true
	_overview_scroll.focus_mode = Control.FOCUS_ALL
	_overview_scroll.tooltip_text = LocalizationCatalogScript.text("UI_RUN_SCENE_0050")
	_run_status_panel.add_child(_overview_scroll)
	var overview := VBoxContainer.new()
	overview.add_theme_constant_override("separation", 2)
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_scroll.add_child(overview)
	_run_value = _add_wrapped_label(overview)
	_battle_value = _add_wrapped_label(overview)
	_hand_value = _add_wrapped_label(overview)
	_help_value = _add_wrapped_label(overview)
	_help_value.name = "RunHelpPrompt"
	_help_value.add_theme_color_override("font_color", ForbiddenThemeScript.color("muted"))
	_tutorial_prompt = _add_wrapped_label(overview)
	_tutorial_prompt.name = "TutorialPrompt"
	_tutorial_prompt.add_theme_color_override("font_color", ForbiddenThemeScript.color("brass"))
	_tutorial_prompt.visible = false

	_run_columns = PanelContainer.new()
	_run_columns.name = "RunJourneyStage"
	_run_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_run_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ForbiddenThemeScript.style_panel(_run_columns, "table")
	_page.add_child(_run_columns)
	_journey_host = Control.new()
	_journey_host.name = "JourneyHost"
	_journey_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journey_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_run_columns.add_child(_journey_host)
	_journey_view = RunJourneyViewScript.new()
	_journey_view.name = "RunJourneyView"
	_journey_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journey_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_journey_view.configure(Callable(self, "_action_label"), Callable(self, "_action_tooltip"), Callable(self, "_action_details_text"), Callable(self, "_pretty_id"), Callable(self, "_pretty_words"))
	_journey_view.connect("selection_changed", Callable(self, "_on_journey_selection_changed"))
	_journey_view.connect("action_committed", Callable(self, "_on_journey_action_committed"))
	_journey_view.connect("focus_changed", Callable(self, "_on_journey_focus_changed"))
	_journey_view.connect("confirmation_changed", Callable(self, "_on_journey_confirmation_changed"))
	_journey_host.add_child(_journey_view)
	_action_details_value = _journey_view.details_label()

	_summary_panel = PanelContainer.new()
	_summary_panel.name = "RunSummaryPanel"
	_summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_panel.visible = false
	ForbiddenThemeScript.style_panel(_summary_panel, "table")
	_page.add_child(_summary_panel)
	_summary_view = RunSummaryViewScript.new()
	_summary_view.name = "RunSummaryView"
	_summary_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_panel.add_child(_summary_view)
	_summary_view.render(null, "", initial_locale, initial_scale)
	_summary_value = _summary_view.summary_label()

	_feedback_value = Label.new()
	_feedback_value.name = "RunFeedback"
	_configure_wrapped_label(_feedback_value)
	_feedback_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var footer := HBoxContainer.new()
	footer.name = "RunActionRail"
	footer.add_theme_constant_override("separation", 10)
	_page.add_child(footer)
	footer.add_child(_feedback_value)
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0014")
	_back_button.custom_minimum_size = Vector2(140.0, 44.0)
	_back_button.pressed.connect(_on_back_pressed)
	ForbiddenThemeScript.style_button(_back_button)
	footer.add_child(_back_button)
	_commit_selected_button = Button.new()
	_commit_selected_button.name = "CommitSelectedButton"
	_commit_selected_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0037")
	_commit_selected_button.custom_minimum_size = Vector2(220.0, 44.0)
	_commit_selected_button.pressed.connect(_on_commit_selected_pressed)
	ForbiddenThemeScript.style_button(_commit_selected_button, true)
	footer.add_child(_commit_selected_button)
	_summary_acknowledge_button = _commit_selected_button

	_build_new_run_confirmation()
	_preferences_overlay = PreferencesOverlayScript.new()
	_preferences_overlay.name = "PreferencesOverlay"
	_preferences_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preferences_overlay.connect("preferences_applied", Callable(self, "_on_preferences_applied"))
	add_child(_preferences_overlay)


func _build_new_run_confirmation() -> void:
	_confirmation_overlay = Control.new()
	_confirmation_overlay.name = "NewRunConfirmation"
	_confirmation_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirmation_overlay.visible = false
	_confirmation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirmation_overlay.z_index = 30
	add_child(_confirmation_overlay)
	var scrim := ColorRect.new()
	scrim.name = "ConfirmationScrim"
	scrim.color = Color(0.015, 0.055, 0.043, 0.9)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirmation_overlay.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirmation_overlay.add_child(center)
	var card := PanelContainer.new()
	card.name = "NewRunConfirmationCard"
	card.custom_minimum_size = Vector2(540.0, 220.0)
	ForbiddenThemeScript.style_panel(card, "paper", true)
	center.add_child(card)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	card.add_child(layout)
	var heading := Label.new()
	heading.name = "ConfirmationHeading"
	heading.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0034")
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ForbiddenThemeScript.title(heading, str(_applied_preferences.get("locale", "en")))
	layout.add_child(heading)
	_confirmation_message = Label.new()
	_confirmation_message.name = "ConfirmationDetails"
	_confirmation_message.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0035")
	_confirmation_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirmation_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_confirmation_message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	layout.add_child(buttons)
	_cancel_new_run_button = Button.new()
	_cancel_new_run_button.name = "CancelNewRunButton"
	_cancel_new_run_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0036")
	_cancel_new_run_button.custom_minimum_size = Vector2(200.0, 44.0)
	_cancel_new_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_new_run_button.pressed.connect(_close_new_run_confirmation.bind(true))
	ForbiddenThemeScript.style_button(_cancel_new_run_button)
	buttons.add_child(_cancel_new_run_button)
	_confirm_new_run_button = Button.new()
	_confirm_new_run_button.name = "ConfirmNewRunButton"
	_confirm_new_run_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0019")
	_confirm_new_run_button.custom_minimum_size = Vector2(200.0, 44.0)
	_confirm_new_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_new_run_button.pressed.connect(_confirm_pending_new_run)
	ForbiddenThemeScript.style_button(_confirm_new_run_button, true)
	buttons.add_child(_confirm_new_run_button)


func _connect_presentation_preferences() -> void:
	var preferences = _preferences_service()
	if preferences != null and not preferences.is_connected("preferences_changed", Callable(self, "_on_preferences_changed")):
		preferences.connect("preferences_changed", Callable(self, "_on_preferences_changed"))
	_apply_presentation_preferences(_applied_preferences, false)


func _on_preferences_changed(preferences: Dictionary) -> void:
	_apply_presentation_preferences(preferences, true)


func _on_preferences_applied(preferences: Dictionary) -> void:
	if preferences == _applied_preferences:
		# The overlay can apply tutorial-only changes without emitting
		# preferences_changed. Refresh that prompt after it mutates progress, while
		# avoiding a second full journey rebuild for the same settings apply.
		_refresh_tutorial_presentation()
		return
	_apply_presentation_preferences(preferences, true)


func _refresh_tutorial_presentation() -> void:
	if controller == null or _tutorial_prompt == null:
		return
	var phase := str(controller.domain.state.phase)
	_render_tutorial(phase)
	if _run_status_panel != null:
		if phase == RunPhaseScript.BATTLE:
			_run_status_panel.visible = _tutorial_prompt.visible
			_run_status_panel.custom_minimum_size.y = (34.0 if _tutorial_prompt.visible else 0.0) * float(_applied_preferences.get("ui_scale", 1.0))
			var overview_scroll := _run_status_panel.find_child("RunOverviewScroll", true, false) as ScrollContainer
			if overview_scroll != null:
				overview_scroll.custom_minimum_size.y = 24.0 * float(_applied_preferences.get("ui_scale", 1.0))
		else:
			_run_status_panel.visible = true
			_run_status_panel.custom_minimum_size.y = (58.0 if _tutorial_prompt.visible else 54.0) * float(_applied_preferences.get("ui_scale", 1.0))


func _apply_presentation_preferences(preferences: Dictionary, refresh_cached_descriptors: bool) -> void:
	var locale := "zh_CN" if str(preferences.get("locale", "en")).to_lower().begins_with("zh") else "en"
	var normalized := preferences.duplicate(true)
	normalized["locale"] = locale
	_applied_preferences = normalized
	TranslationServer.set_locale(locale)
	var scale := float(normalized.get("ui_scale", 1.0))
	theme = ForbiddenThemeScript.create_theme(locale, scale)
	if _table_backdrop != null:
		_table_backdrop.call("configure", str(normalized.get("presentation_mode", "NORMAL")), bool(normalized.get("reduced_motion", false)), bool(normalized.get("ambient_glow", true)))
	if _journey_view != null:
		_journey_view.set_presentation_preferences(locale, scale, str(normalized.get("presentation_mode", "NORMAL")), bool(normalized.get("reduced_motion", false)))
	if _battle_view != null and _battle_view.has_method("set_presentation_preferences"):
		_battle_view.call("set_presentation_preferences", locale, scale, str(normalized.get("presentation_mode", "NORMAL")), bool(normalized.get("reduced_motion", false)), bool(normalized.get("ambient_glow", true)))
	_refresh_static_labels()
	if controller != null:
		_suppress_controller_render = true
		if str(controller.snapshot().get("presentation_mode", "NORMAL")) != str(normalized.get("presentation_mode", "NORMAL")):
			controller.set_mode(str(normalized.get("presentation_mode", "NORMAL")))
		if refresh_cached_descriptors:
			# Rebuild only presentation descriptors; the Run Domain, checkpoint and replay bytes are unchanged.
			controller.refresh_localized_presentation()
		_suppress_controller_render = false
	_render()


func _refresh_static_labels() -> void:
	if not _meta_progress_warning_parts.is_empty():
		_meta_progress_load_warning = _message_parts_text(_meta_progress_warning_parts)
		if _profile_status != null:
			_set_wrapped_label_text(_profile_status, _meta_progress_load_warning)
	if _settings_button != null:
		_settings_button.text = LocalizationCatalogScript.text("UI_PREFS_TAB_SETTINGS")
	if _back_button != null:
		_back_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0014")
	if _cancel_new_run_button != null:
		_cancel_new_run_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0036")
	if _confirm_new_run_button != null:
		_confirm_new_run_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0019")
	if _confirmation_message != null:
		_confirmation_message.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0035")
	if _tutorial_reset_button != null:
		_tutorial_reset_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0039")
	if _new_run_button != null:
		_new_run_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0040")
	if _reset_profile_button != null:
		_reset_profile_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0041")
		_reset_profile_button.tooltip_text = LocalizationCatalogScript.text("UI_RUN_SCENE_0042")
		_reset_profile_button.disabled = _profile_reset_unavailable()
	if _page != null:
		var title := _page.find_child("GameTitle", true, false) as Label
		if title != null:
			title.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0038")
			ForbiddenThemeScript.title(title, str(_applied_preferences.get("locale", "en")))
	_refresh_suspend_presentation()
	_refresh_action_rail()


func _refresh_profile_recovery_presentation() -> void:
	if _profile_status == null:
		return
	_set_wrapped_label_text(_profile_status, _meta_progress_load_warning)
	_profile_status.visible = not _meta_progress_load_warning.is_empty()
	var has_details := not _profile_technical_details.is_empty()
	if _profile_details_button != null:
		_profile_details_button.visible = has_details
		_profile_details_button.text = LocalizationCatalogScript.text("UI_RUN_RECOVERY_DETAILS_HIDE" if _profile_details_expanded else "UI_RUN_RECOVERY_DETAILS_SHOW")
	if _profile_details_value != null:
		var codes: Array = _profile_technical_details.get("codes", [])
		var recovery_path := str(_profile_technical_details.get("recovery_path", ""))
		var details_text := LocalizationCatalogScript.format("UI_PROFILE_RECOVERY_DETAILS_BODY", [
			str(_profile_technical_details.get("profile_path", "")),
			recovery_path,
			", ".join(PackedStringArray(codes)),
		]) if has_details else ""
		if has_details and bool(_profile_technical_details.get("manual_recovery_required", false)):
			details_text += "\n\n" + LocalizationCatalogScript.text("UI_PROFILE_MANUAL_RECOVERY_STEPS")
		_profile_details_value.text = details_text
		_profile_details_value.visible = has_details and _profile_details_expanded
	if _profile_details_scroll != null:
		_profile_details_scroll.visible = has_details and _profile_details_expanded
		_profile_details_scroll.custom_minimum_size.y = 72.0 * float(_applied_preferences.get("ui_scale", 1.0)) if _profile_details_scroll.visible else 0.0
	if _profile_recovery_scroll != null:
		_profile_recovery_scroll.visible = _profile_status.visible or has_details
		var viewport_height := get_viewport_rect().size.y if is_inside_tree() else 540.0
		var recovery_budget := minf(190.0, viewport_height * 0.35)
		_profile_recovery_scroll.custom_minimum_size.y = minf(_profile_recovery_content.get_combined_minimum_size().y, recovery_budget) if _profile_recovery_scroll.visible else 0.0


func _on_profile_details_pressed() -> void:
	_profile_details_expanded = not _profile_details_expanded
	_refresh_profile_recovery_presentation()


func _profile_reset_unavailable() -> bool:
	return meta_progress_coordinator != null and meta_progress_coordinator.recovery_required and str(meta_progress_coordinator.last_rejected_profile_path).is_empty()


func _on_settings_pressed() -> void:
	var preferences_service = _preferences_service()
	if _preferences_overlay == null or preferences_service == null:
		return
	var preferences: Dictionary = preferences_service.call("snapshot")
	_preferences_overlay.call("open", preferences, _settings_button, controller.tutorial_progress if controller != null else null)


func _preferences_service():
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null or scene_tree.root == null:
		return null
	return scene_tree.root.get_node_or_null("PresentationPrefs")


func _open_new_run_confirmation(from_suspend: bool) -> void:
	_new_run_from_suspend_pending = from_suspend
	_new_run_confirmation_origin = _new_run_from_suspend_button if from_suspend else _new_run_button
	_confirmation_overlay.visible = true
	_confirmation_message.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0035")
	_grab_focus_if_available(_cancel_new_run_button)


func _close_new_run_confirmation(restore_focus: bool = false) -> void:
	if _confirmation_overlay == null or not _confirmation_overlay.visible:
		return
	_confirmation_overlay.visible = false
	_new_run_from_suspend_pending = false
	if restore_focus and is_instance_valid(_new_run_confirmation_origin) and _new_run_confirmation_origin.is_visible_in_tree():
		_grab_focus_if_available(_new_run_confirmation_origin)
	_new_run_confirmation_origin = null


func _confirm_pending_new_run() -> void:
	if _confirmation_overlay == null or not _confirmation_overlay.visible:
		return
	var from_suspend := _new_run_from_suspend_pending
	_close_new_run_confirmation(false)
	if from_suspend:
		_perform_new_run_from_suspend()
	else:
		_perform_terminal_new_run()

func _render() -> void:
	var viewport := get_viewport()
	var focused_control: Control = viewport.gui_get_focus_owner() as Control if viewport != null else null
	var prior_focus_name: String = focused_control.name if focused_control != null else ""
	var prior_action_id := str(focused_control.get_meta("run_action_id", "")) if focused_control != null else ""
	var prior_commit_focus := focused_control == _commit_selected_button
	if controller == null:
		_last_rendered_phase = ""
		if _phase_value != null:
			_phase_value.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0054")
		_refresh_profile_recovery_presentation()
		if _reset_profile_button != null:
			_reset_profile_button.visible = meta_progress_coordinator.recovery_required
			_reset_profile_button.disabled = _profile_reset_unavailable()
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
		if _run_status_panel != null:
			_run_status_panel.visible = false
		if _journey_view != null:
			_journey_view.visible = false
		if _battle_view != null:
			_battle_view.visible = false
		if _new_run_button != null:
			_new_run_button.disabled = true
		if _feedback_value != null:
			_set_wrapped_label_text(_feedback_value, _startup_error)
		_refresh_action_rail()
		return
	_suspend_choice_panel.visible = false
	_run_status_panel.visible = true
	var state = controller.domain.state
	var phase := str(state.phase)
	var phase_changed := phase != _last_rendered_phase
	_phase_value.text = LocalizationCatalogScript.template("UI_RUN_SCENE_0055") % [state.act_index, state.act_count, _pretty_words(phase)]
	_set_wrapped_label_text(_run_value, LocalizationCatalogScript.format("UI_RUN_JOURNEY_RESOURCES", [
		state.gold,
		state.refinement_tokens,
		_pretty_id(state.character_id),
		_pretty_id(state.contract_id),
	]))
	_set_wrapped_label_text(_battle_value, _battle_summary())
	_set_wrapped_label_text(_hand_value, _hand_summary())
	_set_wrapped_label_text(_help_value, _help_text(phase))
	_run_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_run_value.visible = phase != RunPhaseScript.BATTLE
	_battle_value.visible = false
	_hand_value.visible = false
	_help_value.visible = phase != RunPhaseScript.BATTLE
	_render_tutorial(phase)
	if phase == RunPhaseScript.BATTLE:
		_run_status_panel.visible = _tutorial_prompt.visible
		_run_status_panel.custom_minimum_size.y = (34.0 if _tutorial_prompt.visible else 0.0) * float(_applied_preferences.get("ui_scale", 1.0))
		_overview_scroll.custom_minimum_size.y = 24.0 * float(_applied_preferences.get("ui_scale", 1.0))
	else:
		_run_status_panel.visible = true
		_run_status_panel.custom_minimum_size.y = (58.0 if _tutorial_prompt.visible else 54.0) * float(_applied_preferences.get("ui_scale", 1.0))
		_overview_scroll.custom_minimum_size.y = 42.0 * float(_applied_preferences.get("ui_scale", 1.0))
	_set_wrapped_label_text(_feedback_value, str(controller.snapshot().get("feedback", "")))
	_refresh_profile_recovery_presentation()
	_reset_profile_button.visible = meta_progress_coordinator.recovery_required
	_reset_profile_button.disabled = _profile_reset_unavailable()
	var showing_summary := phase in [RunPhaseScript.RUN_SUMMARY, RunPhaseScript.RUN_COMPLETE]
	_run_columns.visible = not showing_summary
	_summary_panel.visible = showing_summary
	var summary_clock_anchor := _summary_clock_anchor(state) if phase in [RunPhaseScript.RUN_SUMMARY, RunPhaseScript.RUN_COMPLETE] else -1
	_summary_view.render(state, RunSummaryPresenterScript.format(state, summary_clock_anchor), str(_applied_preferences.get("locale", "en")), float(_applied_preferences.get("ui_scale", 1.0)))
	_summary_acknowledge_button.visible = false
	_new_run_button.disabled = phase != RunPhaseScript.RUN_COMPLETE
	_new_run_button.visible = phase == RunPhaseScript.RUN_COMPLETE
	_render_actions()
	_refresh_action_rail()
	if viewport != null and not _preferences_overlay.visible and not _confirmation_overlay.visible:
		if phase_changed and phase == RunPhaseScript.BATTLE:
			_focus_initial_battle_control()
		elif phase_changed and phase == RunPhaseScript.RUN_SUMMARY and not _commit_selected_button.disabled and _commit_selected_button.visible:
			_grab_focus_if_available(_commit_selected_button)
		elif phase_changed and phase == RunPhaseScript.RUN_COMPLETE and not _new_run_button.disabled and _new_run_button.visible:
			_grab_focus_if_available(_new_run_button)
		elif phase_changed and _journey_view.visible:
			_focus_initial_journey_choice()
		elif prior_commit_focus and not _commit_selected_button.disabled and _commit_selected_button.visible:
			_grab_focus_if_available(_commit_selected_button)
		elif not prior_action_id.is_empty() and _journey_view.visible:
			var same_choice: Button = _journey_view.action_button(prior_action_id)
			if same_choice != null and not same_choice.disabled:
				_grab_focus_if_available(same_choice)
		elif prior_focus_name == "SettingsButton" and _settings_button.visible:
			_grab_focus_if_available(_settings_button)
		elif phase == RunPhaseScript.RUN_SUMMARY and not _commit_selected_button.disabled:
			_grab_focus_if_available(_commit_selected_button)
		elif phase == RunPhaseScript.RUN_COMPLETE and not _new_run_button.disabled:
			_grab_focus_if_available(_new_run_button)
		elif _journey_view.visible and _journey_view.get("focused_action_id") != "":
			var focused_choice: Button = _journey_view.action_button(str(_journey_view.get("focused_action_id")))
			if focused_choice != null and focused_choice.is_inside_tree():
				_grab_focus_if_available(focused_choice)
		_restore_focus_after_render(phase)
	_last_rendered_phase = phase


func _summary_clock_anchor(run_state) -> int:
	if run_state == null or run_state.terminal_summary == null:
		return -1
	var summary_identity := "%s:%s" % [str(run_state.run_id), JSON.stringify(run_state.terminal_summary.to_dictionary())]
	if summary_identity != _summary_duration_identity:
		_summary_duration_identity = summary_identity
		_summary_duration_anchor_unix_seconds = int(Time.get_unix_time_from_system())
	return _summary_duration_anchor_unix_seconds


func _restore_focus_after_render(phase: String) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var focus_owner := viewport.gui_get_focus_owner() as Control
	if phase == RunPhaseScript.BATTLE and _battle_view != null and _battle_view.visible:
		if focus_owner == null or not focus_owner.is_visible_in_tree() or not _battle_view.is_ancestor_of(focus_owner):
			_focus_initial_battle_control()
		return
	if _journey_view == null or not _journey_view.visible:
		return
	if focus_owner == null or not focus_owner.is_visible_in_tree() or (focus_owner is BaseButton and (focus_owner as BaseButton).disabled):
		_focus_initial_journey_choice()


func _focus_initial_journey_choice() -> void:
	if controller == null or _journey_view == null or not _journey_view.visible:
		return
	var action_id := str(_journey_view.get("focused_action_id"))
	var button: Button = _journey_view.action_button(action_id)
	if button == null or button.disabled or not button.is_visible_in_tree():
		for action in controller.action_descriptors():
			button = _journey_view.action_button(str(action.get("id", "")))
			if button != null and not button.disabled and button.is_visible_in_tree():
				break
	if button != null and not button.disabled:
		_grab_focus_if_available(button)

func _render_actions() -> void:
	if controller == null:
		return
	var descriptors: Array = controller.action_descriptors()
	var phase := str(controller.domain.state.phase)
	var effective_mode := str(controller.snapshot().get("presentation_mode", _applied_preferences.get("presentation_mode", "NORMAL")))
	if phase == RunPhaseScript.BATTLE and _ensure_battle_view():
		_journey_view.visible = false
		_battle_view.visible = true
		if str(_battle_view.get("_locale")) != str(_applied_preferences.get("locale", "en")) or float(_battle_view.get("_ui_scale")) != float(_applied_preferences.get("ui_scale", 1.0)) or str(_battle_view.get("_presentation_mode")) != effective_mode or bool(_battle_view.get("_reduced_motion")) != bool(_applied_preferences.get("reduced_motion", false)) or bool(_battle_view.get("_ambient_glow")) != bool(_applied_preferences.get("ambient_glow", true)):
			_battle_view.set_presentation_preferences(str(_applied_preferences.get("locale", "en")), float(_applied_preferences.get("ui_scale", 1.0)), effective_mode, bool(_applied_preferences.get("reduced_motion", false)), bool(_applied_preferences.get("ambient_glow", true)))
		_battle_view.render()
		_back_button.visible = false
		_commit_selected_button.visible = false
		return
	if _battle_view != null:
		_battle_view.visible = false
		if _battle_view.has_method("sync_persistent_receipt"):
			_battle_view.call("sync_persistent_receipt")
	_journey_view.visible = true
	_back_button.visible = true
	_commit_selected_button.visible = true
	if str(_journey_view.get("_locale")) != str(_applied_preferences.get("locale", "en")) or float(_journey_view.get("_ui_scale")) != float(_applied_preferences.get("ui_scale", 1.0)) or str(_journey_view.get("_presentation_mode")) != effective_mode or bool(_journey_view.get("_reduced_motion")) != bool(_applied_preferences.get("reduced_motion", false)):
		_journey_view.set_presentation_preferences(str(_applied_preferences.get("locale", "en")), float(_applied_preferences.get("ui_scale", 1.0)), effective_mode, bool(_applied_preferences.get("reduced_motion", false)))
	var preferred_focus := str(_journey_view.get("focused_action_id"))
	_journey_view.render(controller, descriptors, preferred_focus)
	_action_details_value = _journey_view.details_label()
	if phase in [RunPhaseScript.REWARD_CHOICE, RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD, RunPhaseScript.RUN_SUMMARY, RunPhaseScript.RUN_COMPLETE] and _battle_view != null and _battle_view.has_method("persistent_receipt_text"):
		var receipt := str(_battle_view.call("persistent_receipt_text"))
		if not receipt.is_empty():
			var feedback := str(controller.snapshot().get("feedback", ""))
			var combined_feedback := receipt if feedback.is_empty() else "%s\n%s" % [feedback, receipt]
			_set_wrapped_label_text(_feedback_value, combined_feedback)


func _ensure_battle_view() -> bool:
	if _battle_view != null:
		if _battle_configured_controller != controller:
			_battle_view.configure(controller, Callable(self, "_action_label"), Callable(self, "_action_tooltip"), Callable(self, "_action_details_text"))
			_battle_configured_controller = controller
		return true
	if not FileAccess.file_exists(ProjectSettings.globalize_path(BattleViewPath)):
		return false
	var script = load(BattleViewPath)
	if script == null:
		return false
	_battle_view = script.new()
	_battle_view.name = "BattleView"
	_battle_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _battle_view.has_method("set_external_preferences_owner"):
		_battle_view.call("set_external_preferences_owner", true)
	_battle_view.configure(controller, Callable(self, "_action_label"), Callable(self, "_action_tooltip"), Callable(self, "_action_details_text"))
	_battle_configured_controller = controller
	_battle_view.action_requested.connect(_on_battle_action_requested)
	_battle_view.focus_requested.connect(_on_battle_focus_requested)
	_battle_view.set_presentation_preferences(str(_applied_preferences.get("locale", "en")), float(_applied_preferences.get("ui_scale", 1.0)), str(_applied_preferences.get("presentation_mode", "NORMAL")), bool(_applied_preferences.get("reduced_motion", false)), bool(_applied_preferences.get("ambient_glow", true)))
	_journey_host.add_child(_battle_view)
	return true


func _on_battle_action_requested(action_id: String) -> void:
	if controller == null:
		return
	controller.confirm(action_id)


func _on_battle_focus_requested(action_id: String) -> void:
	_battle_focus_action_id = action_id
	_sync_presentation_focus(action_id)
	if _action_details_value != null and controller != null:
		for action in controller.action_descriptors():
			if str(action.get("id", "")) == action_id:
				_action_details_value.text = _action_details_text(action)
				return


func _refresh_action_rail() -> void:
	if _commit_selected_button == null or _back_button == null:
		return
	var action_id := ""
	var action: Dictionary = {}
	var is_confirming := _journey_view != null and bool(_journey_view.get("is_confirmation_open"))
	if is_confirming:
		action_id = str(_journey_view.confirmation_action_id())
		action = _journey_view.selected_action()
		_commit_selected_button.text = _journey_view.confirmation_commit_label()
	elif controller != null and str(controller.domain.state.phase) == RunPhaseScript.RUN_SUMMARY:
		for candidate in controller.action_descriptors():
			if str(candidate.get("kind", "")) == "RUN_SUMMARY":
				action = candidate
				action_id = str(candidate.get("id", ""))
				break
		_commit_selected_button.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0053")
	else:
		if _journey_view != null:
			action = _journey_view.selected_action()
			action_id = str(action.get("id", ""))
		var kind := str(action.get("kind", ""))
		if kind == "SHOP_OFFER":
			_commit_selected_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0038")
		elif kind == "WORKSHOP_SERVICE":
			_commit_selected_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0039")
		else:
			_commit_selected_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0037")
	_commit_selected_button.set_meta("run_commit_action_id", action_id)
	_commit_selected_button.tooltip_text = _action_tooltip(action) if not action.is_empty() else LocalizationCatalogScript.text("UI_RUN_JOURNEY_0013")
	_commit_selected_button.disabled = action_id.is_empty() or controller == null
	_back_button.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0015") if is_confirming else LocalizationCatalogScript.text("UI_RUN_JOURNEY_0014")
	_back_button.disabled = controller == null
	var in_battle := controller != null and str(controller.domain.state.phase) == RunPhaseScript.BATTLE
	_back_button.visible = not in_battle
	_commit_selected_button.visible = not in_battle
	if _feedback_value != null:
		_feedback_value.visible = not _feedback_value.text.is_empty()


func _on_journey_selection_changed(action_id: String) -> void:
	_refresh_action_rail()


func _on_journey_focus_changed(action_id: String) -> void:
	_battle_focus_action_id = action_id
	_sync_presentation_focus(action_id)


func _on_journey_confirmation_changed(_opened: bool) -> void:
	_refresh_action_rail()


func _on_journey_action_committed(action_id: String) -> void:
	if controller == null:
		return
	var result = controller.confirm(action_id)
	if result != null and result.accepted:
		_journey_view.clear_committed_selection()


func _sync_presentation_focus(action_id: String) -> void:
	if controller == null or action_id.is_empty():
		return
	var focused_index: int = controller.state.focus_action_ids.find(action_id)
	if focused_index >= 0:
		controller.state.focused_index = focused_index


func _on_commit_selected_pressed() -> void:
	if _confirmation_overlay != null and _confirmation_overlay.visible:
		_confirm_pending_new_run()
		return
	if controller == null:
		return
	if str(controller.domain.state.phase) in [RunPhaseScript.RUN_SUMMARY, RunPhaseScript.RUN_COMPLETE]:
		var action_id := str(_commit_selected_button.get_meta("run_commit_action_id", ""))
		if not action_id.is_empty():
			_on_action_pressed(action_id)
		return
	if _journey_view != null and _journey_view.visible:
		_journey_view.commit_selected()


func _on_back_pressed() -> void:
	if _confirmation_overlay != null and _confirmation_overlay.visible:
		_close_new_run_confirmation(true)
		return
	if _journey_view != null and _journey_view.visible and _journey_view.cancel_local_state():
		_refresh_action_rail()
		return
	if _battle_view != null and _battle_view.visible and _battle_view.has_method("cancel") and _battle_view.cancel():
		return
	if controller != null:
		controller.back()

func _on_action_focus_entered(action_id: String) -> void:
	if controller == null or _action_details_value == null:
		return
	for action in controller.action_descriptors():
		if str(action.get("id", "")) == action_id:
			_set_wrapped_label_text(_action_details_value, _action_details_text(action))
			var viewport := get_viewport()
			var focused_button := viewport.gui_get_focus_owner() as Button if viewport != null else null
			_action_details_value.visible = not _action_details_value.text.is_empty() and focused_button != null and _action_details_value.text != focused_button.text
			return


func _focus_initial_battle_control() -> void:
	if controller == null or _battle_view == null or not _battle_view.visible or not _battle_view.has_method("action_button"):
		return
	var action_id := str(_battle_view.get("focused_action_id"))
	var button := _battle_view.call("action_button", action_id) as Button
	if button == null or button.disabled or not button.is_visible_in_tree():
		for action in controller.action_descriptors():
			button = _battle_view.call("action_button", str(action.get("id", ""))) as Button
			if button != null and not button.disabled and button.is_visible_in_tree():
				break
	if button != null and not button.disabled:
		_grab_focus_if_available(button)


func _on_action_pressed(action_id: String):
	var result = controller.confirm(action_id)
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
	_open_new_run_confirmation(false)


func _perform_terminal_new_run() -> void:
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
	if controller != null and controller.presentation_changed.is_connected(_on_controller_presentation_changed):
		controller.presentation_changed.disconnect(_on_controller_presentation_changed)
	controller = null
	_content_registry = registry_result.registry
	_start_new_run(_content_registry)
	_render()

func _on_reset_profile_pressed() -> void:
	if _profile_reset_unavailable():
		return
	var result: Dictionary = meta_progress_coordinator.reset_profile()
	if result.get("accepted", false):
		_meta_progress_warning_parts = [_localized_message_part("UI_PROFILE_RESET_PRESERVED")]
		_profile_technical_details["recovery_path"] = str(result.get("preserved_path", _profile_technical_details.get("recovery_path", "")))
	else:
		_meta_progress_warning_parts = [_localized_message_part("UI_PROFILE_RESET_FAILED")]
		var codes: Array = _profile_technical_details.get("codes", [])
		var reset_code := str(result.get("code", "RESET_FAILED"))
		if not codes.has(reset_code):
			codes.append(reset_code)
		_profile_technical_details["codes"] = codes
	_meta_progress_load_warning = _message_parts_text(_meta_progress_warning_parts)
	_refresh_profile_recovery_presentation()
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
		intent_text = LocalizationCatalogScript.template("UI_RUN_SCENE_0074") % [LocalizationCatalogScript.display_text(str(intent.display_name)), intent.pressure_amount]
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
		return _action_label(action)
	var service_id := str(action.get("service_id", action.get("target_id", "")))
	var tile_definition_id := str(details.get("tile_definition_id", ""))
	var lines := PackedStringArray()
	lines.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0133") % _pretty_tile_id(tile_definition_id))
	match service_id:
		"TRANSFORM":
			var value_id := str(action.get("value_id", ""))
			lines.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0134") % _pretty_tile_id(value_id))
		"ADD_MODIFIER":
			lines.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0135") % _pretty_id(str(action.get("modifier_id", ""))))
		"REPLACE_MODIFIER":
			var existing_modifier_labels := PackedStringArray()
			var existing_modifier_ids: Variant = details.get("existing_modifier_ids", [])
			if existing_modifier_ids is Array:
				for modifier_id in existing_modifier_ids:
					existing_modifier_labels.append(_pretty_id(str(modifier_id)))
			lines.append(LocalizationCatalogScript.template("UI_RUN_SCENE_0136") % [", ".join(existing_modifier_labels), _pretty_id(str(action.get("modifier_id", "")))])
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
		if str(TranslationServer.translate(identifier)) != identifier:
			return LocalizationCatalogScript.content_text(identifier)
		return _pretty_words(identifier.get_slice(".", identifier.get_slice_count(".") - 1))
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
