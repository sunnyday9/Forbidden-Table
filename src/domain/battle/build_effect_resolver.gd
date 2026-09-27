class_name BuildEffectResolver
extends RefCounted

const CombatResolutionEffectScript = preload("res://src/domain/combat/combat_resolution_effect.gd")
const CombatResolverScript = preload("res://src/domain/combat/combat_resolver.gd")
const EffectScript = preload("res://src/domain/effects/effect.gd")
const EffectContextScript = preload("res://src/domain/effects/effect_context.gd")
const EffectResolutionResultScript = preload("res://src/domain/effects/effect_resolution_result.gd")
const EffectTriggerScript = preload("res://src/domain/effects/effect_trigger.gd")
const GainTPOperationScript = preload("res://src/domain/effects/operations/gain_tp_operation.gd")
const ActiveEffectInstanceScript = preload("res://src/domain/effects/active_effect_instance.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")
const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const RuleBreakerDefinitionScript = preload("res://src/content/definitions/rule_breaker_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")
const SettlementCapacityScript = preload("res://src/domain/mahjong/settlement/settlement_capacity.gd")
const RunModifierEffectResolverScript = preload("res://src/domain/run/run_modifier_effect_resolver.gd")

const RULE_MEMORY_RELIC_ID := "base.relic.rule_memory"
const RULE_MEMORY_MODIFIER_ID := "content.base.relic.rule_memory"

var _content_registry
var _run_modifier_effect_resolver

func _init(content_registry = null) -> void:
	_content_registry = content_registry
	_run_modifier_effect_resolver = RunModifierEffectResolverScript.new()

func resolve_battle_entry(run_state, battle) -> Dictionary:
	if run_state == null or battle == null or battle.combat_state == null:
		return {"accepted": false, "reason": "MISSING_BATTLE_CONTEXT", "events": []}
	var context = _context_for_battle(run_state, battle)
	var effects: Array = []
	effects.append_array(_owned_definition_effects(
		run_state.build_ownership.owned_relic_ids,
		"RELIC",
	))
	effects.append_array(_owned_definition_effects(
		run_state.build_ownership.acquired_rule_breaker_ids,
		"RULE_BREAKER",
	))
	effects.append_array(_run_modifier_effect_resolver.battle_entry_effects(run_state))
	var rule_memory_amount := _rule_memory_entry_amount(run_state, effects)
	if rule_memory_amount > 0:
		effects.append(EffectScript.new(
			"run_modifier.%s" % RULE_MEMORY_MODIFIER_ID,
			EffectTriggerScript.new(EffectTriggerScript.MANUAL),
			[],
			[],
			[GainTPOperationScript.new(rule_memory_amount)],
		))
	if effects.is_empty():
		return {"accepted": true, "events": []}
	var selection := _select_valid_effects(effects, context)
	if not selection.get("accepted", false):
		return {"accepted": false, "reason": str(selection.get("reason", "BUILD_EFFECT_REJECTED")), "effect_id": str(selection.get("effect_id", "")), "events": []}
	effects = selection.get("effects", [])
	if effects.is_empty():
		return {"accepted": true, "events": []}

	var battle_before: Dictionary = battle.checkpoint()
	var rng_before: Dictionary = battle.rng_snapshot()
	var run_state_before := _capture_run_effect_state(run_state)
	var queue = CombatResolverScript.new().begin_queue(battle.combat_state, 256, context, "")
	for effect in effects:
		if not queue.enqueue_effect(effect):
			queue.drain()
			_restore_effect_state(battle, run_state, battle_before, rng_before, run_state_before)
			return {"accepted": false, "reason": "BUILD_EFFECT_QUEUE_REJECTED", "effect_id": effect.effect_id, "events": []}
	var result = queue.drain()
	var late_failure := _first_non_optional_rejection(result.effect_results)
	if not result.is_resolved() or not late_failure.is_empty():
		_restore_effect_state(battle, run_state, battle_before, rng_before, run_state_before)
		return {"accepted": false, "reason": str(late_failure.get("reason", result.status)), "effect_id": str(late_failure.get("effect_id", "")), "events": result.events.duplicate()}
	sync_capacity_services(battle.combat_state, battle.reserve_service, battle.settlement_window, result.events)
	return {"accepted": true, "events": result.events.duplicate()}

func validate_tile_modifier_effects(base_context, instance_ids: Array) -> Dictionary:
	if base_context == null or base_context.run_state == null:
		return {"accepted": true, "entries": []}
	var selection := _select_valid_scoped_effects(base_context, instance_ids)
	return {"accepted": bool(selection.get("accepted", false)), "reason": str(selection.get("reason", "")), "effect_id": str(selection.get("effect_id", "")), "entries": selection.get("entries", [])}

