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
var _shoe_id: String = "starter_soles"
var _soft_surface_score: float = 1.0
var _prefer_vertical: bool = false
## Last advance_course_estimate call, and how many grounded reacquisitions
## have happened. The headless observer reads both. Neither moves the body.
var last_reacquired: bool = false
var reacquire_count: int = 0

## A crawling body this far from the open-loop estimate is no longer being
## steered along the line. Run 39966865889 at f39658f: after Verdant's
## airborne crossing, wall deltas of 0.013–0.022 s plus a 2.5 m/s floor grew
## the gap to about 135. solo-b crawled at ~2 m/s and never retook checkpoint
## 4; solo-a and batch-first finished. Run 39972796105 at 38b6435 used the
## physics tick, so those three processes finally matched, but reacquiring
## every grounded gap over 12 m (44 times, including at racing speed) pulled
## the look target back before checkpoint 4 and all three finished zero laps.
## A moving body that is off the line keeps the forward estimate through the
## crossing. Snapping on every call, including in the
## air, missed checkpoint 4 on runs 39963277126 and 39964928289.
const REACQUIRE_GAP_M := 12.0
const REACQUIRE_VERTICAL_SPEED := 0.5
const REACQUIRE_MAX_SPEED := 4.0
## Run 39975106922 at 595e1f0: a short Verdant landing was still on the path
## (lateral 0.6 m, speed about 10) with a 55 m progress gap. The crawl-only
## gate left that gap in place, and one second later the body was in the wall
## at lateral 6.5 m. Healthy laps in that same log led the body by at most
## about 13 m. An on-line gap past 20 m is the missed landing, not that lead.
const REACQUIRE_ON_LINE_M := 1.5
const REACQUIRE_ON_LINE_GAP_M := 20.0


func setup(race_path: Path3D) -> void:
	path = race_path
	if path and path.curve:
		_curve = path.curve
		_path_length = maxf(_curve.get_baked_length(), 1.0)
	_apply_tier_defaults()


func set_shoe_context(shoe_id: String) -> void:
	_shoe_id = shoe_id
	_soft_surface_score = ShoeData.soft_surface_penalty(shoe_id)
	_prefer_vertical = ShoeData.prefers_vertical(shoe_id)
	# Soft shoes hold speed in mud; hard plates get earlier brake thresholds via curvature.
	if _soft_surface_score < 0.85:
		look_ahead = maxf(look_ahead, look_ahead * 1.08)
	elif _soft_surface_score > 1.05:
		_lane_bias = clampf(_lane_bias - 0.35, -3.5, 3.5)
	if _prefer_vertical:
		_prefer_shortcut = true
		_shortcut_bias = maxf(_shortcut_bias, 3.5)


func set_tier(next_tier: Tier) -> void:
	tier = next_tier
	_apply_tier_defaults()


func configure_route_plan(prefer_shortcut: bool, lane_bias: float = 0.0) -> void:
	_prefer_shortcut = prefer_shortcut
	_lane_bias = clampf(lane_bias, -3.5, 3.5)
	_shortcut_bias = 4.0 if prefer_shortcut else 0.0


func configure_shortcut_from_course(routes: Array, tier_name: String) -> void:
	## Ace prefers authored shortcuts; rookies rarely take risky cuts. No teleport.
	if routes.is_empty():
		return
	var best_pref := 0.0
	for route in routes:
		if typeof(route) != TYPE_DICTIONARY:
			continue
		best_pref = maxf(best_pref, float(route.get("ai_preference", 0.25)))
	match tier_name:
		"ace":
			_prefer_shortcut = best_pref >= 0.2
			_shortcut_bias = 5.5 * clampf(best_pref + 0.4, 0.4, 1.0)
			_lane_bias = clampf(_lane_bias - 1.1, -3.5, 3.5)
		"standard":
			_prefer_shortcut = best_pref >= 0.4
			_shortcut_bias = 2.5 if _prefer_shortcut else 0.0
		_:
			_prefer_shortcut = false
			_shortcut_bias = 0.0


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


func measure_course_progress(body: Node3D) -> Dictionary:
	## Read-only. Compares the integrated progress estimate with the baked
	## offset closest to the body. Does not move the body or change steering.
	if _curve == null or path == null:
		return {}
	var local := path.to_local(body.global_position)
	var closest := _curve.get_closest_offset(local)
	var on_path := path.to_global(_curve.sample_baked(closest))
	var lateral := body.global_position - on_path
	lateral.y = 0.0
	var gap := wrapped_course_gap(closest, _progress)
	return {
		"follower_progress": _progress,
		"closest_offset": closest,
		"progress_gap": gap,
		"lateral": lateral.length(),
		"path_length": _path_length,
	}


