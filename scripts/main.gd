extends Control

const Palette = preload("res://scripts/palette.gd")
const LevelCatalog = preload("res://scripts/levels.gd")
const BoardView = preload("res://scripts/board.gd")
const GameRules = preload("res://scripts/rules.gd")

const SAVE_PATH := "user://squares.cfg"

var _screen := "menu"
var board: BoardView
var menu_screen: Control
var rules_screen: Control
var levels_screen: Control
var game_screen: Control
var levels_box: VBoxContainer
var mode_dialog: Control
var mode_title: Label
var mode_blurb: Label
var pending_level: Dictionary = {}
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
	levels_screen = _build_levels()
	game_screen = _build_game()
	for screen in [menu_screen, rules_screen, levels_screen, game_screen]:
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
	box.add_child(_label("Квадраты", 58, Palette.CREAM, true))
	box.add_child(_label("Ставьте палочки и забирайте клетки", 20, Palette.CREAM_DIM, true))

	var demo: Dictionary = {}
	for level in LevelCatalog.all():
		if str(level.id) == "yard":
			demo = level
			break
	var preview := ShapePreview.new()
	preview.box_size = Vector2(168, 168)
	preview.rows = demo.get("rows", [])
	preview.marks = _mark_colors(demo)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(preview)

	var play := _button("Выбрать поле")
	_paint_button(play, Palette.P1, Palette.CREAM)
	play.pressed.connect(func() -> void: _show("levels"))
	box.add_child(play)

	var rules := _button("Как играть")
	rules.pressed.connect(func() -> void: _show("rules"))
	box.add_child(rules)

	box.add_child(_spacer())
	box.add_child(_label("Два игрока на одном телефоне или партия против ИИ", 16, Palette.MUTED, true))
	return root


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


