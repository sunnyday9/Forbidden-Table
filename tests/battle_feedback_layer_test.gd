extends RefCounted

const LAYER_PATH := "res://src/presentation/ui/battle_feedback_layer.gd"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_viewport_size := tree.root.size
	tree.root.size = Vector2i(960, 540)
	var script := load(LAYER_PATH) as Script
	var failures: Array[String] = []
	assert_true(script != null, "the combat choreography layer is available through its public interface", failures)
	if script == null:
		tree.root.size = previous_viewport_size
		return failures

	var layer = script.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.root.add_child(layer)
	var anchors := _anchors()
	var started: Array[Dictionary] = []
	var finished: Array[bool] = []
	layer.cue_started.connect(func(cue: Dictionary) -> void: started.append(cue))
	layer.playback_finished.connect(func() -> void: finished.append(true))

	# The Normal seam starts one cue immediately and exposes a defensive copy of it.
	layer.configure("NORMAL", false)
	var draw_cue := {
		"kind": "DRAW",
		"definition_id": "base.tile.characters.1",
		"instance_id": "tile.drawn",
		"text": "Characters 1 drawn",
	}
	layer.play([draw_cue], anchors)
	assert_true(layer.is_playing(), "Normal playback remains active while the tile travels from Wall to Hand", failures)
	assert_true(layer.current_cue().get("instance_id", "") == "tile.drawn", "the current cue exposes the physical tile being animated", failures)
	var caller_copy: Dictionary = layer.current_cue()
	caller_copy["nested"] = {"value": "changed"}
	assert_true(not layer.current_cue().has("nested"), "mutating a current-cue copy cannot change the active receipt", failures)
	assert_true(started.size() == 1 and started[0].get("kind", "") == "DRAW", "cue_started reports the ordered public cue", failures)
	await tree.create_timer(0.9).timeout
	assert_true(not layer.is_playing() and layer.current_cue().is_empty(), "completed playback clears its current cue", failures)
	assert_true(finished.size() == 1, "a completed batch emits one playback_finished signal", failures)

	# Instant and reduced-motion receipts are synchronous and keep factual cue order.
	started.clear()
	finished.clear()
	layer.configure("INSTANT", false)
	var instant_cues: Array[Dictionary] = [
		{"kind": "DRAW", "instance_id": "draw.1", "definition_id": "base.tile.dots.2", "text": "Drawn"},
		{"kind": "ATTACK", "amount": 4, "text": "4 damage"},
		{"kind": "RELIEF", "amount": 2, "text": "2 pressure relieved"},
	]
	layer.play(instant_cues, anchors)
	assert_true(not layer.is_playing() and layer.current_cue().is_empty(), "Instant playback creates no active visual sequence", failures)
	assert_true(_kinds(started) == ["DRAW", "ATTACK", "RELIEF"], "Instant playback synchronously preserves the complete factual order", failures)
	assert_true(finished.size() == 1, "Instant playback finishes its batch once", failures)

	started.clear()
	finished.clear()
	layer.configure("NORMAL", true)
	layer.play([{"kind": "PRESSURE", "amount": 3, "text": "3 pressure"}, {"kind": "PHASE", "text": "Second phase"}], anchors)
	assert_true(not layer.is_playing() and _kinds(started) == ["PRESSURE", "PHASE"], "reduced motion emits the readable receipt without a moving sequence", failures)
	assert_true(finished.size() == 1, "reduced-motion playback finishes synchronously", failures)

	# Fast still builds real tile flights, enemy windups, impacts, wards, and action-target effects.
	started.clear()
	finished.clear()
	layer.configure("FAST", false)
	var full_sequence: Array[Dictionary] = [
		{"kind": "DRAW", "instance_id": "tile.drawn", "definition_id": "base.tile.characters.1", "text": "Drawn"},
		{"kind": "DISCARD", "instance_id": "tile.discard", "definition_id": "base.tile.dots.2", "text": "Discarded"},
		{"kind": "SETTLE", "instance_ids": ["tile.a", "tile.b", "tile.c"], "definition_ids": ["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3"], "text": "Pattern settled"},
		{"kind": "COMPLETE", "instance_ids": ["tile.d", "tile.e"], "definition_ids": ["base.tile.dots.4", "base.tile.dots.5"], "text": "Complete Hand"},
		{"kind": "ATTACK", "amount": 7, "text": "Attack for 7"},
		{"kind": "RELIEF", "amount": 2, "text": "2 pressure relieved"},
		{"kind": "PRESSURE", "amount": 3, "text": "3 incoming pressure"},
		{"kind": "ENEMY_EFFECT", "action_type": "WALL_TAX", "channel": "draw_wall", "target_instance_id": "tile.target", "text": "Draw Wall capacity −1"},
		{"kind": "STABILITY", "amount": 2, "text": "Stability +2"},
		{"kind": "STRESS", "amount": 1, "text": "Pressure +1"},
		{"kind": "PHASE", "text": "Second phase"},
		{"kind": "VICTORY", "text": "Victory!"},
	]
	layer.play(full_sequence, anchors)
	await tree.create_timer(3.8).timeout
	assert_true(_kinds(started) == ["DRAW", "DISCARD", "SETTLE", "COMPLETE", "ATTACK", "RELIEF", "PRESSURE", "ENEMY_EFFECT", "STABILITY", "STRESS", "PHASE", "VICTORY"], "Fast playback preserves the complete authored choreography order", failures)
	assert_true(not layer.is_playing() and layer.current_cue().is_empty(), "the full Fast choreography clears all transient presentation state", failures)
	assert_true(finished.size() == 1, "the full Fast cue queue emits one completion receipt", failures)

	# Repeated high-trigger hits keep ordered receipts but share one readable impact.
	layer.configure("NORMAL", false)
	started.clear()
	var repeated_hits: Array = []
	for index in range(50):
		repeated_hits.append({"kind": "ATTACK", "source_id": "technique.echo", "origin": "player", "amount": 1, "text": "1 damage"})
	layer.play(repeated_hits, anchors)
	assert_true(started.size() == 50, "Repeated hits retain every factual receipt without fifty sequential flashes", failures)
	assert_true(int(layer.current_cue().get("amount", 0)) == 50 and int(layer.current_cue().get("count", 0)) == 50, "A repeated same-source burst presents the actual aggregate damage and hit count", failures)
	await tree.create_timer(0.9).timeout
	assert_true(not layer.is_playing(), "A high-trigger burst remains readable and finishes as one impact", failures)
	layer.cancel()

	# Distinct-source, mixed factual bursts keep every receipt while showing one
	# bounded summary instead of compressing dozens of separate flashes.
	TranslationServer.set_locale("en")
	started.clear()
	finished.clear()
	var mixed_cues: Array[Dictionary] = [
		{"kind": "PRESSURE", "source_id": "intent.pressure", "amount": 3, "receipt_id": "summary.pressure.add"},
		{"kind": "STRESS", "source_id": "effect.stress", "amount": 1, "receipt_id": "summary.pressure.stress"},
		{"kind": "STABILITY", "amount": 2, "receipt_id": "summary.stability.gain"},
		{"kind": "DRAW", "instance_id": "summary.draw", "definition_id": "base.tile.dots.1", "receipt_id": "summary.draw"},
		{"kind": "DISCARD", "instance_id": "summary.discard", "definition_id": "base.tile.dots.2", "receipt_id": "summary.discard"},
		{"kind": "STABILITY", "amount": -1, "receipt_id": "summary.stability.loss"},
	]
	var expected_receipt_ids: Array[String] = []
	for cue in mixed_cues:
		expected_receipt_ids.append(str(cue.receipt_id))
	for index in range(50):
		var receipt_id := "mixed.%02d" % index
		var cue: Dictionary
		match index % 3:
			0:
				cue = {"kind": "ATTACK", "source_id": "source.attack.%02d" % index, "origin": "hand", "amount": 1, "text": "1 damage"}
			1:
				cue = {"kind": "RELIEF", "source_id": "source.relief.%02d" % index, "amount": 2, "text": "2 pressure relieved"}
			_:
				var effect_kind := "WALL_TAX" if index % 2 == 0 else "HUNT"
				cue = {"kind": "ENEMY_EFFECT", "source_id": "source.effect.%02d" % index, "action_type": effect_kind, "channel": "draw_capacity" if effect_kind == "WALL_TAX" else "reserve_integrity", "amount": index + 1, "text": "Effect applied"}
		cue["receipt_id"] = receipt_id
		mixed_cues.append(cue)
		expected_receipt_ids.append(receipt_id)
	mixed_cues.append({"kind": "PHASE", "text": "Second phase", "receipt_id": "summary.phase"})
	mixed_cues.append({"kind": "VICTORY", "text": "Victory!", "receipt_id": "summary.victory"})
	expected_receipt_ids.append("summary.phase")
	expected_receipt_ids.append("summary.victory")
	layer.play(mixed_cues, anchors)
	var active_burst: Dictionary = layer.current_cue()
	assert_true(layer.is_playing() and str(active_burst.get("kind", "")) == "BURST", "a long mixed-source batch starts with a readable Burst summary", failures)
	assert_true(
		int(active_burst.get("damage", 0)) == 17
		and int(active_burst.get("attack_count", 0)) == 17
		and str(active_burst.get("attack_origin", "")) == "player",
		"the Burst summary reports actual mixed-source damage from a generic Player origin",
		failures,
	)
	assert_true(
		int(active_burst.get("pressure_added", 0)) == 4
		and int(active_burst.get("pressure_relieved", 0)) == 34
		and bool(active_burst.get("incoming_pressure", false)),
		"the Burst keeps added Pressure and relief as separate actual totals and winds up from Enemy",
		failures,
	)
	assert_true(
		int(active_burst.get("stability_net", 0)) == 1
		and int(active_burst.get("draw_count", 0)) == 1
		and int(active_burst.get("discard_count", 0)) == 1
		and int(active_burst.get("enemy_effect_count", 0)) == 16
		and not active_burst.has("enemy_effect_amount"),
		"the Burst reports net Stability, tile counts, and effect count without summing unlike effects",
		failures,
	)
	var summary_lines: PackedStringArray = active_burst.get("summary_lines", PackedStringArray())
	assert_true(summary_lines.size() <= 6, "the Burst card stays within six readable summary lines", failures)
	await tree.create_timer(0.82).timeout
	var visible_burst: Dictionary = layer.current_cue()
	assert_true(layer.is_playing() and str(visible_burst.get("kind", "")) == "BURST", "the summary remains visible for at least 0.8 seconds in Normal mode", failures)
	var burst_card := layer.find_child("BattleFeedbackBurstCard", true, false) as Control
	assert_true(burst_card != null, "the mixed batch presents a bounded Burst summary card", failures)
	if burst_card != null:
		var burst_controls: Array[Control] = []
		_collect_controls(burst_card, burst_controls)
		assert_true(
			burst_controls.all(func(control: Control) -> bool: return control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE),
			"the Burst card and every Control descendant ignore mouse input and focus",
			failures,
		)
		var card_rect := burst_card.get_global_rect()
		var layer_rect: Rect2 = layer.get_global_rect()
		assert_true(
			card_rect.position.x >= layer_rect.position.x - 0.5
			and card_rect.position.y >= layer_rect.position.y - 0.5
			and card_rect.end.x <= layer_rect.end.x + 0.5
			and card_rect.end.y <= layer_rect.end.y + 0.5,
			"the Burst summary card remains entirely inside the visible battle layer",
			failures,
		)
	await tree.create_timer(0.25).timeout
	assert_true(layer.current_cue().get("kind", "") == "PHASE", "a high-priority phase cue remains a separate ordered presentation", failures)
	await tree.create_timer(0.7).timeout
	assert_true(layer.current_cue().get("kind", "") == "VICTORY", "a high-priority victory cue follows the phase cue separately", failures)
	await tree.create_timer(1.9).timeout
	var observed_receipt_ids: Array[String] = []
	for receipt in started:
		observed_receipt_ids.append(str(receipt.get("receipt_id", "")))
	assert_true(not layer.is_playing() and finished.size() == 1, "the mixed burst and retained high-priority cues finish inside four seconds", failures)
	assert_true(observed_receipt_ids == expected_receipt_ids, "all mixed and high-priority factual receipts retain their exact order", failures)
	layer.cancel()

	# Configure, cancellation, hiding, and a replacement batch all clear the old cue.
	layer.configure("NORMAL", false)
	finished.clear()
	layer.play([{"kind": "ATTACK", "amount": 8, "text": "8 damage"}], anchors)
	assert_true(layer.is_playing(), "a normal attack begins cosmetic playback", failures)
	var damage_labels: Array = layer.get_children().filter(func(node): return node is Label)
	assert_true(not damage_labels.is_empty() and damage_labels.all(func(node): return not node.visible), "Damage numbers wait for the projectile to reach the enemy", failures)
	await tree.create_timer(0.46).timeout
	assert_true(damage_labels.any(func(node): return is_instance_valid(node) and node.visible), "Damage numbers appear at the actual impact while the cue is still active", failures)

	layer.configure("INSTANT", false)
	assert_true(not layer.is_playing() and layer.current_cue().is_empty(), "changing to Instant clears an existing cosmetic cue", failures)
	assert_true(finished.size() == 1, "changing playback policy closes the previous batch once", failures)

	layer.configure("NORMAL", false)
	finished.clear()
	layer.play([{"kind": "PRESSURE", "amount": 3, "text": "Incoming"}], anchors)
	layer.cancel()
	assert_true(not layer.is_playing() and layer.current_cue().is_empty(), "cancel clears active choreography immediately", failures)
	assert_true(finished.size() == 1, "cancel finishes an active batch once", failures)

	started.clear()
	finished.clear()
	layer.play([{"kind": "ATTACK", "amount": 8, "text": "8 damage"}], anchors)
	layer.play([{"kind": "RELIEF", "amount": 2, "text": "2 pressure relieved"}], anchors)
	assert_true(_kinds(started) == ["ATTACK", "RELIEF"] and layer.current_cue().get("kind", "") == "RELIEF", "a replacement batch starts cleanly after the active overlay is superseded", failures)
	assert_true(finished.size() == 1 and layer.is_playing(), "superseding cosmetic playback closes only the prior batch", failures)
	layer.cancel()

	layer.configure("NORMAL", false)
	started.clear()
	var rebuild: Array = []
	for index in range(14):
		rebuild.append({"kind": "DRAW", "instance_id": "rebuild.%d" % index, "definition_id": "base.tile.characters.1", "text": "Rebuild tile"})
	layer.play(rebuild, anchors)
	await tree.create_timer(4.7).timeout
	assert_true(not layer.is_playing() and started.size() == 14, "A full fourteen-tile rebuild preserves every cue and finishes within a bounded four-second motion budget", failures)
	layer.cancel()

	finished.clear()
	layer.play([{"kind": "ATTACK", "amount": 1, "text": "Impact"}], anchors)
	layer.hide()
	assert_true(not layer.is_playing() and layer.current_cue().is_empty(), "hiding the layer cancels hidden cosmetic motion", failures)
	assert_true(finished.size() == 1, "hiding an active layer finishes its batch once", failures)
	layer.queue_free()
	await tree.process_frame
	tree.root.size = previous_viewport_size
	return failures

