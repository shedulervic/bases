extends RefCounted
class_name SquaresAi

const GameRules = preload("res://scripts/rules.gd")


## Возвращает {kind, pos, use_spark} или пустой словарь, если ходов нет.
static func choose(h: Dictionary, v: Dictionary, cells: Dictionary, sparks: Array, player: int, difficulty: String) -> Dictionary:
	var moves := GameRules.empty_moves(h, v)
	if moves.is_empty():
		return {}
	var easy := difficulty == "easy"
	if easy and randf() < 0.4:
		return _pack(moves[randi() % moves.size()], false)

	var score_before := int(GameRules.scores(cells)[player])
	var captures: Array = []
	var quiet: Array = []
	for move in moves:
		var state := GameRules.clone_state(h, v, cells, sparks)
		var placed: Dictionary = GameRules.place(state.h, state.v, state.cells, state.sparks, str(move[0]), move[1], player)
		var gained := int(GameRules.scores(state.cells)[player]) - score_before
		var gifts: Array = []
		if placed.claimed.is_empty():
			for cell in state.cells.keys():
				if int(state.cells[cell].owner) == 0 and GameRules.edge_count(cell, state.h, state.v) == 3:
					gifts.append(GameRules.points(str(state.cells[cell].res)))
		var bias := 0.0
		for cell in GameRules.adjacent_cells(str(move[0]), move[1]):
			if state.cells.has(cell) and int(state.cells[cell].owner) == 0:
				bias += float(GameRules.points(str(state.cells[cell].res)))
				bias += 0.25 * float(GameRules.edge_count(cell, state.h, state.v))
		var record := {
			"move": move,
			"eval": float(gained) + float(placed.spark_gain) * 2.0,
			"gifts": gifts,
			"bias": bias,
		}
		if placed.claimed.is_empty():
			quiet.append(record)
		else:
			captures.append(record)

	if not captures.is_empty() and not (easy and randf() < 0.28):
		return _pack(_best_capture(captures).move, false)

	var safe: Array = []
	for record in quiet:
		if record.gifts.is_empty():
			safe.append(record)
	if not safe.is_empty():
		return _pack(_best_safe(safe).move, false)

	if not easy and int(sparks[player]) > 0 and not quiet.is_empty():
		return _pack(_best_spark(quiet).move, true)

	if quiet.is_empty():
		return _pack(moves[randi() % moves.size()], false)
	return _pack(_smallest_gift(quiet).move, false)


static func _pack(move: Array, use_spark: bool) -> Dictionary:
	return {"kind": str(move[0]), "pos": move[1], "use_spark": use_spark}


static func _best_capture(records: Array) -> Dictionary:
	var best: Array = []
	var best_eval := -9999.0
	for record in records:
		var value := float(record.eval)
		if value > best_eval + 0.001:
			best_eval = value
			best = [record]
		elif absf(value - best_eval) <= 0.001:
			best.append(record)
	return best[randi() % best.size()]


static func _best_safe(records: Array) -> Dictionary:
	var best: Array = []
	var best_bias := -9999.0
	for record in records:
		var value := float(record.bias) + randf() * 0.35
		if value > best_bias + 0.001:
			best_bias = value
			best = [record]
		elif absf(value - best_bias) <= 0.35:
			best.append(record)
	return best[randi() % best.size()]


static func _best_spark(records: Array) -> Dictionary:
	var best: Dictionary = records[0]
	var best_key := -9999
	for record in records:
		var gifts: Array = record.gifts
		var keep := 0
		var leftover := 0
		if not gifts.is_empty():
			keep = int(gifts[0])
			var sum := 0
			for gift in gifts:
				keep = maxi(keep, int(gift))
				sum += int(gift)
			leftover = sum - keep
		var key := keep * 10 - leftover
		if key > best_key:
			best_key = key
			best = record
	return best


static func _smallest_gift(records: Array) -> Dictionary:
	var best: Dictionary = records[0]
	var best_sum := 9999
	for record in records:
		var sum := 0
		for gift in record.gifts:
			sum += int(gift)
		if sum < best_sum:
			best_sum = sum
			best = record
	return best
