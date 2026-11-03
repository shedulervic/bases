extends RefCounted
class_name LevelCatalog

## Поля игры.
## rows: "#" — клетка, "." — дыра. Все строки одной длины.
## res: ключ "ряд,столбец" → gem | spark | magnet | crown.

const GameRules = preload("res://scripts/rules.gd")


static func all() -> Array:
	var built := []
	for level in _raw():
		built.append(level.duplicate(true))
	return built


static func problems(level: Dictionary) -> Array:
	var issues: Array = []
	var rows: Array = level.get("rows", [])
	if rows.is_empty():
		issues.append("нет строк")
		return issues
	var width := -1
	var hashes := 0
	for r in rows.size():
		var line := str(rows[r])
		if width < 0:
			width = line.length()
		elif line.length() != width:
			issues.append("разная длина строк")
		if line.is_empty():
			issues.append("пустая строка")
		for c in line.length():
			var ch := line[c]
			if ch == "#":
				hashes += 1
			elif ch != ".":
				issues.append("плохой символ")
	if hashes == 0:
		issues.append("нет клеток")
	var resources: Dictionary = level.get("res", {})
	for key in resources.keys():
		var parts := str(key).split(",")
		if parts.size() != 2:
			issues.append("плохой ключ %s" % key)
			continue
		var row := int(parts[0])
		var col := int(parts[1])
		if row < 0 or row >= rows.size() or col < 0 or col >= str(rows[row]).length() or str(rows[row])[col] != "#":
			issues.append("ресурс вне клетки %s" % key)
		var kind := str(resources[key])
		if not (kind in ["gem", "spark", "magnet", "crown"]):
			issues.append("неизвестный ресурс %s" % kind)
	return issues


## Дыры, которые рисуются водой: пустые места, зажатые клетками
## по ряду или по столбцу. Пустые углы креста и лестницы сюда не входят.
static func holes(rows: Array) -> Array:
	var found: Array = []
	var height := rows.size()
	for r in height:
		var line := str(rows[r])
		for c in line.length():
			if line[c] == "#":
				continue
			var in_row := line.substr(0, c).contains("#") and line.substr(c + 1).contains("#")
			var above := false
			var below := false
			for other in height:
				var other_line := str(rows[other])
				if c >= other_line.length() or other_line[c] != "#":
					continue
				if other < r:
					above = true
				elif other > r:
					below = true
			if in_row or (above and below):
				found.append(Vector2i(c, r))
	return found


static func build(level: Dictionary) -> Dictionary:
	var issues: Array = problems(level)
	if not issues.is_empty():
		push_error("Поле %s: %s" % [str(level.get("id", "?")), ", ".join(PackedStringArray(issues))])
	var cells := {}
	var resources: Dictionary = level.get("res", {})
	var rows: Array = level.rows
	for r in rows.size():
		var line := str(rows[r])
		for c in line.length():
			if line[c] != "#":
				continue
			var key := "%d,%d" % [r, c]
			var res_name := str(resources[key]) if resources.has(key) else ""
			cells[Vector2i(c, r)] = {"owner": 0, "res": res_name}
	var horizontal := {}
	var vertical := {}
	for cell in cells.keys():
		for edge in GameRules.cell_edges(cell):
			if str(edge[0]) == "h":
				horizontal[edge[1]] = 0
			else:
				vertical[edge[1]] = 0
	return {"h": horizontal, "v": vertical, "cells": cells}


static func _raw() -> Array:
	return [
		{
			"id": "gate",
			"name": "Калитка",
			"blurb": "Поле 2×2 без дыр. Удобно вспомнить правила.",
			"rows": ["##", "##"],
			"res": {},
		},
		{
			"id": "yard",
			"name": "Двор",
			"blurb": "Квадрат 3×3. В середине самоцвет на 2 очка.",
			"rows": ["###", "###", "###"],
			"res": {"1,1": "gem"},
		},
		{
			"id": "square",
			"name": "Площадь",
			"blurb": "Угловые самоцветы, искра и магнит.",
			"rows": ["####", "####", "####", "####"],
			"res": {
				"0,0": "gem",
				"0,3": "gem",
				"3,0": "gem",
				"3,3": "gem",
				"1,1": "spark",
				"2,2": "magnet",
			},
		},
		{
			"id": "pond",
			"name": "Пруд",
			"blurb": "Кольцо клеток вокруг большой дыры.",
			"rows": [
				"######",
				"##..##",
				"#....#",
				"#....#",
				"##..##",
				"######",
			],
			"res": {
				"0,2": "gem",
				"0,3": "gem",
				"2,0": "magnet",
				"3,5": "spark",
				"5,2": "crown",
			},
		},
		{
			"id": "cross",
			"name": "Крест",
			"blurb": "Рукава сходятся к короне в центре.",
			"rows": [
				"..###..",
				"..###..",
				"#######",
				"#######",
				"#######",
				"..###..",
				"..###..",
			],
			"res": {
				"0,3": "gem",
				"3,0": "gem",
				"3,6": "gem",
				"6,3": "gem",
				"2,2": "spark",
				"3,3": "crown",
				"4,4": "magnet",
			},
		},
		{
			"id": "stairs",
			"name": "Лестница",
			"blurb": "Ступени, по которым уходит длинная база.",
			"rows": [
				"####...",
				".###...",
				"..###..",
				"...###.",
				"....###",
			],
			"res": {
				"0,0": "spark",
				"0,3": "gem",
				"2,3": "magnet",
				"4,4": "gem",
				"4,6": "crown",
			},
		},
		{
			"id": "islands",
			"name": "Острова",
			"blurb": "Две отдельные базы. Между ними ходить нельзя.",
			"rows": [
				"###....",
				"###....",
				"##.....",
				".......",
				".....##",
				"....###",
				"....###",
			],
			"res": {
				"0,1": "gem",
				"2,0": "spark",
				"4,5": "magnet",
				"5,6": "crown",
				"6,4": "gem",
			},
		},
		{
			"id": "snake",
			"name": "Змейка",
			"blurb": "Узкий коридор с тремя поворотами.",
			"rows": [
				"#####.",
				"....#.",
				".#####",
				".#....",
				".#####",
			],
			"res": {
				"0,0": "gem",
				"0,4": "spark",
				"2,3": "magnet",
				"4,1": "gem",
				"4,5": "crown",
			},
		},
		{
			"id": "fort",
			"name": "Крепость",
			"blurb": "Плотное поле 5×5 и самые дорогие клетки.",
			"rows": ["#####", "#####", "#####", "#####", "#####"],
			"res": {
				"0,0": "gem",
				"0,4": "gem",
				"4,0": "gem",
				"4,4": "gem",
				"1,3": "spark",
				"2,2": "crown",
				"3,1": "magnet",
			},
		},
	]
