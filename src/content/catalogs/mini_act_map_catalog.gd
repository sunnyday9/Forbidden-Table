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
	return _definition("base.map.act_one", "base.map_node.", "")

static func act_two_definition() -> MapDefinitionScript:
	return _definition("base.map.act_two", "base.map_node.act_two.", "act_two.")

static func definition_for_act(act_index: int) -> MapDefinitionScript:
	match act_index:
		1:
			return definition()
		2:
			return act_two_definition()
	return null

static func _definition(map_id: String, node_prefix: String, edge_prefix: String) -> MapDefinitionScript:
	var intro := node_prefix + "intro"
	var left := node_prefix + "normal.left"
	var right := node_prefix + "normal.right"
	var shop := node_prefix + "shop"
	var workshop := node_prefix + "workshop"
	var event_left := node_prefix + "event.left"
	var event_right := node_prefix + "event.right"
	var mid := node_prefix + "normal.mid"
	var elite := node_prefix + "elite"
	var boss := node_prefix + "boss"
	var nodes := {}
	nodes[intro] = _node(intro, MapNodeDefinitionScript.BATTLE, [left, right], "base.encounter.intro", ["base.encounter.intro.a", "base.encounter.intro.b"], ["edge.%sintro.left" % edge_prefix, "edge.%sintro.right" % edge_prefix])
	nodes[left] = _node(left, MapNodeDefinitionScript.BATTLE, [shop, event_left], "base.encounter.normal.left", ["base.encounter.normal.left.a", "base.encounter.normal.left.b"], ["edge.%sleft.shop" % edge_prefix, "edge.%sleft.event" % edge_prefix])
	nodes[right] = _node(right, MapNodeDefinitionScript.BATTLE, [workshop, event_right], "base.encounter.normal.right", ["base.encounter.normal.right.a", "base.encounter.normal.right.b"], ["edge.%sright.workshop" % edge_prefix, "edge.%sright.event" % edge_prefix])
	nodes[shop] = _node(shop, MapNodeDefinitionScript.SHOP, [workshop], "", ["base.shop.act_one"], ["edge.%sshop.workshop" % edge_prefix])
	nodes[workshop] = _node(workshop, MapNodeDefinitionScript.WORKSHOP, [mid], "", ["base.workshop.act_one"], ["edge.%sworkshop.mid" % edge_prefix])
	nodes[event_left] = _node(event_left, MapNodeDefinitionScript.EVENT, [mid], "base.event.risk_bargain", ["base.event.risk_bargain", "base.event.gold_exchange"], ["edge.%sevent_left.mid" % edge_prefix])
	nodes[event_right] = _node(event_right, MapNodeDefinitionScript.EVENT, [mid], "base.event.map_reveal", ["base.event.map_reveal", "base.event.contract_clause"], ["edge.%sevent_right.mid" % edge_prefix])
	nodes[mid] = _node(mid, MapNodeDefinitionScript.BATTLE, [elite], "base.encounter.normal.mid", ["base.encounter.normal.mid.a", "base.encounter.normal.mid.b"], ["edge.%smid.elite" % edge_prefix])
	nodes[elite] = _node(elite, MapNodeDefinitionScript.ELITE, [boss], "base.encounter.elite", ["base.encounter.elite.a", "base.encounter.elite.b"], ["edge.%selite.boss" % edge_prefix])
	nodes[boss] = _node(boss, MapNodeDefinitionScript.BOSS, [], "base.encounter.boss", ["base.encounter.boss.a", "base.encounter.boss.b"], [])
	return MapDefinitionScript.new(
		map_id,
		[intro, left, right, shop, workshop, event_left, event_right, mid, elite, boss],
		intro,
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
