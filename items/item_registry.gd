class_name ItemRegistry
extends Registry
## Registry of item types. Blocks get an item with the same id automatically
## (see ContentLoader), so "blockyworld:stone" is both a block and an item.


func _init() -> void:
	super("blockyworld:items")


func get_item(id: String) -> ItemDefinition:
	return get_entry(id) as ItemDefinition


func max_stack_of(id: String) -> int:
	var definition := get_item(id)
	return definition.max_stack if definition != null else 64


func merge_reload(staged: ItemRegistry) -> Dictionary:
	var added: PackedStringArray = []
	var updated := 0
	for entry in staged.entries():
		var incoming := entry as ItemDefinition
		var current := get_item(incoming.id)
		if current != null:
			current.copy_data_from(incoming)
			updated += 1
		else:
			_entries[incoming.id] = incoming
			_ordered.append(incoming)
			added.append(incoming.id)
	return {"updated": updated, "added": added}
