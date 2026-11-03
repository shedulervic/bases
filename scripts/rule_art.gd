extends Control
class_name RuleArt

## Картинка к одному правилу: stick, close, hole, marks или ресурс.

const Palette = preload("res://scripts/palette.gd")
const BoardArt = preload("res://scripts/art.gd")

var kind := "stick"
var box := 132.0


func _ready() -> void:
	custom_minimum_size = Vector2(maxf(custom_minimum_size.x, box), box)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var origin := (size - Vector2(s, s)) * 0.5
	match kind:
		"stick":
			_stick(origin, s)
		"close":
			_close(origin, s)
		"hole":
			_hole(origin, s)
		"marks":
			_marks(origin, s)
		_:
			_resource(origin, s)


func _stick(origin: Vector2, s: float) -> void:
	var cell := s * 0.62
	var tl := origin + Vector2(s - cell, s - cell) * 0.5
	draw_rect(Rect2(tl, Vector2(cell, cell)), Palette.CELL, true)
	var tr := tl + Vector2(cell, 0)
	var bl := tl + Vector2(0, cell)
	var br := tl + Vector2(cell, cell)
	_solid(tl, tr, cell)
	_solid(tl, bl, cell)
	_dashed(tr, br, cell)
	draw_line(bl, br, Color(Palette.P1, 0.35), cell * 0.2, true)
	draw_line(bl, br, Palette.P1, cell * 0.09, true)
	_dots([tl, tr, bl, br], cell)


func _close(origin: Vector2, s: float) -> void:
	var cell := s * 0.62
	var tl := origin + Vector2(s - cell, s - cell) * 0.5
	draw_rect(Rect2(tl, Vector2(cell, cell)), Palette.P1, true)
	var tr := tl + Vector2(cell, 0)
	var bl := tl + Vector2(0, cell)
	var br := tl + Vector2(cell, cell)
	_solid(tl, tr, cell)
	_solid(tl, bl, cell)
	_solid(bl, br, cell)
	draw_line(tr, br, Palette.P1_DARK, cell * 0.11, true)
	BoardArt.cross(self, tl + Vector2(cell, cell) * 0.5, cell * 0.2, Color(Palette.INK, 0.85))
	_dots([tl, tr, bl, br], cell)


func _hole(origin: Vector2, s: float) -> void:
	var cell := s / 3.2
	var tl := origin + Vector2(s - cell * 3.0, s - cell * 3.0) * 0.5
	var dots: Array = []
	for r in 3:
		for c in 3:
			var rect := Rect2(tl + Vector2(c, r) * cell, Vector2(cell, cell))
			if r == 1 and c == 1:
				BoardArt.water(self, rect)
			else:
				draw_rect(rect, Palette.CELL, true)
	for line in 4:
		var x := tl + Vector2(line * cell, 0)
		var y := tl + Vector2(0, line * cell)
		_dashed(x, x + Vector2(0, cell * 3.0), cell)
		_dashed(y, y + Vector2(cell * 3.0, 0), cell)
	for r in 4:
		for c in 4:
			dots.append(tl + Vector2(c, r) * cell)
	_dots(dots, cell)


func _marks(origin: Vector2, s: float) -> void:
	var cell := s * 0.46
	var tl := origin + Vector2(s - cell * 2.0, s - cell) * 0.5
	draw_rect(Rect2(tl, Vector2(cell, cell)), Palette.P1, true)
	draw_rect(Rect2(tl + Vector2(cell, 0), Vector2(cell, cell)), Palette.P2, true)
	var ink := Color(Palette.INK, 0.85)
	BoardArt.cross(self, tl + Vector2(cell, cell) * 0.5, cell * 0.2, ink)
	BoardArt.ring(self, tl + Vector2(cell * 1.5, cell * 0.5), cell * 0.2, ink)
	var dots: Array = []
	for r in 2:
		for c in 3:
			dots.append(tl + Vector2(c, r) * cell)
	_dots(dots, cell)


func _resource(origin: Vector2, s: float) -> void:
	var cell := s * 0.7
	var tl := origin + Vector2(s - cell, s - cell) * 0.5
	draw_rect(Rect2(tl, Vector2(cell, cell)), Palette.CELL, true)
	var center := tl + Vector2(cell, cell) * 0.5
	var radius := cell * 0.3
	draw_circle(center, radius * 1.4, Color(1, 1, 1, 0.55))
	BoardArt.resource(self, kind, center, radius)


func _solid(a: Vector2, b: Vector2, cell: float) -> void:
	draw_line(a, b, Palette.INK, cell * 0.09, true)


func _dashed(a: Vector2, b: Vector2, cell: float) -> void:
	draw_dashed_line(a, b, Color(Palette.INK, 0.7), cell * 0.05, cell * 0.11)


func _dots(points: Array, cell: float) -> void:
	for point in points:
		draw_circle(point, maxf(3.5, cell * 0.065), Palette.INK)