func physics_step_seconds() -> float:
	## One physics tick, scaled when the game slows time. Callers must invoke
	## advance once per physics frame. Wall-clock gaps between those frames
	## are not course distance.
	var ticks := maxi(Engine.get_physics_ticks_per_second(), 1)
	return (1.0 / float(ticks)) * maxf(Engine.time_scale, 0.0)


func wrapped_course_gap(closest_offset: float, progress: float) -> float:
	var gap := closest_offset - progress
	if gap > _path_length * 0.5:
		gap -= _path_length
	elif gap < -_path_length * 0.5:
		gap += _path_length
	return gap


func advance_course_estimate(speed: float, grounded: bool, vertical_speed: float, closest_offset: float, lateral_m: float = 99.0) -> Dictionary:
	## Move the look-ahead estimate. Does not move the body.
	## Airborne closest-offset is ambiguous on the Verdant crossing. A large
	## gap reacquires when the body is grounded and not rising or falling,
	## and either crawling or still on the racing line. A moving body that is
	## off the line keeps the forward estimate. There is no speed floor.
	var step := physics_step_seconds()
	var gap := wrapped_course_gap(closest_offset, _progress)
	var settled := grounded and absf(vertical_speed) <= REACQUIRE_VERTICAL_SPEED
	var crawling := speed <= REACQUIRE_MAX_SPEED and absf(gap) > REACQUIRE_GAP_M
	var on_line := lateral_m <= REACQUIRE_ON_LINE_M and absf(gap) > REACQUIRE_ON_LINE_GAP_M
	var reacquired := settled and (crawling or on_line)
	if reacquired:
		_progress = fposmod(closest_offset, _path_length)
		reacquire_count += 1
	else:
		_progress = fposmod(_progress + maxf(speed, 0.0) * step, _path_length)
	last_reacquired = reacquired
	return {
		"progress": _progress,
		"gap": gap,
		"reacquired": reacquired,
		"physics_delta": step,
	}


func get_steer_and_accel(body: CharacterBody3D, _delta: float = 0.016) -> Dictionary:
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

	# Physics-tick integration. The unused caller delta is wall time in the
	# headless observer and must not advance the racing line.
	var closest_offset := _curve.get_closest_offset(path.to_local(body.global_position))
	var on_path_now := path.to_global(_curve.sample_baked(closest_offset))
	var off_line := body.global_position - on_path_now
	off_line.y = 0.0
	advance_course_estimate(speed, body.is_on_floor(), body.velocity.y, closest_offset, off_line.length())

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
	# Hard-plate footwear brakes earlier when curvature rises (material-aware planning).
	var soft_factor := clampf(_soft_surface_score, 0.7, 1.25)
	var drift: bool = absf(steer) > 0.5 and speed > 8.0 and curvature > 0.015
	var accelerate := true
	var brake_steer := 0.85 if tier == Tier.ROOKIE else (0.78 if tier == Tier.STANDARD else 0.7)
	var brake_speed := 12.0 if tier == Tier.ROOKIE else (14.5 if tier == Tier.STANDARD else 16.5)
	brake_speed *= lerpf(0.88, 1.06, (soft_factor - 0.7) / 0.55)
	if soft_factor < 0.9:
		brake_steer -= 0.06
	if (absf(steer) > brake_steer or curvature > (0.03 if soft_factor >= 0.95 else 0.022)) and speed > brake_speed:
		accelerate = false

	# Pack awareness without rubber-band speed cheats: trailers keep accel when safe.
	if body.has_meta("race_place_estimate"):
		var place := int(body.get_meta("race_place_estimate"))
		if place >= 3 and absf(steer) < 0.65 and curvature < 0.025:
			accelerate = true

	var use_item := false
	if tier == Tier.ACE and body.has_meta("held_item_ready"):
		use_item = bool(body.get_meta("held_item_ready")) and absf(steer) < 0.4

	# Bounce-family footwear seeks rails when nearby (no teleport — steer bias only).
	if _prefer_vertical and body.has_meta("nearest_rail_dist"):
		var rail_d := float(body.get_meta("nearest_rail_dist"))
		if rail_d < 6.0 and absf(steer) < 0.55:
			accelerate = true

	return {
		"steer": steer,
		"accelerate": accelerate,
		"drift": drift,
		"use_item": use_item,
		"curvature": curvature,
		"off_track": off_track,
		"shoe_id": _shoe_id,
		"soft_surface_score": soft_factor,
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
