class_name BattlePresentationState
extends RefCounted
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

var hand: Array = []
var draw_wall_count := 0
var discard: Array = []
var enemy_hp := 0
var enemy_max_hp := 0
var enemy_intent: Dictionary = {}
var pressure := 0
var pressure_limit := 0
var pattern_highlights: Array = []
var outcome := "ONGOING"
var status := ""
var last_event_types: Array[String] = []

func sync(snapshot: Dictionary) -> void:
	hand = snapshot.get("hand", []).duplicate(true)
	draw_wall_count = int(snapshot.get("draw_wall_count", 0))
	discard = snapshot.get("discard", []).duplicate(true)
	enemy_hp = int(snapshot.get("enemy_hp", 0))
	enemy_max_hp = int(snapshot.get("enemy_max_hp", 0))
	enemy_intent = snapshot.get("enemy_intent", {}).duplicate(true)
	pressure = int(snapshot.get("pressure", 0))
	pressure_limit = int(snapshot.get("pressure_limit", 0))
	pattern_highlights = snapshot.get("pattern_highlights", []).duplicate(true)
	outcome = str(snapshot.get("outcome", "ONGOING"))

func apply_domain_event(event, snapshot: Dictionary) -> void:
	if event == null:
		return
	last_event_types.append(event.event_type)
	sync(snapshot)
	match event.event_type:
		"TileDrawn":
			status = LocalizationCatalogScript.text("UI_BATTLE_STATE_0001")
		"PatternSettled":
			status = LocalizationCatalogScript.template("UI_BATTLE_STATE_0002") % LocalizationCatalogScript.word_text(str(event.data.get("pattern_type", "Pattern")))
		"EnemyHpChanged":
			status = LocalizationCatalogScript.template("UI_BATTLE_STATE_0003") % int(event.data.get("amount", 0))
		"PressureChanged":
			status = LocalizationCatalogScript.template("UI_BATTLE_STATE_0004") % int(event.data.get("amount", 0))
		"BattleWon":
			status = LocalizationCatalogScript.text("UI_BATTLE_STATE_0005")
		"BattleLost":
			status = LocalizationCatalogScript.text("UI_BATTLE_STATE_0006")
