class_name CharacterPassiveTest
extends RefCounted

const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const CharacterPassiveDefinitionScript = preload("res://src/content/definitions/character_passive_definition.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const SelectMapNodeCommandScript = preload("res://src/domain/commands/select_map_node_command.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const SettleCompleteHandCommandScript = preload("res://src/domain/commands/settle_complete_hand_command.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_harbor_read_resolves_in_encounters(failures)
	return failures

func test_harbor_read_resolves_in_encounters(failures: Array[String]) -> void:
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	AlphaActTwoCatalogScript.register_all(registry)
	AlphaScaleCatalogScript.register_all(registry)
	var passive = registry.resolve(AlphaScaleCatalogScript.PASSIVE_ID)
	assert_true(passive is CharacterPassiveDefinitionScript and passive.trigger_id == CharacterPassiveDefinitionScript.AFTER_COMPLETE_HAND, "Harbor Read is registered as a typed, triggered passive with an authored effect", failures)
	var domain = RunDomainScript.new_alpha_run("passive.harbor-reader", 5601, registry, "", null, null, MetaProgressStateScript.all_unlocked_test_profile())
	var character_result = domain.execute(ChooseCharacterCommandScript.new("passive.character", AlphaScaleCatalogScript.CHARACTER_ID))
	var contract_result = domain.execute(ChooseContractCommandScript.new("passive.contract", Phase2CatalogScript.CONTRACT_IDS[0]))
	assert_true(character_result.accepted and contract_result.accepted, "the unlocked Harbor Reader can begin a Run", failures)
	var start_node = domain.map_definition.node_definition(domain.state.map_state.current_node_id)
	var battle_node_id := ""
	for next_node_id in start_node.next_node_ids:
		var next_node = domain.map_definition.node_definition(next_node_id)
		if next_node != null and next_node.node_kind == "BATTLE":
			battle_node_id = next_node_id
			break
	assert_true(not battle_node_id.is_empty(), "the Alpha map exposes a first normal encounter", failures)
	if battle_node_id.is_empty():
		return
	var battle_start = domain.execute(SelectMapNodeCommandScript.new("passive.first-battle", battle_node_id))
	assert_true(battle_start.accepted and domain.state.phase == RunPhaseScript.BATTLE, "Harbor Reader enters a real encounter", failures)
	if not battle_start.accepted:
		return
	domain.current_battle.combat_state.enemy_hp = 999
	var draws_accepted := true
	for draw_index in range(14):
		var draw_result = domain.execute(DrawCommandScript.new("passive.draw.%d" % draw_index))
		if not draw_result.accepted:
			draws_accepted = false
			break
	assert_true(draws_accepted and domain.current_battle.zones.size(TileZoneScript.HAND) == 14, "the encounter draws the 14-tile Character pool through authoritative battle commands", failures)
	var interpretations: Array = domain.current_battle.complete_hand_interpretations()
	assert_true(not interpretations.is_empty(), "the Character starting pool supports its complete-hand gameplay path", failures)
	if interpretations.is_empty():
		return
	var tp_before: int = domain.current_battle.combat_state.tp
	var settled = domain.execute(SettleCompleteHandCommandScript.new("passive.complete-hand", interpretations[0].interpretation_id))
	assert_true(settled.accepted, "a complete hand can be settled during the encounter", failures)
	assert_true(domain.current_battle.combat_state.tp == tp_before + 1, "Harbor Read grants one TP when its first Complete Hand resolves", failures)
	assert_true(_has_event(settled.events, DomainEventScript.CHARACTER_PASSIVE_TRIGGERED), "the gameplay result records the passive trigger", failures)
	assert_true(domain.state.complete_hand_count == 1 and domain.state.maximum_mahjong_score > 0, "the Run tracks its Complete Hand count and maximum score from the same encounter result", failures)
	assert_true(not domain.state.pattern_counts.is_empty(), "the Run records the Complete Hand's common Pattern groups", failures)
	assert_true(domain.current_battle.combat_state.triggered_signature_passive_ids.has(AlphaScaleCatalogScript.PASSIVE_ID), "the battle checkpoint records the once-per-encounter passive use", failures)
	var tp_after: int = domain.current_battle.combat_state.tp
	var repeated = domain.current_battle.resolve_character_passive(passive)
	assert_true(not repeated.accepted and repeated.status == "CHARACTER_PASSIVE_ALREADY_TRIGGERED" and domain.current_battle.combat_state.tp == tp_after, "Harbor Read cannot grant repeated TP in one encounter", failures)

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event != null and event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
