class_name MiniActMapCatalog
extends RefCounted

const MapDefinitionScript = preload("res://src/content/definitions/map_definition.gd")
const MapNodeDefinitionScript = preload("res://src/content/definitions/map_node_definition.gd")

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

static func definition() -> MapDefinitionScript:
	var nodes := {}
	nodes[INTRO] = _node(INTRO, MapNodeDefinitionScript.BATTLE, [LEFT, RIGHT], "base.encounter.intro", ["base.encounter.intro.a", "base.encounter.intro.b"], ["edge.intro.left", "edge.intro.right"])
	nodes[LEFT] = _node(LEFT, MapNodeDefinitionScript.BATTLE, [SHOP, EVENT_LEFT], "base.encounter.normal.left", ["base.encounter.normal.left.a", "base.encounter.normal.left.b"], ["edge.left.shop", "edge.left.event"])
	nodes[RIGHT] = _node(RIGHT, MapNodeDefinitionScript.BATTLE, [WORKSHOP, EVENT_RIGHT], "base.encounter.normal.right", ["base.encounter.normal.right.a", "base.encounter.normal.right.b"], ["edge.right.workshop", "edge.right.event"])
	nodes[SHOP] = _node(SHOP, MapNodeDefinitionScript.SHOP, [WORKSHOP], "", ["base.shop.act_one"], ["edge.shop.workshop"])
	nodes[WORKSHOP] = _node(WORKSHOP, MapNodeDefinitionScript.WORKSHOP, [MID], "", ["base.workshop.act_one"], ["edge.workshop.mid"])
	nodes[EVENT_LEFT] = _node(EVENT_LEFT, MapNodeDefinitionScript.EVENT, [MID], "base.event.risk_bargain", ["base.event.risk_bargain", "base.event.gold_exchange"], ["edge.event_left.mid"])
	nodes[EVENT_RIGHT] = _node(EVENT_RIGHT, MapNodeDefinitionScript.EVENT, [MID], "base.event.map_reveal", ["base.event.map_reveal", "base.event.contract_clause"], ["edge.event_right.mid"])
	nodes[MID] = _node(MID, MapNodeDefinitionScript.BATTLE, [ELITE], "base.encounter.normal.mid", ["base.encounter.normal.mid.a", "base.encounter.normal.mid.b"], ["edge.mid.elite"])
	nodes[ELITE] = _node(ELITE, MapNodeDefinitionScript.ELITE, [BOSS], "base.encounter.elite", ["base.encounter.elite.a", "base.encounter.elite.b"], ["edge.elite.boss"])
	nodes[BOSS] = _node(BOSS, MapNodeDefinitionScript.BOSS, [], "base.encounter.boss", ["base.encounter.boss.a", "base.encounter.boss.b"], [])
	return MapDefinitionScript.new(
		"base.map.act_one",
		[INTRO, LEFT, RIGHT, SHOP, WORKSHOP, EVENT_LEFT, EVENT_RIGHT, MID, ELITE, BOSS],
		INTRO,
		nodes,
		"mini-act.v1",
	)

static func _node(
	node_id: String,
	kind: String,
	next_nodes: Array[String],
	content_id: String,
	payload_ids: Array[String],
	edges: Array[String],
) -> MapNodeDefinitionScript:
	return MapNodeDefinitionScript.new(node_id, kind, next_nodes, content_id, payload_ids, edges)
