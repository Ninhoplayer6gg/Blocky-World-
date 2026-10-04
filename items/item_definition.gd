class_name ItemDefinition
extends RefCounted
## Data describing one item type.

var id: String = ""
var display_name: String = ""
## Texture asset id for the inventory icon ("" -> derived from places_block or
## a generated placeholder).
var icon: String = ""
var placeholder_color: Color = Color(1, 0, 1)
var max_stack: int = 64
## Block id placed when the item is used on a block face ("" -> not placeable).
var places_block: String = ""
var tags: PackedStringArray = PackedStringArray()
## Free-form, namespaced properties for future systems (tools, food, ...).
var properties: Dictionary = {}
var source_mod: String = ""


func is_placeable() -> bool:
	return not places_block.is_empty()


func copy_data_from(other: ItemDefinition) -> void:
	display_name = other.display_name
	icon = other.icon
	placeholder_color = other.placeholder_color
	max_stack = other.max_stack
	places_block = other.places_block
	tags = other.tags.duplicate()
	properties = other.properties.duplicate(true)
