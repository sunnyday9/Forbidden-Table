class_name SaveMapper
extends RefCounted

const SuspendSnapshotScript = preload("res://src/infrastructure/persistence/suspend_snapshot.gd")
const RunRecordScript = preload("res://src/infrastructure/persistence/run_record.gd")
const MigrationPipelineScript = preload("res://src/infrastructure/persistence/migration_pipeline.gd")
const ContentVersionMigrationScript = preload("res://src/infrastructure/persistence/content_version_migration.gd")
const LoadValidatorScript = preload("res://src/infrastructure/persistence/load_validator.gd")
const JsonIntegerCodecScript = preload("res://src/infrastructure/serialization/json_integer_codec.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const MiniActMapCatalogScript = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const RunStateScript = preload("res://src/domain/run/run_state.gd")
const RunMapStateScript = preload("res://src/domain/run/run_map_state.gd")
const RunTilePoolStateScript = preload("res://src/domain/run/run_tile_pool_state.gd")
const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")
const RunBuildStateScript = preload("res://src/domain/run/run_build_state.gd")
const RunTutorialStateScript = preload("res://src/domain/run/run_tutorial_state.gd")
const RunTerminalSummaryScript = preload("res://src/domain/run/run_terminal_summary.gd")
const RunBattleSnapshotScript = preload("res://src/domain/run/run_battle_snapshot.gd")
const ShopStateScript = preload("res://src/domain/run/shop_state.gd")
const ShopOfferScript = preload("res://src/domain/run/shop_offer.gd")
const WorkshopStateScript = preload("res://src/domain/run/workshop_state.gd")
const EventStateScript = preload("res://src/domain/run/event_state.gd")
const RewardDraftScript = preload("res://src/domain/run/reward_draft.gd")
const RewardOptionScript = preload("res://src/domain/run/reward_option.gd")
const ActiveEffectInstanceScript = preload("res://src/domain/effects/active_effect_instance.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")

static func suspend_snapshot(domain, checkpoint_metadata: Dictionary = {}):
	var metadata := checkpoint_metadata.duplicate(true)
	if metadata.is_empty():
		metadata = {"stable": true, "stable_boundary": str(domain.checkpoint().get("stable_boundary", "")), "state_hash": domain.checkpoint().get("state_hash", "")}
	return SuspendSnapshotScript.new(domain.state.content_version, domain.state.run_id, domain.state.seed, domain.state.to_dictionary(), domain.rng_snapshot(), metadata)

static func run_record(domain, checkpoint_metadata: Dictionary = {}):
	var snapshot = suspend_snapshot(domain, checkpoint_metadata)
	return RunRecordScript.new(snapshot.content_version, snapshot.run_id, snapshot.run_seed, snapshot.authoritative_state, snapshot.rng_state, snapshot.checkpoint_metadata)

static func load_into_domain(serialized, content_registry, _target_domain = null) -> Dictionary:
	return _load_into_domain(serialized, content_registry, false)

static func load_phase2_v1_suspend_snapshot_into_domain(serialized, content_registry, _target_domain = null) -> Dictionary:
	return _load_into_domain(serialized, content_registry, true)

static func _load_into_domain(serialized, content_registry, allow_explicit_content_migration: bool) -> Dictionary:
	var parsed: Dictionary
	if serialized is String:
		var json_parse := JsonIntegerCodecScript.parse(serialized)
		if not json_parse.accepted or not json_parse.data is Dictionary:
			return _reject(str(json_parse.get("code", "PARSE_FAILED")))
		parsed = json_parse.data
	elif serialized is Dictionary:
		parsed = serialized.duplicate(true)
	else:
		return _reject("PARSE_FAILED")
	var migration := MigrationPipelineScript.new(1)
	var migrated := migration.migrate(parsed)
	if not migrated.accepted:
		return migrated
	var data: Dictionary = migrated.data
	var pipeline: Array[String] = ["Parse", "Schema Migration"]
	if allow_explicit_content_migration:
		var content_migration := ContentVersionMigrationScript.migrate_phase2_v1_suspend_snapshot(data, content_registry)
		if not content_migration.accepted:
			return content_migration
		data = content_migration.data
		pipeline.append(content_migration.migration)
	var validation := LoadValidatorScript.new().validate(data, content_registry)
	if not validation.accepted:
		return {"accepted": false, "code": "VALIDATION_FAILED", "errors": validation.errors, "pipeline": pipeline.duplicate()}
	# Content IDs are resolved by the validator before any runtime object is constructed.
	var state = _state_from_dictionary(data.get("authoritative_state", data.get("run_state", {})), data)
	var domain := RunDomainScript.new(str(data.run_id), int(data.run_seed), content_registry, str(data.content_version))
	domain.rebind_state(state)
	domain.map_definition = MiniActMapCatalogScript.definition_for_act(state.act_index)
	if domain.map_definition == null:
		return _reject("INVALID_ACT_INDEX")
	if state.phase == RunPhaseScript.BATTLE:
		var battle_reconstruction := _reconstruct_battle(domain)
		if not battle_reconstruction.accepted:
			return battle_reconstruction
	if not domain.rng_streams.restore(data.rng_state):
		return _reject("INVALID_RNG_STATE")
	# A Suspend Save starts a new accepted-command replay segment at the restored
	# authoritative checkpoint. This leaves older replay fixture semantics alone.
	var resumed_snapshot = suspend_snapshot(domain, data.get("checkpoint_metadata", {}))
	var resumed_replay = ReplayRecordScript.new(domain.state.seed, domain.state.content_version, domain.state.run_id)
	resumed_replay.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), str(domain.state.terminal_summary.outcome))
	var replay_factory := func(_replay_seed: int, _replay_content_version: String):
		var replay_loaded: Dictionary = load_into_domain(resumed_snapshot.serialize(), content_registry)
		return replay_loaded.domain if replay_loaded.get("accepted", false) else null
	resumed_replay.restored_replay_factory = replay_factory
	domain.replay_record = resumed_replay
	pipeline.append_array(["Validate", "Resolve Content IDs", "Reconstruct"])
	return {"accepted": true, "domain": domain, "snapshot": SuspendSnapshotScript.from_dictionary(data), "pipeline": pipeline}

