extends RefCounted
class_name Palette

const SAVE_PATH := "user://squares.cfg"
const ON_ACCENT := Color8(243, 230, 200)

static var id: String = "sand"
static var BG: Color = Color8(214, 176, 122)
static var CREAM: Color = Color8(48, 30, 16)
static var CREAM_DIM: Color = Color8(86, 56, 30)
static var INK: Color = Color8(36, 28, 22)
static var CELL: Color = Color8(255, 248, 230)
static var P1: Color = Color8(225, 90, 69)
static var P1_DARK: Color = Color8(163, 59, 44)
static var P2: Color = Color8(47, 158, 150)
static var P2_DARK: Color = Color8(29, 110, 104)
static var GOLD: Color = Color8(122, 68, 12)
static var GEM_C: Color = Color8(70, 130, 235)
static var SPARK_C: Color = Color8(250, 205, 50)
static var MAGNET_C: Color = Color8(150, 110, 240)
static var MAGNET_TIP: Color = Color8(205, 212, 218)
static var CROWN_C: Color = Color8(240, 140, 35)
static var WATER: Color = Color8(42, 108, 142)
static var READY: Color = Color8(255, 196, 120)
static var DANGER_TEXT: Color = Color8(150, 42, 28)
static var MUTED: Color = Color8(110, 74, 40)
static var PANEL: Color = Color8(255, 244, 220)
static var BUTTON: Color = Color8(196, 154, 98)
static var BUTTON_HOVER: Color = Color8(184, 142, 86)
static var BUTTON_DOWN: Color = Color8(166, 124, 70)


static func restore() -> void:
	apply(_saved_id())


static func use(theme_id: String) -> void:
	apply(theme_id)
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("settings", "theme", id)
	config.save(SAVE_PATH)


static func apply(theme_id: String) -> void:
	var next := theme_id
	if next != "night" and next != "light" and next != "sand":
		next = "sand"
	id = next
	P1 = Color8(225, 90, 69)
	P1_DARK = Color8(163, 59, 44)
	P2 = Color8(47, 158, 150)
	P2_DARK = Color8(29, 110, 104)
	GEM_C = Color8(70, 130, 235)
	SPARK_C = Color8(250, 205, 50)
	MAGNET_C = Color8(150, 110, 240)
	MAGNET_TIP = Color8(205, 212, 218)
	CROWN_C = Color8(240, 140, 35)
	INK = Color8(36, 28, 22)
	if next == "light":
		_light()
	elif next == "sand":
		_sand()
	else:
		_night()


static func _saved_id() -> String:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return "sand"
	return str(config.get_value("settings", "theme", "sand"))


static func _night() -> void:
	BG = Color8(20, 32, 40)
	CREAM = Color8(243, 230, 200)
	CREAM_DIM = Color8(217, 203, 179)
	CELL = Color8(243, 230, 200)
	GOLD = Color8(230, 179, 77)
	WATER = Color8(52, 98, 128)
	READY = Color8(250, 214, 150)
	DANGER_TEXT = Color8(240, 130, 110)
	MUTED = Color8(138, 160, 170)
	PANEL = Color8(28, 46, 56)
	BUTTON = Color8(36, 58, 70)
	BUTTON_HOVER = Color8(48, 74, 88)
	BUTTON_DOWN = Color8(24, 40, 50)


static func _light() -> void:
	BG = Color8(220, 228, 234)
	CREAM = Color8(26, 36, 46)
	CREAM_DIM = Color8(52, 66, 78)
	CELL = Color8(255, 252, 247)
	GOLD = Color8(140, 90, 12)
	WATER = Color8(48, 112, 150)
	READY = Color8(255, 210, 140)
	DANGER_TEXT = Color8(168, 48, 36)
	MUTED = Color8(90, 104, 116)
	PANEL = Color8(255, 255, 255)
	BUTTON = Color8(198, 210, 218)
	BUTTON_HOVER = Color8(184, 198, 208)
	BUTTON_DOWN = Color8(168, 182, 192)


static func _sand() -> void:
	BG = Color8(214, 176, 122)
	CREAM = Color8(48, 30, 16)
	CREAM_DIM = Color8(86, 56, 30)
	CELL = Color8(255, 248, 230)
	GOLD = Color8(122, 68, 12)
	WATER = Color8(42, 108, 142)
	READY = Color8(255, 196, 120)
	DANGER_TEXT = Color8(150, 42, 28)
	MUTED = Color8(110, 74, 40)
	PANEL = Color8(255, 244, 220)
	BUTTON = Color8(196, 154, 98)
	BUTTON_HOVER = Color8(184, 142, 86)
	BUTTON_DOWN = Color8(166, 124, 70)


static func name_of(player: int) -> String:
	if player == 1:
		return "Алые"
	if player == 2:
		return "Бирюза"
	return ""


static func color_of(player: int) -> Color:
	if player == 1:
		return P1
	if player == 2:
		return P2
	return CREAM


static func resource_color(res: String) -> Color:
	match res:
		"gem":
			return GEM_C
		"spark":
			return SPARK_C
		"magnet":
			return MAGNET_C
		"crown":
			return CROWN_C
		_:
			return CREAM
