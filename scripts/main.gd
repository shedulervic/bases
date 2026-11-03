extends Control

const Palette = preload("res://scripts/palette.gd")
const Campaign = preload("res://scripts/campaign.gd")
const BoardView = preload("res://scripts/board.gd")
const GameRules = preload("res://scripts/rules.gd")
const LevelCatalog = preload("res://scripts/levels.gd")
const RuleArt = preload("res://scripts/rule_art.gd")
const ShapePreview = preload("res://scripts/shape_preview.gd")
const Confetti = preload("res://scripts/confetti.gd")

const LEGEND := [
	["gem", "2 очка"],
	["crown", "3 очка"],
	["spark", "ещё ход"],
	["magnet", "берёт соседей"],
]

var _screen := "menu"
var board: BoardView
var menu_screen: Control
var rules_screen: Control
var settings_screen: Control
var game_screen: Control
var pending_level: Dictionary = {}
var menu_preview: ShapePreview
var menu_legend: HFlowContainer
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
var overlay_again: Button
var overlay_panel: PanelContainer
var overlay_confetti: Confetti
var overlay_title: Label
var overlay_sub: Label
var overlay_s1: Label
var overlay_s2: Label
var background: ColorRect
var host: Control
var _back_at := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Palette.restore()
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
	theme.default_font_size = 28
	theme.set_color("font_color", "Label", Palette.CREAM)
	theme.set_color("font_color", "Button", Palette.CREAM)
	theme.set_color("font_disabled_color", "Button", Palette.MUTED)
	theme.set_font_size("font_size", "Button", 30)
	theme.set_stylebox("normal", "Button", _flat(Palette.BUTTON, 16))
	theme.set_stylebox("hover", "Button", _flat(Palette.BUTTON_HOVER, 16))
	theme.set_stylebox("pressed", "Button", _flat(Palette.BUTTON_DOWN, 16))
	theme.set_stylebox("disabled", "Button", _flat(Palette.BUTTON_DOWN, 16))
	theme.set_stylebox("focus", "Button", _flat(Palette.BUTTON, 16, Palette.MUTED, 2))
	self.theme = theme


func _build() -> void:
	background = ColorRect.new()
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

	host = Control.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(host)
	_fill_screens()


func _fill_screens() -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.free()
	background.color = Palette.BG
	_apply_theme()
	menu_screen = _build_menu()
	rules_screen = _build_rules()
	settings_screen = _build_settings()
	game_screen = _build_game()
	for screen in [menu_screen, rules_screen, settings_screen, game_screen]:
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
	box.add_child(_label("Квадраты", 64, Palette.CREAM, true))
	var tagline := _label("Каждый следующий уровень — после победы", 26, Palette.CREAM_DIM, true)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(tagline)

	menu_preview = ShapePreview.new()
	menu_preview.box_size = Vector2(220, 220)
	menu_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(menu_preview)

	menu_legend = HFlowContainer.new()
	menu_legend.alignment = FlowContainer.ALIGNMENT_CENTER
	menu_legend.add_theme_constant_override("h_separation", 22)
	menu_legend.add_theme_constant_override("v_separation", 4)
	box.add_child(menu_legend)

	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", _flat(Palette.PANEL, 16))
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 2)
	stats.add_child(stats_box)
	stat_level = _label("Уровень 1", 30, Palette.CREAM, true)
	stat_points = _label("Очки: 0", 32, Palette.GOLD, true)
	stat_goal = _label("", 26, Palette.CREAM_DIM, true)
	stat_goal.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_box.add_child(stat_level)
	stats_box.add_child(stat_points)
	stats_box.add_child(stat_goal)
	box.add_child(stats)

	var play := _button("Играть")
	_paint_button(play, Palette.P1_DARK, Palette.ON_ACCENT)
	play.pressed.connect(_play_current)
	box.add_child(play)

	var rules := _button("Как играть")
	rules.pressed.connect(func() -> void: _show("rules"))
	box.add_child(rules)

	box.add_child(_spacer())
	var footer := _label("После третьего уровня форма поля меняется, условия остаются", 24, Palette.MUTED, true)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(footer)

	var gear := GearButton.new()
	gear.tooltip_text = "Настройки"
	gear.pressed.connect(func() -> void: _show("settings"))
	root.add_child(gear)
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
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", _flat(Palette.PANEL, 20))
	center.add_child(panel)
	var dialog := VBoxContainer.new()
	dialog.add_theme_constant_override("separation", 14)
	panel.add_child(dialog)
	var title := _label("Сбросить прогресс?", 34, Palette.CREAM, true)
	var body := _label("Очки и открытые уровни пропадут. Кампания начнётся с Калитки.", 26, Palette.CREAM_DIM, true)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialog.add_child(title)
	dialog.add_child(body)
	var confirm := _button("Да, сбросить")
	_paint_button(confirm, Palette.BUTTON, Palette.DANGER_TEXT)
	confirm.pressed.connect(_confirm_reset)
	dialog.add_child(confirm)
	var cancel := _button("Отмена")
	cancel.pressed.connect(func() -> void: dim.visible = false)
	dialog.add_child(cancel)
	return dim


