class_name IntentGraph
extends RefCounted

const ContentValidationIssueScript = preload("res://src/content/validation/content_validation_issue.gd")
const ContentValidationReportScript = preload("res://src/content/validation/content_validation_report.gd")
const EnemyIntentScript = preload("res://src/domain/combat/enemy_intent.gd")
const IntentGraphScript = preload("res://src/domain/combat/intent_graph.gd")
const IntentTransitionScript = preload("res://src/domain/combat/intent_transition.gd")
const IntentConditionScript = preload("res://src/domain/combat/intent_condition.gd")
const IntentTransitionSelectionScript = preload("res://src/domain/combat/intent_transition_selection.gd")

var start_intent_id: String
var _intents: Dictionary = {}
var _source_definitions: Array = []

func _init(initial_start_intent_id: String = "", intent_definitions: Array = []) -> void:
	start_intent_id = initial_start_intent_id
	_source_definitions = intent_definitions.duplicate()
	for intent in intent_definitions:
		if intent is EnemyIntentScript and not _intents.has(intent.intent_id):
			_intents[intent.intent_id] = intent

func intents() -> Array:
	var result: Array = []
	var ids: Array = _intents.keys()
	ids.sort()
	for identifier in ids:
		result.append(_intents[identifier])
	return result

func intent(identifier: String):
	return _intents.get(identifier)

func is_valid() -> bool:
	return validation().is_valid()

func validation():
	var report = ContentValidationReportScript.new()
	if start_intent_id.is_empty():
		report.add_issue(ContentValidationIssueScript.new("missing_start_intent", "", "Intent Graph has no start Intent ID."))
	elif not _intents.has(start_intent_id):
		report.add_issue(ContentValidationIssueScript.new("missing_start_intent", start_intent_id, "Intent Graph start Intent ID is not defined."))

	if _intents.is_empty():
		report.add_issue(ContentValidationIssueScript.new("empty_graph", "", "Intent Graph has no Intent definitions."))

	var definition_ids: Dictionary = {}
	for definition in _source_definitions:
		if not definition is EnemyIntentScript:
			continue
		if definition_ids.has(definition.intent_id):
			report.add_issue(ContentValidationIssueScript.new("duplicate_intent_id", definition.intent_id, "Intent IDs must be unique."))
		else:
			definition_ids[definition.intent_id] = true

	for intent in intents():
		if not intent is EnemyIntentScript:
			report.add_issue(ContentValidationIssueScript.new("invalid_intent_definition", "", "Intent Graph contains a non-Intent definition."))
			continue
		var transition_ids: Dictionary = {}
		var transition_types: Dictionary = {}
		for transition in intent.transitions:
			if not transition is IntentTransitionScript:
				report.add_issue(ContentValidationIssueScript.new("invalid_transition_definition", intent.intent_id, "Intent contains a non-transition definition."))
				continue
			if transition.transition_id.is_empty():
				report.add_issue(ContentValidationIssueScript.new("missing_transition_id", intent.intent_id, "Intent transition IDs must be stable and non-empty."))
			elif transition_ids.has(transition.transition_id):
				report.add_issue(ContentValidationIssueScript.new("duplicate_transition_id", intent.intent_id, "Intent transition IDs must be unique." , transition.transition_id))
			else:
				transition_ids[transition.transition_id] = true
			if not [IntentTransitionScript.FIXED, IntentTransitionScript.CONDITIONAL, IntentTransitionScript.WEIGHTED].has(transition.transition_type):
				report.add_issue(ContentValidationIssueScript.new("invalid_transition_type", intent.intent_id, "Intent transition type is not supported.", transition.transition_type))
			else:
				transition_types[transition.transition_type] = true
			if transition.target_intent_id.is_empty() or not _intents.has(transition.target_intent_id):
				report.add_issue(ContentValidationIssueScript.new("missing_target", intent.intent_id, "Intent transition target is not defined.", transition.target_intent_id))
			if transition.transition_type == IntentTransitionScript.CONDITIONAL:
				if not transition.condition is IntentConditionScript or not transition.condition.is_valid():
					report.add_issue(ContentValidationIssueScript.new(
						transition.condition.validation_code() if transition.condition != null and transition.condition.has_method("validation_code") else "invalid_condition",
						intent.intent_id,
						"Conditional transitions require a valid public-state condition.",
					))
			if transition.transition_type == IntentTransitionScript.WEIGHTED and transition.weight <= 0:
				report.add_issue(ContentValidationIssueScript.new("invalid_weight", intent.intent_id, "Weighted transitions require a positive weight.", transition.transition_id))
		if transition_types.size() > 1:
			report.add_issue(ContentValidationIssueScript.new("mixed_transition_types", intent.intent_id, "An Intent must use one transition selection mode."))
	return report

