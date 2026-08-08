extends Node

## Lightweight rail grind: jump near a grindable rail segment to ride along it briefly.
## Alpha depth — greybox rails from track data; art polish is REQUIRES_ART_PRODUCTION.

signal grind_started
signal grind_ended

@export var grind_speed_bonus: float = 1.18
@export var grind_duration: float = 1.35
@export var attach_radius: float = 2.8

var is_grinding: bool = false
var _timer: float = 0.0
var _rail_points: Array[Vector3] = []
var _rail_index: int = 0
var _host: CharacterBody3D


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
	is_grinding = true
	_timer = grind_duration
	_rail_index = nearest
	grind_started.emit()
	return true


func tick(delta: float) -> Dictionary:
	## Returns {"active": bool, "velocity": Vector3, "multiplier": float}
	if not is_grinding:
		return {"active": false, "velocity": Vector3.ZERO, "multiplier": 1.0}
	_timer -= delta
	if _timer <= 0.0 or _rail_index >= _rail_points.size() - 1:
		_stop()
		return {"active": false, "velocity": Vector3.ZERO, "multiplier": 1.0}

	var a := _rail_points[_rail_index]
	var b := _rail_points[mini(_rail_index + 1, _rail_points.size() - 1)]
	var dir := b - a
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		_stop()
		return {"active": false, "velocity": Vector3.ZERO, "multiplier": 1.0}
	dir = dir.normalized()
	var target := a.lerp(b, 0.55) + Vector3(0, 1.2, 0)
	_host.global_position = _host.global_position.lerp(target, clampf(6.0 * delta, 0.0, 1.0))
	if _host.global_position.distance_to(b + Vector3(0, 1.2, 0)) < 1.4:
		_rail_index += 1
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


func _stop() -> void:
	if not is_grinding:
		return
	is_grinding = false
	_timer = 0.0
	grind_ended.emit()
