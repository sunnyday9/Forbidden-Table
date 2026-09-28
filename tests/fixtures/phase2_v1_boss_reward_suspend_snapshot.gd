class_name Phase2V1BossRewardSuspendSnapshotFixture
extends RefCounted

# Captured with Godot 4.7.2 from pre-change commit 622ff72a3673309e6753c478e8bd1577b258a1af
# via the v1 RunDomain Boss victory -> SaveCoordinator stable REWARD path.
const AUTHORITATIVE_STATE: Dictionary = {
		"active_effects": [],
		"build_ownership": {
			"acquired_rule_breaker_ids": [],
			"character_core_technique_id": "",
			"owned_relic_ids": [],
			"owned_special_offer_ids": [],
			"persistent_tile_modifier_state": {},
			"run_technique_ids": [],
			"yaku_build_milestones": {}
		},
		"character_id": "base.character.sequence",
		"content_version": "content.slice.v1",
		"contract_id": "base.contract.pressure",
		"current_battle_snapshot": {},
		"event_state": {
			"active": false,
			"choices": [],
			"completed": false,
			"completed_node_ids": [],
			"entry_id": "",
			"entry_sequence": 0,
			"event_id": "",
			"event_rng_state": {},
			"node_id": "",
			"resolved_alternative_id": "",
			"selected_choice_id": ""
		},
		"gold": 10,
		"map_state": {
			"current_node_id": "base.map_node.boss",
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
			"knowledge_state": {
				"base.map_node.boss": "EXACT",
				"base.map_node.elite": "PARTIAL",
				"base.map_node.event.left": "PARTIAL",
				"base.map_node.event.right": "PARTIAL",
				"base.map_node.intro": "PARTIAL",
				"base.map_node.normal.left": "PARTIAL",
				"base.map_node.normal.mid": "PARTIAL",
				"base.map_node.normal.right": "PARTIAL",
				"base.map_node.shop": "PARTIAL",
				"base.map_node.workshop": "PARTIAL"
			},
			"map_definition_id": "base.map.act_one",
			"map_rng_state": {
				"state": 7292171864419497038,
				"stream_id": "map",
				"version": 1
			},
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
			"node_kinds": {
				"base.map_node.boss": "BOSS",
				"base.map_node.elite": "ELITE",
				"base.map_node.event.left": "EVENT",
				"base.map_node.event.right": "EVENT",
				"base.map_node.intro": "BATTLE",
				"base.map_node.normal.left": "BATTLE",
				"base.map_node.normal.mid": "BATTLE",
				"base.map_node.normal.right": "BATTLE",
				"base.map_node.shop": "SHOP",
				"base.map_node.workshop": "WORKSHOP"
			},
			"ordered_path": [
				"base.map_node.intro",
				"base.map_node.normal.left",
				"base.map_node.shop",
				"base.map_node.workshop",
				"base.map_node.normal.mid",
				"base.map_node.elite",
				"base.map_node.boss"
			],
			"path_edge_ids": [
				"edge.intro.left",
				"edge.left.shop",
				"edge.shop.workshop",
				"edge.workshop.mid",
				"edge.mid.elite",
				"edge.elite.boss"
			],
			"payload_ids": {
				"base.map_node.boss": "base.encounter.boss.a",
				"base.map_node.elite": "base.encounter.elite.b",
				"base.map_node.event.left": "base.event.gold_exchange",
				"base.map_node.event.right": "base.event.contract_clause",
				"base.map_node.intro": "base.encounter.intro.a",
				"base.map_node.normal.left": "base.encounter.normal.left.a",
				"base.map_node.normal.mid": "base.encounter.normal.mid.a",
				"base.map_node.normal.right": "base.encounter.normal.right.a",
				"base.map_node.shop": "base.shop.act_one",
				"base.map_node.workshop": "base.workshop.act_one"
			},
			"visited_node_ids": [
				"base.map_node.intro",
				"base.map_node.normal.left",
				"base.map_node.shop",
				"base.map_node.workshop",
				"base.map_node.normal.mid",
				"base.map_node.elite",
				"base.map_node.boss"
			]
		},
		"phase": "BOSS_REWARD",
		"refinement_tokens": 0,
		"reward_draft": {},
		"reward_draft_sequence": 2,
		"run_id": "phase2.v1.pending-boss",
		"seed": 4905,
		"shop_state": {
			"active": false,
			"base_refresh_allowance": 0,
			"completed": false,
			"completed_node_ids": [],
			"entry_id": "",
			"entry_sequence": 0,
			"node_id": "",
			"offers": [],
			"refresh_count": 0,
			"refreshes_remaining": 0,
			"shop_rng_state": {}
		},
		"terminal_summary": {
			"outcome": "ONGOING",
			"reason": "",
			"summary_data": {}
		},
		"tile_instance_sequence": 0,
		"tile_pool": {
			"tile_instances": []
		},
		"tutorial_state": {
			"active_step_id": "",
			"completed_step_ids": []
		},
		"workshop_state": {
			"active": false,
			"available_service_ids": [],
			"completed": false,
			"completed_node_ids": [],
			"entry_id": "",
			"entry_sequence": 0,
			"node_id": "",
			"used_service_ids": []
		}
	}

const RNG_STATE: Dictionary = {
		"streams": {
			"combat": {
				"state": -3533372081142439688,
				"stream_id": "combat",
				"version": 1
			},
			"cosmetic": {
				"state": 4750434288509015580,
				"stream_id": "cosmetic",
				"version": 1
			},
			"draw_wall": {
				"state": 6495802816628324868,
				"stream_id": "draw_wall",
				"version": 1
			},
			"enemy": {
				"state": -8274819665024927872,
				"stream_id": "enemy",
				"version": 1
			},
			"event": {
				"state": 480432898504650029,
				"stream_id": "event",
				"version": 1
			},
			"map": {
				"state": 7292171864419497038,
				"stream_id": "map",
				"version": 1
			},
			"reward": {
				"state": -9200687802000412860,
				"stream_id": "reward",
				"version": 1
			},
			"shop": {
				"state": 8182960141096605598,
				"stream_id": "shop",
				"version": 1
			}
		},
		"version": 1
	}
const CHECKPOINT_METADATA: Dictionary = {
		"checkpoint_sequence": 2,
		"stable": true,
		"stable_boundary": "REWARD",
		"state_hash": "5ff950c328234813cb620e66c1798451c110f098d359d63b09d7a0518adc88b0"
	}

static func suspend_snapshot() -> Dictionary:
	var state := AUTHORITATIVE_STATE.duplicate(true)
	return {
		"schema_version": 1,
		"game_version": "game.phase2.v1",
		"content_version": "content.slice.v1",
		"save_kind": "SUSPEND",
		"run_id": "phase2.v1.pending-boss",
		"run_seed": 4905,
		"authoritative_state": state,
		"run_state": state.duplicate(true),
		"rng_state": RNG_STATE.duplicate(true),
		"checkpoint_metadata": CHECKPOINT_METADATA.duplicate(true),
	}