func select_next_intent(current_intent_id: String, public_battle_state: Dictionary, rng = null):
	var report = validation()
	if not report.is_valid():
		return IntentTransitionSelectionScript.new(
			IntentTransitionSelectionScript.INVALID_GRAPH,
			"",
			"",
			"Intent Graph validation failed.",
			{"issues": _validation_issues(report)},
		)
	var current = intent(current_intent_id)
	if current == null:
		return IntentTransitionSelectionScript.new(
			IntentTransitionSelectionScript.MISSING_CURRENT_INTENT,
			"",
			"",
			"Current Intent is not present in the Intent Graph.",
			{"intent_id": current_intent_id},
		)
	if current.transitions.is_empty():
		return IntentTransitionSelectionScript.new(
			IntentTransitionSelectionScript.TRANSITIONS_EXHAUSTED,
			"",
			"",
			"Current Intent has no available transition options.",
			{"intent_id": current_intent_id},
		)

	var first_transition = current.transitions[0]
	if first_transition.transition_type == IntentTransitionScript.FIXED:
		return _selected(first_transition)
	if first_transition.transition_type == IntentTransitionScript.CONDITIONAL:
		for transition in current.transitions:
			if transition.condition.evaluate(public_battle_state):
				return _selected(transition)
		return IntentTransitionSelectionScript.new(
			IntentTransitionSelectionScript.TRANSITIONS_EXHAUSTED,
			"",
			"",
			"No conditional Intent transition matched public Battle State.",
			{"intent_id": current_intent_id},
		)
	if rng == null or not rng.has_method("next_int"):
		return IntentTransitionSelectionScript.new(
			IntentTransitionSelectionScript.RNG_UNAVAILABLE,
			"",
			"",
			"Weighted Intent transition selection requires the deterministic Enemy RNG stream.",
			{"intent_id": current_intent_id},
		)
	var weighted: Array = current.transitions.duplicate()
	weighted.sort_custom(func(left, right): return left.transition_id < right.transition_id)
	var total_weight := 0
	for transition in weighted:
		total_weight += transition.weight
	var roll: int = rng.next_int(1, total_weight)
	var cursor := 0
	for transition in weighted:
		cursor += transition.weight
		if roll <= cursor:
			return _selected(transition)
	return IntentTransitionSelectionScript.new(IntentTransitionSelectionScript.TRANSITIONS_EXHAUSTED, "", "", "Weighted Intent transition selection exhausted its options.")

func select_transition(current_intent_id: String, public_battle_state: Dictionary, rng = null):
	return select_next_intent(current_intent_id, public_battle_state, rng)

func to_dictionary() -> Dictionary:
	var definitions: Array = []
	for intent in intents():
		definitions.append(intent.to_dictionary())
	return {"start_intent_id": start_intent_id, "intents": definitions}

func validation_issues() -> Array:
	return _validation_issues(validation())

static func from_intent_loop(intent_loop: Array):
	var intents: Array = []
	for intent in intent_loop:
		if intent is EnemyIntentScript:
			intents.append(intent)
	var graph = IntentGraphScript.new()
	if intents.is_empty():
		return graph
	graph.start_intent_id = intents[0].intent_id
	graph._source_definitions = intents.duplicate()
	for index in range(intents.size()):
		var source = intents[index]
		var copied_transitions: Array = source.transitions.duplicate()
		if copied_transitions.is_empty():
			copied_transitions.append(IntentTransitionScript.fixed(
				"%s.loop" % source.intent_id,
				intents[(index + 1) % intents.size()].intent_id,
			))
		graph._intents[source.intent_id] = EnemyIntentScript.new(source.intent_id, source.display_name, source.pressure_amount, source.action_type, copied_transitions)
	return graph

func _selected(transition):
	return IntentTransitionSelectionScript.new(
		IntentTransitionSelectionScript.SELECTED,
		transition.transition_id,
		transition.target_intent_id,
	)

func _validation_issues(report) -> Array:
	var issues: Array = []
	for issue in report.issues:
		issues.append({
			"code": issue.code,
			"content_id": issue.content_id,
			"reference_id": issue.reference_id,
			"message": issue.message,
		})
	return issues
