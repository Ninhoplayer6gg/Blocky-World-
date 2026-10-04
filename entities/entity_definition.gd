class_name EntityDefinition
extends RefCounted
## Data describing an entity type as a composition of components.
##
## Example: a future dragon = components movement(flying) + health +
## hostile_ai + fire_attack + loot, each configured by JSON parameters.

var id: String = ""
var display_name: String = ""
## Model id from the model registry.
var model: String = ""
## Collision box (width is used for x and z).
var width: float = 0.6
var height: float = 1.8
var eye_height: float = 1.62
## Attribute id -> base value.
var attributes: Dictionary = {}
## [{type: component id, ...params}] in execution order.
var components: Array = []
var tags: PackedStringArray = PackedStringArray()
var source_mod: String = ""