func _build_levels() -> Control:
	var root := Control.new()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	box.add_child(_label("Поля", 36, Palette.CREAM, true))
	box.add_child(_label("Дыры — не клетки. Точки внутри — ресурсы.", 16, Palette.MUTED, true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	levels_box = VBoxContainer.new()
	levels_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_box.add_theme_constant_override("separation", 10)
	scroll.add_child(levels_box)

	var back := _button("В меню")
	back.pressed.connect(func() -> void: _show("menu"))
	box.add_child(back)

	mode_dialog = ColorRect.new()
	mode_dialog.color = Color(0, 0, 0, 0.55)
	mode_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	mode_dialog.visible = false
	mode_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	mode_dialog.gui_input.connect(_on_mode_backdrop)
	root.add_child(mode_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_dialog.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", _flat(Palette.PANEL, 20))
	center.add_child(panel)
	var dialog_box := VBoxContainer.new()
	dialog_box.add_theme_constant_override("separation", 10)
	panel.add_child(dialog_box)
	mode_title = _label("Поле", 28, Palette.CREAM, true)
	mode_blurb = _label("", 16, Palette.CREAM_DIM, true)
	mode_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialog_box.add_child(mode_title)
	dialog_box.add_child(mode_blurb)
	dialog_box.add_child(_label("Кто начинает — решает жребий. Против ИИ вы играете за Алых.", 15, Palette.MUTED, true))

	var hotseat := _button("Вдвоём на этом экране")
	hotseat.pressed.connect(_start_game.bind("hotseat", ""))
	dialog_box.add_child(hotseat)
	var easy := _button("ИИ · спокойный")
	_paint_button(easy, Palette.P2_DARK, Palette.CREAM)
	easy.pressed.connect(_start_game.bind("ai", "easy"))
	dialog_box.add_child(easy)
	var hard := _button("ИИ · внимательный")
	_paint_button(hard, Palette.P2, Palette.INK)
	hard.pressed.connect(_start_game.bind("ai", "normal"))
	dialog_box.add_child(hard)
	var cancel := _button("Назад")
	cancel.pressed.connect(func() -> void: mode_dialog.visible = false)
	dialog_box.add_child(cancel)
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
	var leave := _button("К полям")
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void: _show("levels"))
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
	var rematch := _button("Ещё раз")
	_paint_button(rematch, Palette.P1, Palette.CREAM)
	rematch.pressed.connect(_restart)
	result.add_child(rematch)
	var fields := _button("К полям")
	fields.pressed.connect(func() -> void:
		overlay.visible = false
		_show("levels")
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


func _fill_levels() -> void:
	for child in levels_box.get_children():
		levels_box.remove_child(child)
		child.free()
	for level in LevelCatalog.all():
		levels_box.add_child(_level_button(level))


func _level_button(level: Dictionary) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 108)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_ask_mode.bind(level.duplicate(true)))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	var preview := ShapePreview.new()
	preview.box_size = Vector2(78, 78)
	preview.rows = level.rows
	preview.marks = _mark_colors(level)
	row.add_child(preview)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	var name := _label(str(level.name), 22, Palette.CREAM, false)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(name)
	var blurb := _label(str(level.blurb), 15, Palette.CREAM_DIM, false)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.add_child(blurb)
	var record := _record_line(str(level.id))
	if record != "":
		text.add_child(_label(record, 14, Palette.GOLD, false))
	_ignore_tree(margin)
	return button


func _ask_mode(level: Dictionary) -> void:
	pending_level = level
	mode_title.text = str(level.name)
	mode_blurb.text = str(level.blurb)
	mode_dialog.visible = true


func _on_mode_backdrop(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mode_dialog.visible = false


func _start_game(mode: String, difficulty: String) -> void:
	if pending_level.is_empty():
		return
	mode_dialog.visible = false
	overlay.visible = false
	_show("game")
	board.load_level(pending_level, mode, difficulty)
	_refresh_hud()


func _restart() -> void:
	overlay.visible = false
	board.restart()
	_refresh_hud()


func _show(screen: String) -> void:
	_screen = screen
	menu_screen.visible = screen == "menu"
	rules_screen.visible = screen == "rules"
	levels_screen.visible = screen == "levels"
	game_screen.visible = screen == "game"
	if screen == "levels":
		mode_dialog.visible = false
		_fill_levels()
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
		_show("levels")
	elif _screen == "levels":
		if mode_dialog.visible:
			mode_dialog.visible = false
		else:
			_show("menu")
	elif _screen == "rules":
		_show("menu")
	elif _screen == "menu" and OS.has_feature("mobile"):
		get_tree().quit()


func _refresh_hud() -> void:
	if board.level_data.is_empty():
		return
	level_title.text = str(board.level_data.get("name", ""))
	mode_label.text = board.mode_line()
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
	overlay_s1.text = str(int(scores[1]))
	overlay_s2.text = str(int(scores[2]))
	if int(winner) == 0:
		overlay_title.text = "Ничья"
		overlay_title.add_theme_color_override("font_color", Palette.CREAM)
		overlay_sub.text = "Очки сравнялись."
	else:
		overlay_title.text = "Победа · %s" % Palette.name_of(int(winner))
		overlay_title.add_theme_color_override("font_color", Palette.color_of(int(winner)))
		if board.vs_ai and int(winner) == 1:
			overlay_sub.text = "Вы набрали больше очков."
		elif board.vs_ai and int(winner) == 2:
			overlay_sub.text = "ИИ набрал больше очков."
		else:
			overlay_sub.text = "Больше очков у того, кто закрыл удачные клетки."
	if board.vs_ai:
		var score := int(scores[1])
		if _write_best(str(board.level_data.get("id", "")), board.ai_difficulty, score) and score > 0:
			overlay_sub.text += " Новый рекорд."
	overlay.visible = true


func _record_line(level_id: String) -> String:
	var easy := _read_best(level_id, "easy")
	var hard := _read_best(level_id, "normal")
	var bits: Array = []
	if easy >= 0:
		bits.append("спокойный %d" % easy)
	if hard >= 0:
		bits.append("внимательный %d" % hard)
	if bits.is_empty():
		return ""
	return "Рекорд — " + " · ".join(PackedStringArray(bits))


func _read_best(level_id: String, difficulty: String) -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return -1
	return int(config.get_value("best", "%s|%s" % [level_id, difficulty], -1))


func _write_best(level_id: String, difficulty: String, score: int) -> bool:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var key := "%s|%s" % [level_id, difficulty]
	var previous := int(config.get_value("best", key, -1))
	if score <= previous:
		return false
	config.set_value("best", key, score)
	config.save(SAVE_PATH)
	return true


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
		"Можно играть вдвоём на одном телефоне или против ИИ. Против ИИ вы всегда Алые.",
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


func _ignore_tree(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_tree(child)


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
