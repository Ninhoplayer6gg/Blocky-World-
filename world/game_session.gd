class_name GameSession
extends Node3D
## One play session in one world: builds the world, player, HUD, console and
## menus, routes UI input, and saves on exit. Root of game_session.tscn.

signal ready_to_play

## Given to new players. Data-driven kits arrive with game modes (0.2).
const STARTER_KIT: Array = [
	["blockyworld:grass", 64], ["blockyworld:dirt", 64], ["blockyworld:stone", 64],
	["blockyworld:planks", 64], ["blockyworld:log", 32], ["blockyworld:glass", 32],
	["blockyworld:sand", 32], ["blockyworld:bricks", 32], ["blockyworld:leaves", 32],
]

## Below this height the player is returned to spawn.
const VOID_Y := -32.0

var world: World
var player: Player
var hud: GameHud
var console: DevConsole
var debug_overlay: DebugOverlay
var pause_menu: PauseMenu
var environment_root: Node3D
var is_playing := false
var _loading: Label
var _is_new_player := false
var _closing := false


func _ready() -> void:
	var request: Dictionary = Game.take_session_request()
	if request.is_empty() or request.get("save") == null:
		Log.error("WORLD", "Game session started without a world; returning to menu")
		Game.return_to_menu.call_deferred()
		return
	var save: WorldSave = request.save
	environment_root = WorldEnvironmentFactory.create(Game.settings.render_distance)
	add_child(environment_root)
	world = World.new()
	var error := world.setup(Game.content, save, Game.events, Game.settings.render_distance)
	if not error.is_empty():
		Log.error("WORLD", "Cannot open world '%s': %s" % [save.get_name(), error])
		Game.return_to_menu.call_deferred()
		return
	add_child(world)
	_build_ui()
	_spawn_player()
	world.spawn_area_ready.connect(_on_spawn_area_ready)
	Game.settings.changed.connect(_on_settings_changed)
	Game.session = self
	Log.info("WORLD", "Opened world '%s' (seed %d, generator %s)" % [save.get_name(), save.get_seed(), save.get_generator()])
	var missing: Array = request.get("missing_mods", [])
	if not missing.is_empty():
		var names := PackedStringArray()
		for mod in missing:
			names.append(str(mod.get("id", "?")))
		hud.show_message("Missing mods: %s — their blocks are kept as placeholders" % ", ".join(names), 8.0)


func _exit_tree() -> void:
	# Also covers the tree quitting without going through Game.quit_game():
	# background chunk jobs must finish before the world is freed.
	close_session()
	if Game.session == self:
		Game.session = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing or console.is_open():
		return
	if event.is_action_pressed(InputActions.PAUSE):
		_set_paused(not pause_menu.visible)
	elif pause_menu.visible:
		return
	elif event.is_action_pressed(InputActions.TOGGLE_CONSOLE):
		console.open()
	elif event.is_action_pressed(InputActions.OPEN_COMMAND):
		console.open("/")
	elif event.is_action_pressed(InputActions.TOGGLE_DEBUG):
		debug_overlay.visible = not debug_overlay.visible
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_playing and not console.is_open():
		_set_paused(true)


## Saves world chunks, metadata and the player.
func save_game() -> void:
	if world == null:
		return
	world.save_world(true)
	if player != null:
		world.save.save_player_data(player.save_state())


## Saves and releases everything; safe to call more than once.
func close_session() -> void:
	if _closing or world == null:
		return
	_closing = true
	is_playing = false
	if player != null:
		world.save.save_player_data(player.save_state())
	world.shutdown()
	_capture_mouse(false)


func quit_to_menu() -> void:
	close_session()
	Game.return_to_menu()


func on_content_reloaded() -> void:
	var size_before := Game.content.registries.blocks.runtime_count()
	world.save.bind_blocks(Game.content.registries.blocks)
	if Game.content.registries.blocks.runtime_count() != size_before:
		Game.content.refresh_block_tables()
	var generator := Game.content.registries.generators.create(world.save.get_generator()) as WorldGenerator
	generator.setup(world.save.get_seed(), Game.content)
	world.generator = generator
	world.chunks.set_generator(generator)
	world.chunks.remesh_all()
	hud.refresh_all()


