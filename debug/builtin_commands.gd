class_name BuiltinCommands
extends RefCounted
## Base game console commands. Mods will register theirs the same way.


static func register_all(registry: CommandRegistry) -> void:
	registry.register("blockyworld:help", "/help [command]", "List commands or show one command's usage", _help, false)
	registry.register("blockyworld:give", "/give <item> [amount]", "Give items to the player", _give)
	registry.register("blockyworld:setblock", "/setblock <x> <y> <z> <block>", "Set a block (~ = relative to you)", _setblock)
	registry.register("blockyworld:tp", "/tp <x> <y> <z>", "Teleport the player", _tp)
	registry.register("blockyworld:spawn", "/spawn <entity> [x y z]", "Spawn an entity", _spawn)
	registry.register("blockyworld:reload", "/reload", "Reload content packs (JSON) and textures", _reload, false)
	registry.register("blockyworld:chunks", "/chunks", "Chunk streaming statistics", _chunks)
	registry.register("blockyworld:fps", "/fps", "Frame rate and frame time", _fps, false)
	registry.register("blockyworld:seed", "/seed", "Show the world seed", _seed)
	registry.register("blockyworld:save", "/save", "Save the world now", _save)
	registry.register("blockyworld:fly", "/fly", "Toggle flying", _fly)
	registry.register("blockyworld:rd", "/rd <chunks>", "Set render distance", _render_distance)
	registry.register("blockyworld:mods", "/mods", "List mods and their state", _mods, false)
	registry.register("blockyworld:blocks", "/blocks [filter]", "List registered blocks", _blocks, false)
	registry.register("blockyworld:items", "/items [filter]", "List registered items", _items, false)
	registry.register("blockyworld:entities", "/entities", "List entity types and live entities", _entities, false)
	registry.register("blockyworld:assets", "/assets", "List assets still using placeholders and where to put them", _assets, false)
	registry.register("blockyworld:pos", "/pos", "Show position, chunk and biome", _pos)
	registry.register("blockyworld:clear", "/clear", "Clear the console", _clear, false)


static func _help(context: CommandContext, args: PackedStringArray) -> String:
	if not args.is_empty():
		var command := context.registry.find(args[0].trim_prefix("/"))
		if command == null:
			return "Unknown command '%s'" % args[0]
		return "%s — %s (%s)" % [command.usage, command.description, command.id]
	var lines := PackedStringArray(["Commands:"])
	for command in context.registry.all():
		lines.append("  %s — %s" % [command.usage, command.description])
	return "\n".join(lines)


