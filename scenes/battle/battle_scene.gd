extends Control

const BattleControllerScript = preload("res://src/presentation/battle/battle_controller.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const SettlePatternCommandScript = preload("res://src/domain/commands/settle_pattern_command.gd")

var controller
var _selected_instance_ids: Array[String] = []
var _command_sequence := 0

func _init() -> void:
	controller = BattleControllerScript.new()

func _ready() -> void:
	controller.presentation_changed.connect(_render)
	_render()

func _on_draw_pressed() -> void:
	_command_sequence += 1
	controller.submit(DrawCommandScript.new("battle.draw.%d" % _command_sequence))

func _on_settle_pressed() -> void:
	if _selected_instance_ids.is_empty():
		return
	_command_sequence += 1
	controller.submit(SettlePatternCommandScript.new(
		"battle.settle.%d" % _command_sequence,
		_selected_instance_ids,
	))

func _render() -> void:
	var state = controller.presentation
	$HandValue.text = _format_tiles(state.hand)
	$DrawWallValue.text = str(state.draw_wall_count)
	$DiscardValue.text = "%d: %s" % [state.discard.size(), _format_tiles(state.discard)]
	$EnemyHpValue.text = "%d / %d" % [state.enemy_hp, state.enemy_max_hp]
	$EnemyIntentValue.text = "%s (%d Pressure)" % [
		str(state.enemy_intent.get("display_name", "None")),
		int(state.enemy_intent.get("pressure_amount", 0)),
	]
	$PressureValue.text = "%d / %d" % [state.pressure, state.pressure_limit]
	$PatternHighlights.text = _format_patterns(state.pattern_highlights)
	$StatusValue.text = state.status
	$SettleButton.disabled = not controller.can_settle()
	if state.pattern_highlights.is_empty():
		_selected_instance_ids = []
	else:
		_selected_instance_ids = state.pattern_highlights[0]["instance_ids"].duplicate()

func _format_tiles(tiles: Array) -> String:
	if tiles.is_empty():
		return "None"
	var labels: Array[String] = []
	for tile in tiles:
		labels.append(str(tile.get("label", tile.get("definition_id", "?"))))
	return ", ".join(labels)

func _format_patterns(patterns: Array) -> String:
	if patterns.is_empty():
		return "No Scoring Pattern highlighted."
	var lines: Array[String] = []
	for pattern in patterns:
		lines.append("%s: %s" % [pattern["pattern_type"], ", ".join(pattern["labels"])])
	return "\n".join(lines)
