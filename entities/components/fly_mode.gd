class_name FlyMode
extends MovementMode
## Free flight without gravity (development tool now; flying creatures and
## abilities later). Collision still applies.

const SPEED_MULTIPLIER := 2.5


func _init() -> void:
	mode_id = "fly"


func tick(entity: Entity, movement: MovementComponent, delta: float) -> void:
	var intent := entity.intent
	var speed := movement.get_speed(intent.sprint) * SPEED_MULTIPLIER
	var target := intent.direction.limit_length(1.0) * speed
	target.y = intent.vertical * speed
	entity.velocity = entity.velocity.move_toward(target, movement.ground_acceleration * 2.0 * delta)
	entity.move_and_slide()
