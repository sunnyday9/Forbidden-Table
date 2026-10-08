extends RefCounted

const RunScene = preload("res://scenes/run/run_scene.gd")
const GuidedSample = preload("res://src/presentation/run/guided_sample_session.gd")
const Tutorial = preload("res://src/presentation/run/tutorial_progress.gd")
const Event = preload("res://src/domain/events/domain_event.gd")
const Localization = preload("res://src/presentation/localization/localization.gd")
const ActionText = preload("res://src/presentation/ui/player_action_text.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const Controller = preload("res://src/presentation/run/run_presentation_controller.gd")
const ReplayVerifier = preload("res://src/infrastructure/replay/replay_verifier.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const JourneyView = preload("res://src/presentation/ui/run_journey_view.gd")
const ShopOffer = preload("res://src/domain/run/shop_offer.gd")

var completed := false

func run() -> Array[String]:
	var failures: Array[String] = []
	var tutorial = Tutorial.new()
	tutorial.observe([Event.new(Event.TILE_DRAWN), Event.new(Event.TP_CHANGED)])
	_check(tutorial.current_step_id == Tutorial.DRAW_PATTERN_PARTIAL, "draws and TP changes cannot skip the Pattern lesson", failures)
	tutorial.observe([Event.new(Event.PATTERN_SETTLED)])
	_check(tutorial.current_step_id == Tutorial.TP_CORE_TECHNIQUE, "settling a Pattern completes the Pattern lesson", failures)
	tutorial.observe([Event.new(Event.TECHNIQUE_USED, {"tp_cost": 0})])
	_check(tutorial.current_step_id == Tutorial.RESERVE_INTEGRITY, "a real zero-cost skill completes the skill lesson", failures)
	var builder = RunScene.new()
	var registry: Dictionary = builder._validated_content_registry()
	builder.free()
	var session = GuidedSample.new()
	_check(bool(session.start(registry.registry).get("accepted", false)), "sample starts", failures)
	var controller = session.controller
	_choose(controller, "CHARACTER")
	_choose(controller, "CONTRACT")
	_choose(controller, "MAP_NODE")
	_choose(controller, "DRAW")
	var battle = controller.domain.current_battle
	var partial := _action(controller, "PARTIAL_SETTLEMENT")
	var before: Dictionary = battle.checkpoint()
	var rng_before: Dictionary = battle.rng_snapshot()
	var preview: Dictionary = battle.preview_settlement(str(partial.get("target_id", "")))
	_check(not preview.is_empty() and int(preview.damage) == 0, "intro Pattern preview explains its zero base damage", failures)
	_check(before == battle.checkpoint() and rng_before == battle.rng_snapshot(), "preview leaves battle state and RNG unchanged", failures)
	var partial_result = controller.confirm(str(partial.id))
	_check(partial_result.accepted, "previewed Pattern executes", failures)
	var output: Dictionary = partial_result.data.get("combat_output", {})
	_check(int(output.get("damage", -1)) == int(preview.damage), "base preview agrees with authoritative conversion", failures)
	var core := {}
	for candidate in controller.action_descriptors():
		if str(candidate.get("target_id", "")) == "base.technique.core.sequence_line":
			core = candidate
			break
	var effects := ActionText.definition_effect_lines(controller.domain.content_registry, str(core.get("target_id", "")))
	_check(not effects.is_empty() and " ".join(effects).contains("TP") and " ".join(effects).contains("+1"), "Sequence skill describes its TP gain", failures)
	var winning_session = GuidedSample.new()
	winning_session.start(registry.registry)
	var winning_controller = winning_session.controller
	_choose(winning_controller, "CHARACTER")
	_choose(winning_controller, "CONTRACT")
	_choose(winning_controller, "MAP_NODE")
	for index in 3:
		_choose(winning_controller, "DRAW")
	var winning_battle = winning_controller.domain.current_battle
	_check(winning_battle.can_complete_hand(), "the prepared sample can form a Complete Hand", failures)
	if winning_battle.can_complete_hand():
		var complete := _action(winning_controller, "COMPLETE_HAND")
		var complete_preview: Dictionary = winning_battle.preview_settlement(str(complete.target_id), true)
		_check(int(complete_preview.consumed) == 14 and int(complete_preview.damage) > 0, "Complete Hand previews fourteen tiles and damage", failures)
	# Exercise the actual map UI: preview is reversible, Travel is the commit.
	var tree := Engine.get_main_loop() as SceneTree
	var scene = RunScene.new()
	scene.suspend_file_path = "user://new_player_experience_test_suspend.json"
	tree.root.add_child(scene)
	await tree.process_frame
	scene._on_guided_sample_pressed()
	_choose(scene.controller, "CHARACTER")
	_choose(scene.controller, "CONTRACT")
	await tree.process_frame
	var map_action := _action(scene.controller, "MAP_NODE")
	var command_count: int = scene.controller.domain.replay_record.commands.size()
	scene._journey_view._on_choice_selected(str(map_action.id))
	_check(scene.controller.domain.replay_record.commands.size() == command_count and str(scene.controller.domain.state.phase) == "MAP_CHOICE", "clicking a map node previews without travelling", failures)
	var travel: Button = scene.find_child("MapTravelButton", true, false)
	_check(travel != null and not travel.disabled, "preview enables the explicit Travel action", failures)
	if travel != null:
		travel.emit_signal("pressed")
	await tree.process_frame
	_check(str(scene.controller.domain.state.phase) == "BATTLE", "Travel enters the selected battle", failures)
	var guidance: Label = scene.find_child("TutorialPrompt", true, false)
	_check(guidance != null and guidance.is_visible_in_tree() and guidance.get_parent().get_parent().name == "PlayerGuidanceScroll", "lesson remains outside the scrolling journey", failures)
	var active_battle = scene.controller.domain.current_battle
	active_battle.combat_state.pressure = active_battle.combat_state.pressure_limit - 1
	_check(ActionText.lethal_intent_amount(active_battle) > 0, "lethal Pressure intent is detected before End Turn", failures)
	_choose(scene.controller, "END_TURN")
	var summary: Dictionary = scene.controller.domain.state.terminal_summary.summary_data
	_check(summary.has("defeat_context") and int(summary.defeat_context.pressure) == int(summary.defeat_context.pressure_limit), "defeat preserves final Pressure before battle cleanup", failures)
	_check(not ActionText.defeat_text(summary).is_empty(), "defeat supplies a practical localized lesson", failures)
	scene.free()
	if FileAccess.file_exists("user://new_player_experience_test_suspend.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://new_player_experience_test_suspend.json"))
	var normal_domain = RunDomain.new("new-player.defeat", 71305, registry.registry)
	var normal_controller = Controller.new(normal_domain)
	_choose(normal_controller, "CHARACTER")
	_choose(normal_controller, "CONTRACT")
	_choose(normal_controller, "MAP_NODE")
	for turn in 30:
		if str(normal_domain.state.phase) != "BATTLE":
			break
		_choose(normal_controller, "END_TURN")
	_check(str(normal_domain.state.phase) == "RUN_SUMMARY", "ordinary accepted commands reproduce defeat", failures)
	var trace_summary: Dictionary = normal_domain.checkpoint().run_state.terminal_summary.summary_data
	_check(not trace_summary.has("defeat_context"), "presentation-only defeat details preserve deterministic replay hashes", failures)
	for checkpoint in normal_domain.replay_record.checkpoints:
		for domain_event in checkpoint.domain_events:
			if str(domain_event.get("event_type", "")) == "RunSummaryReached":
				_check(not domain_event.get("data", {}).get("summary_data", {}).has("defeat_context"), "saved UI explanation does not change deterministic summary events", failures)
	var replay_factory := func(seed: int, _content_version: String): return RunDomain.new("new-player.defeat", seed, registry.registry)
	var replay_report = ReplayVerifier.verify(normal_domain.replay_record, replay_factory, normal_domain.state.content_version)
	_check(replay_report.is_match(), "new defeat replay verifies exactly", failures)
	var saved = SaveMapper.suspend_snapshot(normal_domain)
	var restored: Dictionary = SaveMapper.load_into_domain(saved.serialize(), registry.registry)
	_check(bool(restored.get("accepted", false)), "defeat summary snapshot reloads: %s" % str(restored.get("errors", restored.get("code", "unknown"))), failures)
	if bool(restored.get("accepted", false)):
		_check(restored.domain.state.terminal_summary.summary_data.get("defeat_context", {}) == normal_domain.state.terminal_summary.summary_data.get("defeat_context", {}), "saved defeat explanation survives reload", failures)
	# A legacy special with no implemented gameplay effect must not be a buyable UI choice.
	normal_domain.state.phase = "SHOP"
	normal_domain.state.gold = 100
	normal_domain.state.shop_state.active = true
	normal_domain.state.shop_state.entry_id = "test.special.entry"
	var inert_offer = ShopOffer.new("test.special.no_effect", 0, "SPECIAL", "base.special.copy_license", 15, {"special_action": "COPY_LICENSE"})
	normal_domain.state.shop_state.offers = [inert_offer]
	var journey = JourneyView.new()
	journey._controller = normal_controller
	journey._state = normal_domain.state
	var inert_action := {"id": "shop.buy:test.special.no_effect", "kind": "SHOP_OFFER", "target_id": inert_offer.offer_id, "entry_id": "test.special.entry", "details": inert_offer.to_dictionary()}
	_check(not journey._shop_offer_available(inert_action), "shop UI blocks spending Gold on an offer without a gameplay effect", failures)
	var token_lines := ActionText.shop_offer_effect_lines(registry.registry, {"kind": "SPECIAL", "metadata": {"special_action": "REFINEMENT_TOKEN"}})
	_check(not token_lines.is_empty() and token_lines[0].contains("+1"), "special shop offer previews the actual Refinement Token gain", failures)
	var modifier_lines := ActionText.definition_effect_lines(registry.registry, "alpha.modifier.trade_mark")
	_check(not modifier_lines.is_empty() and modifier_lines[0].begins_with(Localization.template("UI_PLAYER_EFFECT_TILE_SETTLED").get_slice("%s", 0)), "modifier preview explains when its effect happens", failures)
	var gold_before: int = normal_domain.state.gold
	normal_controller._refresh([])
	var rejected_purchase = normal_controller.confirm(str(inert_action.id))
	_check(not rejected_purchase.accepted and normal_domain.state.gold == gold_before, "presentation command path rejects a no-effect purchase without spending Gold", failures)
	journey.free()
	completed = true
	return failures

func _action(controller, kind: String) -> Dictionary:
	for action in controller.action_descriptors():
		if str(action.get("kind", "")) == kind:
			if kind == "CHARACTER" and str(action.get("target_id", "")) != "base.character.sequence":
				continue
			return action
	return {}

func _choose(controller, kind: String) -> void:
	if kind == "END_TURN" and controller.domain.current_battle != null and controller.domain.current_battle.validate_end_turn().code == "PLAY_REQUIRED":
		_choose(controller, "DISCARD")
	var action := _action(controller, kind)
	if not action.is_empty():
		controller.confirm(str(action.id))

func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
