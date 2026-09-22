class_name ContaminationTest
extends RefCounted

const ContaminationCleanupPolicy = preload("res://src/domain/tiles/contamination_cleanup_policy.gd")
const ContaminationDefinition = preload("res://src/domain/tiles/contamination_definition.gd")
const ContaminationCatalog = preload("res://src/domain/tiles/contamination_catalog.gd")
const ContaminationService = preload("res://src/domain/tiles/contamination_service.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const CombatResolver = preload("res://src/domain/combat/combat_resolver.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const BattleDomain = preload("res://src/domain/battle/battle_domain.gd")
const DrawResolver = preload("res://src/domain/tiles/draw_resolver.gd")
const DrawWall = preload("res://src/domain/tiles/draw_wall.gd")
const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const Effect = preload("res://src/domain/effects/effect.gd")
const EffectContext = preload("res://src/domain/effects/effect_context.gd")
const EffectTrigger = preload("res://src/domain/effects/effect_trigger.gd")
const ApplyContaminationOperation = preload("res://src/domain/effects/operations/apply_contamination_operation.gd")
const ExhaustTileOperation = preload("res://src/domain/effects/operations/exhaust_tile_operation.gd")
const PurgeContaminationOperation = preload("res://src/domain/effects/operations/purge_contamination_operation.gd")
const InjectContaminationOperation = preload("res://src/domain/effects/operations/inject_contamination_operation.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileLifetime = preload("res://src/domain/tiles/tile_lifetime.gd")
const TileOrigin = preload("res://src/domain/tiles/tile_origin.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_contaminated_tile_preserves_grammar_through_checkpoint(failures)
	test_contamination_service_applies_observes_and_rejects_atomically(failures)
	test_exhaust_and_purge_are_distinct_recoverability_transitions(failures)
	test_battle_cleanup_clears_run_tiles_and_removes_injected_tiles_without_purge_events(failures)
	test_contamination_application_and_cleanse_are_typed_queue_effects(failures)
	test_battle_domain_end_boundary_cleans_contamination_once(failures)
	test_shared_catalog_and_injection_effect_are_deterministic(failures)
	test_draw_resolver_preserves_contaminated_tiles_in_battle_circulation(failures)
	return failures

func test_contaminated_tile_preserves_grammar_through_checkpoint(failures: Array[String]) -> void:
	var configured_effect := {"kind": "PRESSURE", "amount": 2}
	var contamination := ContaminationDefinition.new(
		"base.contamination.pressure_dross",
		configured_effect,
		TileOrigin.ENEMY,
		TileLifetime.BATTLE,
		true,
		true,
		ContaminationCleanupPolicy.REMOVE_TILE,
	)
	var tile := TileInstance.new("battle.contamination.001", "base.tile.man.1")

	assert_true(tile.apply_contamination(contamination), "a valid contamination can be applied to a TileInstance", failures)
	assert_true(tile.is_contaminated(), "the TileInstance exposes its contaminated state", failures)
	assert_true(tile.origin == TileOrigin.ENEMY, "contamination records its TileOrigin", failures)
	assert_true(tile.lifetime == TileLifetime.BATTLE, "contamination records its TileLifetime", failures)
	assert_true(tile.contamination_id == "base.contamination.pressure_dross", "contamination identity is observable", failures)
	assert_true(tile.contamination_effect == configured_effect, "the configured contamination Effect is observable", failures)
	assert_true(tile.can_exhaust_contamination and tile.can_purge_contamination, "cleanup permissions are carried by the contaminated tile", failures)
	assert_true(tile.cleanup_policy == ContaminationCleanupPolicy.REMOVE_TILE, "battle cleanup policy is observable", failures)

	var checkpoint: Dictionary = tile.to_dictionary()
	assert_true(checkpoint["origin"] == TileOrigin.ENEMY, "TileOrigin survives a TileInstance checkpoint", failures)
	assert_true(checkpoint["lifetime"] == TileLifetime.BATTLE, "TileLifetime survives a TileInstance checkpoint", failures)
	assert_true(checkpoint["contamination"]["contamination_id"] == "base.contamination.pressure_dross", "contamination identity survives a checkpoint", failures)
	assert_true(checkpoint["contamination"]["configured_effect"] == configured_effect, "configured contamination Effect survives a checkpoint", failures)
	var restored = TileInstance.from_checkpoint(checkpoint)
	assert_true(restored != null and restored.contamination_id == tile.contamination_id, "a contaminated TileInstance restores from its checkpoint", failures)
	assert_true(restored.origin == TileOrigin.ENEMY and restored.lifetime == TileLifetime.BATTLE, "restored contamination retains origin and lifetime", failures)

func test_contamination_service_applies_observes_and_rejects_atomically(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var tile := TileInstance.new("battle.contamination.service.001", "base.tile.man.2")
	zones.add(tile, TileZone.HAND)
	var service := ContaminationService.new(zones)
	var contamination := ContaminationDefinition.new("base.contamination.clutter", {"kind": "DRAW_DISRUPTION"})

	var applied = service.apply_contamination(tile.instance_id, contamination)
	assert_true(applied.is_accepted(), "ContaminationService applies a valid contamination target", failures)
	assert_true(service.observe(tile.instance_id) == tile, "ContaminationService observes the authoritative TileInstance", failures)
	assert_true(tile.contamination_id == "base.contamination.clutter", "service application updates the tile identity", failures)

	var before_ids := _zone_ids(zones, TileZone.HAND)
	var rejected = service.apply_contamination("battle.contamination.missing", contamination)
	assert_true(not rejected.is_accepted() and rejected.status == "INVALID_TILE", "missing contamination targets are rejected", failures)
	assert_true(_zone_ids(zones, TileZone.HAND) == before_ids, "an invalid contamination target leaves zones unchanged", failures)
	assert_true(tile.contamination_id == "base.contamination.clutter", "an invalid contamination target leaves existing contamination unchanged", failures)

func _zone_ids(zones, zone: String) -> Array[String]:
	var ids: Array[String] = []
	for tile in zones.contents(zone):
		ids.append(tile.instance_id)
	return ids

func test_exhaust_and_purge_are_distinct_recoverability_transitions(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var exhaust_tile := TileInstance.new("battle.contamination.exhaust", "base.tile.man.3")
	var purge_tile := TileInstance.new("battle.contamination.purge", "base.tile.man.4")
	var protected_tile := TileInstance.new("battle.contamination.protected", "base.tile.man.5")
	for tile in [exhaust_tile, purge_tile, protected_tile]:
		zones.add(tile, TileZone.HAND)
	var service := ContaminationService.new(zones)
	var recoverable := ContaminationDefinition.new("base.contamination.recoverable", {}, TileOrigin.ENEMY, TileLifetime.BATTLE, true, true)
	var protected := ContaminationDefinition.new("base.contamination.protected", {}, TileOrigin.ENEMY, TileLifetime.BATTLE, false, false)
	service.apply_contamination(exhaust_tile.instance_id, recoverable)
	service.apply_contamination(purge_tile.instance_id, recoverable)
	service.apply_contamination(protected_tile.instance_id, protected)

	var exhausted = service.exhaust(exhaust_tile.instance_id)
	assert_true(exhausted.is_accepted(), "Exhaust accepts an eligible contaminated tile", failures)
	assert_true(zones.contains_in_zone(exhaust_tile.instance_id, TileZone.EXHAUST), "Exhaust moves contamination to recoverable battle Exhaust", failures)
	assert_true(exhaust_tile.is_contaminated(), "Exhaust preserves contamination for explicit recovery", failures)
	assert_true(_has_event(exhausted.events, DomainEvent.TILE_EXHAUSTED), "Exhaust emits the existing TileExhausted event", failures)

	var purged = service.purge(purge_tile.instance_id)
	assert_true(purged.is_accepted(), "Purge accepts an eligible contaminated tile", failures)
	assert_true(zones.contains_in_zone(purge_tile.instance_id, TileZone.PURGED), "Purge moves a tile out of the active battle lifecycle", failures)
	assert_true(not zones.contains_in_zone(purge_tile.instance_id, TileZone.EXHAUST), "Purge does not use the recoverable Exhaust zone", failures)
	assert_true(not zones.transfer(purge_tile.instance_id, TileZone.PURGED, TileZone.HAND), "ordinary zone transfer cannot recover a Purged tile", failures)
	assert_true(_has_event(purged.events, DomainEvent.TILE_PURGED), "Purge emits a distinct TilePurged event", failures)

	var rejected_exhaust = service.exhaust(protected_tile.instance_id)
	var rejected_purge = service.purge(protected_tile.instance_id)
	assert_true(rejected_exhaust.status == "CANNOT_EXHAUST" and rejected_purge.status == "CANNOT_PURGE", "configured cleanup permissions reject unsupported operations", failures)
	var generic_exhaust := ExhaustTileOperation.new(protected_tile.instance_id)
	assert_true(generic_exhaust.validate(EffectContext.new(CombatState.new(10, 10), zones), {}) == "CANNOT_EXHAUST", "generic Exhaust Effects cannot bypass contamination cleanup permissions", failures)
	assert_true(zones.contains_in_zone(protected_tile.instance_id, TileZone.HAND), "rejected cleanup leaves the target zone unchanged", failures)

func test_battle_cleanup_clears_run_tiles_and_removes_injected_tiles_without_purge_events(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var run_tile := TileInstance.new("run.contaminated", "base.tile.man.6")
	var injected_tile := TileInstance.new("battle.injected", "base.tile.man.7", TileOrigin.ENEMY, TileLifetime.BATTLE)
	zones.add(run_tile, TileZone.HAND)
	zones.add(injected_tile, TileZone.DISCARD)
	var service := ContaminationService.new(zones)
	var contamination := ContaminationDefinition.new("base.contamination.battle_only", {"kind": "CLUTTER"})
	service.apply_contamination(run_tile.instance_id, contamination)
	service.apply_contamination(injected_tile.instance_id, contamination)

	var events: Array = service.cleanup_battle()
	assert_true(not run_tile.is_contaminated(), "battle cleanup clears battle-only contamination from a Run tile", failures)
	assert_true(run_tile.origin == TileOrigin.RUN_POOL and run_tile.lifetime == TileLifetime.RUN, "battle cleanup restores a Run tile's base origin and lifetime", failures)
	assert_true(zones.contains_in_zone(run_tile.instance_id, TileZone.HAND), "battle cleanup preserves the Run tile's active zone", failures)
	assert_true(zones.contains_in_zone(injected_tile.instance_id, TileZone.PURGED), "battle cleanup removes an injected battle-only tile", failures)
	assert_true(_has_event(events, DomainEvent.BATTLE_CONTAMINATION_CLEANED), "battle cleanup emits a lifecycle cleanup fact", failures)
	assert_true(not _has_event(events, DomainEvent.TILE_PURGED), "battle cleanup does not emit gameplay Purge events", failures)
	assert_true(not _has_event(events, DomainEvent.TILE_EXHAUSTED), "battle cleanup does not emit gameplay Exhaust events", failures)
	for event in events:
		assert_true(event.data.get("reward_triggers", true) == false, "battle cleanup explicitly suppresses reward triggers", failures)

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func test_contamination_application_and_cleanse_are_typed_queue_effects(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var tile := TileInstance.new("battle.contamination.effect", "base.tile.man.8")
	zones.add(tile, TileZone.HAND)
	var state := CombatState.new(10, 10)
	var context := EffectContext.new(state, zones)
	var contamination := ContaminationDefinition.new("base.contamination.effect", {"kind": "CLUTTER"})

	var application = Effect.new(
		"prototype.contamination.apply",
		EffectTrigger.new(EffectTrigger.MANUAL),
		[],
		[],
		[ApplyContaminationOperation.new(tile.instance_id, contamination)],
	)
	var applied = CombatResolver.new().resolve_atomic_queue(state, [application], context)
	assert_true(applied.is_resolved(), "contamination application resolves through the Effect queue", failures)
	assert_true(tile.is_contaminated(), "the typed application Effect changes the TileInstance", failures)
	assert_true(_has_event(applied.events, DomainEvent.CONTAMINATION_APPLIED), "typed contamination application emits a domain event", failures)

	var cleanse = Effect.new(
		"prototype.contamination.cleanse",
		EffectTrigger.new(EffectTrigger.MANUAL),
		[],
		[],
		[PurgeContaminationOperation.new(tile.instance_id)],
	)
	var purged = CombatResolver.new().resolve_atomic_queue(state, [cleanse], context)
	assert_true(purged.is_resolved(), "dedicated contamination cleanup resolves through the Effect queue", failures)
	assert_true(zones.contains_in_zone(tile.instance_id, TileZone.PURGED), "dedicated cleanup uses Purge semantics", failures)
	assert_true(_has_event(purged.events, DomainEvent.TILE_PURGED), "dedicated cleanup emits the Purge event", failures)

func test_battle_domain_end_boundary_cleans_contamination_once(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var tile := TileInstance.new("battle.contamination.boundary", "base.tile.man.9", TileOrigin.ENEMY, TileLifetime.BATTLE)
	zones.add(tile, TileZone.DRAW_WALL)
	var state := CombatState.new(10, 10)
	state.terminal_outcome = CombatState.VICTORY
	var battle := BattleDomain.new(zones, null, null, null, null, null, null, null, state, null)
	var contamination := ContaminationDefinition.new("base.contamination.boundary", {"kind": "CLUTTER"})
	battle.contamination_service.apply_contamination(tile.instance_id, contamination)

	var first_events: Array = battle.end_battle()
	var second_events: Array = battle.end_battle()
	assert_true(zones.contains_in_zone(tile.instance_id, TileZone.PURGED), "BattleDomain end cleanup removes battle-only contamination at the terminal boundary", failures)
	assert_true(_has_event(first_events, DomainEvent.BATTLE_CONTAMINATION_CLEANED), "BattleDomain exposes the lifecycle cleanup event", failures)
	assert_true(second_events.is_empty(), "Battle-end contamination cleanup is idempotent", failures)
	for event in first_events:
		assert_true(event.data.get("reward_triggers", true) == false, "BattleDomain cleanup cannot trigger rewards or acquisition", failures)

	var checkpoint: Dictionary = battle.checkpoint()
	assert_true(checkpoint.has("tile_instances"), "Battle checkpoints include TileInstance state in addition to zone IDs", failures)
	assert_true(checkpoint["tile_instances"].size() == 1, "Battle checkpoint retains the purged TileInstance record", failures)
	assert_true(checkpoint["tile_instances"][0]["lifetime"] == TileLifetime.BATTLE, "Battle checkpoint retains TileLifetime", failures)

func test_shared_catalog_and_injection_effect_are_deterministic(failures: Array[String]) -> void:
	var catalog := ContaminationCatalog.all()
	assert_true(catalog.size() >= 2 and catalog.size() <= 4, "the shared grammar exposes two to four reusable contamination types", failures)
	var ids: Array[String] = []
	for definition in catalog:
		ids.append(definition.contamination_id)
	assert_true(ids == ["base.contamination.clutter", "base.contamination.pressure_dross", "base.contamination.fatigue_mold"], "shared contamination IDs are stable and content-addressable", failures)

	var first := _run_injection_effect(catalog[0])
	var second := _run_injection_effect(catalog[0])
	assert_true(first == second, "identical contamination injection Effects produce identical state and events", failures)
	assert_true(first["draw_wall"] == ["battle.injected.effect"], "injection places a contaminated TileInstance in the Draw Wall", failures)
	assert_true(first["tile"]["origin"] == TileOrigin.ENEMY and first["tile"]["lifetime"] == TileLifetime.BATTLE, "injection assigns battle grammar metadata", failures)
	assert_true(first["events"][0]["event_type"] == DomainEvent.TILE_INJECTED and first["events"][1]["event_type"] == DomainEvent.CONTAMINATION_APPLIED, "injection events preserve causal order", failures)

func _run_injection_effect(contamination) -> Dictionary:
	var zones := TileZoneContainer.new()
	var state := CombatState.new(10, 10)
	var context := EffectContext.new(state, zones)
	var effect := Effect.new(
		"prototype.contamination.inject",
		EffectTrigger.new(EffectTrigger.MANUAL),
		[],
		[],
		[InjectContaminationOperation.new("battle.injected.effect", "base.tile.man.9", contamination, TileZone.DRAW_WALL)],
	)
	var result = CombatResolver.new().resolve_atomic_queue(state, [effect], context)
	var tile = zones.contents(TileZone.DRAW_WALL)[0] if not zones.contents(TileZone.DRAW_WALL).is_empty() else null
	return {
		"resolved": result.is_resolved(),
		"events": result.to_dictionary()["events"],
		"draw_wall": _zone_ids(zones, TileZone.DRAW_WALL),
		"tile": tile.to_dictionary() if tile != null else {},
	}

func test_draw_resolver_preserves_contaminated_tiles_in_battle_circulation(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new()
	var state := CombatState.new(10, 10)
	var wall := DrawWall.new(zones, DomainRngStreams.new(77).draw_wall)
	assert_true(wall.initialize(), "DrawResolver fixture initializes an empty Draw Wall", failures)
	var resolver := DrawResolver.new(wall, zones, state)
	var contamination = ContaminationCatalog.by_id("base.contamination.clutter")
	var injected = resolver.inject_contamination("battle.draw.injected", "base.tile.man.1", contamination, TileZone.DRAW_WALL)
	assert_true(injected.is_accepted(), "DrawResolver accepts deterministic contamination injection", failures)
	assert_true(wall.size() == 1, "injected contamination participates in Draw Wall size", failures)
	var draw_result = resolver.draw(1)
	assert_true(draw_result.is_accepted() and draw_result.tile_instance.contamination_id == contamination.contamination_id, "DrawResolver draws the contaminated TileInstance through normal circulation", failures)
	assert_true(zones.contains_in_zone("battle.draw.injected", TileZone.HAND), "DrawResolver transfers the contaminated tile to Hand", failures)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
