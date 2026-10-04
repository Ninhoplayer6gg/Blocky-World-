class_name VoxelRaycast
extends RefCounted
## Exact grid traversal (Amanatides & Woo) against block data. Independent of
## physics, so it reports the precise block and face hit.

class Hit:
	extends RefCounted
	var position: Vector3i
	## Outward normal of the face that was hit (zero if the ray started inside).
	var normal: Vector3i
	var block_id: int
	var distance: float

	func adjacent() -> Vector3i:
		return position + normal


## `target_at` is Callable(Vector3i) -> int returning a block id > 0 when the
## cell should stop the ray. Returns null when nothing is hit within range.
static func cast(origin: Vector3, direction: Vector3, max_distance: float, target_at: Callable) -> Hit:
	if direction.length_squared() < 0.000001:
		return null
	var dir := direction.normalized()
	var cell := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(_sign(dir.x), _sign(dir.y), _sign(dir.z))
	var t_delta := Vector3(_inv_abs(dir.x), _inv_abs(dir.y), _inv_abs(dir.z))
	var t_max := Vector3(
		_first_boundary(origin.x, cell.x, step.x, t_delta.x),
		_first_boundary(origin.y, cell.y, step.y, t_delta.y),
		_first_boundary(origin.z, cell.z, step.z, t_delta.z))
	var normal := Vector3i.ZERO
	var distance := 0.0
	while distance <= max_distance:
		var block_id: int = target_at.call(cell)
		if block_id > 0:
			var hit := Hit.new()
			hit.position = cell
			hit.normal = normal
			hit.block_id = block_id
			hit.distance = distance
			return hit
		if t_max.x < t_max.y and t_max.x < t_max.z:
			cell.x += step.x
			distance = t_max.x
			t_max.x += t_delta.x
			normal = Vector3i(-step.x, 0, 0)
		elif t_max.y < t_max.z:
			cell.y += step.y
			distance = t_max.y
			t_max.y += t_delta.y
			normal = Vector3i(0, -step.y, 0)
		else:
			cell.z += step.z
			distance = t_max.z
			t_max.z += t_delta.z
			normal = Vector3i(0, 0, -step.z)
	return null


static func _sign(value: float) -> int:
	if value > 0.0:
		return 1
	if value < 0.0:
		return -1
	return 0


static func _inv_abs(value: float) -> float:
	return INF if is_zero_approx(value) else absf(1.0 / value)


static func _first_boundary(origin: float, cell: int, step: int, t_delta: float) -> float:
	if step > 0:
		return (cell + 1 - origin) * t_delta
	if step < 0:
		return (origin - cell) * t_delta
	return INF
