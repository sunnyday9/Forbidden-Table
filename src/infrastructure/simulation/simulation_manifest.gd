class_name SimulationManifest
extends RefCounted

const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const SCHEMA_VERSION := 1
const RUNS_REQUIRED_PER_GATE := 1000
const STARTING_POOL_FIXTURE_ID := "phase2.character_biased_complete_hand.v1"
const POLICY_ORDER := ["Partial", "Complete", "Hybrid"]
const GATE_ORDER := ["readiness", "hardening", "scale", "exit", "stage4_beta"]
const ACT_1_BOSS_THREE_CHOICE_PATH := "ACT_1_BOSS_RULE_BREAKER_THREE_CHOICES"
const ACT_2_BOSS_THREE_CHOICE_PATH := "ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"
const ACT_2_BOSS_RULE_BREAKER_POOL_ID := AlphaActTwoCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_POOL_ID
const BASELINE_AVAILABLE_REWARD_PATHS := [
	"NORMAL_REWARD",
	"ELITE_REWARD",
	"BOSS_RULE_BREAKER",
	ACT_1_BOSS_THREE_CHOICE_PATH,
	ACT_2_BOSS_THREE_CHOICE_PATH,
]

var _data: Dictionary = {}
var _errors: Array[String] = []
var _starting_pool_fixture_id := STARTING_POOL_FIXTURE_ID

func _init(config: Dictionary = {}, available_character_ids: Array = [], available_contract_ids: Array = []) -> void:
	var available_characters := _string_ids(available_character_ids, "available_character_ids")
	var available_contracts := _string_ids(available_contract_ids, "available_contract_ids")
	if int(config.get("schema_version", SCHEMA_VERSION)) != SCHEMA_VERSION:
		_errors.append("UNSUPPORTED_MANIFEST_SCHEMA")
	var content_version := str(config.get("content_version", ""))
	if content_version.is_empty():
		_errors.append("MISSING_CONTENT_VERSION")
	var starting_pool_fixture_id := str(config.get("starting_pool_fixture_id", STARTING_POOL_FIXTURE_ID))
	if starting_pool_fixture_id.is_empty():
		_errors.append("MISSING_STARTING_POOL_FIXTURE")
	_starting_pool_fixture_id = starting_pool_fixture_id
	var source_profiles: Array = config.get("gate_profiles", [])
	if source_profiles.is_empty():
		_errors.append("MISSING_GATE_PROFILES")

	var profiles := {}
	for source_profile in source_profiles:
		if not source_profile is Dictionary:
			_errors.append("INVALID_GATE_PROFILE")
			continue
		var gate_id := str(source_profile.get("gate_id", ""))
		if gate_id not in GATE_ORDER:
			_errors.append("INVALID_GATE_ID:%s" % gate_id)
			continue
		if profiles.has(gate_id):
			_errors.append("DUPLICATE_GATE_PROFILE:%s" % gate_id)
			continue
		profiles[gate_id] = _build_gate_profile(
			source_profile,
			gate_id,
			available_characters,
			available_contracts,
		)

	var ordered_profiles := {}
	for gate_id in GATE_ORDER:
		if profiles.has(gate_id):
			ordered_profiles[gate_id] = profiles[gate_id]
	_data = {
		"schema_version": SCHEMA_VERSION,
		"content_version": content_version,
		"starting_pool_fixture_id": starting_pool_fixture_id,
		"required_runs_per_gate": RUNS_REQUIRED_PER_GATE,
		"available_character_ids": available_characters,
		"available_contract_ids": available_contracts,
		"gate_order": GATE_ORDER.duplicate(),
		"gates": ordered_profiles,
		"alpha_full_roster_claim": false,
		"alpha_full_roster_claim_reason": "Coverage is reported only against each gate's declared matrix; unavailable or undeclared Alpha content is never inferred as covered.",
	}

func is_valid() -> bool:
	return _errors.is_empty()

func errors() -> Array[String]:
	return _errors.duplicate()

func to_dictionary() -> Dictionary:
	var result := _data.duplicate(true)
	result["manifest_hash"] = DeterministicSerializerScript.hash(_data)
	return result

func serialize() -> String:
	return DeterministicSerializerScript.serialize(to_dictionary())

