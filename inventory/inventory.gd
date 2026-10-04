class_name Inventory
extends RefCounted
## Fixed-size list of item slots. Knows stacking rules through ItemRegistry.

signal slot_changed(index: int)

var _slots: Array = []
var _items: ItemRegistry


func _init(slot_count: int, items: ItemRegistry) -> void:
	_items = items
	_slots.resize(slot_count)


func size() -> int:
	return _slots.size()


## Returns the stack in `index` (null when empty). Do not modify it directly;
## use set_slot so listeners are notified.
func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


func set_slot(index: int, stack: ItemStack) -> void:
	if index < 0 or index >= _slots.size():
		return
	_slots[index] = null if stack == null or stack.is_empty() else stack
	slot_changed.emit(index)


## Adds as much as fits (existing stacks first). Returns the amount that did
## not fit.
func add_item(stack: ItemStack) -> int:
	if stack == null or stack.is_empty():
		return 0
	var remaining := stack.amount
	var limit := _items.max_stack_of(stack.item_id)
	for i in _slots.size():
		var slot: ItemStack = _slots[i]
		if slot != null and slot.can_stack_with(stack) and slot.amount < limit:
			var moved := mini(limit - slot.amount, remaining)
			slot.amount += moved
			remaining -= moved
			slot_changed.emit(i)
			if remaining == 0:
				return 0
	for i in _slots.size():
		if _slots[i] == null:
			var placed := stack.duplicate_stack()
			placed.amount = mini(limit, remaining)
			remaining -= placed.amount
			_slots[i] = placed
			slot_changed.emit(i)
			if remaining == 0:
				return 0
	return remaining


## Removes up to `count` from a slot and returns how many were removed.
func remove_from_slot(index: int, count: int) -> int:
	var slot := get_slot(index)
	if slot == null:
		return 0
	var removed := mini(count, slot.amount)
	slot.amount -= removed
	if slot.amount <= 0:
		_slots[index] = null
	slot_changed.emit(index)
	return removed


func find_item(item_id: String) -> int:
	for i in _slots.size():
		var slot: ItemStack = _slots[i]
		if slot != null and slot.item_id == item_id:
			return i
	return -1


func count_item(item_id: String) -> int:
	var total := 0
	for slot in _slots:
		if slot != null and slot.item_id == item_id:
			total += slot.amount
	return total


func clear() -> void:
	for i in _slots.size():
		_slots[i] = null
		slot_changed.emit(i)


func to_array() -> Array:
	var result: Array = []
	for i in _slots.size():
		var slot: ItemStack = _slots[i]
		if slot != null:
			var entry := slot.to_dict()
			entry["slot"] = i
			result.append(entry)
	return result


func load_array(data: Array) -> void:
	clear()
	for entry in data:
		if not entry is Dictionary:
			continue
		var index := int(entry.get("slot", -1))
		var stack := ItemStack.from_dict(entry)
		if stack == null or index < 0 or index >= _slots.size():
			Log.warn("SAVE", "Skipping malformed inventory entry %s" % str(entry))
			continue
		set_slot(index, stack)
