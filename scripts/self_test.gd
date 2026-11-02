extends SceneTree

const GameRules = preload("res://scripts/rules.gd")
const LevelCatalog = preload("res://scripts/levels.gd")
const SquaresAi = preload("res://scripts/ai.gd")

var fails := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog()
	_test_crown_and_basic_close()
	_test_closer_owns_the_cell()
	_test_double_close()
	_test_magnet_grabs_neighbor()
	_test_magnet_ignores_open_neighbor()
	_test_ai_takes_capture()
	_test_playouts()
	print("SELFTEST ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)


func check(condition: bool, message: String) -> void:
	if condition:
		print("ok: ", message)
	else:
		fails += 1
		print("FAIL: ", message)


func _test_catalog() -> void:
	var seen := {}
	for level in LevelCatalog.all():
		var id := str(level.id)
		check(not seen.has(id) and id != "", "уникальный id %s" % id)
		seen[id] = true
		check(str(level.name) != "" and str(level.blurb) != "", "тексты %s" % id)
		var issues: Array = LevelCatalog.problems(level)
		check(issues.is_empty(), "маска %s %s" % [id, issues])
		var state: Dictionary = LevelCatalog.build(level)
		var hashes := 0
		for line in level.rows:
			for ch in str(line):
				if ch == "#":
					hashes += 1
		check(state.cells.size() == hashes, "клетки %s: %d" % [id, state.cells.size()])
		for cell in state.cells.keys():
			for edge in GameRules.cell_edges(cell):
				var board: Dictionary = state.h if str(edge[0]) == "h" else state.v
				check(board.has(edge[1]), "грань %s" % id)


func _test_crown_and_basic_close() -> void:
	var state := LevelCatalog.build({"id": "t", "rows": ["#"], "res": {"0,0": "crown"}})
	var sparks := [0, 0, 0]
	var moves: Array = GameRules.empty_moves(state.h, state.v)
	check(moves.size() == 4, "у клетки четыре стороны")
	for index in 3:
		var edge: Array = moves[index]
		var placed: Dictionary = GameRules.place(state.h, state.v, state.cells, sparks, str(edge[0]), edge[1], 1)
		check(bool(placed.ok) and placed.claimed.is_empty(), "ранняя грань не закрывает")
	moves = GameRules.empty_moves(state.h, state.v)
	check(moves.size() == 1, "осталась одна грань")
	var last: Array = moves[0]
	var done: Dictionary = GameRules.place(state.h, state.v, state.cells, sparks, str(last[0]), last[1], 1)
	check(done.claimed.size() == 1, "четвёртая грань забирает клетку")
	check(int(GameRules.scores(state.cells)[1]) == 3, "корона стоит 3")
	check(int(sparks[1]) == 1, "корона даёт искру")
	var again: Dictionary = GameRules.place(state.h, state.v, state.cells, sparks, str(last[0]), last[1], 2)
	check(not bool(again.ok), "занятую грань нельзя поставить снова")


func _test_closer_owns_the_cell() -> void:
	var state := LevelCatalog.build({"id": "t", "rows": ["#"], "res": {}})
	var sparks := [0, 0, 0]
	var moves: Array = GameRules.empty_moves(state.h, state.v)
	for index in 3:
		var edge: Array = moves[index]
		GameRules.place(state.h, state.v, state.cells, sparks, str(edge[0]), edge[1], 2)
	var last: Array = GameRules.empty_moves(state.h, state.v)[0]
	GameRules.place(state.h, state.v, state.cells, sparks, str(last[0]), last[1], 1)
	check(int(state.cells[Vector2i(0, 0)].owner) == 1, "клетку забирает тот, кто закрыл")


func _test_double_close() -> void:
	var state := LevelCatalog.build({"id": "t", "rows": ["##"], "res": {}})
	var sparks := [0, 0, 0]
	var left := Vector2i(0, 0)
	var right := Vector2i(1, 0)
	for edge in GameRules.cell_edges(left):
		_set_edge(state, edge, 2)
	for edge in GameRules.cell_edges(right):
		_set_edge(state, edge, 2)
	var shared: Array = GameRules.cell_edges(left)[3]
	_set_edge(state, shared, 0)
	var placed: Dictionary = GameRules.place(state.h, state.v, state.cells, sparks, str(shared[0]), shared[1], 1)
	check(placed.claimed.size() == 2, "общая палочка закрывает две клетки")
	check(int(state.cells[left].owner) == 1 and int(state.cells[right].owner) == 1, "обе клетки у закрывшего")
	check(placed.edges.size() == 1, "для двойного закрытия хватает одной палочки")


func _test_magnet_grabs_neighbor() -> void:
	var state := LevelCatalog.build({"id": "t", "rows": ["##"], "res": {"0,0": "magnet"}})
	var sparks := [0, 0, 0]
	var left := Vector2i(0, 0)
	var right := Vector2i(1, 0)
	var left_edges: Array = GameRules.cell_edges(left)
	var right_edges: Array = GameRules.cell_edges(right)
	_set_edge(state, left_edges[1], 2)
	_set_edge(state, left_edges[2], 2)
	_set_edge(state, left_edges[3], 2)
	_set_edge(state, right_edges[0], 2)
	_set_edge(state, right_edges[1], 2)
	check(GameRules.edge_count(right, state.h, state.v) == 3, "соседу не хватает одной стороны")
	var placed: Dictionary = GameRules.place(state.h, state.v, state.cells, sparks, str(left_edges[0][0]), left_edges[0][1], 1)
	check(placed.claimed.size() == 2, "магнит забирает соседнюю базу")
	check(int(state.cells[left].owner) == 1 and int(state.cells[right].owner) == 1, "обе клетки алых")
	check(int(state.v[right_edges[3][1]]) == 1, "магнит сам ставит недостающую палочку")


func _test_magnet_ignores_open_neighbor() -> void:
	var state := LevelCatalog.build({"id": "t", "rows": ["##"], "res": {"0,0": "magnet"}})
	var sparks := [0, 0, 0]
	var left := Vector2i(0, 0)
	var right := Vector2i(1, 0)
	var left_edges: Array = GameRules.cell_edges(left)
	for index in [1, 2, 3]:
		_set_edge(state, left_edges[index], 1)
	var placed: Dictionary = GameRules.place(state.h, state.v, state.cells, sparks, str(left_edges[0][0]), left_edges[0][1], 1)
	check(placed.claimed.size() == 1, "открытого соседа магнит не забирает")
	check(int(state.cells[right].owner) == 0, "сосед остаётся свободным")


func _test_ai_takes_capture() -> void:
	var state := LevelCatalog.build({"id": "t", "rows": ["##"], "res": {}})
	var sparks := [0, 0, 0]
	var edges: Array = GameRules.cell_edges(Vector2i(0, 0))
	for index in 3:
		_set_edge(state, edges[index], 2)
	var choice: Dictionary = SquaresAi.choose(state.h, state.v, state.cells, sparks, 1, "normal")
	check(not choice.is_empty(), "ИИ находит ход")
	var placed: Dictionary = GameRules.place(state.h, state.v, state.cells, sparks, str(choice.kind), choice.pos, 1)
	check(not placed.claimed.is_empty(), "внимательный ИИ закрывает готовую клетку")


func _test_playouts() -> void:
	for level in LevelCatalog.all():
		for difficulty in ["normal", "easy"]:
			var problem := _playout(level, difficulty)
			check(problem == "", "партия %s/%s %s" % [level.id, difficulty, problem])


func _playout(level: Dictionary, difficulty: String) -> String:
	seed(1000 + int(hash(str(level.id) + difficulty)))
	var state := LevelCatalog.build(level)
	var sparks := [0, 0, 0]
	var player := 1
	var finished := false
	for _guard in 800:
		var moves := GameRules.empty_moves(state.h, state.v)
		if moves.is_empty():
			finished = true
			break
		var choice: Dictionary = SquaresAi.choose(state.h, state.v, state.cells, sparks, player, difficulty)
		if choice.is_empty():
			return "ИИ не нашёл ход"
		if bool(choice.use_spark) and int(sparks[player]) <= 0:
			return "искра без запаса"
		var placed: Dictionary = GameRules.place(state.h, state.v, state.cells, sparks, str(choice.kind), choice.pos, player)
		if not bool(placed.ok):
			return "нелегальная грань"
		var claimed: Array = placed.claimed
		var stayed := not claimed.is_empty()
		if claimed.is_empty() and bool(choice.use_spark) and int(sparks[player]) > 0:
			sparks[player] = int(sparks[player]) - 1
			stayed = true
		if int(sparks[player]) < 0:
			return "отрицательные искры"
		if not stayed:
			player = 3 - player
	if not finished:
		return "партия не закончилась"
	for cell in state.cells.keys():
		if int(state.cells[cell].owner) == 0:
			return "осталась свободная клетка"
	var scores := GameRules.scores(state.cells)
	if int(scores[1]) + int(scores[2]) != GameRules.total_points(state.cells):
		return "счёт %s против %s" % [scores, GameRules.total_points(state.cells)]
	return ""


func _set_edge(state: Dictionary, edge: Array, owner: int) -> void:
	if str(edge[0]) == "h":
		state.h[edge[1]] = owner
	else:
		state.v[edge[1]] = owner
