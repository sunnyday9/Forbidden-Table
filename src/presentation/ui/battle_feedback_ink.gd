extends Control

var ink_kind: String = ""
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var ink_color := Color.WHITE
var _progress := 0.0
var progress: float:
	get:
		return _progress
	set(value):
		_progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func configure(kind: String, from_point: Vector2, to_point: Vector2, color: Color) -> void:
	ink_kind = kind
	origin = from_point
	destination = to_point
	ink_color = color
	_progress = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _draw() -> void:
	match ink_kind:
		"flight", "pressure", "effect":
			_draw_travel()
		"impact":
			_draw_impact()
		"ward":
			_draw_ward()
		"stability":
			_draw_stability()
		"phase":
			_draw_phase()
		"victory":
			_draw_victory()


func _draw_travel() -> void:
	var travel_progress := minf(_progress / 0.65, 1.0) if ink_kind == "flight" else _progress
	if ink_kind == "pressure":
		# The red seal gathers at the enemy first, then visibly crosses the table.
		var windup := clampf(_progress / 0.34, 0.0, 1.0)
		var source_radius := lerpf(8.0, 29.0, windup)
		var source_alpha := 0.72 * (1.0 - windup * 0.5)
		for ring in range(2):
			draw_arc(origin, source_radius + float(ring) * 8.0, -PI * 0.86, PI * 0.86, 28, _with_alpha(ink_color, source_alpha - float(ring) * 0.22), 4.0 - float(ring), true)
		travel_progress = clampf((_progress - 0.28) / 0.72, 0.0, 1.0)
	elif ink_kind == "effect":
		var source_radius := lerpf(5.0, 23.0, minf(_progress / 0.38, 1.0))
		draw_arc(origin, source_radius, -PI, PI, 24, _with_alpha(ink_color, 0.58), 3.0, true)
		travel_progress = clampf((_progress - 0.22) / 0.78, 0.0, 1.0)
	if travel_progress <= 0.0:
		return
	var trail_start := maxf(0.0, travel_progress - 0.46)
	var points := PackedVector2Array()
	var steps := 18
	for index in range(steps + 1):
		var fraction := lerpf(trail_start, travel_progress, float(index) / float(steps))
		points.append(_curve_point(fraction))
	if points.size() >= 2:
		draw_polyline(points, _with_alpha(ink_color, 0.24), 19.0, true)
		draw_polyline(points, _with_alpha(ink_color, 0.72), 7.5, true)
		draw_polyline(points, Color(1.0, 0.91, 0.70, 0.92), 2.1, true)
	var head := _curve_point(travel_progress)
	draw_circle(head, 9.0, _with_alpha(ink_color, 0.28))
	draw_circle(head, 4.2, Color(1.0, 0.94, 0.77, 0.96))
	if travel_progress > 0.88:
		var impact_fraction := (travel_progress - 0.88) / 0.12
		var impact_color := _with_alpha(ink_color, 1.0 - impact_fraction)
		draw_arc(destination, lerpf(8.0, 35.0, impact_fraction), -PI, PI, 32, impact_color, 5.0 * (1.0 - impact_fraction) + 1.0, true)
		draw_arc(destination, lerpf(3.0, 20.0, impact_fraction), -PI, PI, 24, Color(1.0, 0.91, 0.70, 0.8 * (1.0 - impact_fraction)), 2.0, true)


func _draw_impact() -> void:
	if _progress < 0.65:
		return
	var impact_progress := clampf((_progress - 0.65) / 0.35, 0.0, 1.0)
	var radius := lerpf(7.0, 46.0, impact_progress)
	var alpha := (1.0 - impact_progress) * 0.92
	draw_circle(destination, 7.0 + impact_progress * 5.0, _with_alpha(ink_color, 0.26 * alpha))
	draw_arc(destination, radius, -PI, PI, 36, _with_alpha(ink_color, alpha), lerpf(5.5, 1.0, impact_progress), true)
	draw_arc(destination, radius * 0.62, -PI, PI, 28, Color(1.0, 0.91, 0.70, alpha * 0.82), 1.8, true)
	for spoke in range(8):
		var angle := TAU * float(spoke) / 8.0
		var inner := destination + Vector2(cos(angle), sin(angle)) * (radius * 0.73)
		var outer := destination + Vector2(cos(angle), sin(angle)) * (radius + 5.0)
		draw_line(inner, outer, _with_alpha(ink_color, alpha * 0.84), 2.0, true)


