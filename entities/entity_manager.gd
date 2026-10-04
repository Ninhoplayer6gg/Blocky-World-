class_name EntityManager
extends Node3D
## Creates, tracks and removes entities in a world. Entities are assembled
## from their definition: collision box, model and components.

var world: World
var _content: GameContent
var _entities: Dictionary = {}


func setup(owner_world: World, content: GameContent) -> void:
	world = owner_world
	_content = content
	name = "Entities"


## Spawns an entity of type `entity_id` with its feet at `position`.
## Returns null (and logs why) if the type is unknown.
func spawn(entity_id: String, position: Vector3, entity_script: Script = null) -> Entity:
	var definition := _content.registries.entities.get_entity(entity_id)
	if definition == null:
		Log.error("ENTITY", "Cannot spawn unknown entity '%s'" % entity_id)
		return null
	var entity: Entity = entity_script.new() if entity_script != null else Entity.new()
	entity.uuid = _make_uuid()
	entity.world = world
	entity.setup(definition, _content.registries.attributes)
	var model := CharacterModel.new()
	model.name = "Model"
	var model_definition := _content.registries.models.get_model(definition.model)
	model.build(model_definition, _content.resources, Vector3(definition.width, definition.height, definition.width))
	entity.set_model(model)
	add_child(entity)
	entity.global_position = position
	for params in definition.components:
		var component := _content.registries.components.create(params.type) as EntityComponent
		if component == null:
			Log.error("ENTITY", "Component %s of %s is not an EntityComponent" % [params.type, entity_id])
			continue
		component.type_id = params.type
		component.name = NamespacedId.path_of(params.type).capitalize().replace(" ", "")
		if not component.configure(params):
			Log.error("ENTITY", "Component %s of %s rejected its parameters" % [params.type, entity_id])
			component.free()
			continue
		entity.add_component(component)
	_entities[entity.uuid] = entity
	entity.removed.connect(_on_entity_removed)
	world.events.emit(Events.ENTITY_SPAWNED, {"entity": entity})
	return entity


func despawn(entity: Entity) -> void:
	if not _entities.has(entity.uuid):
		return
	entity.remove()


func get_all() -> Array:
	return _entities.values()


func count() -> int:
	return _entities.size()


func find_by_uuid(uuid: String) -> Entity:
	return _entities.get(uuid)


func _on_entity_removed(entity: Entity) -> void:
	_entities.erase(entity.uuid)
	world.events.emit(Events.ENTITY_REMOVED, {"entity": entity})


static func _make_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	return bytes.hex_encode()
