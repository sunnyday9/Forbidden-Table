class_name ContentVersionMigration
extends RefCounted

const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const MiniActMapCatalogScript = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RewardDraftSelectorScript = preload("res://src/domain/run/reward_draft_selector.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunStateScript = preload("res://src/domain/run/run_state.gd")
const DomainRngStreamsScript = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")

const PHASE2_V1 := "content.slice.v1"
const PHASE2_V2 := "content.slice.v2"
const PHASE2_V3 := "content.slice.v3"
const ACT_TWO_V2 := "content.bundle.v1.alpha.act_two@v2+phase2@v2"
const ACT_TWO_SCALE_V2 := "content.bundle.v1.alpha.act_two@v2+alpha.scale@v2+phase2@v2"
const ACT_TWO_V3 := "content.bundle.v1.alpha.act_two@v3+phase2@v3"
const ACT_TWO_SCALE_V3 := "content.bundle.v1.alpha.act_two@v3+alpha.scale@v2+phase2@v3"
const CHANGED_EVENT_MODIFIER_IDS := [
	"event.risk_bargain.accept",
	"event.contract_clause.apply",
	"event.act_two.contract_clause",
	"event.act_two.rule_memory",
]
const MIGRATION_STEP := "Explicit Content Migration: content.slice.v1 -> content.slice.v3"

static func migrate_phase2_v1_suspend_snapshot(source: Dictionary, content_registry) -> Dictionary:
	if content_registry == null:
		return _reject("CONTENT_REGISTRY_REQUIRED")
	if not content_registry.has_method("content_version") or content_registry.content_version() != PHASE2_V3:
		return _reject("UNSUPPORTED_CONTENT_MIGRATION_TARGET")
	if int(source.get("schema_version", -1)) != 1 or str(source.get("game_version", "")) != "game.phase2.v1":
		return _reject("UNSUPPORTED_CONTENT_MIGRATION_ENVELOPE")
	if str(source.get("save_kind", "")) != "SUSPEND":
		return _reject("CONTENT_MIGRATION_REQUIRES_SUSPEND_SNAPSHOT")
	if str(source.get("content_version", "")) != PHASE2_V1:
		return _reject("UNSUPPORTED_CONTENT_MIGRATION_SOURCE")

	var state = source.get("authoritative_state", null)
	if not state is Dictionary or str(state.get("content_version", "")) != PHASE2_V1:
		return _reject("CONTENT_MIGRATION_STATE_VERSION_MISMATCH")
	if source.has("run_state"):
		var run_state = source.get("run_state")
		if not run_state is Dictionary:
			return _reject("INVALID_RUN_STATE_ALIAS")
		if DeterministicSerializerScript.serialize(run_state) != DeterministicSerializerScript.serialize(state):
			return _reject("RUN_STATE_ALIAS_MISMATCH")

	var metadata = source.get("checkpoint_metadata", null)
	if not metadata is Dictionary or not bool(metadata.get("stable", false)):
		return _reject("UNSTABLE_CHECKPOINT")
	if str(metadata.get("stable_boundary", "")).is_empty():
		return _reject("MISSING_STABLE_BOUNDARY")
	if not metadata.has("state_hash"):
		return _reject("SOURCE_STATE_HASH_MISSING")
	if str(metadata.get("state_hash", "")) != _run_state_hash(state):
		return _reject("SOURCE_STATE_HASH_MISMATCH")
	var active_effect_validation := _validate_active_event_migration_state(state)
	if not active_effect_validation.accepted:
		return active_effect_validation

	var migrated_state: Dictionary = state.duplicate(true)
	# Phase 2 saves represent a single Mini-Act; newer RunState fields must not
	# reinterpret an old Boss reward as the Act 1 boundary of a two-Act Run.
	migrated_state["act_index"] = 1
	migrated_state["act_count"] = 1
	var migrated_rng_state = source.get("rng_state", null)
	if migrated_rng_state is Dictionary:
		migrated_rng_state = migrated_rng_state.duplicate(true)
	var migrated_metadata: Dictionary = metadata.duplicate(true)
	if str(migrated_state.get("phase", "")) == RunPhaseScript.BOSS_REWARD:
		var boss_reward_migration := _migrate_legacy_boss_reward(migrated_state, source, content_registry)
		if not boss_reward_migration.accepted:
			return boss_reward_migration
		migrated_state = boss_reward_migration.state
		migrated_rng_state = boss_reward_migration.rng_state
		if migrated_metadata.has("checkpoint_sequence"):
			migrated_metadata["checkpoint_sequence"] = int(migrated_state["reward_draft_sequence"]) + int(migrated_state["tile_instance_sequence"])

	migrated_state["content_version"] = PHASE2_V3
	var migrated: Dictionary = source.duplicate(true)
	migrated["content_version"] = PHASE2_V3
	migrated["authoritative_state"] = migrated_state
	if migrated.has("run_state"):
		migrated["run_state"] = migrated_state.duplicate(true)
	migrated["rng_state"] = migrated_rng_state
	migrated_metadata["state_hash"] = _run_state_hash(migrated_state)
	migrated["checkpoint_metadata"] = migrated_metadata
	return {"accepted": true, "data": migrated, "migration": MIGRATION_STEP}

static func migrate_phase2_v2_suspend_snapshot(source: Dictionary, content_registry) -> Dictionary:
	if content_registry == null:
		return _reject("CONTENT_REGISTRY_REQUIRED")
	if not content_registry.has_method("content_version"):
		return _reject("UNSUPPORTED_CONTENT_MIGRATION_TARGET")
	var source_version := str(source.get("content_version", ""))
	var target_version := _phase2_v2_migration_target(source_version)
	if target_version.is_empty() or content_registry.content_version() != target_version:
		return _reject("UNSUPPORTED_CONTENT_MIGRATION_TARGET")
	if int(source.get("schema_version", -1)) != 1 or str(source.get("game_version", "")) != "game.phase2.v1":
		return _reject("UNSUPPORTED_CONTENT_MIGRATION_ENVELOPE")
	if str(source.get("save_kind", "")) != "SUSPEND":
		return _reject("CONTENT_MIGRATION_REQUIRES_SUSPEND_SNAPSHOT")
	var state = source.get("authoritative_state", null)
	if not state is Dictionary or str(state.get("content_version", "")) != source_version:
		return _reject("CONTENT_MIGRATION_STATE_VERSION_MISMATCH")
	if source.has("run_state"):
		var run_state = source.get("run_state")
		if not run_state is Dictionary:
			return _reject("INVALID_RUN_STATE_ALIAS")
		if DeterministicSerializerScript.serialize(run_state) != DeterministicSerializerScript.serialize(state):
			return _reject("RUN_STATE_ALIAS_MISMATCH")
	var metadata = source.get("checkpoint_metadata", null)
	if not metadata is Dictionary or not bool(metadata.get("stable", false)):
		return _reject("UNSTABLE_CHECKPOINT")
	if str(metadata.get("stable_boundary", "")).is_empty():
		return _reject("MISSING_STABLE_BOUNDARY")
	if not metadata.has("state_hash"):
		return _reject("SOURCE_STATE_HASH_MISSING")
	if str(metadata.get("state_hash", "")) != _run_state_hash(state):
		return _reject("SOURCE_STATE_HASH_MISMATCH")
	var active_effect_validation := _validate_active_event_migration_state(state)
	if not active_effect_validation.accepted:
		return active_effect_validation

	var migrated_state: Dictionary = state.duplicate(true)
	migrated_state["content_version"] = target_version
	var migrated: Dictionary = source.duplicate(true)
	migrated["content_version"] = target_version
	migrated["authoritative_state"] = migrated_state
	if migrated.has("run_state"):
		migrated["run_state"] = migrated_state.duplicate(true)
	var migrated_metadata: Dictionary = metadata.duplicate(true)
	migrated_metadata["state_hash"] = _run_state_hash(migrated_state)
	migrated["checkpoint_metadata"] = migrated_metadata
	return {
		"accepted": true,
		"data": migrated,
		"migration": "Explicit Content Migration: %s -> %s" % [source_version, target_version],
	}

static func _phase2_v2_migration_target(source_version: String) -> String:
	match source_version:
		PHASE2_V2:
			return PHASE2_V3
		ACT_TWO_V2:
			return ACT_TWO_V3
		ACT_TWO_SCALE_V2:
			return ACT_TWO_SCALE_V3
		_:
			return ""

static func _validate_active_event_migration_state(state: Dictionary) -> Dictionary:
	if not state.has("active_effects"):
		return _reject("UNVERIFIABLE_ACTIVE_EVENT_MODIFIER_STATE")
	var active_effects = state.get("active_effects", [])
	if not active_effects is Array:
		return _reject("UNVERIFIABLE_ACTIVE_EVENT_MODIFIER_STATE")
	for effect in active_effects:
		if not effect is Dictionary:
			return _reject("UNVERIFIABLE_ACTIVE_EVENT_MODIFIER_STATE")
		for field in ["instance_id", "definition_id", "source_id", "runtime_parameters"]:
			if not effect.has(field):
				return _reject("UNVERIFIABLE_ACTIVE_EVENT_MODIFIER_STATE")
		for field in ["instance_id", "definition_id", "source_id"]:
			if typeof(effect[field]) != TYPE_STRING:
				return _reject("UNVERIFIABLE_ACTIVE_EVENT_MODIFIER_STATE")
		var runtime_parameters = effect.get("runtime_parameters", {})
		if not runtime_parameters is Dictionary:
			return _reject("UNVERIFIABLE_ACTIVE_EVENT_MODIFIER_STATE")
		if runtime_parameters.has("modifier_id") and typeof(runtime_parameters["modifier_id"]) != TYPE_STRING:
			return _reject("UNVERIFIABLE_ACTIVE_EVENT_MODIFIER_STATE")
		var serialized_ids: Array = [
			str(runtime_parameters.get("modifier_id", "")),
			str(effect.get("instance_id", "")),
			str(effect.get("definition_id", "")),
			str(effect.get("source_id", "")),
		]
		for serialized_id in serialized_ids:
			for changed_modifier_id in CHANGED_EVENT_MODIFIER_IDS:
				if str(serialized_id) == str(changed_modifier_id) or str(serialized_id).contains(str(changed_modifier_id)):
					return _reject("UNSUPPORTED_ACTIVE_EVENT_MODIFIER_MIGRATION")
	return {"accepted": true}

static func _run_state_hash(state: Dictionary) -> String:
	var deterministic_state: Dictionary = state.duplicate(true)
	deterministic_state.erase("run_started_at_unix_seconds")
	return DeterministicSerializerScript.hash(deterministic_state)

static func _migrate_legacy_boss_reward(state: Dictionary, source: Dictionary, content_registry) -> Dictionary:
	var legacy_draft = state.get("reward_draft", null)
	if not legacy_draft is Dictionary or not legacy_draft.is_empty():
		return _reject("UNEXPECTED_LEGACY_BOSS_REWARD_DRAFT")
	var sequence = state.get("reward_draft_sequence", null)
	if typeof(sequence) != TYPE_INT or int(sequence) < 0:
		return _reject("INVALID_LEGACY_BOSS_REWARD_SEQUENCE")
	var tile_sequence = state.get("tile_instance_sequence", null)
	if typeof(tile_sequence) != TYPE_INT or int(tile_sequence) < 0:
		return _reject("INVALID_LEGACY_BOSS_REWARD_TILE_SEQUENCE")
	var map_state = state.get("map_state", null)
	if not map_state is Dictionary:
		return _reject("INVALID_LEGACY_BOSS_REWARD_MAP")
	var node_id := str(map_state.get("current_node_id", ""))
	var node = MiniActMapCatalogScript.definition().node_definition(node_id)
	if node == null or node.node_kind != "BOSS":
		return _reject("LEGACY_BOSS_REWARD_NOT_AT_BOSS_NODE")
	var payload_ids = map_state.get("payload_ids", null)
	if not payload_ids is Dictionary:
		return _reject("INVALID_LEGACY_BOSS_REWARD_MAP")
	var encounter_id := str(payload_ids.get(node_id, ""))
	var encounter = content_registry.resolve(encounter_id)
	if not encounter is EncounterDefinitionScript or encounter.encounter_kind != EncounterDefinitionScript.BOSS:
		return _reject("LEGACY_BOSS_REWARD_ENCOUNTER_UNAVAILABLE")
	var rng_state = source.get("rng_state", null)
	var run_seed = source.get("run_seed", null)
	if not rng_state is Dictionary or typeof(run_seed) != TYPE_INT:
		return _reject("INVALID_LEGACY_BOSS_REWARD_RNG")
	var rng_streams = DomainRngStreamsScript.new(int(run_seed))
	if not rng_streams.restore(rng_state):
		return _reject("INVALID_LEGACY_BOSS_REWARD_RNG")
	var ownership = state.get("build_ownership", null)
	if not ownership is Dictionary:
		return _reject("INVALID_LEGACY_BOSS_REWARD_OWNERSHIP")
	var acquired_rule_breaker_ids = ownership.get("acquired_rule_breaker_ids", null)
	if not acquired_rule_breaker_ids is Array:
		return _reject("INVALID_LEGACY_BOSS_REWARD_OWNERSHIP")
	var run_state = RunStateScript.new(str(state.get("run_id", "")), int(run_seed), PHASE2_V3)
	for rule_breaker_id in acquired_rule_breaker_ids:
		run_state.build_ownership.acquired_rule_breaker_ids.append(str(rule_breaker_id))
	var next_sequence := int(sequence) + 1
	var draft = RewardDraftSelectorScript.new().create_boss_rule_breaker_draft(
		run_state,
		content_registry,
		rng_streams.reward,
		encounter_id,
		int(sequence),
		Phase2CatalogScript.BOSS_RULE_BREAKER_POOL_ID,
	)
	if draft == null or draft.options.size() != 3:
		return _reject("BOSS_RULE_BREAKER_DRAFT_UNAVAILABLE")
	var migrated_state: Dictionary = state.duplicate(true)
	migrated_state["reward_draft"] = draft.to_dictionary()
	migrated_state["reward_draft_sequence"] = next_sequence
	return {"accepted": true, "state": migrated_state, "rng_state": rng_streams.snapshot()}

static func _reject(code: String) -> Dictionary:
	return {"accepted": false, "code": code}