static func _reconstruct_battle(domain) -> Dictionary:
	var node = domain.map_definition.node_definition(domain.state.map_state.current_node_id)
	if node == null or not domain._is_battle_node(node):
		return _reject("BATTLE_NODE_NOT_RESOLVED")
	var encounter_id: String = domain._encounter_id_for_node(domain.state.map_state.current_node_id)
	if encounter_id.is_empty():
		return _reject("BATTLE_ENCOUNTER_NOT_RESOLVED")
	var battle = domain.encounter_factory.create(domain.state, encounter_id, domain.rng_streams, domain._encounter_kind_for_node(node))
	if battle == null or not battle.restore_checkpoint(domain.state.current_battle_snapshot.to_dictionary()):
		return _reject("BATTLE_RECONSTRUCTION_FAILED")
	if battle.checkpoint() != domain.state.current_battle_snapshot.to_dictionary():
		return _reject("BATTLE_CHECKPOINT_MISMATCH")
	domain.current_battle = battle
	return {"accepted": true}

static func load(serialized, content_registry) -> Dictionary:
	return load_into_domain(serialized, content_registry)

static func _state_from_dictionary(data: Dictionary, envelope: Dictionary):
	var state := RunStateScript.new(str(envelope.get("run_id", data.get("run_id", ""))), int(envelope.get("run_seed", data.get("seed", 0))), str(envelope.get("content_version", data.get("content_version", ""))))
	state.phase = str(data.get("phase", state.phase))
	state.act_index = int(data.get("act_index", 1))
	state.act_count = int(data.get("act_count", 1))
	state.character_id = str(data.get("character_id", ""))
	state.contract_id = str(data.get("contract_id", ""))
	state.gold = int(data.get("gold", 0))
	state.refinement_tokens = int(data.get("refinement_tokens", 0))
	state.run_started_at_unix_seconds = int(data.get("run_started_at_unix_seconds", 0))
	state.pattern_counts = data.get("pattern_counts", {}).duplicate(true) if data.get("pattern_counts", {}) is Dictionary else {}
	state.yaku_counts = data.get("yaku_counts", {}).duplicate(true) if data.get("yaku_counts", {}) is Dictionary else {}
	state.complete_hand_count = maxi(0, int(data.get("complete_hand_count", 0)))
	state.maximum_mahjong_score = maxi(0, int(data.get("maximum_mahjong_score", 0)))
	state.boss_progress.clear()
	var boss_progress_value: Variant = data.get("boss_progress", [])
	if boss_progress_value is Array:
		for boss_progress_item in boss_progress_value:
			if boss_progress_item is Dictionary:
				state.boss_progress.append(boss_progress_item.duplicate(true))
	state.milestones = _string_array(data.get("milestones", []))
	state.reward_draft_sequence = int(data.get("reward_draft_sequence", 0))
	state.tile_instance_sequence = int(data.get("tile_instance_sequence", 0))
	state.map_state = _map_from_dictionary(data.get("map_state", {}))
	state.tile_pool = _tile_pool_from_dictionary(data.get("tile_pool", {}))
	state.shop_state = _shop_from_dictionary(data.get("shop_state", {}))
	state.workshop_state = _workshop_from_dictionary(data.get("workshop_state", {}))
	state.event_state = _event_from_dictionary(data.get("event_state", {}))
	state.build_ownership = _build_from_dictionary(data.get("build_ownership", {}))
	state.tutorial_state = _tutorial_from_dictionary(data.get("tutorial_state", {}))
	var terminal: Dictionary = data.get("terminal_summary", {})
	state.terminal_summary = RunTerminalSummaryScript.new(str(terminal.get("outcome", "ONGOING")), str(terminal.get("reason", "")), terminal.get("summary_data", {}))
	state.reward_draft = _reward_from_dictionary(data.get("reward_draft", {}))
	state.current_battle_snapshot = RunBattleSnapshotScript.new(data.get("current_battle_snapshot", {})) if not data.get("current_battle_snapshot", {}).is_empty() else null
	state.active_effects = _effects_from_dictionary(data.get("active_effects", []))
	return state

