class_name RunModifierEffectResolver
extends RefCounted

const WORKSHOP_KIT_MODIFIER_ID := "content.base.relic.workshop_kit"

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
