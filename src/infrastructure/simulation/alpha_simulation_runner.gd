class_name AlphaSimulationRunner
extends RefCounted

const AlphaFailureClassifierScript = preload("res://src/infrastructure/simulation/alpha_failure_classifier.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifierScript = preload("res://src/infrastructure/replay/replay_verifier.gd")
const SaveCoordinatorScript = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const LoadValidatorScript = preload("res://src/infrastructure/persistence/load_validator.gd")
const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const AlphaSimulationStartingPoolFixtureScript = preload("res://src/infrastructure/simulation/alpha_simulation_starting_pool_fixture.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const SelectMapNodeCommandScript = preload("res://src/domain/commands/select_map_node_command.gd")
const EnterShopCommandScript = preload("res://src/domain/commands/enter_shop_command.gd")
const ExitShopCommandScript = preload("res://src/domain/commands/exit_shop_command.gd")
const EnterWorkshopCommandScript = preload("res://src/domain/commands/enter_workshop_command.gd")
const ExitWorkshopCommandScript = preload("res://src/domain/commands/exit_workshop_command.gd")
const EnterEventCommandScript = preload("res://src/domain/commands/enter_event_command.gd")
const ChooseEventOptionCommandScript = preload("res://src/domain/commands/choose_event_option_command.gd")
const ChooseRewardCommandScript = preload("res://src/domain/commands/choose_reward_command.gd")
const UseWorkshopServiceCommandScript = preload("res://src/domain/commands/use_workshop_service_command.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const EndTurnCommandScript = preload("res://src/domain/commands/end_turn_command.gd")
const SettlePatternCommandScript = preload("res://src/domain/commands/settle_pattern_command.gd")
const SettleCompleteHandCommandScript = preload("res://src/domain/commands/settle_complete_hand_command.gd")
const StoreTileCommandScript = preload("res://src/domain/commands/store_tile_command.gd")

const SUPPORTED_POLICIES := ["Partial", "Complete", "Hybrid"]
const MAX_DRAWS_PER_TURN := 16
const POLICY_RULE_VERSION := "v5"

var _domain
var _attempt_case: Dictionary
var _manifest_hash := ""
var _command_limit := 0
var _command_sequence := 0
var _draws_this_turn := 0
var _draws_since_last_settlement := 0
var _accepted_action_counts: Dictionary = {}
var _partial_settlement_count := 0
var _complete_hand_count := 0
var _failure_detail := ""
var _command_rejected := false
var _content_available := true
var _soft_lock_detected := false
var _starting_pool_hash := ""
var _starting_pool_tile_count := 0
var _unavailable_content_paths: Array[String] = []

func run_attempt(attempt_case: Dictionary, manifest_hash: String, command_limit: int = 1024) -> Dictionary:
	_reset_attempt(attempt_case, manifest_hash, command_limit)
	var registry = ContentRegistryScript.new()
	var registration_report = Phase2CatalogScript.register_all(registry)
	var alpha_act_two_registration_report = AlphaActTwoCatalogScript.register_all(registry)
	var attempt_id := str(_attempt_case.get("attempt_id", "attempt.%05d" % int(_attempt_case.get("attempt_index", 0))))
	var run_id := "alpha.%s.%s" % [str(_attempt_case.get("gate_id", "unknown")), attempt_id]
	var seed := int(_attempt_case.get("seed", 0))
	_domain = RunDomainScript.new_alpha_run(run_id, seed, registry, registry.content_version())

	if (
		registration_report == null
		or not registration_report.is_valid()
		or alpha_act_two_registration_report == null
		or not alpha_act_two_registration_report.is_valid()
	):
		_content_available = false
		_failure_detail = "The Phase 2 and Act 2 Boss reward content bundles could not be registered."
	elif str(_attempt_case.get("policy_id", "")) not in SUPPORTED_POLICIES:
		_content_available = false
		_failure_detail = "The scheduled policy is not supported by the Alpha runner."
	elif not registry.resolve(str(_attempt_case.get("character_id", ""))) is CharacterDefinitionScript:
		_content_available = false
		_failure_detail = "Scheduled Character content is unavailable: %s" % str(_attempt_case.get("character_id", ""))
	elif registry.resolve(str(_attempt_case.get("contract_id", ""))) == null:
		_content_available = false
		_failure_detail = "Scheduled Contract content is unavailable: %s" % str(_attempt_case.get("contract_id", ""))
	else:
		var character = registry.resolve(str(_attempt_case.get("character_id", "")))
		var starting_pool: Array = AlphaSimulationStartingPoolFixtureScript.create(
			str(_attempt_case.get("character_id", "")),
			character.starting_tile_pool_bias,
		)
		var pool_initialized := not starting_pool.is_empty()
		for tile_record in starting_pool:
			if not _domain.state.tile_pool.add_tile_instance(tile_record):
				pool_initialized = false
				break
		if not pool_initialized:
			_content_available = false
			_failure_detail = "The versioned starting-pool fixture could not be materialized from the selected Character bias."
		else:
			_starting_pool_tile_count = starting_pool.size()
			_starting_pool_hash = AlphaSimulationStartingPoolFixtureScript.hash(
				str(_attempt_case.get("character_id", "")),
				character.starting_tile_pool_bias,
			)
			_reset_initial_replay_checkpoint(_domain)
			_execute_command(ChooseCharacterCommandScript.new(_next_command_id("character"), str(_attempt_case.get("character_id", ""))))
		if not _command_rejected and _content_available:
			_execute_command(ChooseContractCommandScript.new(_next_command_id("contract"), str(_attempt_case.get("contract_id", ""))))

	while _content_available and not _command_rejected and not _soft_lock_detected and not _is_terminal() and _accepted_command_count() < _command_limit:
		var made_step := false
		match str(_domain.state.phase):
			RunPhaseScript.MAP_CHOICE:
				made_step = _step_map_choice()
			RunPhaseScript.BATTLE:
				made_step = _step_battle()
			RunPhaseScript.REWARD_CHOICE, RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD:
				made_step = _step_reward()
			RunPhaseScript.SHOP:
				made_step = _execute_command(ExitShopCommandScript.new(_next_command_id("shop.exit")))
			RunPhaseScript.WORKSHOP:
				made_step = _step_workshop()
			RunPhaseScript.EVENT:
				made_step = _step_event()
			_:
				made_step = false
		if not made_step and not _command_rejected:
			if is_unavailable_act_two_boss_reward(
				str(_domain.state.phase),
				int(_domain.state.act_index),
				int(_domain.state.act_count),
				_domain.state.reward_draft,
			):
				_content_available = false
				_unavailable_content_paths.append(AlphaActTwoCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_POOL_ID)
				_failure_detail = "Act 2 Boss Rule Breaker content is not yet introduced; this reward path is not covered."
			else:
				_soft_lock_detected = true
				if _failure_detail.is_empty():
					_failure_detail = "No legal authoritative command was available in phase %s." % str(_domain.state.phase)

	if not _is_terminal() and _accepted_command_count() >= _command_limit and _failure_detail.is_empty():
		_failure_detail = "The attempt reached its accepted-command limit before a Run ending."
	return _build_attempt_record()

func _reset_attempt(attempt_case: Dictionary, manifest_hash: String, command_limit: int) -> void:
	_domain = null
	_attempt_case = attempt_case.duplicate(true)
	_manifest_hash = manifest_hash
	_command_limit = maxi(0, command_limit)
	_command_sequence = 0
	_draws_this_turn = 0
	_draws_since_last_settlement = 0
	_accepted_action_counts = {}
	_partial_settlement_count = 0
	_complete_hand_count = 0
	_failure_detail = ""
	_command_rejected = false
	_content_available = true
	_soft_lock_detected = false
	_starting_pool_hash = ""
	_starting_pool_tile_count = 0
	_unavailable_content_paths = []

static func is_unavailable_act_two_boss_reward(phase: String, act_index: int, act_count: int, reward_draft) -> bool:
	return phase == RunPhaseScript.BOSS_REWARD and act_index == 2 and act_count >= 2 and reward_draft == null

func _reset_initial_replay_checkpoint(domain) -> void:
	domain.replay_record = ReplayRecordScript.new(domain.state.seed, domain.state.content_version, domain.state.run_id)
	domain.replay_record.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), "ONGOING")

func _replay_factory(replay_seed: int, replay_content_version: String):
	var run_id := str(_domain.state.run_id)
	var character_id := str(_attempt_case.get("character_id", ""))
	var replay_domain = RunDomainScript.new_alpha_run(run_id, replay_seed, _domain.content_registry, replay_content_version)
	var character = replay_domain.content_registry.resolve(character_id)
	if not character is CharacterDefinitionScript:
		return null
	for tile_record in AlphaSimulationStartingPoolFixtureScript.create(character_id, character.starting_tile_pool_bias):
		if not replay_domain.state.tile_pool.add_tile_instance(tile_record):
			return null
	_reset_initial_replay_checkpoint(replay_domain)
	return replay_domain

func _step_map_choice() -> bool:
	var node_id := str(_domain.state.map_state.current_node_id)
	var current_node = _domain.map_definition.node_definition(node_id)
	if current_node == null:
		return false
	match current_node.node_kind:
		"SHOP":
			if not _domain.state.shop_state.has_completed_node(node_id):
				return _execute_command(EnterShopCommandScript.new(_next_command_id("shop.enter")))
		"WORKSHOP":
			if not _domain.state.workshop_state.has_completed_node(node_id):
				return _execute_command(EnterWorkshopCommandScript.new(_next_command_id("workshop.enter")))
		"EVENT":
			if not _domain.state.event_state.has_completed_node(node_id):
				return _execute_command(EnterEventCommandScript.new(_next_command_id("event.enter")))

	var next_node_ids: Array = current_node.next_node_ids.duplicate()
	if next_node_ids.is_empty():
		return false
	var selected_node_id := _select_route_node(next_node_ids)
	if selected_node_id.is_empty():
		return false
	return _execute_command(SelectMapNodeCommandScript.new(_next_command_id("map.select"), selected_node_id))

func _select_route_node(next_node_ids: Array) -> String:
	var candidates: Array[String] = []
	for candidate_value in next_node_ids:
		var candidate_id := str(candidate_value)
		if _domain.map_definition.node_definition(candidate_id) != null:
			candidates.append(candidate_id)
	candidates.sort()
	if candidates.is_empty():
		return ""

	var route_id := str(_attempt_case.get("route_id", "" )).to_upper()
	var preferred_kind := "EVENT" if route_id.find("EVENT") >= 0 else "SHOP" if route_id.find("SHOP") >= 0 else ""
	if preferred_kind.is_empty() and route_id.find("SERVICE") >= 0:
		preferred_kind = "WORKSHOP"
	if preferred_kind.is_empty() and route_id.find("WORKSHOP") >= 0:
		preferred_kind = "WORKSHOP"
	if preferred_kind.is_empty():
		return candidates[0]

	for candidate_id in candidates:
		var candidate = _domain.map_definition.node_definition(candidate_id)
		if candidate.node_kind == preferred_kind:
			return candidate_id
		for child_id in candidate.next_node_ids:
			var child = _domain.map_definition.node_definition(str(child_id))
			if child != null and child.node_kind == preferred_kind:
				return candidate_id
	return candidates[0]

func _step_battle() -> bool:
	var battle = _domain.current_battle
	if battle == null or battle.combat_state == null:
		return false
	if not battle.combat_state.is_active():
		return false
	var draw_sources_available: bool = battle.draw_wall.size() > 0 or battle.zones.size(TileZoneScript.DISCARD) > 0
	if battle.recovery_state != null and battle.recovery_state.is_recovering():
		var hand_size := int(battle.zones.size(TileZoneScript.HAND))
		var recovery_baseline := int(battle.recovery_state.normal_hand_baseline)
		if hand_size < recovery_baseline and draw_sources_available:
			var drew_recovery_tile := _execute_command(DrawCommandScript.new(_next_command_id("battle.recovery.draw")))
			if drew_recovery_tile and int(battle.zones.size(TileZoneScript.HAND)) <= hand_size:
				_soft_lock_detected = true
				_failure_detail = "A Recovery draw was accepted without moving the Hand toward its normal baseline."
				return false
			return drew_recovery_tile
		return _execute_command(EndTurnCommandScript.new(_next_command_id("battle.recovery.end_turn")))

	var candidates: Array = battle.settlement_window.candidates() if battle.settlement_window != null and battle.settlement_window.has_capacity() else []
	var policy_id := str(_attempt_case.get("policy_id", ""))
	var complete_hand_window: bool = policy_id != "Partial" and battle.recovery_state != null and battle.recovery_state.can_complete_hand()
	var complete_hands: Array = battle.complete_hand_interpretations() if complete_hand_window else []
	var has_complete_hand := not complete_hands.is_empty()
	var selected_partial = _best_partial_candidate(candidates)
	var has_partial := selected_partial != null
	if policy_id == "Complete" and not has_complete_hand and draw_sources_available:
		var store_target := _next_complete_hand_store_target(battle)
		if not store_target.is_empty():
			return _execute_command(StoreTileCommandScript.new(
				_next_command_id("battle.reserve.store"),
				store_target,
			))
	var pressure := int(battle.combat_state.pressure)
	var pressure_limit := maxi(1, int(battle.combat_state.pressure_limit))
	var decision := ""

	match policy_id:
		"Partial":
			if has_partial:
				decision = "PARTIAL_SETTLEMENT"
		"Complete":
			if has_complete_hand:
				decision = "COMPLETE_HAND"
			elif has_partial and (_draws_since_last_settlement >= MAX_DRAWS_PER_TURN or battle.draw_wall.size() == 0):
				decision = "PARTIAL_SETTLEMENT"
		"Hybrid":
			if has_complete_hand and (pressure * 2 < pressure_limit or not has_partial):
				decision = "COMPLETE_HAND"
			elif has_partial:
				decision = "PARTIAL_SETTLEMENT"
			elif has_complete_hand:
				decision = "COMPLETE_HAND"

	if decision == "PARTIAL_SETTLEMENT":
		return _execute_command(SettlePatternCommandScript.new(
			_next_command_id("battle.partial"),
			[],
			"",
			"",
			false,
			selected_partial.candidate_id,
		))
	if decision == "COMPLETE_HAND":
		var interpretation = _best_complete_hand(complete_hands)
		if interpretation != null:
			return _execute_command(SettleCompleteHandCommandScript.new(
				_next_command_id("battle.complete"),
				interpretation.interpretation_id,
			))

	if _draws_this_turn >= MAX_DRAWS_PER_TURN or not draw_sources_available:
		return _execute_command(EndTurnCommandScript.new(_next_command_id("battle.end_turn")))
	return _execute_command(DrawCommandScript.new(_next_command_id("battle.draw")))

func _best_partial_candidate(candidates: Array):
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(left, right):
		var left_rank := _pattern_rank(str(left.pattern_type))
		var right_rank := _pattern_rank(str(right.pattern_type))
		if left_rank != right_rank:
			return left_rank > right_rank
		return str(left.candidate_id) < str(right.candidate_id)
	)
	return sorted[0] if not sorted.is_empty() else null

