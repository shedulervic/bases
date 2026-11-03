extends Control
class_name BoardView

const Palette = preload("res://scripts/palette.gd")
const GameRules = preload("res://scripts/rules.gd")
const LevelCatalog = preload("res://scripts/levels.gd")
const SquaresAi = preload("res://scripts/ai.gd")
const BoardArt = preload("res://scripts/art.gd")

signal changed
signal finished(scores, winner)

const PHASE_HUMAN := 0
const PHASE_AI := 1
const PHASE_OVER := 2

var level_data: Dictionary = {}
var vs_ai := false
var ai_difficulty := "normal"
var h_edges: Dictionary = {}
var v_edges: Dictionary = {}
var cells: Dictionary = {}
var holes: Array = []
var sparks: Array = [0, 0, 0]
var current := 1
var phase := PHASE_HUMAN
var over := false
var winner := 0
var spark_armed := false
var suspended := false

var _ai_token := 0
var _last_commit := 0
var pressing := false
var press_edge = null
var hover = null
var last_edge_set: Dictionary = {}
var edge_anim: Dictionary = {}
var claim_anim: Dictionary = {}
var toasts: Array = []
var _cached_size := Vector2(-1, -1)
var _cached_metrics: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(func() -> void:
		_cached_size = Vector2(-1, -1)
	)


func load_level(level: Dictionary, mode: String, difficulty: String) -> void:
	level_data = level.duplicate(true)
	vs_ai = mode == "ai"
	ai_difficulty = "easy" if difficulty == "easy" else "normal"
	_reset()


func restart() -> void:
	if level_data.is_empty():
		return
	_reset()


func suspend() -> void:
	suspended = true
	_ai_token += 1


func resume() -> void:
	suspended = false
	if phase == PHASE_AI and not over and vs_ai and current == 2:
		_schedule_ai()


func can_toggle_spark() -> bool:
	return phase == PHASE_HUMAN and not over and not suspended and int(sparks[current]) > 0


func toggle_spark() -> void:
	if not can_toggle_spark():
		spark_armed = false
	else:
		spark_armed = not spark_armed
	changed.emit()
	queue_redraw()


func status_line() -> String:
	if level_data.is_empty():
		return ""
	if over:
		if winner == 0:
			return "Ничья"
		return "Победа · %s" % Palette.name_of(winner)
	var who := Palette.name_of(current)
	if phase == PHASE_AI:
		return "%s думает…" % who
	if spark_armed:
		return "%s · искра готова" % who
	return "Ход · %s" % who


func hint_line() -> String:
	if level_data.is_empty():
		return ""
	if over:
		return "Свободных граней не осталось."
	if spark_armed:
		return "Эта палочка не отдаст ход, даже без захвата."
	if phase == PHASE_AI:
		return "Свободных клеток: %d" % remaining()
	return "Свободных клеток: %d. Палец на грань — и отпустите." % remaining()


func mode_line() -> String:
	if level_data.is_empty():
		return ""
	if not vs_ai:
		return "Два игрока на одном экране"
	var diff := "спокойный" if ai_difficulty == "easy" else "внимательный"
	return "Против ИИ · %s · вы Алые" % diff


func remaining() -> int:
	var count := 0
	for key in cells.keys():
		if int(cells[key].owner) == 0:
			count += 1
	return count


func _reset() -> void:
	_ai_token += 1
	suspended = false
	var built: Dictionary = LevelCatalog.build(level_data)
	h_edges = built.h
	v_edges = built.v
	cells = built.cells
	holes = LevelCatalog.holes(level_data.get("rows", []))
	sparks = [0, 0, 0]
	current = 1 if randf() < 0.5 else 2
	phase = PHASE_HUMAN
	over = false
	winner = 0
	spark_armed = false
	pressing = false
	press_edge = null
	hover = null
	last_edge_set = {}
	edge_anim = {}
	claim_anim = {}
	toasts = []
	_cached_size = Vector2(-1, -1)
	if vs_ai and current == 2:
		phase = PHASE_AI
		_schedule_ai()
	changed.emit()
	queue_redraw()


func _schedule_ai() -> void:
	if suspended or get_tree() == null:
		return
	_ai_token += 1
	var token := _ai_token
	get_tree().create_timer(0.32).timeout.connect(_on_ai.bind(token))


func _on_ai(token: int) -> void:
	if token != _ai_token or suspended or over or phase != PHASE_AI:
		return
	if not vs_ai or current != 2:
		return
	var choice: Dictionary = SquaresAi.choose(h_edges, v_edges, cells, sparks, current, ai_difficulty)
	if choice.is_empty():
		_finish()
		return
	_apply(str(choice.kind), choice.pos, bool(choice.use_spark))


