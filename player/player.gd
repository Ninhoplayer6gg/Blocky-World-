class_name Player
extends Entity
## The local player: an ordinary entity ("blockyworld:player" from the base
## content pack) plus input, camera, inventory and block interaction. Movement
## itself is done by the generic movement component, driven by MovementIntent.

signal selected_slot_changed(index: int)
signal message(text: String)

const HOTBAR_SIZE := InputActions.HOTBAR_SLOT_COUNT
const INVENTORY_SIZE := 36
const THIRD_PERSON_DISTANCE := 4.0

var inventory: Inventory
var selected_slot := 0
var input_enabled := true
var third_person := false
var settings: Settings
var head: Node3D
var camera: Camera3D
var interaction: BlockInteraction
var _last_cell := Vector3i(2147483647, 0, 0)


func setup_player(content: GameContent, player_settings: Settings) -> void:
	settings = player_settings
	inventory = Inventory.new(INVENTORY_SIZE, content.registries.items)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, definition.eye_height, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.05
	camera.far = 1000.0
	camera.fov = settings.fov
	head.add_child(camera)
	camera.make_current()
	interaction = BlockInteraction.new()
	interaction.name = "Interaction"
	add_child(interaction)
	interaction.setup(self)
	settings.changed.connect(_on_settings_changed)
	_update_view()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := deg_to_rad(settings.mouse_sensitivity)
		rotation.y -= event.relative.x * sensitivity
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed(InputActions.HOTBAR_NEXT):
		select_slot(posmod(selected_slot + 1, HOTBAR_SIZE))
	elif event.is_action_pressed(InputActions.HOTBAR_PREV):
		select_slot(posmod(selected_slot - 1, HOTBAR_SIZE))
	elif event.is_action_pressed(InputActions.TOGGLE_FLY):
		if world.creative:
			toggle_fly()
	elif event.is_action_pressed(InputActions.TOGGLE_VIEW):
		third_person = not third_person
		_update_view()
	else:
		for i in HOTBAR_SIZE:
			if event.is_action_pressed(InputActions.hotbar_action(i)):
				select_slot(i)
				return


func _physics_process(delta: float) -> void:
	_read_movement_input()
	super(delta)
	var cell := VoxelCoords.position_to_block(global_position)
	if cell != _last_cell:
		var previous := _last_cell
		_last_cell = cell
		if world != null:
			world.events.emit(Events.PLAYER_MOVED, {"player": self, "from": previous, "to": cell})


func _process(delta: float) -> void:
	if world != null:
		world.focus_position = global_position
	if input_enabled and not frozen:
		interaction.process_interaction(delta)
	else:
		interaction.clear_target()


func select_slot(index: int) -> void:
	selected_slot = clampi(index, 0, HOTBAR_SIZE - 1)
	interaction.reset_progress()
	selected_slot_changed.emit(selected_slot)


func get_selected_stack() -> ItemStack:
	return inventory.get_slot(selected_slot)


func toggle_fly() -> bool:
	var movement := get_component("blockyworld:movement") as MovementComponent
	if movement == null or not movement.has_mode("fly"):
		return false
	var flying := movement.get_mode() != "fly"
	movement.set_mode("fly" if flying else "walk")
	message.emit("Flying" if flying else "Walking")
	return flying


func get_look_origin() -> Vector3:
	return head.global_position


func get_look_direction() -> Vector3:
	return -head.global_transform.basis.z


func teleport(position: Vector3) -> void:
	global_position = position
	velocity = Vector3.ZERO
	frozen = true


func save_state() -> Dictionary:
	var component_state := {}
	for component in components:
		var state := component.save_state()
		if not state.is_empty():
			component_state[component.type_id] = state
	return {
		"version": 1,
		# Entities live under World/Entities at the origin, so local == global;
		# local also works while the tree is being torn down.
		"position": [position.x, position.y, position.z],
		"yaw": rotation.y,
		"pitch": head.rotation.x,
		"selected_slot": selected_slot,
		"inventory": inventory.to_array(),
		"components": component_state,
	}


func load_state(data: Dictionary) -> void:
	var position: Array = data.get("position", [])
	if position.size() == 3:
		global_position = Vector3(float(position[0]), float(position[1]), float(position[2]))
	rotation.y = float(data.get("yaw", 0.0))
	head.rotation.x = float(data.get("pitch", 0.0))
	inventory.load_array(data.get("inventory", []))
	select_slot(int(data.get("selected_slot", 0)))
	var component_state: Dictionary = data.get("components", {})
	for component in components:
		if component_state.has(component.type_id):
			component.load_state(component_state[component.type_id])


func _read_movement_input() -> void:
	intent.clear()
	if not input_enabled:
		return
	var input := Input.get_vector(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.MOVE_FORWARD, InputActions.MOVE_BACKWARD)
	intent.direction = Basis(Vector3.UP, rotation.y) * Vector3(input.x, 0, input.y)
	intent.jump = Input.is_action_pressed(InputActions.JUMP)
	intent.sprint = Input.is_action_pressed(InputActions.SPRINT)
	intent.crouch = Input.is_action_pressed(InputActions.CROUCH)
	intent.vertical = (1.0 if intent.jump else 0.0) - (1.0 if intent.crouch else 0.0)


func _update_view() -> void:
	camera.position = Vector3(0, 0, THIRD_PERSON_DISTANCE) if third_person else Vector3.ZERO
	if model != null:
		model.visible = third_person


func _on_settings_changed() -> void:
	camera.fov = settings.fov
