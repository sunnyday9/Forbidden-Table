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
const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ActiveEffectInstance = preload("res://src/domain/effects/active_effect_instance.gd")
const MiniActMapCatalog = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const ModifyRunCurrencyOperation = preload("res://src/domain/effects/operations/modify_run_currency_operation.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunEconomy = preload("res://src/domain/run/run_economy.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunStartingPoolContentFixture = preload("res://tests/fixtures/run_starting_pool_content_fixture.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const SaveCoordinator = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const ReplayRecord = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifier = preload("res://src/infrastructure/replay/replay_verifier.gd")
const StackPolicy = preload("res://src/domain/effects/stack_policy.gd")
const DurationSpecScope = preload("res://src/domain/effects/duration_spec.gd")

const EVENT_NODE := "base.map_node.event.left"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_event_entry_choice_resolution_and_exit_are_explicit(failures)
	test_invalid_event_choice_is_atomic_and_uses_stable_ids(failures)
	test_event_alternatives_are_deterministic_and_stream_isolated(failures)
	test_run_scoped_contract_modifier_cleans_up_without_leaking(failures)
	test_phase_2_event_identity_contracts_are_explicit(failures)
	test_existing_event_payloads_remain_act_eligible(failures)
	test_new_production_events_are_act_eligible_and_replayable(failures)
	test_act_two_event_families_are_deterministic_typed_and_resumable(failures)
	test_act_two_event_entry_uses_restored_map_definition(failures)
	test_event_modifier_save_fixtures_include_completed_intro(failures)
	test_base_event_modifiers_change_battleplay_and_expire(failures)
	test_act_two_event_modifiers_change_battleplay_and_expire(failures)
	test_event_modifier_labels_explain_their_effects(failures)
	test_unknown_event_modifier_has_no_invented_battle_effect(failures)
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

func test_new_production_events_are_act_eligible_and_replayable(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{
			"event_id": "alpha.event.act_one.tile_surgery",
			"act_index": 1,
			"event_node_id": "base.map_node.event.left",
			"branch_node_id": "base.map_node.normal.left",
			"choice_id": "trade_gold",
			"effect_kind": "CURRENCY",
			"gold_delta": -2,
			"token_delta": 1,
		},
		{
			"event_id": "alpha.event.act_one.risk_bargain",
			"act_index": 1,
			"event_node_id": "base.map_node.event.left",
			"branch_node_id": "base.map_node.normal.left",
			"choice_id": "take_advance",
			"effect_kind": "GOLD_CHANGES",
			"token_delta": -1,
			"allowed_gold_deltas": [6, -2],
		},
		{
			"event_id": "alpha.event.act_one.gold_exchange",
			"act_index": 1,
			"event_node_id": "base.map_node.event.left",
			"branch_node_id": "base.map_node.normal.left",
			"choice_id": "exchange",
			"effect_kind": "CURRENCY",
			"gold_delta": -3,
			"token_delta": 1,
		},
		{
			"event_id": "alpha.event.act_one.map_reveal",
			"act_index": 1,
			"event_node_id": "base.map_node.event.right",
			"branch_node_id": "base.map_node.normal.right",
			"choice_id": "reveal_route",
			"effect_kind": "MAP_REVEAL",
			"revealed_node_id": "base.map_node.boss",
		},
		{
			"event_id": "alpha.event.act_one.contract_clause",
			"act_index": 1,
			"event_node_id": "base.map_node.event.right",
			"branch_node_id": "base.map_node.normal.right",
			"choice_id": "carry_clause",
			"effect_kind": "RUN_MODIFIER",
			"modifier_id": "event.contract_clause.apply",
			"modifier_scope": "RUN",
		},
		{
			"event_id": "alpha.event.act_one.rule_memory",
			"act_index": 1,
			"event_node_id": "base.map_node.event.right",
			"branch_node_id": "base.map_node.normal.right",
			"choice_id": "remember_rule",
			"effect_kind": "RUN_MODIFIER_AND_TOKEN",
			"modifier_id": "event.act_two.rule_memory",
			"modifier_scope": "RUN",
			"token_delta": 1,
		},
		{
			"event_id": "alpha.event.act_two.tile_surgery.sealed_entry",
			"act_index": 2,
			"event_node_id": "base.map_node.act_two.event.left",
			"branch_node_id": "base.map_node.act_two.normal.left",
			"choice_id": "repair_with_token",
			"effect_kind": "CURRENCY",
			"gold_delta": 3,
			"token_delta": -1,
		},
		{
			"event_id": "alpha.event.act_two.risk_bargain.shadow_account",
			"act_index": 2,
			"event_node_id": "base.map_node.act_two.event.left",
			"branch_node_id": "base.map_node.act_two.normal.left",
			"choice_id": "stake_hidden_account",
			"effect_kind": "GOLD_CHANGES",
			"allowed_gold_deltas": [3, -5],
		},
		{
			"event_id": "alpha.event.act_two.gold_exchange.long_margin",
			"act_index": 2,
			"event_node_id": "base.map_node.act_two.event.left",
			"branch_node_id": "base.map_node.act_two.normal.left",
			"choice_id": "trade_margin",
			"effect_kind": "CURRENCY",
			"gold_delta": -6,
			"token_delta": 2,
		},
		{
			"event_id": "alpha.event.act_two.map_reveal.final_annotation",
			"act_index": 2,
			"event_node_id": "base.map_node.act_two.event.right",
			"branch_node_id": "base.map_node.act_two.normal.right",
			"choice_id": "reveal_route",
			"effect_kind": "MAP_REVEAL",
			"revealed_node_id": "base.map_node.act_two.boss",
		},
		{
			"event_id": "alpha.event.act_two.contract_clause.amended_clause",
			"act_index": 2,
			"event_node_id": "base.map_node.act_two.event.right",
			"branch_node_id": "base.map_node.act_two.normal.right",
			"choice_id": "carry_clause",
			"effect_kind": "RUN_MODIFIER",
			"modifier_id": "event.act_two.contract_clause",
			"modifier_scope": "ACT",
		},
		{
			"event_id": "alpha.event.act_two.rule_memory.cross_reference",
			"act_index": 2,
			"event_node_id": "base.map_node.act_two.event.right",
			"branch_node_id": "base.map_node.act_two.normal.right",
			"choice_id": "cross_reference",
			"effect_kind": "RUN_MODIFIER_AND_TOKEN",
			"modifier_id": "event.act_two.rule_memory",
			"modifier_scope": "RUN",
			"token_delta": 1,
		},
	]
	_assert_new_production_event_cases(cases, failures)

func test_existing_event_payloads_remain_act_eligible(failures: Array[String]) -> void:
	var registry := _production_event_registry()
	var event_cases: Array[Dictionary] = [
		{"event_id": "base.event.tile_surgery", "act_index": 1, "event_node_id": "base.map_node.event.left"},
		{"event_id": "base.event.risk_bargain", "act_index": 1, "event_node_id": "base.map_node.event.left"},
		{"event_id": "base.event.gold_exchange", "act_index": 1, "event_node_id": "base.map_node.event.left"},
		{"event_id": "base.event.map_reveal", "act_index": 1, "event_node_id": "base.map_node.event.right"},
		{"event_id": "base.event.contract_clause", "act_index": 1, "event_node_id": "base.map_node.event.right"},
		{"event_id": "base.event.rule_memory", "act_index": 1, "event_node_id": "base.map_node.event.right"},
		{"event_id": "alpha.event.act_two.tile_surgery", "act_index": 2, "event_node_id": "base.map_node.act_two.event.left"},
		{"event_id": "alpha.event.act_two.risk_bargain", "act_index": 2, "event_node_id": "base.map_node.act_two.event.left"},
		{"event_id": "alpha.event.act_two.gold_exchange", "act_index": 2, "event_node_id": "base.map_node.act_two.event.left"},
		{"event_id": "alpha.event.act_two.map_reveal", "act_index": 2, "event_node_id": "base.map_node.act_two.event.right"},
		{"event_id": "alpha.event.act_two.contract_clause", "act_index": 2, "event_node_id": "base.map_node.act_two.event.right"},
		{"event_id": "alpha.event.act_two.rule_memory", "act_index": 2, "event_node_id": "base.map_node.act_two.event.right"},
	]
	for event_case in event_cases:
		var event_id := str(event_case["event_id"])
		var act_index := int(event_case["act_index"])
		var event_node_id := str(event_case["event_node_id"])
		var map_definition = MiniActMapCatalog.definition_for_act(act_index, registry)
		var event_node = map_definition.node_definition(event_node_id)
		assert_true(event_node != null and event_node.payload_options.has(event_id), "%s remains eligible on its authored Act %d map" % [event_id, act_index], failures)
		assert_true(registry.resolve(event_id) is EventDefinition, "%s remains a registered EventDefinition" % event_id, failures)

func _assert_new_production_event_cases(cases: Array[Dictionary], failures: Array[String]) -> void:
	for event_index in cases.size():
		var event_case: Dictionary = cases[event_index]
		var act_index := int(event_case["act_index"])
		var event_id := str(event_case["event_id"])
		var event_node_id := str(event_case["event_node_id"])
		var branch_node_id := str(event_case["branch_node_id"])
		var registry := _production_event_registry()
		var domain := _production_event_domain("event.production.%d" % event_index, 7560 + event_index, act_index, registry)
		var event_node = domain.map_definition.node_definition(event_node_id)
		assert_true(event_node != null and event_node.payload_options.has(event_id), "%s is eligible at its authored Act %d Event node" % [event_id, act_index], failures)
		var other_map = MiniActMapCatalog.definition_for_act(3 - act_index, registry)
		var other_event_node_id := "base.map_node.event.left" if act_index == 2 else "base.map_node.act_two.event.left"
		var other_event_node = other_map.node_definition(other_event_node_id)
		assert_true(other_event_node != null and not other_event_node.payload_options.has(event_id), "%s is not eligible in the other Act" % event_id, failures)
		var definition = registry.resolve(event_id)
		assert_true(definition is EventDefinition, "%s is a registered production EventDefinition" % event_id, failures)
		if event_node == null or not event_node.payload_options.has(event_id) or not definition is EventDefinition:
			continue
		assert_true(
			definition.legal_choice_ids().has(str(event_case["choice_id"])) and definition.legal_choice_ids().has("leave"),
			"%s declares its stable primary choice and explicit Leave choice" % event_id,
			failures,
		)
		var choices_before: int = domain.state.refinement_tokens
		var gold_before: int = domain.state.gold
		domain.state.map_state.select_node(branch_node_id, domain.map_definition)
		domain.state.map_state.payload_ids[event_node_id] = event_id
		domain.state.map_state.select_node(event_node_id, domain.map_definition)
		domain.state.phase = RunPhase.MAP_CHOICE
		var entry = domain.execute(EnterEventCommand.new("event.production.%d.enter" % event_index))
		assert_true(entry.accepted and domain.state.event_state.event_id == event_id, "%s enters through its authored map payload" % event_id, failures)
		if not entry.accepted:
			continue
		var saved = SaveCoordinator.new().save(domain)
		assert_true(saved.accepted, "%s saves at the pending Event choice boundary" % event_id, failures)
		if not saved.accepted:
			continue
		var resumed = SaveMapper.load_into_domain(saved.snapshot.to_dictionary(), registry)
		assert_true(resumed.accepted, "%s restores the pending Event choice" % event_id, failures)
		if not resumed.accepted:
			continue
		var resumed_domain: RunDomain = resumed.domain
		assert_true(resumed_domain.state.event_state.event_id == event_id, "%s keeps its stable identity after restore" % event_id, failures)
		var replay_start: Dictionary = resumed_domain.checkpoint()
		var replay_record := ReplayRecord.new(resumed_domain.state.seed, resumed_domain.state.content_version, resumed_domain.state.run_id)
		resumed_domain.replay_record = replay_record
		resumed_domain.replay_record.record_initial_checkpoint(replay_start, resumed_domain.rng_snapshot(), "ONGOING")
		var choice = resumed_domain.execute(ChooseEventOptionCommand.new(
			"event.production.%d.choose" % event_index,
			str(event_case["choice_id"]),
			event_id,
			resumed_domain.state.event_state.entry_id,
		))
		assert_true(choice.accepted, "%s accepts its typed choice after restore (status=%s message=%s data=%s)" % [event_id, choice.status, choice.message, JSON.stringify(choice.data)], failures)
		if choice.accepted:
			match str(event_case["effect_kind"]):
				"CURRENCY":
					assert_true(resumed_domain.state.gold == gold_before + int(event_case["gold_delta"]), "%s applies its authored Gold effect" % event_id, failures)
					assert_true(resumed_domain.state.refinement_tokens == choices_before + int(event_case["token_delta"]), "%s applies its authored Refinement Token effect" % event_id, failures)
				"GOLD_CHANGES":
					var gold_delta: int = resumed_domain.state.gold - gold_before
					assert_true(event_case.get("allowed_gold_deltas", []).has(gold_delta), "%s resolves one of its deterministic wager outcomes" % event_id, failures)
					_assert_production_event_wager_outcomes(event_case, event_index, registry, failures)
					if event_case.has("token_delta"):
						assert_true(resumed_domain.state.refinement_tokens == choices_before + int(event_case["token_delta"]), "%s applies its authored Refinement Token stake" % event_id, failures)
				"MAP_REVEAL":
					assert_true(resumed_domain.state.map_state.knowledge_state.get(str(event_case["revealed_node_id"]), "") == "EXACT", "%s reveals its authored route node" % event_id, failures)
				"RUN_MODIFIER":
					var clause_modifier = resumed_domain.state.active_modifier(str(event_case["modifier_id"]))
					assert_true(clause_modifier != null, "%s applies its authored modifier" % event_id, failures)
					if clause_modifier != null and event_case.has("modifier_scope"):
						assert_true(clause_modifier.duration_scope == str(event_case["modifier_scope"]) and clause_modifier.remaining == 1, "%s keeps its authored modifier scope" % event_id, failures)
				"RUN_MODIFIER_AND_TOKEN":
					var memory_modifier = resumed_domain.state.active_modifier(str(event_case["modifier_id"]))
					assert_true(memory_modifier != null, "%s applies its authored modifier" % event_id, failures)
					if memory_modifier != null and event_case.has("modifier_scope"):
						assert_true(memory_modifier.duration_scope == str(event_case["modifier_scope"]) and memory_modifier.remaining == 1, "%s keeps its authored modifier scope" % event_id, failures)
					assert_true(resumed_domain.state.refinement_tokens == choices_before + int(event_case["token_delta"]), "%s applies its authored Refinement Token effect" % event_id, failures)
		var saved_state: Dictionary = saved.snapshot.to_dictionary()
		var replay_factory: Callable = func(_seed: int, _content_version: String):
			var replay_loaded = SaveMapper.load_into_domain(saved_state, registry)
			return replay_loaded.domain if replay_loaded.accepted else null
		var replay_report = ReplayVerifier.verify(replay_record, replay_factory, resumed_domain.state.content_version)
		assert_true(replay_report.is_match(), "%s accepted Event choice replays from the restored checkpoint" % event_id, failures)
		var skip_domain := _production_event_domain("event.production.%d.skip" % event_index, 7660 + event_index, act_index, registry)
		skip_domain.state.map_state.select_node(branch_node_id, skip_domain.map_definition)
		skip_domain.state.map_state.payload_ids[event_node_id] = event_id
		skip_domain.state.map_state.select_node(event_node_id, skip_domain.map_definition)
		skip_domain.state.phase = RunPhase.MAP_CHOICE
		var skip_entry = skip_domain.execute(EnterEventCommand.new("event.production.%d.skip.enter" % event_index))
		assert_true(skip_entry.accepted, "%s also opens for its explicit Leave choice" % event_id, failures)
		if not skip_entry.accepted:
			continue
		var skip_gold_before: int = skip_domain.state.gold
		var skip_tokens_before: int = skip_domain.state.refinement_tokens
		var skip_effects_before: Dictionary = skip_domain.state.active_effects.duplicate(true)
		var skipped = skip_domain.execute(ChooseEventOptionCommand.new(
			"event.production.%d.skip.choose" % event_index,
			"leave",
			event_id,
			skip_domain.state.event_state.entry_id,
		))
		assert_true(skipped.accepted, "%s accepts its explicit Leave choice" % event_id, failures)
		assert_true(skip_domain.state.gold == skip_gold_before and skip_domain.state.refinement_tokens == skip_tokens_before and skip_domain.state.active_effects == skip_effects_before, "%s Leave choice has no gameplay effect" % event_id, failures)

func _assert_production_event_wager_outcomes(event_case: Dictionary, event_index: int, registry: ContentRegistry, failures: Array[String]) -> void:
	var act_index := int(event_case["act_index"])
	var event_id := str(event_case["event_id"])
	var branch_node_id := str(event_case["branch_node_id"])
	var event_node_id := str(event_case["event_node_id"])
	var choice_id := str(event_case["choice_id"])
	var expected_deltas: Array = event_case.get("allowed_gold_deltas", [])
	var exercised_deltas: Dictionary = {}
	for seed in range(1, 33):
		if exercised_deltas.size() == expected_deltas.size():
			break
		var domain := _production_event_domain("event.production.wager.%d.%d" % [event_index, seed], seed, act_index, registry)
		domain.state.map_state.select_node(branch_node_id, domain.map_definition)
		domain.state.map_state.payload_ids[event_node_id] = event_id
		domain.state.map_state.select_node(event_node_id, domain.map_definition)
		domain.state.phase = RunPhase.MAP_CHOICE
		var entry = domain.execute(EnterEventCommand.new("event.production.wager.%d.%d.enter" % [event_index, seed]))
		if not entry.accepted:
			continue
		var gold_before: int = domain.state.gold
		var choice = domain.execute(ChooseEventOptionCommand.new(
			"event.production.wager.%d.%d.choose" % [event_index, seed],
			choice_id,
			event_id,
			domain.state.event_state.entry_id,
		))
		if not choice.accepted:
			continue
		var gold_delta: int = domain.state.gold - gold_before
		if expected_deltas.has(gold_delta):
			exercised_deltas[gold_delta] = true
	for expected_delta in expected_deltas:
		assert_true(exercised_deltas.has(expected_delta), "%s exercises authored wager outcome %+d Gold" % [event_id, int(expected_delta)], failures)

func test_act_two_event_families_are_deterministic_typed_and_resumable(failures: Array[String]) -> void:
	var expected_event_ids := [
		"alpha.event.act_two.tile_surgery",
		"alpha.event.act_two.risk_bargain",
		"alpha.event.act_two.gold_exchange",
		"alpha.event.act_two.map_reveal",
		"alpha.event.act_two.contract_clause",
		"alpha.event.act_two.rule_memory",
	]
	var first_map_domain := _act_two_event_domain("event.act-two.same-seed", 7410)
	var second_map_domain := _act_two_event_domain("event.act-two.same-seed", 7410)
	assert_true(first_map_domain.state.map_state.payload_ids == second_map_domain.state.map_state.payload_ids, "same seed deterministically selects the same Act 2 Event payloads", failures)
	var mapped_event_ids: Dictionary = {}
	for node_id in ["base.map_node.act_two.event.left", "base.map_node.act_two.event.right"]:
		var node = first_map_domain.map_definition.node_definition(node_id)
		for payload_id in node.payload_options:
			mapped_event_ids[payload_id] = true
	for event_id in expected_event_ids:
		assert_true(mapped_event_ids.has(event_id), "%s remains an Act 2 Event payload alternative" % event_id, failures)

	for event_index in expected_event_ids.size():
		var event_id: String = expected_event_ids[event_index]
		var domain := _act_two_event_domain("event.act-two.family.%d" % event_index, 7420 + event_index)
		var entry = _prepare_act_two_event(domain, event_id, "event.act-two.family.%d" % event_index)
		assert_true(entry.accepted, "%s enters through its authored Act 2 Event node" % event_id, failures)
		assert_true(domain.state.event_state.event_id == event_id, "%s is the exact reachable Event identity" % event_id, failures)
		var saved = SaveCoordinator.new().save(domain)
		assert_true(saved.accepted, "%s saves at the stable Act 2 Event choice boundary" % event_id, failures)
		if not saved.accepted:
			continue
		var resumed = SaveMapper.load_into_domain(saved.snapshot.to_dictionary(), domain.content_registry)
		assert_true(resumed.accepted, "%s resumes from the pending stable Event boundary" % event_id, failures)
		if not resumed.accepted:
			continue
		var resumed_domain = resumed.domain
		assert_true(resumed_domain.state.event_state.event_id == event_id and resumed_domain.state.map_state.map_definition_id == "base.map.act_two", "%s keeps the active Event and Act 2 map identity after resume" % event_id, failures)
		var before_gold: int = resumed_domain.state.gold
		var before_tokens: int = resumed_domain.state.refinement_tokens
		var choice_id := _act_two_event_choice_id(event_id)
		var choice_command := ChooseEventOptionCommand.new(
			"event.act-two.family.%d.choose" % event_index,
			choice_id,
			resumed_domain.state.event_state.event_id,
			resumed_domain.state.event_state.entry_id,
		)
		var replay_start: Dictionary = resumed_domain.checkpoint()
		var replay_record := ReplayRecord.new(resumed_domain.state.seed, resumed_domain.state.content_version, resumed_domain.state.run_id)
		resumed_domain.replay_record = replay_record
		resumed_domain.replay_record.record_initial_checkpoint(replay_start, resumed_domain.rng_snapshot(), "ONGOING")
		var result = resumed_domain.execute(choice_command)
		assert_true(result.accepted, "%s resolves its typed choice after resume" % event_id, failures)
		match event_id:
			"alpha.event.act_two.tile_surgery":
				assert_true(resumed_domain.state.refinement_tokens == before_tokens - 1, "Act 2 Tile Surgery spends a Refinement Token", failures)
			"alpha.event.act_two.risk_bargain":
				assert_true(resumed_domain.state.gold != before_gold, "Act 2 Risk Bargain resolves its Gold risk and reward", failures)
			"alpha.event.act_two.gold_exchange":
				assert_true(resumed_domain.state.gold == before_gold - 4 and resumed_domain.state.refinement_tokens == before_tokens + 1, "Act 2 Gold Exchange trades Gold for a Refinement Token", failures)
			"alpha.event.act_two.map_reveal":
				assert_true(resumed_domain.state.map_state.knowledge_state.get("base.map_node.act_two.boss", "") == "EXACT", "Act 2 Map Reveal exposes the terminal route", failures)
			"alpha.event.act_two.contract_clause":
				var clause = resumed_domain.state.active_modifier("event.act_two.contract_clause")
				assert_true(clause != null, "Act 2 Contract Clause installs its modifier", failures)
				if clause != null:
					assert_true(clause.duration_scope == "ACT" and clause.remaining == 1, "Act 2 Contract Clause lasts for one Act", failures)
			"alpha.event.act_two.rule_memory":
				var memory = resumed_domain.state.active_modifier("event.act_two.rule_memory")
				assert_true(memory != null and resumed_domain.state.refinement_tokens == before_tokens + 1, "Act 2 Rule Memory records a Run modifier and grants a Refinement Token", failures)
		var saved_state: Dictionary = saved.snapshot.to_dictionary()
		var replay_factory: Callable = func(_seed: int, _content_version: String):
			var replay_loaded = SaveMapper.load_into_domain(saved_state, domain.content_registry)
			return replay_loaded.domain if replay_loaded.accepted else null
		var replay_report = ReplayVerifier.verify(resumed_domain.replay_record, replay_factory, resumed_domain.state.content_version)
		assert_true(replay_report.is_match(), "%s accepted choice replays from the stable Event checkpoint" % event_id, failures)

func test_act_two_event_entry_uses_restored_map_definition(failures: Array[String]) -> void:
	var source := _act_two_event_domain("event.act-two.entry-resume", 7440)
	var event_node_id := "base.map_node.act_two.event.right"
	var branch_node_id := "base.map_node.act_two.normal.right"
	var event_id := "alpha.event.act_two.map_reveal"
	if source.state.map_state.visited_node_ids.is_empty():
		# This fixture represents a completed intro entry when starting from the
		# intro worker's pending-entry shape; ordinary tests use the pre-entry form.
		var intro_node_id: String = source.state.map_state.current_node_id
		if intro_node_id.is_empty():
			intro_node_id = source.map_definition.start_node_id
			source.state.map_state.current_node_id = intro_node_id
		source.state.map_state.visited_node_ids.append(intro_node_id)
		source.state.map_state.ordered_path.append(intro_node_id)
		source.state.map_state.knowledge_state[intro_node_id] = "EXACT"
	source.state.map_state.select_node(branch_node_id, source.map_definition)
	source.state.map_state.payload_ids[event_node_id] = event_id
	source.state.map_state.select_node(event_node_id, source.map_definition)
	assert_true(source.state.map_state.ordered_path[0] == source.map_definition.start_node_id and source.state.map_state.ordered_path.size() == 3, "the saved fixture records a continuous path from the completed Act 2 intro", failures)
	var snapshot = SaveMapper.suspend_snapshot(source)
	var restored = SaveMapper.load_into_domain(snapshot.to_dictionary(), source.content_registry)
	assert_true(restored.accepted, "a Map Choice checkpoint on the Act 2 Event node restores", failures)
	if not restored.accepted:
		return
	var restored_domain = restored.domain
	assert_true(restored_domain.map_definition.content_id == "base.map.act_two", "restored RunDomain binds the Act 2 map before Event entry", failures)
	var entry = restored_domain.execute(EnterEventCommand.new("event.act-two.entry-resume.enter"))
	assert_true(entry.accepted, "the restored Act 2 Event node accepts Event entry", failures)
	assert_true(restored_domain.state.event_state.event_id == event_id, "restored entry resolves the authored Act 2 Event payload", failures)
	var choice = restored_domain.execute(ChooseEventOptionCommand.new(
		"event.act-two.entry-resume.choose",
		"reveal_route",
		event_id,
		restored_domain.state.event_state.entry_id,
	))
	assert_true(choice.accepted, "the restored Act 2 Event accepts a choice", failures)
	assert_true(restored_domain.state.map_state.knowledge_state.get("base.map_node.act_two.boss", "") == "EXACT", "the restored Act 2 Map Reveal applies to the active map", failures)
	assert_true(source.state.event_state.active == false and source.state.map_state.knowledge_state.get("base.map_node.act_two.boss", "") != "EXACT", "post-resume Event commands do not mutate the pre-load RunState", failures)

func test_event_modifier_save_fixtures_include_completed_intro(failures: Array[String]) -> void:
	var registry := _event_effect_registry(true)
	var cases: Array = [
		{"run_id": "event.fixture.act-one", "seed": 7439, "event_id": "base.event.risk_bargain", "act_two": false},
		{"run_id": "event.fixture.act-two", "seed": 7440, "event_id": "alpha.event.act_two.contract_clause", "act_two": true},
	]
	for fixture in cases:
		var domain := _prepared_event_modifier_domain(
			str(fixture["run_id"]),
			int(fixture["seed"]),
			registry,
			str(fixture["event_id"]),
			bool(fixture["act_two"]),
		)
		var path: Array = domain.state.map_state.ordered_path
		assert_true(path.size() == 3 and path[0] == domain.map_definition.start_node_id,
			"%s Event modifier save fixture records the completed mandatory intro before branch and Event" % fixture["run_id"], failures)

func test_base_event_modifiers_change_battleplay_and_expire(failures: Array[String]) -> void:
	var registry := _event_effect_registry(false)
	var risk_domain := _prepared_event_modifier_domain("event.modifier.risk", 7441, registry, "base.event.risk_bargain", false)
	var risk_baseline := _prepared_event_modifier_domain("event.modifier.risk.baseline", 7441, registry, "base.event.risk_bargain", false)
	assert_true(_choose_event_modifier(risk_domain, "accept"), "Risk Bargain installs its Run modifier", failures)
	assert_true(_choose_event_modifier(risk_baseline, "leave"), "the Risk Bargain comparison run can decline", failures)
	var risk_entry = risk_domain.execute(SelectMapNodeCommand.new("event.modifier.risk.battle", "base.map_node.normal.mid"))
	var risk_baseline_entry = risk_baseline.execute(SelectMapNodeCommand.new("event.modifier.risk.baseline.battle", "base.map_node.normal.mid"))
	assert_true(risk_entry.accepted and risk_baseline_entry.accepted, "Risk Bargain and comparison runs enter the same later battle", failures)
	if risk_entry.accepted and risk_baseline_entry.accepted:
		assert_true(risk_domain.current_battle.combat_state.pressure == risk_baseline.current_battle.combat_state.pressure + 1, "Risk Bargain adds one starting Pressure to a later battle", failures)
		assert_true(_has_effect_event(risk_entry.events, DomainEvent.PRESSURE_CHANGED, "run_modifier.event.risk_bargain.accept"), "Risk Bargain starting Pressure has a causal battle-entry event", failures)
		var checkpoint_after_entry: Dictionary = risk_domain.checkpoint()
		var rng_after_entry: Dictionary = risk_domain.rng_snapshot()
		var saved = SaveCoordinator.new().save(risk_domain)
		assert_true(saved.accepted, "the battle entered under Risk Bargain can be saved", failures)
		if saved.accepted:
			var resumed = SaveMapper.load_into_domain(saved.snapshot.to_dictionary(), registry)
			assert_true(resumed.accepted, "the Risk Bargain battle resumes", failures)
			if resumed.accepted:
				assert_true(resumed.domain.current_battle.combat_state.pressure == risk_domain.current_battle.combat_state.pressure, "resume does not apply starting Pressure twice", failures)
				assert_true(resumed.domain.checkpoint() == checkpoint_after_entry and resumed.domain.rng_snapshot() == rng_after_entry, "Risk Bargain resume preserves the entry checkpoint and RNG", failures)
		var replay_factory: Callable = func(seed: int, _version: String):
			return _prepared_event_modifier_domain("event.modifier.risk", seed, registry, "base.event.risk_bargain", false)
		var replay = ReplayVerifier.verify(risk_domain.replay_record, replay_factory, risk_domain.state.content_version)
		assert_true(replay.is_match(), "Risk Bargain choice and battle entry replay with the same effect events", failures)
		var gold_before_victory: int = risk_domain.state.gold
		var victory = risk_domain.current_battle.combat_resolver.resolve_player_action(risk_domain.current_battle.combat_state, 17)
		assert_true(victory.terminal_outcome == CombatState.VICTORY, "the Risk Bargain fixture reaches a battle victory", failures)
		var victory_events: Array = risk_domain.apply_battle_outcome()
		assert_true(risk_domain.state.gold == gold_before_victory + 2, "Risk Bargain grants two Gold on a subsequent victory", failures)
		assert_true(_has_currency_event(victory_events, DomainEvent.GOLD_CHANGED, RunEconomy.GOLD, "EVENT_RISK_BARGAIN_VICTORY", 2), "the Risk Bargain victory payout has a causal GoldChanged event", failures)
		var post_victory_gold: int = risk_domain.state.gold
		risk_domain.apply_battle_outcome()
		assert_true(risk_domain.state.gold == post_victory_gold, "transferring one victory twice cannot duplicate the Risk Bargain payout", failures)
		var saved_victory = SaveCoordinator.new().save(risk_domain)
		assert_true(saved_victory.accepted, "the Risk Bargain victory payout can be saved at its reward boundary", failures)
		if saved_victory.accepted:
			var resumed_victory = SaveMapper.load_into_domain(saved_victory.snapshot.to_dictionary(), registry)
			assert_true(resumed_victory.accepted, "the Risk Bargain victory reward resumes", failures)
			if resumed_victory.accepted:
				assert_true(resumed_victory.domain.state.gold == post_victory_gold, "resuming after victory does not pay Risk Bargain twice", failures)
		var expiry_events: Array = risk_domain.enter_run_summary("VICTORY", "TEST_EVENT_MODIFIER_EXPIRY")
		assert_true(risk_domain.state.active_modifier("event.risk_bargain.accept") == null, "Risk Bargain expires when the Run ends", failures)
		assert_true(_has_event(expiry_events, DomainEvent.EFFECT_EXPIRED), "Risk Bargain expiry emits its lifecycle event", failures)

	var lethal_risk_domain := _prepared_event_modifier_domain("event.modifier.risk.lethal", 7443, registry, "base.event.risk_bargain", false)
	assert_true(_choose_event_modifier(lethal_risk_domain, "accept"), "Risk Bargain installs before a lethal-entry fixture", failures)
	var next_node_id := "base.map_node.normal.mid"
	var encounter = registry.resolve(str(lethal_risk_domain.state.map_state.payload_ids[next_node_id]))
	if encounter != null:
		encounter.battle_values["pressure_limit"] = 1
		encounter.battle_values["initial_pressure"] = 0
	var lethal_entry = lethal_risk_domain.execute(SelectMapNodeCommand.new("event.modifier.risk.lethal.battle", next_node_id))
	assert_true(lethal_entry.accepted, "the map command accepts the authored lethal Risk Bargain battle entry", failures)
	assert_true(lethal_risk_domain.state.phase == RunPhase.RUN_SUMMARY and lethal_risk_domain.state.terminal_summary.outcome == "DEFEAT", "entry Pressure at the enemy limit transfers to Run Defeat instead of stranding a terminal Battle", failures)
	assert_true(_has_event(lethal_entry.events, DomainEvent.BATTLE_OUTCOME_TRANSFERRED) and _has_event(lethal_entry.events, DomainEvent.RUN_SUMMARY_REACHED), "lethal entry preserves battle-outcome and Run-summary events", failures)
	assert_true(lethal_risk_domain.state.gold == 0 and not _has_currency_event(lethal_entry.events, DomainEvent.GOLD_CHANGED, RunEconomy.GOLD, "EVENT_RISK_BARGAIN_VICTORY", 2), "Risk Bargain pays no victory Gold on entry defeat", failures)
	assert_true(lethal_entry.data.get("phase", "") == RunPhase.RUN_SUMMARY, "the lethal map command returns its final Run Summary phase", failures)
	var event_types: Array = lethal_entry.events.map(func(event): return event.event_type)
	var battle_phase_index := -1
	var summary_phase_index := -1
	for index in lethal_entry.events.size():
		var event = lethal_entry.events[index]
		if event.event_type != DomainEvent.RUN_PHASE_CHANGED:
			continue
		if str(event.data.get("to_phase", "")) == RunPhase.BATTLE:
			battle_phase_index = index
		elif str(event.data.get("to_phase", "")) == RunPhase.RUN_SUMMARY:
			summary_phase_index = index
	assert_true(event_types.find(DomainEvent.MAP_NODE_SELECTED) < event_types.find(DomainEvent.BATTLE_STARTED) \
		and event_types.find(DomainEvent.BATTLE_STARTED) < event_types.find(DomainEvent.PRESSURE_CHANGED) \
		and event_types.find(DomainEvent.PRESSURE_CHANGED) < battle_phase_index \
		and battle_phase_index < event_types.find(DomainEvent.BATTLE_OUTCOME_TRANSFERRED) \
		and event_types.find(DomainEvent.BATTLE_OUTCOME_TRANSFERRED) < summary_phase_index, "lethal entry preserves map, battle, effect, phase, and outcome event order", failures)
	assert_true(lethal_risk_domain.state.map_state.last_events.map(func(event): return event.to_dictionary()) == lethal_entry.events.map(func(event): return event.to_dictionary()), "the lethal map command stores its full ordered event list", failures)

	var clause_domain := _prepared_event_modifier_domain("event.modifier.contract", 7442, registry, "base.event.contract_clause", false)
	var clause_baseline := _prepared_event_modifier_domain("event.modifier.contract.baseline", 7442, registry, "base.event.contract_clause", false)
	assert_true(_choose_event_modifier(clause_domain, "carry_clause"), "Contract Clause installs its Run modifier", failures)
	assert_true(_choose_event_modifier(clause_baseline, "leave"), "the Contract Clause comparison run can decline", failures)
	var clause_entry = clause_domain.execute(SelectMapNodeCommand.new("event.modifier.contract.battle", "base.map_node.normal.mid"))
	var clause_baseline_entry = clause_baseline.execute(SelectMapNodeCommand.new("event.modifier.contract.baseline.battle", "base.map_node.normal.mid"))
	assert_true(clause_entry.accepted and clause_baseline_entry.accepted, "Contract Clause and comparison runs enter the same later battle", failures)
	if clause_entry.accepted and clause_baseline_entry.accepted:
		var clause_capacity: int = clause_domain.current_battle.combat_state.settlement_capacity
		assert_true(clause_capacity == clause_baseline.current_battle.combat_state.settlement_capacity + 1, "base Contract Clause adds one Settlement Capacity", failures)
		assert_true(clause_domain.current_battle.settlement_window.settlement_capacity().maximum == clause_capacity, "the Settlement Window uses the added capacity", failures)
		assert_true(_has_capacity_event(clause_entry.events, "settlement_capacity", clause_capacity, "run_modifier.event.contract_clause.apply"), "base Contract Clause emits its causal capacity event", failures)
		var saved_clause = SaveCoordinator.new().save(clause_domain)
		assert_true(saved_clause.accepted, "a battle entered under Contract Clause can be saved", failures)
		if saved_clause.accepted:
			var resumed_clause = SaveMapper.load_into_domain(saved_clause.snapshot.to_dictionary(), registry)
			assert_true(resumed_clause.accepted, "the Contract Clause battle resumes", failures)
			if resumed_clause.accepted:
				assert_true(resumed_clause.domain.current_battle.combat_state.settlement_capacity == clause_capacity, "resume does not apply Settlement Capacity twice", failures)
		var expired_clause_events = clause_domain.advance_run_boundary(DurationSpecScope.RUN)
		assert_true(clause_domain.state.active_modifier("event.contract_clause.apply") == null, "base Contract Clause expires at the Run boundary", failures)
		assert_true(_has_event(expired_clause_events, DomainEvent.EFFECT_EXPIRED), "base Contract Clause expiry emits its lifecycle event", failures)

func test_act_two_event_modifiers_change_battleplay_and_expire(failures: Array[String]) -> void:
	var registry := _event_effect_registry(true)
	var clause_domain := _prepared_event_modifier_domain("event.modifier.act-two.contract", 7451, registry, "alpha.event.act_two.contract_clause", true)
	var clause_baseline := _prepared_event_modifier_domain("event.modifier.act-two.contract.baseline", 7451, registry, "alpha.event.act_two.contract_clause", true)
	assert_true(_choose_event_modifier(clause_domain, "carry_clause"), "Act 2 Contract Clause installs its one-Act modifier", failures)
	assert_true(_choose_event_modifier(clause_baseline, "leave"), "the Act 2 Contract Clause comparison run can decline", failures)
	var clause_entry = clause_domain.execute(SelectMapNodeCommand.new("event.modifier.act-two.contract.battle", "base.map_node.act_two.normal.mid"))
	var clause_baseline_entry = clause_baseline.execute(SelectMapNodeCommand.new("event.modifier.act-two.contract.baseline.battle", "base.map_node.act_two.normal.mid"))
	assert_true(clause_entry.accepted and clause_baseline_entry.accepted, "Act 2 Contract Clause and comparison runs enter the same battle", failures)
	if clause_entry.accepted and clause_baseline_entry.accepted:
		var reserve_capacity: int = clause_domain.current_battle.combat_state.reserve_capacity
		assert_true(reserve_capacity == clause_baseline.current_battle.combat_state.reserve_capacity + 1, "Act 2 Contract Clause adds one Reserve Capacity", failures)
		assert_true(clause_domain.current_battle.reserve_service.reserve_capacity == reserve_capacity, "the Reserve Service uses the added capacity", failures)
		assert_true(_has_capacity_event(clause_entry.events, "reserve_capacity", reserve_capacity, "run_modifier.event.act_two.contract_clause"), "Act 2 Contract Clause emits its causal capacity event", failures)
		var clause = clause_domain.state.active_modifier("event.act_two.contract_clause")
		assert_true(clause != null and clause.duration_scope == DurationSpecScope.ACT and clause.remaining == 1, "the Reserve Capacity modifier retains its authored one-Act scope", failures)
		var saved_clause = SaveCoordinator.new().save(clause_domain)
		assert_true(saved_clause.accepted, "the Act 2 Contract Clause battle can be saved", failures)
		if saved_clause.accepted:
			var resumed_clause = SaveMapper.load_into_domain(saved_clause.snapshot.to_dictionary(), registry)
			assert_true(resumed_clause.accepted, "the Act 2 Contract Clause battle resumes", failures)
			if resumed_clause.accepted:
				assert_true(resumed_clause.domain.current_battle.combat_state.reserve_capacity == reserve_capacity, "resume does not add Reserve Capacity twice", failures)
		var expired_events = clause_domain.enter_run_summary("VICTORY", "TEST_ACT_TWO_CONTRACT_EXPIRY")
		assert_true(clause_domain.state.active_modifier("event.act_two.contract_clause") == null, "Act 2 Contract Clause expires at the Act boundary", failures)
		assert_true(_has_event(expired_events, DomainEvent.EFFECT_EXPIRED), "Act 2 Contract Clause expires with a factual lifecycle event at the end of its Act", failures)

	var memory_domain := _prepared_event_modifier_domain("event.modifier.act-two.memory", 7452, registry, "alpha.event.act_two.rule_memory", true)
	var memory_baseline := _prepared_event_modifier_domain("event.modifier.act-two.memory.baseline", 7452, registry, "alpha.event.act_two.rule_memory", true)
	var tokens_before: int = memory_domain.state.refinement_tokens
	assert_true(_choose_event_modifier(memory_domain, "study_yaku"), "Act 2 Rule Memory installs its Run modifier", failures)
	assert_true(_choose_event_modifier(memory_baseline, "leave"), "the Act 2 Rule Memory comparison run can decline", failures)
	assert_true(memory_domain.state.refinement_tokens == tokens_before + 1, "Act 2 Rule Memory preserves its existing Refinement Token reward", failures)
	var memory_entry = memory_domain.execute(SelectMapNodeCommand.new("event.modifier.act-two.memory.battle", "base.map_node.act_two.normal.mid"))
	var memory_baseline_entry = memory_baseline.execute(SelectMapNodeCommand.new("event.modifier.act-two.memory.baseline.battle", "base.map_node.act_two.normal.mid"))
	assert_true(memory_entry.accepted and memory_baseline_entry.accepted, "Act 2 Rule Memory and comparison runs enter the same battle", failures)
	if memory_entry.accepted and memory_baseline_entry.accepted:
		var memory_tp: int = memory_domain.current_battle.combat_state.tp
		assert_true(memory_tp == memory_baseline.current_battle.combat_state.tp + 1, "Act 2 Rule Memory grants one TP at battle entry", failures)
		assert_true(_has_effect_event(memory_entry.events, DomainEvent.TP_CHANGED, "run_modifier.event.act_two.rule_memory"), "Act 2 Rule Memory emits its causal TP event", failures)
		var saved_memory = SaveCoordinator.new().save(memory_domain)
		assert_true(saved_memory.accepted, "the Act 2 Rule Memory battle can be saved", failures)
		if saved_memory.accepted:
			var resumed_memory = SaveMapper.load_into_domain(saved_memory.snapshot.to_dictionary(), registry)
			assert_true(resumed_memory.accepted, "the Act 2 Rule Memory battle resumes", failures)
			if resumed_memory.accepted:
				assert_true(resumed_memory.domain.current_battle.combat_state.tp == memory_tp, "resume does not grant Rule Memory TP twice", failures)
		var memory_replay_factory: Callable = func(seed: int, _version: String):
			return _prepared_event_modifier_domain("event.modifier.act-two.memory", seed, registry, "alpha.event.act_two.rule_memory", true)
		var memory_replay = ReplayVerifier.verify(memory_domain.replay_record, memory_replay_factory, memory_domain.state.content_version)
		assert_true(memory_replay.is_match(), "Act 2 Rule Memory choice and battle-entry TP replay deterministically", failures)
		memory_domain.state.current_battle_snapshot = null
		memory_baseline.state.current_battle_snapshot = null
		var encounter_id := str(memory_domain.state.map_state.payload_ids["base.map_node.act_two.normal.mid"])
		var subsequent_memory_battle = memory_domain.encounter_factory.create(memory_domain.state, encounter_id, memory_domain.rng_streams, "NORMAL")
		var subsequent_baseline_battle = memory_baseline.encounter_factory.create(memory_baseline.state, encounter_id, memory_baseline.rng_streams, "NORMAL")
		assert_true(subsequent_memory_battle != null and subsequent_baseline_battle != null, "the Act 2 Rule Memory remains usable for a later battle entry", failures)
		if subsequent_memory_battle != null and subsequent_baseline_battle != null:
			assert_true(subsequent_memory_battle.combat_state.tp == subsequent_baseline_battle.combat_state.tp + 1, "Run-scoped Rule Memory grants TP again at a later battle entry", failures)
		var expiry_events = memory_domain.enter_run_summary("VICTORY", "TEST_EVENT_MODIFIER_EXPIRY")
		assert_true(memory_domain.state.active_modifier("event.act_two.rule_memory") == null, "Act 2 Rule Memory expires at the Run boundary", failures)
		assert_true(_has_event(expiry_events, DomainEvent.EFFECT_EXPIRED), "Act 2 Rule Memory expiry emits its lifecycle event", failures)

func test_event_modifier_labels_explain_their_effects(failures: Array[String]) -> void:
	var registry := _event_effect_registry(true)
	var expected_labels := {
		"base.event.risk_bargain": {"accept": ["1", "Pressure", "2", "Gold"]},
		"base.event.contract_clause": {"carry_clause": ["1", "Settlement Capacity"]},
		"alpha.event.act_two.contract_clause": {"carry_clause": ["1", "Reserve Capacity", "Act"]},
		"alpha.event.act_two.rule_memory": {"study_yaku": ["1", "TP", "Refinement Token"]},
	}
	for event_id in expected_labels:
		var definition = registry.resolve(event_id)
		var choice = definition.choice_by_id(expected_labels[event_id].keys()[0])
		var label := str(choice.get("label", "")) if choice is Dictionary else ""
		for expected_fragment in expected_labels[event_id][expected_labels[event_id].keys()[0]]:
			assert_true(label.contains(expected_fragment), "%s player-facing choice label explains %s" % [event_id, expected_fragment], failures)

func test_unknown_event_modifier_has_no_invented_battle_effect(failures: Array[String]) -> void:
	var registry := _event_effect_registry(false)
	var domain := _prepared_event_modifier_domain("event.modifier.unknown", 7461, registry, "base.event.risk_bargain", false)
	var unknown := ActiveEffectInstance.new(
		"run.modifier.event.future_unknown",
		DurationSpec.new(DurationSpec.RUN, 1),
		StackPolicy.UNIQUE,
		"test.unknown",
		1,
		-1,
		-1,
		"run.modifier.event.future_unknown",
		0,
		{"modifier_id": "event.future_unknown", "value": 99},
	)
	domain.state.active_effects[unknown.instance_id] = unknown
	var selection = domain.execute(SelectMapNodeCommand.new("event.modifier.unknown.battle", "base.map_node.normal.mid"))
	assert_true(selection.accepted, "an unknown active Event modifier does not block battle entry", failures)
	if selection.accepted:
		assert_true(domain.current_battle.combat_state.pressure == 0 and domain.current_battle.combat_state.tp == 0 and domain.current_battle.combat_state.settlement_capacity == 2 and domain.current_battle.combat_state.reserve_capacity == 3, "an unknown modifier ID receives no generic Event gameplay benefit", failures)
		assert_true(not _has_effect_event(selection.events, DomainEvent.PRESSURE_CHANGED, "run_modifier.event.future_unknown") and not _has_effect_event(selection.events, DomainEvent.TP_CHANGED, "run_modifier.event.future_unknown"), "unknown Event modifiers emit no invented battle-entry effects", failures)

func _event_effect_registry(include_act_two: bool) -> ContentRegistry:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	if include_act_two:
		AlphaActTwoCatalog.register_all(registry)
	return registry

func _production_event_registry() -> ContentRegistry:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	AlphaScaleCatalog.register_all(registry)
	return registry

func _production_event_domain(run_id: String, seed: int, act_index: int, registry: ContentRegistry) -> RunDomain:
	var domain: RunDomain = RunDomain.new(run_id, seed, registry) if act_index == 1 else RunDomain.new_alpha_run(run_id, seed, registry)
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, Phase2Catalog.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, Phase2Catalog.CONTRACT_IDS[0]))
	domain.state.gold = 10
	domain.state.refinement_tokens = 3
	domain.state.act_index = act_index
	if act_index == 2:
		domain.map_definition = MiniActMapCatalog.definition_for_act(2, registry)
		domain.state.map_state.initialize(domain.map_definition, domain.rng_streams.map)
	domain.state.phase = RunPhase.MAP_CHOICE
	_mark_intro_complete_for_later_event_fixture(domain)
	return domain

