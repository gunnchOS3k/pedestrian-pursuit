extends Node

## Arcade path follower: advances along the race curve by traveled speed and
## magnets the body onto the racing line. Used by AI and Android soft-assist.

@export var look_ahead: float = 10.0
@export var speed_multiplier: float = 0.88
@export var magnet_strength: float = 0.22
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


func get_steer_and_accel(body: CharacterBody3D, delta: float = 0.016) -> Dictionary:
	if _curve == null:
		return {"steer": 0.0, "accelerate": true, "drift": false}

	var speed := 0.0
	if "horizontal_speed" in body:
		speed = absf(float(body.horizontal_speed))
	else:
		var v := body.velocity
		v.y = 0.0
		speed = v.length()

	# Do not slide racers along the path during countdown.
	if "movement_enabled" in body and not bool(body.movement_enabled):
		return {"steer": 0.0, "accelerate": true, "drift": false}

	# Advance along the official racing line from motion (and a little crawl so
	# stuck racers still recover toward the next gate).
	_progress = fposmod(_progress + maxf(speed, 4.0) * delta, _path_length)

	var on_path := path.to_global(_curve.sample_baked(_progress))
	var target_pos := path.to_global(
		_curve.sample_baked(fposmod(_progress + look_ahead, _path_length))
	)

	# Lateral magnet onto the line so void falls / off-course loops stop.
	var lateral := body.global_position - on_path
	lateral.y = 0.0
	if lateral.length() > 0.15:
		body.global_position -= lateral * clampf(magnet_strength, 0.0, 1.0)
	if body.global_position.y < 0.2:
		body.global_position.y = on_path.y + 1.05

	var to_target := target_pos - body.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return {"steer": 0.0, "accelerate": true, "drift": false}

	var forward := -body.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var dir := to_target.normalized()
	var cross := forward.cross(dir).y
	var steer := clampf(cross * 3.5, -1.0, 1.0)

	# Hard-align yaw when far off the look target so corners are makeable.
	if absf(steer) > 0.65 and speed > 6.0:
		var look := body.global_position + dir * 4.0
		look.y = body.global_position.y
		body.look_at(look, Vector3.UP)

	var drift: bool = absf(steer) > 0.55 and speed > 8.0
	# Corner hazard awareness: brake-tap on sharp high-speed turns.
	var accelerate := true
	if absf(steer) > 0.8 and speed > 14.0:
		accelerate = false
	# Mild rubber-band for pack density (trailers keep accelerating).
	if body.has_meta("race_place_estimate"):
		var place := int(body.get_meta("race_place_estimate"))
		if place >= 3 and absf(steer) < 0.7:
			accelerate = true
	return {"steer": steer, "accelerate": accelerate, "drift": drift}


func snap_to_path(body: Node3D, offset: float, lane_offset: float = 0.0) -> void:
	if _curve == null:
		return
	_progress = fposmod(offset, _path_length)
	var pos := path.to_global(_curve.sample_baked(_progress))
	var next := path.to_global(_curve.sample_baked(fposmod(_progress + 2.0, _path_length)))
	var direction := next - pos
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	var right := direction.normalized().cross(Vector3.UP)
	body.global_position = pos + Vector3(0, 1.05, 0) + right * lane_offset
	var look_target := body.global_position + direction.normalized() * 4.0
	look_target.y = body.global_position.y
	body.look_at(look_target, Vector3.UP)
