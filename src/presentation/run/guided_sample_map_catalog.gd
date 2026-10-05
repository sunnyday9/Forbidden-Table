class_name GuidedSampleMapCatalog
extends RefCounted

const MapDefinitionScript = preload("res://src/content/definitions/map_definition.gd")
const MapNodeDefinitionScript = preload("res://src/content/definitions/map_node_definition.gd")

const INTRO_ENCOUNTER := "prototype.encounter.guided_sample"
const PRACTICE_ENCOUNTER := "prototype.encounter.guided_sample_actions"
const PRACTICE_ENEMY := "prototype.enemy.guided_sample"
const ACTION_PRACTICE_ENEMY := "prototype.enemy.guided_sample_actions"
const INTRO_NODE := "base.map_node.guided_sample.intro"
const PRACTICE_NODE := "base.map_node.guided_sample.practice_battle"
const EVENT_REVEAL_NODE := "base.map_node.guided_sample.map_reveal"
const EVENT_BARGAIN_NODE := "base.map_node.guided_sample.risk_bargain"
const SHOP_NODE := "base.map_node.guided_sample.shop"
const WORKSHOP_NODE := "base.map_node.guided_sample.workshop"
const BOSS_NODE := "base.map_node.guided_sample.boss"

static func definition() -> MapDefinitionScript:
	var intro_edges: Array[String] = ["guided-sample.intro.practice-battle"]
	var practice_edges: Array[String] = ["guided-sample.practice.map-reveal", "guided-sample.practice.risk-bargain"]
	var reveal_edges: Array[String] = ["guided-sample.map-reveal.shop"]
	var bargain_edges: Array[String] = ["guided-sample.risk-bargain.shop"]
	var shop_edges: Array[String] = ["guided-sample.shop.workshop"]
	var workshop_edges: Array[String] = ["guided-sample.workshop.boss"]
	var nodes: Dictionary = {
		INTRO_NODE: MapNodeDefinitionScript.new(
			INTRO_NODE,
			MapNodeDefinitionScript.BATTLE,
			[PRACTICE_NODE],
			INTRO_ENCOUNTER,
			[INTRO_ENCOUNTER],
			intro_edges,
		),
		PRACTICE_NODE: MapNodeDefinitionScript.new(
			PRACTICE_NODE,
			MapNodeDefinitionScript.BATTLE,
			[EVENT_REVEAL_NODE, EVENT_BARGAIN_NODE],
			PRACTICE_ENCOUNTER,
			[PRACTICE_ENCOUNTER],
			practice_edges,
		),
		EVENT_REVEAL_NODE: MapNodeDefinitionScript.new(
			EVENT_REVEAL_NODE,
			MapNodeDefinitionScript.EVENT,
			[SHOP_NODE],
			"base.event.map_reveal",
			["base.event.map_reveal"],
			reveal_edges,
		),
		EVENT_BARGAIN_NODE: MapNodeDefinitionScript.new(
			EVENT_BARGAIN_NODE,
			MapNodeDefinitionScript.EVENT,
			[SHOP_NODE],
			"base.event.risk_bargain",
			["base.event.risk_bargain"],
			bargain_edges,
		),
		SHOP_NODE: MapNodeDefinitionScript.new(
			SHOP_NODE,
			MapNodeDefinitionScript.SHOP,
			[WORKSHOP_NODE],
			"base.shop.act_one",
			[],
			shop_edges,
		),
		WORKSHOP_NODE: MapNodeDefinitionScript.new(
			WORKSHOP_NODE,
			MapNodeDefinitionScript.WORKSHOP,
			[BOSS_NODE],
			"base.workshop.act_one",
			[],
			workshop_edges,
		),
		BOSS_NODE: MapNodeDefinitionScript.new(
			BOSS_NODE,
			MapNodeDefinitionScript.BOSS,
			[],
			"base.encounter.boss",
			["base.encounter.boss.a"],
			[],
		),
	}
	var node_ids: Array[String] = [INTRO_NODE, PRACTICE_NODE, EVENT_REVEAL_NODE, EVENT_BARGAIN_NODE, SHOP_NODE, WORKSHOP_NODE, BOSS_NODE]
	return MapDefinitionScript.new("base.map.guided_sample", node_ids, INTRO_NODE, nodes, "guided-sample.v1")
