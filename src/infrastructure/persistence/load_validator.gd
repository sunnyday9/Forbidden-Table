class_name LoadValidator
extends RefCounted

const DomainRngStreamsScript = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const MiniActMapCatalogScript = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const ShopOfferScript = preload("res://src/domain/run/shop_offer.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")

func validate(data: Dictionary, content_registry = null) -> Dictionary:
	var errors: Array = []
	for field in ["schema_version", "game_version", "content_version", "save_kind", "run_id", "run_seed", "rng_state", "checkpoint_metadata"]:
		if not data.has(field):
			errors.append({"code": "MISSING_FIELD", "field": field})
	if int(data.get("schema_version", -1)) != 1:
		errors.append({"code": "UNSUPPORTED_SCHEMA_VERSION"})
	if str(data.get("game_version", "")) != "game.phase2.v1":
		errors.append({"code": "UNSUPPORTED_GAME_VERSION"})
	if str(data.get("save_kind", "")) not in ["SUSPEND", "RUN_RECORD"]:
		errors.append({"code": "INVALID_SAVE_KIND"})
	if content_registry != null and str(data.get("content_version", "")) != content_registry.content_version():
		errors.append({"code": "UNSUPPORTED_CONTENT_VERSION"})
	if str(data.get("run_id", "")).is_empty():
		errors.append({"code": "MISSING_RUN_ID"})
	if typeof(data.get("rng_state")) != TYPE_DICTIONARY:
		errors.append({"code": "INVALID_RNG_STATE"})
	else:
		var streams := DomainRngStreamsScript.new(int(data.get("run_seed", 0)))
		if not streams.restore(data["rng_state"]):
			errors.append({"code": "INVALID_RNG_STATE"})
	if typeof(data.get("run_seed", null)) != TYPE_INT:
		errors.append({"code": "INVALID_RUN_SEED"})
	var state = data.get("authoritative_state", data.get("run_state", {}))
	if not state is Dictionary:
		errors.append({"code": "INVALID_AUTHORITATIVE_STATE"})
	else:
		if str(data.get("run_id", "")) != str(state.get("run_id", "")):
			errors.append({"code": "ENVELOPE_RUN_ID_MISMATCH"})
		if typeof(data.get("run_seed", null)) == TYPE_INT and typeof(state.get("seed", null)) == TYPE_INT and int(data["run_seed"]) != int(state["seed"]):
			errors.append({"code": "ENVELOPE_RUN_SEED_MISMATCH"})
		_validate_state(state, content_registry, errors)
	if state is Dictionary:
		_validate_checkpoint(data.get("checkpoint_metadata", {}), state, errors)
		var metadata = data.get("checkpoint_metadata", {})
		if metadata is Dictionary and metadata.has("state_hash") and str(metadata["state_hash"]) != DeterministicSerializerScript.hash(state):
			errors.append({"code": "STATE_HASH_MISMATCH"})
	return {"accepted": errors.is_empty(), "errors": errors}

