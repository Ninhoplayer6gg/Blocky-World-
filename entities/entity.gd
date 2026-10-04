class_name Entity
extends CharacterBody3D
## Anything that lives in the world besides blocks. Behaviour comes from
## EntityComponent children; data from its EntityDefinition and AttributeSet.
## The origin is at the feet, centred.

signal removed(entity: Entity)

var definition: EntityDefinition
var uuid: String = ""
var attributes: AttributeSet
var world: World
var model: CharacterModel
var intent := MovementIntent.new()
var components: Array[EntityComponent] = []
## Physics is suspended until the terrain below has collision.
var frozen := true
var collision_shape: CollisionShape3D


func setup(entity_definition: EntityDefinition, attribute_registry: AttributeRegistry) -> void:
	definition = entity_definition
	name = "%s_%s" % [NamespacedId.get_path(definition.id), uuid.substr(0, 8)]
	attributes = AttributeSet.new(attribute_registry)
	for attribute_id in definition.attributes:
		attributes.set_base(attribute_id, definition.attributes[attribute_id])
	collision_layer = 1 << (GameConfig.LAYER_ENTITIES - 1)
	collision_mask = 1 << (GameConfig.LAYER_WORLD - 1)
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.05
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(definition.width, definition.height, definition.width)
	collision_shape.shape = box
	collision_shape.position = Vector3(0, definition.height * 0.5, 0)
	add_child(collision_shape)


func add_component(component: EntityComponent) -> void:
	component.entity = self
	components.append(component)
	add_child(component)
	component.attached()


func get_component(component_type: String) -> EntityComponent:
	for component in components:
		if component.type_id == component_type:
			return component
	return null


func set_model(character_model: CharacterModel) -> void:
	if model != null:
		model.queue_free()
	model = character_model
	add_child(model)


func _physics_process(delta: float) -> void:
	if frozen:
		if world == null or not world.has_collision_at(global_position):
			return
		frozen = false
	for component in components:
		if component.enabled:
			component.physics_tick(delta)
	if model != null:
		model.update_locomotion(Vector2(velocity.x, velocity.z).length(), is_on_floor(), velocity.y, delta)


func get_eye_position() -> Vector3:
	return global_position + Vector3(0, definition.eye_height, 0)


## World-space bounding box of the collision box.
func get_world_aabb() -> AABB:
	var half := definition.width * 0.5
	return AABB(global_position - Vector3(half, 0, half), Vector3(definition.width, definition.height, definition.width))


func remove() -> void:
	for component in components:
		component.detached()
	removed.emit(self)
	queue_free()
