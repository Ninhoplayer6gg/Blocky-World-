class_name AttributeRegistry
extends Registry

const MAX_HEALTH := "blockyworld:max_health"
const MOVEMENT_SPEED := "blockyworld:movement_speed"
const JUMP_STRENGTH := "blockyworld:jump_strength"
const ATTACK_DAMAGE := "blockyworld:attack_damage"
const ARMOR := "blockyworld:armor"


func _init() -> void:
	super("blockyworld:attributes")


func get_attribute(id: String) -> AttributeDefinition:
	return get_entry(id) as AttributeDefinition
