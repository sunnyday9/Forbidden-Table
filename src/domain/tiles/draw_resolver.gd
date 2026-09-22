class_name DrawResolver
extends RefCounted

const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const DrawEscalationPolicyScript = preload("res://src/domain/tiles/draw_escalation_policy.gd")
const DrawResultScript = preload("res://src/domain/tiles/draw_result.gd")
const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")
const ContaminationServiceScript = preload("res://src/domain/tiles/contamination_service.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var draw_wall
var zones
var combat_state
var policy
var fatigue := 0
var starvation_count := 0
var starvation_active := false
var contamination_service

func _init(domain_draw_wall, domain_zones, domain_combat_state = null, escalation_policy = null) -> void:
	draw_wall = domain_draw_wall
	zones = domain_zones
	combat_state = domain_combat_state
	policy = escalation_policy if escalation_policy != null else DrawEscalationPolicyScript.new()
	contamination_service = ContaminationServiceScript.new(domain_zones, domain_combat_state) if domain_zones != null else null

func set_combat_state(state) -> void:
	combat_state = state

func set_contamination_service(service) -> void:
	contamination_service = service

func apply_contamination(instance_id: String, contamination, sequence_index: int = -1):
	if contamination_service == null:
		return null
	return contamination_service.apply_contamination(instance_id, contamination, sequence_index)

func inject_contamination(
	instance_id: String,
	tile_definition_or_contamination,
	contamination = null,
	target_zone: String = TileZoneScript.DRAW_WALL,
	sequence_index: int = -1,
):
	if contamination_service == null:
		return null
	if contamination == null or contamination is int:
		var resolved_sequence: int = int(contamination) if contamination is int else sequence_index
		return contamination_service.apply_contamination(instance_id, tile_definition_or_contamination, resolved_sequence)
	return contamination_service.inject_contamination(instance_id, str(tile_definition_or_contamination), contamination, target_zone, sequence_index)

func cleanup_battle_contamination(sequence_index: int = -1) -> Array:
	return contamination_service.cleanup_battle(sequence_index) if contamination_service != null else []

func draw(requested_count = 1, source: String = DrawSourceScript.NORMAL_ACTION, sequence_index: int = -1):
	if requested_count is String:
		source = requested_count
		requested_count = 1
	var requested: int = maxi(0, int(requested_count))
	if not DrawSourceScript.is_valid(source):
		return _result(DrawResultScript.INVALID_SOURCE, requested, 0, requested, [], source, [])
	if draw_wall == null or not draw_wall.is_initialized():
		return _result(DrawResultScript.DRAW_WALL_NOT_READY, requested, 0, requested, [], source, [])
	if requested == 0:
		return _result(DrawResultScript.ACCEPTED, 0, 0, 0, [], source, [])

	var drawn_tiles: Array = []
	var events: Array = []
	while drawn_tiles.size() < requested:
		if draw_wall.size() == 0:
			if policy.can_reshuffle(source) and draw_wall.reshuffle_discard():
				events.append(DomainEventScript.new(DomainEventScript.DRAW_WALL_RESHUFFLED, {
					"source": source,
					"tile_count": draw_wall.size(),
					"sequence_index": sequence_index,
				}))
				events.append_array(_increment_fatigue(source, sequence_index))
				continue
			var shortfall := requested - drawn_tiles.size()
			events.append_array(_enter_starvation(requested, shortfall, source, sequence_index))
			break

		var tile_instance = draw_wall.draw_one()
		if tile_instance == null:
			return _result(DrawResultScript.TRANSFER_FAILED, requested, drawn_tiles.size(), requested - drawn_tiles.size(), drawn_tiles, source, events)
		drawn_tiles.append(tile_instance)
		events.append(DomainEventScript.new(DomainEventScript.TILE_DRAWN, {
			"instance_id": tile_instance.instance_id,
			"definition_id": tile_instance.definition_id,
			"source": source,
			"sequence_index": sequence_index,
		}))

	var status := DrawResultScript.ACCEPTED if drawn_tiles.size() == requested else DrawResultScript.STARVATION
	return _result(status, requested, drawn_tiles.size(), requested - drawn_tiles.size(), drawn_tiles, source, events)

func _increment_fatigue(source: String, sequence_index: int) -> Array:
	if combat_state != null and combat_state.has_method("increment_fatigue"):
		return combat_state.increment_fatigue(source, sequence_index)
	fatigue += 1
	return [DomainEventScript.new(DomainEventScript.FATIGUE_CHANGED, {
		"source": source,
		"previous_fatigue": fatigue - 1,
		"fatigue": fatigue,
		"amount": 1,
		"sequence_index": sequence_index,
	})]

func _enter_starvation(requested: int, shortfall: int, source: String, sequence_index: int) -> Array:
	if combat_state != null and combat_state.has_method("enter_starvation"):
		return combat_state.enter_starvation(requested, shortfall, source, sequence_index, policy)
	starvation_count += 1
	starvation_active = true
	var event_type := DomainEventScript.STARVATION_ENTERED if starvation_count == 1 else DomainEventScript.STARVATION_ESCALATED
	return [DomainEventScript.new(event_type, {
		"source": source,
		"requested": requested,
		"shortfall": shortfall,
		"starvation_count": starvation_count,
		"pressure_amount": policy.pressure_for_starvation(starvation_count) + policy.pressure_for_fatigue(fatigue),
		"sequence_index": sequence_index,
	})]

func _result(status: String, requested: int, drawn: int, shortfall: int, drawn_tiles: Array, source: String, events: Array):
	var result = DrawResultScript.new(
		status,
		requested,
		drawn,
		shortfall,
		drawn_tiles[0] if not drawn_tiles.is_empty() else null,
		events,
		source,
	)
	result.tile_instances = drawn_tiles.duplicate()
	return result
