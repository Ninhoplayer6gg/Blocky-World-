extends TestCase
## Raycast, events, attributes.


func _solid_at(cells: Array) -> Callable:
	return func(cell: Vector3i) -> int: return 1 if cells.has(cell) else 0


func test_raycast_hits_block_and_face() -> void:
	var hit := VoxelRaycast.cast(Vector3(0.5, 1.5, 0.5), Vector3(1, 0, 0), 10.0, _solid_at([Vector3i(4, 1, 0)]))
	assert_not_null(hit)
	assert_eq(hit.position, Vector3i(4, 1, 0))
	assert_eq(hit.normal, Vector3i(-1, 0, 0), "west face hit")
	assert_eq(hit.adjacent(), Vector3i(3, 1, 0), "placement cell")
	assert_true(absf(hit.distance - 3.5) < 0.001)


func test_raycast_downwards_negative_coords_and_range() -> void:
	var hit := VoxelRaycast.cast(Vector3(-2.5, 10.2, -7.5), Vector3(0, -1, 0), 20.0, _solid_at([Vector3i(-3, 4, -8)]))
	assert_eq(hit.position, Vector3i(-3, 4, -8))
	assert_eq(hit.normal, Vector3i(0, 1, 0), "top face")
	assert_null(VoxelRaycast.cast(Vector3(0.5, 0.5, 0.5), Vector3(0, 0, 1), 3.0, _solid_at([Vector3i(0, 0, 10)])), "out of reach")
	assert_null(VoxelRaycast.cast(Vector3.ZERO, Vector3.ZERO, 3.0, _solid_at([])), "zero direction")


func test_raycast_diagonal() -> void:
	var hit := VoxelRaycast.cast(Vector3(0.5, 0.5, 0.5), Vector3(1, 1, 1), 10.0, _solid_at([Vector3i(2, 2, 2)]))
	assert_eq(hit.position, Vector3i(2, 2, 2))


func test_event_bus_priority_and_cancel() -> void:
	var bus := EventBus.new()
	var order: Array = []
	bus.subscribe(&"test:thing", func(_p: Dictionary) -> void: order.append("low"), -5)
	bus.subscribe(&"test:thing", func(_p: Dictionary) -> void: order.append("high"), 10)
	bus.subscribe(&"test:thing", func(p: Dictionary) -> void:
		order.append("mid")
		p["cancelled"] = true)
	assert_false(bus.emit_cancellable(&"test:thing", {}))
	assert_eq(order, ["high", "mid", "low"])
	assert_eq(bus.listener_count(&"test:thing"), 3)


func test_event_bus_rejects_bad_ids_and_unsubscribes() -> void:
	var bus := EventBus.new()
	var calls := [0]
	var listener := func(_p: Dictionary) -> void: calls[0] += 1
	Log.muted = true
	bus.subscribe(&"no_namespace", listener)
	assert_eq(bus.listener_count(&"no_namespace"), 0)
	bus.subscribe(&"test:x", listener)
	bus.subscribe(&"test:x", listener)
	bus.emit(&"test:x")
	assert_eq(calls[0], 1, "duplicate subscription ignored")
	bus.unsubscribe(&"test:x", listener)
	bus.emit(&"test:x")
	assert_eq(calls[0], 1)


func test_attribute_modifiers() -> void:
	var registry := AttributeRegistry.new()
	var speed := AttributeDefinition.new()
	speed.id = "blockyworld:movement_speed"
	speed.default_value = 4.0
	speed.min_value = 0.0
	speed.max_value = 10.0
	registry.register(speed)
	var set := AttributeSet.new(registry)
	assert_eq(set.get_value("blockyworld:movement_speed"), 4.0, "default when unset")
	set.set_base("blockyworld:movement_speed", 5.0)
	set.add_modifier("blockyworld:movement_speed", "example:boots", AttributeSet.Operation.ADD, 1.0)
	set.add_modifier("blockyworld:movement_speed", "example:potion", AttributeSet.Operation.MULTIPLY, 0.5)
	assert_eq(set.get_value("blockyworld:movement_speed"), 9.0, "(5 + 1) * 1.5")
	set.add_modifier("blockyworld:movement_speed", "example:rocket", AttributeSet.Operation.ADD, 100.0)
	assert_eq(set.get_value("blockyworld:movement_speed"), 10.0, "clamped to max")
	set.remove_modifier("blockyworld:movement_speed", "example:rocket")
	assert_eq(set.get_value("blockyworld:movement_speed"), 9.0)
	Log.muted = true
	assert_false(set.set_base("magic:mana", 1.0), "unknown attributes rejected")


func test_command_registry_parsing() -> void:
	var registry := CommandRegistry.new()
	registry.register("test:echo", "/echo", "echo", func(_c: CommandContext, args: PackedStringArray) -> String: return " ".join(args), false)
	var context := CommandContext.new()
	context.registry = registry
	assert_eq(registry.execute("/echo hello world", context), "hello world")
	assert_eq(registry.execute("test:echo a", context), "a", "full id also works")
	assert_contains(registry.execute("/nothing", context), "Unknown command")
	assert_eq(CommandContext.parse_coordinate("~", 10.0), 10.0)
	assert_eq(CommandContext.parse_coordinate("~-2", 10.0), 8.0)
	assert_eq(CommandContext.parse_coordinate("5", 10.0), 5.0)
	assert_null(CommandContext.parse_coordinate("x", 10.0))
