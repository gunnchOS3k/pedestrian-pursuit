extends CanvasLayer

## UI notification for newly unlocked achievements. PROCESS_MODE_ALWAYS
## so toasts still appear while a race is paused.

var _panel: PanelContainer
var _title: Label
var _body: Label
var _queue: Array = []
var _showing: bool = false
var _timer: float = 0.0


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	var runtime := get_node_or_null("/root/AchievementRuntime")
	if runtime != null and runtime.has_signal("unlocked"):
		if not runtime.unlocked.is_connected(enqueue):
			runtime.unlocked.connect(enqueue)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -420
	_panel.offset_top = 24
	_panel.offset_right = -24
	_panel.offset_bottom = 140
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	var header := Label.new()
	header.text = "Achievement unlocked"
	header.add_theme_font_size_override("font_size", 14)
	v.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	v.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 14)
	v.add_child(_body)


func enqueue(_id: String, entry: Dictionary) -> void:
	_queue.append(entry)
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	var entry: Dictionary = _queue.pop_front()
	_title.text = str(entry.get("title", "Achievement"))
	_body.text = str(entry.get("description", ""))
	_showing = true
	visible = true
	_timer = 3.2


func _process(delta: float) -> void:
	if not _showing:
		return
	_timer -= delta
	if _timer <= 0.0:
		_show_next()
