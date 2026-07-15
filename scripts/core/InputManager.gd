extends Node

## Wraps InputMap actions for consistent querying.


func get_steer() -> float:
	if GameManager.accept_test_mode and absf(GameManager.accept_steer) > 0.01:
		return GameManager.accept_steer
	var steer := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
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
	return Input.is_action_pressed("accelerate")


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
	return Input.is_action_just_pressed("use_item")


func is_tricking() -> bool:
	return Input.is_action_just_pressed("trick")


func is_pause_pressed() -> bool:
	return Input.is_action_just_pressed("pause")
