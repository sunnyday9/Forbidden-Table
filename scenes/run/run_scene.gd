extends Control

const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
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
var _feedback_value: Label
var _profile_status: Label
var _reset_profile_button: Button
var _new_run_button: Button
var _suspend_choice_panel: VBoxContainer
var _suspend_status: Label
var _resume_run_button: Button
var _new_run_from_suspend_button: Button
var _actions_column: VBoxContainer
var _run_columns: HBoxContainer
var _summary_panel: PanelContainer
var _summary_value: Label
var _summary_acknowledge_button: Button

func _ready() -> void:
	if suspend_store == null:
		suspend_store = SuspendSaveStoreScript.new(suspend_file_path)
	if meta_progress_coordinator == null:
		meta_progress_coordinator = MetaProgressCoordinatorScript.new()
	var meta_load: Dictionary = meta_progress_coordinator.load_profile()
	if not meta_load.get("accepted", false):
		var recovery_path := str(meta_load.get("preserved_path", ""))
		var preservation_text := "A recovery copy is at %s." % recovery_path if not recovery_path.is_empty() else "The original save remains in place."
		_meta_progress_load_warning = "Saved unlock profile could not be loaded (%s). %s Progression writes are disabled until you reset the profile." % [str(meta_load.get("code", "LOAD_FAILED")), preservation_text]
	_build_interface()
	var registry_result := _validated_content_registry()
	if not registry_result.get("accepted", false):
		_startup_error = str(registry_result.get("message", "A new run could not start because game content failed validation."))
	else:
		_content_registry = registry_result.registry
		_load_suspend_or_start_new(_content_registry)
	_render()

func _validated_content_registry() -> Dictionary:
	var registry = ContentRegistryScript.new()
	if content_registry_factory.is_valid():
		registry = content_registry_factory.call()
	if not registry is ContentRegistryScript:
		return {"accepted": false, "message": "A new run could not start because its content registry is unavailable."}
	var registration_reports: Array = [
		{"catalog": "Phase 2", "report": Phase2CatalogScript.register_all(registry)},
		{"catalog": "Act Two", "report": AlphaActTwoCatalogScript.register_all(registry)},
		{"catalog": "Alpha Scale", "report": AlphaScaleCatalogScript.register_all(registry)},
	]
	var validation_errors: Array[String] = []
	for registration in registration_reports:
		_append_content_validation_errors(
			validation_errors,
			"%s catalog registration" % str(registration.get("catalog", "Catalog")),
			registration.get("report"),
		)
	_append_content_validation_errors(validation_errors, "Content registry validation", registry.validate())
	if not validation_errors.is_empty():
		return {"accepted": false, "message": "A new run could not start because game content failed validation. Please report this issue:\n%s" % "\n".join(validation_errors)}
	return {"accepted": true, "registry": registry}