func _choose_theme(theme_id: String) -> void:
	if theme_id == Palette.id:
		return
	Palette.use(theme_id)
	call_deferred("_apply_chosen_theme")


func _apply_chosen_theme() -> void:
	_fill_screens()
	_show("settings")


func _confirm_reset() -> void:
	Campaign.reset()
	reset_dialog.visible = false
	_refresh_menu()


func _build_settings() -> Control:
	var root := Control.new()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	box.add_child(_label("Настройки", 40, Palette.CREAM, true))
	box.add_child(_label("Тема", 32, Palette.GOLD, true))
	var themes := HBoxContainer.new()
	themes.add_theme_constant_override("separation", 10)
	box.add_child(themes)
	for entry in [["night", "Ночная"], ["light", "Светлая"], ["sand", "Песочная"]]:
		var theme_id: String = str(entry[0])
		var theme_button := _button(str(entry[1]))
		theme_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		theme_button.add_theme_font_size_override("font_size", 24)
		if Palette.id == theme_id:
			_paint_button(theme_button, Palette.BUTTON_HOVER, Palette.CREAM, Palette.GOLD)
		theme_button.pressed.connect(_choose_theme.bind(theme_id))
		themes.add_child(theme_button)
	reset_button = _button("Сбросить прогресс")
	_paint_button(reset_button, Palette.BUTTON, Palette.DANGER_TEXT)
	reset_button.pressed.connect(func() -> void: reset_dialog.visible = true)
	box.add_child(reset_button)
	var note := _label("Очки и открытые уровни пропадут. Кампания начнётся с Калитки.", 24, Palette.MUTED, true)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(note)
	box.add_child(_spacer())
	var back := _button("Назад")
	back.pressed.connect(func() -> void: _show("menu"))
	box.add_child(back)
	reset_dialog = _build_reset_dialog()
	root.add_child(reset_dialog)
	return root


