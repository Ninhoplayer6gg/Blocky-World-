extends TestCase


func test_valid_ids() -> void:
	assert_true(NamespacedId.is_valid("blockyworld:stone"))
	assert_true(NamespacedId.is_valid("my_mod:blocks/ruby_block"))
	assert_true(NamespacedId.is_valid("magic:crystal.blue"))


func test_invalid_ids() -> void:
	assert_false(NamespacedId.is_valid("stone"), "missing namespace")
	assert_false(NamespacedId.is_valid("Blocky:stone"), "uppercase namespace")
	assert_false(NamespacedId.is_valid("blockyworld:Stone"), "uppercase path")
	assert_false(NamespacedId.is_valid("a:b:c"), "two separators")
	assert_false(NamespacedId.is_valid("1mod:stone"), "namespace starts with digit")
	assert_false(NamespacedId.is_valid("mod:"), "empty path")
	assert_false(NamespacedId.is_valid("mod:a//b"), "empty segment")
	assert_false(NamespacedId.is_valid(""), "empty")


func test_parts_and_qualify() -> void:
	assert_eq(NamespacedId.namespace_of("example:ruby"), "example")
	assert_eq(NamespacedId.path_of("example:blocks/ruby"), "blocks/ruby")
	assert_eq(NamespacedId.qualify("ruby", "example"), "example:ruby")
	assert_eq(NamespacedId.qualify("other:ruby", "example"), "other:ruby")


func test_explain_invalid() -> void:
	assert_eq(NamespacedId.explain_invalid("blockyworld:stone"), "")
	assert_contains(NamespacedId.explain_invalid("stone"), "namespace:path")
	assert_contains(NamespacedId.explain_invalid("Bad:stone"), "namespace")
