extends Node

## Arcade path follower with route-planning tiers.
## Tiers differ by look-ahead, braking, shortcut preference, and recovery assist.
## No physics teleportation / speed cheats — magnet only as soft off-track recovery.

enum Tier { ROOKIE, STANDARD, ACE }

@export var look_ahead: float = 10.0
@export var speed_multiplier: float = 0.88
@export var magnet_strength: float = 0.0
@export var waypoint_threshold: float = 4.0
@export var tier: Tier = Tier.STANDARD

var path: Path3D
var _curve: Curve3D
var _progress: float = 0.0
var _path_length: float = 1.0
var _prefer_shortcut: bool = false
var _shortcut_bias: float = 0.0
var _lane_bias: float = 0.0


func setup(race_path: Path3D) -> void:
	path = race_path
	if path and path.curve:
		_curve = path.curve
		_path_length = maxf(_curve.get_baked_length(), 1.0)
	_apply_tier_defaults()


func set_tier(next_tier: Tier) -> void:
	tier = next_tier
	_apply_tier_defaults()


func configure_route_plan(prefer_shortcut: bool, lane_bias: float = 0.0) -> void:
	_prefer_shortcut = prefer_shortcut
	_lane_bias = clampf(lane_bias, -3.5, 3.5)
	_shortcut_bias = 4.0 if prefer_shortcut else 0.0


func _apply_tier_defaults() -> void:
	match tier:
		Tier.ROOKIE:
			look_ahead = 7.0
			speed_multiplier = 0.78
			# Soft recovery only when badly off-course — not continuous teleport.
			magnet_strength = 0.08
		Tier.STANDARD:
			look_ahead = 10.0
			speed_multiplier = 0.88
			magnet_strength = 0.0
		Tier.ACE:
			look_ahead = 14.0
			speed_multiplier = 0.96
			magnet_strength = 0.0
			_prefer_shortcut = true
			_shortcut_bias = 5.5


func get_steer_and_accel(body: CharacterBody3D, delta: float = 0.016) -> Dictionary:
	if _curve == null:
		return {"steer": 0.0, "accelerate": true, "drift": false, "use_item": false}

	var speed := 0.0
	if "horizontal_speed" in body:
		speed = absf(float(body.horizontal_speed))
	else:
		var v := body.velocity
		v.y = 0.0
		speed = v.length()

	if "movement_enabled" in body and not bool(body.movement_enabled):
		return {"steer": 0.0, "accelerate": true, "drift": false, "use_item": false}

	# Advance progress from actual travel — never invent extra path speed.
	_progress = fposmod(_progress + maxf(speed, 2.5) * delta, _path_length)

	var sample_ahead := look_ahead + _shortcut_bias
	var on_path := path.to_global(_curve.sample_baked(_progress))
	var mid_pos := path.to_global(
		_curve.sample_baked(fposmod(_progress + sample_ahead * 0.45, _path_length))
	)
	var target_pos := path.to_global(
		_curve.sample_baked(fposmod(_progress + sample_ahead, _path_length))
	)

	# Soft recovery magnet: only when clearly off the racing line.
	var lateral := body.global_position - on_path
	lateral.y = 0.0
	var off_track := lateral.length()
	var recovery_limit := 9.0 if tier == Tier.ROOKIE else 14.0
	if magnet_strength > 0.0 and off_track > recovery_limit * 0.55:
		body.global_position -= lateral * clampf(magnet_strength, 0.0, 0.2)
	if body.global_position.y < 0.2:
		# Height floor is spawn safety, not a speed cheat.
		body.global_position.y = on_path.y + 1.05

	# Route planning: blend near and far look targets; Ace cuts inside slightly.
	var planned := mid_pos.lerp(target_pos, 0.65 if tier == Tier.ACE else 0.5)
	if absf(_lane_bias) > 0.01:
		var tangent := (target_pos - on_path)
		tangent.y = 0.0
		if tangent.length_squared() > 0.01:
			var right := tangent.normalized().cross(Vector3.UP)
			planned += right * _lane_bias

	var to_target := planned - body.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return {"steer": 0.0, "accelerate": true, "drift": false, "use_item": false}

	var forward := -body.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var dir := to_target.normalized()
	var cross := forward.cross(dir).y
	var steer_gain := 3.2 if tier == Tier.ACE else (2.8 if tier == Tier.STANDARD else 2.2)
	var steer := clampf(cross * steer_gain, -1.0, 1.0)

	# Yaw assist only when far off heading — still player-physics steering, no snap speed.
	if absf(steer) > 0.75 and speed > 7.0 and tier != Tier.ACE:
		var look := body.global_position + dir * 4.0
		look.y = body.global_position.y
		body.look_at(look, Vector3.UP)

	var curvature := _estimate_curvature()
	var drift: bool = absf(steer) > 0.5 and speed > 8.0 and curvature > 0.015
	var accelerate := true
	var brake_steer := 0.85 if tier == Tier.ROOKIE else (0.78 if tier == Tier.STANDARD else 0.7)
	var brake_speed := 12.0 if tier == Tier.ROOKIE else (14.5 if tier == Tier.STANDARD else 16.5)
	if (absf(steer) > brake_steer or curvature > 0.03) and speed > brake_speed:
		accelerate = false

	# Pack awareness without rubber-band speed cheats: trailers keep accel when safe.
	if body.has_meta("race_place_estimate"):
		var place := int(body.get_meta("race_place_estimate"))
		if place >= 3 and absf(steer) < 0.65 and curvature < 0.025:
			accelerate = true

	var use_item := false
	if tier == Tier.ACE and body.has_meta("held_item_ready"):
		use_item = bool(body.get_meta("held_item_ready")) and absf(steer) < 0.4

	return {
		"steer": steer,
		"accelerate": accelerate,
		"drift": drift,
		"use_item": use_item,
		"curvature": curvature,
		"off_track": off_track,
	}


func _estimate_curvature() -> float:
	if _curve == null:
		return 0.0
	var p0 := _curve.sample_baked(_progress)
	var p1 := _curve.sample_baked(fposmod(_progress + 4.0, _path_length))
	var p2 := _curve.sample_baked(fposmod(_progress + 8.0, _path_length))
	var v1 := p1 - p0
	var v2 := p2 - p1
	v1.y = 0.0
	v2.y = 0.0
	if v1.length_squared() < 0.01 or v2.length_squared() < 0.01:
		return 0.0
	return absf(v1.normalized().cross(v2.normalized()).y)


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
	body.global_position = pos + Vector3(0, 1.05, 0) + right * (lane_offset + _lane_bias)
	var look_target := body.global_position + direction.normalized() * 4.0
	look_target.y = body.global_position.y
	body.look_at(look_target, Vector3.UP)
