class_name CommandRegistry
extends RefCounted
## Developer console commands. Each command has a namespaced id; it is typed
## by its short name ("give") or, when two mods use the same name, by its full
## id ("example:give").
##
## Handler signature: func(context: CommandContext, args: PackedStringArray) -> String

class Command:
	extends RefCounted
	var id: String
	var name: String
	var usage: String
	var description: String
	var handler: Callable
	var needs_world: bool

var _by_id: Dictionary = {}
var _by_name: Dictionary = {}


func register(id: String, usage: String, description: String, handler: Callable, needs_world: bool = true) -> Error:
	if not NamespacedId.is_valid(id):
		Log.error("CONSOLE", "Invalid command id '%s': %s" % [id, NamespacedId.explain_invalid(id)])
		return ERR_INVALID_PARAMETER
	if _by_id.has(id):
		Log.error("CONSOLE", "Command '%s' is already registered" % id)
		return ERR_ALREADY_EXISTS
	var command := Command.new()
	command.id = id
	command.name = NamespacedId.path_of(id)
	command.usage = usage
	command.description = description
	command.handler = handler
	command.needs_world = needs_world
	_by_id[id] = command
	if not _by_name.has(command.name):
		_by_name[command.name] = command
	return OK


func find(name_or_id: String) -> Command:
	if _by_id.has(name_or_id):
		return _by_id[name_or_id]
	return _by_name.get(name_or_id)


func all() -> Array:
	var list := _by_id.values()
	list.sort_custom(func(a: Command, b: Command) -> bool: return a.name < b.name)
	return list


## Parses and runs a command line ("/give blockyworld:stone 10").
func execute(line: String, context: CommandContext) -> String:
	var text := line.strip_edges()
	if text.begins_with("/"):
		text = text.substr(1)
	if text.is_empty():
		return ""
	var parts := text.split(" ", false)
	var command := find(parts[0])
	if command == null:
		return "Unknown command '%s'. Type /help." % parts[0]
	if command.needs_world and context.world == null:
		return "/%s needs a loaded world." % command.name
	var result: Variant = command.handler.call(context, parts.slice(1))
	return str(result) if result != null else ""
