class_name RunModifierEffectResolver
extends RefCounted

const EffectScript = preload("res://src/domain/effects/effect.gd")
const EffectTriggerScript = preload("res://src/domain/effects/effect_trigger.gd")
const GainPressureOperationScript = preload("res://src/domain/effects/operations/gain_pressure_operation.gd")
const GainTPOperationScript = preload("res://src/domain/effects/operations/gain_tp_operation.gd")
const ModifyReserveCapacityOperationScript = preload("res://src/domain/effects/operations/modify_reserve_capacity_operation.gd")
const ModifySettlementCapacityOperationScript = preload("res://src/domain/effects/operations/modify_settlement_capacity_operation.gd")

const WORKSHOP_KIT_MODIFIER_ID := "content.base.relic.workshop_kit"
const EVENT_RISK_BARGAIN_MODIFIER_ID := "event.risk_bargain.accept"
const EVENT_CONTRACT_CLAUSE_MODIFIER_ID := "event.contract_clause.apply"
const ACT_TWO_CONTRACT_CLAUSE_MODIFIER_ID := "event.act_two.contract_clause"
const ACT_TWO_RULE_MEMORY_MODIFIER_ID := "event.act_two.rule_memory"
const EVENT_RISK_BARGAIN_VICTORY_GOLD := 2

func workshop_price(run_state, base_price: int) -> Dictionary:
	var bounded_base := maxi(0, base_price)
	var price := bounded_base
	var adjustments: Array = []
	if run_state != null and run_state.has_method("active_modifier"):
		var modifier = run_state.active_modifier(WORKSHOP_KIT_MODIFIER_ID)
		if modifier != null:
			var configured_discount := maxi(0, int(modifier.runtime_parameters.get("value", 0)))
			var discount := mini(bounded_base, configured_discount)
			if discount > 0:
				price -= discount
				adjustments.append({
					"modifier_id": WORKSHOP_KIT_MODIFIER_ID,
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
	var effect_specs := [
		[EVENT_RISK_BARGAIN_MODIFIER_ID, GainPressureOperationScript.new(1)],
		[EVENT_CONTRACT_CLAUSE_MODIFIER_ID, ModifySettlementCapacityOperationScript.new(1)],
		[ACT_TWO_CONTRACT_CLAUSE_MODIFIER_ID, ModifyReserveCapacityOperationScript.new(1)],
		[ACT_TWO_RULE_MEMORY_MODIFIER_ID, GainTPOperationScript.new(1)],
	]
	for effect_spec in effect_specs:
		var modifier_id := str(effect_spec[0])
		if run_state == null or not run_state.has_method("active_modifier") or run_state.active_modifier(modifier_id) == null:
			continue
		var operation = effect_spec[1]
		effects.append(EffectScript.new(
			"run_modifier.%s" % modifier_id,
			EffectTriggerScript.new(EffectTriggerScript.MANUAL),
			[],
			[],
			[operation],
		))
	return effects

func risk_bargain_victory_gold(run_state) -> int:
	if run_state == null or not run_state.has_method("active_modifier"):
		return 0
	return EVENT_RISK_BARGAIN_VICTORY_GOLD if run_state.active_modifier(EVENT_RISK_BARGAIN_MODIFIER_ID) != null else 0