func _prepared_event_modifier_domain(run_id: String, seed: int, registry, event_id: String, act_two: bool) -> RunDomain:
	var domain: RunDomain = RunDomain.new_alpha_run(run_id, seed, registry) if act_two else RunDomain.new(run_id, seed, registry)
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, Phase2Catalog.CHARACTER_IDS[0]))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, Phase2Catalog.CONTRACT_IDS[0]))
	var branch_node_id := "base.map_node.normal.left"
	var event_node_id := "base.map_node.event.left"
	if act_two:
		domain.state.act_index = 2
		domain.map_definition = MiniActMapCatalog.act_two_definition()
		domain.state.map_state.initialize(domain.map_definition, domain.rng_streams.map)
		domain.state.refinement_tokens = 3
		branch_node_id = "base.map_node.act_two.normal.left" if event_id in ["alpha.event.act_two.risk_bargain", "alpha.event.act_two.tile_surgery", "alpha.event.act_two.gold_exchange"] else "base.map_node.act_two.normal.right"
		event_node_id = "base.map_node.act_two.event.left" if branch_node_id.ends_with("left") else "base.map_node.act_two.event.right"
	else:
		branch_node_id = "base.map_node.normal.right" if event_id == "base.event.contract_clause" else "base.map_node.normal.left"
		event_node_id = "base.map_node.event.right" if branch_node_id.ends_with("right") else "base.map_node.event.left"
	# Model the mandatory intro as pending, matching the current map-entry boundary.
	domain.state.map_state.visited_node_ids.clear()
	domain.state.map_state.ordered_path.clear()
	domain.state.map_state.path_edge_ids.clear()
	domain.state.map_state.select_node(domain.map_definition.start_node_id, domain.map_definition)
	if domain.state.map_state.path_edge_ids.size() == 1 and str(domain.state.map_state.path_edge_ids[0]).is_empty():
		domain.state.map_state.path_edge_ids.clear()
	domain.state.map_state.select_node(branch_node_id, domain.map_definition)
	domain.state.map_state.payload_ids[event_node_id] = event_id
	domain.state.map_state.select_node(event_node_id, domain.map_definition)
	domain.state.phase = RunPhase.MAP_CHOICE
	domain.replay_record = ReplayRecord.new(seed, domain.state.content_version, run_id)
	domain.replay_record.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), "ONGOING")
	return domain

