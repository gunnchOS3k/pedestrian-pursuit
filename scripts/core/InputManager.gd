extends Node

## Wraps InputMap actions for consistent querying.


func get_steer() -> float:
	if GameManager.accept_test_mode and absf(GameManager.accept_steer) > 0.01:
		return GameManager.accept_steer
	return Input.get_action_strength("move_right") - Input.get_action_strength("move_left")


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
