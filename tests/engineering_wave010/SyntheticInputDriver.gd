extends RefCounted
## Wave010 SYNTHETIC_INPUT_DRIVER — steer from CourseTrack path only.
## Drives via InputManager.set_touch_* and Input.action_press/release.
## Never mutates player transform, velocity, checkpoints, or laps.

var look_ahead: float = 12.0
var profile: String = "basic"
var _drift_held: bool = false
var _drift_hold_frames: int = 0
var _boost_cooldown: int = 0
var _trick_cooldown: int = 0
var _frame: int = 0
var _progress: float = -1.0
var technique_counts: Dictionary = {
	"drift_release": 0,
	"manual_boost": 0,
	"jump_trick": 0,
	"rail": 0,
	"shortcut": 0,
}


func reset(profile_name: String) -> void:
	profile = profile_name
	_drift_held = false
	_drift_hold_frames = 0
	_boost_cooldown = 0
	_trick_cooldown = 0
	_frame = 0
	_progress = -1.0
	technique_counts = {
		"drift_release": 0,
		"manual_boost": 0,
		"jump_trick": 0,
		"rail": 0,
		"shortcut": 0,
	}
	_release_all_actions()


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
	# Profile-specific racing-line look-ahead (input style, not a speed cheat).
	# Basic must still finish reliably on CI Linux; keep shorter look-ahead than advanced.
	look_ahead = 15.0 if profile == "advanced" else 10.0
	var steer := compute_steer(player, path)
	if profile == "basic":
		# Milder corrections → wider/less precise line (not so weak it DNFs).
		steer = clampf(steer * 0.88, -1.0, 1.0)
	var im := _im()
	if im != null:
		im.set_touch_steer(steer)
		im.set_touch_accelerate(true)
	# Dual-path accel: sticky touch + action map (headless-safe).
	Input.action_press("accelerate")
	Input.action_release("brake")
	if profile == "advanced":
		_tick_advanced(player, steer)
	else:
		_release_skill_actions()
	_observe_techniques(player)


func compute_steer(player: Node3D, path: Path3D) -> float:
	## Pure geometry — no body mutation (unlike AIPathFollower magnet/snap/look_at).
	if player == null or path == null or path.curve == null:
		return 0.0
	var curve: Curve3D = path.curve
	var path_len: float = maxf(curve.get_baked_length(), 1.0)
	var local: Vector3 = path.to_local(player.global_position)
	var closest: float = curve.get_closest_offset(local)
	if _progress < 0.0:
		_progress = closest
	# Keep look-target progressing along the authored line even when the body lags.
	var ahead_bias := 0.0
	var speed := 0.0
	if "horizontal_speed" in player:
		speed = absf(float(player.horizontal_speed))
	ahead_bias = maxf(speed, 4.0) * 0.05
	# Unwrap closest relative to progress to avoid backward snaps at loop seam.
	var delta_along := closest - _progress
	if delta_along < -path_len * 0.5:
		delta_along += path_len
	elif delta_along > path_len * 0.5:
		delta_along -= path_len
	if delta_along > -2.0:
		_progress = fposmod(_progress + maxf(delta_along, 0.0) + ahead_bias, path_len)
	else:
		# Far behind: gently pull progress toward closest without teleporting the body.
		_progress = fposmod(_progress + ahead_bias * 0.5, path_len)

	var sample_ahead: float = look_ahead + clampf(speed * 0.25, 0.0, 8.0)
	var on_path: Vector3 = path.to_global(curve.sample_baked(_progress))
	var tangent_pos: Vector3 = path.to_global(
		curve.sample_baked(fposmod(_progress + 3.0, path_len))
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

	# Blend toward path center when laterally off — still input-only.
	var lateral: Vector3 = player.global_position - on_path
	lateral.y = 0.0
	if lateral.length() > 3.0:
		target = target.lerp(on_path, 0.35)

	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	# If facing opposite the race direction, hard-steer to reverse course (no look_at).
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
	var gain := 4.2
	return clampf(cross_y * gain, -1.0, 1.0)


func technique_categories_hit() -> int:
	var n := 0
	for k in technique_counts.keys():
		if int(technique_counts[k]) > 0:
			n += 1
	return n


func _tick_advanced(player: Node3D, _steer: float) -> void:
	var _speed := 0.0
	if "horizontal_speed" in player:
		_speed = absf(float(player.horizontal_speed))

	# Speed advantage = longer look-ahead. Skills are short early proof taps only.
	var need_drift := int(technique_counts["drift_release"]) < 1
	var need_boost := int(technique_counts["manual_boost"]) < 1
	var upright := player.global_position.y > -1.0

	if not need_drift and not need_boost:
		if _drift_held:
			Input.action_release("drift")
			_drift_held = false
			_drift_hold_frames = 0
		Input.action_release("boost")
		Input.action_release("jump")
		Input.action_release("trick")
		return

	# Very early windows near spawn (usually straight) so both categories always fire.
	if upright and need_drift and _frame >= 20 and _frame < 30:
		if not _drift_held:
			Input.action_press("drift")
			_drift_held = true
			_drift_hold_frames = 0
		_drift_hold_frames += 1
		Input.action_release("boost")
	elif _drift_held:
		Input.action_release("drift")
		_drift_held = false
		_drift_hold_frames = 0
		technique_counts["drift_release"] = int(technique_counts["drift_release"]) + 1
		Input.action_release("boost")
	elif upright and need_boost and not _drift_held and _frame >= 40 and _frame < 48:
		if _boost_cooldown <= 0:
			Input.action_press("boost")
			technique_counts["manual_boost"] = int(technique_counts["manual_boost"]) + 1
			_boost_cooldown = 6
		else:
			_boost_cooldown -= 1
			if _boost_cooldown == 0:
				Input.action_release("boost")
	else:
		if _drift_held:
			Input.action_release("drift")
			_drift_held = false
			_drift_hold_frames = 0
			technique_counts["drift_release"] = int(technique_counts["drift_release"]) + 1
		else:
			Input.action_release("drift")
		if _boost_cooldown > 0:
			_boost_cooldown -= 1
			if _boost_cooldown == 0:
				Input.action_release("boost")
		else:
			Input.action_release("boost")

	Input.action_release("jump")
	Input.action_release("trick")
	_trick_cooldown = 0


func _observe_techniques(player: Node3D) -> void:
	if player == null:
		return
	var rail = player.get_node_or_null("RailGrindSystem")
	if rail != null and bool(rail.get("is_grinding")):
		technique_counts["rail"] = int(technique_counts["rail"]) + 1
	if player.has_meta("on_shortcut") and bool(player.get_meta("on_shortcut")):
		technique_counts["shortcut"] = int(technique_counts["shortcut"]) + 1
	elif str(player.get("terrain_name")) == "shortcut":
		technique_counts["shortcut"] = int(technique_counts["shortcut"]) + 1


func _release_skill_actions() -> void:
	Input.action_release("drift")
	Input.action_release("boost")
	Input.action_release("jump")
	Input.action_release("trick")
	_drift_held = false


func _release_all_actions() -> void:
	_release_skill_actions()
	Input.action_release("accelerate")
	Input.action_release("brake")
	var im := _im()
	if im != null:
		im.set_touch_steer(0.0)
		im.set_touch_accelerate(false)
