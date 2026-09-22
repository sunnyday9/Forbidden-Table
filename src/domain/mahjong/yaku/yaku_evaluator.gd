class_name YakuEvaluator
extends RefCounted

const CompleteHandEvaluatorScript = preload("res://src/domain/mahjong/complete_hand/complete_hand_evaluator.gd")
const CompleteHandInterpretationScript = preload("res://src/domain/mahjong/complete_hand/complete_hand_interpretation.gd")
const PatternCandidateScript = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const PatternEvaluatorScript = preload("res://src/domain/mahjong/pattern/pattern_evaluator.gd")
const ScoreContributionScript = preload("res://src/domain/mahjong/scoring/score_contribution.gd")
const SettledPatternScript = preload("res://src/domain/mahjong/settlement/settled_pattern.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const YakuDefinitionScript = preload("res://src/content/definitions/yaku_definition.gd")
const YakuProgressResultScript = preload("res://src/domain/mahjong/yaku/yaku_progress_result.gd")

var _content_registry
var _pattern_evaluator
var _complete_hand_evaluator

func _init(content_registry) -> void:
	_content_registry = content_registry
	_pattern_evaluator = PatternEvaluatorScript.new(content_registry)
	_complete_hand_evaluator = CompleteHandEvaluatorScript.new(content_registry)

func get_progress(yaku_id: String, state = {}) -> YakuProgressResultScript:
	var definition = _definition(yaku_id)
	if definition == null:
		return YakuProgressResultScript.new(yaku_id, "UNKNOWN", [], [], ["unknown yaku definition"], null, [], null)
	var hand := _hand(state)
	var reserve := _reserve(state)
	var interpretation = _interpretation(state)
	var progress := _progress_for(definition, hand, interpretation)
	var reserve_potential = null
	if not reserve.is_empty():
		var potential := _progress_for(definition, hand + reserve, null)
		reserve_potential = {
			"stage": potential.stage,
			"satisfied_conditions": potential.satisfied_conditions,
			"missing_conditions": potential.missing_conditions,
			"blockers": potential.blockers,
			"display_tokens": potential.display_tokens,
		}
	return YakuProgressResultScript.new(
		definition.content_id,
		progress.stage,
		progress.satisfied_conditions,
		progress.missing_conditions,
		progress.blockers,
		reserve_potential,
		progress.display_tokens,
		progress.normalized_score,
	)

func evaluate_all(state = {}) -> Array:
	var results: Array = []
	if _content_registry == null:
		return results
	for definition in _content_registry.enumerate():
		if definition is YakuDefinitionScript:
			results.append(get_progress(definition.content_id, state))
	return results

func evaluate_local(selection, state = {}) -> Array:
	var contributions: Array = []
	if selection == null or _content_registry == null:
		return contributions
	for definition in _content_registry.enumerate():
		if not definition is YakuDefinitionScript or not _has_local_scope(definition):
			continue
		if _local_satisfied(definition, selection, state):
			var contribution = _contribution(definition.local_score, definition.content_id)
			if contribution != null:
				contributions.append(contribution)
	return contributions

func resolve_local(selection, state = {}) -> Array:
	return evaluate_local(selection, state)

func evaluate_complete(interpretation, state = {}) -> Array:
	var contributions: Array = []
	if interpretation == null or _content_registry == null:
		return contributions
	for definition in _content_registry.enumerate():
		if not definition is YakuDefinitionScript or not _has_complete_scope(definition):
			continue
		if _complete_satisfied(definition, interpretation):
			var contribution = _contribution(definition.complete_score, definition.content_id)
			if contribution != null:
				contributions.append(contribution)
	return contributions

func resolve_complete(interpretation, state = {}) -> Array:
	return evaluate_complete(interpretation, state)

func resolve(interpretation) -> Array:
	return evaluate_complete(interpretation)

func _definition(yaku_id: String):
	if _content_registry == null:
		return null
	var definition = _content_registry.resolve(yaku_id)
	return definition if definition is YakuDefinitionScript else null

func _progress_for(definition, hand: Array, interpretation) -> Dictionary:
	var model: String = definition.progress_model
	if model == YakuDefinitionScript.COMPLETE_HAND_MODEL:
		return _complete_hand_progress(definition, hand, interpretation)
	if model == YakuDefinitionScript.PATTERN_COUNT:
		return _pattern_count_progress(definition, hand)
	if model == YakuDefinitionScript.TILE_CONDITION:
		return _tile_condition_progress(definition, hand)
	if model == YakuDefinitionScript.SUIT_CONCENTRATION:
		return _suit_concentration_progress(definition, hand)
	if model == YakuDefinitionScript.GROUP_SHAPE:
		return _group_shape_progress(definition, hand)
	return _progress("UNKNOWN", [], [], ["unsupported progress model"], [], null)

func _pattern_count_progress(definition, hand: Array) -> Dictionary:
	var config: Dictionary = definition.progress_config
	var pattern_type := str(config.get("pattern_type", ""))
	var target := maxi(1, int(config.get("target", 1)))
	var count := _max_disjoint_pattern_count(hand, pattern_type)
	var label := str(config.get("label", pattern_type.to_lower()))
	var satisfied: Array[String] = []
	var missing: Array[String] = []
	if count > 0:
		satisfied.append(_quantity_label(count, label))
	if count < target:
		missing.append("%d more %s" % [target - count, label if target - count == 1 else _plural(label)])
	var stage := _stage(count, target)
	return _progress(
		stage,
		satisfied,
		missing,
		[],
		[str(pattern_type).to_upper(), "%d/%d" % [mini(count, target), target]],
		float(mini(count, target)) / float(target),
	)

func _tile_condition_progress(definition, hand: Array) -> Dictionary:
	var config: Dictionary = definition.progress_config
	var requested_suit := str(config.get("suit", ""))
	var target := maxi(1, int(config.get("target", 1)))
	var count := _count_suit(hand, requested_suit)
	var label := str(config.get("label", "%s tile" % requested_suit))
	var missing_count := target - count
	var satisfied: Array[String] = []
	var missing: Array[String] = []
	if count > 0:
		satisfied.append(_quantity_label(count, label))
	if missing_count > 0:
		missing.append("%d more %s" % [missing_count, label if missing_count == 1 else _plural(label)])
	var blockers: Array[String] = []
	var off_suit := hand.size() - count
	if off_suit > 0 and requested_suit == "honors":
		blockers.append("%d suited tiles dilute the honor path" % off_suit)
	return _progress(
		_stage(count, target),
		satisfied,
		missing,
		blockers,
		[requested_suit.to_upper(), "%d/%d" % [mini(count, target), target]],
		float(mini(count, target)) / float(target),
	)

func _suit_concentration_progress(definition, hand: Array) -> Dictionary:
	var config: Dictionary = definition.progress_config
	var requested_suit := str(config.get("suit", ""))
	var target := maxi(1, int(config.get("target", 1)))
	var count := _count_suit(hand, requested_suit)
	var missing_count := target - count
	var label := str(config.get("label", "%s tile" % requested_suit))
	var satisfied: Array[String] = []
	var missing: Array[String] = []
	if count > 0:
		satisfied.append(_quantity_label(count, label))
	if missing_count > 0:
		missing.append("%d more %s" % [missing_count, label if missing_count == 1 else _plural(label)])
	var off_suit := hand.size() - count
	var blockers: Array[String] = []
	if off_suit > 0:
		blockers.append("%d off-suit tiles" % off_suit)
	return _progress(
		_stage(count, target),
		satisfied,
		missing,
		blockers,
		[requested_suit.to_upper(), "%d/%d" % [mini(count, target), target]],
		float(mini(count, target)) / float(target),
	)

func _complete_hand_progress(definition, hand: Array, interpretation) -> Dictionary:
	var hand_type := str(definition.progress_config.get("hand_type", ""))
	var valid := false
	if interpretation is CompleteHandInterpretationScript:
		valid = interpretation.hand_type == hand_type
	else:
		for candidate in _complete_hand_evaluator.evaluate(hand):
			if candidate.hand_type == hand_type:
				valid = true
				break
	var label := str(definition.progress_config.get("label", hand_type.to_lower()))
	if valid:
		return _progress("COMPLETE", [label], [], [], ["COMPLETE_HAND", hand_type.to_upper()], 1.0)
	return _progress("STARTING", [], [label], [], ["COMPLETE_HAND", "0/1"], 0.0)

func _group_shape_progress(definition, hand: Array) -> Dictionary:
	var required_patterns: Array = definition.progress_config.get("required_patterns", [])
	var available: Dictionary = {}
	for candidate in _pattern_evaluator.evaluate(hand):
		available[candidate.pattern_type] = true
	var satisfied: Array[String] = []
	var missing: Array[String] = []
	for pattern_type in required_patterns:
		var label := str(pattern_type).to_lower()
		if available.has(pattern_type):
			satisfied.append(label)
		else:
			missing.append("one %s" % label)
	var target := required_patterns.size()
	var count := satisfied.size()
	return _progress(
		"COMPLETE" if count == target else ("ADVANCING" if count > 0 else "STARTING"),
		satisfied,
		missing,
		[],
		["MIXED_TABLE", "%d/%d" % [count, target]],
		float(count) / float(target) if target > 0 else 0.0,
	)

func _local_satisfied(definition, selection, state) -> bool:
	var config: Dictionary = definition.progress_config
	var local_pattern_types: Array = config.get("local_pattern_types", [])
	if not selection is PatternCandidateScript and not selection is SettledPatternScript:
		return false
	var pattern_type: String = selection.pattern_type
	if not local_pattern_types.is_empty() and not local_pattern_types.has(pattern_type):
		return false
	if definition.progress_model == YakuDefinitionScript.PATTERN_COUNT:
		return pattern_type == str(config.get("pattern_type", "")) or (pattern_type == "Quad" and str(config.get("pattern_type", "")) == "Triplet")
	if definition.progress_model == YakuDefinitionScript.TILE_CONDITION:
		return _count_suit(selection.tile_instances, str(config.get("suit", ""))) >= maxi(1, int(config.get("target", 1)))
	if definition.progress_model == YakuDefinitionScript.SUIT_CONCENTRATION:
		return _count_suit(selection.tile_instances, str(config.get("suit", ""))) == selection.tile_instances.size()
	if definition.progress_model == YakuDefinitionScript.GROUP_SHAPE:
		var evaluation_hand := _hand(state)
		evaluation_hand.append_array(selection.tile_instances)
		return _group_shape_progress(definition, evaluation_hand).stage == "COMPLETE"
	return false

func _complete_satisfied(definition, interpretation) -> bool:
	var config: Dictionary = definition.progress_config
	if definition.progress_model == YakuDefinitionScript.COMPLETE_HAND_MODEL:
		return interpretation.hand_type == str(config.get("hand_type", ""))
	if definition.progress_model == YakuDefinitionScript.PATTERN_COUNT:
		return _count_groups(interpretation.groups, str(config.get("pattern_type", ""))) >= maxi(1, int(config.get("target", 1)))
	if definition.progress_model == YakuDefinitionScript.TILE_CONDITION:
		return _count_suit(interpretation.tile_instances, str(config.get("suit", ""))) >= maxi(1, int(config.get("target", 1)))
	if definition.progress_model == YakuDefinitionScript.SUIT_CONCENTRATION:
		return _count_suit(interpretation.tile_instances, str(config.get("suit", ""))) >= maxi(1, int(config.get("target", 1)))
	if definition.progress_model == YakuDefinitionScript.GROUP_SHAPE:
		for required_pattern in config.get("required_patterns", []):
			if _count_groups(interpretation.groups, str(required_pattern)) == 0:
				return false
		return true
	return false

func _contribution(spec: Dictionary, fallback_source_id: String):
	if spec.is_empty():
		return null
	var source_id := str(spec.get("source_id", fallback_source_id))
	if source_id.is_empty():
		return null
	return ScoreContributionScript.new(
		source_id,
		int(spec.get("amount", 0)),
		spec.get("tags", []),
		spec.get("metadata", {"yaku_id": fallback_source_id}),
		spec.get("conversion_modifiers", {}),
	)

func _progress(stage: String, satisfied: Array, missing: Array, blockers: Array, display_tokens: Array, normalized_score) -> Dictionary:
	return {
		"stage": stage,
		"satisfied_conditions": satisfied,
		"missing_conditions": missing,
		"blockers": blockers,
		"display_tokens": display_tokens,
		"normalized_score": normalized_score,
	}

func _has_local_scope(definition) -> bool:
	return definition.scope == YakuDefinitionScript.LOCAL_SETTLEMENT or definition.scope == YakuDefinitionScript.BOTH

func _has_complete_scope(definition) -> bool:
	return definition.scope == YakuDefinitionScript.COMPLETE_HAND or definition.scope == YakuDefinitionScript.BOTH

func _hand(state) -> Array:
	if state is Dictionary:
		return _array_copy(state.get("hand", []))
	if state != null and state.has_method("contents"):
		return _array_copy(state.contents(TileZoneScript.HAND))
	return []

func _reserve(state) -> Array:
	if state is Dictionary:
		return _array_copy(state.get("reserve", []))
	if state != null and state.has_method("contents"):
		return _array_copy(state.contents(TileZoneScript.RESERVE))
	return []

func _interpretation(state):
	if state is Dictionary:
		return state.get("complete_hand", state.get("interpretation", null))
	return null

func _array_copy(values) -> Array:
	return values.duplicate() if values is Array else []

func _max_disjoint_pattern_count(hand: Array, pattern_type: String) -> int:
	var candidates: Array = []
	for candidate in _pattern_evaluator.evaluate(hand):
		if candidate.pattern_type == pattern_type:
			candidates.append(candidate)
	return _max_disjoint_from(candidates, 0, {})

func _max_disjoint_from(candidates: Array, index: int, used: Dictionary) -> int:
	if index >= candidates.size():
		return 0
	var best := _max_disjoint_from(candidates, index + 1, used)
	var candidate = candidates[index]
	var can_use := true
	for tile_instance in candidate.tile_instances:
		if used.has(tile_instance.instance_id):
			can_use = false
			break
	if can_use:
		var next_used := used.duplicate()
		for tile_instance in candidate.tile_instances:
			next_used[tile_instance.instance_id] = true
		best = maxi(best, 1 + _max_disjoint_from(candidates, index + 1, next_used))
	return best

func _count_suit(tiles: Array, suit: String) -> int:
	var count := 0
	for tile_instance in tiles:
		var definition = _resolve_definition(tile_instance)
		if definition != null and definition.suit == suit:
			count += 1
	return count

func _count_groups(groups: Array, pattern_type: String) -> int:
	var count := 0
	for group in groups:
		if group.pattern_type == pattern_type:
			count += 1
	return count

func _resolve_definition(tile_instance):
	if tile_instance == null or _content_registry == null or not tile_instance.has_method("is_valid") or not tile_instance.is_valid():
		return null
	var definition = _content_registry.resolve(tile_instance.definition_id)
	return definition if definition is TileDefinitionScript else null

func _stage(count: int, target: int) -> String:
	if count >= target:
		return "COMPLETE"
	return "ADVANCING" if count > 0 else "STARTING"

func _quantity_label(count: int, label: String) -> String:
	return "%d %s" % [count, label if count == 1 else _plural(label)]

func _plural(label: String) -> String:
	if label.ends_with("y"):
		return label.left(-1) + "ies"
	return label + "s"