func enqueue_tile_modifier_effects(queue, base_context, instance_ids: Array) -> Dictionary:
	if queue == null or base_context == null or base_context.run_state == null:
		return {"accepted": true, "events": []}
	var selection := _select_valid_scoped_effects(base_context, instance_ids)
	if not selection.get("accepted", false):
		return {"accepted": false, "reason": str(selection.get("reason", "BUILD_EFFECT_REJECTED")), "effect_id": str(selection.get("effect_id", "")), "events": []}
	var index := 0
	for entry in selection.get("entries", []):
		var effect = entry.effect
		var effect_context = entry.context
		var scoped_resolver := Callable(self, "_resolve_scoped_effect").bind(effect, effect_context)
		if not queue.enqueue_effect(CombatResolutionEffectScript.new(
			"build.tile_modifier.%s.%s.%d" % [str(entry.instance_id), str(effect.effect_id), index],
			scoped_resolver,
		)):
			return {"accepted": false, "reason": "BUILD_EFFECT_QUEUE_REJECTED", "effect_id": str(effect.effect_id), "events": []}
		index += 1
	return {"accepted": true, "events": []}

func capture_run_state(run_state) -> Dictionary:
	return _capture_run_effect_state(run_state)

func restore_run_state(run_state, snapshot: Dictionary) -> bool:
	if run_state == null or not snapshot is Dictionary:
		return false
	run_state.gold = int(snapshot.get("gold", run_state.gold))
	run_state.refinement_tokens = int(snapshot.get("refinement_tokens", run_state.refinement_tokens))
	run_state.active_effects = _active_effects_from_snapshot(snapshot.get("active_effects", {}))
	return true

func sync_capacity_services(combat_state, reserve_service, settlement_window, events: Array) -> void:
	var reserve_capacity_changed := false
	var settlement_capacity_changed := false
	for event in events:
		if event == null or event.event_type != "CapacityChanged":
			continue
		match str(event.data.get("capacity", "")):
			"reserve_capacity":
				reserve_capacity_changed = true
			"settlement_capacity":
				settlement_capacity_changed = true
	if reserve_capacity_changed and reserve_service != null and combat_state != null:
		reserve_service.set_capacity(combat_state.reserve_capacity)
	if settlement_capacity_changed and settlement_window != null and combat_state != null:
		var capacity = settlement_window.settlement_capacity()
		if capacity != null and capacity.maximum != combat_state.settlement_capacity:
			var spent: int = capacity.spent
			capacity.baseline = maxi(0, capacity.baseline + combat_state.settlement_capacity - capacity.maximum)
			capacity._remaining = maxi(0, capacity.maximum - spent)

func _owned_definition_effects(content_ids: Array, definition_kind: String) -> Array:
	var effects: Array = []
	if content_ids.is_empty():
		return effects
	var ordered_content_ids: Array = content_ids.duplicate()
	ordered_content_ids.sort()
	var seen: Dictionary = {}
	for content_id in ordered_content_ids:
		var identifier := str(content_id)
		if seen.has(identifier):
			continue
		seen[identifier] = true
		var definition = _content_registry.resolve(identifier) if _content_registry != null else null
		if not _is_definition_kind(definition, definition_kind):
			continue
		for effect in definition.effects:
			if effect != null and effect.trigger != null and effect.trigger.trigger_id == EffectTriggerScript.MANUAL:
				effects.append(effect)
	return effects

func _select_valid_effects(effects: Array, context) -> Dictionary:
	var selected: Array = []
	for effect in effects:
		if not effect.has_method("validate_in_context"):
			return {"accepted": false, "effect_id": "", "reason": "INVALID_BUILD_EFFECT"}
		var validation: Dictionary = effect.validate_in_context(context)
		if bool(validation.get("valid", false)):
			selected.append(effect)
			continue
		if str(validation.get("reason", "")) == "NO_PURGE_TARGET":
			continue
		return {"accepted": false, "effect_id": str(effect.effect_id), "reason": str(validation.get("reason", "BUILD_EFFECT_REJECTED"))}
	return {"accepted": true, "effects": selected}

func _select_valid_scoped_effects(base_context, instance_ids: Array) -> Dictionary:
	var run_state = base_context.run_state
	var persistent_state: Dictionary = run_state.build_ownership.persistent_tile_modifier_state
	var ordered_instance_ids: Array = instance_ids.duplicate()
	ordered_instance_ids.sort()
	var entries: Array = []
	for instance_id in ordered_instance_ids:
		var modifier_ids: Array = persistent_state.get(str(instance_id), []).duplicate()
		for modifier_id in modifier_ids:
			var definition = _content_registry.resolve(str(modifier_id)) if _content_registry != null else null
			if not definition is TileModifierDefinitionScript:
				return {"accepted": false, "effect_id": str(modifier_id), "reason": "INVALID_TILE_MODIFIER"}
			for effect in definition.effects:
				if not _is_manual_or_settlement_effect(effect):
					continue
				if not effect.has_method("validate_in_context"):
					return {"accepted": false, "effect_id": str(effect.get("effect_id")), "reason": "INVALID_BUILD_EFFECT"}
				var scoped_context := EffectContextScript.new(
					base_context.state,
					base_context.zones,
					base_context.draw_wall,
					base_context.reserve_service,
					base_context.resolve_contamination_service(),
					base_context.run_state,
					str(instance_id),
				)
				var validation: Dictionary = effect.validate_in_context(scoped_context)
				if not validation.get("valid", false):
					if str(validation.get("reason", "")) == "NO_PURGE_TARGET":
						continue
					return {"accepted": false, "effect_id": str(effect.effect_id), "reason": str(validation.get("reason", "BUILD_EFFECT_REJECTED"))}
				entries.append({"instance_id": str(instance_id), "effect": effect, "context": scoped_context})
	return {"accepted": true, "entries": entries}

