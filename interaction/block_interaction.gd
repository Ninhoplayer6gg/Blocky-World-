class_name BlockInteraction
extends Node3D
## Player <-> world interaction: targets blocks (voxel raycast) and entities
## (physics ray), breaks with the primary action, places with the secondary,
## picks blocks with the middle button. Placement never overlaps entities,
## including the player.

signal target_changed(hit: VoxelRaycast.Hit)

var player: Player
var target: VoxelRaycast.Hit
var target_entity: Entity
## 0..1 progress of breaking the targeted block.
var break_progress := 0.0
var _break_cell := Vector3i.ZERO
var _repeat_timer := 0.0
var _highlight: MeshInstance3D


func setup(owner_player: Player) -> void:
	player = owner_player
	_highlight = MeshInstance3D.new()
	_highlight.name = "Highlight"
	_highlight.mesh = _make_outline_mesh()
	_highlight.top_level = true
	_highlight.visible = false
	add_child(_highlight)


func process_interaction(delta: float) -> void:
	_update_target()
	_repeat_timer = maxf(_repeat_timer - delta, 0.0)
	if Input.is_action_just_pressed(InputActions.ATTACK) and target_entity != null:
		_attack_entity(target_entity)
	elif Input.is_action_pressed(InputActions.ATTACK) and target != null and target_entity == null:
		_progress_break(delta)
	else:
		reset_progress()
	if Input.is_action_just_pressed(InputActions.USE):
		_repeat_timer = 0.0
	if Input.is_action_pressed(InputActions.USE) and _repeat_timer <= 0.0 and target != null:
		_repeat_timer = GameConfig.PLACE_REPEAT_SECONDS
		try_place()
	if Input.is_action_just_pressed(InputActions.PICK_BLOCK) and target != null:
		pick_block()


func clear_target() -> void:
	if target != null:
		target = null
		target_changed.emit(null)
	target_entity = null
	reset_progress()
	if _highlight != null:
		_highlight.visible = false


func reset_progress() -> void:
	break_progress = 0.0


## Places the selected block item against the targeted face.
func try_place() -> bool:
	if target == null:
		return false
	var stack := player.get_selected_stack()
	if stack == null:
		return false
	var item := player.world.content.registries.items.get_item(stack.item_id)
	if item == null or not item.is_placeable():
		return false
	var block_id := player.world.content.registries.blocks.get_runtime_id(item.places_block)
	if block_id <= 0:
		return false
	var hit_definition := player.world.get_block_definition(target.position)
	var cell := target.position if hit_definition != null and hit_definition.replaceable else target.adjacent()
	if not player.world.place_block(cell, block_id, player):
		return false
	if not player.world.creative:
		player.inventory.remove_from_slot(player.selected_slot, 1)
	return true


## Breaks the targeted block immediately (creative / commands).
func break_target() -> bool:
	if target == null:
		return false
	var drops: Variant = player.world.break_block(target.position, player)
	if drops == null:
		return false
	if not player.world.creative:
		for stack in drops:
			var left := player.inventory.add_item(stack)
			if left > 0:
				player.message.emit("Inventory full: %d %s lost" % [left, stack.item_id])
	reset_progress()
	_update_target()
	return true


func pick_block() -> void:
	var definition := player.world.get_block_definition(target.position)
	if definition == null or not player.world.content.registries.items.has(definition.id):
		return
	var slot := player.inventory.find_item(definition.id)
	if slot >= 0 and slot < Player.HOTBAR_SIZE:
		player.select_slot(slot)
	elif player.world.creative:
		player.inventory.set_slot(player.selected_slot, ItemStack.create(definition.id, 64))


func _progress_break(delta: float) -> void:
	if target.position != _break_cell:
		_break_cell = target.position
		break_progress = 0.0
	var definition := player.world.get_block_definition(target.position)
	if definition == null or not definition.is_breakable():
		break_progress = 0.0
		return
	if player.world.creative:
		if _repeat_timer <= 0.0:
			_repeat_timer = GameConfig.PLACE_REPEAT_SECONDS
			break_target()
		return
	var duration := definition.break_time()
	break_progress = 1.0 if duration <= 0.0 else break_progress + delta / duration
	if break_progress >= 1.0:
		break_target()


func _attack_entity(entity: Entity) -> void:
	var health := entity.get_component("blockyworld:health") as HealthComponent
	if health == null:
		return
	var amount := player.attributes.get_value(AttributeRegistry.ATTACK_DAMAGE)
	health.damage(amount, player.definition.id)


func _update_target() -> void:
	var origin := player.get_look_origin()
	var direction := player.get_look_direction()
	var hit := player.world.raycast_block(origin, direction, GameConfig.REACH_DISTANCE)
	target_entity = _raycast_entity(origin, direction, hit.distance if hit != null else GameConfig.REACH_DISTANCE)
	var changed := (hit == null) != (target == null) or (hit != null and target != null and (hit.position != target.position or hit.normal != target.normal))
	target = hit
	if changed:
		target_changed.emit(target)
	_highlight.visible = target != null and target_entity == null
	if _highlight.visible:
		_highlight.global_transform = Transform3D(Basis.IDENTITY, Vector3(target.position) - Vector3.ONE * 0.002)


func _raycast_entity(origin: Vector3, direction: Vector3, max_distance: float) -> Entity:
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance, 1 << (GameConfig.LAYER_ENTITIES - 1))
	query.exclude = [player.get_rid()]
	var result := space.intersect_ray(query)
	return result.collider as Entity if not result.is_empty() and result.collider is Entity else null


static func _make_outline_mesh() -> ArrayMesh:
	var size := 1.004
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1) * size)
	var lines := PackedVector3Array()
	for i in 8:
		for bit in [1, 2, 4]:
			if i & bit == 0:
				lines.append(corners[i])
				lines.append(corners[i | bit])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.05, 0.05, 0.05)
	mesh.surface_set_material(0, material)
	return mesh
