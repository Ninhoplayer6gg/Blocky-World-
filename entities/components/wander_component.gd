class_name WanderComponent
extends EntityComponent
## "blockyworld:wander": minimal AI that alternates between idling and
## walking in a random direction, hopping over 1-block steps.
## Params: speed_factor (0.5), min_idle (1.0), max_idle (4.0), max_walk (3.0).

var speed_factor := 0.5
var min_idle := 1.0
var max_idle := 4.0
var max_walk := 3.0
var _timer := 0.0
var _walking := false
var _direction := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func configure(params: Dictionary) -> bool:
	speed_factor = clampf(float(params.get("speed_factor", speed_factor)), 0.0, 1.0)
	min_idle = maxf(float(params.get("min_idle", min_idle)), 0.1)
	max_idle = maxf(float(params.get("max_idle", max_idle)), min_idle)
	max_walk = maxf(float(params.get("max_walk", max_walk)), 0.5)
	return true


func attached() -> void:
	_rng.seed = hash(entity.uuid)
	_timer = _rng.randf_range(min_idle, max_idle)


func physics_tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_walking = not _walking
		if _walking:
			var angle := _rng.randf() * TAU
			_direction = Vector3(cos(angle), 0, sin(angle))
			_timer = _rng.randf_range(0.5, max_walk)
		else:
			_timer = _rng.randf_range(min_idle, max_idle)
	entity.intent.direction = _direction * speed_factor if _walking else Vector3.ZERO
	entity.intent.jump = _walking and entity.is_on_wall() and entity.is_on_floor()
	if _walking and _direction != Vector3.ZERO:
		entity.rotation.y = lerp_angle(entity.rotation.y, atan2(_direction.x, _direction.z), minf(delta * 8.0, 1.0))