func _first_non_optional_rejection(effect_results: Array) -> Dictionary:
	for effect_result in effect_results:
		if effect_result != null and not effect_result.is_resolved() and effect_result.reason != "NO_PURGE_TARGET":
			return {"effect_id": effect_result.effect_id, "reason": effect_result.reason}
	return {}

func _capture_run_effect_state(run_state) -> Dictionary:
	var active_effect_data: Dictionary = {}
	for effect_key in run_state.active_effects.keys():
		var effect = run_state.active_effects[effect_key]
		if effect != null and effect.has_method("to_dictionary"):
			active_effect_data[str(effect_key)] = effect.to_dictionary()
	return {
		"gold": run_state.gold,
		"refinement_tokens": run_state.refinement_tokens,
		"active_effects": active_effect_data,
	}

func _restore_effect_state(battle, run_state, battle_checkpoint: Dictionary, rng_snapshot: Dictionary, run_snapshot: Dictionary) -> void:
	battle.restore_checkpoint(battle_checkpoint)
	battle._restore_rng_snapshot(rng_snapshot)
	restore_run_state(run_state, run_snapshot)
	if battle.reserve_service != null:
		battle.reserve_service.set_capacity(battle.combat_state.reserve_capacity)

func _is_definition_kind(definition, definition_kind: String) -> bool:
	if definition_kind == "RELIC":
		return definition is RelicDefinitionScript
	if definition_kind == "RULE_BREAKER":
		return definition is RuleBreakerDefinitionScript
	return false

func _is_manual_or_settlement_effect(effect) -> bool:
	return effect != null and effect.trigger != null and effect.trigger.trigger_id in [
		EffectTriggerScript.MANUAL,
		EffectTriggerScript.SETTLEMENT,
	]

func _rule_memory_entry_amount(run_state, effects: Array) -> int:
	for effect in effects:
		if effect == null or not effect.get("operations") is Array:
			continue
		for operation in effect.operations:
			if operation != null and str(operation.get("operation_id")) == "ApplyRunModifier" and str(operation.get("modifier_id")) == RULE_MEMORY_MODIFIER_ID:
				return maxi(0, int(operation.get("modifier_value")))
	var active_modifier = run_state.active_modifier(RULE_MEMORY_MODIFIER_ID) if run_state != null and run_state.has_method("active_modifier") else null
	if active_modifier != null:
		return maxi(0, int(active_modifier.runtime_parameters.get("value", 0)))
	return 0

func _context_for_battle(run_state, battle):
	return EffectContextScript.new(
		battle.combat_state,
		battle.zones,
		battle.draw_wall,
		battle.reserve_service,
		battle.contamination_service,
		run_state,
	)

func _resolve_scoped_effect(queue, _state, sequence_index: int, effect, effect_context):
	var result = effect.resolve_in_context(effect_context, sequence_index)
	if result == null:
		queue.fail("BUILD_EFFECT_REJECTED", {"effect_id": str(effect.effect_id), "reason": "MISSING_EFFECT_RESULT"})
		return []
	if not result.is_resolved():
		if result.reason == "NO_PURGE_TARGET":
			return []
		queue.fail("BUILD_EFFECT_REJECTED", {"effect_id": str(effect.effect_id), "reason": result.reason})
		return []
	return result.events

func _active_effects_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var active_effects: Dictionary = {}
	for effect_key in snapshot.keys():
		var data: Variant = snapshot[effect_key]
		if not data is Dictionary:
			continue
		var duration_data: Dictionary = data.get("duration", {})
		var duration := DurationSpecScript.new(str(duration_data.get("scope", DurationSpecScript.PERMANENT)), int(duration_data.get("remaining", 0)))
		var effect := ActiveEffectInstanceScript.new(
			str(data.get("definition_id", "")),
			duration,
			StackPolicyScript.new(str(data.get("stack_policy", StackPolicyScript.REPLACE)), int(data.get("max_stacks", 0))),
			str(data.get("source_id", "")),
			int(data.get("stacks", 1)),
			int(data.get("uses_remaining", -1)),
			int(data.get("charges_remaining", -1)),
			str(data.get("instance_id", effect_key)),
			int(data.get("max_stacks", 0)),
			data.get("runtime_parameters", {}),
		)
		effect.remaining = int(duration_data.get("remaining", effect.remaining))
		active_effects[str(effect_key)] = effect
	return active_effects
