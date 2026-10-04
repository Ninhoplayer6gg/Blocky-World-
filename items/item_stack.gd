class_name ItemStack
extends RefCounted
## A quantity of one item plus optional metadata.
##
## The item is referenced by namespaced id (not by object) so stacks of items
## from a missing mod survive load/save untouched.
##
## Metadata rules (keep stacks serializable and mod-safe):
##   - keys are namespaced ids ("example:charge")
##   - values are JSON-compatible: bool, int, float, String, Array, Dictionary
##   - stacks only merge when their metadata is equal

var item_id: String = ""
var amount: int = 0
var _metadata: Dictionary = {}


static func create(id: String, count: int = 1, metadata: Dictionary = {}) -> ItemStack:
	var stack := ItemStack.new()
	stack.item_id = id
	stack.amount = count
	for key in metadata:
		stack.set_meta_value(key, metadata[key])
	return stack


func is_empty() -> bool:
	return item_id.is_empty() or amount <= 0


func get_meta_value(key: String, default: Variant = null) -> Variant:
	return _metadata.get(key, default)


## Returns false (and leaves metadata unchanged) when key or value is invalid.
func set_meta_value(key: String, value: Variant) -> bool:
	if not NamespacedId.is_valid(key):
		Log.error("ITEM", "Item metadata key '%s' is not a namespaced id" % key)
		return false
	if not is_json_safe(value):
		Log.error("ITEM", "Item metadata '%s' has a non JSON-compatible value (%s)" % [key, type_string(typeof(value))])
		return false
	_metadata[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return true


func remove_meta_value(key: String) -> void:
	_metadata.erase(key)


func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


func has_metadata() -> bool:
	return not _metadata.is_empty()


func can_stack_with(other: ItemStack) -> bool:
	return other != null and other.item_id == item_id and other._metadata == _metadata


func duplicate_stack() -> ItemStack:
	var copy := ItemStack.new()
	copy.item_id = item_id
	copy.amount = amount
	copy._metadata = _metadata.duplicate(true)
	return copy


func to_dict() -> Dictionary:
	var data := {"item": item_id, "amount": amount}
	if not _metadata.is_empty():
		data["metadata"] = _metadata.duplicate(true)
	return data


## Returns null for malformed data.
static func from_dict(data: Variant) -> ItemStack:
	if not data is Dictionary:
		return null
	var id: String = str(data.get("item", ""))
	if not NamespacedId.is_valid(id):
		return null
	var stack := ItemStack.create(id, int(data.get("amount", 1)))
	var metadata: Variant = data.get("metadata", {})
	if metadata is Dictionary:
		for key in metadata:
			stack.set_meta_value(str(key), metadata[key])
	return stack


static func is_json_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for element in value:
				if not is_json_safe(element):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not is_json_safe(value[key]):
					return false
			return true
	return false
