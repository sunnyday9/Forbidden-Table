class_name EffectOperationFactory
extends RefCounted

const GainPressureOperationScript = preload("res://src/domain/effects/operations/gain_pressure_operation.gd")
const GainTPOperationScript = preload("res://src/domain/effects/operations/gain_tp_operation.gd")
const ModifyReserveCapacityOperationScript = preload("res://src/domain/effects/operations/modify_reserve_capacity_operation.gd")
const ModifySettlementCapacityOperationScript = preload("res://src/domain/effects/operations/modify_settlement_capacity_operation.gd")

# Keep this to the amount-based operations shared by catalog Effects and modifier entry specs.
static func create_shared_amount_operation(operation_id: String, amount: int):
	match operation_id:
		"GainPressure":
			return GainPressureOperationScript.new(amount)
		"GainTP":
			return GainTPOperationScript.new(amount)
		"ModifyReserveCapacity":
			return ModifyReserveCapacityOperationScript.new(amount)
		"ModifySettlementCapacity":
			return ModifySettlementCapacityOperationScript.new(amount)
	return null
