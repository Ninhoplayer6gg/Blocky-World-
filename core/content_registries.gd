class_name ContentRegistries
extends RefCounted
## Every registry the game exposes. Base content and mods register into the
## very same instances (no special path for vanilla content).

var blocks := BlockRegistry.new()
var items := ItemRegistry.new()
var attributes := AttributeRegistry.new()
var biomes := BiomeRegistry.new()
var models := ModelRegistry.new()
var entities := EntityRegistry.new()
## Code-backed types referenced from JSON by id.
var components := ScriptTypeRegistry.new("blockyworld:entity_components")
var generators := ScriptTypeRegistry.new("blockyworld:world_generators")
var features := ScriptTypeRegistry.new("blockyworld:terrain_features")


func all() -> Array[Registry]:
	return [blocks, items, attributes, biomes, models, entities, components, generators, features]


func freeze_all() -> void:
	for registry in all():
		registry.freeze()
