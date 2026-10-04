class_name EntityComponent
extends Node
## Base for entity behaviour pieces. An entity is composed of components
## (movement, health, AI, ...) declared in its JSON definition, instead of a
## deep class hierarchy.
##
## Lifecycle: configure(params) -> attached(entity) -> physics_tick(delta)
## every physics frame (in declaration order) -> detached().

var entity: Entity
var type_id: String = ""
var enabled := true


## Receives the JSON parameters of this component. Return false to reject
## invalid parameters (the component is then not added).
func configure(_params: Dictionary) -> bool:
	return true


func attached() -> void:
	pass


func physics_tick(_delta: float) -> void:
	pass


func detached() -> void:
	pass


## Serializable state (persistence of entities arrives in 0.2).
func save_state() -> Dictionary:
	return {}


func load_state(_state: Dictionary) -> void:
	pass
