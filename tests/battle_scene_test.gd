class_name BattleSceneTest
extends RefCounted

const DrawCommand = preload("res://src/domain/commands/draw_command.gd")
const SettlePatternCommand = preload("res://src/domain/commands/settle_pattern_command.gd")
const BattleScene = preload("res://scenes/battle/battle_scene.tscn")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_default_battle_scene_exposes_operable_loop(failures)
	test_domain_scripts_have_no_scene_dependencies(failures)
	return failures

func test_default_battle_scene_exposes_operable_loop(failures: Array[String]) -> void:
	var scene = BattleScene.instantiate()
	scene._ready()

	assert_true(scene.controller != null, "BattleScene creates a controller", failures)
	assert_true(scene.get_node("HandValue").text != "", "BattleScene shows the Hand", failures)
	assert_true(scene.get_node("DrawWallValue").text != "", "BattleScene shows the Draw Wall count", failures)
	assert_true(scene.get_node("DiscardValue").text != "", "BattleScene shows the Discard", failures)
	assert_true(scene.get_node("EnemyHpValue").text != "", "BattleScene shows enemy HP", failures)
	assert_true(scene.get_node("EnemyIntentValue").text != "", "BattleScene shows enemy Intent", failures)
	assert_true(scene.get_node("PressureValue").text != "", "BattleScene shows Pressure", failures)
	assert_true(scene.get_node("PatternHighlights").text != "", "BattleScene shows Pattern highlights", failures)

	var initial_draw_wall_count := int(scene.get_node("DrawWallValue").text)
	var draw_result = scene.controller.submit(DrawCommand.new("test.draw.1"))
	assert_true(draw_result.accepted, "the Draw Command is accepted", failures)
	assert_true(int(scene.get_node("DrawWallValue").text) == initial_draw_wall_count - 1, "TileDrawn updates the Draw Wall presentation", failures)
	assert_true(scene.get_node("PatternHighlights").text.find("Sequence") >= 0, "the draw exposes a highlighted Pattern", failures)

	var highlighted_ids: Array[String] = scene.controller.presentation.pattern_highlights[0]["instance_ids"]
	var settlement_command := SettlePatternCommand.new("test.settle.1", highlighted_ids)
	assert_true(settlement_command.to_dictionary()["instance_ids"] == highlighted_ids, "Settlement Command is serializable-ish", failures)
	var initial_enemy_hp := int(scene.get_node("EnemyHpValue").text.split("/")[0].strip_edges())
	var settlement_result = scene.controller.submit(settlement_command)
	assert_true(settlement_result.accepted, "the Settlement Command is accepted through the controller", failures)
	assert_true(scene.get_node("DiscardValue").text.find("3") >= 0, "PatternSettled updates the Discard presentation", failures)
	assert_true(int(scene.get_node("EnemyHpValue").text.split("/")[0].strip_edges()) < initial_enemy_hp, "combat domain events update enemy HP presentation", failures)
	assert_true(scene.get_node("StatusValue").text.find("Damage") >= 0, "the presentation records the combat event", failures)

	scene.free()

func test_domain_scripts_have_no_scene_dependencies(failures: Array[String]) -> void:
	var forbidden_tokens := ["Node", "Control", "SceneTree", "AnimationPlayer", "AudioStreamPlayer"]
	var scripts := _domain_scripts("res://src/domain")
	assert_true(not scripts.is_empty(), "the domain dependency check finds domain scripts", failures)
	for script_path in scripts:
		var file := FileAccess.open(script_path, FileAccess.READ)
		if file == null:
			failures.append("ASSERTION FAILED: domain dependency check could not read %s" % script_path)
			continue
		var source := file.get_as_text()
		for forbidden_token in forbidden_tokens:
			assert_true(source.find(forbidden_token) < 0, "%s does not reference %s" % [script_path, forbidden_token], failures)

func _domain_scripts(path: String) -> Array[String]:
	var scripts: Array[String] = []
	var directory := DirAccess.open(path)
	if directory == null:
		return scripts
	for entry in directory.get_files():
		if entry.ends_with(".gd"):
			scripts.append(path.path_join(entry))
	for entry in directory.get_directories():
		scripts.append_array(_domain_scripts(path.path_join(entry)))
	scripts.sort()
	return scripts

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
