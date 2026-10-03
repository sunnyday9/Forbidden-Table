extends RefCounted

const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const ChooseEventOptionCommand = preload("res://src/domain/commands/choose_event_option_command.gd")
const ChooseRewardCommand = preload("res://src/domain/commands/choose_reward_command.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const EndTurnCommand = preload("res://src/domain/commands/end_turn_command.gd")
const EnterEventCommand = preload("res://src/domain/commands/enter_event_command.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const ScriptedContentRegistry = preload("res://tests/fixtures/stage4_onboarding_content_registry.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const UseTechniqueCommand = preload("res://src/domain/commands/use_technique_command.gd")

const ACT_ONE_RULE_MEMORY_EVENT := "alpha.event.act_one.rule_memory"
const ACT_ONE_EVENT_NODE := "base.map_node.event.right"
const ACT_TWO_EVENT_NODE := "base.map_node.act_two.event.right"
const ACT_ONE_ROUTE := [
	"base.map_node.intro",
	"base.map_node.normal.right",
	"base.map_node.event.right",
	"base.map_node.normal.mid",
	"base.map_node.elite",
	"base.map_node.boss",
]
const ACT_TWO_ROUTE := [
	"base.map_node.act_two.intro",
	"base.map_node.act_two.normal.right",
	"base.map_node.act_two.event.right",
]
static func two_act_rule_memory_domain(
	run_id: String,
	seed: int,
	act_two_event_id: String,
	failures: Array[String],
) -> Dictionary:
	var domain := _new_domain(run_id, seed)
	if not _execute(domain, ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"), "Character selection", failures):
		return {"accepted": false}
	if not _execute(domain, ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"), "Contract selection", failures):
		return {"accepted": false}
	if str(domain.state.map_state.payload_ids.get(ACT_ONE_EVENT_NODE, "")) != ACT_ONE_RULE_MEMORY_EVENT:
		return _failed_route("seed %d does not author Rule Memory at the Act 1 right Event node" % seed, failures)

	if not _select_and_win(domain, ACT_ONE_ROUTE[0], "%s.act1.intro" % run_id, failures):
		return {"accepted": false}
	if not _choose_reward(domain, "%s.act1.intro.reward" % run_id, failures):
		return {"accepted": false}
	if not _select_and_win(domain, ACT_ONE_ROUTE[1], "%s.act1.branch" % run_id, failures):
		return {"accepted": false}
	if not _choose_reward(domain, "%s.act1.branch.reward" % run_id, failures):
		return {"accepted": false}
	var act_one_event_node = _execute(domain, SelectMapNodeCommand.new("%s.act1.event-node" % run_id, ACT_ONE_EVENT_NODE), "Act 1 Rule Memory Map Node selection", failures)
	if act_one_event_node == null or not act_one_event_node.accepted:
		return {"accepted": false}
	var act_one_entry = _execute(domain, EnterEventCommand.new("%s.act1.enter" % run_id), "Act 1 Rule Memory Event entry", failures)
	if act_one_entry == null or not act_one_entry.accepted:
		return {"accepted": false}
	if domain.state.event_state.event_id != ACT_ONE_RULE_MEMORY_EVENT:
		return _failed_route("the authored Act 1 Event node did not enter Rule Memory", failures)
	var remember = _execute(domain, ChooseEventOptionCommand.new(
		"%s.act1.remember" % run_id,
		"remember_rule",
		ACT_ONE_RULE_MEMORY_EVENT,
		domain.state.event_state.entry_id,
	), "Act 1 remember_rule choice", failures)
	if remember == null or not remember.accepted:
		return {"accepted": false}
	if domain.state.active_modifier("event.act_two.rule_memory") == null:
		return _failed_route("Act 1 remember_rule did not carry the unique Run modifier", failures)

	if not _select_and_win(domain, ACT_ONE_ROUTE[3], "%s.act1.mid" % run_id, failures):
		return {"accepted": false}
	if not _choose_reward(domain, "%s.act1.mid.reward" % run_id, failures):
		return {"accepted": false}
	if not _select_and_win(domain, ACT_ONE_ROUTE[4], "%s.act1.elite" % run_id, failures):
		return {"accepted": false}
	if not _choose_reward(domain, "%s.act1.elite.reward" % run_id, failures):
		return {"accepted": false}
	if not _select_and_win(domain, ACT_ONE_ROUTE[5], "%s.act1.boss" % run_id, failures):
		return {"accepted": false}
	if domain.state.phase != RunPhase.BOSS_REWARD or domain.state.act_index != 1 or domain.state.reward_draft == null:
		return _failed_route("the authored Act 1 Boss encounter did not open its Boss reward", failures)

	var act_one_path: Array = domain.state.map_state.ordered_path.duplicate()
	var act_one_boss_draft_id := str(domain.state.reward_draft.draft_id)
	var act_one_boss_option_id := str(domain.state.reward_draft.options[0].option_id) if not domain.state.reward_draft.options.is_empty() else ""
	var act_one_boss_reward_command := ChooseRewardCommand.new("%s.act1.boss.reward" % run_id, act_one_boss_option_id, act_one_boss_draft_id)
	var act_one_boss_reward = _execute(domain, act_one_boss_reward_command, "Act 1 Boss ChooseRewardCommand", failures)
	if act_one_boss_reward == null or not act_one_boss_reward.accepted:
		return {"accepted": false}
	var act_transition_emitted: bool = act_one_boss_reward.events.any(func(event): return event.event_type == DomainEvent.ACT_TRANSITIONED)
	if domain.state.act_index != 2 or domain.state.phase != RunPhase.MAP_CHOICE or not act_transition_emitted:
		return _failed_route("the public Act 1 Boss reward did not transition the continuous Run into Act 2", failures)
	if str(domain.state.map_state.payload_ids.get(ACT_TWO_EVENT_NODE, "")) != act_two_event_id:
		return _failed_route("seed %d authors %s at the Act 2 right Event node, not %s" % [seed, str(domain.state.map_state.payload_ids.get(ACT_TWO_EVENT_NODE, "")), act_two_event_id], failures)

	if not _select_and_win(domain, ACT_TWO_ROUTE[0], "%s.act2.intro" % run_id, failures):
		return {"accepted": false}
	if not _choose_reward(domain, "%s.act2.intro.reward" % run_id, failures):
		return {"accepted": false}
	if not _select_and_win(domain, ACT_TWO_ROUTE[1], "%s.act2.branch" % run_id, failures):
		return {"accepted": false}
	if not _choose_reward(domain, "%s.act2.branch.reward" % run_id, failures):
		return {"accepted": false}
	var act_two_event_node = _execute(domain, SelectMapNodeCommand.new("%s.act2.event-node" % run_id, ACT_TWO_EVENT_NODE), "Act 2 Rule Memory Map Node selection", failures)
	if act_two_event_node == null or not act_two_event_node.accepted:
		return {"accepted": false}
	var act_two_entry = _execute(domain, EnterEventCommand.new("%s.act2.enter" % run_id), "Act 2 Rule Memory Event entry", failures)
	if act_two_entry == null or not act_two_entry.accepted:
		return {"accepted": false}
	if domain.state.event_state.event_id != act_two_event_id:
		return _failed_route("the authored Act 2 Event node did not enter the requested Rule Memory variant", failures)

	var act_two_path: Array = domain.state.map_state.ordered_path.duplicate()
	return {
		"accepted": true,
		"domain": domain,
		"seed": seed,
		"act_one_path": act_one_path,
		"act_one_boss_reward_command_type": act_one_boss_reward_command.command_type(),
		"act_one_boss_transition_emitted": act_transition_emitted,
		"act_two_path": act_two_path,
	}

static func _new_domain(run_id: String, seed: int) -> RunDomain:
	var registry = ScriptedContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	AlphaScaleCatalog.register_all(registry)
	return RunDomain.new_alpha_run(run_id, seed, registry)

static func _select_and_win(domain: RunDomain, node_id: String, command_prefix: String, failures: Array[String]) -> bool:
	var selected = _execute(domain, SelectMapNodeCommand.new(command_prefix, node_id), "%s Map Node selection" % node_id, failures)
	if selected == null or not selected.accepted:
		return false
	if not _win_battle(domain, command_prefix, failures):
		return false
	return true

static func _win_battle(domain: RunDomain, command_prefix: String, failures: Array[String]) -> bool:
	var action_count := 0
	while domain.state.phase == RunPhase.BATTLE and action_count < 16:
		var technique_id := str(domain.state.build_ownership.character_core_technique_id)
		var technique = _execute(domain, UseTechniqueCommand.new("%s.core.%d" % [command_prefix, action_count], technique_id), "controlled Core Technique", failures)
		if technique == null or not technique.accepted:
			return false
		action_count += 1
		if domain.state.phase == RunPhase.BATTLE:
			var end_turn = _execute(domain, EndTurnCommand.new("%s.end-turn.%d" % [command_prefix, action_count]), "controlled Battle End Turn", failures)
			if end_turn == null or not end_turn.accepted:
				return false
			action_count += 1
	var victory: bool = domain.state.phase in [RunPhase.REWARD_CHOICE, RunPhase.ELITE_REWARD, RunPhase.BOSS_REWARD]
	if not victory:
		_failed_route("controlled battle did not reach its authored reward destination", failures)
	return victory

static func _choose_reward(domain: RunDomain, command_id: String, failures: Array[String]) -> bool:
	if domain.state.reward_draft == null or domain.state.reward_draft.options.is_empty():
		_failed_route("an authored encounter did not expose a selectable reward draft", failures)
		return false
	var draft_id := str(domain.state.reward_draft.draft_id)
	var option_id := str(domain.state.reward_draft.options[0].option_id)
	var choice = _execute(domain, ChooseRewardCommand.new(command_id, option_id, draft_id), "encounter ChooseRewardCommand", failures)
	return choice != null and choice.accepted

static func _execute(domain: RunDomain, command, description: String, failures: Array[String]):
	var result = domain.execute(command)
	if result == null or not result.accepted:
		var code := str(result.validation.code) if result != null and result.validation != null else "NO_RESULT"
		failures.append("ASSERTION FAILED: %s was rejected (%s)" % [description, code])
		return null
	return result

static func _failed_route(message: String, failures: Array[String]) -> Dictionary:
	failures.append("ASSERTION FAILED: public Act route fixture %s" % message)
	return {"accepted": false, "reason": message}