func _load_suspend_or_start_new(registry) -> void:
	var stored: Dictionary = suspend_store.read_source()
	if not stored.get("accepted", false):
		if stored.get("preserve_required", false):
			var interrupted_preservation: Dictionary = suspend_store.preserve_source()
			if interrupted_preservation.get("accepted", false):
				_suspend_rejected_copy_path = str(interrupted_preservation.get("path", ""))
				_show_suspend_recovery_required(
					"The Suspend Save commit was interrupted (%s). No older save was loaded. Recovery sources remain unchanged and are copied to %s. Choose New Run only if you want to leave this save behind." % [str(stored.get("code", "SUSPEND_COMMIT_INTERRUPTED")), _suspend_rejected_copy_path],
					true,
				)
			else:
				_show_suspend_recovery_required(
					"The Suspend Save commit was interrupted (%s), and a recovery copy failed (%s). No older save was loaded. Copy the files manually before starting over." % [str(stored.get("code", "SUSPEND_COMMIT_INTERRUPTED")), str(interrupted_preservation.get("code", "SUSPEND_PRESERVE_FAILED"))],
					false,
				)
			return
		_show_suspend_recovery_required(
			"The saved Run could not be read (%s). The source has not been changed. Check the save file permissions or move the file before trying again." % str(stored.get("code", "SUSPEND_READ_FAILED")),
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
				"%s The original save remains unchanged, and a byte-for-byte recovery copy is at %s. Choose New Run only if you want to leave this save behind." % [explanation, _suspend_rejected_copy_path],
				true,
			)
		else:
			_show_suspend_recovery_required(
				"%s The original save remains unchanged, but its recovery copy failed (%s). Copy the file manually before starting over." % [_suspend_load_error(loaded), str(preservation.get("code", "SUSPEND_PRESERVE_FAILED"))],
				false,
			)
		return
	var saved_domain = loaded.domain
	var finalized: Dictionary = suspend_store.finalize_load(stored, str(saved_domain.state.run_id))
	if not finalized.get("accepted", false):
		var preservation: Dictionary = suspend_store.preserve_source()
		var recovery_path := str(preservation.get("path", "")) if preservation.get("accepted", false) else ""
		var suffix := " A recovery copy is at %s." % recovery_path if not recovery_path.is_empty() else " Copy the files manually before starting over."
		_show_suspend_recovery_required(
			"The saved Run was valid, but interrupted-save recovery could not be finalized (%s). The original sources were retained.%s" % [str(finalized.get("code", "SUSPEND_RECOVERY_FAILED")), suffix],
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
			var prefix := "The previous Run is complete, but progression could not be saved (%s). Resume to view it; its save stays available so launch can retry." % str(cleared.get("code", "META_PROGRESS_SAVE_FAILED")) if progression_pending else "The previous Run is complete, but its save slot could not be cleared (%s). Resume to view the result or choose New Run to retry clearing it." % str(cleared.get("code", "SUSPEND_CLEAR_FAILED"))
			_show_valid_suspend_choice(saved_domain, prefix, not progression_pending, str(loaded.snapshot.checkpoint_metadata.get("stable_boundary", "")))
		return
	_pending_resume_domain = saved_domain
	var cleanup_prefix := ""
	if finalized.has("cleanup_warning"):
		cleanup_prefix = "The saved Run loaded, but interrupted-save cleanup needs attention (%s)." % str(finalized.get("cleanup_warning"))
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
			return "This saved Run uses an unsupported content version."
		if code == "UNSUPPORTED_GAME_VERSION":
			return "This saved Run uses an unsupported game version."
	return "The saved Run could not be loaded (%s)." % str(loaded.get("code", "SUSPEND_LOAD_FAILED"))

func _show_valid_suspend_choice(saved_domain, prefix: String = "", can_start_new: bool = true, saved_boundary: String = "") -> void:
	var checkpoint: Dictionary = saved_domain.checkpoint()
	var message := "A saved Run is ready to continue. Run: %s. Resume restores its saved state and RNG; New Run discards this one continuation save." % str(saved_domain.state.run_id)
	var boundary := saved_boundary if not saved_boundary.is_empty() else str(checkpoint.get("stable_boundary", ""))
	if not boundary.is_empty():
		message += " Saved boundary: %s." % _pretty_words(boundary)
	if not prefix.is_empty():
		message = "%s\n%s" % [prefix, message]
	_show_suspend_choice(message, true, "New Run (discard saved Run)", can_start_new)

func _show_suspend_recovery_required(message: String, can_start_new: bool) -> void:
	_show_suspend_choice(message, false, "Start New Run (keep rejected save)", can_start_new)

func _show_suspend_choice(message: String, can_resume: bool, new_run_label: String, can_start_new: bool) -> void:
	_suspend_choice_panel.visible = true
	_suspend_status.text = message
	_resume_run_button.visible = can_resume
	_resume_run_button.disabled = not can_resume
	_new_run_from_suspend_button.text = new_run_label
	_new_run_from_suspend_button.visible = true
	_new_run_from_suspend_button.disabled = not can_start_new
	_run_columns.visible = false
	_summary_panel.visible = false
	_new_run_button.disabled = true

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
			_suspend_status.text = "Progression is still not saved (%s). The completed Run remains in its Suspend Save so you can retry on the next launch." % str(unlock_retry.get("code", "META_PROGRESS_SAVE_FAILED"))
			_pending_resume_domain = resumed_domain
			return
		var clear_result: Dictionary = suspend_store.clear()
		if not clear_result.get("accepted", false):
			_suspend_status.text = "The completed Run could not be cleared (%s). Its save remains available." % str(clear_result.get("code", "SUSPEND_CLEAR_FAILED"))
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
		_suspend_status.text += "\nThe saved Run could not be cleared (%s). No new Run was started; retry after checking file permissions." % str(cleared.get("code", "SUSPEND_CLEAR_FAILED"))
		return
	_pending_resume_domain = null
	_suspend_rejected_copy_path = ""
	_suspend_choice_panel.visible = false
	_start_new_run(_content_registry)
	_render()

func _append_content_validation_errors(errors: Array[String], source: String, report) -> void:
	if report == null or not report.has_method("is_valid") or not report.has_method("get"):
		errors.append("%s did not return a validation report." % source)
		return
	if report.is_valid():
		return
	var issues: Variant = report.get("issues")
	if not issues is Array or issues.is_empty():
		errors.append("%s failed without diagnostic details." % source)
		return
	for issue in issues:
		if issue == null or not issue.has_method("get"):
			errors.append("%s returned an invalid diagnostic." % source)
			continue
		var code := str(issue.get("code"))
		var content_id := str(issue.get("content_id"))
		var reference_id := str(issue.get("reference_id"))
		var message := str(issue.get("message"))
		var location := content_id
		if not reference_id.is_empty():
			location += " -> %s" % reference_id
		errors.append("%s [%s] %s: %s" % [source, code, location, message])

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
	title.text = "Forbidden Table — Alpha Run"
	title.add_theme_font_size_override("font_size", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_new_run_button = Button.new()
	_new_run_button.text = "New Run"
	_new_run_button.disabled = true
	_new_run_button.pressed.connect(_on_new_run_pressed)
	header.add_child(_new_run_button)

	_phase_value = Label.new()
	_phase_value.add_theme_font_size_override("font_size", 17)
	page.add_child(_phase_value)
	_profile_status = Label.new()
	_profile_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_status.text = _meta_progress_load_warning
	_profile_status.visible = not _meta_progress_load_warning.is_empty()
	page.add_child(_profile_status)
	_reset_profile_button = Button.new()
	_reset_profile_button.text = "Reset progression profile"
	_reset_profile_button.tooltip_text = "Archive the rejected save and create a fresh starter unlock profile."
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
	_suspend_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_suspend_choice_panel.add_child(_suspend_status)
	_resume_run_button = Button.new()
	_resume_run_button.name = "ResumeRunButton"
	_resume_run_button.text = "Resume Run"
	_resume_run_button.pressed.connect(_on_resume_run_pressed)
	_suspend_choice_panel.add_child(_resume_run_button)
	_new_run_from_suspend_button = Button.new()
	_new_run_from_suspend_button.name = "NewRunFromSuspendButton"
	_new_run_from_suspend_button.text = "Start New Run (keep rejected save)"
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
	var overview := VBoxContainer.new()
	overview.add_theme_constant_override("separation", 12)
	overview_panel.add_child(overview)
	_add_section_heading(overview, "Run state")
	_run_value = _add_wrapped_label(overview)
	_add_section_heading(overview, "Battle")
	_battle_value = _add_wrapped_label(overview)
	_add_section_heading(overview, "Hand and Reserve")
	_hand_value = _add_wrapped_label(overview)
	_help_value = _add_wrapped_label(overview)
	_help_value.modulate = Color(0.78, 0.82, 0.9)
	_help_value.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var actions_panel := PanelContainer.new()
	actions_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions_panel.size_flags_stretch_ratio = 1.0
	columns.add_child(actions_panel)
	var action_layout := VBoxContainer.new()
	action_layout.add_theme_constant_override("separation", 8)
	actions_panel.add_child(action_layout)
	_add_section_heading(action_layout, "Available actions")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	action_layout.add_child(scroll)
	_actions_column = VBoxContainer.new()
	_actions_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_column.add_theme_constant_override("separation", 7)
	scroll.add_child(_actions_column)

	_summary_panel = PanelContainer.new()
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
	_summary_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_scroll.add_child(_summary_value)
	_summary_acknowledge_button = Button.new()
	_summary_acknowledge_button.text = "Finish Run"
	_summary_acknowledge_button.pressed.connect(_on_action_pressed.bind("run.summary.acknowledge"))
	summary_layout.add_child(_summary_acknowledge_button)

	_feedback_value = Label.new()
	_feedback_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_feedback_value)

func _render() -> void:
	if controller == null:
		if _phase_value != null:
			_phase_value.text = "Run unavailable"
		if _profile_status != null:
			_profile_status.text = _meta_progress_load_warning
			_profile_status.visible = not _meta_progress_load_warning.is_empty()
		if _reset_profile_button != null:
			_reset_profile_button.visible = meta_progress_coordinator.recovery_required
		if _run_columns != null:
			_run_columns.visible = false
		if _summary_panel != null:
			_summary_panel.visible = false
		if _new_run_button != null:
			_new_run_button.disabled = true
		if _feedback_value != null:
			_feedback_value.text = _startup_error
		return
	_suspend_choice_panel.visible = false
	var state = controller.domain.state
	var phase := str(state.phase)
	_phase_value.text = "Act %d of %d   ·   %s" % [state.act_index, state.act_count, _pretty_words(phase)]
	_run_value.text = "Run: %s\nCharacter: %s\nContract: %s\nGold: %d     Refinement: %d\nCurrent map node: %s" % [
		state.run_id,
		_pretty_id(state.character_id),
		_pretty_id(state.contract_id),
		state.gold,
		state.refinement_tokens,
		_pretty_id(state.map_state.current_node_id),
	]
	_battle_value.text = _battle_summary()
	_hand_value.text = _hand_summary()
	_help_value.text = _help_text(phase)
	_feedback_value.text = controller.snapshot().get("feedback", "")
	_profile_status.text = _meta_progress_load_warning
	_profile_status.visible = not _meta_progress_load_warning.is_empty()
	_reset_profile_button.visible = meta_progress_coordinator.recovery_required
	var showing_summary := phase in [RunPhaseScript.RUN_SUMMARY, RunPhaseScript.RUN_COMPLETE]
	_run_columns.visible = not showing_summary
	_summary_panel.visible = showing_summary
	_summary_value.text = RunSummaryPresenterScript.format(state)
	_summary_acknowledge_button.visible = phase == RunPhaseScript.RUN_SUMMARY
	_new_run_button.disabled = phase != RunPhaseScript.RUN_COMPLETE
	_render_actions()

func _render_actions() -> void:
	for child in _actions_column.get_children():
		_actions_column.remove_child(child)
		child.queue_free()
	var descriptors: Array = controller.action_descriptors()
	if descriptors.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No actions are available in this state."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_actions_column.add_child(empty_label)
		return
	var focused_id := str(controller.snapshot().get("focused_action_id", ""))
	var focused_button: Button
	for action in descriptors:
		var action_id := str(action.get("id", ""))
		var button := Button.new()
		button.text = _action_label(action)
		button.tooltip_text = _action_tooltip(action)
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_action_pressed.bind(action_id))
		_actions_column.add_child(button)
		if focused_button == null or action_id == focused_id:
			focused_button = button
	if focused_button != null and focused_button.is_inside_tree() and not _reset_profile_button.has_focus():
		focused_button.grab_focus()

