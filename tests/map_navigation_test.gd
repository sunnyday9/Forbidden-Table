class_name MapNavigationTest
extends RefCounted

const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const MiniActMapCatalog = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const RelicDefinition = preload("res://src/content/definitions/relic_definition.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")

const INTRO := "base.map_node.intro"
const LEFT := "base.map_node.normal.left"
const RIGHT := "base.map_node.normal.right"
const SHOP := "base.map_node.shop"
const WORKSHOP := "base.map_node.workshop"
const EVENT_LEFT := "base.map_node.event.left"
const EVENT_RIGHT := "base.map_node.event.right"
const MID := "base.map_node.normal.mid"
const ELITE := "base.map_node.elite"
const BOSS := "base.map_node.boss"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_authored_graph_is_bounded_and_route_safe(failures)
	test_contract_choice_initializes_visible_deterministic_map(failures)
	test_valid_route_reaches_boss_and_records_stable_edge_path(failures)
	test_every_authored_route_reaches_boss(failures)
	test_invalid_map_selection_is_atomic_and_does_not_consume_map_rng(failures)
	test_same_seed_and_accepted_map_commands_reproduce_checkpoint(failures)
	test_map_command_serializes_stable_node_id(failures)
	return failures

func test_authored_graph_is_bounded_and_route_safe(failures: Array[String]) -> void:
	var definition = MiniActMapCatalog.definition()
	var issues: Array = definition.graph_issues()
	assert_true(issues.is_empty(), "the authored Mini-Act graph has no topology issues", failures)
	assert_true(definition.node_ids.size() == 10, "the Mini-Act graph has exactly ten authored nodes", failures)
	assert_true(definition.count_nodes_of_kind("BATTLE") == 4, "the graph has four Normal battle nodes", failures)
	assert_true(definition.count_nodes_of_kind("ELITE") == 1, "the graph has one Elite node", failures)
	assert_true(definition.count_nodes_of_kind("SHOP") == 1, "the graph has one Shop node", failures)
	assert_true(definition.count_nodes_of_kind("WORKSHOP") == 1, "the graph has one Workshop node", failures)
	assert_true(definition.count_nodes_of_kind("EVENT") == 2, "the graph has two Event opportunities", failures)
	assert_true(definition.count_nodes_of_kind("BOSS") == 1, "the graph has one Boss node", failures)
	assert_true(definition.start_node_id == INTRO, "the graph starts at the mandatory introductory Normal", failures)
	assert_true(definition.branch_decision_count_before(ELITE) >= 2, "at least two branch decisions precede the Elite", failures)
	assert_true(definition.has_route_through([SHOP, WORKSHOP], BOSS), "a valid route exposes both Shop and Workshop", failures)

func test_contract_choice_initializes_visible_deterministic_map(failures: Array[String]) -> void:
	var domain := _prepared_domain("map.visibility", 101)
	var map_state = domain.state.map_state

	assert_true(domain.state.phase == RunPhase.MAP_CHOICE, "Contract choice enters Map Choice", failures)
	assert_true(map_state.current_node_id == INTRO, "the mandatory introductory Normal is the current node", failures)
	assert_true(map_state.ordered_path == [INTRO], "the map path starts at the introductory Normal", failures)
	assert_true(map_state.knowledge_state[INTRO] == "EXACT", "the current node identity is exact", failures)
	assert_true(map_state.knowledge_state[LEFT] == "EXACT", "an immediately selectable node is exact", failures)
	assert_true(map_state.knowledge_state[BOSS] == "PARTIAL", "a distant node keeps partial identity visibility", failures)
	assert_true(map_state.node_kinds[BOSS] == "BOSS", "topology exposes a distant node's kind", failures)
	assert_true(map_state.visible_payload_id(LEFT) == map_state.payload_ids[LEFT], "an adjacent node exposes its payload identity", failures)
	assert_true(map_state.visible_payload_id(BOSS).is_empty(), "a distant node hides its payload identity", failures)
	assert_true(map_state.payload_ids.size() == 10, "every authored node receives a deterministic payload ID", failures)
	assert_true(map_state.edge_ids.size() == 12, "every authored edge has a stable edge ID", failures)
	assert_true(not map_state.map_rng_state.is_empty(), "map state records the Map RNG checkpoint", failures)

func test_valid_route_reaches_boss_and_records_stable_edge_path(failures: Array[String]) -> void:
	var domain := _prepared_domain("map.route", 202)
	for node_id in [LEFT, SHOP, WORKSHOP, MID, ELITE, BOSS]:
		var result = domain.execute(SelectMapNodeCommand.new("map.route.%s" % node_id, node_id))
		assert_true(result.accepted, "valid route accepts %s" % node_id, failures)

	assert_true(domain.state.map_state.current_node_id == BOSS, "the valid route reaches the Boss", failures)
	assert_true(domain.state.map_state.ordered_path == [INTRO, LEFT, SHOP, WORKSHOP, MID, ELITE, BOSS], "the map path records stable node IDs", failures)
	assert_true(domain.state.map_state.path_edge_ids.size() == 6, "the map path records one stable edge per transition", failures)
	assert_true(domain.state.map_state.to_dictionary().has("edge_ids"), "map serialization includes authored edge IDs", failures)
	assert_true(domain.state.map_state.to_dictionary().has("payload_ids"), "map serialization includes payload IDs", failures)
	assert_true(domain.state.map_state.to_dictionary().has("knowledge_state"), "map serialization includes knowledge state", failures)
	assert_true(_has_event(domain.state.map_state.last_events, DomainEvent.MAP_NODE_SELECTED), "map traversal emits a factual selection event", failures)

