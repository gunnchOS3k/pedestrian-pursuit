extends Node

## Wraps InputMap actions for consistent querying across keyboard, gamepad,
## and touch. Device role picks the preferred default; all sources coexist.

enum InputSource { KEYBOARD, GAMEPAD, TOUCH, RING }

var preferred_source: InputSource = InputSource.KEYBOARD
var last_active_source: InputSource = InputSource.KEYBOARD
var _touch_steer: float = 0.0
var _touch_accelerate: bool = false
var _ring_confirm_held: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func apply_device_role(profile: Dictionary) -> void:
	var input_default := str(profile.get("input_default", "keyboard"))
	match input_default:
		"touch":
			preferred_source = InputSource.TOUCH
		"gamepad":
			preferred_source = InputSource.GAMEPAD
		"ring_confirm":
			preferred_source = InputSource.RING
		_:
			preferred_source = InputSource.KEYBOARD


func set_touch_steer(value: float) -> void:
	_touch_steer = clampf(value, -1.0, 1.0)
	if absf(_touch_steer) > 0.05:
		last_active_source = InputSource.TOUCH


func set_touch_accelerate(pressed: bool) -> void:
	_touch_accelerate = pressed
	if pressed:
		last_active_source = InputSource.TOUCH


func set_ring_confirm(pressed: bool) -> void:
	_ring_confirm_held = pressed
	if pressed:
		last_active_source = InputSource.RING


func get_steer() -> float:
	if GameManager.accept_test_mode and absf(GameManager.accept_steer) > 0.01:
		return GameManager.accept_steer
	var steer := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if absf(_touch_steer) > absf(steer):
		steer = _touch_steer
	_note_digital_source(steer)
	var assist := GameManager.mobile_assist_steer
	if absf(assist) < 0.01:
		return steer
	# While accelerating, prefer the racing line so touch/ADB runs stay on course.
	# Strong player left/right still overrides.
	if is_accelerating() and absf(steer) < 0.35:
		return clampf(assist, -1.0, 1.0)
	if absf(steer) < 0.2:
		return clampf(assist * 0.9, -1.0, 1.0)
	return clampf(steer * 0.7 + assist * 0.3, -1.0, 1.0)


func is_accelerating() -> bool:
	if GameManager.auto_accelerate:
		return true
	if _touch_accelerate:
		return true
	if preferred_source == InputSource.RING and _ring_confirm_held:
		return true
	if Input.is_action_pressed("accelerate"):
		_note_action_source("accelerate")
		return true
	return false


func is_braking() -> bool:
	return Input.is_action_pressed("brake")


func is_jumping() -> bool:
	return Input.is_action_just_pressed("jump")


func is_drifting() -> bool:
	return Input.is_action_pressed("drift")


func is_sliding() -> bool:
	return Input.is_action_pressed("slide")


func is_boosting() -> bool:
	return Input.is_action_just_pressed("boost")


func is_using_item() -> bool:
	if preferred_source == InputSource.RING and Input.is_action_just_pressed("special"):
		# Ring confirm secondary: special also triggers item use when preferred.
		return true
	return Input.is_action_just_pressed("use_item")


func is_tricking() -> bool:
	return Input.is_action_just_pressed("trick")


func is_pause_pressed() -> bool:
	return Input.is_action_just_pressed("pause")


func get_active_source_name() -> String:
	match last_active_source:
		InputSource.GAMEPAD:
			return "gamepad"
		InputSource.TOUCH:
			return "touch"
		InputSource.RING:
			return "ring_confirm"
		_:
			return "keyboard"


func _note_digital_source(steer: float) -> void:
	if absf(steer) < 0.05:
		return
	if Input.is_joy_known(0) and (
		absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) > 0.2
		or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT)
		or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)
	):
		last_active_source = InputSource.GAMEPAD
	elif absf(_touch_steer) > 0.05:
		last_active_source = InputSource.TOUCH
	else:
		last_active_source = InputSource.KEYBOARD


func _note_action_source(_action: String) -> void:
	# Prefer gamepad if any joypad is reporting activity; else keyboard.
	if Input.get_connected_joypads().size() > 0:
		for device_id in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(device_id, JOY_BUTTON_A):
				last_active_source = InputSource.GAMEPAD
				return
	last_active_source = InputSource.KEYBOARD
