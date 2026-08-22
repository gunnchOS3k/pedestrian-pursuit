extends RefCounted
## Wave010 SYNTHETIC_INPUT_DRIVER — identical steering for BASIC and ADVANCED.
## BASIC: skills off. ADVANCED: same baseline + skill inputs only.
## Skill timing uses simulation seconds via physics delta (time-scale invariant).
## Never mutates player transform, velocity, checkpoints, or laps.
## Technique success is NOT counted here (production signals only).

const LOOK_AHEAD: float = 12.0
const STEERING_GAIN: float = 4.2
const STEERING_MULTIPLIER: float = 1.0
const LATERAL_BLEND: float = 0.35
const LATERAL_THRESHOLD: float = 3.0
const TANGENT_SAMPLE: float = 3.0
const SPEED_LOOK_AHEAD_FACTOR: float = 0.25
const SPEED_LOOK_AHEAD_CAP: float = 8.0
const PROGRESS_AHEAD_FACTOR: float = 0.05
const PROGRESS_MIN_SPEED: float = 4.0

## Skill policy (sim seconds — NOT frame counts).
const FRAME_COUNT_SKILL_TIMING: bool = false
const DRIVER_INTENT_COUNTED_AS_SUCCESS: bool = false
const DRIFT_MIN_SPEED: float = 5.0
const DRIFT_CURVATURE_ENTER: float = 0.11
const DRIFT_CURVATURE_HOLD: float = 0.06
const DRIFT_STEER_ENTER: float = 0.36
const DRIFT_STEER_HOLD: float = 0.22
const DRIFT_MIN_HOLD_SEC: float = 0.45
const DRIFT_MAX_HOLD_SEC: float = 1.25
const DRIFT_SAFE_RELEASE_SEC: float = 1.40
const OVERCOMMIT_PROD_SEC: float = 2.4
const SKILL_COOLDOWN_SEC: float = 3.1
const BOOST_COOLDOWN_SEC: float = 1.8
const BOOST_PULSE_SEC: float = 0.06
const BOOST_START_DELAY_SEC: float = 1.0
const STRAIGHT_CURVATURE: float = 0.055
const STRAIGHT_STEER: float = 0.30
const MAX_LATERAL_FOR_SKILL: float = 4.2
const ABORT_LATERAL: float = 6.0
const MAX_SKILL_EVENT_LOG: int = 48

var look_ahead: float = LOOK_AHEAD
var profile: String = "basic"
var skills_enabled: bool = false
var _drift_held: bool = false
var _drift_elapsed_sec: float = 0.0
var _boost_pulse_sec: float = 0.0
var _boost_cooldown_sec: float = 0.0
var _skill_cooldown_sec: float = 0.0
var _sim_elapsed_sec: float = 0.0
var _progress: float = -1.0
var _path_ref: Path3D = null
## Intent mirrors only — NEVER used as mastery technique success.
var intent_counts: Dictionary = {
	"drift_press": 0,
	"boost_press": 0,
}
var skill_event_log: Array = []
var diagnostics: Dictionary = {
	"FRAME_COUNT_SKILL_TIMING": FRAME_COUNT_SKILL_TIMING,
	"DRIVER_INTENT_COUNTED_AS_SUCCESS": DRIVER_INTENT_COUNTED_AS_SUCCESS,
	"ADVANCED_OVERCOMMIT_RELEASES": 0,
	"drift_starts": 0,
	"drift_releases": 0,
	"boost_intents": 0,
	"boost_confirmed_manual": 0,
	"boost_suppressed_meter": 0,
	"boost_suppressed_corner": 0,
	"drift_suppressed_speed": 0,
	"drift_suppressed_curve": 0,
	"low_quality_skips": 0,
}


