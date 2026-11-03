extends RefCounted
class_name BoardArt

## Общая отрисовка значков: ресурсы, метки владельца, вода в дырах.
## Используется полем и картинками на экране «Как играть».

const Palette = preload("res://scripts/palette.gd")


static func resource(canvas: CanvasItem, res: String, center: Vector2, radius: float) -> void:
	var color: Color = Palette.resource_color(res)
	match res:
		"gem":
			_gem(canvas, center, radius, color)
		"spark":
			_spark(canvas, center, radius, color)
		"magnet":
			_magnet(canvas, center, radius, color)
		"crown":
			_crown(canvas, center, radius, color)


static func cross(canvas: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	var width := maxf(2.5, radius * 0.42)
	canvas.draw_line(at + Vector2(-radius, -radius), at + Vector2(radius, radius), color, width, true)
	canvas.draw_line(at + Vector2(-radius, radius), at + Vector2(radius, -radius), color, width, true)


static func ring(canvas: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	canvas.draw_arc(at, radius, 0.0, TAU, 28, color, maxf(2.5, radius * 0.36), true)


static func water(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.WATER, true)
	var wave := Color(Palette.ON_ACCENT, 0.38)
	var width := maxf(1.5, rect.size.x * 0.04)
	for row in 2:
		var y := rect.position.y + rect.size.y * (0.38 + 0.28 * row)
		var x0 := rect.position.x + rect.size.x * (0.18 + 0.12 * row)
		var span := rect.size.x * 0.5
		var pts := PackedVector2Array()
		var steps := 10
		for step in steps + 1:
			var t := float(step) / float(steps)
			pts.append(Vector2(x0 + span * t, y + sin(t * TAU) * rect.size.y * 0.05))
		canvas.draw_polyline(pts, wave, width, true)


static func _outline(canvas: CanvasItem, poly: PackedVector2Array, radius: float) -> void:
	var closed := poly.duplicate()
	closed.append(poly[0])
	canvas.draw_polyline(closed, Palette.INK, maxf(1.5, radius * 0.14), true)


static func _gem(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var poly := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.86, -radius * 0.2),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.86, -radius * 0.2),
	])
	canvas.draw_colored_polygon(poly, color)
	canvas.draw_line(center + Vector2(-radius * 0.86, -radius * 0.2), center + Vector2(radius * 0.86, -radius * 0.2), Color(1, 1, 1, 0.55), maxf(1.0, radius * 0.1), true)
	_outline(canvas, poly, radius)


static func _spark(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var poly := PackedVector2Array([
		center + Vector2(0.3, -1.0) * radius,
		center + Vector2(-0.6, 0.12) * radius,
		center + Vector2(-0.04, 0.12) * radius,
		center + Vector2(-0.32, 1.0) * radius,
		center + Vector2(0.6, -0.18) * radius,
		center + Vector2(0.06, -0.18) * radius,
	])
	canvas.draw_colored_polygon(poly, color)
	_outline(canvas, poly, radius)


static func _magnet(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var width := maxf(4.0, radius * 0.5)
	var border := maxf(1.5, radius * 0.14)
	var arc_r := radius * 0.62
	var top := center + Vector2(0, -radius * 0.1)
	var pts := PackedVector2Array()
	var steps := 14
	for step in steps + 1:
		var angle := PI - PI * float(step) / float(steps)
		pts.append(top + Vector2(cos(angle), -sin(angle)) * arc_r)
	var left := top + Vector2(-arc_r, 0)
	var right := top + Vector2(arc_r, 0)
	var foot := radius * 0.78
	var path := PackedVector2Array([left + Vector2(0, foot)])
	path.append_array(pts)
	path.append(right + Vector2(0, foot))
	canvas.draw_polyline(path, Palette.INK, width + border * 2.0, true)
	canvas.draw_polyline(path, color, width, true)
	var tip := radius * 0.3
	for leg in [left, right]:
		var at: Vector2 = leg + Vector2(0, foot - tip)
		canvas.draw_line(at, at + Vector2(0, tip), Palette.MAGNET_TIP, width, false)


static func _crown(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var w := radius * 0.95
	var poly := PackedVector2Array([
		center + Vector2(-w, radius * 0.62),
		center + Vector2(-w, -radius * 0.55),
		center + Vector2(-w * 0.48, 0.0),
		center + Vector2(0, -radius * 0.95),
		center + Vector2(w * 0.48, 0.0),
		center + Vector2(w, -radius * 0.55),
		center + Vector2(w, radius * 0.62),
	])
	canvas.draw_colored_polygon(poly, color)
	_outline(canvas, poly, radius)
