class_name ModelRegistry
extends Registry


func _init() -> void:
	super("blockyworld:models")


func get_model(id: String) -> ModelDefinition:
	return get_entry(id) as ModelDefinition
