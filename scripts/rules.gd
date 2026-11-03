extends RefCounted
class_name GameRules

## Чистые правила «квадратов»: грани, захват клетки, магнит и очки.
## Состояние передаётся словарями и меняется на месте.


static func cell_edges(cell: Vector2i) -> Array:
	var c := cell.x
	var r := cell.y
	return [
		["h", Vector2i(c, r)],
		["h", Vector2i(c, r + 1)],
		["v", Vector2i(c, r)],
		["v", Vector2i(c + 1, r)],
	]


static func adjacent_cells(kind: String, pos: Vector2i) -> Array:
	if kind == "h":
		return [Vector2i(pos.x, pos.y - 1), Vector2i(pos.x, pos.y)]
	return [Vector2i(pos.x - 1, pos.y), Vector2i(pos.x, pos.y)]


static func neighbors(cell: Vector2i) -> Array:
	return [
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1),
	]


static func points(res: String) -> int:
	match res:
		"gem":
			return 2
		"crown":
			return 3
		_:
			return 1


static func resource_toast(res: String) -> String:
	match res:
		"gem":
			return "Самоцвет +2"
		"crown":
			return "Корона +3 и искра!"
		"spark":
			return "Искра в запасе!"
		"magnet":
			return "Магнит тянет соседей!"
		_:
			return ""


static func scores(cells: Dictionary) -> Array:
	var total := [0, 0, 0]
	for key in cells.keys():
		var owner := int(cells[key].owner)
		if owner > 0:
			total[owner] += points(str(cells[key].res))
	return total


static func total_points(cells: Dictionary) -> int:
	var total := 0
	for key in cells.keys():
		total += points(str(cells[key].res))
	return total


static func edge_count(cell: Vector2i, h: Dictionary, v: Dictionary) -> int:
	var count := 0
	for edge in cell_edges(cell):
		if _filled(h, v, str(edge[0]), edge[1]):
			count += 1
	return count


static func empty_moves(h: Dictionary, v: Dictionary) -> Array:
	var moves := []
	for pos in h.keys():
		if int(h[pos]) == 0:
			moves.append(["h", pos])
	for pos in v.keys():
		if int(v[pos]) == 0:
			moves.append(["v", pos])
	return moves


static func clone_state(h: Dictionary, v: Dictionary, cells: Dictionary, sparks: Array) -> Dictionary:
	var cells_copy := {}
	for key in cells.keys():
		cells_copy[key] = {
			"owner": int(cells[key].owner),
			"res": str(cells[key].res),
		}
	return {
		"h": h.duplicate(),
		"v": v.duplicate(),
		"cells": cells_copy,
		"sparks": [int(sparks[0]), int(sparks[1]), int(sparks[2])],
	}


## Ставит грань. Если клетка закрылась, она переходит игроку.
## Магнит добирает соседние клетки, у которых не хватает одной стороны.
static func place(h: Dictionary, v: Dictionary, cells: Dictionary, sparks: Array, kind: String, pos: Vector2i, player: int) -> Dictionary:
	var failed := {"ok": false, "claimed": [], "edges": [], "spark_gain": 0}
	var board := h if kind == "h" else v
	if int(board.get(pos, -1)) != 0:
		return failed
	board[pos] = player
	var edges := [[kind, pos]]
	var claimed: Array = []
	var queue: Array = []
	_claim_from_edge(h, v, cells, kind, pos, player, claimed, queue)
	var guard := 0
	while not queue.is_empty() and guard < 80:
		guard += 1
		var source: Vector2i = queue.pop_front()
		for next in neighbors(source):
			if not cells.has(next) or int(cells[next].owner) != 0:
				continue
			if edge_count(next, h, v) != 3:
				continue
			var missing := _missing(next, h, v)
			if missing.size() != 1:
				continue
			var edge: Array = missing[0]
			var edge_board: Dictionary = h if str(edge[0]) == "h" else v
			if int(edge_board.get(edge[1], -1)) != 0:
				continue
			edge_board[edge[1]] = player
			edges.append(edge)
			_claim_from_edge(h, v, cells, str(edge[0]), edge[1], player, claimed, queue)
	var gain := 0
	for cell in claimed:
		var res := str(cells[cell].res)
		if res == "spark" or res == "crown":
			gain += 1
	if gain > 0:
		sparks[player] = int(sparks[player]) + gain
	return {"ok": true, "claimed": claimed, "edges": edges, "spark_gain": gain}


static func _filled(h: Dictionary, v: Dictionary, kind: String, pos: Vector2i) -> bool:
	var board := h if kind == "h" else v
	return int(board.get(pos, -1)) > 0


static func _missing(cell: Vector2i, h: Dictionary, v: Dictionary) -> Array:
	var missing := []
	for edge in cell_edges(cell):
		if not _filled(h, v, str(edge[0]), edge[1]):
			missing.append(edge)
	return missing


static func _complete(cell: Vector2i, h: Dictionary, v: Dictionary) -> bool:
	return edge_count(cell, h, v) == 4


static func _claim_from_edge(h: Dictionary, v: Dictionary, cells: Dictionary, kind: String, pos: Vector2i, player: int, claimed: Array, queue: Array) -> void:
	for cell in adjacent_cells(kind, pos):
		if not cells.has(cell) or int(cells[cell].owner) != 0:
			continue
		if not _complete(cell, h, v):
			continue
		cells[cell].owner = player
		claimed.append(cell)
		if str(cells[cell].res) == "magnet":
			queue.append(cell)
