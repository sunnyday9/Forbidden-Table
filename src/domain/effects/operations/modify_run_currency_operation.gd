class_name ModifyRunCurrencyOperation
extends "res://src/domain/effects/effect_operation.gd"

const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")

var currency: String
var amount: int
var source_id: String

func _init(currency_id: String, delta: int, transaction_source_id: String = "") -> void:
	super("ModifyRunCurrency")
	currency = currency_id
	amount = delta
	source_id = transaction_source_id

func validate(context, _targets: Dictionary) -> String:
	var run_state = _run_state(context)
	if run_state == null:
		return "NO_STATE"
	if currency not in [RunEconomyScript.GOLD, RunEconomyScript.REFINEMENT_TOKENS]:
		return "INVALID_CURRENCY"
	if amount < 0 and _read_currency(run_state) < -amount:
		return "INSUFFICIENT_%s" % currency
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	var run_state = _run_state(context)
	if run_state == null:
		return [_event(DomainEventScript.EFFECT_REJECTED, {
			"effect_id": effect_id,
			"operation_id": operation_id,
			"reason": "NO_RUN_STATE",
			"sequence_index": sequence_index,
		})]
	var economy := RunEconomyScript.new()
	var transaction: Dictionary
	if amount >= 0:
		transaction = economy.apply_source(run_state, currency, amount, source_id if not source_id.is_empty() else RunEconomyScript.SOURCE_HIGH_RISK_CONTENT)
	else:
		transaction = economy.apply_sink(run_state, currency, -amount, RunEconomyScript.SINK_EVENT_TRADE)
	if transaction.is_empty():
		return [_event(DomainEventScript.EFFECT_REJECTED, {
			"effect_id": effect_id,
			"operation_id": operation_id,
			"reason": "CURRENCY_TRANSACTION_REJECTED",
			"currency": currency,
			"amount": amount,
			"sequence_index": sequence_index,
		})]
	transaction["effect_id"] = effect_id
	transaction["sequence_index"] = sequence_index
	var event_type := DomainEventScript.GOLD_CHANGED if currency == RunEconomyScript.GOLD else DomainEventScript.REFINEMENT_TOKENS_CHANGED
	return [_event(event_type, transaction)]

func to_dictionary() -> Dictionary:
	return {
		"operation_id": operation_id,
		"currency": currency,
		"amount": amount,
		"source_id": source_id,
	}

func _read_currency(run_state) -> int:
	return run_state.gold if currency == RunEconomyScript.GOLD else run_state.refinement_tokens

func _run_state(context):
	if context == null:
		return null
	return context.run_state if context.get("run_state") != null else context.state

func _event(event_type: String, data: Dictionary):
	return DomainEventScript.new(event_type, data)
