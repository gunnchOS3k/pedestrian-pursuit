extends Node

## Tracks checkpoint order and lap counts per racer.

signal lap_changed(racer: Node, lap: int)
signal racer_finished(racer: Node, finish_time: float)

var total_laps: int = 3
var checkpoint_count: int = 0

var _racer_state: Dictionary = {}


func setup(laps: int, checkpoints: int) -> void:
	total_laps = laps
	checkpoint_count = checkpoints
	_racer_state.clear()


func register_racer(racer: Node) -> void:
	_racer_state[racer.get_instance_id()] = {
		"racer": racer,
		"lap": 0,
		"next_checkpoint": 0,
		"finished": false,
		"finish_time": 0.0,
	}


func on_checkpoint(racer: Node, index: int) -> void:
	var id := racer.get_instance_id()
	if not _racer_state.has(id):
		return
	var state: Dictionary = _racer_state[id]
	if state.finished:
		return
	if index == state.next_checkpoint:
		state.next_checkpoint += 1
		if state.next_checkpoint >= checkpoint_count:
			state.next_checkpoint = 0
			state.lap += 1
			lap_changed.emit(racer, state.lap)
			if state.lap >= total_laps:
				state.finished = true
				racer_finished.emit(racer, state.finish_time)


func set_finish_time(racer: Node, time: float) -> void:
	var id := racer.get_instance_id()
	if _racer_state.has(id):
		_racer_state[id].finish_time = time


func get_lap(racer: Node) -> int:
	var id := racer.get_instance_id()
	if _racer_state.has(id):
		return _racer_state[id].lap
	return 0


func is_finished(racer: Node) -> bool:
	var id := racer.get_instance_id()
	if _racer_state.has(id):
		return _racer_state[id].finished
	return false


func get_racer_states() -> Array:
	var result: Array = []
	for state in _racer_state.values():
		result.append(state)
	return result
