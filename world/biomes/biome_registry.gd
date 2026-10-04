class_name BiomeRegistry
extends Registry


func _init() -> void:
	super("blockyworld:biomes")


func get_biome(id: String) -> BiomeDefinition:
	return get_entry(id) as BiomeDefinition