func _draw_ward() -> void:
	var radius := lerpf(13.0, 58.0, _progress)
	var alpha := (1.0 - _progress * 0.58) * 0.9
	draw_arc(origin, radius, -PI * 0.88, PI * 0.88, 38, _with_alpha(ink_color, alpha), 5.0, true)
	draw_arc(origin, radius * 0.72, -PI * 0.72, PI * 0.72, 34, Color(1.0, 0.91, 0.70, alpha * 0.82), 2.0, true)
	var shield := PackedVector2Array([
		origin + Vector2(0.0, -25.0),
		origin + Vector2(23.0, -11.0),
		origin + Vector2(18.0, 15.0),
		origin + Vector2(0.0, 31.0),
		origin + Vector2(-18.0, 15.0),
		origin + Vector2(-23.0, -11.0),
	])
	draw_colored_polygon(shield, Color(ink_color.r, ink_color.g, ink_color.b, 0.10 * alpha))
	shield.append(shield[0])
	draw_polyline(shield, _with_alpha(ink_color, alpha), 3.0, true)
	draw_line(origin + Vector2(-10.0, 1.0), origin + Vector2(-2.0, 9.0), Color(1.0, 0.96, 0.78, alpha), 3.0, true)
	draw_line(origin + Vector2(-2.0, 9.0), origin + Vector2(13.0, -8.0), Color(1.0, 0.96, 0.78, alpha), 3.0, true)


func _draw_stability() -> void:
	var radius := lerpf(9.0, 54.0, _progress)
	var alpha := 1.0 - _progress * 0.7
	for ring in range(3):
		var offset := float(ring) * 9.0
		draw_arc(origin, radius + offset, -PI * 0.9, PI * 0.9, 36, _with_alpha(ink_color, alpha * (0.82 - float(ring) * 0.2)), 3.5 - float(ring) * 0.7, true)
	for spoke in range(6):
		var angle := TAU * float(spoke) / 6.0
		var point := origin + Vector2(cos(angle), sin(angle)) * (radius + 13.0)
		draw_circle(point, 2.6, Color(1.0, 0.91, 0.70, alpha))


func _draw_phase() -> void:
	var radius := lerpf(14.0, 92.0, _progress)
	var alpha := 1.0 - _progress * 0.65
	for ring in range(3):
		var start_angle := -PI * 0.74 + float(ring) * 0.42
		var end_angle := PI * 0.74 - float(ring) * 0.42
		draw_arc(origin, radius + float(ring) * 13.0, start_angle, end_angle, 42, _with_alpha(ink_color, alpha * (0.92 - float(ring) * 0.2)), 4.0 - float(ring), true)
	for spoke in range(10):
		var angle := TAU * float(spoke) / 10.0 + _progress * 0.08
		var inner := origin + Vector2(cos(angle), sin(angle)) * (radius - 9.0)
		var outer := origin + Vector2(cos(angle), sin(angle)) * (radius + 11.0)
		draw_line(inner, outer, _with_alpha(ink_color, alpha), 2.3, true)


func _draw_victory() -> void:
	var radius := lerpf(16.0, 108.0, _progress)
	var alpha := 1.0 - _progress * 0.7
	for ring in range(3):
		draw_arc(origin, radius + float(ring) * 14.0, -PI, PI, 48, _with_alpha(ink_color, alpha * (0.96 - float(ring) * 0.18)), 4.5 - float(ring), true)
	for ray in range(12):
		var angle := TAU * float(ray) / 12.0
		var start := origin + Vector2(cos(angle), sin(angle)) * (radius * 0.64)
		var finish := origin + Vector2(cos(angle), sin(angle)) * (radius + 24.0)
		draw_line(start, finish, _with_alpha(ink_color, alpha * 0.84), 2.6, true)


func _curve_point(progress_value: float) -> Vector2:
	var fraction := clampf(progress_value, 0.0, 1.0)
	var midpoint := origin.lerp(destination, 0.5)
	var delta := destination - origin
	var normal := Vector2(-delta.y, delta.x).normalized()
	var arc_height := clampf(delta.length() * 0.14, 22.0, 80.0)
	var control := midpoint - normal * arc_height
	var inverse := 1.0 - fraction
	return origin * inverse * inverse + control * 2.0 * inverse * fraction + destination * fraction * fraction


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
