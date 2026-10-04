extends Control
## Main menu: Play (world list / create), Blocky Lab, Mods, Settings, Exit.
## Built in code; functional first, the final UI comes later.

var _pages: Dictionary = {}
var _world_list: ItemList
var _worlds: Array = []
var _dialog: AcceptDialog
var _confirm: ConfirmationDialog
var _pending_open: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color(0.11, 0.14, 0.17)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog = AcceptDialog.new()
	add_child(_dialog)
	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(_on_confirmed)
	add_child(_confirm)
	_build_main()
	_build_worlds()
	_build_create()
	_build_mods()
	_build_settings()
	_show("main")
	if Game.content == null:
		_alert("Content failed to load. Check the log.")


# --- Pages ---------------------------------------------------------------------

func _build_main() -> void:
	var page := _page("main")
	var title := Label.new()
	title.text = GameInfo.GAME_NAME
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	page.add_child(title)
	var version := Label.new()
	version.text = "Version %s — built for mods" % GameInfo.GAME_VERSION
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.modulate = Color(1, 1, 1, 0.6)
	page.add_child(version)
	page.add_child(_spacer(24))
	_button(page, "Play", _show.bind("worlds"))
	_button(page, "Blocky Lab", _open_lab)
	_button(page, "Mods", _show.bind("mods"))
	_button(page, "Settings", _show.bind("settings"))
	_button(page, "Exit", Game.quit_game)
	if Game.content != null:
		var failed := Game.content.failed_mods()
		if not failed.is_empty():
			var warning := Label.new()
			warning.text = "%d mod(s) reported problems — see Mods" % failed.size()
			warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			warning.modulate = Color(1, 0.75, 0.4)
			page.add_child(warning)


func _build_worlds() -> void:
	var page := _page("worlds")
	page.add_child(_heading("Worlds"))
	_world_list = ItemList.new()
	_world_list.custom_minimum_size = Vector2(560, 300)
	_world_list.item_activated.connect(func(_index: int) -> void: _open_selected())
	page.add_child(_world_list)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	page.add_child(row)
	_button(row, "Play Selected", _open_selected)
	_button(row, "Create New World", _show.bind("create"))
	_button(row, "Delete", _delete_selected)
	_button(row, "Back", _show.bind("main"))


func _build_create() -> void:
	var page := _page("create")
	page.add_child(_heading("Create World"))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "World Name"
	name_edit.text = "New World"
	name_edit.custom_minimum_size = Vector2(360, 0)
	page.add_child(_labeled("World Name", name_edit))
	var seed_edit := LineEdit.new()
	seed_edit.placeholder_text = "Leave empty for a random seed"
	page.add_child(_labeled("Seed", seed_edit))
	page.add_child(_spacer(12))
	_button(page, "Create", func() -> void:
		var created := Game.create_world(name_edit.text, seed_edit.text, GameConfig.DEFAULT_GENERATOR, false)
		if created.save == null:
			_alert("Could not create the world:\n%s" % created.error)
		else:
			Game.start_session(created.save))
	_button(page, "Back", _show.bind("worlds"))


