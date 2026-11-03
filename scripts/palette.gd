extends RefCounted
class_name Palette

const BG := Color8(20, 32, 40)
const CREAM := Color8(243, 230, 200)
const CREAM_DIM := Color8(217, 203, 179)
const INK := Color8(36, 28, 22)
const P1 := Color8(225, 90, 69)
const P1_DARK := Color8(163, 59, 44)
const P2 := Color8(47, 158, 150)
const P2_DARK := Color8(29, 110, 104)
const GOLD := Color8(230, 179, 77)
const GEM_C := Color8(70, 130, 235)
const SPARK_C := Color8(250, 205, 50)
const MAGNET_C := Color8(150, 110, 240)
const MAGNET_TIP := Color8(205, 212, 218)
const CROWN_C := Color8(240, 140, 35)
const WATER := Color8(52, 98, 128)
const READY := Color8(250, 214, 150)
const DANGER_TEXT := Color8(240, 130, 110)
const MUTED := Color8(138, 160, 170)
const PANEL := Color8(28, 46, 56)
const BUTTON := Color8(36, 58, 70)
const BUTTON_HOVER := Color8(48, 74, 88)
const BUTTON_DOWN := Color8(24, 40, 50)


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
