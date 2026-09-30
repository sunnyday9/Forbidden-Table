extends Control
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

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
	$DiscardValue.text = LocalizationCatalogScript.template("UI_BATTLE_SCENE_0001") % [state.discard.size(), _format_tiles(state.discard)]
	$EnemyHpValue.text = LocalizationCatalogScript.template("UI_BATTLE_SCENE_0002") % [state.enemy_hp, state.enemy_max_hp]
	$EnemyIntentValue.text = LocalizationCatalogScript.template("UI_BATTLE_SCENE_0003") % [
		str(state.enemy_intent.get("display_name", LocalizationCatalogScript.text("WORD_NONE"))),
		int(state.enemy_intent.get("pressure_amount", 0)),
	]
	$PressureValue.text = LocalizationCatalogScript.template("UI_BATTLE_SCENE_0004") % [state.pressure, state.pressure_limit]
	$PatternHighlights.text = _format_patterns(state.pattern_highlights)
	$StatusValue.text = state.status
	$SettleButton.disabled = not controller.can_settle()
	if state.pattern_highlights.is_empty():
		_selected_instance_ids = []
	else:
		_selected_instance_ids = state.pattern_highlights[0]["instance_ids"].duplicate()

func _format_tiles(tiles: Array) -> String:
	if tiles.is_empty():
		return LocalizationCatalogScript.text("WORD_NONE")
	var labels: Array[String] = []
	for tile in tiles:
		var tile_label := str(tile.get("label", ""))
		if tile_label.is_empty():
			var definition_id := str(tile.get("definition_id", ""))
			tile_label = LocalizationCatalogScript.content_text(definition_id) if not definition_id.is_empty() else LocalizationCatalogScript.text("UI_BATTLE_STATIC_NONE")
		labels.append(tile_label)
	return ", ".join(labels)

func _format_patterns(patterns: Array) -> String:
	if patterns.is_empty():
		return LocalizationCatalogScript.text("UI_BATTLE_SCENE_0005")
	var lines: Array[String] = []
	for pattern in patterns:
		lines.append(LocalizationCatalogScript.template("UI_BATTLE_SCENE_0006") % [
			LocalizationCatalogScript.word_text(str(pattern["pattern_type"])),
			", ".join(pattern["labels"]),
		])
	return "\n".join(lines)
