class_name Settings
extends RefCounted
## Player settings persisted in user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440),
]

var resolution := Vector2i(1280, 720)
var fullscreen := false
var render_distance := GameConfig.DEFAULT_RENDER_DISTANCE
var mouse_sensitivity := 0.15
var master_volume := 0.8
var fov := 75.0


func _init() -> void:
	if OS.has_feature("mobile"):
		render_distance = GameConfig.MOBILE_RENDER_DISTANCE


func load_from_disk(path: String = PATH) -> void:
	var config := ConfigFile.new()
	var err := config.load(path)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		Log.warn("CORE", "Could not read settings %s (error %d); using defaults" % [path, err])
		return
	resolution = config.get_value("display", "resolution", resolution)
	fullscreen = config.get_value("display", "fullscreen", fullscreen)
	render_distance = clampi(int(config.get_value("video", "render_distance", render_distance)), 2, 32)
	fov = clampf(float(config.get_value("video", "fov", fov)), 50.0, 110.0)
	mouse_sensitivity = clampf(float(config.get_value("input", "mouse_sensitivity", mouse_sensitivity)), 0.01, 2.0)
	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)


func save_to_disk(path: String = PATH) -> void:
	var config := ConfigFile.new()
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("video", "render_distance", render_distance)
	config.set_value("video", "fov", fov)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("audio", "master_volume", master_volume)
	var err := config.save(path)
	if err != OK:
		Log.error("CORE", "Could not save settings to %s (error %d)" % [path, err])


func apply() -> void:
	_apply_display()
	_apply_audio()
	changed.emit()


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)


func _apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.0)
