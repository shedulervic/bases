extends RefCounted
class_name GameMusic

## Два трека: меню (и экраны вокруг него) и партия.
## Флаг лежит в секции settings и не стирается сбросом кампании.

const SAVE_PATH := "user://squares.cfg"
const MENU_TRACK := "res://media/Theme of Siberia Smith.ogg"
const GAME_TRACK := "res://media/song18.mp3"


static func enabled() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return true
	return bool(config.get_value("settings", "music", true))


static func set_enabled(on: bool) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("settings", "music", on)
	config.save(SAVE_PATH)


static func make_stream(path: String) -> AudioStream:
	var loaded: Resource = load(path)
	if loaded is AudioStream:
		var copy: AudioStream = loaded.duplicate() as AudioStream
		_enable_loop(copy)
		return copy
	return _from_file(path)


static func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


static func _from_file(path: String) -> AudioStream:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	if path.ends_with(".ogg"):
		var ogg := AudioStreamOggVorbis.load_from_buffer(bytes)
		if ogg != null:
			ogg.loop = true
		return ogg
	var raw := AudioStreamMP3.new()
	raw.data = bytes
	raw.loop = true
	return raw
