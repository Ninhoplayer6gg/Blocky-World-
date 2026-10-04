extends Node
## Autoload "Game": process-wide services and the boot sequence.
##
## Owns settings, the event bus, loaded content (registries + mods) and the
## console command registry, and switches between the menu and game sessions.
## Systems receive what they need explicitly; this singleton is the place
## where those references are created, not a global grab-bag for gameplay.

const MENU_SCENE := "res://ui/main_menu.tscn"
const GAME_SCENE := "res://world/game_session.tscn"
const MOD_CONFIG_PATH := "user://mods.cfg"
const NO_BOOT_ARG := "--bw-no-boot"

var settings := Settings.new()
var events := EventBus.new()
var commands := CommandRegistry.new()
var content: GameContent
var session: GameSession
var _session_request: Dictionary = {}


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	Log.info("CORE", "%s %s starting (Godot %s, %s, save v%d, mod API v%d)" % [
		GameInfo.GAME_NAME, GameInfo.GAME_VERSION, Engine.get_version_info().string,
		OS.get_name(), GameInfo.SAVE_VERSION, GameInfo.MOD_API_VERSION])
	InputActions.install_defaults()
	settings.load_from_disk()
	settings.apply()
	BuiltinCommands.register_all(commands)
	if OS.get_cmdline_user_args().has(NO_BOOT_ARG):
		return
	boot()


## Runs the content pipeline (see ContentPipeline for the phases).
func boot() -> void:
	var started := Time.get_ticks_msec()
	var pipeline := ContentPipeline.new()
	pipeline.search_paths = ContentPipeline.default_search_paths()
	pipeline.disabled_mods = load_disabled_mods()
	content = pipeline.run()
	content.build_render_resources()
	events.emit(Events.CONTENT_LOADED, {"content": content})
	Log.info("CORE", "Boot finished in %d ms" % (Time.get_ticks_msec() - started))


# --- Sessions ------------------------------------------------------------------

## Returns {"save": WorldSave or null, "error": String}.
func create_world(world_name: String, seed_text: String, generator_id: String, creative: bool) -> Dictionary:
	var name_clean := world_name.strip_edges()
	if name_clean.is_empty():
		name_clean = "New World"
	var generator := content.registries.generators.create(generator_id) as WorldGenerator
	if generator == null:
		return {"save": null, "error": "Unknown world generator '%s'" % generator_id}
	var folder := SaveManager.make_folder_name(name_clean)
	var save := WorldSave.create(SaveManager.SAVES_ROOT.path_join(folder), name_clean,
		WorldHash.seed_from_text(seed_text), generator_id, generator.get_version(), content.active_mod_list(), creative)
	save.bind_blocks(content.registries.blocks)
	if save.save_metadata(content) != OK:
		return {"save": null, "error": "Could not write the world folder %s" % save.directory}
	Log.info("SAVE", "Created world '%s' in %s (seed %d)" % [name_clean, save.directory, save.get_seed()])
	return {"save": save, "error": ""}


## Returns {"save": WorldSave or null, "error": String, "missing_mods": Array}.
func open_world(directory: String) -> Dictionary:
	var opened := WorldSave.open(directory)
	if opened.save == null:
		Log.error("SAVE", "Cannot open %s: %s" % [directory, opened.error])
		return {"save": null, "error": opened.error, "missing_mods": []}
	var missing: Array = opened.save.find_missing_mods(content)
	return {"save": opened.save, "error": "", "missing_mods": missing}


## Opens Blocky Lab, creating it on first use.
func open_lab() -> Dictionary:
	for world in SaveManager.list_worlds():
		if world.error.is_empty() and world.generator == GameConfig.LAB_GENERATOR:
			return open_world(world.directory)
	var created := create_world(GameConfig.LAB_WORLD_NAME, str(GameConfig.DEFAULT_WORLD_SEED), GameConfig.LAB_GENERATOR, true)
	created["missing_mods"] = []
	return created


func start_session(save: WorldSave, missing_mods: Array = []) -> void:
	_session_request = {"save": save, "missing_mods": missing_mods}
	get_tree().change_scene_to_file(GAME_SCENE)


func take_session_request() -> Dictionary:
	var request := _session_request
	_session_request = {}
	return request


func return_to_menu() -> void:
	if session != null:
		session.close_session()
	get_tree().change_scene_to_file(MENU_SCENE)


func quit_game() -> void:
	if session != null:
		session.close_session()
	settings.save_to_disk()
	Log.info("CORE", "Exiting")
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


# --- Console & reload ----------------------------------------------------------

func make_command_context(world: World, player: Player) -> CommandContext:
	var context := CommandContext.new()
	context.content = content
	context.world = world
	context.player = player
	context.registry = commands
	context.reload = reload_content
	return context


## Hot reload of JSON content and textures. Existing block/item definitions are
## updated in place (runtime ids stay valid), new ones are appended; other
## registries are replaced. Code (GDScript) is not reloaded.
func reload_content() -> String:
	var started := Time.get_ticks_msec()
	var pipeline := ContentPipeline.new()
	pipeline.search_paths = ContentPipeline.default_search_paths()
	pipeline.disabled_mods = load_disabled_mods()
	var staged := pipeline.run()
	var live := content.registries
	var blocks: Dictionary = live.blocks.merge_reload(staged.registries.blocks)
	var items: Dictionary = live.items.merge_reload(staged.registries.items)
	live.attributes = staged.registries.attributes
	live.biomes = staged.registries.biomes
	live.models = staged.registries.models
	live.entities = staged.registries.entities
	content.resources = staged.resources
	content.mods = staged.mods
	content.load_order = staged.load_order
	content.build_render_resources()
	if session != null:
		session.on_content_reloaded()
	events.emit(Events.CONTENT_RELOADED, {"content": content})
	var summary := "Reloaded in %d ms: blocks %d updated, %d new; items %d updated, %d new" % [
		Time.get_ticks_msec() - started, blocks.updated, blocks.added.size(), items.updated, items.added.size()]
	if not blocks.removed.is_empty():
		summary += "; %d block(s) no longer defined stay registered until restart: %s" % [blocks.removed.size(), ", ".join(blocks.removed)]
	Log.info("CONTENT", summary)
	return summary


# --- Mod enable/disable --------------------------------------------------------

func load_disabled_mods() -> PackedStringArray:
	var config := ConfigFile.new()
	if config.load(MOD_CONFIG_PATH) != OK:
		return PackedStringArray()
	return PackedStringArray(config.get_value("mods", "disabled", []))


## Takes effect on next start (or /reload for newly enabled content).
func set_mod_enabled(mod_id: String, enabled: bool) -> void:
	var disabled := load_disabled_mods()
	if enabled:
		var index := disabled.find(mod_id)
		if index >= 0:
			disabled.remove_at(index)
	elif not disabled.has(mod_id):
		disabled.append(mod_id)
	var config := ConfigFile.new()
	config.set_value("mods", "disabled", Array(disabled))
	var err := config.save(MOD_CONFIG_PATH)
	if err != OK:
		Log.error("MOD", "Could not save %s (error %d)" % [MOD_CONFIG_PATH, err])