func manifest_hash() -> String:
	return DeterministicSerializerScript.hash(_data)

func _build_gate_profile(
	source: Dictionary,
	gate_id: String,
	available_characters: Array[String],
	available_contracts: Array[String],
) -> Dictionary:
	var attempt_count := int(source.get("attempt_count", 0))
	if attempt_count < 1 or attempt_count > 100000:
		_errors.append("INVALID_ATTEMPT_COUNT:%s" % gate_id)
		attempt_count = 0
	var seed_start := int(source.get("seed_start", 0))
	var requested_policies := _string_ids(source.get("policy_ids", POLICY_ORDER), "%s.policy_ids" % gate_id)
	var policies: Array[String] = []
	for policy_id in POLICY_ORDER:
		if requested_policies.has(policy_id):
			policies.append(policy_id)
	for policy_id in requested_policies:
		if policy_id not in POLICY_ORDER:
			_errors.append("UNSUPPORTED_POLICY:%s:%s" % [gate_id, policy_id])
	if policies.is_empty():
		_errors.append("MISSING_POLICIES:%s" % gate_id)

	var requested_characters := _string_ids(source.get("character_ids", available_characters), "%s.character_ids" % gate_id)
	var requested_contracts := _string_ids(source.get("contract_ids", available_contracts), "%s.contract_ids" % gate_id)
	var character_ids := _available_subset(requested_characters, available_characters)
	var contract_ids := _available_subset(requested_contracts, available_contracts)
	if character_ids.is_empty():
		_errors.append("NO_AVAILABLE_CHARACTERS:%s" % gate_id)
	if contract_ids.is_empty():
		_errors.append("NO_AVAILABLE_CONTRACTS:%s" % gate_id)
	var route_ids := _string_ids(source.get("route_ids", ["SERVICE", "EVENT"]), "%s.route_ids" % gate_id)
	if route_ids.is_empty():
		_errors.append("MISSING_ROUTES:%s" % gate_id)

	var required_characters := _string_ids(source.get("required_character_ids", character_ids), "%s.required_character_ids" % gate_id)
	var required_contracts := _string_ids(source.get("required_contract_ids", contract_ids), "%s.required_contract_ids" % gate_id)
	var required_policies := _string_ids(source.get("required_policy_ids", POLICY_ORDER), "%s.required_policy_ids" % gate_id)
	var boundaries := _string_ids(source.get("required_act_boundaries", ["ACT_1_BOSS_REWARD_TO_ACT_2", "ACT_2_BOSS_REWARD_TO_SUMMARY"]), "%s.required_act_boundaries" % gate_id)
	var reward_paths := _string_ids(source.get("required_reward_paths", ["NORMAL_REWARD", "ELITE_REWARD", "BOSS_RULE_BREAKER"]), "%s.required_reward_paths" % gate_id)
	if not reward_paths.has(ACT_1_BOSS_THREE_CHOICE_PATH):
		reward_paths.append(ACT_1_BOSS_THREE_CHOICE_PATH)
	if not reward_paths.has(ACT_2_BOSS_THREE_CHOICE_PATH):
		reward_paths.append(ACT_2_BOSS_THREE_CHOICE_PATH)
	reward_paths.sort()
	var available_reward_paths := _string_ids(
		source.get("available_reward_paths", BASELINE_AVAILABLE_REWARD_PATHS),
		"%s.available_reward_paths" % gate_id,
	)
	var not_yet_introduced_reward_paths := _string_ids(
		source.get("not_yet_introduced_reward_paths", []),
		"%s.not_yet_introduced_reward_paths" % gate_id,
	)
	for reward_path in reward_paths:
		if not available_reward_paths.has(reward_path) and not not_yet_introduced_reward_paths.has(reward_path):
			not_yet_introduced_reward_paths.append(reward_path)
	for reward_path in available_reward_paths:
		not_yet_introduced_reward_paths.erase(reward_path)
	not_yet_introduced_reward_paths.sort()
	var not_yet_introduced_content_ids := _string_ids(
		source.get("not_yet_introduced_content_ids", []),
		"%s.not_yet_introduced_content_ids" % gate_id,
	)
	if not available_reward_paths.has(ACT_2_BOSS_THREE_CHOICE_PATH):
		if not not_yet_introduced_content_ids.has(ACT_2_BOSS_RULE_BREAKER_POOL_ID):
			not_yet_introduced_content_ids.append(ACT_2_BOSS_RULE_BREAKER_POOL_ID)
	else:
		not_yet_introduced_content_ids.erase(ACT_2_BOSS_RULE_BREAKER_POOL_ID)
	not_yet_introduced_content_ids.sort()
	var cases: Array[Dictionary] = []
	if attempt_count > 0 and not policies.is_empty() and not character_ids.is_empty() and not contract_ids.is_empty() and not route_ids.is_empty():
		var case_plan: Array[Dictionary] = []
		if gate_id == "stage4_beta":
			case_plan = build_balanced_case_plan(
				character_ids,
				contract_ids,
				policies,
				route_ids,
				attempt_count,
			)
			if case_plan.size() != attempt_count:
				_errors.append("INVALID_STAGE4_BETA_CASE_PLAN")
				return {
					"gate_id": gate_id,
					"attempt_count": attempt_count,
					"required_run_count": RUNS_REQUIRED_PER_GATE,
					"cases": [],
				}
		for index in range(attempt_count):
			var case_spec: Dictionary = case_plan[index] if not case_plan.is_empty() else {}
			var character_stride := maxi(1, policies.size())
			var contract_stride := character_stride * maxi(1, character_ids.size())
			var route_stride := contract_stride * maxi(1, contract_ids.size())
			cases.append({
				"attempt_index": index,
				"attempt_id": "%s.%05d" % [gate_id, index + 1],
				"gate_id": gate_id,
				"seed": seed_start + index,
				"policy_id": str(case_spec.get("policy_id", policies[index % policies.size()])),
				"character_id": str(case_spec.get("character_id", character_ids[floori(float(index) / float(character_stride)) % character_ids.size()])),
				"contract_id": str(case_spec.get("contract_id", contract_ids[floori(float(index) / float(contract_stride)) % contract_ids.size()])),
				"route_id": str(case_spec.get("route_id", route_ids[floori(float(index) / float(route_stride)) % route_ids.size()])),
				"starting_pool_fixture_id": _starting_pool_fixture_id,
			})

	return {
		"gate_id": gate_id,
		"attempt_count": attempt_count,
		"required_run_count": RUNS_REQUIRED_PER_GATE,
		"run_count_requirement_met": attempt_count >= RUNS_REQUIRED_PER_GATE,
		"seed_start": seed_start,
		"policy_ids": policies,
		"required_policy_ids": required_policies,
		"character_ids": character_ids,
		"contract_ids": contract_ids,
		"route_ids": route_ids,
		"required_character_ids": required_characters,
		"required_contract_ids": required_contracts,
		"required_act_boundaries": boundaries,
		"required_reward_paths": reward_paths,
		"available_reward_paths": available_reward_paths,
		"not_yet_introduced_reward_paths": not_yet_introduced_reward_paths,
		"not_yet_introduced_content_ids": not_yet_introduced_content_ids,
		"content_use_catalog": source.get("content_use_catalog", {}).duplicate(true) if source.get("content_use_catalog", {}) is Dictionary else {},
		"missing_character_content_ids": _missing_ids(required_characters, available_characters),
		"missing_contract_content_ids": _missing_ids(required_contracts, available_contracts),
		"cases": cases,
		"coverage_status": "NOT_RUN",
		"full_alpha_roster_claim": false,
	}

