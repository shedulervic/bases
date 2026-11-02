extends Control

const Palette = preload("res://scripts/palette.gd")
const Campaign = preload("res://scripts/campaign.gd")
const BoardView = preload("res://scripts/board.gd")
const GameRules = preload("res://scripts/rules.gd")

var _screen := "menu"
var board: BoardView
var menu_screen: Control
var rules_screen: Control
var game_screen: Control
var pending_level: Dictionary = {}
var menu_preview: ShapePreview
var stat_level: Label
var stat_points: Label
var stat_goal: Label
var reset_button: Button
var reset_dialog: Control
var level_title: Label
var mode_label: Label
var status_label: Label
var hint_label: Label
var p1_panel: PanelContainer
var p2_panel: PanelContainer
var p1_score: Label
var p2_score: Label
var p1_meta: Label
var p2_meta: Label
var spark_button: Button
var overlay: Control
var overlay_next: Button
var overlay_title: Label
var overlay_sub: Label
var overlay_s1: Label
var overlay_s2: Label
var rules_label: Label
var rules_scroll: ScrollContainer
var _back_at := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_theme()
	_build()
	_show("menu")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if _screen == "game":
			_restart()
			get_viewport().set_input_as_handled()


func _apply_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", Palette.CREAM)
	theme.set_color("font_color", "Button", Palette.CREAM)
	theme.set_color("font_disabled_color", "Button", Palette.MUTED)
	theme.set_font_size("font_size", "Button", 22)
	theme.set_stylebox("normal", "Button", _flat(Palette.BUTTON, 16))
	theme.set_stylebox("hover", "Button", _flat(Palette.BUTTON_HOVER, 16))
	theme.set_stylebox("pressed", "Button", _flat(Palette.BUTTON_DOWN, 16))
	theme.set_stylebox("disabled", "Button", _flat(Color8(24, 36, 44), 16))
	theme.set_stylebox("focus", "Button", _flat(Palette.BUTTON, 16, Palette.MUTED, 2))
	self.theme = theme


func _build() -> void:
	var background := ColorRect.new()
	background.color = Palette.BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var top := 36 if OS.has_feature("mobile") else 24
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var host := Control.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(host)

	menu_screen = _build_menu()
	rules_screen = _build_rules()
	game_screen = _build_game()
	for screen in [menu_screen, rules_screen, game_screen]:
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.add_child(screen)


func _build_menu() -> Control:
	var root := Control.new()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)

	box.add_child(_spacer())
	box.add_child(_label("Квадраты", 52, Palette.CREAM, true))
	box.add_child(_label("Каждый следующий уровень — после победы", 18, Palette.CREAM_DIM, true))

	menu_preview = ShapePreview.new()
	menu_preview.box_size = Vector2(150, 150)
	menu_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(menu_preview)

	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", _flat(Palette.PANEL, 16))
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 2)
	stats.add_child(stats_box)
	stat_level = _label("Уровень 1", 22, Palette.CREAM, true)
	stat_points = _label("Очки: 0", 28, Palette.GOLD, true)
	stat_goal = _label("", 16, Palette.CREAM_DIM, true)
	stat_goal.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_box.add_child(stat_level)
	stats_box.add_child(stat_points)
	stats_box.add_child(stat_goal)
	box.add_child(stats)

	var play := _button("Играть")
	_paint_button(play, Palette.P1, Palette.CREAM)
	play.pressed.connect(_play_current)
	box.add_child(play)

	var rules := _button("Как играть")
	rules.pressed.connect(func() -> void: _show("rules"))
	box.add_child(rules)

	reset_button = _button("Сбросить прогресс")
	reset_button.pressed.connect(func() -> void: reset_dialog.visible = true)
	box.add_child(reset_button)

	box.add_child(_spacer())
	box.add_child(_label("После третьего уровня форма поля меняется, условия остаются", 16, Palette.MUTED, true))

	reset_dialog = _build_reset_dialog()
	root.add_child(reset_dialog)
	return root


func _build_reset_dialog() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dim.visible = false
	)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_stylebox_override("panel", _flat(Palette.PANEL, 20))
	center.add_child(panel)
	var dialog := VBoxContainer.new()
	dialog.add_theme_constant_override("separation", 10)
	panel.add_child(dialog)
	var title := _label("Сбросить прогресс?", 26, Palette.CREAM, true)
	var body := _label("Очки и открытые уровни пропадут. Кампания начнётся с Калитки.", 16, Palette.CREAM_DIM, true)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialog.add_child(title)
	dialog.add_child(body)
	var confirm := _button("Сбросить")
	_paint_button(confirm, Palette.P1, Palette.CREAM)
	confirm.pressed.connect(_confirm_reset)
	dialog.add_child(confirm)
	var cancel := _button("Отмена")
	cancel.pressed.connect(func() -> void: dim.visible = false)
	dialog.add_child(cancel)
	return dim


