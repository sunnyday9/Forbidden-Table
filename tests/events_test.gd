class_name EventsTest
extends RefCounted

const ApplyRunModifierOperation = preload("res://src/domain/effects/operations/apply_run_modifier_operation.gd")
const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const ChooseEventOptionCommand = preload("res://src/domain/commands/choose_event_option_command.gd")
const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const DurationSpec = preload("res://src/domain/effects/duration_spec.gd")
const Effect = preload("res://src/domain/effects/effect.gd")
const EventDefinition = preload("res://src/content/definitions/event_definition.gd")
const EventState = preload("res://src/domain/run/event_state.gd")
const EnterEventCommand = preload("res://src/domain/commands/enter_event_command.gd")
const ModifyRunCurrencyOperation = preload("res://src/domain/effects/operations/modify_run_currency_operation.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunEconomy = preload("res://src/domain/run/run_economy.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunStartingPoolContentFixture = preload("res://tests/fixtures/run_starting_pool_content_fixture.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const StackPolicy = preload("res://src/domain/effects/stack_policy.gd")

const EVENT_NODE := "base.map_node.event.left"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_event_entry_choice_resolution_and_exit_are_explicit(failures)
	test_invalid_event_choice_is_atomic_and_uses_stable_ids(failures)
	test_event_alternatives_are_deterministic_and_stream_isolated(failures)
	test_run_scoped_contract_modifier_cleans_up_without_leaking(failures)
	test_phase_2_event_identity_contracts_are_explicit(failures)
	return failures

func test_event_entry_choice_resolution_and_exit_are_explicit(failures: Array[String]) -> void:
	var domain := _event_domain("event.transitions", 3301)
	var select = _prepare_event_node(domain, "event.transitions")
	assert_true(select.accepted, "an authored Event map node is selectable", failures)
	var entry = domain.execute(EnterEventCommand.new("event.transitions.enter"))

	assert_true(entry.accepted, "Event entry is accepted at the current Event node", failures)
	assert_true(domain.state.phase == RunPhase.EVENT, "Event entry advances the RunPhase to EVENT", failures)
	assert_true(domain.state.event_state is EventState, "RunState owns authoritative typed EventState", failures)
	assert_true(domain.state.event_state.active, "EventState remains active while a choice is pending", failures)
	assert_true(_has_event(entry.events, DomainEvent.EVENT_ENTERED), "Event entry emits a factual EventEntered event", failures)
	assert_true(_has_event(entry.events, DomainEvent.RUN_PHASE_CHANGED), "Event entry emits an explicit phase transition", failures)

	var before_choice := domain.checkpoint()
	var choice = domain.execute(ChooseEventOptionCommand.new(
		"event.transitions.choose",
		"accept_bargain",
		domain.state.event_state.event_id,
		domain.state.event_state.entry_id,
	))

	assert_true(choice.accepted, "a legal stable Event option is accepted", failures)
	assert_true(choice.before_checkpoint == before_choice, "the choice result exposes the stable before-choice checkpoint", failures)
	assert_true(choice.before_checkpoint["stable_boundary"] == "EVENT_CHOICE_BEFORE", "the before-choice checkpoint is explicitly stable", failures)
	assert_true(choice.state_checkpoint["stable_boundary"] == "MAP_NODE", "the resolved Event returns to a stable Map Node boundary", failures)
	assert_true(domain.state.phase == RunPhase.MAP_CHOICE, "Event resolution exits to Map Choice", failures)
	assert_true(not domain.state.event_state.active and domain.state.event_state.completed, "Event exit completes and clears the active Event", failures)
	assert_true(domain.state.event_state.selected_choice_id == "accept_bargain", "EventState records the stable selected option ID", failures)
	assert_true(_has_event(choice.events, DomainEvent.EVENT_OPTION_CHOSEN), "choice resolution emits a factual EventOptionChosen event", failures)
	assert_true(_has_event(choice.events, DomainEvent.EVENT_RESOLVED), "choice resolution emits a factual EventResolved event", failures)
	assert_true(_has_event(choice.events, DomainEvent.EVENT_EXITED), "Event exit emits a factual EventExited event", failures)
	assert_true(_has_event(choice.events, DomainEvent.RUN_PHASE_CHANGED), "Event exit emits an explicit phase transition", failures)

func test_invalid_event_choice_is_atomic_and_uses_stable_ids(failures: Array[String]) -> void:
	var domain := _event_domain("event.invalid", 3302)
	_prepare_event_node(domain, "event.invalid")
	domain.execute(EnterEventCommand.new("event.invalid.enter"))
	var before := domain.checkpoint()
	var rng_before := domain.rng_snapshot()
	var rejected = domain.execute(ChooseEventOptionCommand.new(
		"event.invalid.choose",
		"choice.index.0",
		domain.state.event_state.event_id,
		domain.state.event_state.entry_id,
	))

	assert_true(not rejected.accepted, "an unknown Event option ID is rejected", failures)
	assert_true(rejected.validation.code == "INVALID_EVENT_OPTION", "unknown Event option rejection is explicit", failures)
	assert_true(rejected.events.is_empty(), "a rejected Event option emits no authoritative events", failures)
	assert_true(domain.checkpoint() == before, "a rejected Event option leaves RunState unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "a rejected Event option leaves every RNG stream unchanged", failures)
	assert_true(not ChooseEventOptionCommand.new("event.ids", "accept_bargain").to_dictionary().has("option_index"), "Event Commands never serialize a UI option index", failures)

func test_event_alternatives_are_deterministic_and_stream_isolated(failures: Array[String]) -> void:
	var first := _event_domain("event.deterministic", 3303)
	var second := _event_domain("event.deterministic", 3303)
	for domain in [first, second]:
		_prepare_event_node(domain, "event.deterministic")
		domain.execute(EnterEventCommand.new("event.deterministic.enter"))
	var first_other_streams := first.rng_snapshot()
	var first_result = first.execute(ChooseEventOptionCommand.new(
		"event.deterministic.choose",
		"accept_bargain",
		first.state.event_state.event_id,
		first.state.event_state.entry_id,
	))
	var second_result = second.execute(ChooseEventOptionCommand.new(
		"event.deterministic.choose",
		"accept_bargain",
		second.state.event_state.event_id,
		second.state.event_state.entry_id,
	))

	assert_true(first_result.accepted and second_result.accepted, "the deterministic alternative choice is accepted in both runs", failures)
	assert_true(first.checkpoint() == second.checkpoint(), "same seed and accepted Event Commands reproduce the complete checkpoint", failures)
	assert_true(first_result.events.map(func(event): return event.to_dictionary()) == second_result.events.map(func(event): return event.to_dictionary()), "same seed reproduces the factual Event alternative trace", failures)
	var second_other_streams := second.rng_snapshot()
	for stream_id in ["combat", "draw_wall", "enemy", "map", "reward", "shop", "cosmetic"]:
		assert_true(first_other_streams["streams"][stream_id] == second_other_streams["streams"][stream_id], "Event resolution does not perturb the %s RNG stream" % stream_id, failures)
	assert_true(first_other_streams["streams"]["event"] != second_other_streams["streams"]["event"], "an accepted alternative advances only the isolated Event stream", failures)

func test_run_scoped_contract_modifier_cleans_up_without_leaking(failures: Array[String]) -> void:
	var domain := _event_domain("event.contract-clause", 3304)
	_prepare_event_node(domain, "event.contract-clause")
	domain.execute(EnterEventCommand.new("event.contract-clause.enter"))
	var result = domain.execute(ChooseEventOptionCommand.new(
		"event.contract-clause.choose",
		"accept_clause",
		domain.state.event_state.event_id,
		domain.state.event_state.entry_id,
	))
	var modifier = domain.state.active_modifier("event.contract_clause")

	assert_true(result.accepted, "a Contract clause choice is accepted", failures)
	assert_true(modifier != null, "the Contract clause installs an active run modifier", failures)
	if modifier != null:
		assert_true(modifier.duration_scope == DurationSpec.RUN, "the Contract modifier declares RUN scope", failures)
		assert_true(modifier.source_id == domain.state.contract_id, "the Contract modifier records its source Contract", failures)
		assert_true(modifier.runtime_parameters.get("modifier_id", "") == "event.contract_clause", "the Contract modifier has an explicit stable modifier ID", failures)

	var cleanup_events = domain.advance_run_boundary(DurationSpec.RUN)
	assert_true(domain.state.active_modifier("event.contract_clause") == null, "RUN-scoped Contract modifiers clean up at the run boundary", failures)
	assert_true(_has_event(cleanup_events, DomainEvent.EFFECT_EXPIRED), "Contract modifier cleanup emits a factual lifecycle event", failures)
	var fresh_domain := _event_domain("event.contract-clause.fresh", 3304)
	assert_true(fresh_domain.state.active_effects.is_empty(), "a new RunState cannot inherit a prior run's Contract modifier", failures)

func test_phase_2_event_identity_contracts_are_explicit(failures: Array[String]) -> void:
	var expected := [
		"base.event.tile_surgery",
		"base.event.risk_bargain",
		"base.event.gold_exchange",
		"base.event.map_reveal",
		"base.event.contract_clause",
		"base.event.rule_memory",
	]
	assert_true(EventDefinition.PHASE_2_EVENT_IDS == expected, "the six Phase 2 Event identities are explicit stable content contracts", failures)
	for contract in EventDefinition.phase_2_content_contracts():
		assert_true(contract.get("event_id", "") in expected, "each Event content contract uses a stable Phase 2 Event ID", failures)
		assert_true(int(contract.get("minimum_choice_count", 0)) >= 2, "each Event content contract requires systemic choice coverage", failures)
		assert_true(bool(contract.get("systemic_trade", false)), "each Event content contract declares a systemic trade", failures)
		assert_true(not str(contract.get("required_behavior", "")).is_empty(), "each Event content contract declares its required systemic behavior", failures)

func _event_domain(run_id: String, seed: int) -> RunDomain:
	var domain := RunDomain.new(run_id, seed, _registry())
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	domain.state.gold = 5
	return domain

func _prepare_event_node(domain: RunDomain, command_prefix: String):
	domain.execute(SelectMapNodeCommand.new("%s.left" % command_prefix, "base.map_node.normal.left"))
	var result = domain.execute(SelectMapNodeCommand.new("%s.event" % command_prefix, EVENT_NODE))
	if result.accepted:
		domain.state.map_state.payload_ids[EVENT_NODE] = "base.event.risk_bargain"
	return result

func _registry() -> ContentRegistry:
	var registry := ContentRegistry.new()
	RunStartingPoolContentFixture.register_character_starting_pool_tiles(registry)
	registry.register(ContentDefinition.new("base.relic.open_hand"))
	registry.register(ContentDefinition.new("base.technique.core.sequence_line"))
	registry.register(ContentDefinition.new("base.passive.sequence"))
	registry.register(CharacterDefinition.new(
		"base.character.sequence",
		RunStartingPoolContentFixture.character_tile_pool_bias(),
		"base.relic.open_hand",
		"base.technique.core.sequence_line",
		"base.passive.sequence",
	))
	registry.register(ContractDefinition.new("base.contract.pressure", ContractDefinition.PRESSURE, {"pressure": 1}, {"draw_actions": 1}))
	registry.register(EventDefinition.new("base.event.risk_bargain", [
		{
			"choice_id": "accept_bargain",
			"label": "Take the wager",
			"effects": [Effect.new("event.bargain.cost", null, [], [], [ModifyRunCurrencyOperation.new(RunEconomy.GOLD, -3, "event.risk_bargain")])],
			"alternatives": [
				{"alternative_id": "favorable", "weight": 1, "effects": [Effect.new("event.bargain.reward", null, [], [], [ModifyRunCurrencyOperation.new(RunEconomy.GOLD, 8, "event.risk_bargain")])]},
				{"alternative_id": "backfire", "weight": 1, "effects": [Effect.new("event.bargain.penalty", null, [], [], [ModifyRunCurrencyOperation.new(RunEconomy.GOLD, -2, "event.risk_bargain")])]},
			],
		},
		{"choice_id": "accept_clause", "label": "Carry the clause", "effects": [Effect.new("event.contract.clause", null, [], [], [ApplyRunModifierOperation.new("event.contract_clause", 1, DurationSpec.new(DurationSpec.RUN, 1), StackPolicy.REPLACE, "base.contract.pressure")])]},
		{"choice_id": "leave", "label": "Leave", "is_skip": true, "effects": []},
	]))
	registry.register(EventDefinition.new("base.event.gold_exchange", [
		{"choice_id": "accept_bargain", "label": "Trade Gold", "effects": []},
		{"choice_id": "leave", "label": "Leave", "is_skip": true, "effects": []},
	]))
	return registry

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