func test_every_authored_route_reaches_boss(failures: Array[String]) -> void:
	var route_choices := [[LEFT, SHOP, WORKSHOP], [LEFT, EVENT_LEFT], [RIGHT, WORKSHOP], [RIGHT, EVENT_RIGHT]]
	for route_index in route_choices.size():
		var domain := _prepared_domain("map.route.%d" % route_index, 250 + route_index)
		for node_id in route_choices[route_index] + [MID, ELITE, BOSS]:
			var result = domain.execute(SelectMapNodeCommand.new("map.route.%d.%s" % [route_index, node_id], node_id))
			assert_true(result.accepted, "authored route %d accepts %s" % [route_index, node_id], failures)
		assert_true(domain.state.map_state.current_node_id == BOSS, "authored route %d reaches the Boss" % route_index, failures)

func test_invalid_map_selection_is_atomic_and_does_not_consume_map_rng(failures: Array[String]) -> void:
	var domain := _prepared_domain("map.invalid", 303)
	var before := domain.checkpoint()
	var rng_before := domain.rng_snapshot()
	var unknown = domain.execute(SelectMapNodeCommand.new("map.invalid.unknown", "base.map_node.missing"))
	assert_true(not unknown.accepted, "an unknown node ID is rejected", failures)
	assert_true(unknown.validation.code == "INVALID_MAP_NODE_ID", "unknown node rejection is explicit", failures)
	assert_true(domain.checkpoint() == before, "unknown node selection leaves state unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "unknown node selection does not consume Map RNG", failures)

	var non_adjacent = domain.execute(SelectMapNodeCommand.new("map.invalid.far", WORKSHOP))
	assert_true(not non_adjacent.accepted, "a non-adjacent node is rejected", failures)
	assert_true(non_adjacent.validation.code == "NON_ADJACENT_NODE", "non-adjacent rejection is explicit", failures)
	assert_true(domain.checkpoint() == before, "non-adjacent selection leaves state unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "non-adjacent selection does not consume Map RNG", failures)

	domain.execute(SelectMapNodeCommand.new("map.invalid.left", LEFT))
	var visited_before := domain.checkpoint()
	var visited_rng_before := domain.rng_snapshot()
	var visited = domain.execute(SelectMapNodeCommand.new("map.invalid.visited", INTRO))
	assert_true(not visited.accepted and visited.validation.code == "VISITED_NODE", "a visited node is rejected", failures)
	assert_true(domain.checkpoint() == visited_before, "visited selection leaves state unchanged", failures)
	assert_true(domain.rng_snapshot() == visited_rng_before, "visited selection does not consume Map RNG", failures)

	for node_id in [SHOP, WORKSHOP, MID, ELITE, BOSS]:
		domain.execute(SelectMapNodeCommand.new("map.invalid.path.%s" % node_id, node_id))
	var terminal_before := domain.checkpoint()
	var terminal_rng_before := domain.rng_snapshot()
	var terminal = domain.execute(SelectMapNodeCommand.new("map.invalid.terminal", BOSS))
	assert_true(not terminal.accepted and terminal.validation.code == "TERMINAL_NODE", "a terminal-node selection is rejected", failures)
	assert_true(domain.checkpoint() == terminal_before, "terminal selection leaves state unchanged", failures)
	assert_true(domain.rng_snapshot() == terminal_rng_before, "terminal selection does not consume Map RNG", failures)

func test_same_seed_and_accepted_map_commands_reproduce_checkpoint(failures: Array[String]) -> void:
	var first := _prepared_domain("map.deterministic", 404)
	var second := _prepared_domain("map.deterministic", 404)
	for node_id in [RIGHT, EVENT_RIGHT, MID, ELITE, BOSS]:
		first.execute(SelectMapNodeCommand.new("map.deterministic.%s" % node_id, node_id))
		second.execute(SelectMapNodeCommand.new("map.deterministic.%s" % node_id, node_id))
	assert_true(first.state.map_state.payload_ids == second.state.map_state.payload_ids, "same seed reproduces map payload IDs", failures)
	assert_true(first.state.map_state.knowledge_state == second.state.map_state.knowledge_state, "same seed reproduces reveal state", failures)
	assert_true(first.state.map_state.ordered_path == second.state.map_state.ordered_path, "same seed reproduces map path", failures)
	assert_true(first.checkpoint().state_hash == second.checkpoint().state_hash, "same seed and commands reproduce the checkpoint hash", failures)

func test_map_command_serializes_stable_node_id(failures: Array[String]) -> void:
	var command := SelectMapNodeCommand.new("map.ids.select", LEFT, "player.1")
	var data := command.to_dictionary()
	assert_true(data["command_type"] == "SelectMapNode", "map command has a stable command type", failures)
	assert_true(data["node_id"] == LEFT, "map command serializes a stable node ID", failures)
	assert_true(not data.has("node_index"), "map command does not serialize a UI index", failures)

func _prepared_domain(run_id: String, seed: int) -> RunDomain:
	var domain := RunDomain.new(run_id, seed, _registry())
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	return domain

func _registry() -> ContentRegistry:
	var registry := ContentRegistry.new()
	registry.register(TileDefinition.new("base.tile.characters.1", "characters", 1))
	registry.register(RelicDefinition.new("base.relic.open_hand"))
	registry.register(TechniqueDefinition.new("base.technique.core.sequence_line", TechniqueDefinition.CORE, 1))
	registry.register(ContentDefinition.new("base.passive.sequence"))
	registry.register(CharacterDefinition.new(
		"base.character.sequence",
		["base.tile.characters.1"],
		"base.relic.open_hand",
		"base.technique.core.sequence_line",
		"base.passive.sequence",
	))
	registry.register(ContractDefinition.new("base.contract.pressure", ContractDefinition.PRESSURE, {"pressure": 1}, {"draw_actions": 1}))
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
