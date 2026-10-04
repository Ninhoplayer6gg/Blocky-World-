class_name BlockDefinition
extends RefCounted
## Data describing one block type. Created from JSON content packs (base game
## and mods alike) by ContentLoader. Behaviour beyond data (scripts) arrives
## with the Lua API; see docs/Modding.md.

enum RenderLayer { NONE, OPAQUE, CUTOUT }

## Face indices used by the mesher and texture lookup.
enum Face { EAST, WEST, TOP, BOTTOM, SOUTH, NORTH }
const FACE_KEYS: PackedStringArray = ["east", "west", "top", "bottom", "south", "north"]

var id: String = ""
## Numeric id used inside chunk arrays for this session only. Never saved;
## saves store namespaced ids through the world palette.
var runtime_id: int = -1
var display_name: String = ""
## Face key -> texture asset id. Keys: all, side, top, bottom, east, west,
## south, north (most specific wins).
var textures: Dictionary = {}
## Colour of the generated placeholder texture used while the real texture
## is missing. Per-face overrides use the same keys as `textures`.
var placeholder_color: Color = Color(1, 0, 1)
var placeholder_colors: Dictionary = {}
## Seconds to break = hardness * GameConfig.BREAK_SECONDS_PER_HARDNESS.
## Negative means unbreakable.
var hardness: float = 1.0
var solid: bool = true
var transparent: bool = false
var collision: bool = true
## Emitted light level 0-15. Stored for the future lighting engine; not
## rendered in 0.1.
var light: int = 0
var render_layer: RenderLayer = RenderLayer.OPAQUE
## Cull faces between two blocks of this same type (glass next to glass).
var cull_same: bool = true
var replaceable: bool = false
var tags: PackedStringArray = PackedStringArray()
## [{item: String, count: int}]. Empty -> drops its own block item.
var drops: Array = []
## Whether a block item is generated automatically, and its overrides.
var has_item: bool = true
var item_overrides: Dictionary = {}
## Mod that registered this block.
var source_mod: String = ""
## True for placeholders standing in for blocks whose mod is missing; the
## original id is preserved so saving does not lose data.
var missing: bool = false


func is_air() -> bool:
	return render_layer == RenderLayer.NONE and not collision and not solid


func is_opaque_cube() -> bool:
	return render_layer == RenderLayer.OPAQUE and not transparent


func is_breakable() -> bool:
	return hardness >= 0.0


func break_time() -> float:
	return maxf(hardness, 0.0) * GameConfig.BREAK_SECONDS_PER_HARDNESS


func has_tag(tag: String) -> bool:
	return tags.has(tag)


## Texture asset id for a face, following most-specific-wins resolution.
func get_face_texture(face: int) -> String:
	var key := FACE_KEYS[face]
	if textures.has(key):
		return textures[key]
	if face != Face.TOP and face != Face.BOTTOM and textures.has("side"):
		return textures["side"]
	return textures.get("all", "")


func get_face_placeholder_color(face: int) -> Color:
	var key := FACE_KEYS[face]
	if placeholder_colors.has(key):
		return placeholder_colors[key]
	if face != Face.TOP and face != Face.BOTTOM and placeholder_colors.has("side"):
		return placeholder_colors["side"]
	return placeholder_colors.get("all", placeholder_color)


## Copies data fields from `other` keeping identity (id, runtime_id). Used by
## hot reload so chunk arrays stay valid.
func copy_data_from(other: BlockDefinition) -> void:
	display_name = other.display_name
	textures = other.textures.duplicate()
	placeholder_color = other.placeholder_color
	placeholder_colors = other.placeholder_colors.duplicate()
	hardness = other.hardness
	solid = other.solid
	transparent = other.transparent
	collision = other.collision
	light = other.light
	render_layer = other.render_layer
	cull_same = other.cull_same
	replaceable = other.replaceable
	tags = other.tags.duplicate()
	drops = other.drops.duplicate(true)
	has_item = other.has_item
	item_overrides = other.item_overrides.duplicate(true)
	missing = other.missing