static func _map_from_dictionary(data: Dictionary):
	var result := RunMapStateScript.new(str(data.get("map_definition_id", "")), str(data.get("current_node_id", "")), _string_array(data.get("visited_node_ids", [])), _string_array(data.get("ordered_path", [])))
	result.map_version = str(data.get("map_version", ""))
	result.node_ids = _string_array(data.get("node_ids", []))
	result.edge_ids = _string_array(data.get("edge_ids", []))
	result.node_kinds = data.get("node_kinds", {}).duplicate(true)
	result.payload_ids = data.get("payload_ids", {}).duplicate(true)
	result.knowledge_state = data.get("knowledge_state", {}).duplicate(true)
	result.path_edge_ids = _string_array(data.get("path_edge_ids", []))
	result.map_rng_state = data.get("map_rng_state", {}).duplicate(true)
	result.last_events = data.get("last_events", []).duplicate(true)
	return result

static func _tile_pool_from_dictionary(data: Dictionary):
	var result := RunTilePoolStateScript.new()
	for value in data.get("tile_instances", []):
		result.add_tile_instance(RunTileInstanceRecordScript.new(str(value.get("instance_id", "")), str(value.get("definition_id", "")), str(value.get("ownership_scope", "RUN")), str(value.get("lifetime_scope", value.get("lifetime", "RUN"))), str(value.get("origin", "RUN_POOL"))))
	return result