func _validate_state(state: Dictionary, content_registry, errors: Array) -> void:
	var phase := str(state.get("phase", ""))
	if not RunPhaseScript.all().has(phase):
		errors.append({"code": "INVALID_RUN_PHASE", "phase": phase})
	for currency in ["gold", "refinement_tokens"]:
		if typeof(state.get(currency, null)) != TYPE_INT or int(state.get(currency, -1)) < 0:
			errors.append({"code": "INVALID_CURRENCY", "field": currency})
	var tile_ids: Dictionary = {}
	var tile_pool = state.get("tile_pool", {})
	if not tile_pool is Dictionary:
		errors.append({"code": "INVALID_TILE_POOL"})
		tile_pool = {}
	for tile in tile_pool.get("tile_instances", []):
		if not tile is Dictionary or str(tile.get("instance_id", "")).is_empty() or str(tile.get("definition_id", "")).is_empty():
			errors.append({"code": "INVALID_TILE_INSTANCE"})
			continue
		var instance_id := str(tile["instance_id"])
		if tile_ids.has(instance_id):
			errors.append({"code": "DUPLICATE_TILE_INSTANCE_ID", "instance_id": instance_id})
		tile_ids[instance_id] = true
		if str(tile.get("ownership_scope", "RUN")) != "RUN" or str(tile.get("lifetime_scope", tile.get("lifetime", "RUN"))) != "RUN":
			errors.append({"code": "INVALID_TILE_ZONE_OWNERSHIP", "instance_id": instance_id})
		_require_content(content_registry, str(tile.get("definition_id", "")), errors, "INVALID_TILE_CONTENT")
	var map_state = state.get("map_state", {})
	var shop_state = state.get("shop_state", {})
	var workshop_state = state.get("workshop_state", {})
	var event_state = state.get("event_state", {})
	if not map_state is Dictionary:
		errors.append({"code": "INVALID_MAP_STATE"})
	else:
		_validate_map(map_state, errors)
	if not shop_state is Dictionary:
		errors.append({"code": "INVALID_SHOP_PURCHASE_STATE"})
	else:
		_validate_shop(shop_state, content_registry, errors)
	if not workshop_state is Dictionary:
		errors.append({"code": "INVALID_WORKSHOP_PURCHASE_STATE"})
	else:
		_validate_workshop(workshop_state, errors)
	if not event_state is Dictionary:
		errors.append({"code": "INVALID_EVENT_STATE"})
	else:
		_validate_event(event_state, content_registry, errors)
	var battle_snapshot = state.get("current_battle_snapshot", {})
	if not battle_snapshot is Dictionary:
		errors.append({"code": "INVALID_BATTLE_SNAPSHOT"})
	for id_field in ["character_id", "contract_id"]:
		var identifier := str(state.get(id_field, ""))
		if not identifier.is_empty():
			_require_content(content_registry, identifier, errors, "INVALID_CONTENT_ID")
	var build = state.get("build_ownership", {})
	if not build is Dictionary:
		errors.append({"code": "INVALID_BUILD_STATE"})
		build = {}
	_require_content(content_registry, str(build.get("character_core_technique_id", "")), errors, "INVALID_CONTENT_ID")
	var owned_relic_ids = build.get("owned_relic_ids", [])
	var run_technique_ids = build.get("run_technique_ids", [])
	var special_offer_ids = build.get("owned_special_offer_ids", [])
	var rule_breaker_ids = build.get("acquired_rule_breaker_ids", [])
	if not owned_relic_ids is Array or not run_technique_ids is Array or not special_offer_ids is Array or not rule_breaker_ids is Array:
		errors.append({"code": "INVALID_BUILD_STATE"})
		return
	for identifier in owned_relic_ids + run_technique_ids + special_offer_ids + rule_breaker_ids:
		_require_content(content_registry, str(identifier), errors, "INVALID_CONTENT_ID")
	for instance_id in build.get("persistent_tile_modifier_state", {}).keys():
		if not tile_ids.has(str(instance_id)):
			errors.append({"code": "INVALID_MODIFIER_TARGET", "instance_id": str(instance_id)})

func _validate_map(map_state: Dictionary, errors: Array) -> void:
	var ordered = map_state.get("ordered_path", [])
	var visited = map_state.get("visited_node_ids", [])
	var node_ids = map_state.get("node_ids", [])
	var path_edges = map_state.get("path_edge_ids", [])
	if not ordered is Array or not visited is Array or not node_ids is Array or not path_edges is Array:
		errors.append({"code": "INVALID_MAP_PATH"})
		return
	var current := str(map_state.get("current_node_id", ""))
	if current.is_empty() and not ordered.is_empty():
		errors.append({"code": "INVALID_MAP_NODE"})
	if not current.is_empty() and not node_ids.has(current):
		errors.append({"code": "INVALID_MAP_NODE", "node_id": current})
	if ordered != visited or (ordered.size() > 0 and ordered[-1] != current):
		errors.append({"code": "INVALID_MAP_PATH"})
	if path_edges.size() != maxi(0, ordered.size() - 1):
		errors.append({"code": "INVALID_MAP_PATH"})
	if not current.is_empty():
		var definition = MiniActMapCatalogScript.definition()
		if str(map_state.get("map_definition_id", "")) != definition.content_id:
			errors.append({"code": "INVALID_MAP_DEFINITION"})
		for index in range(ordered.size() - 1):
			var node = definition.node_definition(str(ordered[index]))
			if node == null or not node.next_node_ids.has(str(ordered[index + 1])):
				errors.append({"code": "INVALID_MAP_PATH"})

func _validate_shop(shop: Dictionary, content_registry, errors: Array) -> void:
	if bool(shop.get("active", false)) and bool(shop.get("completed", false)):
		errors.append({"code": "INVALID_SHOP_PURCHASE_STATE"})

	var offer_ids: Dictionary = {}
	var offers = shop.get("offers", [])
	if not offers is Array:
		errors.append({"code": "INVALID_SHOP_PURCHASE_STATE"})
		offers = []
	for offer in offers:
		if not offer is Dictionary or str(offer.get("offer_id", "")).is_empty() or offer_ids.has(str(offer.get("offer_id", ""))):
			errors.append({"code": "INVALID_SHOP_PURCHASE_STATE"})
			continue
		offer_ids[str(offer["offer_id"])] = true
		if not [ShopOfferScript.AVAILABLE, ShopOfferScript.SOLD].has(str(offer.get("status", ""))) or typeof(offer.get("price", null)) != TYPE_INT or int(offer.get("price", -1)) < 0:
			errors.append({"code": "INVALID_SHOP_PURCHASE_STATE"})
		var content_id := str(offer.get("content_id", ""))
		if not content_id.is_empty():
			if content_registry == null:
				errors.append({"code": "CONTENT_REGISTRY_REQUIRED", "content_id": content_id})
			elif content_registry.resolve(content_id) == null:
				errors.append({"code": "INVALID_SHOP_CONTENT", "content_id": content_id})
	if int(shop.get("refreshes_remaining", 0)) < 0 or int(shop.get("refresh_count", 0)) < 0:
		errors.append({"code": "INVALID_SHOP_PURCHASE_STATE"})

