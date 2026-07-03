extends Node

enum State { GROUNDED, AIR, SLIDE, DRIFT, STOMP }

signal state_changed(new_state: State)

var current_state: State = State.GROUNDED


func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)


func is_grounded() -> bool:
	return current_state == State.GROUNDED or current_state == State.SLIDE or current_state == State.DRIFT


func is_airborne() -> bool:
	return current_state == State.AIR or current_state == State.STOMP