func _gui_input(event: InputEvent) -> void:
	if phase != PHASE_HUMAN or over or suspended:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer(event.pressed, event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		hover = _nearest(event.position)
		queue_redraw()
	elif event is InputEventScreenTouch:
		_pointer(event.pressed, event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		hover = _nearest(event.position)
		queue_redraw()
		accept_event()


func _pointer(down: bool, pos: Vector2) -> void:
	if down:
		pressing = true
		press_edge = _nearest(pos)
		hover = press_edge
		queue_redraw()
		return
	var released = _nearest(pos)
	if pressing and _edge_eq(press_edge, released):
		_commit(str(released[0]), released[1])
	pressing = false
	press_edge = null
	hover = released
	queue_redraw()


func _commit(kind: String, pos: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_commit < 80:
		return
	if phase != PHASE_HUMAN or over or suspended:
		return
	if _apply(kind, pos, spark_armed):
		_last_commit = now


func _apply(kind: String, pos: Vector2i, consume_spark: bool) -> bool:
	if over:
		return false
	var player := current
	var placed: Dictionary = GameRules.place(h_edges, v_edges, cells, sparks, kind, pos, player)
	if not bool(placed.ok):
		return false
	last_edge_set = {}
	for edge in placed.edges:
		var key := _ekey(str(edge[0]), edge[1])
		last_edge_set[key] = true
		edge_anim[key] = 0.0
	for cell in placed.claimed:
		claim_anim[cell] = 0.0
		var toast := GameRules.resource_toast(str(cells[cell].res))
		if toast != "":
			toasts.append({"cell": cell, "text": toast, "age": 0.0})
	if placed.claimed.size() >= 2:
		toasts.append({
			"cell": placed.claimed[placed.claimed.size() - 1],
			"text": "Серия ×%d!" % placed.claimed.size(),
			"age": 0.0,
		})
	var claimed: Array = placed.claimed
	var stayed := not claimed.is_empty()
	if claimed.is_empty() and consume_spark and int(sparks[player]) > 0:
		sparks[player] = int(sparks[player]) - 1
		stayed = true
	spark_armed = false
	pressing = false
	press_edge = null
	Input.vibrate_handheld(22 if not placed.claimed.is_empty() else 8)
	if not _moves_left() or _all_owned():
		_finish()
		queue_redraw()
		return true
	if not stayed:
		current = 3 - player
	if vs_ai and current == 2:
		phase = PHASE_AI
		_schedule_ai()
	else:
		phase = PHASE_HUMAN
	changed.emit()
	queue_redraw()
	return true


func _finish() -> void:
	if over:
		return
	over = true
	phase = PHASE_OVER
	_ai_token += 1
	spark_armed = false
	pressing = false
	press_edge = null
	var scores := GameRules.scores(cells)
	if scores[1] > scores[2]:
		winner = 1
	elif scores[2] > scores[1]:
		winner = 2
	else:
		winner = 0
	changed.emit()
	finished.emit(scores, winner)


func _moves_left() -> bool:
	return not GameRules.empty_moves(h_edges, v_edges).is_empty()


func _all_owned() -> bool:
	for key in cells.keys():
		if int(cells[key].owner) == 0:
			return false
	return not cells.is_empty()


func _process(delta: float) -> void:
	var busy := false
	var kept: Array = []
	for toast in toasts:
		toast.age = float(toast.age) + delta
		if float(toast.age) < 1.25:
			kept.append(toast)
			busy = true
	toasts = kept
	for key in claim_anim.keys():
		if float(claim_anim[key]) < 1.0:
			claim_anim[key] = minf(1.0, float(claim_anim[key]) + delta * 4.2)
			busy = true
	for key in edge_anim.keys():
		if float(edge_anim[key]) < 1.0:
			edge_anim[key] = minf(1.0, float(edge_anim[key]) + delta * 6.5)
			busy = true
	if busy:
		queue_redraw()


func _draw() -> void:
	var metrics := _metrics()
	if not bool(metrics.ok):
		return
	for raw_hole in holes:
		var hole: Vector2i = raw_hole
		BoardArt.water(self, Rect2(_dot(hole.x, hole.y, metrics), Vector2.ONE * _cs(metrics)))
	for cell in cells.keys():
		if int(cells[cell].owner) == 0:
			_draw_cell(cell, metrics)
	for cell in cells.keys():
		if int(cells[cell].owner) != 0:
			_draw_cell(cell, metrics)
	for kind in ["h", "v"]:
		var board: Dictionary = h_edges if kind == "h" else v_edges
		for pos in board.keys():
			_draw_owned_edge(kind, pos, int(board[pos]), metrics)
	if press_edge != null:
		_draw_preview(press_edge, Palette.color_of(current), 0.95, metrics)
	elif hover != null and phase == PHASE_HUMAN and not over:
		_draw_preview(hover, Palette.color_of(current), 0.4, metrics)
	for raw_dot in _dot_positions():
		var dot: Vector2i = raw_dot
		draw_circle(_dot(dot.x, dot.y, metrics), maxf(3.5, _cs(metrics) * 0.065), Palette.INK)
	for cell in cells.keys():
		_draw_mark_and_resource(cell, metrics)
	_draw_toasts(metrics)


func _draw_cell(cell: Vector2i, metrics: Dictionary) -> void:
	var top_left: Vector2 = _dot(cell.x, cell.y, metrics)
	var cell_px := _cs(metrics)
	var owner := int(cells[cell].owner)
	var rect := Rect2(top_left, Vector2(cell_px, cell_px))
	var fill: Color = Palette.CELL
	if owner == 0 and GameRules.edge_count(cell, h_edges, v_edges) == 3:
		fill = Palette.READY
	if owner != 0:
		var shown := clampf(float(claim_anim.get(cell, 1.0)), 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - shown, 3.0)
		fill = Palette.CELL.lerp(Palette.color_of(owner), ease)
		var shrink := (1.0 - ease) * cell_px * 0.12
		rect = Rect2(top_left + Vector2(shrink, shrink), Vector2(cell_px - shrink * 2.0, cell_px - shrink * 2.0))
	draw_rect(rect, fill, true)


func _draw_owned_edge(kind: String, pos: Vector2i, owner: int, metrics: Dictionary) -> void:
	var segment := _segment(kind, pos, metrics)
	if owner == 0:
		var dash := maxf(4.0, _cs(metrics) * 0.11)
		draw_dashed_line(segment[0], segment[1], Color(Palette.INK, 0.7), maxf(3.0, _cs(metrics) * 0.05), dash)
		return
	var key := _ekey(kind, pos)
	var shown := clampf(float(edge_anim.get(key, 1.0)), 0.0, 1.0)
	var color := Palette.INK
	var width := maxf(4.0, _cs(metrics) * 0.09)
	if last_edge_set.has(key):
		color = Palette.color_of(owner)
		width *= 1.15
	color.a = shown
	draw_line(segment[0], segment[1], color, width, true)


func _draw_preview(edge: Array, color: Color, alpha: float, metrics: Dictionary) -> void:
	var segment := _segment(str(edge[0]), edge[1], metrics)
	var glow := color
	glow.a = alpha * 0.35
	draw_line(segment[0], segment[1], glow, maxf(8.0, _cs(metrics) * 0.18), true)
	var solid := color
	solid.a = alpha
	draw_line(segment[0], segment[1], solid, maxf(3.0, _cs(metrics) * 0.08), true)


func _draw_mark_and_resource(cell: Vector2i, metrics: Dictionary) -> void:
	var info: Dictionary = cells[cell]
	var owner := int(info.owner)
	var res := str(info.res)
	var cell_px := _cs(metrics)
	var top_left: Vector2 = _dot(cell.x, cell.y, metrics)
	var center := top_left + Vector2(cell_px, cell_px) * 0.5
	var shown := 1.0
	if owner != 0:
		shown = 1.0 - pow(1.0 - clampf(float(claim_anim.get(cell, 1.0)), 0.0, 1.0), 3.0)
	var icon_at := center
	var radius := maxf(6.0, cell_px * 0.22)
	if owner != 0 and shown > 0.45:
		var at := center
		var mark_r := cell_px * 0.2
		if res != "":
			at = top_left + Vector2(cell_px * 0.23, cell_px * 0.23)
			mark_r = cell_px * 0.12
			icon_at = top_left + Vector2(cell_px * 0.6, cell_px * 0.6)
			radius = maxf(6.0, cell_px * 0.19)
		var mark := Color(Palette.INK, 0.85)
		if owner == 1:
			BoardArt.cross(self, at, mark_r, mark)
		else:
			BoardArt.ring(self, at, mark_r, mark)
	if res == "":
		return
	var chip := Color(1, 1, 1, 0.55) if owner == 0 else Color(Palette.CELL, 0.9)
	draw_circle(icon_at, radius * 1.4, chip)
	BoardArt.resource(self, res, icon_at, radius)


func _draw_toasts(metrics: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var cell_px := _cs(metrics)
	var font_size := int(clamp(cell_px * 0.32, 24.0, 32.0))
	for index in toasts.size():
		var toast: Dictionary = toasts[index]
		var alpha := clampf(1.0 - float(toast.age) / 1.2, 0.0, 1.0)
		var spot: Vector2i = toast.cell
		var center := _dot(spot.x, spot.y, metrics)
		center += Vector2(cell_px * 0.5, cell_px * 0.22)
		center.y -= float(toast.age) * 16.0 + float(index) * (font_size + 12.0)
		var text := str(toast.text)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box := Rect2(center.x - text_size.x * 0.5 - 8.0, center.y - font.get_ascent(font_size) - 4.0, text_size.x + 16.0, text_size.y + 8.0)
		draw_rect(box, Color(0, 0, 0, 0.58 * alpha), true)
		draw_string(font, Vector2(box.position.x + 8.0, box.position.y + 4.0 + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(Palette.ON_ACCENT, alpha))


func _metrics() -> Dictionary:
	if _cached_size == size and not _cached_metrics.is_empty():
		return _cached_metrics
	if cells.is_empty() or size.x < 32.0 or size.y < 32.0:
		return {"ok": false}
	var min_c: int = 999
	var min_r: int = 999
	var max_c: int = -999
	var max_r: int = -999
	for raw in cells.keys():
		var cell: Vector2i = raw
		min_c = mini(min_c, cell.x)
		min_r = mini(min_r, cell.y)
		max_c = maxi(max_c, cell.x)
		max_r = maxi(max_r, cell.y)
	var span_c: int = max_c - min_c + 1
	var span_r: int = max_r - min_r + 1
	var pad := 8.0
	var avail := Vector2(maxf(8.0, size.x - pad * 2.0), maxf(8.0, size.y - pad * 2.0))
	var cell_size: float = floorf(minf(avail.x / float(span_c), avail.y / float(span_r)))
	cell_size = maxf(cell_size, 8.0)
	var board_size := Vector2(float(span_c), float(span_r)) * cell_size
	var origin := (size - board_size) * 0.5
	var slop: float = minf(maxf(cell_size * 0.4, minf(22.0, cell_size * 0.48)), cell_size * 0.48)
	var metrics := {
		"ok": true,
		"origin": origin,
		"cs": cell_size,
		"min_c": min_c,
		"min_r": min_r,
		"slop": slop,
	}
	_cached_size = size
	_cached_metrics = metrics
	return metrics


func _cs(metrics: Dictionary) -> float:
	return float(metrics.cs)


func _dot(column: int, row: int, metrics: Dictionary) -> Vector2:
	var origin: Vector2 = metrics.origin
	return origin + Vector2(column - int(metrics.min_c), row - int(metrics.min_r)) * _cs(metrics)


func _segment(kind: String, pos: Vector2i, metrics: Dictionary) -> PackedVector2Array:
	if kind == "h":
		return PackedVector2Array([_dot(pos.x, pos.y, metrics), _dot(pos.x + 1, pos.y, metrics)])
	return PackedVector2Array([_dot(pos.x, pos.y, metrics), _dot(pos.x, pos.y + 1, metrics)])


func _nearest(local_pos: Vector2):
	var metrics := _metrics()
	if not bool(metrics.get("ok", false)):
		return null
	var best = null
	var best_distance := float(metrics.slop)
	for kind in ["h", "v"]:
		var board: Dictionary = h_edges if kind == "h" else v_edges
		for pos in board.keys():
			if int(board[pos]) != 0:
				continue
			var segment := _segment(kind, pos, metrics)
			var distance := _distance_to_segment(local_pos, segment[0], segment[1])
			if distance <= best_distance:
				best_distance = distance
				best = [kind, pos]
	return best


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var span := finish - start
	var length_sq := span.length_squared()
	if length_sq < 0.001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(span) / length_sq, 0.0, 1.0)
	return point.distance_to(start + span * t)


func _dot_positions() -> Array:
	var seen := {}
	var dots: Array = []
	for pos in h_edges.keys():
		_remember_dot(seen, dots, Vector2i(pos.x, pos.y))
		_remember_dot(seen, dots, Vector2i(pos.x + 1, pos.y))
	for pos in v_edges.keys():
		_remember_dot(seen, dots, Vector2i(pos.x, pos.y))
		_remember_dot(seen, dots, Vector2i(pos.x, pos.y + 1))
	return dots


func _remember_dot(seen: Dictionary, dots: Array, dot: Vector2i) -> void:
	var key := "%d:%d" % [dot.x, dot.y]
	if seen.has(key):
		return
	seen[key] = true
	dots.append(dot)


func _edge_eq(left, right) -> bool:
	if left == null or right == null:
		return false
	return str(left[0]) == str(right[0]) and left[1] == right[1]


func _ekey(kind: String, pos: Vector2i) -> String:
	return "%s:%d:%d" % [kind, pos.x, pos.y]
