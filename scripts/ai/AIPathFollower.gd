extends Node

## Simple path follower for AI racers.

@export var look_ahead: float = 3.0
@export var speed_multiplier: float = 0.88
@export var waypoint_threshold: float = 4.0

var path: Path3D
var _curve: Curve3D
var _progress: float = 0.0
var _path_length: float = 1.0


func setup(race_path: Path3D) -> void:
	path = race_path
	if path and path.curve:
		_curve = path.curve
		_path_length = maxf(_curve.get_baked_length(), 1.0)


func get_steer_and_accel(body: CharacterBody3D, _delta: float = 0.016) -> Dictionary:
	if _curve == null:
		return {"steer": 0.0, "accelerate": true, "drift": false}

	_progress = _curve.get_closest_offset(path.to_local(body.global_position))
	var target_pos := _curve.sample_baked(fposmod(_progress + look_ahead, _path_length))
	target_pos = path.to_global(target_pos)
	var to_target := target_pos - body.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return {"steer": 0.0, "accelerate": true, "drift": false}

	var forward := -body.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var dir := to_target.normalized()
	var cross := forward.cross(dir).y
	var steer := clampf(cross * 3.0, -1.0, 1.0)
	var drift: bool = absf(steer) > 0.55 and body.horizontal_speed > 8.0
	return {"steer": steer, "accelerate": true, "drift": drift}


func snap_to_path(body: Node3D, offset: float, lane_offset: float = 0.0) -> void:
	if _curve == null:
		return
	_progress = fposmod(offset, _path_length)
	var pos := path.to_global(_curve.sample_baked(_progress))
	var next := path.to_global(_curve.sample_baked(fposmod(_progress + 2.0, _path_length)))
	var direction := next - pos
	direction.y = 0.0
	var right := direction.normalized().cross(Vector3.UP)
	body.global_position = pos + Vector3(0, 1, 0) + right * lane_offset
	body.look_at(next + Vector3(0, 1, 0), Vector3.UP)