func _next_complete_hand_store_target(battle) -> String:
	if battle == null or battle.zones == null or battle.complete_hand_evaluator == null:
		return ""
	var hand: Array = battle.zones.contents(TileZoneScript.HAND)
	hand.sort_custom(func(left, right): return str(left.instance_id) < str(right.instance_id))
	var available_reserve_slots := int(battle.combat_state.reserve_capacity) - int(battle.zones.size(TileZoneScript.RESERVE))
	var maximum_store_count := mini(available_reserve_slots, hand.size() - 14)
	if available_reserve_slots < 1 or hand.size() < 14:
		return ""
	for store_count in range(1, maximum_store_count + 1):
		var target := _find_complete_hand_store_target_for_count(battle, hand, store_count)
		if not target.is_empty():
			return target

	var candidate_usage: Dictionary = {}
	for candidate in battle.settlement_window.candidates():
		for tile in candidate.tile_instances:
			var instance_id := str(tile.instance_id)
			candidate_usage[instance_id] = int(candidate_usage.get(instance_id, 0)) + 1
	var unmatched_target := ""
	var lowest_candidate_usage := 2147483647
	for tile in hand:
		var instance_id := str(tile.instance_id)
		var usage := int(candidate_usage.get(instance_id, 0))
		if usage < lowest_candidate_usage:
			lowest_candidate_usage = usage
			unmatched_target = instance_id
	return unmatched_target

