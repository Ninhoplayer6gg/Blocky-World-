class_name WorldHash
extends RefCounted
## Deterministic integer hashing for world generation. Same inputs give the
## same output on every platform (64-bit wrapping integer math), which keeps
## worlds reproducible from their seed.


static func hash3(world_seed: int, x: int, y: int, z: int) -> int:
	var h := world_seed ^ (x * 0x27D4EB2D) ^ (y * 0x165667B1) ^ (z * 0x1B873593)
	h = (h ^ (h >> 15)) * 0x2C1B3C6D
	h = (h ^ (h >> 12)) * 0x297A2D39
	h = h ^ (h >> 15)
	return h & 0x7FFFFFFF


## Uniform float in [0, 1).
static func hash01(world_seed: int, x: int, y: int, z: int) -> float:
	return float(hash3(world_seed, x, y, z) & 0xFFFFFF) / 16777216.0


## 32-bit seed for noise generators derived from the world seed and a salt.
static func sub_seed(world_seed: int, salt: int) -> int:
	return hash3(world_seed, salt, salt * 31, salt * 17)


## Numeric seed from user text: integers are used directly, anything else is
## hashed. The result is stored in world.json, never recomputed.
static func seed_from_text(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return randi()
	if trimmed.is_valid_int():
		return trimmed.to_int()
	var h := 1469598103934665603
	for code in trimmed.to_utf8_buffer():
		h = (h ^ code) * 1099511628211
	return h & 0x7FFFFFFFFFFFFFFF
