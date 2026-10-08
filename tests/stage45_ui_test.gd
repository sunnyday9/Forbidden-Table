extends RefCounted

const MODULE_SUITES := [
	"res://tests/hand_play_order_test.gd",
	"res://tests/new_player_experience_test.gd",
	"res://tests/stage45_ui_foundation_test.gd",
	"res://tests/stage45_bilingual_test.gd",
	"res://tests/stage45_run_ui_test.gd",
	"res://tests/stage45_battle_ui_test.gd",
	"res://tests/stage45_mouse_motion_test.gd",
	"res://tests/battle_event_transport_test.gd",
	"res://tests/enemy_arena_test.gd",
	"res://tests/battle_cue_projection_test.gd",
	"res://tests/battle_feedback_layer_test.gd",
	"res://tests/battle_feedback_integration_test.gd",
	"res://tests/battle_tile_selection_test.gd",
	"res://tests/tile_table_interaction_test.gd",
	"res://tests/tile_table_layout_test.gd",
	"res://tests/run_window_layout_test.gd",
	"res://tests/rc2_battle_resume_regression_test.gd",
	"res://tests/rc2_preferences_regression_test.gd",
	"res://tests/rc2_journey_regression_test.gd",
	"res://tests/rc3_draw_hand_regression_test.gd",
	"res://tests/rc3_direct_choices_regression_test.gd",
	"res://tests/rc3_direct_battle_regression_test.gd",
	"res://tests/rc3_loss_summary_regression_test.gd",
	"res://tests/rc5_typography_regression_test.gd",
	"res://tests/rc5_battle_layout_regression_test.gd",
	"res://tests/rc5_reward_visuals_regression_test.gd",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	for path in MODULE_SUITES:
		var suite: Script = load(path) as Script
		if suite == null or not suite.can_instantiate():
			failures.append("Stage 4.5 module suite could not load: " + path)
			continue
		var instance = suite.new()
		failures.append_array(await instance.run())
	print("STAGE45_UI_REPORT modules=%d failures=%d physical_device=NOT_PERFORMED participant_testing=NOT_PERFORMED" % [MODULE_SUITES.size(), failures.size()])
	return failures
