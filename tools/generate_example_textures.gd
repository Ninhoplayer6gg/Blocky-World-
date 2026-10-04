extends SceneTree
## Draws the two small pixel-art PNGs shipped with example_mod (ruby block and
## ruby item icon). They exist to exercise the external texture pipeline with
## real files instead of placeholders. Re-run only if you want to regenerate:
##   godot --headless --path . -s res://tools/generate_example_textures.gd

const OUT := "res://mods/example_mod/textures"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT + "/blocks")
	DirAccess.make_dir_recursive_absolute(OUT + "/items")
	_ruby_block().save_png(OUT + "/blocks/ruby_block.png")
	_ruby_item().save_png(OUT + "/items/ruby.png")
	print("Wrote example_mod textures")
	quit()


func _ruby_block() -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var dark := Color("6e0f22")
	var mid := Color("b3193a")
	var light := Color("e8506c")
	var shine := Color("ffd0d8")
	for y in 16:
		for x in 16:
			var color := mid
			if x == 0 or y == 0 or x == 15 or y == 15:
				color = dark
			elif (x + y) % 6 == 0:
				color = light
			elif (x - y + 16) % 5 == 0:
				color = dark.lerp(mid, 0.5)
			image.set_pixel(x, y, color)
	for p in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(11, 10), Vector2i(12, 11)]:
		image.set_pixelv(p, shine)
	return image


func _ruby_item() -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rows := [
		"................",
		"................",
		"....dddddddd....",
		"...dLLmmmmmmd...",
		"..dLLmmmmmmmmd..",
		".dLmmmmmmmmmmmd.",
		".dmmmmmmmmmmmmd.",
		"..dmmmmmmmmmmd..",
		"...dmmmmmmmmd...",
		"....dmmmmmmd....",
		".....dmmmmd.....",
		"......dmmd......",
		".......dd.......",
		"................",
		"................",
		"................",
	]
	var palette := {"d": Color("5e0c1d"), "m": Color("c41f43"), "L": Color("ff8fa3")}
	for y in 16:
		for x in 16:
			var key: String = rows[y][x]
			if palette.has(key):
				image.set_pixel(x, y, palette[key])
	return image
