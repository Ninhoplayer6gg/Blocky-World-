class_name DevConsole
extends PanelContainer
## Developer console: shows the log and runs commands. Opened with ` or F1,
## or with / (prefilled). Esc closes it.

signal opened
signal closed

const MAX_HISTORY := 50
const MAX_LINES := 400

var context: CommandContext
var _output: RichTextLabel
var _input: LineEdit
var _history: PackedStringArray = PackedStringArray()
var _history_index := -1
var _log_cursor := 0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 320)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.78)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	add_child(box)
	_output = RichTextLabel.new()
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_size_override("normal_font_size", 13)
	box.add_child(_output)
	_input = LineEdit.new()
	_input.placeholder_text = "Type a command, e.g. /help"
	_input.text_submitted.connect(_on_submitted)
	_input.gui_input.connect(_on_input_gui)
	box.add_child(_input)
	visible = false
	_log_cursor = Log.read_since(0).next
	_append("[color=#9cf]%s %s developer console. Type /help.[/color]" % [GameInfo.GAME_NAME, GameInfo.GAME_VERSION])


func _process(_delta: float) -> void:
	var update := Log.read_since(_log_cursor)
	_log_cursor = update.next
	for line in update.lines:
		var color := "#bbbbbb"
		if line.begins_with("[ERROR]"):
			color = "#ff7070"
		elif line.begins_with("[WARN]"):
			color = "#ffd070"
		_append("[color=%s]%s[/color]" % [color, _escape(line)])


func is_open() -> bool:
	return visible


func open(prefill: String = "") -> void:
	visible = true
	_input.text = prefill
	_input.grab_focus()
	_input.caret_column = prefill.length()
	opened.emit()


func close() -> void:
	visible = false
	_input.release_focus()
	closed.emit()


func run(line: String) -> String:
	_append("[color=#ffffff]> %s[/color]" % _escape(line))
	var result := context.registry.execute(line, context) if context != null else "Console not ready"
	if not result.is_empty():
		_append(_escape(result))
	return result


func clear_output() -> void:
	_output.clear()


func _on_submitted(text: String) -> void:
	_input.clear()
	if text.strip_edges().is_empty():
		return
	_history.append(text)
	if _history.size() > MAX_HISTORY:
		_history.remove_at(0)
	_history_index = -1
	run(text)


func _on_input_gui(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.PAUSE) or event.is_action_pressed(InputActions.TOGGLE_CONSOLE):
		close()
		_input.accept_event()
	elif event is InputEventKey and event.pressed and not _history.is_empty():
		if event.keycode == KEY_UP:
			_history_index = _history.size() - 1 if _history_index < 0 else maxi(_history_index - 1, 0)
			_input.text = _history[_history_index]
			_input.caret_column = _input.text.length()
			_input.accept_event()
		elif event.keycode == KEY_DOWN and _history_index >= 0:
			_history_index = mini(_history_index + 1, _history.size() - 1)
			_input.text = _history[_history_index]
			_input.caret_column = _input.text.length()
			_input.accept_event()


func _append(bbcode: String) -> void:
	_output.append_text(bbcode + "\n")
	while _output.get_paragraph_count() > MAX_LINES:
		_output.remove_paragraph(0)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
