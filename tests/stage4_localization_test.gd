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
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunPresentationController = preload("res://src/presentation/run/run_presentation_controller.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const WorkshopState = preload("res://src/domain/run/workshop_state.gd")
const Localization = preload("res://src/presentation/localization/localization.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const BattlePresentationState = preload("res://src/presentation/battle/battle_presentation_state.gd")
const RunScene = preload("res://scenes/run/run_scene.gd")

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
	var run_scene = RunScene.new()
	var draw_tooltip: String = run_scene._action_tooltip({
		"kind": "DRAW",
		"target_id": "internal.draw.action",
		"details": {"debug_id": "internal.draw.action", "opaque": true},
	})
	assert_true(draw_tooltip == Localization.text("UI_RUN_SCENE_0080"), "DRAW tooltips use localized action copy even when arbitrary details are present", failures)
	assert_true("internal.draw.action" not in draw_tooltip and "debug_id" not in draw_tooltip, "DRAW tooltips never expose raw detail JSON or internal IDs", failures)
	var operational_ids := {
		"base.reward.skip": "SKIP",
		"base.special.copy_license": "COPY_LICENSE",
		"base.special.gold_cache": "GOLD_CACHE",
		"base.special.refinement_token": "REFINEMENT_TOKEN",
		"base.special.ritual_salve": "RITUAL_SALVE",
		"base.special.workshop_coupon": "WORKSHOP_COUPON",
	}
	for operational_id in operational_ids:
		assert_true(run_scene._pretty_id(operational_id) == Localization.word_text(operational_ids[operational_id]), "operational ID %s uses a localized final-word label" % operational_id, failures)
	var tile_id := "base.tile.characters.3"
	var new_tile_id := "base.tile.bamboo.1"
	var current_tile_label := Localization.content_text(tile_id)
	var new_tile_label := Localization.content_text(new_tile_id)
	var transform_tooltip: String = run_scene._action_tooltip({
		"kind": "WORKSHOP_SERVICE",
		"service_id": "TRANSFORM",
		"instance_id": "internal.tile.instance.27",
		"value_id": new_tile_id,
		"details": {"tile_definition_id": tile_id, "price": 7},
	})
	assert_true(current_tile_label in transform_tooltip and new_tile_label in transform_tooltip, "Workshop transform tooltip shows localized tile names", failures)
	assert_true(tile_id not in transform_tooltip and new_tile_id not in transform_tooltip and "internal.tile.instance.27" not in transform_tooltip, "Workshop transform tooltip hides content and instance IDs", failures)
	var modifier_id := "base.modifier.flexible_identity"
	var replacement_modifier_id := "base.modifier.recycling"
	var add_modifier_tooltip: String = run_scene._action_tooltip({
		"kind": "WORKSHOP_SERVICE",
		"service_id": "ADD_MODIFIER",
		"instance_id": "internal.tile.instance.28",
		"modifier_id": modifier_id,
		"details": {"tile_definition_id": tile_id, "price": 7},
	})
	var replace_modifier_tooltip: String = run_scene._action_tooltip({
		"kind": "WORKSHOP_SERVICE",
		"service_id": "REPLACE_MODIFIER",
		"instance_id": "internal.tile.instance.29",
		"modifier_id": replacement_modifier_id,
		"details": {"tile_definition_id": tile_id, "price": 7, "existing_modifier_ids": [modifier_id]},
	})
	var modifier_label := Localization.content_text(modifier_id)
	var replacement_modifier_label := Localization.content_text(replacement_modifier_id)
	assert_true(modifier_label in add_modifier_tooltip and modifier_label in replace_modifier_tooltip and replacement_modifier_label in replace_modifier_tooltip, "Workshop modifier tooltips show localized modifier names", failures)
	assert_true(modifier_id not in add_modifier_tooltip and modifier_id not in replace_modifier_tooltip and replacement_modifier_id not in replace_modifier_tooltip, "Workshop modifier tooltips hide modifier IDs", failures)
	run_scene.free()

	var feedback_controller := RunPresentationController.new(RunDomain.new("run.localization.feedback", 93, registry))
	var technique_id: String = Phase2.CORE_TECHNIQUE_IDS[0]
	var technique_label := Localization.content_text(technique_id)
	var technique_feedback: String = feedback_controller._feedback_for_events([DomainEvent.new(DomainEvent.TECHNIQUE_USED, {"technique_id": technique_id})])
	assert_true(technique_feedback == Localization.template("UI_RUN_CONTROLLER_0071") % technique_label, "Technique feedback uses a translated catalog label", failures)
	assert_true(technique_id not in technique_feedback, "Technique feedback never exposes its internal content ID", failures)
	var reaction_trigger_id := TechniqueDefinition.REACTION_ENEMY_CONTAMINATION_ADDED
	var reaction_feedback: String = feedback_controller._feedback_for_events([DomainEvent.new(DomainEvent.TECHNIQUE_USED, {
		"technique_id": technique_id,
		"reaction_trigger_id": reaction_trigger_id,
		"reaction_trigger_label": "unlocalized event label",
	})])
	var reaction_trigger_label := Localization.text("CONTENT_TECHNIQUE_0005")
	assert_true(reaction_feedback == Localization.template("UI_RUN_CONTROLLER_0055") % [technique_label, reaction_trigger_label], "reaction feedback resolves its trigger ID through the localization catalog", failures)
	assert_true("unlocalized event label" not in reaction_feedback, "reaction feedback never interpolates the event's display string", failures)
	var fallback_feedback: String = feedback_controller._feedback_for_events([DomainEvent.new(DomainEvent.TP_CHANGED)])
	assert_true(fallback_feedback == Localization.text("UI_RUN_CONTROLLER_0074"), "unmapped domain events use stable generic feedback copy", failures)
	assert_true("TPChanged" not in fallback_feedback, "unmapped feedback never exposes the event type", failures)
	var battle_presentation_state := BattlePresentationState.new()
	battle_presentation_state.apply_domain_event(DomainEvent.new(DomainEvent.PATTERN_SETTLED, {"pattern_type": "SEQUENCE"}), {})
	assert_true(battle_presentation_state.status == (Localization.template("UI_BATTLE_STATE_0002") % Localization.word_text("SEQUENCE")), "settled-pattern feedback localizes its dynamic pattern label", failures)

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
