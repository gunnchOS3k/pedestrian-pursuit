extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.12, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 48
	panel.offset_top = 40
	panel.offset_right = -48
	panel.offset_bottom = -48
	panel.add_theme_constant_override("separation", 12)
	add_child(panel)
	var title := Label.new()
	title.text = "Build Info"
	title.add_theme_font_size_override("font_size", 32)
	panel.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	var identity := get_node_or_null("/root/BuildIdentity")
	if identity != null and identity.has_method("display_lines"):
		body.text = "\n".join(identity.display_lines())
	else:
		body.text = "Build identity unavailable."
	panel.add_child(body)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 44)
	back.pressed.connect(_on_back)
	panel.add_child(back)


func _on_back() -> void:
	var identity := get_node_or_null("/root/BuildIdentity")
	if identity != null and bool(identity.return_to_guest_review):
		identity.return_to_guest_review = false
		SceneLoader.go_to_guest_runner_review()
		return
	SceneLoader.go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
