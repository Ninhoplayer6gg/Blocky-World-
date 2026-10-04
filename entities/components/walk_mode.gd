class_name WalkMode
extends MovementMode
## Ground locomotion with gravity, jumping and reduced air control.


func _init() -> void:
	mode_id = "walk"


func tick(entity: Entity, movement: MovementComponent, delta: float) -> void:
	var intent := entity.intent
	var velocity := entity.velocity
	var speed := movement.get_speed(intent.sprint)
	var target := intent.direction.limit_length(1.0) * speed
	var on_floor := entity.is_on_floor()
	var rate := (movement.ground_acceleration if on_floor else movement.air_acceleration) * delta
	velocity = approach(velocity, target, rate)
	if on_floor:
		if intent.jump:
			velocity.y = movement.get_jump_velocity()
		else:
			velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y = maxf(velocity.y - movement.gravity * delta, -movement.terminal_velocity)
	entity.velocity = velocity
	entity.move_and_slide()
	if entity.is_on_ceiling() and entity.velocity.y > 0.0:
		entity.velocity.y = 0.0