func _confirm_reset() -> void:
	Campaign.reset()
	reset_dialog.visible = false
	_refresh_menu()


func _build_rules() -> Control:
	var root := Control.new()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	box.add_child(_label("Как играть", 36, Palette.CREAM, true))

	rules_scroll = ScrollContainer.new()
	rules_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(rules_scroll)

	rules_label = _label(_rules_text(), 20, Palette.CREAM_DIM, false)
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	rules_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_scroll.add_child(rules_label)
	rules_scroll.resized.connect(func() -> void:
		rules_label.custom_minimum_size.x = maxf(120.0, rules_scroll.size.x - 8.0)
	)

	var back := _button("Назад")
	back.pressed.connect(func() -> void: _show("menu"))
	box.add_child(back)
	return root


func _build_game() -> Control:
	var root := Control.new()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)

	level_title = _label("Поле", 28, Palette.CREAM, true)
	mode_label = _label("", 15, Palette.MUTED, true)
	box.add_child(level_title)
	box.add_child(mode_label)

	var scores := HBoxContainer.new()
	scores.add_theme_constant_override("separation", 10)
	box.add_child(scores)
	var p1 := _score_card(1)
	var p2 := _score_card(2)
	p1_panel = p1.panel
	p2_panel = p2.panel
	p1_score = p1.score
	p2_score = p2.score
	p1_meta = p1.meta
	p2_meta = p2.meta
	scores.add_child(p1_panel)
	scores.add_child(p2_panel)

	status_label = _label("Ход", 22, Palette.CREAM, true)
	hint_label = _label("", 15, Palette.MUTED, true)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(status_label)
	box.add_child(hint_label)

	board = BoardView.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(220, 280)
	board.changed.connect(_refresh_hud)
	board.finished.connect(_on_finished)
	box.add_child(board)

	spark_button = _button("Искра")
	spark_button.pressed.connect(func() -> void: board.toggle_spark())
	box.add_child(spark_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	var again := _button("Заново")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(_restart)
	actions.add_child(again)
	var leave := _button("В меню")
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void: _show("menu"))
	actions.add_child(leave)

	overlay = ColorRect.new()
	overlay.color = Color(20 / 255.0, 32 / 255.0, 40 / 255.0, 0.78)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_stylebox_override("panel", _flat(Palette.PANEL, 20))
	center.add_child(panel)
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", 8)
	panel.add_child(result)
	overlay_title = _label("Партия", 32, Palette.CREAM, true)
	overlay_sub = _label("", 16, Palette.CREAM_DIM, true)
	overlay_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	result.add_child(overlay_title)
	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 12)
	result.add_child(score_row)
	overlay_s1 = _label("0", 48, Palette.P1, true)
	overlay_s2 = _label("0", 48, Palette.P2, true)
	score_row.add_child(overlay_s1)
	score_row.add_child(_label(":", 40, Palette.CREAM, true))
	score_row.add_child(overlay_s2)
	result.add_child(overlay_sub)
	overlay_next = _button("Дальше")
	_paint_button(overlay_next, Palette.P1, Palette.CREAM)
	overlay_next.visible = false
	overlay_next.pressed.connect(_play_current)
	result.add_child(overlay_next)
	var rematch := _button("Ещё раз")
	rematch.pressed.connect(_restart)
	result.add_child(rematch)
	var fields := _button("В меню")
	fields.pressed.connect(func() -> void:
		overlay.visible = false
		_show("menu")
	)
	result.add_child(fields)
	return root


func _score_card(player: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)
	var mark := PlayerMark.new()
	mark.player = player
	mark.mark_color = Palette.color_of(player)
	title_row.add_child(mark)
	title_row.add_child(_label(Palette.name_of(player), 16, Palette.CREAM_DIM, false))
	var score := _label("0", 40, Palette.color_of(player), true)
	var meta := _label("очки", 14, Palette.MUTED, true)
	box.add_child(score)
	box.add_child(meta)
	return {"panel": panel, "score": score, "meta": meta}