func _choose_event_modifier(domain: RunDomain, choice_id: String) -> bool:
	var entry = domain.execute(EnterEventCommand.new("%s.enter" % domain.state.run_id))
	if not entry.accepted:
		return false
	var choice = domain.execute(ChooseEventOptionCommand.new(
		"%s.choose" % domain.state.run_id,
		choice_id,
		domain.state.event_state.event_id,
		domain.state.event_state.entry_id,
	))
	return choice.accepted

func _has_effect_event(events: Array, event_type: String, effect_id: String) -> bool:
	for event in events:
		if event.event_type == event_type and str(event.data.get("effect_id", event.data.get("source_id", ""))) == effect_id:
			return true
	return false

func _has_capacity_event(events: Array, capacity_id: String, capacity_value: int, effect_id: String) -> bool:
	for event in events:
		if event.event_type == DomainEvent.CAPACITY_CHANGED \
		and str(event.data.get("capacity", "")) == capacity_id \
		and int(event.data.get("value", -1)) == capacity_value \
		and str(event.data.get("effect_id", "")) == effect_id:
			return true
	return false

func _has_currency_event(events: Array, event_type: String, currency: String, source_id: String, amount: int) -> bool:
	for event in events:
		if event.event_type == event_type \
		and str(event.data.get("currency", "")) == currency \
		and str(event.data.get("source_id", "")) == source_id \
		and int(event.data.get("amount", 0)) == amount:
			return true
	return false

