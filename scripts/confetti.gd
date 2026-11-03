extends Control
class_name Confetti

## Короткий залп конфетти поверх экрана итога.

const Palette = preload("res://scripts/palette.gd")

const LIFE := 2.4

var _pieces: Array = []
var _age := LIFE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func burst() -> void:
	var colors := [Palette.P1, Palette.P2, Palette.GOLD, Palette.GEM_C, Palette.ON_ACCENT]
	_pieces.clear()
	for i in 70:
		_pieces.append({
			"pos": Vector2(randf_range(0.1, 0.9) * size.x, randf_range(-0.15, 0.05) * size.y),
			"vel": Vector2(randf_range(-90.0, 90.0), randf_range(140.0, 380.0)),
			"spin": randf_range(-7.0, 7.0),
			"angle": randf() * TAU,
			"size": randf_range(10.0, 18.0),
			"color": colors[i % colors.size()],
		})
	_age = 0.0
	set_process(true)


func stop() -> void:
	_age = LIFE
	_pieces.clear()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	for piece in _pieces:
		piece.vel.y += 160.0 * delta
		piece.pos += piece.vel * delta
		piece.angle += piece.spin * delta
	if _age >= LIFE:
		stop()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := clampf((LIFE - _age) / 0.6, 0.0, 1.0)
	for piece in _pieces:
		var color: Color = piece.color
		color.a = alpha
		var half := Vector2(piece.size, piece.size * 0.45) * 0.5
		draw_set_transform(piece.pos, piece.angle, Vector2.ONE)
		draw_rect(Rect2(-half, half * 2.0), color, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