func _find_complete_hand_store_target_for_count(battle, hand: Array, store_count: int) -> String:
	if store_count == 1:
		for first in range(hand.size()):
			if _is_complete_hand_without_stored_indices(battle, hand, [first]):
				return str(hand[first].instance_id)
	elif store_count == 2:
		for first in range(hand.size()):
			for second in range(first + 1, hand.size()):
				if _is_complete_hand_without_stored_indices(battle, hand, [first, second]):
					return str(hand[first].instance_id)
	elif store_count == 3:
		for first in range(hand.size()):
			for second in range(first + 1, hand.size()):
				for third in range(second + 1, hand.size()):
					if _is_complete_hand_without_stored_indices(battle, hand, [first, second, third]):
						return str(hand[first].instance_id)
	return ""

func _is_complete_hand_without_stored_indices(battle, hand: Array, stored_indices: Array) -> bool:
	var candidate_hand: Array = []
	for index in range(hand.size()):
		if index not in stored_indices:
			candidate_hand.append(hand[index])
	return not battle.complete_hand_evaluator.evaluate(candidate_hand).is_empty()

func _pattern_rank(pattern_type: String) -> int:
	match pattern_type:
		"Quad": return 3
		"Triplet": return 2
		"Sequence": return 1
	return 0

func _best_complete_hand(interpretations: Array):
	var sorted := interpretations.duplicate()
	sorted.sort_custom(func(left, right):
		if left.hand_type != right.hand_type:
			return str(left.hand_type) < str(right.hand_type)
		return str(left.interpretation_id) < str(right.interpretation_id)
	)
	return sorted[0] if not sorted.is_empty() else null