func reset(profile_name: String) -> void:
	profile = profile_name
	skills_enabled = profile_name == "advanced"
	look_ahead = LOOK_AHEAD
	_drift_held = false
	_drift_elapsed_sec = 0.0
	_boost_pulse_sec = 0.0
	_boost_cooldown_sec = 0.0
	_skill_cooldown_sec = 0.9
	_sim_elapsed_sec = 0.0
	_progress = -1.0
	_path_ref = null
	intent_counts = {"drift_press": 0, "boost_press": 0}
	skill_event_log = []
	diagnostics = {
		"FRAME_COUNT_SKILL_TIMING": FRAME_COUNT_SKILL_TIMING,
		"DRIVER_INTENT_COUNTED_AS_SUCCESS": DRIVER_INTENT_COUNTED_AS_SUCCESS,
		"ADVANCED_OVERCOMMIT_RELEASES": 0,
		"drift_starts": 0,
		"drift_releases": 0,
		"boost_intents": 0,
		"boost_confirmed_manual": 0,
		"boost_suppressed_meter": 0,
		"boost_suppressed_corner": 0,
		"drift_suppressed_speed": 0,
		"drift_suppressed_curve": 0,
		"low_quality_skips": 0,
	}
	_release_all_actions()


func driver_parameters() -> Dictionary:
	return {
		"look_ahead": LOOK_AHEAD,
		"steering_gain": STEERING_GAIN,
		"steering_multiplier": STEERING_MULTIPLIER,
		"lateral_blend": LATERAL_BLEND,
		"lateral_threshold": LATERAL_THRESHOLD,
		"tangent_sample": TANGENT_SAMPLE,
		"speed_look_ahead_factor": SPEED_LOOK_AHEAD_FACTOR,
		"speed_look_ahead_cap": SPEED_LOOK_AHEAD_CAP,
		"progress_ahead_factor": PROGRESS_AHEAD_FACTOR,
		"progress_min_speed": PROGRESS_MIN_SPEED,
		"brake_coast": "none",
		"recovery_policy": "progress_pull_no_body_teleport",
	}


func parameter_hash() -> String:
	var params := driver_parameters()
	var keys: Array = params.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k in keys:
		parts.append("%s=%s" % [str(k), str(params[k])])
	return "|".join(parts).sha256_text()


func get_skill_policy_flags() -> Dictionary:
	return {
		"FRAME_COUNT_SKILL_TIMING": FRAME_COUNT_SKILL_TIMING,
		"DRIVER_INTENT_COUNTED_AS_SUCCESS": DRIVER_INTENT_COUNTED_AS_SUCCESS,
		"ADVANCED_OVERCOMMIT_RELEASES": int(diagnostics.get("ADVANCED_OVERCOMMIT_RELEASES", 0)),
		"skill_timing_unit": "simulation_seconds",
	}


func _gm() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("GameManager")


func _im() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("InputManager")


func force_normal_input_flags() -> void:
	var gm := _gm()
	if gm == null:
		return
	gm.accept_test_mode = false
	gm.accept_force_laps = 0
	gm.auto_accelerate = false
	gm.accept_steer = 0.0
	gm.mobile_assist_steer = 0.0


func tick(player: Node3D, path: Path3D, delta: float = -1.0) -> void:
	force_normal_input_flags()
	var dt := delta
	if dt < 0.0:
		dt = 1.0 / 60.0
	# Clamp pathological spikes; still sim-seconds (time_scale-aware via caller delta).
	dt = clampf(dt, 0.0, 0.25)
	_sim_elapsed_sec += dt
	_path_ref = path
	look_ahead = LOOK_AHEAD
	var steer := compute_steer(player, path)
	steer = clampf(steer * STEERING_MULTIPLIER, -1.0, 1.0)
	var im := _im()
	if im != null:
		im.set_touch_steer(steer)
		im.set_touch_accelerate(true)
	Input.action_press("accelerate")
	Input.action_release("brake")
	if skills_enabled:
		_tick_advanced(player, path, steer, dt)
	else:
		_release_skill_actions()


