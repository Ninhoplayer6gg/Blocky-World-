class_name MovementComponent
extends EntityComponent
## "blockyworld:movement": moves the entity according to its MovementIntent
## using the active MovementMode. Speed and jump come from attributes, so
## effects/equipment from mods can change them through modifiers.
##
## Params: gravity, ground_acceleration, air_acceleration, sprint_multiplier,
## terminal_velocity, modes (["walk", "fly"]).

const KNOWN_MODES: PackedStringArray = ["walk", "fly"]

var gravity := 28.0
var ground_acceleration := 60.0
var air_acceleration := 14.0
var sprint_multiplier := 1.35
var terminal_velocity := 60.0
var _modes: Dictionary = {}
var _active: MovementMode


func configure(params: Dictionary) -> bool:
	gravity = float(params.get("gravity", gravity))
	ground_acceleration = float(params.get("ground_acceleration", ground_acceleration))
	air_acceleration = float(params.get("air_acceleration", air_acceleration))
	sprint_multiplier = float(params.get("sprint_multiplier", sprint_multiplier))
	terminal_velocity = float(params.get("terminal_velocity", terminal_velocity))
	var allowed: Array = params.get("modes", ["walk"])
	for mode_id in allowed:
		var mode := _create_mode(str(mode_id))
		if mode == null:
			Log.error("ENTITY", "Unknown movement mode '%s' (known: %s)" % [mode_id, ", ".join(KNOWN_MODES)])
			return false
		_modes[mode_id] = mode
	if _modes.is_empty():
		return false
	_active = _modes.get("walk", _modes.values()[0])
	return true


func physics_tick(delta: float) -> void:
	_active.tick(entity, self, delta)


func get_mode() -> String:
	return _active.mode_id


func has_mode(mode_id: String) -> bool:
	return _modes.has(mode_id)


func set_mode(mode_id: String) -> bool:
	if not _modes.has(mode_id):
		return false
	if _active != null:
		_active.exit(entity)
	_active = _modes[mode_id]
	_active.enter(entity)
	return true


func get_speed(sprinting: bool) -> float:
	var speed := entity.attributes.get_value(AttributeRegistry.MOVEMENT_SPEED)
	return speed * (sprint_multiplier if sprinting else 1.0)


func get_jump_velocity() -> float:
	return entity.attributes.get_value(AttributeRegistry.JUMP_STRENGTH)


static func _create_mode(mode_id: String) -> MovementMode:
	match mode_id:
		"walk":
			return WalkMode.new()
		"fly":
			return FlyMode.new()
	return null


func save_state() -> Dictionary:
	return {"mode": get_mode()}


func load_state(state: Dictionary) -> void:
	set_mode(str(state.get("mode", "walk")))