func _step_workshop() -> bool:
	var tile_instances: Array = _domain.state.tile_pool.tile_instances.duplicate()
	tile_instances.sort_custom(func(left, right):
		return str(left.instance_id) < str(right.instance_id)
	)
	var modifier_ids: Array[String] = []
	for modifier_id_value in Phase2CatalogScript.MODIFIER_IDS:
		modifier_ids.append(str(modifier_id_value))
	modifier_ids.sort()
	for tile_instance in tile_instances:
		for modifier_id in modifier_ids:
			var command = UseWorkshopServiceCommandScript.new(
				"sim.workshop.validation",
				"MODIFIER",
				str(tile_instance.instance_id),
				"",
				modifier_id,
			)
			var validation = command.validate(_domain)
			if validation != null and validation.is_valid():
				return _execute_command(command)
	return _execute_command(ExitWorkshopCommandScript.new(_next_command_id("workshop.exit")))

func _should_bank_gold_for_workshop() -> bool:
	if str(_attempt_case.get("route_id", "")).to_upper().find("SERVICE") < 0:
		return false
	var gold_if_skipped := int(_domain.state.gold) + int(_domain.economy.normal_skip_gold)
	if gold_if_skipped < int(_domain.economy.workshop_modifier_price):
		return false
	for node_id in _domain.map_definition.node_ids:
		var node = _domain.map_definition.node_definition(node_id)
		if node != null and node.node_kind == "WORKSHOP" and not _domain.state.workshop_state.has_completed_node(node_id):
			return true
	return false