func compute_steer(player: Node3D, path: Path3D) -> float:
	if player == null or path == null or path.curve == null:
		return 0.0
	var curve: Curve3D = path.curve
	var path_len: float = maxf(curve.get_baked_length(), 1.0)
	var local: Vector3 = path.to_local(player.global_position)
	var closest: float = curve.get_closest_offset(local)
	if _progress < 0.0:
		_progress = closest
	var ahead_bias := 0.0
	var speed := 0.0
	if "horizontal_speed" in player:
		speed = absf(float(player.horizontal_speed))
	ahead_bias = maxf(speed, PROGRESS_MIN_SPEED) * PROGRESS_AHEAD_FACTOR
	var delta_along := closest - _progress
	if delta_along < -path_len * 0.5:
		delta_along += path_len
	elif delta_along > path_len * 0.5:
		delta_along -= path_len
	if delta_along > -2.0:
		_progress = fposmod(_progress + maxf(delta_along, 0.0) + ahead_bias, path_len)
	else:
		_progress = fposmod(_progress + ahead_bias * 0.5, path_len)

	var sample_ahead: float = look_ahead + clampf(speed * SPEED_LOOK_AHEAD_FACTOR, 0.0, SPEED_LOOK_AHEAD_CAP)
	var on_path: Vector3 = path.to_global(curve.sample_baked(_progress))
	var tangent_pos: Vector3 = path.to_global(
		curve.sample_baked(fposmod(_progress + TANGENT_SAMPLE, path_len))
	)
	var target: Vector3 = path.to_global(
		curve.sample_baked(fposmod(_progress + sample_ahead, path_len))
	)
	var tangent: Vector3 = tangent_pos - on_path
	tangent.y = 0.0
	if tangent.length_squared() > 0.01:
		tangent = tangent.normalized()
	else:
		tangent = Vector3.FORWARD

	var lateral: Vector3 = player.global_position - on_path
	lateral.y = 0.0
	if lateral.length() > LATERAL_THRESHOLD:
		target = target.lerp(on_path, LATERAL_BLEND)

	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var along := forward.dot(tangent)
	if along < 0.15:
		var turn_sign := signf(forward.cross(tangent).y)
		if is_zero_approx(turn_sign):
			turn_sign = 1.0
		return clampf(turn_sign * 1.0, -1.0, 1.0)

	var to_target: Vector3 = target - player.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return 0.0
	var dir: Vector3 = to_target.normalized()
	var cross_y: float = forward.cross(dir).y
	return clampf(cross_y * STEERING_GAIN, -1.0, 1.0)


func path_curvature(path: Path3D, offset: float = -1.0) -> float:
	if path == null or path.curve == null:
		return 0.0
	var curve: Curve3D = path.curve
	var path_len: float = maxf(curve.get_baked_length(), 1.0)
	var o := offset if offset >= 0.0 else _progress
	if o < 0.0:
		o = 0.0
	var sample: float = 4.0
	var p0: Vector3 = path.to_global(curve.sample_baked(fposmod(o, path_len)))
	var p1: Vector3 = path.to_global(curve.sample_baked(fposmod(o + sample, path_len)))
	var p2: Vector3 = path.to_global(curve.sample_baked(fposmod(o + sample * 2.0, path_len)))
	var t0: Vector3 = p1 - p0
	var t1: Vector3 = p2 - p1
	t0.y = 0.0
	t1.y = 0.0
	if t0.length_squared() < 0.0001 or t1.length_squared() < 0.0001:
		return 0.0
	t0 = t0.normalized()
	t1 = t1.normalized()
	var dot := clampf(t0.dot(t1), -1.0, 1.0)
	return acos(dot) / sample


func _path_lateral(player: Node3D, path: Path3D) -> float:
	if player == null or path == null or path.curve == null:
		return 0.0
	var curve: Curve3D = path.curve
	var local: Vector3 = path.to_local(player.global_position)
	var closest: float = curve.get_closest_offset(local)
	var on_path: Vector3 = path.to_global(curve.sample_baked(closest))
	var lateral: Vector3 = player.global_position - on_path
	lateral.y = 0.0
	return lateral.length()


func _heading_ok(player: Node3D, path: Path3D) -> bool:
	if player == null or path == null or path.curve == null:
		return true
	var curve: Curve3D = path.curve
	var path_len: float = maxf(curve.get_baked_length(), 1.0)
	var local: Vector3 = path.to_local(player.global_position)
	var closest: float = curve.get_closest_offset(local)
	var on_path: Vector3 = path.to_global(curve.sample_baked(closest))
	var ahead: Vector3 = path.to_global(curve.sample_baked(fposmod(closest + 3.0, path_len)))
	var tangent: Vector3 = ahead - on_path
	tangent.y = 0.0
	if tangent.length_squared() < 0.01:
		return true
	tangent = tangent.normalized()
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return true
	forward = forward.normalized()
	return forward.dot(tangent) >= 0.25


