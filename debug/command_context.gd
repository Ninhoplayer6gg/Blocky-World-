class_name CommandContext
extends RefCounted
## What a console command can act on. World/player are null in menus.

var content: GameContent
var world: World
var player: Player
var registry: CommandRegistry
## Callable() -> String, provided by the game to run a content reload.
var reload: Callable
## Callable(String) for UI-only actions (e.g. "clear").
var ui_action: Callable


## Parses a coordinate token: number, "~" or "~offset" relative to `base`.
static func parse_coordinate(token: String, base: float) -> Variant:
	if token.begins_with("~"):
		var rest := token.substr(1)
		if rest.is_empty():
			return base
		return base + rest.to_float() if rest.is_valid_float() else null
	return token.to_float() if token.is_valid_float() else null


func parse_position(args: PackedStringArray, offset: int) -> Variant:
	if args.size() < offset + 3:
		return null
	var base := player.global_position if player != null else Vector3.ZERO
	var x: Variant = parse_coordinate(args[offset], floorf(base.x))
	var y: Variant = parse_coordinate(args[offset + 1], floorf(base.y))
	var z: Variant = parse_coordinate(args[offset + 2], floorf(base.z))
	if x == null or y == null or z == null:
		return null
	return Vector3(x, y, z)


func qualify(id: String) -> String:
	return NamespacedId.qualify(id, GameInfo.CORE_NAMESPACE)
