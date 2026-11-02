extends RefCounted
class_name Campaign

## Кампания без выбора поля.
## Уровни 1–3 фиксированные. Дальше тот же тип поля (пруд, крест, …),
## но размер и форма зависят от номера уровня. Номер задаёт генератор,
## поэтому повтор уровня выглядит так же.

const LevelCatalog = preload("res://scripts/levels.gd")
const GameRules = preload("res://scripts/rules.gd")
const SAVE_PATH := "user://squares.cfg"

const ARCHETYPES := ["pond", "cross", "stairs", "islands", "snake", "fort"]


static func unlocked() -> int:
	return maxi(1, int(_config().get_value("campaign", "unlocked", 1)))


static func total_points() -> int:
	return maxi(0, int(_config().get_value("campaign", "total", 0)))


static func best_score(index: int) -> int:
	return int(_config().get_value("campaign", "best_%d" % index, -1))


static func cleared_count() -> int:
	return maxi(0, unlocked() - 1)


static func level_at(index: int) -> Dictionary:
	var safe := maxi(1, index)
	var level: Dictionary = _fixed(safe) if safe <= 3 else _generate(safe)
	var built: Dictionary = LevelCatalog.build(level)
	var total := GameRules.total_points(built.cells)
	var goal := goal_for(safe, total)
	level["index"] = safe
	level["target"] = goal
	level["total"] = total
	level["ai"] = "easy" if safe <= 2 else "normal"
	level["blurb"] = "Нужно %d очков и победа." % goal
	return level


static func goal_for(index: int, total: int) -> int:
	if total <= 1:
		return 1
	var ratio := 0.58 + minf(float(index) * 0.004, 0.1)
	var need := ceili(float(total) * ratio)
	var minimum_win := int(total / 2) + 1
	need = maxi(need, minimum_win)
	return mini(need, total - 1)


static func reset() -> void:
	var config := _config()
	if config.has_section("campaign"):
		config.erase_section("campaign")
		config.save(SAVE_PATH)


static func note_clear(index: int, score: int) -> void:
	var config := _config()
	var best := int(config.get_value("campaign", "best_%d" % index, -1))
	var total := int(config.get_value("campaign", "total", 0))
	if best < 0:
		total += score
		best = score
	elif score > best:
		total += score - best
		best = score
	config.set_value("campaign", "best_%d" % index, best)
	config.set_value("campaign", "total", total)
	var frontier := int(config.get_value("campaign", "unlocked", 1))
	if index >= frontier:
		config.set_value("campaign", "unlocked", index + 1)
	config.save(SAVE_PATH)


static func _config() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	return config


static func _fixed(index: int) -> Dictionary:
	return (LevelCatalog.all()[index - 1] as Dictionary).duplicate(true)


