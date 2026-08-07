extends Node

## Sorts racers by lap, checkpoint, and distance to next checkpoint.

signal positions_updated(ranking: Array)

var _checkpoints: Array[Node3D] = []
var _lap_manager: Node


func setup(lap_manager: Node, checkpoints: Array[Node3D]) -> void:
	_lap_manager = lap_manager
	_checkpoints = checkpoints


func update_positions() -> void:
	if _lap_manager == null:
		return
	var states: Array = _lap_manager.get_racer_states()
	for state in states:
		var racer: Node3D = state.racer
		var cp_index: int = state.next_checkpoint
		var progress := float(state.lap) * 1000.0
		var checkpoints_passed := cp_index - 1 if cp_index > 0 else maxi(_checkpoints.size() - 1, 0)
		progress += float(checkpoints_passed) * 100.0
		if cp_index < _checkpoints.size() and _checkpoints[cp_index] != null:
			var cp_pos := _checkpoints[cp_index].global_position
			var dist := racer.global_position.distance_to(cp_pos)
			progress += maxf(0.0, 100.0 - dist)
		state["sort_key"] = progress

	states.sort_custom(func(a, b): return a.sort_key > b.sort_key)
	var ranking: Array = []
	for i in states.size():
		var racer_node: Node = states[i].racer
		if racer_node != null:
			racer_node.set_meta("race_place_estimate", i + 1)
		ranking.append({"racer": racer_node, "position": i + 1})
	positions_updated.emit(ranking)


func get_position_for(racer: Node) -> int:
	update_positions()
	var states: Array = _lap_manager.get_racer_states()
	states.sort_custom(func(a, b): return a.sort_key > b.sort_key)
	for i in states.size():
		if states[i].racer == racer:
			return i + 1
	return 1


func get_checkpoints() -> Array[Node3D]:
	return _checkpoints