func _validate_workshop(workshop: Dictionary, errors: Array) -> void:
	var used = workshop.get("used_service_ids", [])
	var available = workshop.get("available_service_ids", [])
	if not used is Array or not available is Array:
		errors.append({"code": "INVALID_WORKSHOP_PURCHASE_STATE"})
		return
	for service_id in used:
		if not available.has(service_id):
			errors.append({"code": "INVALID_WORKSHOP_PURCHASE_STATE"})

func _validate_event(event: Dictionary, content_registry, errors: Array) -> void:
	var event_id := str(event.get("event_id", ""))
	if not event_id.is_empty():
		if content_registry == null:
			errors.append({"code": "CONTENT_REGISTRY_REQUIRED", "content_id": event_id})
		elif content_registry.resolve(event_id) == null:
			errors.append({"code": "INVALID_EVENT_ID", "content_id": event_id})
	var selected := str(event.get("selected_choice_id", ""))
	if not selected.is_empty():
		var legal := false
		var choices = event.get("choices", [])
		if not choices is Array:
			errors.append({"code": "INVALID_EVENT_CHOICE"})
			return
		for choice in choices:
			if choice is Dictionary and str(choice.get("choice_id", "")) == selected:
				legal = true
		if not legal:
			errors.append({"code": "INVALID_EVENT_CHOICE"})

func _validate_checkpoint(metadata, state, errors: Array) -> void:
	if not metadata is Dictionary or not bool(metadata.get("stable", false)):
		errors.append({"code": "UNSTABLE_CHECKPOINT"})
	if not metadata is Dictionary:
		return
	var boundary := str(metadata.get("stable_boundary", ""))
	if boundary in ["EFFECT_QUEUE", "REACTION_WINDOW", "PATTERN_RESOLUTION", "BOSS_TRANSITION"]:
		errors.append({"code": "UNSTABLE_CHECKPOINT"})
	var phase := str(state.get("phase", ""))
	var valid_boundary := false
	match boundary:
		"MAP_NODE": valid_boundary = phase == RunPhaseScript.MAP_CHOICE
		"BATTLE_START", "TURN_START", "DRAW_ACTION", "SETTLEMENT_COMPLETE", "ENEMY_INTENT_COMPLETE": valid_boundary = phase == RunPhaseScript.BATTLE
		"SHOP": valid_boundary = phase == RunPhaseScript.SHOP
		"WORKSHOP": valid_boundary = phase == RunPhaseScript.WORKSHOP
		"EVENT_CHOICE_BEFORE", "EVENT_CHOICE_AFTER": valid_boundary = phase == RunPhaseScript.EVENT
		"REWARD": valid_boundary = phase in [RunPhaseScript.REWARD_CHOICE, RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD]
		"RUN_SUMMARY": valid_boundary = phase == RunPhaseScript.RUN_SUMMARY
		"RUN_COMPLETE": valid_boundary = phase == RunPhaseScript.RUN_COMPLETE
	if not valid_boundary:
		errors.append({"code": "CHECKPOINT_BOUNDARY_MISMATCH", "boundary": boundary, "phase": phase})
	var battle_snapshot = state.get("current_battle_snapshot", {})
	var has_battle_snapshot: bool = battle_snapshot is Dictionary and not battle_snapshot.is_empty()
	if phase == RunPhaseScript.BATTLE and not has_battle_snapshot:
		errors.append({"code": "MISSING_BATTLE_SNAPSHOT"})
	if phase != RunPhaseScript.BATTLE and has_battle_snapshot:
		errors.append({"code": "STALE_BATTLE_SNAPSHOT"})

func _require_content(registry, identifier: String, errors: Array, code: String) -> void:
	if identifier.is_empty():
		return
	if registry == null:
		errors.append({"code": "CONTENT_REGISTRY_REQUIRED", "content_id": identifier})
	elif registry.resolve(identifier) == null:
		errors.append({"code": code, "content_id": identifier})