func _build_mods() -> void:
	var page := _page("mods")
	page.add_child(_heading("Mods"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 380)
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	if Game.content != null:
		var disabled := Game.load_disabled_mods()
		for mod in Game.content.mods:
			list.add_child(_mod_row(mod, disabled))
	var hint := Label.new()
	hint.text = "Put mods in: %s (enable/disable takes effect after restart)" % ProjectSettings.globalize_path("user://mods")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(760, 0)
	hint.modulate = Color(1, 1, 1, 0.6)
	page.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(row)
	_button(row, "Open Mods Folder", func() -> void:
		DirAccess.make_dir_recursive_absolute("user://mods")
		OS.shell_open(ProjectSettings.globalize_path("user://mods")))
	_button(row, "Back", _show.bind("main"))


func _mod_row(mod: ModEntry, disabled: PackedStringArray) -> Control:
	var box := VBoxContainer.new()
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	var version: String = mod.manifest.version if mod.manifest != null and not mod.manifest.version.is_empty() else "?"
	title.text = "%s  %s  (%s)" % [mod.get_display_name(), version, mod.get_id()]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var state := Label.new()
	var label := mod.state_label()
	if mod.state == ModEntry.State.LOADED and not mod.errors.is_empty():
		label += " (%d problem(s))" % mod.errors.size()
	state.text = label
	state.modulate = {ModEntry.State.LOADED: Color(0.5, 1, 0.5), ModEntry.State.ERROR: Color(1, 0.45, 0.45)}.get(mod.state, Color(0.8, 0.8, 0.8))
	header.add_child(state)
	if not mod.is_builtin() and mod.manifest != null and not mod.manifest.id.is_empty():
		var toggle := CheckButton.new()
		toggle.text = "Enabled"
		toggle.button_pressed = not disabled.has(mod.get_id())
		toggle.toggled.connect(func(on: bool) -> void: Game.set_mod_enabled(mod.get_id(), on))
		header.add_child(toggle)
	var details := PackedStringArray()
	if mod.manifest != null and not mod.manifest.description.is_empty():
		details.append(mod.manifest.description)
	if mod.manifest != null and not mod.manifest.author.is_empty():
		details.append("by " + mod.manifest.author)
	if not mod.content_counts.is_empty():
		details.append(str(mod.content_counts))
	for message in mod.errors:
		details.append("Error: " + message)
	var text := Label.new()
	text.text = "\n".join(details)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(740, 0)
	text.modulate = Color(1, 1, 1, 0.7)
	box.add_child(text)
	return box


func _build_settings() -> void:
	var page := _page("settings")
	page.add_child(_heading("Settings"))
	var settings := Game.settings
	var resolution := OptionButton.new()
	for i in Settings.RESOLUTIONS.size():
		var size := Settings.RESOLUTIONS[i]
		resolution.add_item("%d x %d" % [size.x, size.y], i)
		if size == settings.resolution:
			resolution.select(i)
	resolution.item_selected.connect(func(index: int) -> void: settings.resolution = Settings.RESOLUTIONS[index])
	page.add_child(_labeled("Resolution", resolution))
	var fullscreen := CheckBox.new()
	fullscreen.button_pressed = settings.fullscreen
	fullscreen.toggled.connect(func(on: bool) -> void: settings.fullscreen = on)
	page.add_child(_labeled("Fullscreen", fullscreen))
	var distance := OptionButton.new()
	for value in GameConfig.RENDER_DISTANCE_OPTIONS:
		distance.add_item("%d chunks" % value, value)
		if value == settings.render_distance:
			distance.select(distance.item_count - 1)
	distance.item_selected.connect(func(index: int) -> void: settings.render_distance = distance.get_item_id(index))
	page.add_child(_labeled("Render Distance", distance))
	page.add_child(_labeled("Mouse Sensitivity", _slider(0.02, 0.6, 0.01, settings.mouse_sensitivity,
		func(value: float) -> void: settings.mouse_sensitivity = value)))
	page.add_child(_labeled("Field of View", _slider(50, 110, 1, settings.fov,
		func(value: float) -> void: settings.fov = value)))
	page.add_child(_labeled("Master Volume", _slider(0, 1, 0.01, settings.master_volume,
		func(value: float) -> void: settings.master_volume = value)))
	page.add_child(_spacer(12))
	_button(page, "Apply and Save", func() -> void:
		settings.apply()
		settings.save_to_disk()
		_alert("Settings saved."))
	_button(page, "Back", _show.bind("main"))


# --- Actions -----------------------------------------------------------------

func _refresh_worlds() -> void:
	_worlds = SaveManager.list_worlds()
	_world_list.clear()
	for world in _worlds:
		var text := "%s   —   last played %s, v%s" % [world.name, world.last_played.replace("T", " "), world.game_version]
		if not world.error.is_empty():
			text = "%s   —   UNREADABLE: %s" % [world.folder, world.error]
		_world_list.add_item(text)
	if not _worlds.is_empty():
		_world_list.select(0)


func _selected_world() -> Dictionary:
	var selected := _world_list.get_selected_items()
	return _worlds[selected[0]] if not selected.is_empty() else {}


func _open_selected() -> void:
	var world := _selected_world()
	if world.is_empty():
		_alert("Select a world first, or create a new one.")
		return
	_open_result(Game.open_world(world.directory))


func _open_lab() -> void:
	_open_result(Game.open_lab())


func _open_result(result: Dictionary) -> void:
	if result.save == null:
		_alert("This world cannot be opened:\n%s" % result.error)
		return
	var missing: Array = result.get("missing_mods", [])
	if missing.is_empty():
		Game.start_session(result.save)
		return
	var names := PackedStringArray()
	for mod in missing:
		names.append("%s %s" % [mod.get("id", "?"), mod.get("version", "")])
	_pending_open = {"action": "open", "result": result}
	_confirm.dialog_text = "This world was saved with mods that are not loaded:\n\n%s\n\nTheir blocks will be shown as placeholders and are preserved when saving (nothing is deleted). Open anyway?" % "\n".join(names)
	_confirm.popup_centered()


func _delete_selected() -> void:
	var world := _selected_world()
	if world.is_empty():
		return
	_pending_open = {"action": "delete", "world": world}
	_confirm.dialog_text = "Delete world '%s'? This cannot be undone." % world.name
	_confirm.popup_centered()


func _on_confirmed() -> void:
	match _pending_open.get("action", ""):
		"open":
			var result: Dictionary = _pending_open.result
			Game.start_session(result.save, result.missing_mods)
		"delete":
			var err := SaveManager.delete_world(_pending_open.world.directory)
			if err != OK:
				_alert("Could not delete the world (error %d)." % err)
			_refresh_worlds()
	_pending_open = {}


# --- Helpers -------------------------------------------------------------------

func _show(page_name: String) -> void:
	for key in _pages:
		_pages[key].visible = key == page_name
	if page_name == "worlds":
		_refresh_worlds()


func _page(page_name: String) -> VBoxContainer:
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	center.add_child(page)
	_pages[page_name] = center
	return page


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	return label


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 42)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _labeled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 260)
	row.add_child(control)
	return row


func _slider(minimum: float, maximum: float, step: float, value: float, on_change: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(on_change)
	return slider


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _alert(text: String) -> void:
	_dialog.dialog_text = text
	_dialog.popup_centered()