func _anchors() -> Dictionary:
	return {
		"enemy": Vector2(830.0, 160.0),
		"player": Vector2(140.0, 210.0),
		"wall": Vector2(740.0, 390.0),
		"hand": Vector2(300.0, 390.0),
		"discard": Vector2(530.0, 300.0),
		"tiles": {"tile.drawn": Rect2(330.0, 356.0, 42.0, 64.0)},
		"departing_tiles": {
			"tile.drawn": Rect2(704.0, 350.0, 42.0, 64.0),
			"tile.discard": Rect2(330.0, 356.0, 42.0, 64.0),
			"tile.a": Rect2(300.0, 356.0, 42.0, 64.0),
			"tile.b": Rect2(344.0, 356.0, 42.0, 64.0),
			"tile.c": Rect2(388.0, 356.0, 42.0, 64.0),
			"tile.d": Rect2(300.0, 356.0, 42.0, 64.0),
			"tile.e": Rect2(344.0, 356.0, 42.0, 64.0),
			"tile.target": Rect2(478.0, 254.0, 42.0, 64.0),
		},
	}

func _kinds(cues: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for cue in cues:
		result.append(str(cue.get("kind", "")))
	return result

func _collect_controls(node: Node, controls: Array[Control]) -> void:
	if node is Control:
		controls.append(node)
	for child in node.get_children():
		_collect_controls(child, controls)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
