class_name MetaProgressState
extends RefCounted

const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")

const PROFILE_DEFAULT := "default"
const PROFILE_ALL_UNLOCKED_TEST := "test.all_unlocked"
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")

var profile_id := PROFILE_DEFAULT
var discovered_character_ids: Array[String] = []
var unlocked_character_ids: Array[String] = []
var discovered_contract_ids: Array[String] = []
var unlocked_contract_ids: Array[String] = []
var act_two_normal_ending_run_ids: Array[String] = []

func _init(initial_profile_id: String = PROFILE_DEFAULT) -> void:
	profile_id = initial_profile_id
	var initial_characters := Phase2CatalogScript.CHARACTER_IDS.duplicate()
	var initial_contracts := Phase2CatalogScript.CONTRACT_IDS.duplicate()
	if profile_id == PROFILE_ALL_UNLOCKED_TEST:
		initial_characters = AlphaScaleCatalogScript.all_character_ids()
		initial_contracts = AlphaScaleCatalogScript.all_contract_ids()
	discovered_character_ids = _string_ids(initial_characters)
	unlocked_character_ids = _string_ids(initial_characters)
	discovered_contract_ids = _string_ids(initial_contracts)
	unlocked_contract_ids = _string_ids(initial_contracts)

static func all_unlocked_test_profile():
	return MetaProgressStateScript.new(PROFILE_ALL_UNLOCKED_TEST)

func is_test_profile() -> bool:
	return profile_id == PROFILE_ALL_UNLOCKED_TEST

func is_unlocked(kind: String, content_id: String) -> bool:
	match kind:
		"CHARACTER":
			return unlocked_character_ids.has(content_id)
		"CONTRACT":
			return unlocked_contract_ids.has(content_id)
		_:
			return true

func record_act_two_normal_ending(run_id: String) -> bool:
	if is_test_profile() or run_id.is_empty() or act_two_normal_ending_run_ids.has(run_id):
		return false
	act_two_normal_ending_run_ids.append(run_id)
	_discover_and_unlock(discovered_character_ids, unlocked_character_ids, AlphaScaleCatalogScript.all_character_ids())
	_discover_and_unlock(discovered_contract_ids, unlocked_contract_ids, AlphaScaleCatalogScript.all_contract_ids())
	return true

func progress_count() -> int:
	return act_two_normal_ending_run_ids.size()

func to_dictionary() -> Dictionary:
	return {
		"profile_id": profile_id,
		"discovered_character_ids": discovered_character_ids.duplicate(),
		"unlocked_character_ids": unlocked_character_ids.duplicate(),
		"discovered_contract_ids": discovered_contract_ids.duplicate(),
		"unlocked_contract_ids": unlocked_contract_ids.duplicate(),
		"progress": {
			"act_two_normal_ending_count": act_two_normal_ending_run_ids.size(),
			"act_two_normal_ending_run_ids": act_two_normal_ending_run_ids.duplicate(),
		},
	}