static func _give(context: CommandContext, args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: /give <item> [amount]"
	var item_id := context.qualify(args[0])
	var item := context.content.registries.items.get_item(item_id)
	if item == null:
		return "Unknown item '%s'. Try /items." % item_id
	var amount := maxi(args[1].to_int(), 1) if args.size() > 1 else item.max_stack
	var left := context.player.inventory.add_item(ItemStack.create(item_id, amount))
	return "Gave %d x %s%s" % [amount - left, item.display_name, " (%d did not fit)" % left if left > 0 else ""]


static func _setblock(context: CommandContext, args: PackedStringArray) -> String:
	var position: Variant = context.parse_position(args, 0)
	if position == null or args.size() < 4:
		return "Usage: /setblock <x> <y> <z> <block>"
	var block_id := context.qualify(args[3])
	var runtime_id := context.content.registries.blocks.get_runtime_id(block_id)
	if runtime_id < 0:
		return "Unknown block '%s'. Try /blocks." % block_id
	var cell := VoxelCoords.position_to_block(position)
	if not context.world.set_block(cell, runtime_id):
		return "Cannot set block at %s (outside the world or chunk not loaded)" % cell
	return "Set %s at %s" % [block_id, cell]


static func _tp(context: CommandContext, args: PackedStringArray) -> String:
	var position: Variant = context.parse_position(args, 0)
	if position == null:
		return "Usage: /tp <x> <y> <z>"
	context.player.teleport(position)
	return "Teleported to %s" % position


static func _spawn(context: CommandContext, args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: /spawn <entity> [x y z]. Types: %s" % ", ".join(context.content.registries.entities.ids())
	var entity_id := context.qualify(args[0])
	var position: Variant = context.parse_position(args, 1)
	if position == null:
		position = context.player.global_position + context.player.get_look_direction() * Vector3(3, 0, 3) + Vector3(0, 0.5, 0)
	var entity := context.world.entities.spawn(entity_id, position)
	if entity == null:
		return "Unknown entity '%s'" % entity_id
	return "Spawned %s at %s" % [entity_id, (position as Vector3).snapped(Vector3.ONE * 0.1)]


static func _reload(context: CommandContext, _args: PackedStringArray) -> String:
	if not context.reload.is_valid():
		return "Reload is not available here"
	return context.reload.call()


static func _chunks(context: CommandContext, _args: PackedStringArray) -> String:
	var stats := context.world.chunks.stats()
	return "Chunks: %d loaded, %d meshed, %d section meshes | queues: load %d, mesh %d, backlog %d | jobs %d | pending saves %d | render distance %d" % [
		stats.loaded, stats.meshed, stats.section_meshes, stats.load_queue, stats.mesh_queue,
		stats.backlog, stats.jobs, stats.pending_saves, stats.render_distance]


static func _fps(_context: CommandContext, _args: PackedStringArray) -> String:
	return "%d FPS (%.2f ms/frame)" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]


static func _seed(context: CommandContext, _args: PackedStringArray) -> String:
	return "Seed: %d" % context.world.save.get_seed()


static func _save(context: CommandContext, _args: PackedStringArray) -> String:
	context.world.save_world(true)
	context.world.save.save_player_data(context.player.save_state())
	return "World saved"


static func _fly(context: CommandContext, _args: PackedStringArray) -> String:
	var movement := context.player.get_component("blockyworld:movement") as MovementComponent
	if movement == null or not movement.has_mode("fly"):
		return "This player cannot fly"
	return "Flying enabled" if context.player.toggle_fly() else "Flying disabled"


static func _render_distance(context: CommandContext, args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_int():
		return "Render distance: %d. Usage: /rd <chunks>" % context.world.chunks.render_distance
	context.world.chunks.set_render_distance(args[0].to_int())
	return "Render distance set to %d" % context.world.chunks.render_distance


static func _mods(context: CommandContext, _args: PackedStringArray) -> String:
	var lines := PackedStringArray()
	for mod in context.content.mods:
		var version: String = mod.manifest.version if mod.manifest != null else "?"
		var line := "%s %s [%s] %s" % [mod.get_id(), version, mod.state_label(), mod.path]
		if not mod.errors.is_empty():
			line += "\n    errors: " + "; ".join(mod.errors)
		lines.append(line)
	return "\n".join(lines)


static func _blocks(context: CommandContext, args: PackedStringArray) -> String:
	return _list_ids(context.content.registries.blocks.ids(), args)


static func _items(context: CommandContext, args: PackedStringArray) -> String:
	return _list_ids(context.content.registries.items.ids(), args)


static func _entities(context: CommandContext, _args: PackedStringArray) -> String:
	var text := "Types: " + ", ".join(context.content.registries.entities.ids())
	if context.world != null:
		text += "\nLive: %d" % context.world.entities.count()
	return text


static func _assets(context: CommandContext, _args: PackedStringArray) -> String:
	var report := context.content.resources.get_placeholder_report()
	if report.is_empty():
		return "No placeholders in use."
	var lines := PackedStringArray(["%d asset(s) use placeholders:" % report.size()])
	for entry in report:
		lines.append("  [%s] %s -> %s" % [entry.type, entry.id, entry.expected])
	return "\n".join(lines)


static func _pos(context: CommandContext, _args: PackedStringArray) -> String:
	var position := context.player.global_position
	var block := VoxelCoords.position_to_block(position)
	return "Position %s | block %s | chunk %s | biome %s" % [position.snapped(Vector3.ONE * 0.01), block,
		VoxelCoords.block_to_chunk(block), context.world.get_biome_name(block)]


static func _clear(context: CommandContext, _args: PackedStringArray) -> String:
	if context.ui_action.is_valid():
		context.ui_action.call("clear")
	return ""


static func _list_ids(ids: PackedStringArray, args: PackedStringArray) -> String:
	var filter := args[0] if not args.is_empty() else ""
	var shown := PackedStringArray()
	for id in ids:
		if filter.is_empty() or id.contains(filter):
			shown.append(id)
	return "%d: %s" % [shown.size(), ", ".join(shown)]
