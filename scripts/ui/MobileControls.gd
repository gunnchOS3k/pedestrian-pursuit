extends CanvasLayer

## Multi-touch controls for Android. Buttons inject the same InputMap actions used
## by keyboard and gamepads, so gameplay code has one input path.

signal pause_requested

@export var show_on_desktop: bool = false

var _button_root: Node2D


func _ready() -> void:
	if not OS.has_feature("mobile") and not show_on_desktop:
		return
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button_root = Node2D.new()
	_button_root.name = "Buttons"
	add_child(_button_root)
	_build_buttons(get_viewport().get_visible_rect().size)


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
	var button := TouchScreenButton.new()
	button.name = button_name
	button.position = center
	if not action.is_empty():
		button.action = action
	button.visibility_mode = (
		TouchScreenButton.VISIBILITY_ALWAYS
		if show_on_desktop
		else TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	)
	if button_name == "Pause":
		button.pressed.connect(func(): pause_requested.emit())
	var shape := RectangleShape2D.new()
	shape.size = size
	button.shape = shape

	var background := Polygon2D.new()
	var half := size * 0.5
	background.polygon = PackedVector2Array(
		[
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		]
	)
	background.color = color
	button.add_child(background)

	var label := Label.new()
	label.position = -half
	label.size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	button.add_child(label)
	_button_root.add_child(button)