func _spawn_player() -> void:
	var data := world.save.load_player_data()
	_is_new_player = data.is_empty()
	var spawn := world.generator.get_spawn_position()
	player = world.entities.spawn("blockyworld:player", spawn, Player) as Player
	if player == null:
		Log.error("PLAYER", "Entity blockyworld:player is not registered; the base content pack is broken")
		Game.return_to_menu.call_deferred()
		return
	player.setup_player(Game.content, Game.settings)
	player.input_enabled = false
	if _is_new_player:
		for entry in STARTER_KIT:
			if Game.content.registries.items.has(entry[0]):
				player.inventory.add_item(ItemStack.create(entry[0], entry[1]))
	else:
		player.load_state(data)
	world.focus_position = player.global_position
	hud.bind(player, Game.content)
	debug_overlay.world = world
	debug_overlay.player = player
	console.context.player = player


func _process(_delta: float) -> void:
	if is_playing and player != null and player.global_position.y < VOID_Y:
		Log.warn("PLAYER", "Player fell out of the world at %s; returning to spawn" % player.global_position)
		_move_to_surface(world.generator.get_spawn_position())
		hud.show_message("You fell out of the world")


func _on_spawn_area_ready() -> void:
	var feet := VoxelCoords.position_to_block(player.global_position)
	var head := feet + Vector3i(0, 1, 0)
	var buried := _is_solid(feet) or _is_solid(head) or player.global_position.y < 0.0
	if _is_new_player or buried:
		if buried and not _is_new_player:
			Log.warn("PLAYER", "Saved position %s is inside blocks; moving to the surface" % player.global_position)
		_move_to_surface(player.global_position)
	_loading.visible = false
	is_playing = true
	player.input_enabled = true
	_capture_mouse(true)
	world.events.emit(Events.WORLD_LOADED, {"world": world})
	world.events.emit(Events.PLAYER_SPAWNED, {"player": player})
	ready_to_play.emit()


func _move_to_surface(position: Vector3) -> void:
	var cell := VoxelCoords.position_to_block(position)
	var standing := world.find_standing_y(cell.x, cell.z)
	if standing < 0:
		standing = int(world.generator.get_spawn_position().y)
	player.teleport(Vector3(cell.x + 0.5, standing + 0.05, cell.z + 0.5))


func _is_solid(cell: Vector3i) -> bool:
	var definition := world.get_block_definition(cell)
	return definition != null and definition.collision


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	hud = GameHud.new()
	hud.name = "HUD"
	layer.add_child(hud)
	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "Debug"
	layer.add_child(debug_overlay)
	pause_menu = PauseMenu.new()
	pause_menu.name = "Pause"
	layer.add_child(pause_menu)
	pause_menu.resume_requested.connect(_set_paused.bind(false))
	pause_menu.save_requested.connect(func() -> void:
		save_game()
		hud.show_message("World saved"))
	pause_menu.quit_requested.connect(quit_to_menu)
	console = DevConsole.new()
	console.name = "Console"
	layer.add_child(console)
	console.context = Game.make_command_context(world, null)
	console.context.ui_action = func(action: String) -> void:
		if action == "clear":
			console.clear_output()
	console.opened.connect(_on_console_toggled.bind(true))
	console.closed.connect(_on_console_toggled.bind(false))
	_loading = Label.new()
	_loading.text = "Generating world..."
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading.add_theme_font_size_override("font_size", 32)
	var shade := StyleBoxFlat.new()
	shade.bg_color = Color(0.08, 0.1, 0.12)
	_loading.add_theme_stylebox_override("normal", shade)
	layer.add_child(_loading)
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _set_paused(paused: bool) -> void:
	pause_menu.visible = paused
	player.input_enabled = not paused and not console.is_open()
	_capture_mouse(not paused)


func _on_console_toggled(open: bool) -> void:
	player.input_enabled = not open and not pause_menu.visible
	_capture_mouse(not open and not pause_menu.visible)


func _capture_mouse(capture: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE


func _on_settings_changed() -> void:
	world.chunks.set_render_distance(Game.settings.render_distance)
	var world_environment := environment_root.get_node("WorldEnvironment") as WorldEnvironment
	WorldEnvironmentFactory.update_fog(world_environment.environment, Game.settings.render_distance)