func _event_domain(run_id: String, seed: int) -> RunDomain:
	var domain := RunDomain.new(run_id, seed, _registry())
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	domain.state.gold = 5
	_mark_intro_complete_for_later_event_fixture(domain)
	return domain

func _act_two_event_domain(run_id: String, seed: int) -> RunDomain:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	var domain := RunDomain.new(run_id, seed, registry, "", null, 2)
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	domain.state.gold = 10
	domain.state.refinement_tokens = 3
	domain.state.act_index = 2
	domain.map_definition = MiniActMapCatalog.act_two_definition()
	domain.state.map_state.initialize(domain.map_definition, domain.rng_streams.map)
	domain.state.phase = RunPhase.MAP_CHOICE
	_mark_intro_complete_for_later_event_fixture(domain)
	return domain

func _mark_intro_complete_for_later_event_fixture(domain: RunDomain) -> void:
	# These tests isolate downstream Event behavior; map/presentation tests cover the real intro battle journey.
	domain.state.map_state.select_node(domain.map_definition.start_node_id, domain.map_definition)

func _prepare_act_two_event(domain: RunDomain, event_id: String, command_prefix: String):
	var is_left_event := event_id in [
		"alpha.event.act_two.tile_surgery",
		"alpha.event.act_two.risk_bargain",
		"alpha.event.act_two.gold_exchange",
	]
	var branch_node_id := "base.map_node.act_two.normal.left" if is_left_event else "base.map_node.act_two.normal.right"
	var event_node_id := "base.map_node.act_two.event.left" if is_left_event else "base.map_node.act_two.event.right"
	var event_node = domain.map_definition.node_definition(event_node_id)
	if not event_node.payload_options.has(event_id):
		return {"accepted": false, "status": "EVENT_NOT_AUTHORED"}
	domain.state.map_state.select_node(branch_node_id, domain.map_definition)
	domain.state.map_state.payload_ids[event_node_id] = event_id
	domain.state.map_state.select_node(event_node_id, domain.map_definition)
	return domain.execute(EnterEventCommand.new("%s.enter" % command_prefix))

func _act_two_event_choice_id(event_id: String) -> String:
	match event_id:
		"alpha.event.act_two.tile_surgery": return "repair_with_token"
		"alpha.event.act_two.risk_bargain": return "take_wager"
		"alpha.event.act_two.gold_exchange": return "trade_gold"
		"alpha.event.act_two.map_reveal": return "reveal_route"
		"alpha.event.act_two.contract_clause": return "carry_clause"
		"alpha.event.act_two.rule_memory": return "study_yaku"
	return ""

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