func _tick_advanced(player: Node3D, path: Path3D, steer: float, dt: float) -> void:
	var speed := 0.0
	if "horizontal_speed" in player:
		speed = absf(float(player.horizontal_speed))
	var upright := player.global_position.y > -1.0
	var curve_mag := path_curvature(path)
	var lateral := _path_lateral(player, path)
	var heading_ok := _heading_ok(player, path)
	var line_ok := lateral <= MAX_LATERAL_FOR_SKILL and heading_ok
	var high_curve := curve_mag >= DRIFT_CURVATURE_ENTER and absf(steer) >= DRIFT_STEER_ENTER
	var hold_curve := curve_mag >= DRIFT_CURVATURE_HOLD or absf(steer) >= DRIFT_STEER_HOLD
	var straight := curve_mag <= STRAIGHT_CURVATURE and absf(steer) <= STRAIGHT_STEER
	var fast_enough := speed >= DRIFT_MIN_SPEED

	if _skill_cooldown_sec > 0.0:
		_skill_cooldown_sec = maxf(0.0, _skill_cooldown_sec - dt)
	if _boost_cooldown_sec > 0.0:
		_boost_cooldown_sec = maxf(0.0, _boost_cooldown_sec - dt)

	# End brief boost pulse so just_pressed can fire again later.
	if _boost_pulse_sec > 0.0:
		_boost_pulse_sec = maxf(0.0, _boost_pulse_sec - dt)
		if _boost_pulse_sec <= 0.0:
			Input.action_release("boost")

	var drift_sys = player.get_node_or_null("DriftSystem") if player != null else null
	var boost_sys = player.get_node_or_null("BoostSystem") if player != null else null

	# Drift: only when speed + curvature warrant and line is healthy; release before overcommit.
	if _drift_held:
		_drift_elapsed_sec += dt
		Input.action_press("drift")
		var prod_drift_t := _drift_elapsed_sec
		var prod_tier := 0
		if drift_sys != null:
			if "_drift_time" in drift_sys:
				prod_drift_t = float(drift_sys._drift_time)
			if "spark_tier" in drift_sys:
				prod_tier = int(drift_sys.spark_tier)
		var release_now := false
		var release_reason := ""
		if lateral >= ABORT_LATERAL or not upright:
			release_now = true
			release_reason = "line_abort"
		elif _drift_elapsed_sec >= DRIFT_MAX_HOLD_SEC:
			release_now = true
			release_reason = "max_hold"
		elif prod_tier >= 2 and _drift_elapsed_sec >= DRIFT_MIN_HOLD_SEC and not hold_curve:
			# Release after earning a useful spark tier when curve opens.
			release_now = true
			release_reason = "tier2_exit"
		elif _drift_elapsed_sec >= DRIFT_SAFE_RELEASE_SEC:
			release_now = true
			release_reason = "safe_release"
		elif _drift_elapsed_sec >= DRIFT_MIN_HOLD_SEC and not hold_curve and prod_tier >= 1:
			release_now = true
			release_reason = "curve_exit"
		elif prod_drift_t >= OVERCOMMIT_PROD_SEC - 0.35 and prod_tier < 2:
			release_now = true
			release_reason = "pre_overcommit"
		if release_now:
			_release_drift(drift_sys, release_reason, prod_drift_t, prod_tier)
	elif (
		upright
		and fast_enough
		and high_curve
		and line_ok
		and _skill_cooldown_sec <= 0.0
		and _boost_pulse_sec <= 0.0
	):
		Input.action_press("drift")
		_drift_held = true
		_drift_elapsed_sec = 0.0
		intent_counts["drift_press"] = int(intent_counts["drift_press"]) + 1
		diagnostics["drift_starts"] = int(diagnostics["drift_starts"]) + 1
		_log_skill_event("drift_start", {
			"speed": snappedf(speed, 0.01),
			"curvature": snappedf(curve_mag, 0.001),
			"steer": snappedf(steer, 0.01),
			"lateral": snappedf(lateral, 0.01),
		})
	else:
		Input.action_release("drift")
		if skills_enabled and upright and _skill_cooldown_sec <= 0.0 and not _drift_held:
			if not fast_enough and high_curve:
				diagnostics["drift_suppressed_speed"] = int(diagnostics["drift_suppressed_speed"]) + 1
			elif fast_enough and not high_curve:
				diagnostics["drift_suppressed_curve"] = int(diagnostics["drift_suppressed_curve"]) + 1
				diagnostics["low_quality_skips"] = int(diagnostics["low_quality_skips"]) + 1
			elif not line_ok:
				diagnostics["low_quality_skips"] = int(diagnostics["low_quality_skips"]) + 1

	# Manual boost: meter/cost, not unsafe corner, sim-time cooldown; confirm via production later.
	if (
		upright
		and not _drift_held
		and fast_enough
		and straight
		and line_ok
		and _boost_cooldown_sec <= 0.0
		and _boost_pulse_sec <= 0.0
		and _sim_elapsed_sec >= BOOST_START_DELAY_SEC
	):
		var meter_ok := true
		if boost_sys != null and "current_boost" in boost_sys and "boost_cost" in boost_sys:
			meter_ok = float(boost_sys.current_boost) >= float(boost_sys.boost_cost) * 0.98
		if not meter_ok:
			diagnostics["boost_suppressed_meter"] = int(diagnostics["boost_suppressed_meter"]) + 1
		else:
			Input.action_press("boost")
			intent_counts["boost_press"] = int(intent_counts["boost_press"]) + 1
			diagnostics["boost_intents"] = int(diagnostics["boost_intents"]) + 1
			_boost_pulse_sec = BOOST_PULSE_SEC
			_boost_cooldown_sec = BOOST_COOLDOWN_SEC
			_log_skill_event("boost_intent", {
				"speed": snappedf(speed, 0.01),
				"curvature": snappedf(curve_mag, 0.001),
				"meter": snappedf(float(boost_sys.current_boost), 0.1) if boost_sys != null and "current_boost" in boost_sys else -1.0,
			})
	elif not straight and not _drift_held and _boost_cooldown_sec <= 0.0 and fast_enough:
		diagnostics["boost_suppressed_corner"] = int(diagnostics["boost_suppressed_corner"]) + 1

	Input.action_release("jump")
	Input.action_release("trick")