func _play_current() -> void:
	pending_level = Campaign.level_at(Campaign.unlocked())
	overlay.visible = false
	overlay_next.visible = false
	_show("game")
	board.load_level(pending_level, "ai", str(pending_level.get("ai", "normal")))
	_refresh_hud()


func _refresh_menu() -> void:
	var level: Dictionary = Campaign.level_at(Campaign.unlocked())
	var index := int(level.index)
	stat_level.text = "Уровень %d · %s" % [index, str(level.name)]
	stat_points.text = "Очки: %d    Пройдено: %d" % [Campaign.total_points(), Campaign.cleared_count()]
	var goal_line := "Цель: %d очков и победа" % int(level.target)
	var best := Campaign.best_score(index)
	if best >= 0:
		goal_line += "\nЛучший результат этого уровня: %d" % best
	stat_goal.text = goal_line
	reset_button.disabled = Campaign.cleared_count() == 0 and Campaign.total_points() == 0
	menu_preview.rows = level.rows
	menu_preview.marks = _mark_colors(level)
	menu_preview.queue_redraw()


func _restart() -> void:
	overlay.visible = false
	board.restart()
	_refresh_hud()


func _show(screen: String) -> void:
	_screen = screen
	menu_screen.visible = screen == "menu"
	rules_screen.visible = screen == "rules"
	game_screen.visible = screen == "game"
	if screen == "menu":
		_refresh_menu()
	if screen == "game":
		board.resume()
	else:
		board.suspend()


func _back() -> void:
	var now := Time.get_ticks_msec()
	if now - _back_at < 200:
		return
	_back_at = now
	if _screen == "game":
		if overlay.visible:
			overlay.visible = false
			return
		_show("menu")
	elif _screen == "rules":
		_show("menu")
	elif _screen == "menu" and reset_dialog.visible:
		reset_dialog.visible = false
	elif _screen == "menu" and OS.has_feature("mobile"):
		get_tree().quit()


func _refresh_hud() -> void:
	if board.level_data.is_empty():
		return
	var index := int(board.level_data.get("index", 1))
	var target := int(board.level_data.get("target", 0))
	level_title.text = "Уровень %d · %s" % [index, str(board.level_data.get("name", ""))]
	mode_label.text = "Цель: %d очков и победа" % target
	status_label.text = board.status_line()
	hint_label.text = board.hint_line()
	status_label.add_theme_color_override("font_color", Palette.color_of(board.current) if not board.over else Palette.CREAM)
	var scores := GameRules.scores(board.cells)
	p1_score.text = str(scores[1])
	p2_score.text = str(scores[2])
	p1_meta.text = _spark_meta(1)
	p2_meta.text = _spark_meta(2)
	var active := 0 if board.over else board.current
	p1_panel.add_theme_stylebox_override("panel", _score_style(1, active))
	p2_panel.add_theme_stylebox_override("panel", _score_style(2, active))
	_refresh_spark_button()


func _spark_meta(player: int) -> String:
	var count := int(board.sparks[player])
	if count <= 0:
		return "очки"
	return "очки · искра ×%d" % count


func _refresh_spark_button() -> void:
	var count := int(board.sparks[board.current]) if not board.over else 0
	if board.spark_armed:
		spark_button.text = "Искра готова"
		_paint_button(spark_button, Palette.GOLD, Palette.INK)
	elif board.can_toggle_spark():
		spark_button.text = "Искра ×%d" % count
		_paint_button(spark_button, Palette.BUTTON, Palette.GOLD)
	else:
		spark_button.text = "Искра ×%d" % count if count > 0 else "Искра"
		_paint_button(spark_button, Color8(24, 36, 44), Palette.MUTED)
	spark_button.disabled = not board.can_toggle_spark()


func _on_finished(scores, winner) -> void:
	_refresh_hud()
	var score := int(scores[1])
	var target := int(board.level_data.get("target", 1))
	var index := int(board.level_data.get("index", 1))
	var cleared := int(winner) == 1 and score >= target
	overlay_s1.text = str(score)
	overlay_s2.text = str(int(scores[2]))
	overlay_next.visible = cleared
	if cleared:
		Campaign.note_clear(index, score)
		overlay_title.text = "Уровень пройден"
		overlay_title.add_theme_color_override("font_color", Palette.P1)
		overlay_sub.text = "Набрано %d при цели %d. Следующий уровень открыт. Всего очков: %d." % [score, target, Campaign.total_points()]
	elif int(winner) == 1:
		overlay_title.text = "Победа не засчитана"
		overlay_title.add_theme_color_override("font_color", Palette.GOLD)
		overlay_sub.text = "Нужно %d очков, набрано %d. Доберите цель и обыграйте Бирюзу." % [target, score]
	elif int(winner) == 0:
		overlay_title.text = "Ничья"
		overlay_title.add_theme_color_override("font_color", Palette.CREAM)
		overlay_sub.text = "Чтобы открыть следующий уровень, нужны победа и %d очков." % target
	else:
		overlay_title.text = "Победа · Бирюза"
		overlay_title.add_theme_color_override("font_color", Palette.P2)
		overlay_sub.text = "Чтобы открыть следующий уровень, нужны победа и %d очков." % target
	overlay.visible = true


