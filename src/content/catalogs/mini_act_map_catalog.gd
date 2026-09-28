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
	return _definition("base.map.act_one", "base.map_node.", "", false)

static func act_two_definition() -> MapDefinitionScript:
	return _definition("base.map.act_two", "base.map_node.act_two.", "act_two.", true)

static func definition_for_act(act_index: int, content_registry = null) -> MapDefinitionScript:
	var include_scale_encounters := _has_scale_encounters(content_registry)
	match act_index:
		1:
			return _definition("base.map.act_one", "base.map_node.", "", false, include_scale_encounters)
		2:
			return _definition("base.map.act_two", "base.map_node.act_two.", "act_two.", true, include_scale_encounters)
	return null

static func _has_scale_encounters(content_registry) -> bool:
	return content_registry != null and content_registry.resolve("alpha.encounter.act_one.normal.fog_caller") != null

static func _definition(map_id: String, node_prefix: String, edge_prefix: String, act_two: bool, include_scale_encounters: bool = false) -> MapDefinitionScript:
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
	var intro_encounter := "alpha.encounter.act_two.normal.intro" if act_two else "base.encounter.intro"
	var left_encounter := "alpha.encounter.act_two.normal.left" if act_two else "base.encounter.normal.left"
	var right_encounter := "alpha.encounter.act_two.normal.right" if act_two else "base.encounter.normal.right"
	var mid_encounter := "alpha.encounter.act_two.normal.mid" if act_two else "base.encounter.normal.mid"
	var elite_encounter := "alpha.encounter.act_two.elite" if act_two else "base.encounter.elite"
	var boss_encounter := "alpha.encounter.act_two.boss" if act_two else "base.encounter.boss"
	var intro_variants: Array[String] = _encounter_variants(intro_encounter) if act_two else _string_array(["base.encounter.intro.a", "base.encounter.intro.b"])
	var left_variants: Array[String] = _encounter_variants(left_encounter) if act_two else _string_array(["base.encounter.normal.left.a", "base.encounter.normal.left.b"])
	var right_variants: Array[String] = _encounter_variants(right_encounter) if act_two else _string_array(["base.encounter.normal.right.a", "base.encounter.normal.right.b"])
	var mid_variants: Array[String] = _encounter_variants(mid_encounter) if act_two else _string_array(["base.encounter.normal.mid.a", "base.encounter.normal.mid.b"])
	var elite_variants: Array[String] = _encounter_variants(elite_encounter) if act_two else _string_array(["base.encounter.elite.a", "base.encounter.elite.b"])
	var boss_variants: Array[String] = _encounter_variants(boss_encounter) if act_two else _string_array(["base.encounter.boss.a", "base.encounter.boss.b"])
	if act_two or include_scale_encounters:
		boss_variants.append("%s.c" % boss_encounter)
	var left_event := "alpha.event.act_two.tile_surgery" if act_two else "base.event.risk_bargain"
	var left_event_variants: Array[String] = _string_array(["alpha.event.act_two.tile_surgery", "alpha.event.act_two.risk_bargain", "alpha.event.act_two.gold_exchange"]) if act_two else _string_array(["base.event.risk_bargain", "base.event.gold_exchange"])
	var right_event := "alpha.event.act_two.map_reveal" if act_two else "base.event.map_reveal"
	var right_event_variants: Array[String] = _string_array(["alpha.event.act_two.map_reveal", "alpha.event.act_two.contract_clause", "alpha.event.act_two.rule_memory"]) if act_two else _string_array(["base.event.map_reveal", "base.event.contract_clause"])
	if include_scale_encounters:
		if act_two:
			intro_variants.append("alpha.encounter.act_two.normal.contract_harrier")
			left_variants.append("alpha.encounter.act_two.normal.echo_courier")
			right_variants.append("alpha.encounter.act_two.normal.lien_keeper")
			elite_variants.append_array([
				"alpha.encounter.act_two.elite.margin_enforcer",
				"alpha.encounter.act_two.elite.infernal_index",
			])
		else:
			intro_variants.append("alpha.encounter.act_one.normal.fog_caller")
			left_variants.append("alpha.encounter.act_one.normal.margin_taker")
			right_variants.append("alpha.encounter.act_one.normal.signal_keeper")
			elite_variants.append_array([
				"alpha.encounter.act_one.elite.clockwork_auditor",
				"alpha.encounter.act_one.elite.drift_captain",
			])
	nodes[intro] = _node(intro, MapNodeDefinitionScript.BATTLE, [left, right], intro_encounter, intro_variants, ["edge.%sintro.left" % edge_prefix, "edge.%sintro.right" % edge_prefix])
	nodes[left] = _node(left, MapNodeDefinitionScript.BATTLE, [shop, event_left], left_encounter, left_variants, ["edge.%sleft.shop" % edge_prefix, "edge.%sleft.event" % edge_prefix])
	nodes[right] = _node(right, MapNodeDefinitionScript.BATTLE, [workshop, event_right], right_encounter, right_variants, ["edge.%sright.workshop" % edge_prefix, "edge.%sright.event" % edge_prefix])
	nodes[shop] = _node(shop, MapNodeDefinitionScript.SHOP, [workshop], "", ["base.shop.act_one"], ["edge.%sshop.workshop" % edge_prefix])
	nodes[workshop] = _node(workshop, MapNodeDefinitionScript.WORKSHOP, [mid], "", ["base.workshop.act_one"], ["edge.%sworkshop.mid" % edge_prefix])
	nodes[event_left] = _node(event_left, MapNodeDefinitionScript.EVENT, [mid], left_event, left_event_variants, ["edge.%sevent_left.mid" % edge_prefix])
	nodes[event_right] = _node(event_right, MapNodeDefinitionScript.EVENT, [mid], right_event, right_event_variants, ["edge.%sevent_right.mid" % edge_prefix])
	nodes[mid] = _node(mid, MapNodeDefinitionScript.BATTLE, [elite], mid_encounter, mid_variants, ["edge.%smid.elite" % edge_prefix])
	nodes[elite] = _node(elite, MapNodeDefinitionScript.ELITE, [boss], elite_encounter, elite_variants, ["edge.%selite.boss" % edge_prefix])
	nodes[boss] = _node(boss, MapNodeDefinitionScript.BOSS, [], boss_encounter, boss_variants, [])
	return MapDefinitionScript.new(
		map_id,
		[intro, left, right, shop, workshop, event_left, event_right, mid, elite, boss],
		intro,
		nodes,
		"mini-act.v2" if act_two else "mini-act.v1",
	)

static func _encounter_variants(base_id: String) -> Array[String]:
	return [base_id, "%s.a" % base_id, "%s.b" % base_id]

static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result

static func _node(
	node_id: String,
	kind: String,
	next_nodes: Array[String],
	content_id: String,
	payload_ids: Array[String],
	edges: Array[String],
) -> MapNodeDefinitionScript:
	return MapNodeDefinitionScript.new(node_id, kind, next_nodes, content_id, payload_ids, edges)