func _step_reward() -> bool:
	var draft = _domain.state.reward_draft
	if draft == null or draft.options.is_empty():
		return false
	var selected_option = null
	if _should_bank_gold_for_workshop() and str(_domain.state.phase) == RunPhaseScript.REWARD_CHOICE:
		for option in draft.options:
			if str(option.kind) == "SKIP":
				selected_option = option
				break
	for option in draft.options:
		if selected_option != null:
			break
		if str(option.kind) != "SKIP":
			selected_option = option
			break
	if selected_option == null:
		selected_option = draft.options[0]
	return _execute_command(ChooseRewardCommandScript.new(
		_next_command_id("reward.choose"),
		str(selected_option.option_id),
		str(draft.draft_id),
	))

func _step_event() -> bool:
	var option_ids: Array[String] = _domain.state.event_state.legal_choice_ids()
	if option_ids.is_empty():
		return false
	option_ids.sort()
	var event_id := str(_domain.state.event_state.event_id)
	var entry_id := str(_domain.state.event_state.entry_id)
	var first_rejection := ""
	for option_id in option_ids:
		var probe = ChooseEventOptionCommandScript.new("sim.event.validation", option_id, event_id, entry_id)
		var validation = probe.validate(_domain)
		if validation != null and validation.is_valid():
			return _execute_command(ChooseEventOptionCommandScript.new(
				_next_command_id("event.choose"),
				option_id,
				event_id,
				entry_id,
			))
		if first_rejection.is_empty() and validation != null:
			first_rejection = "%s: %s" % [str(validation.code), str(validation.message)]
	if not first_rejection.is_empty():
		_failure_detail = "No Event option passed authoritative Command validation. First rejection: %s" % first_rejection
	return false