static func build_balanced_case_plan(
	character_ids: Array,
	contract_ids: Array,
	policy_ids: Array,
	route_ids: Array,
	attempt_count: int,
) -> Array[Dictionary]:
	var characters := _sorted_unique_string_values(character_ids)
	var contracts := _sorted_unique_string_values(contract_ids)
	var policies := _ordered_policy_values(policy_ids)
	var routes := _sorted_unique_string_values(route_ids)
	if (
		characters.size() != 3
		or contracts.size() != 8
		or policies.size() != POLICY_ORDER.size()
		or routes != ["EVENT", "SERVICE"]
		or attempt_count != RUNS_REQUIRED_PER_GATE
	):
		return []
	var stratum_count := characters.size() * contracts.size() * policies.size()
	var base_count := floori(float(attempt_count) / float(stratum_count))
	var extra_per_policy: Array[int] = []
	for policy_index in range(policies.size()):
		var policy_total := floori(float(attempt_count) / float(policies.size()))
		if policy_index < attempt_count % policies.size():
			policy_total += 1
		extra_per_policy.append(policy_total - (base_count * characters.size() * contracts.size()))
	var result: Array[Dictionary] = []
	for policy_index in range(policies.size()):
		for character_index in range(characters.size()):
			for contract_index in range(contracts.size()):
				var pair_index := character_index * contracts.size() + contract_index
				var repetitions := base_count + (1 if pair_index < extra_per_policy[policy_index] else 0)
				for repetition in range(repetitions):
					result.append({
						"policy_id": policies[policy_index],
						"character_id": characters[character_index],
						"contract_id": contracts[contract_index],
						"route_id": routes[repetition % routes.size()],
					})
	return result if result.size() == attempt_count else []

