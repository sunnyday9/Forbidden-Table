class_name RunModifierEffectResolver
extends RefCounted

const EffectScript = preload("res://src/domain/effects/effect.gd")
const EffectTriggerScript = preload("res://src/domain/effects/effect_trigger.gd")
const EffectOperationFactoryScript = preload("res://src/domain/effects/effect_operation_factory.gd")

func workshop_price(run_state, base_price: int) -> Dictionary:
	var bounded_base := maxi(0, base_price)
	var price := bounded_base
	var adjustments: Array = []
	for modifier in _active_modifiers(run_state):
		var configured_discount := maxi(0, int(modifier.runtime_parameters.get("workshop_price_discount", 0)))
		var discount := mini(price, configured_discount)
		if discount <= 0:
			continue
		price -= discount
		adjustments.append({
			"modifier_id": str(modifier.runtime_parameters.get("modifier_id", "")),
			"effect_id": modifier.definition_id,
			"instance_id": modifier.instance_id,
			"amount": -discount,
		})
	return {
		"base_price": bounded_base,
		"price": maxi(0, price),
		"adjustments": adjustments,
	}

func battle_entry_effects(run_state) -> Array:
	var effects: Array = []
	for modifier in _active_modifiers(run_state):
		var modifier_id := str(modifier.runtime_parameters.get("modifier_id", ""))
		var operation_specs = modifier.runtime_parameters.get("battle_entry_operations", [])
		if not operation_specs is Array:
			continue
		for operation_index in operation_specs.size():
			var operation_spec = operation_specs[operation_index]
			if not operation_spec is Dictionary:
				continue
			var operation = _operation_from_spec(operation_spec)
			if operation == null:
				continue
			var effect_id := "run_modifier.%s" % modifier_id
			if operation_index > 0:
				effect_id += ".%d" % (operation_index + 1)
			effects.append(EffectScript.new(
				effect_id,
				EffectTriggerScript.new(EffectTriggerScript.MANUAL),
				[],
				[],
				[operation],
			))
	return effects

func battle_victory_gold_bonus(run_state) -> int:
	var bonus := 0
	for modifier in _active_modifiers(run_state):
		bonus += maxi(0, int(modifier.runtime_parameters.get("battle_victory_gold", 0)))
	return bonus

func _active_modifiers(run_state) -> Array:
	if run_state == null or not run_state.has_method("active_modifiers"):
		return []
	return run_state.active_modifiers()

func _operation_from_spec(spec: Dictionary):
	var amount := int(spec.get("amount", 0))
	return EffectOperationFactoryScript.create_shared_amount_operation(str(spec.get("operation_id", "")), amount)
