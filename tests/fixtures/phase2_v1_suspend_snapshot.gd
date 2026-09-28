extends RefCounted

const SNAPSHOT_TEMPLATE: Dictionary = {
	"schema_version": 1,
	"game_version": "game.phase2.v1",
	"content_version": "content.slice.v1",
	"save_kind": "SUSPEND",
	"run_id": "phase2.v1.fixture",
	"run_seed": 2039,
	"authoritative_state": {
		"run_id": "phase2.v1.fixture",
		"seed": 2039,
		"content_version": "content.slice.v1",
		"phase": "MAP_CHOICE",
		"character_id": "base.character.sequence",
		"contract_id": "base.contract.pressure",
		"map_state": {
			"map_definition_id": "base.map.act_one",
			"map_version": "mini-act.v1",
			"node_ids": [
				"base.map_node.intro",
				"base.map_node.normal.left",
				"base.map_node.normal.right",
				"base.map_node.shop",
				"base.map_node.workshop",
				"base.map_node.event.left",
				"base.map_node.event.right",
				"base.map_node.normal.mid",
				"base.map_node.elite",
				"base.map_node.boss"
			],
			"edge_ids": [
				"edge.intro.left",
				"edge.intro.right",
				"edge.left.shop",
				"edge.left.event",
				"edge.right.workshop",
				"edge.right.event",
				"edge.shop.workshop",
				"edge.workshop.mid",
				"edge.event_left.mid",
				"edge.event_right.mid",
				"edge.mid.elite",
				"edge.elite.boss"
			],
			"node_kinds": {
				"base.map_node.intro": "BATTLE",
				"base.map_node.normal.left": "BATTLE",
				"base.map_node.normal.right": "BATTLE",
				"base.map_node.shop": "SHOP",
				"base.map_node.workshop": "WORKSHOP",
				"base.map_node.event.left": "EVENT",
				"base.map_node.event.right": "EVENT",
				"base.map_node.normal.mid": "BATTLE",
				"base.map_node.elite": "ELITE",
				"base.map_node.boss": "BOSS"
			},
			"payload_ids": {
				"base.map_node.intro": "base.encounter.intro.b",
				"base.map_node.normal.left": "base.encounter.normal.left.b",
				"base.map_node.normal.right": "base.encounter.normal.right.a",
				"base.map_node.shop": "base.shop.act_one",
				"base.map_node.workshop": "base.workshop.act_one",
				"base.map_node.event.left": "base.event.gold_exchange",
				"base.map_node.event.right": "base.event.map_reveal",
				"base.map_node.normal.mid": "base.encounter.normal.mid.b",
				"base.map_node.elite": "base.encounter.elite.a",
				"base.map_node.boss": "base.encounter.boss.a"
			},
			"knowledge_state": {
				"base.map_node.intro": "EXACT",
				"base.map_node.normal.left": "EXACT",
				"base.map_node.normal.right": "EXACT",
				"base.map_node.shop": "PARTIAL",
				"base.map_node.workshop": "PARTIAL",
				"base.map_node.event.left": "PARTIAL",
				"base.map_node.event.right": "PARTIAL",
				"base.map_node.normal.mid": "PARTIAL",
				"base.map_node.elite": "PARTIAL",
				"base.map_node.boss": "PARTIAL"
			},
			"current_node_id": "base.map_node.intro",
			"visited_node_ids": ["base.map_node.intro"],
			"ordered_path": ["base.map_node.intro"],
			"path_edge_ids": [],
			"map_rng_state": {
				"version": 1,
				"stream_id": "map",
				"state": 3168346793640593899
			}
		},
		"tile_pool": {"tile_instances": []},
		"shop_state": {
			"active": false,
			"completed": false,
			"node_id": "",
			"entry_id": "",
			"offers": [],
			"base_refresh_allowance": 0,
			"refreshes_remaining": 0,
			"refresh_count": 0,
			"entry_sequence": 0,
			"shop_rng_state": {},
			"completed_node_ids": []
		},
		"workshop_state": {
			"active": false,
			"completed": false,
			"node_id": "",
			"entry_id": "",
			"available_service_ids": [],
			"used_service_ids": [],
			"entry_sequence": 0,
			"completed_node_ids": []
		},
		"event_state": {
			"active": false,
			"completed": false,
			"node_id": "",
			"entry_id": "",
			"event_id": "",
			"choices": [],
			"selected_choice_id": "",
			"resolved_alternative_id": "",
			"entry_sequence": 0,
			"event_rng_state": {},
			"completed_node_ids": []
		},
		"active_effects": [],
		"gold": 0,
		"refinement_tokens": 0,
		"reward_draft": {},
		"reward_draft_sequence": 0,
		"tile_instance_sequence": 0,
		"build_ownership": {
			"owned_relic_ids": [],
			"run_technique_ids": [],
			"owned_special_offer_ids": [],
			"character_core_technique_id": "",
			"persistent_tile_modifier_state": {},
			"acquired_rule_breaker_ids": [],
			"yaku_build_milestones": {}
		},
		"tutorial_state": {"active_step_id": "", "completed_step_ids": []},
		"terminal_summary": {"outcome": "ONGOING", "reason": "", "summary_data": {}},
		"current_battle_snapshot": {}
	},
	"rng_state": {
		"version": 1,
		"streams": {
			"combat": {"version": 1, "stream_id": "combat", "state": -4549528066960716510},
			"draw_wall": {"version": 1, "stream_id": "draw_wall", "state": 5479646830810048046},
			"enemy": {"version": 1, "stream_id": "enemy", "state": 9155768422866346922},
			"map": {"version": 1, "stream_id": "map", "state": 3168346793640593899},
			"reward": {"version": 1, "stream_id": "reward", "state": -6968476033431657222},
			"shop": {"version": 1, "stream_id": "shop", "state": 7166804155278328776},
			"event": {"version": 1, "stream_id": "event", "state": -535723087313626793},
			"cosmetic": {"version": 1, "stream_id": "cosmetic", "state": 3734278302690738758}
		}
	},
	"checkpoint_metadata": {
		"stable": true,
		"stable_boundary": "MAP_NODE",
		"state_hash": "5fbf83f09376c37ee784b9da3c7b8372b2f3151edca847c21cea1d1e8f83ec00"
	}
}

static func suspend_snapshot() -> Dictionary:
	var snapshot: Dictionary = SNAPSHOT_TEMPLATE.duplicate(true)
	snapshot["run_state"] = snapshot["authoritative_state"].duplicate(true)
	return snapshot