func _on_action_pressed(action_id: String):
	var result = controller.confirm(action_id)
	_render()
	return result

func _on_new_run_pressed() -> void:
	if controller == null or str(controller.domain.state.phase) != RunPhaseScript.RUN_COMPLETE:
		return
	var registry_result := _validated_content_registry()
	if not registry_result.get("accepted", false):
		_startup_error = str(registry_result.get("message", "A new run could not start because game content failed validation."))
		_render()
		return
	if controller != null and str(controller.domain.state.phase) == RunPhaseScript.RUN_COMPLETE:
		var unlock_retry: Dictionary = meta_progress_coordinator.observe_run_state(controller.domain.state)
		if unlock_retry.has("persisted") and not unlock_retry.get("persisted", false):
			controller.state.feedback = "Progression could not be saved (%s). The completed Run remains available; retry before starting another Run." % str(unlock_retry.get("code", "META_PROGRESS_SAVE_FAILED"))
			_render()
			return
	var cleared: Dictionary = suspend_store.clear()
	if not cleared.get("accepted", false):
		controller.state.feedback = "The previous Suspend Save could not be cleared (%s). No new Run was started; check file permissions and retry." % str(cleared.get("code", "SUSPEND_CLEAR_FAILED"))
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
		_meta_progress_load_warning = "Progression profile reset. The rejected save remains preserved at %s." % str(result.get("preserved_path", "the recovery copy"))
	else:
		_meta_progress_load_warning = "Progression profile reset failed (%s). Progression writes remain disabled." % str(result.get("code", "RESET_FAILED"))
	_render()