static func _generate(index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(index) * 104729 + 17
	var tier := index - 3
	var kind: String = str(ARCHETYPES[rng.randi() % ARCHETYPES.size()])
	var made := {}
	var title := ""
	match kind:
		"pond":
			title = "Пруд"
			made = _pond(rng, tier)
		"cross":
			title = "Крест"
			made = _cross(rng, tier)
		"stairs":
			title = "Лестница"
			made = _stairs(rng, tier)
		"islands":
			title = "Острова"
			made = _islands(rng, tier)
		"snake":
			title = "Змейка"
			made = _snake(rng, tier)
		_:
			title = "Крепость"
			made = _fort(rng, tier)
	var rows: Array = made.rows
	var resources: Dictionary = made.res
	return {
		"id": "run-%d" % index,
		"name": title,
		"rows": rows,
		"res": resources,
		"archetype": kind,
	}


static func _pond(rng: RandomNumberGenerator, tier: int) -> Dictionary:
	var span := mini(8, 5 + int(tier / 3) + rng.randi_range(0, 1))
	var width := clampi(span + rng.randi_range(0, 1), 5, 8)
	var height := clampi(span + rng.randi_range(-1, 1), 5, 8)
	var inset := 2 if mini(width, height) >= 7 and rng.randf() < 0.55 else 1
	if inset * 2 >= width or inset * 2 >= height:
		inset = 1
	var rows: Array = []
	var ring: Array = []
	for r in height:
		var line := ""
		for c in width:
			var hole := r >= inset and r < height - inset and c >= inset and c < width - inset
			if hole:
				line += "."
			else:
				line += "#"
				ring.append(Vector2i(c, r))
		rows.append(line)
	return {"rows": rows, "res": _scatter(rng, ring, ["gem", "gem", "spark", "magnet", "crown"])}


static func _cross(rng: RandomNumberGenerator, tier: int) -> Dictionary:
	var size := 5
	if tier >= 4:
		size = 7
	if tier >= 9 and rng.randf() < 0.5:
		size = 9
	var arm := 3 if size >= 7 and rng.randf() < 0.5 else 1
	var mid := int(size / 2)
	var half := int(arm / 2)
	var rows: Array = []
	var cells: Array = []
	for r in size:
		var line := ""
		for c in size:
			var on_bar := absi(r - mid) <= half or absi(c - mid) <= half
			if on_bar:
				line += "#"
				cells.append(Vector2i(c, r))
			else:
				line += "."
		rows.append(line)
	var reserved := {
		Vector2i(mid, mid): "crown",
		Vector2i(mid, 0): "gem",
		Vector2i(mid, size - 1): "gem",
		Vector2i(0, mid): "gem",
		Vector2i(size - 1, mid): "gem",
	}
	var rest: Array = []
	for cell in cells:
		if not reserved.has(cell):
			rest.append(cell)
	var resources := _scatter(rng, rest, ["spark", "magnet"])
	for cell in reserved.keys():
		resources["%d,%d" % [cell.y, cell.x]] = reserved[cell]
	return {"rows": rows, "res": resources}


static func _stairs(rng: RandomNumberGenerator, tier: int) -> Dictionary:
	var steps := clampi(4 + int(tier / 5) + rng.randi_range(0, 1), 4, 6)
	var tread := rng.randi_range(3, 4)
	var width := tread + steps - 1
	var rows: Array = []
	for step in steps:
		var line := ""
		for column in width:
			line += "#" if column >= step and column < step + tread else "."
		rows.append(line)
	var mid := int(steps / 2)
	var resources := {
		"0,0": "spark",
		"0,%d" % (tread - 1): "gem",
		"%d,%d" % [mid, mid + int(tread / 2)]: "magnet",
		"%d,%d" % [steps - 1, steps - 1 + tread - 1]: "crown",
	}
	if tier >= 2:
		resources["%d,%d" % [steps - 1, steps - 1]] = "gem"
	return {"rows": rows, "res": resources}


static func _islands(rng: RandomNumberGenerator, tier: int) -> Dictionary:
	var left_w := rng.randi_range(2, 3 if tier < 4 else 4)
	var left_h := rng.randi_range(2, 3 if tier < 4 else 4)
	var right_w := rng.randi_range(2, 3 if tier < 4 else 4)
	var right_h := rng.randi_range(2, 3 if tier < 4 else 4)
	var shift := rng.randi_range(1, 2)
	var gap := 1
	var width := left_w + gap + right_w
	var height := maxi(left_h, shift + right_h)
	var rows: Array = []
	var left_cells: Array = []
	var right_cells: Array = []
	for r in height:
		var line := ""
		for c in width:
			var on_left := r < left_h and c < left_w
			var on_right := r >= shift and r < shift + right_h and c >= left_w + gap
			if on_left:
				line += "#"
				left_cells.append(Vector2i(c, r))
			elif on_right:
				line += "#"
				right_cells.append(Vector2i(c, r))
			else:
				line += "."
		rows.append(line)
	var resources := _scatter(rng, left_cells, ["gem", "spark"])
	var right_res := _scatter(rng, right_cells, ["gem", "magnet", "crown"])
	for key in right_res.keys():
		resources[key] = right_res[key]
	return {"rows": rows, "res": resources}


static func _snake(rng: RandomNumberGenerator, tier: int) -> Dictionary:
	var bands := clampi(3 + int(tier / 6), 3, 5)
	var width := clampi(3 + rng.randi_range(0, 1) + int(tier / 8), 3, 5)
	var rows: Array = []
	var cells: Array = []
	for band in bands:
		var full := ""
		for column in width:
			full += "#"
			var row_index := rows.size()
			cells.append(Vector2i(column, row_index))
		rows.append(full)
		if band == bands - 1:
			break
		var link := ""
		var joint := width - 1 if band % 2 == 0 else 0
		for column in width:
			if column == joint:
				link += "#"
				cells.append(Vector2i(column, rows.size()))
			else:
				link += "."
		rows.append(link)
	var resources := {}
	if not cells.is_empty():
		var head: Vector2i = cells[0]
		var tail: Vector2i = cells[cells.size() - 1]
		var middle: Vector2i = cells[int(cells.size() / 2)]
		resources["%d,%d" % [head.y, head.x]] = "gem"
		resources["%d,%d" % [tail.y, tail.x]] = "crown"
		if middle != head and middle != tail:
			resources["%d,%d" % [middle.y, middle.x]] = "magnet"
		var spark_at: Vector2i = cells[mini(2, cells.size() - 1)]
		var spark_key := "%d,%d" % [spark_at.y, spark_at.x]
		if not resources.has(spark_key):
			resources[spark_key] = "spark"
	return {"rows": rows, "res": resources}


static func _fort(rng: RandomNumberGenerator, tier: int) -> Dictionary:
	var size := clampi(4 + int(tier / 4) + rng.randi_range(0, 1), 4, 7)
	var rows: Array = []
	for _r in size:
		var line := ""
		for _c in size:
			line += "#"
		rows.append(line)
	var last := size - 1
	var resources := {
		"0,0": "gem",
		"0,%d" % last: "gem",
		"%d,0" % last: "gem",
		"%d,%d" % [last, last]: "gem",
		"%d,%d" % [int(size / 2), int(size / 2)]: "crown",
		"1,%d" % maxi(1, last - 1): "spark",
		"%d,1" % maxi(1, last - 1): "magnet",
	}
	return {"rows": rows, "res": resources}


static func _scatter(rng: RandomNumberGenerator, cells: Array, kinds: Array) -> Dictionary:
	var pool: Array = cells.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var resources := {}
	var count := mini(kinds.size(), pool.size())
	for i in count:
		var cell: Vector2i = pool[i]
		resources["%d,%d" % [cell.y, cell.x]] = str(kinds[i])
	return resources
