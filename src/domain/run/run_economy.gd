class_name RunEconomy
extends RefCounted

const DomainEventScript = preload("res://src/domain/events/domain_event.gd")

const GOLD := "GOLD"
const REFINEMENT_TOKENS := "REFINEMENT_TOKENS"

const SOURCE_NORMAL_REWARD_SKIP := "NORMAL_REWARD_SKIP"
const SOURCE_ELITE_REWARD := "ELITE_REWARD"
const SOURCE_CONTRACT_SELECTION := "CONTRACT_SELECTION"
const SOURCE_BOSS_REWARD := "BOSS_REWARD"
const SOURCE_HIGH_RISK_CONTENT := "HIGH_RISK_CONTENT"
const SOURCE_SHOP_SPECIAL := "SHOP_SPECIAL"
const SOURCE_RUN_MODIFIER_VICTORY_BONUS := "RUN_MODIFIER_VICTORY_BONUS"

const SINK_SHOP_PURCHASE := "SHOP_PURCHASE"
const SINK_WORKSHOP_SERVICE := "WORKSHOP_SERVICE"
const SINK_EVENT_TRADE := "EVENT_TRADE"
const SINK_RULE_BREAKER_REFINEMENT := "RULE_BREAKER_REFINEMENT"
const SINK_ENEMY_REWARD_TAX := "ENEMY_REWARD_TAX"

const DEFAULT_NORMAL_SKIP_GOLD := 5
const DEFAULT_ELITE_SKIP_GOLD := 10
const DEFAULT_SHOP_OFFER_COUNT := 5
const DEFAULT_SHOP_BASE_REFRESH_ALLOWANCE := 1
const DEFAULT_SHOP_RELIC_PRICE := 10
const DEFAULT_SHOP_TECHNIQUE_PRICE := 12
const DEFAULT_SHOP_SPECIAL_PRICE := 15
const DEFAULT_WORKSHOP_REMOVE_PRICE := 8
const DEFAULT_WORKSHOP_TRANSFORM_PRICE := 10
const DEFAULT_WORKSHOP_MODIFIER_PRICE := 7
const DEFAULT_WORKSHOP_DUPLICATE_PRICE := 12
const DEFAULT_WORKSHOP_REFINEMENT_PRICE := 15
const DEFAULT_WORKSHOP_MINIMUM_POOL_SIZE := 1
const DEFAULT_TILE_COPY_LIMIT := 4

var normal_skip_gold: int
var elite_skip_gold: int
var shop_offer_count: int
var shop_base_refresh_allowance: int
var shop_relic_price: int
var shop_technique_price: int
var shop_special_price: int
var shop_special_prices: Dictionary
var workshop_remove_price: int
var workshop_transform_price: int
var workshop_modifier_price: int
var workshop_duplicate_price: int
var workshop_refinement_price: int
var workshop_minimum_pool_size: int
var tile_copy_limit: int

func _init(
	configured_normal_skip_gold: int = DEFAULT_NORMAL_SKIP_GOLD,
	configured_shop_base_refresh_allowance: int = DEFAULT_SHOP_BASE_REFRESH_ALLOWANCE,
	configured_elite_skip_gold: int = DEFAULT_ELITE_SKIP_GOLD,
) -> void:
	normal_skip_gold = maxi(0, configured_normal_skip_gold)
	elite_skip_gold = maxi(0, configured_elite_skip_gold)
	shop_offer_count = DEFAULT_SHOP_OFFER_COUNT
	shop_base_refresh_allowance = maxi(0, configured_shop_base_refresh_allowance)
	shop_relic_price = DEFAULT_SHOP_RELIC_PRICE
	shop_technique_price = DEFAULT_SHOP_TECHNIQUE_PRICE
	shop_special_price = DEFAULT_SHOP_SPECIAL_PRICE
	shop_special_prices = {
		"base.special.refinement_token": 20,
		"base.special.gold_cache": 8,
		"base.special.workshop_coupon": 7,
		"base.special.copy_license": 15,
		"base.special.ritual_salve": 6,
	}
	workshop_remove_price = DEFAULT_WORKSHOP_REMOVE_PRICE
	workshop_transform_price = DEFAULT_WORKSHOP_TRANSFORM_PRICE
	workshop_modifier_price = DEFAULT_WORKSHOP_MODIFIER_PRICE
	workshop_duplicate_price = DEFAULT_WORKSHOP_DUPLICATE_PRICE
	workshop_refinement_price = DEFAULT_WORKSHOP_REFINEMENT_PRICE
	workshop_minimum_pool_size = DEFAULT_WORKSHOP_MINIMUM_POOL_SIZE
	tile_copy_limit = DEFAULT_TILE_COPY_LIMIT

func apply_source(run_state, currency: String, amount: int, source_id: String) -> Dictionary:
	if run_state == null or amount < 0 or source_id.is_empty() or not _is_currency(currency):
		return {}
	var previous := _read_currency(run_state, currency)
	var current := previous + amount
	_write_currency(run_state, currency, current)
	return _transaction(currency, amount, previous, current, source_id, "")

func apply_sink(run_state, currency: String, amount: int, sink_id: String) -> Dictionary:
	if run_state == null or amount < 0 or sink_id.is_empty() or not _is_currency(currency):
		return {}
	var previous := _read_currency(run_state, currency)
	if previous < amount:
		return {}
	var current := previous - amount
	_write_currency(run_state, currency, current)
	return _transaction(currency, amount, previous, current, "", sink_id)

static func event_for_transaction(transaction: Dictionary):
	var event_type := DomainEventScript.GOLD_CHANGED if transaction.get("currency", "") == GOLD else DomainEventScript.REFINEMENT_TOKENS_CHANGED
	return DomainEventScript.new(event_type, transaction)

func _is_currency(currency: String) -> bool:
	return currency in [GOLD, REFINEMENT_TOKENS]

func _read_currency(run_state, currency: String) -> int:
	return run_state.gold if currency == GOLD else run_state.refinement_tokens

func _write_currency(run_state, currency: String, amount: int) -> void:
	if currency == GOLD:
		run_state.gold = amount
	else:
		run_state.refinement_tokens = amount

func _transaction(
	currency: String,
	amount: int,
	previous: int,
	current: int,
	source_id: String,
	sink_id: String,
) -> Dictionary:
	return {
		"currency": currency,
		"amount": amount,
		"previous": previous,
		"current": current,
		"source_id": source_id,
		"sink_id": sink_id,
	}