func _battle_summary() -> String:
	var battle = controller.domain.current_battle
	if battle == null:
		var summary = controller.domain.state.terminal_summary
		if controller.domain.state.phase in [RunPhaseScript.RUN_SUMMARY, RunPhaseScript.RUN_COMPLETE]:
			return "Run outcome: %s\nReason: %s" % [summary.outcome, summary.reason]
		return "No active battle. Use the available actions to advance the Run."
	var battle_state: Dictionary = battle.public_state()
	var intent = battle.combat_state.current_intent
	var intent_text := "None"
	if intent != null:
		intent_text = "%s (%d Pressure)" % [intent.display_name, intent.pressure_amount]
	var outcome := str(battle_state.get("terminal_outcome", "ONGOING"))
	var pattern_count: int = battle.settlement_window.candidates().size() if battle.settlement_window != null else 0
	return "%s\nEnemy HP: %d / %d\nEnemy intent: %s\nPressure: %d / %d\nTP: %d    Stability: %d\nPatterns available: %d    Outcome: %s" % [
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
		return "Run tile pool (%d): %s" % [run_tiles.size(), _join_strings(run_tiles)]
	var hand: Array = []
	var reserve: Array = []
	for tile in battle.zones.contents(TileZoneScript.HAND):
		hand.append(_pretty_tile_id(tile.definition_id))
	for tile in battle.zones.contents(TileZoneScript.RESERVE):
		reserve.append(_pretty_tile_id(tile.definition_id))
	return "Hand (%d): %s\nReserve (%d): %s" % [
		hand.size(), _join_strings(hand) if not hand.is_empty() else "Empty",
		reserve.size(), _join_strings(reserve) if not reserve.is_empty() else "Empty",
	]

func _action_label(action: Dictionary) -> String:
	var kind := str(action.get("kind", "ACTION"))
	var target := str(action.get("target_id", ""))
	var details: Dictionary = action.get("details", {}) if action.get("details", {}) is Dictionary else {}
	match kind:
		"CHARACTER": return "Choose Character — %s" % _pretty_id(target)
		"CONTRACT": return _contract_action_label(details, target)
		"MAP_NODE": return "%s — %s" % [_pretty_words(str(action.get("node_kind", "Map"))), _pretty_id(target)]
		"DRAW": return "Draw tile"
		"END_TURN": return "End turn (resolve enemy intent)"
		"TECHNIQUE":
			var timing := _pretty_words(str(details.get("technique_kind", "Technique")))
			var cost := int(details.get("tp_cost", 0))
			var target_label := _pretty_tile_id(str(details.get("effect_target_id", "")))
			var suffix := " — %s" % target_label if not target_label.is_empty() else ""
			var timing_label := "Reaction before intent" if timing == "Reaction" else ("Settlement" if timing == "Settlement" else timing)
			return "%s Technique — %s%s (TP %d)" % [timing_label, _pretty_id(target), suffix, cost]
		"PARTIAL_SETTLEMENT": return "Settle %s — %s" % [
			_pretty_words(str(details.get("pattern_type", "pattern"))),
			_join_strings(details.get("labels", [])),
		]
		"COMPLETE_HAND": return "Settle complete hand — %s" % _pretty_words(str(details.get("hand_type", "hand")))
		"RESERVE": return "Store %s in Reserve" % _pretty_tile_id(str(details.get("tile_id", target)))
		"DISCARD": return "Discard %s" % _pretty_tile_id(str(details.get("tile_id", target)))
		"RESERVE_SWAP": return "Swap %s with Reserve %s" % [
			_pretty_tile_id(str(details.get("hand_tile_id", ""))),
			_pretty_tile_id(str(details.get("reserve_tile_id", ""))),
		]
		"REWARD", "ELITE_REWARD", "BOSS_REWARD":
			var content_id := str(action.get("content_id", details.get("content_id", target)))
			return "Choose reward — %s" % _pretty_id(content_id)
		"ENTER_SHOP": return "Enter Shop"
		"SHOP_OFFER":
			var content_id := str(details.get("content_id", details.get("offer_id", target)))
			var price := int(details.get("cost", details.get("price", 0)))
			return "Buy %s (%d Gold)" % [_pretty_id(content_id), price]
		"SHOP_REFRESH": return "Refresh Shop"
		"SHOP_EXIT": return "Leave Shop"
		"ENTER_WORKSHOP": return "Enter Workshop"
		"WORKSHOP_SELECT_SERVICE": return "Workshop — %s" % _pretty_words(str(action.get("service_id", target)))
		"WORKSHOP_SELECT_TARGET": return "Choose tile — %s" % _pretty_tile_id(str(details.get("tile_definition_id", "")))
		"WORKSHOP_BACK": return "Back to Workshop choices"
		"WORKSHOP_SERVICE": return _workshop_action_label(action, details)
		"WORKSHOP_EXIT": return "Leave Workshop"
		"ENTER_EVENT": return "Enter Event"
		"EVENT_OPTION": return str(details.get("label", "Event — %s" % _pretty_id(target)))
		"RUN_SUMMARY": return "Acknowledge Run Summary"
	return "%s — %s" % [_pretty_words(kind), _pretty_id(target)]

func _help_text(phase: String) -> String:
	match phase:
		RunPhaseScript.CHARACTER_SELECT: return "Choose a Character, then choose a Contract to begin the Act 1 map. The Run prepares its starting Tile Pool when you choose."
		RunPhaseScript.CONTRACT_SELECT: return "Choose a Contract. Your selection applies across both Acts."
		RunPhaseScript.MAP_CHOICE: return "Choose an adjacent node. Complete battles and the Boss reward to continue the Run."
		RunPhaseScript.BATTLE: return "Draw tiles, settle highlighted Patterns or a Complete Hand, and end the turn to resolve enemy intent."
		RunPhaseScript.RUN_SUMMARY: return "Review the Build Story, then acknowledge the summary to finish the Run."
		RunPhaseScript.RUN_COMPLETE: return "Run complete. Start another Run when you are ready."
	return "Choose an available action to continue. Tab or the directional controls move between actions; Enter confirms."

func _action_label_for_target(kind: String, target_id: String) -> String:
	return "%s — %s" % [_pretty_words(kind), _pretty_id(target_id)]

func _workshop_action_label(action: Dictionary, details: Dictionary) -> String:
	var service_id := str(action.get("service_id", action.get("target_id", "")))
	var tile_label := _pretty_tile_id(str(details.get("tile_definition_id", "")))
	var price := int(details.get("price", 0))
	match service_id:
		"TRANSFORM":
			return "Transform %s to %s (%d Gold)" % [tile_label, _pretty_tile_id(str(action.get("value_id", ""))), price]
		"ADD_MODIFIER":
			return "Add %s to %s (%d Gold)" % [_pretty_id(str(action.get("modifier_id", ""))), tile_label, price]
		"REPLACE_MODIFIER":
			return "Replace modifier on %s with %s (%d Gold)" % [tile_label, _pretty_id(str(action.get("modifier_id", ""))), price]
		"REMOVE":
			return "Remove %s (%d Gold)" % [tile_label, price]
		"DUPLICATE":
			return "Duplicate %s (%d Gold)" % [tile_label, price]
		"REFINEMENT_TOKEN":
			return "Use Refinement Token on %s (%d Gold)" % [tile_label, price]
	return "Workshop — %s" % _pretty_words(service_id)

func _action_tooltip(action: Dictionary) -> String:
	var details: Dictionary = action.get("details", {}) if action.get("details", {}) is Dictionary else {}
	if action.get("kind", "") == "CONTRACT":
		return _contract_action_details_text(details, str(action.get("target_id", "")))
	if action.get("kind", "") != "WORKSHOP_SERVICE":
		return JSON.stringify(action.get("details", {}))
	var service_id := str(action.get("service_id", action.get("target_id", "")))
	var tile_definition_id := str(details.get("tile_definition_id", ""))
	var lines := PackedStringArray()
	lines.append("TileInstance: %s" % str(action.get("instance_id", "")))
	lines.append("Current tile: %s (%s)" % [_pretty_tile_id(tile_definition_id), tile_definition_id])
	match service_id:
		"TRANSFORM":
			var value_id := str(action.get("value_id", ""))
			lines.append("New tile: %s (%s)" % [_pretty_tile_id(value_id), value_id])
		"ADD_MODIFIER":
			lines.append("Add modifier: %s" % str(action.get("modifier_id", "")))
		"REPLACE_MODIFIER":
			lines.append("Replace %s with %s" % [_join_strings(details.get("existing_modifier_ids", [])), str(action.get("modifier_id", ""))])
	lines.append("Cost: %d Gold" % int(details.get("price", 0)))
	if service_id == "REFINEMENT_TOKEN":
		lines.append("Also consumes: 1 Refinement Token")
	return "\n".join(lines)

func _contract_action_label(details: Dictionary, target_id: String) -> String:
	var contract_name := str(details.get("name", _pretty_id(target_id)))
	var risk := str(details.get("risk_summary", "No risk details available"))
	var reward := str(details.get("reward_summary", "No reward details available"))
	return "Choose Contract — %s\nRisk: %s\nReward: %s" % [contract_name, risk, reward]

func _contract_action_details_text(details: Dictionary, target_id: String) -> String:
	var contract_name := str(details.get("name", _pretty_id(target_id)))
	var risk := str(details.get("risk_summary", "No risk details available"))
	var reward := str(details.get("reward_summary", "No reward details available"))
	var build_bias := str(details.get("build_bias_summary", "No specific Tile Pool bias"))
	var yaku_signal := str(details.get("yaku_signal_summary", "No specific Yaku signal"))
	return "%s\nRisk: %s\nReward: %s\nBuild bias: %s\nYaku signal: %s" % [contract_name, risk, reward, build_bias, yaku_signal]

func _join_strings(values: Array) -> String:
	var result := PackedStringArray()
	for value in values:
		result.append(str(value))
	return ", ".join(result)

func _pretty_tile_id(definition_id: String) -> String:
	var parts := definition_id.split(".")
	if parts.size() >= 4 and parts[parts.size() - 2] == "honors":
		return _pretty_words(parts[parts.size() - 1])
	if parts.size() >= 4:
		return "%s %s" % [_pretty_words(parts[parts.size() - 2]), _pretty_words(parts[parts.size() - 1])]
	return _pretty_id(definition_id)

func _pretty_id(identifier: String) -> String:
	if identifier.is_empty():
		return "—"
	var parts := identifier.split(".")
	return _pretty_words(parts[parts.size() - 1])

func _pretty_words(value: String) -> String:
	return value.replace("_", " ").to_lower().capitalize()

func _add_section_heading(parent: Control, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 16)
	parent.add_child(heading)

func _add_wrapped_label(parent: Control) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
