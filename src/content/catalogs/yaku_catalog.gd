class_name YakuCatalog
extends RefCounted

const YakuDefinitionScript = preload("res://src/content/definitions/yaku_definition.gd")

static func representative_definitions() -> Array:
	return [
		_yaku(
			"prototype.yaku.sequence_path",
			"Sequence Path",
			YakuDefinitionScript.LOCAL_SETTLEMENT,
			YakuDefinitionScript.STRUCTURAL,
			YakuDefinitionScript.PATTERN_COUNT,
			{"pattern_type": "Sequence", "target": 3, "label": "sequence", "local_pattern_types": ["Sequence"]},
			{"source_id": "prototype.yaku.sequence_path", "amount": 6, "tags": ["LOCAL_YAKU", "SEQUENCE"]},
			{},
		),
		_yaku(
			"prototype.yaku.triplet_foundation",
			"Triplet Foundation",
			YakuDefinitionScript.BOTH,
			YakuDefinitionScript.STRUCTURAL,
			YakuDefinitionScript.PATTERN_COUNT,
			{"pattern_type": "Triplet", "target": 3, "label": "triplet", "local_pattern_types": ["Triplet", "Quad"]},
			{"source_id": "prototype.yaku.triplet_foundation", "amount": 8, "tags": ["LOCAL_YAKU", "TRIPLET"]},
			{"source_id": "prototype.yaku.triplet_foundation.complete", "amount": 12, "tags": ["HAND_YAKU", "TRIPLET"]},
		),
		_yaku(
			"prototype.yaku.honor_signal",
			"Honor Signal",
			YakuDefinitionScript.LOCAL_SETTLEMENT,
			YakuDefinitionScript.SUIT_HONOR,
			YakuDefinitionScript.TILE_CONDITION,
			{"suit": "honors", "target": 3, "label": "honor tile", "local_pattern_types": ["Triplet", "Quad"]},
			{"source_id": "prototype.yaku.honor_signal", "amount": 7, "tags": ["LOCAL_YAKU", "HONOR"]},
			{},
		),
		_yaku(
			"prototype.yaku.unified_suit",
			"Unified Suit",
			YakuDefinitionScript.BOTH,
			YakuDefinitionScript.SUIT_HONOR,
			YakuDefinitionScript.SUIT_CONCENTRATION,
			{"suit": "characters", "target": 9, "label": "characters tile"},
			{"source_id": "prototype.yaku.unified_suit", "amount": 10, "tags": ["LOCAL_YAKU", "SUIT"]},
			{"source_id": "prototype.yaku.unified_suit.complete", "amount": 18, "tags": ["HAND_YAKU", "SUIT"]},
		),
		_yaku(
			"prototype.yaku.standard_complete_hand",
			"Standard Complete Hand",
			YakuDefinitionScript.COMPLETE_HAND,
			YakuDefinitionScript.COMPLETE_HAND_FAMILY,
			YakuDefinitionScript.COMPLETE_HAND_MODEL,
			{"hand_type": "Standard", "label": "standard complete hand"},
			{},
			{"source_id": "prototype.yaku.standard_complete_hand", "amount": 25, "tags": ["HAND_YAKU", "COMPLETE_HAND"]},
		),
		_yaku(
			"prototype.yaku.seven_pairs",
			"Seven Pairs",
			YakuDefinitionScript.COMPLETE_HAND,
			YakuDefinitionScript.COMPLETE_HAND_FAMILY,
			YakuDefinitionScript.COMPLETE_HAND_MODEL,
			{"hand_type": "Seven Pairs", "label": "seven pairs"},
			{},
			{"source_id": "prototype.yaku.seven_pairs", "amount": 30, "tags": ["HAND_YAKU", "SEVEN_PAIRS"]},
		),
		_yaku(
			"prototype.yaku.quad_foundry",
			"Quad Foundry",
			YakuDefinitionScript.BOTH,
			YakuDefinitionScript.ROGUELIKE_STRUCTURAL,
			YakuDefinitionScript.PATTERN_COUNT,
			{"pattern_type": "Quad", "target": 1, "label": "quad", "local_pattern_types": ["Quad"]},
			{"source_id": "prototype.yaku.quad_foundry", "amount": 14, "tags": ["LOCAL_YAKU", "QUAD"]},
			{"source_id": "prototype.yaku.quad_foundry.complete", "amount": 20, "tags": ["HAND_YAKU", "QUAD"]},
		),
		_yaku(
			"prototype.yaku.mixed_table",
			"Mixed Table",
			YakuDefinitionScript.LOCAL_SETTLEMENT,
			YakuDefinitionScript.ROGUELIKE_STRUCTURAL,
			YakuDefinitionScript.GROUP_SHAPE,
			{"required_patterns": ["Sequence", "Triplet", "Pair"], "local_pattern_types": ["Sequence", "Triplet", "Quad"]},
			{"source_id": "prototype.yaku.mixed_table", "amount": 11, "tags": ["LOCAL_YAKU", "STRUCTURAL"]},
			{},
		),
	]

static func register_representative(registry) -> Array:
	var definitions := representative_definitions()
	for definition in definitions:
		if registry != null:
			registry.register(definition)
	return definitions

static func _yaku(
	definition_id: String,
	definition_name: String,
	definition_scope: String,
	definition_family: String,
	definition_progress_model: String,
	definition_progress_config: Dictionary,
	definition_local_score: Dictionary,
	definition_complete_score: Dictionary,
) -> YakuDefinitionScript:
	return YakuDefinitionScript.new(
		definition_id,
		definition_name,
		definition_scope,
		definition_family,
		definition_progress_model,
		definition_progress_config,
		definition_local_score,
		definition_complete_score,
	)