func _build_rules() -> Control:
	var root := Control.new()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	box.add_child(_label("Как играть", 40, Palette.CREAM, true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	for step in _rule_steps():
		if step[0] == "":
			list.add_child(_label(str(step[1]), 32, Palette.GOLD, false))
		else:
			list.add_child(_rule_row(str(step[0]), str(step[1])))
	var goal := _label("Победите и наберите цель по очкам — откроется следующий уровень. Вы играете за Алых против ИИ.", 26, Palette.CREAM_DIM, false)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD
	list.add_child(goal)

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

	level_title = _label("Поле", 32, Palette.CREAM, true)
	mode_label = _label("", 26, Palette.CREAM_DIM, true)
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

	status_label = _label("Ход", 32, Palette.CREAM, true)
	hint_label = _label("", 26, Palette.MUTED, true)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint_label.custom_minimum_size = Vector2(0, 72)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(status_label)
	box.add_child(hint_label)

	board = BoardView.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(220, 280)
	board.changed.connect(_refresh_hud)
	board.finished.connect(_on_finished)
	box.add_child(board)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	spark_button = _button("Искра")
	spark_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spark_button.size_flags_stretch_ratio = 1.3
	spark_button.visible = false
	spark_button.pressed.connect(func() -> void: board.toggle_spark())
	actions.add_child(spark_button)
	var again := _button("Заново")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(_restart)
	actions.add_child(again)
	var leave := _button("В меню")
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void: _show("menu"))
	actions.add_child(leave)

	overlay = ColorRect.new()
	overlay.color = Color(0.04, 0.05, 0.07, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", _flat(Palette.PANEL, 20))
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	center.add_child(panel)
	overlay_panel = panel
	overlay_confetti = Confetti.new()
	overlay_confetti.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(overlay_confetti)
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", 12)
	panel.add_child(result)
	overlay_title = _label("Партия", 40, Palette.CREAM, true)
	overlay_sub = _label("", 26, Palette.CREAM_DIM, true)
	overlay_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	result.add_child(overlay_title)
	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 12)
	result.add_child(score_row)
	overlay_s1 = _label("0", 64, Palette.P1, true)
	overlay_s2 = _label("0", 64, Palette.P2, true)
	score_row.add_child(overlay_s1)
	score_row.add_child(_label(":", 52, Palette.CREAM, true))
	score_row.add_child(overlay_s2)
	result.add_child(overlay_sub)
	overlay_next = _button("Дальше")
	_paint_button(overlay_next, Palette.P1_DARK, Palette.ON_ACCENT)
	overlay_next.visible = false
	overlay_next.pressed.connect(_play_current)
	result.add_child(overlay_next)
	overlay_again = _button("Ещё раз")
	overlay_again.pressed.connect(_restart)
	result.add_child(overlay_again)
	var fields := _button("В меню")
	_quiet_button(fields)
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
	title_row.add_child(_label(Palette.name_of(player), 24, Palette.CREAM_DIM, false))
	var score := _label("0", 48, Palette.color_of(player), true)
	var meta := _label("очки", 24, Palette.MUTED, true)
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
	menu_preview.holes = LevelCatalog.holes(level.rows)
	menu_preview.resources = level.get("res", {})
	menu_preview.queue_redraw()
	_refresh_legend(level.get("res", {}))


func _restart() -> void:
	overlay.visible = false
	board.restart()
	_refresh_hud()


func _show(screen: String) -> void:
	_screen = screen
	menu_screen.visible = screen == "menu"
	rules_screen.visible = screen == "rules"
	settings_screen.visible = screen == "settings"
	game_screen.visible = screen == "game"
	if screen == "menu" or screen == "settings":
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
	elif _screen == "settings":
		if reset_dialog.visible:
			reset_dialog.visible = false
		else:
			_show("menu")
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
	var holder := 1 if board.vs_ai else board.current
	var count := int(board.sparks[holder]) if not board.over else 0
	spark_button.visible = count > 0
	if board.spark_armed:
		spark_button.text = "Готова"
		_paint_button(spark_button, Palette.GOLD, Palette.INK)
	elif board.can_toggle_spark():
		spark_button.text = "Искра ×%d" % count
		_paint_button(spark_button, Palette.BUTTON, Palette.GOLD)
	else:
		spark_button.text = "Искра ×%d" % count
		_paint_button(spark_button, Palette.BUTTON_DOWN, Palette.MUTED)
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
		_paint_button(overlay_again, Palette.BUTTON, Palette.CREAM)
	else:
		_paint_button(overlay_again, Palette.P1_DARK, Palette.ON_ACCENT)
	if cleared:
		Campaign.note_clear(index, score)
		overlay_title.text = "Уровень пройден!"
		overlay_title.add_theme_color_override("font_color", Palette.P1)
		overlay_sub.text = "Цель %d взята. Открыт уровень %d!" % [target, index + 1]
	elif int(winner) == 1:
		overlay_title.text = "Победа!"
		overlay_title.add_theme_color_override("font_color", Palette.GOLD)
		overlay_sub.text = "Для нового уровня нужно %d очков, у вас %d. Ещё чуть-чуть!" % [target, score]
	elif int(winner) == 0:
		overlay_title.text = "Ничья!"
		overlay_title.add_theme_color_override("font_color", Palette.CREAM)
		overlay_sub.text = "Почти! Для нового уровня нужны победа и %d очков." % target
	else:
		overlay_title.text = "Бирюза победила"
		overlay_title.add_theme_color_override("font_color", Palette.P2)
		overlay_sub.text = "Не беда, попробуйте ещё раз. Для нового уровня нужны победа и %d очков." % target
	overlay.visible = true
	overlay_panel.scale = Vector2(0.86, 0.86)
	create_tween().tween_property(overlay_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if cleared:
		overlay_confetti.burst()
	else:
		overlay_confetti.stop()


func _refresh_legend(resources: Dictionary) -> void:
	for child in menu_legend.get_children():
		child.queue_free()
	var present := {}
	for key in resources.keys():
		present[str(resources[key])] = true
	for entry in LEGEND:
		if not present.has(entry[0]):
			continue
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		var art := RuleArt.new()
		art.kind = str(entry[0])
		art.box = 44.0
		item.add_child(art)
		item.add_child(_label(str(entry[1]), 22, Palette.CREAM_DIM, false))
		menu_legend.add_child(item)


func _score_style(player: int, active: int) -> StyleBoxFlat:
	var border := Palette.color_of(player) if player == active else Color(Palette.MUTED, 0.45)
	var width := 4 if player == active else 1
	return _flat(Palette.PANEL, 16, border, width)


func _rule_steps() -> Array:
	return [
		["stick", "Ходите по очереди. За ход — одна палочка между двумя точками."],
		["close", "Четвёртая палочка закрывает клетку. Клетка ваша, и вы ходите ещё раз."],
		["hole", "Вода — это дыра. Там нет клетки, туда не ходят."],
		["marks", "Крестик — ваши клетки. Кружок — клетки соперника. У кого больше очков, тот победил."],
		["", "Ресурсы в клетках"],
		["gem", "Самоцвет — 2 очка."],
		["crown", "Корона — 3 очка и искра."],
		["spark", "Искра — нажмите «Искра» и ставьте палочку: ход останется у вас."],
		["magnet", "Магнит — заберёт и соседние клетки, где уже три палочки."],
	]


func _rule_row(kind: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var art := RuleArt.new()
	art.kind = kind
	art.box = 132.0 if kind in ["stick", "close", "hole", "marks"] else 96.0
	art.custom_minimum_size = Vector2(132, art.box)
	row.add_child(art)
	var label := _label(text, 28, Palette.CREAM, false)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return row


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
	button.custom_minimum_size = Vector2(0, 88)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _paint_button(button: Button, fill: Color, font: Color, border: Color = Color(0, 0, 0, 0)) -> void:
	var down := fill.darkened(0.12)
	var width := 4 if border.a > 0.0 else 0
	button.add_theme_stylebox_override("normal", _flat(fill, 16, border, width))
	button.add_theme_stylebox_override("hover", _flat(fill.lightened(0.08), 16, border, width))
	button.add_theme_stylebox_override("pressed", _flat(down, 16, border, width))
	button.add_theme_stylebox_override("disabled", _flat(fill.darkened(0.2), 16))
	button.add_theme_stylebox_override("focus", _flat(fill, 16))
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_disabled_color", Palette.MUTED)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)


func _quiet_button(button: Button) -> void:
	var clear := Color(0, 0, 0, 0)
	button.add_theme_stylebox_override("normal", _flat(clear, 16))
	button.add_theme_stylebox_override("hover", _flat(Color(Palette.BUTTON, 0.5), 16))
	button.add_theme_stylebox_override("pressed", _flat(Palette.BUTTON_DOWN, 16))
	button.add_theme_stylebox_override("disabled", _flat(clear, 16))
	button.add_theme_stylebox_override("focus", _flat(clear, 16))
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Palette.MUTED)
	button.add_theme_color_override("font_hover_color", Palette.CREAM_DIM)
	button.add_theme_color_override("font_pressed_color", Palette.CREAM_DIM)
	button.add_theme_color_override("font_disabled_color", Color(Palette.MUTED, 0.4))


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


class GearButton extends Button:
	func _ready() -> void:
		text = ""
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(88, 88)
		tooltip_text = "Настройки"
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -88.0
		offset_top = 0.0
		offset_right = 0.0
		offset_bottom = 88.0
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.34
		var color := Palette.CREAM
		if is_pressed():
			color = Palette.CREAM_DIM
		elif is_hovered():
			color = Color(Palette.CREAM).lightened(0.12)
		var teeth := 8
		var root_r := radius * 0.68
		var pts := PackedVector2Array()
		for i in teeth:
			var base := TAU * float(i) / float(teeth) - PI * 0.5
			var step := TAU / float(teeth)
			var tooth := step * 0.46
			var lead := (step - tooth) * 0.5
			var a0 := base
			var a1 := base + lead
			var a2 := a1 + tooth
			var a3 := base + step
			pts.append(center + Vector2(cos(a0), sin(a0)) * root_r)
			pts.append(center + Vector2(cos(a1), sin(a1)) * root_r)
			pts.append(center + Vector2(cos(a1), sin(a1)) * radius)
			pts.append(center + Vector2(cos(a2), sin(a2)) * radius)
			pts.append(center + Vector2(cos(a2), sin(a2)) * root_r)
			pts.append(center + Vector2(cos(a3), sin(a3)) * root_r)
		draw_colored_polygon(pts, color)
		draw_circle(center, radius * 0.36, Palette.BG)
		draw_arc(center, radius * 0.36, 0.0, TAU, 32, color, maxf(2.5, radius * 0.1), true)
		draw_circle(center, radius * 0.13, color)


class PlayerMark extends Control:
	var player := 1
	var mark_color := Color8(225, 90, 69)

	func _ready() -> void:
		custom_minimum_size = Vector2(36, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 16, mark_color)
		var ink := Color8(36, 28, 22)
		if player == 1:
			draw_line(center + Vector2(-6.5, -6.5), center + Vector2(6.5, 6.5), ink, 3.0, true)
			draw_line(center + Vector2(-6.5, 6.5), center + Vector2(6.5, -6.5), ink, 3.0, true)
		else:
			draw_arc(center, 6.5, 0.0, TAU, 20, ink, 3.0, true)
