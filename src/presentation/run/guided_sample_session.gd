class_name GuidedSampleSession
extends RefCounted

signal guide_changed

const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const TutorialProgressScript = preload("res://src/presentation/run/tutorial_progress.gd")
const GuidedSampleMapCatalogScript = preload("res://src/presentation/run/guided_sample_map_catalog.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const EnemyDefinitionScript = preload("res://src/content/definitions/enemy_definition.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")

const STATUS_IDLE := "IDLE"
const STATUS_ACTIVE := "ACTIVE"
const STATUS_SKIPPED := "SKIPPED"
const STATUS_COMPLETED := "COMPLETED"
const STATUS_EXITED := "EXITED"

const STEP_CHARACTER := "guided_sample.character"
const STEP_CONTRACT := "guided_sample.contract"
const STEP_INTRO_ROUTE := "guided_sample.intro_route"
const STEP_DRAW := "guided_sample.draw"
const STEP_INTENT := "guided_sample.intent"
const STEP_PATTERN := "guided_sample.pattern"
const STEP_RESERVE := "guided_sample.reserve"
const STEP_DISCARD := "guided_sample.discard"
const STEP_SWAP := "guided_sample.swap"
const STEP_TECHNIQUE := "guided_sample.technique"
const STEP_COMPLETE_HAND := "guided_sample.complete_hand"
const STEP_REWARD := "guided_sample.reward"
const STEP_FIRST_REWARD := "guided_sample.first_reward"
const STEP_PRACTICE_ROUTE := "guided_sample.practice_route"
const STEP_EVENT_ROUTE := "guided_sample.event_route"
const STEP_ENTER_EVENT := "guided_sample.enter_event"
const STEP_EVENT_OPTION := "guided_sample.event_option"
const STEP_SHOP_ROUTE := "guided_sample.shop_route"
const STEP_ENTER_SHOP := "guided_sample.enter_shop"
const STEP_EXIT_SHOP := "guided_sample.exit_shop"
const STEP_WORKSHOP_ROUTE := "guided_sample.workshop_route"
const STEP_ENTER_WORKSHOP := "guided_sample.enter_workshop"
const STEP_WORKSHOP_SERVICE := "guided_sample.workshop_service"
const STEP_EXIT_WORKSHOP := "guided_sample.exit_workshop"
const SAMPLE_WORKSHOP_ALLOWANCE := 40
const SAMPLE_WORKSHOP_REFINEMENT_TOKEN_ALLOWANCE := 1
const BATTLE_SETUP_FALLBACK_STEPS := [STEP_DRAW, STEP_PATTERN, STEP_RESERVE, STEP_DISCARD, STEP_SWAP, STEP_TECHNIQUE, STEP_COMPLETE_HAND]

const STEP_DESCRIPTORS := [
	{"id": STEP_CHARACTER, "prompt_key": "UI_GUIDED_SAMPLE_0001", "command_type": "ChooseCharacter", "action_kinds": ["CHARACTER"]},
	{"id": STEP_CONTRACT, "prompt_key": "UI_GUIDED_SAMPLE_0002", "command_type": "ChooseContract", "action_kinds": ["CONTRACT"]},
	{"id": STEP_INTRO_ROUTE, "prompt_key": "UI_GUIDED_SAMPLE_0003", "command_type": "SelectMapNode", "target_ids": [GuidedSampleMapCatalogScript.INTRO_NODE], "action_kinds": ["MAP_NODE"]},
	{"id": STEP_INTENT, "prompt_key": "UI_GUIDED_SAMPLE_0005", "command_type": "EndTurn", "action_kinds": ["END_TURN"]},
	{"id": STEP_DRAW, "prompt_key": "UI_GUIDED_SAMPLE_0004", "command_type": "Draw", "action_kinds": ["DRAW"]},
	{"id": STEP_COMPLETE_HAND, "prompt_key": "UI_GUIDED_SAMPLE_0011", "command_type": "SettleCompleteHand", "action_kinds": ["COMPLETE_HAND"]},
	{"id": STEP_FIRST_REWARD, "prompt_key": "UI_GUIDED_SAMPLE_0012", "command_type": "ChooseReward", "action_kinds": ["REWARD", "ELITE_REWARD", "BOSS_REWARD"]},
	{"id": STEP_PRACTICE_ROUTE, "prompt_key": "UI_GUIDED_SAMPLE_0024", "command_type": "SelectMapNode", "target_ids": [GuidedSampleMapCatalogScript.PRACTICE_NODE], "action_kinds": ["MAP_NODE"]},
	{"id": STEP_RESERVE, "prompt_key": "UI_GUIDED_SAMPLE_0007", "command_type": "StoreTile", "action_kinds": ["RESERVE"]},
	{"id": STEP_DISCARD, "prompt_key": "UI_GUIDED_SAMPLE_0008", "command_type": "DiscardTile", "action_kinds": ["DISCARD"]},
	{"id": STEP_SWAP, "prompt_key": "UI_GUIDED_SAMPLE_0009", "command_type": "SwapReserveTile", "action_kinds": ["RESERVE_SWAP"]},
	{"id": STEP_TECHNIQUE, "prompt_key": "UI_GUIDED_SAMPLE_0010", "command_type": "UseTechnique", "action_kinds": ["TECHNIQUE"]},
	{"id": STEP_PATTERN, "prompt_key": "UI_GUIDED_SAMPLE_0006", "command_type": "SettlePattern", "action_kinds": ["PARTIAL_SETTLEMENT"]},
	{"id": STEP_REWARD, "prompt_key": "UI_GUIDED_SAMPLE_0012", "command_type": "ChooseReward", "action_kinds": ["REWARD", "ELITE_REWARD", "BOSS_REWARD"]},
	{"id": STEP_EVENT_ROUTE, "prompt_key": "UI_GUIDED_SAMPLE_0013", "command_type": "SelectMapNode", "target_ids": [GuidedSampleMapCatalogScript.EVENT_REVEAL_NODE, GuidedSampleMapCatalogScript.EVENT_BARGAIN_NODE], "action_kinds": ["MAP_NODE"]},
	{"id": STEP_ENTER_EVENT, "prompt_key": "UI_GUIDED_SAMPLE_0014", "command_type": "EnterEvent", "action_kinds": ["ENTER_EVENT"]},
	{"id": STEP_EVENT_OPTION, "prompt_key": "UI_GUIDED_SAMPLE_0015", "command_type": "ChooseEventOption", "action_kinds": ["EVENT_OPTION"]},
	{"id": STEP_SHOP_ROUTE, "prompt_key": "UI_GUIDED_SAMPLE_0016", "command_type": "SelectMapNode", "target_ids": [GuidedSampleMapCatalogScript.SHOP_NODE], "action_kinds": ["MAP_NODE"]},
	{"id": STEP_ENTER_SHOP, "prompt_key": "UI_GUIDED_SAMPLE_0017", "command_type": "EnterShop", "action_kinds": ["ENTER_SHOP"]},
	{"id": STEP_EXIT_SHOP, "prompt_key": "UI_GUIDED_SAMPLE_0018", "command_type": "ExitShop", "action_kinds": ["SHOP_EXIT"]},
	{"id": STEP_WORKSHOP_ROUTE, "prompt_key": "UI_GUIDED_SAMPLE_0019", "command_type": "SelectMapNode", "target_ids": [GuidedSampleMapCatalogScript.WORKSHOP_NODE], "action_kinds": ["MAP_NODE"]},
	{"id": STEP_ENTER_WORKSHOP, "prompt_key": "UI_GUIDED_SAMPLE_0020", "command_type": "EnterWorkshop", "action_kinds": ["ENTER_WORKSHOP"]},
	{"id": STEP_WORKSHOP_SERVICE, "prompt_key": "UI_GUIDED_SAMPLE_0025", "command_type": "UseWorkshopService", "action_kinds": ["WORKSHOP_SELECT_SERVICE", "WORKSHOP_SELECT_TARGET", "WORKSHOP_SERVICE"]},
	{"id": STEP_EXIT_WORKSHOP, "prompt_key": "UI_GUIDED_SAMPLE_0021", "command_type": "ExitWorkshop", "action_kinds": ["WORKSHOP_EXIT"]},
]

var status := STATUS_IDLE
var controller
var _content_registry
var _seed := 0
var _attempt := 0
var _step_index := 0

var current_step_id: String:
	get:
		var step := current_step()
		return str(step.get("id", ""))

func start(content_registry, seed: int = 53005) -> Dictionary:
	if status == STATUS_ACTIVE:
		return {"accepted": false, "code": "SAMPLE_ALREADY_ACTIVE"}
	if content_registry == null or not content_registry.has_method("resolve") or not content_registry.has_method("enumerate"):
		return {"accepted": false, "code": "SAMPLE_CONTENT_UNAVAILABLE"}
	var isolated_registry_result := _build_sample_content_registry(content_registry)
	if not isolated_registry_result.get("accepted", false):
		return isolated_registry_result
	_content_registry = isolated_registry_result.registry
	_seed = seed
	_attempt = 0
	return _start_isolated_run()

func _build_sample_content_registry(source_registry) -> Dictionary:
	var registry = ContentRegistryScript.new()
	for definition in source_registry.enumerate():
		var registration = registry.register(definition)
		if not registration.is_valid():
			return {"accepted": false, "code": "SAMPLE_CONTENT_COPY_REJECTED", "content_id": str(definition.content_id)}
	var source_enemy = source_registry.resolve("base.enemy.pressure_sentinel")
	if not source_enemy is EnemyDefinitionScript:
		return {"accepted": false, "code": "SAMPLE_PRACTICE_ENEMY_UNAVAILABLE"}
	var battle_values: Dictionary = source_enemy.battle_values.duplicate(true)
	battle_values["pressure_limit"] = 60
	var practice_enemy = EnemyDefinitionScript.new(
		GuidedSampleMapCatalogScript.PRACTICE_ENEMY,
		source_enemy.intent_graph,
		EnemyDefinitionScript.NORMAL,
		60,
		battle_values,
		source_enemy.contamination_config,
	)
	var enemy_registration = registry.register(practice_enemy)
	if not enemy_registration.is_valid():
		return {"accepted": false, "code": "SAMPLE_PRACTICE_ENEMY_REJECTED"}
	var action_battle_values: Dictionary = source_enemy.battle_values.duplicate(true)
	action_battle_values["pressure_limit"] = 999
	action_battle_values["local_yaku_enabled"] = true
	var action_enemy = EnemyDefinitionScript.new(
		GuidedSampleMapCatalogScript.ACTION_PRACTICE_ENEMY,
		source_enemy.intent_graph,
		EnemyDefinitionScript.NORMAL,
		1,
		action_battle_values,
		source_enemy.contamination_config,
	)
	var action_enemy_registration = registry.register(action_enemy)
	if not action_enemy_registration.is_valid():
		return {"accepted": false, "code": "SAMPLE_ACTION_ENEMY_REJECTED"}
	var intro_encounter = EncounterDefinitionScript.new(
		GuidedSampleMapCatalogScript.INTRO_ENCOUNTER,
		[GuidedSampleMapCatalogScript.PRACTICE_ENEMY],
		EncounterDefinitionScript.NORMAL,
	)
	var intro_registration = registry.register(intro_encounter)
	if not intro_registration.is_valid():
		return {"accepted": false, "code": "SAMPLE_PRACTICE_ENCOUNTER_REJECTED"}
	var action_encounter = EncounterDefinitionScript.new(
		GuidedSampleMapCatalogScript.PRACTICE_ENCOUNTER,
		[GuidedSampleMapCatalogScript.ACTION_PRACTICE_ENEMY],
		EncounterDefinitionScript.NORMAL,
	)
	var action_registration = registry.register(action_encounter)
	if not action_registration.is_valid():
		return {"accepted": false, "code": "SAMPLE_ACTION_ENCOUNTER_REJECTED"}
	var report = registry.validate()
	if not report.is_valid():
		return {"accepted": false, "code": "SAMPLE_CONTENT_INVALID", "issues": report.issues}
	return {"accepted": true, "registry": registry}

func restart() -> bool:
	if _content_registry == null:
		return false
	_attempt += 1
	return bool(_start_isolated_run().get("accepted", false))

func skip() -> bool:
	if status != STATUS_ACTIVE:
		return false
	_disconnect_controller()
	status = STATUS_SKIPPED
	guide_changed.emit()
	return true

func exit() -> bool:
	if status not in [STATUS_ACTIVE, STATUS_SKIPPED, STATUS_COMPLETED]:
		return false
	_disconnect_controller()
	status = STATUS_EXITED
	guide_changed.emit()
	return true

func is_active() -> bool:
	return status == STATUS_ACTIVE

func current_step() -> Dictionary:
	if not is_active() or _step_index < 0 or _step_index >= STEP_DESCRIPTORS.size():
		return {}
	return STEP_DESCRIPTORS[_step_index].duplicate(true)

func current_prompt_key() -> String:
	if status == STATUS_COMPLETED:
		return "UI_GUIDED_SAMPLE_0022"
	return str(current_step().get("prompt_key", ""))

func step_descriptors() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for step in STEP_DESCRIPTORS:
		copy.append(step.duplicate(true))
	return copy

func completed_step_count() -> int:
	return _step_index

func highlighted_action_ids(actions: Array) -> Array[String]:
	var step := current_step()
	if step.is_empty():
		return []
	var step_id := str(step.get("id", ""))
	var kinds: Array = step.get("action_kinds", [])
	var targets: Array = step.get("target_ids", [])
	var result: Array[String] = []
	for action in actions:
		if not action is Dictionary or not kinds.has(str(action.get("kind", ""))):
			continue
		if step_id == STEP_WORKSHOP_SERVICE and str(action.get("service_id", "")) != "REFINEMENT_TOKEN":
			continue
		if step_id == STEP_RESERVE:
			var reserve_target_id := str(action.get("target_id", ""))
			if reserve_target_id.begins_with("run.tile.") or not _is_safe_reserve_candidate(reserve_target_id):
				continue
		if str(action.get("kind", "")) == "DRAW" and not _battle_can_draw():
			continue
		if not targets.is_empty() and not targets.has(str(action.get("target_id", ""))):
			continue
		result.append(str(action.get("id", "")))
	if result.is_empty() and BATTLE_SETUP_FALLBACK_STEPS.has(step_id):
		var fallback_kind := "DRAW" if _battle_can_draw() else "END_TURN"
		for action in actions:
			if action is Dictionary and str(action.get("kind", "")) == fallback_kind:
				result.append(str(action.get("id", "")))
				break
	return result

func _start_isolated_run() -> Dictionary:
	_disconnect_controller()
	var run_id := "guided-sample.%d.%d" % [_seed, _attempt]
	var sample_map = GuidedSampleMapCatalogScript.definition()
	var run_domain = RunDomainScript.new(run_id, _seed, _content_registry, "", null, 1, null, null, sample_map, SAMPLE_WORKSHOP_ALLOWANCE, SAMPLE_WORKSHOP_REFINEMENT_TOKEN_ALLOWANCE)
	var map_issues: Array[Dictionary] = run_domain.map_definition.graph_issues()
	if not map_issues.is_empty():
		status = STATUS_IDLE
		controller = null
		return {"accepted": false, "code": "SAMPLE_MAP_INVALID", "issues": map_issues}
	var tutorial_progress = TutorialProgressScript.new()
	tutorial_progress.disable()
	controller = RunPresentationControllerScript.new(run_domain, tutorial_progress, null, null)
	controller.command_processed.connect(_on_command_processed)
	_step_index = 0
	status = STATUS_ACTIVE
	guide_changed.emit()
	return {"accepted": true, "run_id": run_id}

func _on_command_processed(command, result) -> void:
	if not is_active() or command == null or result == null or not bool(result.accepted):
		return
	var step := current_step()
	var step_id := str(step.get("id", ""))
	if step_id == STEP_DRAW:
		if str(command.command_type()) == "Draw" and _battle_can_complete_hand():
			_advance_current_step()
		return
	if step_id == STEP_PATTERN:
		if str(command.command_type()) == "SettlePattern" and controller.domain.state.phase == RunPhaseScript.REWARD_CHOICE:
			_advance_current_step()
		return
	if str(command.command_type()) != str(step.get("command_type", "")):
		return
	var targets: Array = step.get("target_ids", [])
	if not targets.is_empty() and not targets.has(_command_target(command)):
		return
	_advance_current_step()

func _advance_current_step() -> void:
	_step_index += 1
	if _step_index >= STEP_DESCRIPTORS.size():
		status = STATUS_COMPLETED
	guide_changed.emit()

func _battle_can_draw() -> bool:
	return controller != null and controller.domain != null and controller.domain.can_draw()

func _battle_can_complete_hand() -> bool:
	return controller != null and controller.domain != null and controller.domain.can_complete_hand()

func _is_safe_reserve_candidate(instance_id: String) -> bool:
	return controller != null and controller.domain != null and controller.domain.is_safe_reserve_candidate(instance_id)

func _command_target(command) -> String:
	if command.get("node_id") != null:
		return str(command.get("node_id"))
	return ""

func _disconnect_controller() -> void:
	if controller == null or not controller.command_processed.is_connected(_on_command_processed):
		return
	controller.command_processed.disconnect(_on_command_processed)
