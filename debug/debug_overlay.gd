class_name DebugOverlay
extends Label
## Toggleable (F3) diagnostics: performance, position, chunks, target block.

const REFRESH_SECONDS := 0.25

var world: World
var player: Player
var _timer := 0.0


func _ready() -> void:
	position = Vector2(8, 8)
	add_theme_font_size_override("font_size", 14)
	add_theme_constant_override("outline_size", 4)
	add_theme_color_override("font_outline_color", Color.BLACK)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(delta: float) -> void:
	if not visible or world == null or player == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH_SECONDS
	text = build_text()


func build_text() -> String:
	var position := player.global_position
	var block := VoxelCoords.position_to_block(position)
	var stats := world.chunks.stats()
	var lines := PackedStringArray()
	lines.append("%s %s | Godot %s" % [GameInfo.GAME_NAME, GameInfo.GAME_VERSION, Engine.get_version_info().string])
	lines.append("FPS %d (%.1f ms) | draw calls %d | objects %d" % [
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	lines.append("Memory %.1f MB static | video %.1f MB" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	lines.append("XYZ %.2f / %.2f / %.2f | block %s" % [position.x, position.y, position.z, block])
	lines.append("Chunk %s local %s | biome %s" % [VoxelCoords.block_to_chunk(block), VoxelCoords.block_to_local(block), world.get_biome_name(block)])
	lines.append("Chunks %d loaded, %d meshed, %d section meshes | waiting: %d gen, %d mesh, %d jobs" % [
		stats.loaded, stats.meshed, stats.section_meshes, stats.load_queue, stats.mesh_queue, stats.jobs])
	lines.append("Render distance %d | seed %d | generator %s" % [stats.render_distance, world.save.get_seed(), world.save.get_generator()])
	var movement := player.get_component("blockyworld:movement") as MovementComponent
	lines.append("Mode %s | on floor %s | velocity %.2f | entities %d | %s" % [
		movement.get_mode() if movement != null else "-", player.is_on_floor(), player.velocity.length(),
		world.entities.count(), "creative" if world.creative else "survival"])
	var target := player.interaction.target
	if target != null:
		var definition := world.content.registries.blocks.get_by_runtime(target.block_id)
		lines.append("Looking at %s %s face %s" % [definition.id if definition != null else "?", target.position, target.normal])
	else:
		lines.append("Looking at: nothing")
	lines.append("Mods %d loaded | placeholders %d" % [world.content.load_order.size(), world.content.resources.get_placeholder_report().size()])
	return "\n".join(lines)
