extends Control
class_name ShapePreview

## Маленькая карта следующего поля в меню: клетки, вода и значки ресурсов.

const Palette = preload("res://scripts/palette.gd")
const BoardArt = preload("res://scripts/art.gd")

var box_size := Vector2(200, 200)
var rows: Array = []
var holes: Array = []
var resources: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = box_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if rows.is_empty() or size.x < 4.0 or size.y < 4.0:
		return
	var height := rows.size()
	var width := 0
	for line in rows:
		width = maxi(width, str(line).length())
	if width == 0 or height == 0:
		return
	var pad := 3.0
	var cell := minf((size.x - pad * 2.0) / float(width), (size.y - pad * 2.0) / float(height))
	var origin := Vector2((size.x - cell * width) * 0.5, (size.y - cell * height) * 0.5)
	for raw in holes:
		var hole: Vector2i = raw
		draw_rect(Rect2(origin + Vector2(hole.x, hole.y) * cell, Vector2(cell, cell)), Palette.WATER, true)
	for r in height:
		var line := str(rows[r])
		for c in line.length():
			if line[c] != "#":
				continue
			var rect := Rect2(origin + Vector2(c, r) * cell + Vector2(1, 1), Vector2(cell, cell) - Vector2(2, 2))
			draw_rect(rect, Palette.CREAM, true)
			var key := "%d,%d" % [r, c]
			if resources.has(key):
				BoardArt.resource(self, str(resources[key]), rect.get_center(), maxf(4.0, cell * 0.32))
