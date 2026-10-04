class_name MovementMode
extends RefCounted
## One way of moving (walking, flying; later swimming, climbing, riding).
## MovementComponent delegates to the active mode each physics tick.

var mode_id: String = ""


func enter(_entity: Entity) -> void:
	pass


func tick(_entity: Entity, _movement: MovementComponent, _delta: float) -> void:
	pass


func exit(_entity: Entity) -> void:
	pass


static func approach(current: Vector3, target: Vector3, rate: float) -> Vector3:
	var horizontal := Vector3(current.x, 0, current.z).move_toward(Vector3(target.x, 0, target.z), rate)
	return Vector3(horizontal.x, current.y, horizontal.z)
