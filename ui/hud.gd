class_name GameHud
extends Control
## In-game HUD: crosshair, break progress, hotbar, selected item name and
## short notifications. Functional first; styling comes later.

const SLOT_SIZE := 52

var _player: Player
var _content: GameContent
var _slots: Array[Panel] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _item_name: Label
var _message: Label
var _progress: ProgressBar
var _name_timer := 0.0
var _message_timer := 0.0
var _selected_style: StyleBoxFlat
var _normal_style: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.add_theme_constant_override("outline_size", 4)
	crosshair.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	_place(crosshair, Control.PRESET_CENTER, Vector2(40, 40), Vector2.ZERO)

	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.custom_minimum_size = Vector2(80, 6)
	_progress.visible = false
	add_child(_progress)
	_place(_progress, Control.PRESET_CENTER, Vector2(80, 6), Vector2(0, 24))

	_normal_style = _style(Color(0, 0, 0, 0.45), Color(0.35, 0.35, 0.35), 2)
	_selected_style = _style(Color(0.1, 0.1, 0.1, 0.6), Color(1, 1, 1), 3)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var width := InputActions.HOTBAR_SLOT_COUNT * (SLOT_SIZE + 4) - 4
	_place(bar, Control.PRESET_CENTER_BOTTOM, Vector2(width, SLOT_SIZE), Vector2(0, -14))
	for i in InputActions.HOTBAR_SLOT_COUNT:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(slot)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(8, 8)
		icon.size = Vector2(SLOT_SIZE - 16, SLOT_SIZE - 16)
		slot.add_child(icon)
		var count := Label.new()
		count.position = Vector2(SLOT_SIZE - 32, SLOT_SIZE - 24)
		count.size = Vector2(28, 20)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_constant_override("outline_size", 4)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		slot.add_child(count)
		var number := Label.new()
		number.text = str(i + 1)
		number.position = Vector2(4, 0)
		number.add_theme_font_size_override("font_size", 11)
		number.modulate = Color(1, 1, 1, 0.6)
		slot.add_child(number)
		_slots.append(slot)
		_icons.append(icon)
		_counts.append(count)

	_item_name = _centered_label(Control.PRESET_CENTER_BOTTOM, Vector2(0, -SLOT_SIZE - 22), 18)
	_message = _centered_label(Control.PRESET_CENTER_TOP, Vector2(0, 60), 18)


func bind(player: Player, content: GameContent) -> void:
	_player = player
	_content = content
	player.inventory.slot_changed.connect(_on_slot_changed)
	player.selected_slot_changed.connect(_on_selected)
	player.message.connect(show_message)
	refresh_all()


func refresh_all() -> void:
	for i in _slots.size():
		_on_slot_changed(i)
	_on_selected(_player.selected_slot)


func show_message(text: String, seconds: float = 2.5) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	_message_timer = seconds


func _process(delta: float) -> void:
	if _player == null:
		return
	var progress := _player.interaction.break_progress
	_progress.visible = progress > 0.0 and progress < 1.0
	_progress.value = progress
	_name_timer -= delta
	_item_name.modulate.a = clampf(_name_timer, 0.0, 1.0)
	_message_timer -= delta
	_message.modulate.a = clampf(_message_timer, 0.0, 1.0)


func _on_slot_changed(index: int) -> void:
	if index >= _slots.size():
		return
	var stack := _player.inventory.get_slot(index)
	_icons[index].texture = _content.item_icons.get_icon(stack.item_id) if stack != null else null
	_counts[index].text = str(stack.amount) if stack != null and stack.amount > 1 else ""
	if index == _player.selected_slot:
		_show_item_name()


func _on_selected(index: int) -> void:
	for i in _slots.size():
		_slots[i].add_theme_stylebox_override("panel", _selected_style if i == index else _normal_style)
	_show_item_name()


func _show_item_name() -> void:
	var stack := _player.get_selected_stack()
	if stack == null:
		_item_name.text = ""
		return
	var item := _content.registries.items.get_item(stack.item_id)
	_item_name.text = item.display_name if item != null else "Missing: %s" % stack.item_id
	_name_timer = 2.0


func _centered_label(preset: Control.LayoutPreset, offset: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_place(label, preset, Vector2(600, 28), offset)
	return label


## Anchors `control` to `preset` with a fixed size, then shifts it by `offset`.
static func _place(control: Control, preset: Control.LayoutPreset, size: Vector2, offset: Vector2) -> void:
	control.size = size
	control.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE)
	control.position += offset


static func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	return style