static func _shop_from_dictionary(data: Dictionary):
	var result := ShopStateScript.new()
	for field in ["active", "completed", "node_id", "entry_id", "base_refresh_allowance", "refreshes_remaining", "refresh_count", "entry_sequence", "shop_rng_state", "completed_node_ids"]:
		if data.has(field):
			result.set(field, data[field].duplicate(true) if data[field] is Array or data[field] is Dictionary else data[field])
	for value in data.get("offers", []):
		var offer := ShopOfferScript.new(str(value.get("offer_id", "")), int(value.get("slot_index", 0)), str(value.get("kind", "")), str(value.get("content_id", "")), int(value.get("price", 0)), value.get("metadata", {}))
		offer.status = str(value.get("status", ShopOfferScript.AVAILABLE))
		result.offers.append(offer)
	return result

static func _workshop_from_dictionary(data: Dictionary):
	var result := WorkshopStateScript.new()
	for field in ["active", "completed", "node_id", "entry_id", "entry_sequence"]:
		if data.has(field): result.set(field, data[field])
	result.available_service_ids = _string_array(data.get("available_service_ids", []))
	result.used_service_ids = _string_array(data.get("used_service_ids", []))
	result.completed_node_ids = _string_array(data.get("completed_node_ids", []))
	return result

static func _event_from_dictionary(data: Dictionary):
	var result := EventStateScript.new()
	for field in ["active", "completed", "node_id", "entry_id", "event_id", "choices", "selected_choice_id", "resolved_alternative_id", "entry_sequence", "event_rng_state", "completed_node_ids"]:
		if data.has(field): result.set(field, data[field].duplicate(true) if data[field] is Array or data[field] is Dictionary else data[field])
	return result

static func _build_from_dictionary(data: Dictionary):
	var result := RunBuildStateScript.new()
	for field in ["owned_relic_ids", "run_technique_ids", "owned_special_offer_ids", "acquired_rule_breaker_ids"]:
		result.set(field, _string_array(data.get(field, [])))
	result.character_core_technique_id = str(data.get("character_core_technique_id", ""))
	result.persistent_tile_modifier_state = data.get("persistent_tile_modifier_state", {}).duplicate(true)
	result.yaku_build_milestones = data.get("yaku_build_milestones", {}).duplicate(true)
	return result

static func _tutorial_from_dictionary(data: Dictionary):
	var result := RunTutorialStateScript.new(str(data.get("active_step_id", "")))
	result.completed_step_ids = _string_array(data.get("completed_step_ids", []))
	return result

static func _reward_from_dictionary(data: Dictionary):
	if data.is_empty(): return null
	var options: Array = []
	for value in data.get("options", []):
		options.append(RewardOptionScript.new(str(value.get("option_id", "")), str(value.get("kind", "")), str(value.get("content_id", "")), str(value.get("tile_id", "")), str(value.get("modifier_id", "")), str(value.get("target_instance_id", "")), str(value.get("context_bias", RewardOptionScript.NEUTRAL)), int(value.get("gold_delta", 0)), int(value.get("refinement_token_delta", 0)), value.get("metadata", {})))
	return RewardDraftScript.new(str(data.get("draft_id", "")), str(data.get("draft_kind", "")), str(data.get("encounter_id", "")), str(data.get("encounter_kind", "")), options, data.get("reward_rng_state", {}))

static func _effects_from_dictionary(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		if not value is Dictionary: continue
		var duration: Dictionary = value.get("duration", {})
		var effect := ActiveEffectInstanceScript.new(str(value.get("definition_id", "")), DurationSpecScript.new(str(duration.get("scope", DurationSpecScript.PERMANENT)), int(duration.get("remaining", 0))), StackPolicyScript.new(str(value.get("stack_policy", StackPolicyScript.REPLACE)), int(value.get("max_stacks", 0))), str(value.get("source_id", "")), int(value.get("stacks", 1)), int(value.get("uses_remaining", -1)), int(value.get("charges_remaining", -1)), str(value.get("instance_id", "")), int(value.get("max_stacks", 0)), value.get("runtime_parameters", {}))
		result[effect.instance_id] = effect
	return result

static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values: result.append(str(value))
	return result

static func _reject(code: String) -> Dictionary:
	return {"accepted": false, "code": code}
