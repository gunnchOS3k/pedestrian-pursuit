extends Node

## Slipstream drafting: trailing a racer in their wake grants a temporary speed bump.
## Breaking the cone or overtaking clears the draft.

signal draft_changed(active: bool, strength: float)

@export var max_distance: float = 9.0
@export var cone_dot: float = 0.72
@export var draft_multiplier: float = 1.08
@export var build_rate: float = 1.4
@export var decay_rate: float = 2.2

var draft_active: bool = false
var draft_strength: float = 0.0
var _host: Node3D


func setup(host: Node3D) -> void:
	_host = host


func tick(delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		_clear(delta)
		return
	if "movement_enabled" in _host and not bool(_host.movement_enabled):
		_clear(delta)
		return

	var best_dot := -1.0
	var best_dist := max_distance + 1.0
	var tree := _host.get_tree()
	if tree == null:
		_clear(delta)
		return
	for other in tree.get_nodes_in_group("racers"):
		if other == _host or not (other is Node3D):
			continue
		var ahead: Node3D = other
		var to_other: Vector3 = ahead.global_position - _host.global_position
		to_other.y = 0.0
		var dist := to_other.length()
		if dist < 1.2 or dist > max_distance:
			continue
		var forward := -_host.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() < 0.001:
			continue
		forward = forward.normalized()
		var ahead_back := ahead.global_transform.basis.z
		ahead_back.y = 0.0
		if ahead_back.length_squared() < 0.001:
			ahead_back = -(-ahead.global_transform.basis.z)
		else:
			ahead_back = ahead_back.normalized()
		# Must be behind the leader and roughly aligned with their wake.
		var alignment := forward.dot(to_other.normalized())
		var wake := ahead_back.dot(to_other.normalized())
		if alignment > cone_dot and wake > 0.35 and dist < best_dist:
			best_dist = dist
			best_dot = alignment

	if best_dot >= cone_dot:
		draft_strength = clampf(draft_strength + build_rate * delta, 0.0, 1.0)
		var was := draft_active
		draft_active = draft_strength > 0.35
		if draft_active != was:
			draft_changed.emit(draft_active, get_speed_multiplier())
	else:
		_clear(delta)


func get_speed_multiplier() -> float:
	if not draft_active:
		return 1.0
	return lerpf(1.0, draft_multiplier, draft_strength)


func _clear(delta: float) -> void:
	var was := draft_active
	draft_strength = maxf(0.0, draft_strength - decay_rate * delta)
	draft_active = draft_strength > 0.35
	if draft_active != was:
		draft_changed.emit(draft_active, get_speed_multiplier())
