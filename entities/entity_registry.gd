class_name EntityRegistry
extends Registry


func _init() -> void:
	super("blockyworld:entities")


func get_entity(id: String) -> EntityDefinition:
	return get_entry(id) as EntityDefinition
