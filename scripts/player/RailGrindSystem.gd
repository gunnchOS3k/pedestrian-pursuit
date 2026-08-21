extends Node

## Skill rail grind: proximity + approach-angle eligibility, stable traversal, jump exit.
## No teleport; no infinite grind. Exit can feed a brief boost via host BoostSystem.

signal grind_started
signal grind_ended(exit_reason: String)

@export var grind_speed_bonus: float = 1.20
@export var grind_duration: float = 1.55
@export var attach_radius: float = 2.6
@export var min_approach_dot: float = 0.35
@export var exit_boost_mult: float = 1.12
@export var exit_boost_duration: float = 0.45

var is_grinding: bool = false
var _timer: float = 0.0
var _rail_points: Array[Vector3] = []
var _rail_index: int = 0
var _host: CharacterBody3D
var _segments_ridden: int = 0


func setup(host: CharacterBody3D, rail_world_points: Array) -> void:
	_host = host
	_rail_points.clear()
	for point in rail_world_points:
		if point is Vector3:
			_rail_points.append(point)


func try_start_from_jump() -> bool:
	if is_grinding or _host == null or _rail_points.size() < 2:
		return false
	var nearest := _nearest_rail_index(_host.global_position)
	if nearest < 0:
		return false
	var rail_pos := _rail_points[nearest]
	if _host.global_position.distance_to(rail_pos) > attach_radius:
		return false
	var next_i := mini(nearest + 1, _rail_points.size() - 1)
	var rail_dir := _rail_points[next_i] - rail_pos
	rail_dir.y = 0.0
	if rail_dir.length_squared() < 0.01:
		return false
	rail_dir = rail_dir.normalized()
	var approach := -_host.global_transform.basis.z
	approach.y = 0.0
	if approach.length_squared() < 0.001:
		return false
	approach = approach.normalized()
	if approach.dot(rail_dir) < min_approach_dot:
		return false
	is_grinding = true
	_timer = grind_duration
	_rail_index = nearest
	_segments_ridden = 0
	grind_started.emit()
	return true


func request_jump_exit() -> bool:
	if not is_grinding:
		return false
	_finish("jump_exit", true)
	return true


func tick(delta: float) -> Dictionary:
	if not is_grinding:
		return {"active": false, "velocity": Vector3.ZERO, "multiplier": 1.0}
	_timer -= delta
	if _timer <= 0.0 or _rail_index >= _rail_points.size() - 1:
		_finish("end_of_rail", _segments_ridden >= 1)
		return {"active": false, "velocity": Vector3.ZERO, "multiplier": 1.0}

	var a := _rail_points[_rail_index]
	var b := _rail_points[mini(_rail_index + 1, _rail_points.size() - 1)]
	var dir := b - a
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		_finish("degenerate", false)
		return {"active": false, "velocity": Vector3.ZERO, "multiplier": 1.0}
	dir = dir.normalized()
	var target := a.lerp(b, 0.55) + Vector3(0, 1.2, 0)
	_host.global_position = _host.global_position.lerp(target, clampf(6.0 * delta, 0.0, 1.0))
	if _host.global_position.distance_to(b + Vector3(0, 1.2, 0)) < 1.4:
		_rail_index += 1
		_segments_ridden += 1
	var look := _host.global_position + dir * 3.0
	look.y = _host.global_position.y
	_host.look_at(look, Vector3.UP)
	var speed := 16.0
	if "horizontal_speed" in _host:
		speed = maxf(float(_host.horizontal_speed), 14.0)
		_host.horizontal_speed = speed * grind_speed_bonus
	return {
		"active": true,
		"velocity": dir * speed * grind_speed_bonus,
		"multiplier": grind_speed_bonus,
	}


func _nearest_rail_index(pos: Vector3) -> int:
	var best := -1
	var best_d := attach_radius + 1.0
	for i in _rail_points.size():
		var d := pos.distance_to(_rail_points[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func _finish(reason: String, grant_exit_boost: bool) -> void:
	if not is_grinding:
		return
	is_grinding = false
	_timer = 0.0
	if grant_exit_boost and _host != null:
		var boost := _host.get_node_or_null("BoostSystem")
		if boost != null and boost.has_method("apply_external_boost"):
			boost.apply_external_boost(exit_boost_mult, exit_boost_duration, "rail_exit")
		if boost != null and boost.has_method("add_boost"):
			boost.add_boost(8.0 + float(_segments_ridden) * 2.0, "rail_exit")
	grind_ended.emit(reason)


func _stop() -> void:
	_finish("stop", false)
