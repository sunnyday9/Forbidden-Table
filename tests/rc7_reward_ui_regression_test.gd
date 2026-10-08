extends RefCounted

const Registry = preload("res://src/content/registry/content_registry.gd")
const Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const ScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const Run = preload("res://src/domain/run/run_domain.gd")
const Controller = preload("res://src/presentation/run/run_presentation_controller.gd")
const View = preload("res://src/presentation/ui/run_journey_view.gd")
const Character = preload("res://src/domain/commands/choose_character_command.gd")
const Option = preload("res://src/domain/run/reward_option.gd")
const Draft = preload("res://src/domain/run/reward_draft.gd")
const Receipt = preload("res://src/presentation/ui/run_reward_receipt_view.gd")
const Contract = preload("res://src/domain/commands/choose_contract_command.gd")
const MapNode = preload("res://src/domain/commands/select_map_node_command.gd")
const Draw = preload("res://src/domain/commands/draw_command.gd")
const EndTurn = preload("res://src/domain/commands/end_turn_command.gd")
const Store = preload("res://src/domain/commands/store_tile_command.gd")
const BattleView = preload("res://src/presentation/ui/battle_view.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var registry = Registry.new()
	Catalog.register_all(registry)
	ScaleCatalog.register_all(registry)
	ActTwoCatalog.register_all(registry)
	var domain = Run.new_alpha_run("rc7.ui.%d" % Time.get_ticks_usec(), 7707, registry)
	domain.execute(Character.new("rc7.ui.character", "base.character.sequence"))
	var option = Option.new("rc7.upgrade", Option.MODIFIED_TILE, "base.modifier.flexible_identity", "", "base.modifier.flexible_identity", "", Option.NEUTRAL, 0, 0, {"target_mode": "CHOOSE_TYPE", "target_limit": 2})
	domain.state.phase = "REWARD_CHOICE"
	domain.state.reward_draft = Draft.new("rc7.ui.draft", "NORMAL", "rc7.encounter", "NORMAL", [option])
	var controller = Controller.new(domain)
	var checkpoint: Dictionary = domain.checkpoint().duplicate(true)
	var picked = controller.confirm("reward:rc7.upgrade")
	if not picked is Dictionary or str(picked.get("status", "")) != "PRESENTATION_SELECTION":
		failures.append("targeted upgrade opens a tile-type picker without submitting a reward command")
	if domain.checkpoint() != checkpoint:
		failures.append("opening the reward picker preserves all authoritative state")
	var targets: Array = controller.action_descriptors().filter(func(action): return action.kind == "REWARD_TARGET")
	if targets.is_empty():
		failures.append("target picker offers owned eligible tile types")
	else:
		var result = controller.confirm(str(targets[0].id))
		if result == null or not result.accepted:
			failures.append("choosing an eligible type applies the reward immediately")
		var upgraded := 0
		for modifiers in domain.state.build_ownership.persistent_tile_modifier_state.values():
			if modifiers.has("base.modifier.flexible_identity"):
				upgraded += 1
		if upgraded != 2:
			failures.append("one target choice visibly upgrades exactly two owned copies")
		if result != null and result.accepted:
			var receipt = Receipt.new()
			Engine.get_main_loop().root.add_child(receipt)
			receipt.show_result(result.to_dictionary(), checkpoint.get("run_state", {}), domain.checkpoint().get("run_state", {}), registry)
			if receipt.find_children("ReceiptTileFace*", "TextureRect", true, false).size() != 2:
				failures.append("the accepted modifier receipt displays both affected copies")
			receipt.queue_free()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var original_size := tree.root.size
	var original_locale := TranslationServer.get_locale()
	domain.state.phase = "REWARD_CHOICE"
	var view = View.new()
	view.configure(func(action): return str(action.get("id", "choice")), func(action): return str(action.get("id", "choice")), func(action): return str(action.get("id", "choice")), func(id): return str(id), func(id): return str(id))
	tree.root.add_child(view)
	view.render(controller, [{"id": "reward:targeted", "kind": "REWARD", "details": option.to_dictionary()}], "reward:targeted")
	await tree.process_frame
	if view.find_child("RewardTileFace", true, false) != null:
		failures.append("an upgrade with no selected tile type never renders a blank tile face")
	if view.find_child("RewardChoiceButton", true, false) == null:
		failures.append("the initial targeted upgrade presents an accessible choice button")
	var target_details: Dictionary = option.to_dictionary()
	target_details["tile_id"] = "base.tile.characters.1"
	target_details["target_count"] = 2
	var target_action := {"id": "reward:targeted:type", "kind": "REWARD_TARGET", "details": target_details}
	for viewport_size in [Vector2i(960, 540), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		tree.root.size = viewport_size
		for locale in ["en", "zh_CN"]:
			TranslationServer.set_locale(locale)
			view.set_presentation_preferences(locale, 1.5 if locale == "zh_CN" else 1.0)
			view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			view.render(controller, [target_action, {"id": "reward:target:back", "kind": "REWARD_TARGET_BACK"}], str(target_action.id))
			for _frame in 4:
				await tree.process_frame
			var face = view.find_child("RewardTileFace", true, false)
			if face == null or str(face.tile_definition_id) != "base.tile.characters.1":
				failures.append("target picker displays registered tile art at %s/%s" % [viewport_size, locale])
			var back = view.action_button("reward:target:back")
			if back == null or not back.is_visible_in_tree():
				failures.append("target picker has an accessible Back choice at %s/%s" % [viewport_size, locale])
			if view.get_combined_minimum_size().x > viewport_size.x + 1:
				failures.append("target picker does not force horizontal overflow at %s/%s" % [viewport_size, locale])
	view.queue_free()
	await tree.process_frame
	tree.root.size = original_size
	TranslationServer.set_locale(original_locale)
	await _test_workshop_ui(registry, failures)
	await _test_capacity_discard_ui(failures)
	return failures

func _test_workshop_ui(registry, failures: Array[String]) -> void:
	var domain = Run.new_alpha_run("rc7.workshop.ui.%d" % Time.get_ticks_usec(), 7708, registry)
	domain.execute(Character.new("rc7.workshop.character", "base.character.sequence"))
	domain.state.phase = "WORKSHOP"
	domain.state.gold = 100
	domain.state.workshop_state.begin("rc7.workshop.node", "rc7.workshop.entry")
	var controller = Controller.new(domain)
	var selected = controller.confirm("workshop:service:REMOVE_PAIR")
	if not selected is Dictionary:
		failures.append("Workshop offers a visual two-copy removal service")
		return
	var choices: Array = controller.action_descriptors().filter(func(action): return action.kind == "WORKSHOP_SERVICE")
	if choices.size() != 34:
		failures.append("batch removal groups the Sequence pool into 34 tile types")
	if choices.is_empty():
		return
	var view = View.new()
	view.configure(func(action): return str(action.get("id", "choice")), func(action): return str(action.get("id", "choice")), func(action): return str(action.get("id", "choice")), func(id): return str(id), func(id): return str(id))
	Engine.get_main_loop().root.add_child(view)
	view.render(controller, [choices[0]], str(choices[0].id))
	await Engine.get_main_loop().process_frame

	var faces = view.find_child("WorkshopRemovalCopies", true, false)
	if faces == null or faces.get_child_count() != 2:
		failures.append("batch removal preview shows the two physical copies")
	var before: Dictionary = domain.checkpoint().duplicate(true)
	var result = controller.confirm(str(choices[0].id))
	if result == null or not result.accepted:
		failures.append("choosing the displayed pair removes it immediately")
	else:
		var receipt = Receipt.new()
		Engine.get_main_loop().root.add_child(receipt)
		receipt.show_result(result.to_dictionary(), before.get("run_state", {}), domain.checkpoint().get("run_state", {}), registry)
		if receipt.find_children("ReceiptTileFace*", "TextureRect", true, false).size() != 2:
			failures.append("batch removal receipt displays both removed physical copies")
		receipt.queue_free()
	view.queue_free()
	await Engine.get_main_loop().process_frame


func _test_capacity_discard_ui(failures: Array[String]) -> void:
	var registry = Registry.new()
	Catalog.register_all(registry)
	var domain = Run.new("rc7.capacity.ui.%d" % Time.get_ticks_usec(), 7710, registry)
	domain.execute(Character.new("rc7.capacity.character", "base.character.sequence"))
	domain.execute(Contract.new("rc7.capacity.contract", Catalog.CONTRACT_IDS[0]))
	domain.execute(MapNode.new("rc7.capacity.battle", domain.map_definition.start_node_id))
	var battle = domain.current_battle
	if battle == null:
		failures.append("capacity UI fixture enters a real battle")
		return
	battle.combat_state.draw_capacity = 8
	battle.combat_state.enemy_hp = 999
	battle.combat_state.pressure_limit = 999
	for index in 3:
		domain.execute(Draw.new("rc7.capacity.draw.%d" % index))
	domain.execute(EndTurn.new("rc7.capacity.end"))
	var controller = Controller.new(domain)
	var discards: Array = controller.action_descriptors().filter(func(action): return action.kind == "DISCARD")
	if discards.size() != 14:
		failures.append("the UI exposes all fourteen legal turn-start capacity discards")
	var before: Dictionary = domain.checkpoint().duplicate(true)
	var view = BattleView.new()
	view.configure(controller, func(action): return str(action.get("id", "choice")), func(action): return str(action.get("id", "choice")), func(action): return str(action.get("id", "choice")))
	Engine.get_main_loop().root.add_child(view)
	view.render()
	var advice = view.find_child("DiscardAdviceButton", true, false) as Button
	if advice != null:
		advice.pressed.emit()
	if view.find_child("BattleDiscardAdvice", true, false) == null:
		failures.append("optional discard advice is available for the full turn-start Hand")
	if domain.checkpoint() != before:
		failures.append("requesting discard advice never changes authoritative state")
	if not discards.is_empty():
		var result = controller.confirm(str(discards[0].id))
		if result == null or not result.accepted or battle.zones.size("Hand") != 13:
			failures.append("the exposed discard choice releases exactly one Hand slot")
		controller.submit(Draw.new("rc7.capacity.redraw"))
		var store_id := str(battle.zones.contents("Hand")[0].instance_id)
		controller.submit(Store.new("rc7.capacity.store", store_id))
		var independent_discards: Array = controller.action_descriptors().filter(func(action): return action.kind == "DISCARD")
		if independent_discards.size() != 13:
			failures.append("using Reserve storage does not hide the independent discard choices")
	view.queue_free()
	await Engine.get_main_loop().process_frame
