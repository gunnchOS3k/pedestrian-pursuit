extends CanvasLayer

## Multi-touch controls for Android. Buttons inject the same InputMap actions used
## by keyboard and gamepads, so gameplay code has one input path.
##
## Uses Control Buttons (not only TouchScreenButton) so ADB / mouse-emulated taps
## also hold accelerate correctly on Pixel playtests.

signal pause_requested

@export var show_on_desktop: bool = false

var _button_root: Control


func _ready() -> void:
	var show_touch := false
	if DeviceRoleRuntime != null and DeviceRoleRuntime.wants_touch_controls():
		show_touch = true
	elif OS.has_feature("mobile") or show_on_desktop:
		show_touch = true
	if show_touch:
		_ensure_controls()


func configure_for_device_role(profile: Dictionary) -> void:
	var want := bool(profile.get("show_touch_controls", false)) or str(profile.get("input_default", "")) == "touch"
	if want:
		show_on_desktop = true
		_ensure_controls()
	elif _button_root != null:
		_button_root.queue_free()
		_button_root = null
	_apply_a11y_scale()


func _ensure_controls() -> void:
	if _button_root != null:
		_apply_a11y_scale()
		return
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button_root = Control.new()
	_button_root.name = "Buttons"
	_button_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_button_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_button_root)
	_build_buttons(get_viewport().get_visible_rect().size)
	_apply_a11y_scale()


func _build_buttons(view_size: Vector2) -> void:
	var safe_rect := _get_safe_rect(view_size)
	var left_x := safe_rect.position.x + maxf(92.0, safe_rect.size.x * 0.075)
	var bottom_y := safe_rect.end.y - maxf(88.0, safe_rect.size.y * 0.12)
	var right_x := safe_rect.end.x - maxf(92.0, safe_rect.size.x * 0.075)
	_add_button(
		"Left",
		"move_left",
		Vector2(left_x, bottom_y),
		Vector2(112, 112),
		"◀",
		Color(0.15, 0.32, 0.55, 0.72)
	)
	_add_button(
		"Right",
		"move_right",
		Vector2(left_x + 126.0, bottom_y),
		Vector2(112, 112),
		"▶",
		Color(0.15, 0.32, 0.55, 0.72)
	)
	_add_button(
		"Run",
		"accelerate",
		Vector2(right_x, bottom_y),
		Vector2(122, 122),
		"RUN",
		Color(0.15, 0.58, 0.4, 0.72)
	)
	_add_button(
		"Drift",
		"drift",
		Vector2(right_x - 138.0, bottom_y),
		Vector2(116, 116),
		"DRIFT",
		Color(0.38, 0.27, 0.65, 0.72)
	)
	_add_button(
		"Jump",
		"jump",
		Vector2(right_x, bottom_y - 138.0),
		Vector2(108, 108),
		"JUMP",
		Color(0.82, 0.48, 0.15, 0.72)
	)
	_add_button(
		"Boost",
		"boost",
		Vector2(right_x - 128.0, bottom_y - 130.0),
		Vector2(96, 96),
		"BOOST",
		Color(0.82, 0.2, 0.38, 0.72)
	)
	_add_button(
		"Item",
		"use_item",
		Vector2(right_x - 245.0, bottom_y - 115.0),
		Vector2(88, 88),
		"ITEM",
		Color(0.62, 0.22, 0.66, 0.72)
	)
	_add_button(
		"Brake",
		"brake",
		Vector2(left_x + 64.0, bottom_y - 126.0),
		Vector2(100, 88),
		"BRAKE",
		Color(0.38, 0.38, 0.42, 0.68)
	)
	_add_button(
		"Stomp",
		"slide",
		Vector2(left_x + 174.0, bottom_y - 126.0),
		Vector2(100, 88),
		"STOMP",
		Color(0.55, 0.3, 0.18, 0.68)
	)
	_add_button(
		"Pause",
		"",
		Vector2(safe_rect.end.x - 48.0, safe_rect.position.y + 46.0),
		Vector2(68, 60),
		"Ⅱ",
		Color(0.18, 0.2, 0.28, 0.7)
	)


func _get_safe_rect(view_size: Vector2) -> Rect2:
	var result := Rect2(Vector2.ZERO, view_size)
	if not OS.has_feature("mobile"):
		return result
	var display_size := Vector2(DisplayServer.screen_get_size())
	var safe_pixels := DisplayServer.get_display_safe_area()
	if (
		display_size.x <= 0.0
		or display_size.y <= 0.0
		or safe_pixels.size.x <= 0
		or safe_pixels.size.y <= 0
	):
		return result
	var scale := Vector2(view_size.x / display_size.x, view_size.y / display_size.y)
	return Rect2(Vector2(safe_pixels.position) * scale, Vector2(safe_pixels.size) * scale)


func _add_button(
	button_name: String,
	action: String,
	center: Vector2,
	size: Vector2,
	label_text: String,
	color: Color
) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.position = center - size * 0.5
	button.size = size
	button.modulate = Color(1, 1, 1, 0.92)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	if button_name == "Pause":
		button.pressed.connect(func(): pause_requested.emit())
	elif action == "move_left":
		button.button_down.connect(func():
			Input.action_press(action)
			InputManager.set_touch_steer(-1.0)
		)
		button.button_up.connect(func():
			if Input.is_action_pressed(action):
				Input.action_release(action)
			InputManager.set_touch_steer(0.0)
		)
	elif action == "move_right":
		button.button_down.connect(func():
			Input.action_press(action)
			InputManager.set_touch_steer(1.0)
		)
		button.button_up.connect(func():
			if Input.is_action_pressed(action):
				Input.action_release(action)
			InputManager.set_touch_steer(0.0)
		)
	elif action == "accelerate":
		button.button_down.connect(func():
			Input.action_press(action)
			InputManager.set_touch_accelerate(true)
		)
		button.button_up.connect(func():
			if Input.is_action_pressed(action):
				Input.action_release(action)
			InputManager.set_touch_accelerate(false)
		)
	elif not action.is_empty():
		button.button_down.connect(func(): Input.action_press(action))
		button.button_up.connect(func():
			if Input.is_action_pressed(action):
				Input.action_release(action)
		)
	_button_root.add_child(button)


func _apply_a11y_scale() -> void:
	if _button_root == null:
		return
	var scale := 1.0
	if AccessibilitySettings != null:
		scale = AccessibilitySettings.get_ui_scale_multiplier()
	for child in _button_root.get_children():
		if child is Control:
			child.scale = Vector2(scale, scale)