func _mark_colors(level: Dictionary) -> Dictionary:
	var marks := {}
	var resources: Dictionary = level.get("res", {})
	for key in resources.keys():
		marks[str(key)] = Palette.resource_color(str(resources[key]))
	return marks


func _score_style(player: int, active: int) -> StyleBoxFlat:
	var border := Palette.color_of(player) if player == active else Color(Palette.MUTED, 0.45)
	var width := 4 if player == active else 1
	return _flat(Palette.PANEL, 16, border, width)


func _rules_text() -> String:
	return "\n".join(PackedStringArray([
		"Игроки по очереди ставят одну палочку — сторону клетки.",
		"",
		"Четвёртая палочка закрывает клетку: она ваша, и вы ходите снова. Общая палочка может закрыть сразу две клетки. Цепочка захватов остаётся у вас, пока закрываются новые клетки.",
		"",
		"Дыра — это пустое место внутри поля. Там нет клетки и нечего захватывать.",
		"",
		"Ресурсы достаются тому, кто закрыл клетку.",
		"",
		"Самоцвет — 2 очка вместо одного.",
		"Корона — 3 очка и искра в запас.",
		"Искра — запасная палочка. Нажмите «Искра», затем поставьте грань: ход останется у вас, даже если клетка не закрылась.",
		"Магнит — вместе с клеткой забирает соседние, у которых уже стоят три стороны. Так забирается готовая база рядом. Если среди них тоже есть магнит, захват продолжается.",
		"",
		"На клетке победителя стоит крестик, на клетке соперника — кружок. Побеждает тот, у кого больше очков.",
		"",
		"Уровни идут по порядку. Следующий открывается, только если вы победили и набрали цель по очкам. Первые три поля фиксированные. Дальше тип остаётся — пруд, крест, лестница, острова, змейка или крепость, — а форма этого типа каждый раз другая. Вы играете за Алых против ИИ.",
	]))


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _label(text: String, font_size: int, color: Color, center: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if center:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 58)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _paint_button(button: Button, fill: Color, font: Color) -> void:
	var down := fill.darkened(0.12)
	button.add_theme_stylebox_override("normal", _flat(fill, 16))
	button.add_theme_stylebox_override("hover", _flat(fill.lightened(0.08), 16))
	button.add_theme_stylebox_override("pressed", _flat(down, 16))
	button.add_theme_stylebox_override("disabled", _flat(fill.darkened(0.2), 16))
	button.add_theme_stylebox_override("focus", _flat(fill, 16))
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_disabled_color", Palette.MUTED)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)


func _flat(fill: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if border_width > 0:
		style.border_color = border
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
	return style


class ShapePreview extends Control:
	var box_size := Vector2(78, 78)
	var rows: Array = []
	var marks: Dictionary = {}

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
		for r in height:
			var line := str(rows[r])
			for c in line.length():
				if line[c] != "#":
					continue
				var rect := Rect2(origin + Vector2(c, r) * cell + Vector2(1, 1), Vector2(cell, cell) - Vector2(2, 2))
				draw_rect(rect, Color8(243, 230, 200), true)
				var key := "%d,%d" % [r, c]
				if marks.has(key):
					draw_circle(rect.get_center(), maxf(2.0, cell * 0.16), marks[key])


class PlayerMark extends Control:
	var player := 1
	var mark_color := Color8(225, 90, 69)

	func _ready() -> void:
		custom_minimum_size = Vector2(28, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 11, mark_color)
		var ink := Color8(243, 230, 200)
		if player == 1:
			draw_line(center + Vector2(-4.5, -4.5), center + Vector2(4.5, 4.5), ink, 2.0, true)
			draw_line(center + Vector2(-4.5, 4.5), center + Vector2(4.5, -4.5), ink, 2.0, true)
		else:
			draw_arc(center, 4.5, 0.0, TAU, 16, ink, 2.0, true)