func _execute_command(command) -> bool:
	if _domain == null or command == null or _accepted_command_count() >= _command_limit:
		return false
	var result = _domain.execute(command)
	if result == null or not result.is_accepted():
		_command_rejected = true
		var result_status := str(result.status) if result != null else "NO_RESULT"
		var command_type := str(command.command_type()) if command.has_method("command_type") else "UNKNOWN_COMMAND"
		_failure_detail = "%s was rejected (%s)." % [command_type, result_status]
		return false

	var command_type := str(command.command_type()) if command.has_method("command_type") else "UNKNOWN_COMMAND"
	_accepted_action_counts[command_type] = int(_accepted_action_counts.get(command_type, 0)) + 1
	if command_type == "SettlePattern":
		_partial_settlement_count += 1
		_draws_since_last_settlement = 0
	elif command_type == "SettleCompleteHand":
		_complete_hand_count += 1
		_draws_since_last_settlement = 0
	if command_type == "Draw":
		_draws_this_turn += 1
		_draws_since_last_settlement += 1
	elif command_type == "EndTurn":
		_draws_this_turn = 0
	return true

func _next_command_id(action: String) -> String:
	_command_sequence += 1
	var attempt_id := str(_attempt_case.get("attempt_id", "attempt"))
	return "sim.%s.%05d.%s" % [attempt_id, _command_sequence, action]

func _accepted_command_count() -> int:
	return _domain.replay_record.commands.size() if _domain != null else 0

func _is_terminal() -> bool:
	return _domain != null and _domain.state.terminal_summary != null and RunPhaseScript.is_terminal(str(_domain.state.phase))

func _validate_terminal_authoritative_state() -> Dictionary:
	if not _is_terminal():
		return {"status": "NOT_RUN", "errors": []}
	var saved := SaveCoordinatorScript.new().save(_domain)
	if not saved.get("accepted", false):
		return {
			"status": "INVALID",
			"errors": [{"code": str(saved.get("code", "SAVE_REJECTED")), "details": saved.get("details", {})}],
		}
	var validation: Dictionary = LoadValidatorScript.new().validate(saved.snapshot.to_dictionary(), _domain.content_registry)
	var errors: Array = validation.get("errors", [])
	return {"status": "VALID" if validation.get("accepted", false) else "INVALID", "errors": errors.duplicate(true)}