static func from_dictionary(data: Dictionary) -> Dictionary:
	var profile := MetaProgressStateScript.new(str(data.get("profile_id", PROFILE_DEFAULT)))
	if profile.is_test_profile():
		return {"accepted": false, "code": "TEST_PROFILE_CANNOT_BE_PERSISTED"}
	var known_characters := AlphaScaleCatalogScript.all_character_ids()
	var known_contracts := AlphaScaleCatalogScript.all_contract_ids()
	var state_keys := [
		["discovered_character_ids", "unlocked_character_ids", known_characters],
		["discovered_contract_ids", "unlocked_contract_ids", known_contracts],
	]
	for state_key in state_keys:
		var discovered_key: String = state_key[0]
		var unlocked_key: String = state_key[1]
		var known_ids: Array = state_key[2]
		var discovered := _read_ids(data.get(discovered_key, []), known_ids)
		var unlocked := _read_ids(data.get(unlocked_key, []), known_ids)
		if not discovered.accepted or not unlocked.accepted:
			return {"accepted": false, "code": "INVALID_META_CONTENT_IDS", "field": discovered_key if not discovered.accepted else unlocked_key}
		for content_id in unlocked.ids:
			if not discovered.ids.has(content_id):
				return {"accepted": false, "code": "UNLOCKED_CONTENT_NOT_DISCOVERED", "content_id": content_id}
		if discovered_key == "discovered_character_ids":
			profile.discovered_character_ids = discovered.ids
			profile.unlocked_character_ids = unlocked.ids
		else:
			profile.discovered_contract_ids = discovered.ids
			profile.unlocked_contract_ids = unlocked.ids
	for identifier in Phase2CatalogScript.CHARACTER_IDS:
		if not profile.discovered_character_ids.has(identifier) or not profile.unlocked_character_ids.has(identifier):
			return {"accepted": false, "code": "MISSING_BASE_CHARACTER_UNLOCK", "content_id": identifier}
	for identifier in Phase2CatalogScript.CONTRACT_IDS:
		if not profile.discovered_contract_ids.has(identifier) or not profile.unlocked_contract_ids.has(identifier):
			return {"accepted": false, "code": "MISSING_BASE_CONTRACT_UNLOCK", "content_id": identifier}
	var progress: Variant = data.get("progress", {})
	if not progress is Dictionary:
		return {"accepted": false, "code": "INVALID_META_PROGRESS"}
	var ending_run_ids: Variant = progress.get("act_two_normal_ending_run_ids", [])
	if not ending_run_ids is Array:
		return {"accepted": false, "code": "INVALID_META_PROGRESS"}
	var seen: Dictionary = {}
	profile.act_two_normal_ending_run_ids.clear()
	for run_id_value in ending_run_ids:
		if not run_id_value is String or str(run_id_value).is_empty() or seen.has(str(run_id_value)):
			return {"accepted": false, "code": "INVALID_META_PROGRESS"}
		seen[str(run_id_value)] = true
		profile.act_two_normal_ending_run_ids.append(str(run_id_value))
	if typeof(progress.get("act_two_normal_ending_count", profile.act_two_normal_ending_run_ids.size())) != TYPE_INT:
		return {"accepted": false, "code": "INVALID_META_PROGRESS"}
	if int(progress.get("act_two_normal_ending_count", profile.act_two_normal_ending_run_ids.size())) != profile.act_two_normal_ending_run_ids.size():
		return {"accepted": false, "code": "META_PROGRESS_COUNT_MISMATCH"}
	if profile.progress_count() > 0 and (profile.unlocked_character_ids.size() != known_characters.size() or profile.unlocked_contract_ids.size() != known_contracts.size()):
		return {"accepted": false, "code": "META_MILESTONE_UNLOCK_MISSING"}
	if profile.progress_count() == 0 and (profile.unlocked_character_ids.size() > Phase2CatalogScript.CHARACTER_IDS.size() or profile.unlocked_contract_ids.size() > Phase2CatalogScript.CONTRACT_IDS.size()):
		return {"accepted": false, "code": "META_UNLOCK_WITHOUT_NORMAL_ENDING"}
	return {"accepted": true, "state": profile}

func _discover_and_unlock(discovered: Array[String], unlocked: Array[String], identifiers: Array[String]) -> void:
	for identifier in identifiers:
		if not discovered.has(identifier):
			discovered.append(identifier)
		if not unlocked.has(identifier):
			unlocked.append(identifier)

static func _read_ids(value: Variant, known_ids: Array[String]) -> Dictionary:
	if not value is Array:
		return {"accepted": false, "ids": []}
	var result: Array[String] = []
	for identifier in value:
		if not identifier is String or not known_ids.has(str(identifier)) or result.has(str(identifier)):
			return {"accepted": false, "ids": []}
		result.append(str(identifier))
	return {"accepted": true, "ids": result}

static func _string_ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