func note_manual_boost_confirmed() -> void:
	## Called by E2E when production boost_activated(source=manual) fires — diagnostic only.
	diagnostics["boost_confirmed_manual"] = int(diagnostics["boost_confirmed_manual"]) + 1
	_log_skill_event("boost_confirmed_manual", {"t": snappedf(_sim_elapsed_sec, 0.01)})


func _release_drift(drift_sys: Node, reason: String, prod_drift_t: float, prod_tier: int) -> void:
	Input.action_release("drift")
	_drift_held = false
	diagnostics["drift_releases"] = int(diagnostics["drift_releases"]) + 1
	# Production overcommit: _drift_time > 2.4 and spark_tier < 2 (read-only).
	if prod_drift_t > OVERCOMMIT_PROD_SEC and prod_tier < 2:
		diagnostics["ADVANCED_OVERCOMMIT_RELEASES"] = int(diagnostics["ADVANCED_OVERCOMMIT_RELEASES"]) + 1
		_log_skill_event("overcommit_release", {
			"reason": reason,
			"prod_drift_t": snappedf(prod_drift_t, 0.01),
			"tier": prod_tier,
		})
	else:
		_log_skill_event("drift_release", {
			"reason": reason,
			"held_sec": snappedf(_drift_elapsed_sec, 0.01),
			"prod_drift_t": snappedf(prod_drift_t, 0.01),
			"tier": prod_tier,
		})
	_drift_elapsed_sec = 0.0
	_skill_cooldown_sec = SKILL_COOLDOWN_SEC
	# Silence unused when null.
	if drift_sys == null:
		pass


func _log_skill_event(kind: String, payload: Dictionary) -> void:
	if skill_event_log.size() >= MAX_SKILL_EVENT_LOG:
		return
	var row := {"t": snappedf(_sim_elapsed_sec, 0.01), "kind": kind}
	for k in payload.keys():
		row[k] = payload[k]
	skill_event_log.append(row)


func _release_skill_actions() -> void:
	Input.action_release("drift")
	Input.action_release("boost")
	Input.action_release("jump")
	Input.action_release("trick")
	_drift_held = false
	_drift_elapsed_sec = 0.0
	_boost_pulse_sec = 0.0


func _release_all_actions() -> void:
	_release_skill_actions()
	Input.action_release("accelerate")
	Input.action_release("brake")
	var im := _im()
	if im != null:
		im.set_touch_steer(0.0)
		im.set_touch_accelerate(false)