func _build_attempt_record() -> Dictionary:
	var replay_status := "UNAVAILABLE"
	var replay_verification: Dictionary = {"status": replay_status, "reason": "DOMAIN_NOT_CREATED"}
	var accepted_commands: Array = []
	var checkpoints: Array = []
	var checkpoint_hashes: Array[String] = []
	var rng_snapshots: Array = []
	var factual_events: Array = []
	var outcome := "ONGOING"
	var terminal := false
	var two_act_profile := false
	var configured_act_count := 0
	var act_reached := 0
	var progress_status := "NOT_STARTED"
	var authoritative_validation := {"status": "NOT_RUN", "errors": []}
	var authoritative_state_valid = null
	if _domain != null:
		var replay_report = ReplayVerifierScript.verify(
			_domain.replay_record,
			_replay_factory,
			_domain.state.content_version,
		)
		replay_status = str(replay_report.status)
		replay_verification = replay_report.to_dictionary()
		for command_record in _domain.replay_record.commands:
			accepted_commands.append(command_record.to_dictionary())
		for checkpoint_record in _domain.replay_record.checkpoints:
			var checkpoint_data: Dictionary = checkpoint_record.to_dictionary()
			checkpoints.append(checkpoint_data)
			checkpoint_hashes.append(str(checkpoint_data.get("domain_state_hash", "")))
			rng_snapshots.append(checkpoint_data.get("rng_state", {}).duplicate(true))
			for event in checkpoint_data.get("domain_events", []):
				factual_events.append(event.duplicate(true) if event is Dictionary else event)
		terminal = _is_terminal()
		if _domain.state.terminal_summary != null:
			outcome = str(_domain.state.terminal_summary.outcome)
		two_act_profile = int(_domain.state.act_count) == 2
		configured_act_count = int(_domain.state.act_count)
		act_reached = int(_domain.state.act_index)
		progress_status = _progress_status(configured_act_count, act_reached, terminal)
		var trace_shape_valid := checkpoints.size() == accepted_commands.size() + 1 and not checkpoints.is_empty()
		if _is_terminal():
			authoritative_validation = _validate_terminal_authoritative_state()
			authoritative_state_valid = trace_shape_valid and authoritative_validation.get("status", "") == "VALID"

	var classification_input := {
		"terminal": terminal,
		"outcome": outcome,
		"soft_lock_detected": _soft_lock_detected,
		"command_rejected": _command_rejected,
		"content_available": _content_available,
		"replay_status": replay_status,
		"failure_detail": _failure_detail,
	}
	if authoritative_state_valid != null:
		classification_input["authoritative_state_valid"] = authoritative_state_valid
	var classified := AlphaFailureClassifierScript.classify(classification_input)
	var strategy_rule := "Partial: settle the highest-ranked legal Partial Pattern; never choose Complete Hand."
	match str(_attempt_case.get("policy_id", "")):
		"Complete":
			strategy_rule = "Complete: choose a legal Complete Hand first; when none is available, deterministically store the least-patterned Hand tile in Reserve and draw a replacement when a slot and draw source are available; otherwise accumulate up to the draw budget between settlements, then settle the highest-ranked legal Partial Pattern when the draw wall is exhausted or the budget is reached."
		"Hybrid":
			strategy_rule = "Hybrid: choose Complete Hand below half Pressure when available; otherwise prefer the highest-ranked legal Partial Pattern."
	strategy_rule += " End Turn rather than request a Draw when both Draw Wall and Discard are empty, including during Recovery."
	strategy_rule += " Route SERVICE through an authored Workshop node; use the first deterministic legal Modifier when affordable, banking a Normal Reward skip only when it will reach that price."
	var strategy := {
		"policy_id": str(_attempt_case.get("policy_id", "")),
		"policy_rule_id": "alpha.%s.%s" % [str(_attempt_case.get("policy_id", "unsupported")).to_lower(), POLICY_RULE_VERSION],
		"decision_rule": strategy_rule,
		"accepted_action_counts": _accepted_action_counts.duplicate(true),
		"partial_settlements": _partial_settlement_count,
		"complete_hand_settlements": _complete_hand_count,
	}
	return {
		"manifest_hash": _manifest_hash,
		"gate_id": str(_attempt_case.get("gate_id", "")),
		"attempt_id": str(_attempt_case.get("attempt_id", "")),
		"attempt_index": int(_attempt_case.get("attempt_index", 0)),
		"seed": int(_attempt_case.get("seed", 0)),
		"policy_id": str(_attempt_case.get("policy_id", "")),
		"character_id": str(_attempt_case.get("character_id", "")),
		"contract_id": str(_attempt_case.get("contract_id", "")),
		"route_id": str(_attempt_case.get("route_id", "")),
		"starting_pool_fixture_id": str(_attempt_case.get("starting_pool_fixture_id", AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID)),
		"starting_pool_tile_count": _starting_pool_tile_count,
		"starting_pool_hash": _starting_pool_hash,
		"two_act_profile": two_act_profile,
		"configured_act_count": configured_act_count,
		"act_reached": act_reached,
		"progress_status": progress_status,
		"terminal": terminal,
		"outcome": outcome,
		"accepted_command_count": accepted_commands.size(),
		"accepted_commands": accepted_commands,
		"checkpoints": checkpoints,
		"checkpoint_hashes": checkpoint_hashes,
		"rng_snapshots": rng_snapshots,
		"events": factual_events,
		"strategy": strategy,
		"replay_status": replay_status,
		"replay_verification": replay_verification,
		"authoritative_state_valid": authoritative_state_valid,
		"authoritative_state_validation_status": str(authoritative_validation.get("status", "NOT_RUN")),
		"authoritative_state_validation_errors": authoritative_validation.get("errors", []).duplicate(true),
		"failure_classification": str(classified.get("failure_classification", "INVALID_TERMINAL_OUTCOME")),
		"failure_detail": str(classified.get("detail", "")),
		"content_available": _content_available,
		"unavailable_content_paths": _unavailable_content_paths.duplicate(),
	}

func _progress_status(configured_act_count: int, reached_act: int, terminal: bool) -> String:
	if configured_act_count <= 0 or reached_act <= 0:
		return "NOT_STARTED"
	if terminal:
		return "TERMINAL_AFTER_FINAL_ACT" if reached_act >= configured_act_count else "TERMINAL_BEFORE_FINAL_ACT"
	return "IN_PROGRESS_IN_FINAL_ACT" if reached_act >= configured_act_count else "IN_PROGRESS_BEFORE_FINAL_ACT"
