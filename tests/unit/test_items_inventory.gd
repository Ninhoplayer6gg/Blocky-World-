extends TestCase

var items: ItemRegistry


func before_each() -> void:
	items = ItemRegistry.new()
	for spec in [["blockyworld:stone", 64], ["example:sword", 1]]:
		var item := ItemDefinition.new()
		item.id = spec[0]
		item.max_stack = spec[1]
		items.register(item)


func test_item_stack_metadata_rules() -> void:
	var stack := ItemStack.create("example:sword", 1)
	assert_true(stack.set_meta_value("example:charge", 5))
	assert_false(stack.set_meta_value("charge", 5), "keys must be namespaced")
	assert_false(stack.set_meta_value("example:node", Node3D), "values must be JSON compatible")
	assert_eq(stack.get_meta_value("example:charge"), 5)
	var nested := {"a": [1, 2]}
	stack.set_meta_value("example:data", nested)
	nested["a"].append(3)
	assert_eq(stack.get_meta_value("example:data").a.size(), 2, "metadata is copied")


func test_item_stack_serialization_roundtrip() -> void:
	var stack := ItemStack.create("missingmod:thing", 7, {"missingmod:level": 3})
	var copy := ItemStack.from_dict(JSON.parse_string(JSON.stringify(stack.to_dict())))
	assert_eq(copy.item_id, "missingmod:thing", "unknown items survive round trips")
	assert_eq(copy.amount, 7)
	assert_eq(int(copy.get_meta_value("missingmod:level")), 3)
	assert_null(ItemStack.from_dict({"item": "bad id"}))
	assert_null(ItemStack.from_dict("nonsense"))


func test_stacking_respects_max_and_metadata() -> void:
	var inventory := Inventory.new(3, items)
	assert_eq(inventory.add_item(ItemStack.create("blockyworld:stone", 100)), 0)
	assert_eq(inventory.get_slot(0).amount, 64)
	assert_eq(inventory.get_slot(1).amount, 36)
	var a := ItemStack.create("example:sword", 1)
	assert_eq(inventory.add_item(a), 0)
	assert_eq(inventory.add_item(ItemStack.create("example:sword", 1)), 1, "max_stack 1 and no free slot")
	assert_false(ItemStack.create("blockyworld:stone", 1, {"example:x": 1}).can_stack_with(ItemStack.create("blockyworld:stone", 1)))


func test_remove_and_count() -> void:
	var inventory := Inventory.new(4, items)
	inventory.add_item(ItemStack.create("blockyworld:stone", 10))
	assert_eq(inventory.remove_from_slot(0, 3), 3)
	assert_eq(inventory.count_item("blockyworld:stone"), 7)
	assert_eq(inventory.remove_from_slot(0, 50), 7)
	assert_null(inventory.get_slot(0), "empty slot becomes null")
	assert_eq(inventory.find_item("blockyworld:stone"), -1)


func test_inventory_save_load() -> void:
	var inventory := Inventory.new(9, items)
	inventory.set_slot(4, ItemStack.create("blockyworld:stone", 12))
	inventory.set_slot(8, ItemStack.create("gone:item", 2))
	var data: Array = JSON.parse_string(JSON.stringify(inventory.to_array()))
	var loaded := Inventory.new(9, items)
	loaded.load_array(data)
	assert_eq(loaded.get_slot(4).amount, 12)
	assert_eq(loaded.get_slot(8).item_id, "gone:item")
	assert_null(loaded.get_slot(0))
