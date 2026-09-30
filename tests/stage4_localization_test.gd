class_name Stage4LocalizationTest
extends RefCounted

const AlphaActTwo = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScale = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const EventDefinition = preload("res://src/content/definitions/event_definition.gd")
const EncounterDefinition = preload("res://src/content/definitions/encounter_definition.gd")
const MapNodeDefinition = preload("res://src/content/definitions/map_node_definition.gd")
const Phase2 = preload("res://src/content/catalogs/phase_2_catalog.gd")
const PatternCandidate = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const CompleteHandInterpretation = preload("res://src/domain/mahjong/complete_hand/complete_hand_interpretation.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const WorkshopState = preload("res://src/domain/run/workshop_state.gd")
const Localization = preload("res://src/presentation/localization/localization.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var registry := ContentRegistry.new()
	assert_true(Phase2.register_all(registry).is_valid(), "Phase 2 localization catalog registers", failures)
	assert_true(AlphaActTwo.register_all(registry).is_valid(), "Act Two localization catalog registers", failures)
	assert_true(AlphaScale.register_all(registry).is_valid(), "Alpha Scale localization catalog registers", failures)
	assert_true(registry.validate().is_valid(), "combined Stage 4 localization content validates", failures)

	var content_count := 0
	for definition in registry.enumerate():
		if not definition is ContentDefinition:
			continue
		content_count += 1
		var label := Localization.content_text(str(definition.content_id))
		assert_true(not label.begins_with("[MISSING"), "content ID %s resolves to an English source label" % definition.content_id, failures)
	assert_true(content_count > 0, "Stage 4 localization checks registered content IDs", failures)
	assert_true(not Localization.content_text("alpha.encounter.act_one_boss").begins_with("[MISSING"), "historical Boss IDs in Run Summaries have an English source label", failures)
	assert_true(Localization.reaction_reason_text("INSUFFICIENT_TP") == "Insufficient TP", "reaction feedback localizes its common skip reason", failures)
	assert_true(Localization.reaction_reason_text("UNKNOWN_INTERNAL_REASON") == "Unavailable", "reaction feedback never exposes an internal reason code", failures)

	var word_values: Array[String] = []
	for value in Localization.required_word_values():
		word_values.append(value)
	word_values.append_array(RunPhase.all())
	word_values.append_array(MapNodeDefinition.VALID_KINDS)
	word_values.append_array(EncounterDefinition.VALID_KINDS)
	word_values.append_array(TechniqueDefinition.VALID_KINDS)
	word_values.append_array([
		PatternCandidate.PAIR,
		PatternCandidate.SEQUENCE,
		PatternCandidate.TRIPLET,
		PatternCandidate.QUAD,
		CompleteHandInterpretation.STANDARD,
		CompleteHandInterpretation.SEVEN_PAIRS,
		WorkshopState.REMOVE,
		WorkshopState.TRANSFORM,
		WorkshopState.ADD_MODIFIER,
		WorkshopState.REPLACE_MODIFIER,
		WorkshopState.DUPLICATE,
		WorkshopState.REFINEMENT_TOKEN,
	])
	for definition in registry.enumerate():
		if definition is EventDefinition:
			for choice in definition.choices:
				word_values.append(str(choice.get("choice_id", "")))
				for alternative in choice.get("alternatives", []):
					word_values.append(str(alternative.get("alternative_id", "")))
		if definition is TileDefinition:
			word_values.append(definition.suit)
			if definition.suit == "honors":
				word_values.append(str(definition.content_id).get_slice(".", 3))
		if definition is not ContractDefinition:
			continue
		for section in [definition.risk, definition.reward, definition.build_bias]:
			for key in section:
				word_values.append(str(key))
				_append_word_values(section[key], word_values)

	var unique_words: Dictionary = {}
	for value in word_values:
		var word := str(value)
		if word.is_empty():
			continue
		var key := "WORD_" + word.strip_edges().to_upper().replace(" ", "_").replace("-", "_")
		if unique_words.has(key):
			continue
		unique_words[key] = true
		var label := Localization.word_text(word)
		assert_true(not label.begins_with("[MISSING"), "dynamic word %s resolves through %s" % [word, key], failures)

	var status := "PASS" if failures.is_empty() else "FAIL"
	print("STAGE4_LOCALIZATION_RUNTIME_REPORT content_ids=%d dynamic_words=%d english_only=true final=%s" % [content_count, unique_words.size(), status])
	return failures

func _append_word_values(value: Variant, output: Array[String]) -> void:
	if value is String and not value.is_empty() and "." not in value:
		output.append(value)
	elif value is Array:
		for item in value:
			_append_word_values(item, output)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