static func stage4_beta_content_use_catalog() -> Dictionary:
	var accepted_budget_source := "GitHub issue #87 accepted production content budget; IDs from Phase2Catalog, AlphaScaleCatalog, and AlphaActTwoCatalog."
	var act_one_normals := Phase2CatalogScript.NORMAL_ENEMY_IDS + AlphaScaleCatalogScript.ACT_ONE_NORMAL_ENEMY_IDS
	var act_two_normals := AlphaScaleCatalogScript.ACT_TWO_NORMAL_ENEMY_IDS + AlphaActTwoCatalogScript.ACT_TWO_NORMAL_ENEMY_IDS
	var act_one_elites := [Phase2CatalogScript.ELITE_ENEMY_ID] + AlphaScaleCatalogScript.ACT_ONE_ELITE_ENEMY_IDS
	var act_two_elites := AlphaScaleCatalogScript.ACT_TWO_ELITE_ENEMY_IDS + [AlphaActTwoCatalogScript.ACT_TWO_ELITE_ENEMY_ID]
	var act_one_bosses := [Phase2CatalogScript.BOSS_ID, AlphaScaleCatalogScript.ACT_ONE_BOSS_ENEMY_ID]
	var act_two_bosses := [AlphaActTwoCatalogScript.ACT_TWO_BOSS_ENEMY_ID, AlphaActTwoCatalogScript.ACT_TWO_ALTERNATE_BOSS_ENEMY_ID]
	var act_one_events := Phase2CatalogScript.EVENT_IDS + AlphaScaleCatalogScript.ACT_ONE_EVENT_IDS
	var act_two_events := AlphaActTwoCatalogScript.ACT_TWO_EVENT_IDS + AlphaActTwoCatalogScript.ACT_TWO_ADDITIONAL_EVENT_IDS
	var run_techniques := Phase2CatalogScript.RUN_TECHNIQUE_IDS + AlphaScaleCatalogScript.RUN_TECHNIQUE_IDS
	var core_techniques := Phase2CatalogScript.CORE_TECHNIQUE_IDS + [AlphaScaleCatalogScript.CORE_TECHNIQUE_ID]
	return {
		"source": accepted_budget_source,
		"categories": {
			"acts": {"ids": ["ACT_1", "ACT_2"]},
			"characters": {"ids": _unique_sorted_ids(Phase2CatalogScript.CHARACTER_IDS + [AlphaScaleCatalogScript.CHARACTER_ID])},
			"contracts": {"ids": _unique_sorted_ids(Phase2CatalogScript.CONTRACT_IDS + AlphaScaleCatalogScript.CONTRACT_IDS)},
			"yaku": {"ids": _unique_sorted_ids(Phase2CatalogScript.PRODUCTION_YAKU_IDS + AlphaScaleCatalogScript.YAKU_IDS)},
			"relics": {"ids": _unique_sorted_ids(Phase2CatalogScript.RELIC_IDS + AlphaScaleCatalogScript.ACT_ONE_RELIC_IDS + AlphaScaleCatalogScript.RELIC_IDS)},
			"rule_breakers": {"ids": _unique_sorted_ids(AlphaScaleCatalogScript.ACT_ONE_BOSS_RULE_BREAKER_IDS + AlphaScaleCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_IDS)},
			"techniques": {
				"ids": _unique_sorted_ids(run_techniques + core_techniques),
				"source": "%s 21 Run Techniques plus 3 Character Core Techniques." % accepted_budget_source,
				"subcategories": {
					"run_techniques": {"ids": _unique_sorted_ids(run_techniques), "source": "#87 Run Technique budget: 21 IDs."},
					"core_techniques": {"ids": _unique_sorted_ids(core_techniques), "source": "#87 Character Core Technique budget: 3 IDs."},
				},
			},
			"modifiers": {"ids": _unique_sorted_ids(Phase2CatalogScript.MODIFIER_IDS + AlphaScaleCatalogScript.MODIFIER_IDS)},
			"normal_enemies": {
				"ids": _unique_sorted_ids(act_one_normals + act_two_normals),
				"subcategories": {
					"act_1": {"ids": _unique_sorted_ids(act_one_normals), "evidence_kind": "act_1_encountered", "source": "#87 Act 1 Normal enemy budget: 7 IDs."},
					"act_2": {"ids": _unique_sorted_ids(act_two_normals), "evidence_kind": "act_2_encountered", "source": "#87 Act 2 Normal enemy budget: 7 IDs."},
				},
			},
			"elite_enemies": {
				"ids": _unique_sorted_ids(act_one_elites + act_two_elites),
				"subcategories": {
					"act_1": {"ids": _unique_sorted_ids(act_one_elites), "evidence_kind": "act_1_encountered", "source": "#87 Act 1 Elite budget: 3 IDs."},
					"act_2": {"ids": _unique_sorted_ids(act_two_elites), "evidence_kind": "act_2_encountered", "source": "#87 Act 2 Elite budget: 3 IDs."},
				},
			},
			"bosses": {
				"ids": _unique_sorted_ids(act_one_bosses + act_two_bosses),
				"subcategories": {
					"act_1": {"ids": _unique_sorted_ids(act_one_bosses), "evidence_kind": "act_1_encountered", "source": "#87 Act 1 Boss budget: 2 IDs."},
					"act_2": {"ids": _unique_sorted_ids(act_two_bosses), "evidence_kind": "act_2_encountered", "source": "#87 Act 2 Boss budget: 2 IDs."},
				},
			},
			"events": {
				"ids": _unique_sorted_ids(act_one_events + act_two_events),
				"subcategories": {
					"act_1": {"ids": _unique_sorted_ids(act_one_events), "source": "Phase 2 plus Alpha Scale Act 1 event catalogs."},
					"act_2": {"ids": _unique_sorted_ids(act_two_events), "source": "Alpha Act Two event catalogs."},
				},
			},
		},
		"unobservable_categories": [
			"Tile IDs are reported when observed, but issue #87 defines no accepted Tile denominator.",
			"Per-item effect invocation counts and value-level effect outcomes are not represented by the collected factual evidence.",
		],
	}

static func _unique_sorted_ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var identifier := str(value)
		if not identifier.is_empty() and not result.has(identifier):
			result.append(identifier)
	result.sort()
	return result

static func _sorted_unique_string_values(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if not value is String or value.is_empty() or result.has(value):
			return []
		result.append(value)
	result.sort()
	return result

static func _ordered_policy_values(values: Array) -> Array[String]:
	var result := _sorted_unique_string_values(values)
	if result.size() != POLICY_ORDER.size():
		return []
	for policy in POLICY_ORDER:
		if not result.has(policy):
			return []
	var ordered: Array[String] = []
	for policy in POLICY_ORDER:
		ordered.append(policy)
	return ordered

func _string_ids(values, field_name: String) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		_errors.append("INVALID_ID_LIST:%s" % field_name)
		return result
	for value in values:
		if not value is String or value.is_empty():
			_errors.append("INVALID_ID:%s" % field_name)
			continue
		if not result.has(value):
			result.append(value)
	result.sort()
	return result

func _available_subset(requested: Array[String], available: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for identifier in requested:
		if available.has(identifier):
			result.append(identifier)
	return result

func _missing_ids(required: Array[String], available: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for identifier in required:
		if not available.has(identifier):
			result.append(identifier)
	return result
