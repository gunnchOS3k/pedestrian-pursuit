extends RefCounted
## Wave010 SYNTHETIC_INPUT_DRIVER — identical steering for BASIC and ADVANCED.
## BASIC: skills off. ADVANCED: same baseline + skill inputs only.
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

var look_ahead: float = LOOK_AHEAD
var profile: String = "basic"
var skills_enabled: bool = false
var _drift_held: bool = false
var _drift_hold_frames: int = 0
var _boost_pulse_frames: int = 0
var _boost_cooldown: int = 0
var _skill_cooldown: int = 0
var _frame: int = 0
var _progress: float = -1.0
## Intent mirrors only — NEVER used as mastery technique success.
var intent_counts: Dictionary = {
	"drift_press": 0,
	"boost_press": 0,
}


func reset(profile_name: String) -> void:
	profile = profile_name
	skills_enabled = profile_name == "advanced"
	look_ahead = LOOK_AHEAD
	_drift_held = false
	_drift_hold_frames = 0
	_boost_pulse_frames = 0
	_boost_cooldown = 0
	_skill_cooldown = 45
	_frame = 0
	_progress = -1.0
	intent_counts = {"drift_press": 0, "boost_press": 0}
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


func tick(player: Node3D, path: Path3D) -> void:
	force_normal_input_flags()
	_frame += 1
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
		_tick_advanced(player, steer)
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


func _tick_advanced(player: Node3D, steer: float) -> void:
	## Discrete skill bursts — not continuous drift (which only bleeds accel).
	var speed := 0.0
	if "horizontal_speed" in player:
		speed = absf(float(player.horizontal_speed))
	var upright := player.global_position.y > -1.0
	var turning := absf(steer) >= 0.30
	var fast_enough := speed >= 5.0

	if _skill_cooldown > 0:
		_skill_cooldown -= 1
	if _boost_cooldown > 0:
		_boost_cooldown -= 1

	# End single-frame boost pulse so just_pressed can fire again later.
	if _boost_pulse_frames > 0:
		_boost_pulse_frames -= 1
		if _boost_pulse_frames == 0:
			Input.action_release("boost")

	# Drift burst: hold briefly while turning, release while still steering.
	if _drift_held:
		_drift_hold_frames += 1
		Input.action_press("drift")
		if _drift_hold_frames >= 28 or not turning:
			Input.action_release("drift")
			_drift_held = false
			_drift_hold_frames = 0
			_skill_cooldown = 55
	elif (
		upright
		and fast_enough
		and turning
		and _skill_cooldown <= 0
		and _boost_pulse_frames == 0
	):
		Input.action_press("drift")
		_drift_held = true
		_drift_hold_frames = 0
		intent_counts["drift_press"] = int(intent_counts["drift_press"]) + 1
	else:
		Input.action_release("drift")

	# Manual boost pulse — prefer straights; allow after drifts refill meter.
	if (
		upright
		and not _drift_held
		and fast_enough
		and _boost_cooldown <= 0
		and _boost_pulse_frames == 0
		and _frame > 40
		and (not turning or _frame % 95 == 0)
	):
		Input.action_press("boost")
		intent_counts["boost_press"] = int(intent_counts["boost_press"]) + 1
		_boost_pulse_frames = 3
		_boost_cooldown = 70

	Input.action_release("jump")
	Input.action_release("trick")


func _release_skill_actions() -> void:
	Input.action_release("drift")
	Input.action_release("boost")
	Input.action_release("jump")
	Input.action_release("trick")
	_drift_held = false
	_drift_hold_frames = 0
	_boost_pulse_frames = 0


func _release_all_actions() -> void:
	_release_skill_actions()
	Input.action_release("accelerate")
	Input.action_release("brake")
	var im := _im()
	if im != null:
		im.set_touch_steer(0.0)
		im.set_touch_accelerate(false)
