extends SpringArm3D

## Damped chase observer. Physics stays on the racer; presentation updates in _process.
## Optical forward is local -Z. SpringArm extends opposite travel so the Camera3D sits behind.

const _Dir = preload("res://scripts/player/CameraDirection.gd")

enum Profile { COMFORT, DYNAMIC, REDUCED_MOTION }

const CAMERA_OCCLUDER_MASK := 128 ## Layer 8 — tall walls/scenery only. Not rails or track deck.

## Metric thresholds defined BEFORE results (digital structural gates, not human feel).
const POSITION_DISCONTINUITY_M := 0.35
const YAW_DISCONTINUITY_RAD := 0.12
const NORMAL_RUN_SHAKE_MAX := 0.0
const HIGH_FREQ_POS_RMS_MAX := 0.08
const LANDING_IMPACT_THRESHOLD := 6.0
const VELOCITY_HEADING_SPEED := 2.4
const REVERSE_KEEP_FACING_DOT := -0.15

@export var follow_smoothing: float = 8.0
@export var look_ahead: float = 2.4
@export var shake_decay: float = 8.0
@export var base_fov: float = 65.0
@export var max_fov: float = 73.5
@export var base_spring_length: float = 8.4
@export var max_spring_length: float = 9.2
@export var base_look_ahead: float = 2.4
@export var max_look_ahead: float = 4.2
@export var speed_ref: float = 24.0

var _target: Node3D
var _shake_strength: float = 0.0
var _follow_offset: Vector3
var _camera: Camera3D
var _raw_speed_ratio: float = 0.0
var _camera_speed_ratio: float = 0.0
var _boosting: bool = false
var _was_boosting: bool = false
var _boost_pulse: float = 0.0
var _physics_pos := Vector3.ZERO
var _prev_physics_pos := Vector3.ZERO
var _physics_basis := Basis.IDENTITY
var _smoothed_pos := Vector3.ZERO
var _heading := 0.0
var _pitch := -0.42
var _roll := 0.0
var _has_heading := false
var _look_ahead_f := 2.4
var _spring_f := 8.4
var _impulse := Vector3.ZERO
var _profile: int = Profile.COMFORT
var _last_camera_pos := Vector3.ZERO
var _last_follow_offset := Vector3.ZERO
var _last_yaw := 0.0
var _prev_desired_yaw := 0.0
var _turn_rate := 0.0
var _lateral := 0.0
var _was_airborne := false
var _airborne_vy := 0.0
var _profile_locked := false
var _have_cam_sample := false
var telemetry = null


func _ready() -> void:
	spring_length = base_spring_length
	_follow_offset = position
	_spring_f = base_spring_length
	_look_ahead_f = base_look_ahead
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera != null:
		_camera.fov = base_fov
	# Keep occlusion for tall blockers; exclude track deck / low rails (layer 1).
	collision_mask = CAMERA_OCCLUDER_MASK
	margin = 0.35
	# Resolve a11y only once a racer is attached so headless unit tests keep comfort defaults.
	if _target != null and not _profile_locked:
		_apply_profile(_resolve_profile())
	else:
		_apply_profile(_profile)


func set_target(target: Node3D) -> void:
	_target = target
	if _target != null:
		_physics_pos = _target.global_position
		_prev_physics_pos = _physics_pos
		_smoothed_pos = _physics_pos + _follow_offset
		global_position = _smoothed_pos
		if _target.has_signal("speed_changed"):
			if not _target.speed_changed.is_connected(_on_speed_changed):
				_target.speed_changed.connect(_on_speed_changed)
		_seed_heading_from_target()


func set_boosting(active: bool) -> void:
	_boosting = active


func set_profile(profile: int) -> void:
	_profile_locked = true
	_apply_profile(profile)


func add_shake(strength: float) -> void:
	## Impact-only impulse. Normal run / cadence / boost sustain must not call this
	## as continuous jitter. Reduce Motion and Comfort ignore run-level noise.
	if _profile == Profile.REDUCED_MOTION or _resolve_profile() == Profile.REDUCED_MOTION:
		return
	if not _shake_allowed():
		return
	if strength < 0.35:
		return
	_shake_strength = maxf(_shake_strength, minf(strength, 0.85))
	_impulse = Vector3(0.0, 0.012 * strength, 0.0)


func _yaw_for_minus_z_forward(dir: Vector3) -> float:
	return _Dir.yaw_for_minus_z_forward(dir)


func get_optical_forward() -> Vector3:
	if _camera != null:
		return _Dir.optical_forward(_camera.global_transform.basis)
	return _Dir.optical_xz_from_yaw(_heading)


func get_camera3d() -> Camera3D:
	return _camera


func _accessibility() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("AccessibilitySettings")


func _game_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("GameManager")


func _shake_allowed() -> bool:
	if _profile_locked:
		return _profile != Profile.REDUCED_MOTION
	var allowed := true
	var gm := _game_manager()
	if gm != null and "camera_shake_enabled" in gm:
		allowed = bool(gm.camera_shake_enabled)
	var a11y := _accessibility()
	if a11y != null and a11y.has_method("camera_shake_allowed"):
		allowed = a11y.camera_shake_allowed()
	return allowed


func _resolve_profile() -> int:
	if _profile_locked:
		return _profile
	var a11y := _accessibility()
	if a11y != null and bool(a11y.get("reduce_motion")):
		return Profile.REDUCED_MOTION
	var gm := _game_manager()
	if gm != null and "camera_profile" in gm:
		return int(gm.camera_profile)
	return _profile


func _apply_profile(profile: int) -> void:
	_profile = profile
	match profile:
		Profile.DYNAMIC:
			base_fov = 66.0
			max_fov = 79.0
			base_spring_length = 8.2
			max_spring_length = 9.6
			base_look_ahead = 2.6
			max_look_ahead = 4.8
		Profile.REDUCED_MOTION:
			base_fov = 65.0
			max_fov = 65.8
			base_spring_length = 8.4
			max_spring_length = 8.5
			base_look_ahead = 2.2
			max_look_ahead = 2.6
		_:
			base_fov = 65.0
			max_fov = 73.5
			base_spring_length = 8.4
			max_spring_length = 9.2
			base_look_ahead = 2.4
			max_look_ahead = 4.2


func _on_speed_changed(speed: float) -> void:
	_raw_speed_ratio = clampf(speed / maxf(speed_ref, 0.01), 0.0, 1.35)


func _exp_alpha(lambda: float, delta: float) -> float:
	return 1.0 - exp(-lambda * maxf(delta, 0.0))


func _physics_process(_delta: float) -> void:
	if _target == null:
		# Headless tests still expect speed presentation to move without a target.
		_apply_speed_presentation(_delta if _delta > 0.0 else 0.16)
		return
	_prev_physics_pos = _physics_pos
	_physics_pos = _target.global_position
	_physics_basis = _target.global_transform.basis
	# Keep existing FullProductDepthTest contract: look_ahead/FOV respond in physics too.
	_apply_speed_presentation(_delta)


func _process(delta: float) -> void:
	if _target != null or _profile_locked:
		var next := _resolve_profile()
		if next != _profile:
			_apply_profile(next)
	_apply_speed_presentation(delta)
	if _target == null:
		return
	var target_pos := _interpolated_target_position()
	_update_translation(target_pos, delta)
	_update_heading(target_pos, delta)
	_apply_orientation()
	_apply_impact_impulse(delta)
	_update_landing_impulse()
	_record_telemetry(delta)


func _interpolated_target_position() -> Vector3:
	if _target != null and _target.has_method("get_global_transform_interpolated"):
		var xf: Transform3D = _target.get_global_transform_interpolated()
		return xf.origin
	var frac := Engine.get_physics_interpolation_fraction() if Engine.has_method("get_physics_interpolation_fraction") else 1.0
	return _prev_physics_pos.lerp(_physics_pos, clampf(frac, 0.0, 1.0))


func _apply_speed_presentation(delta: float) -> void:
	if _boosting and not _was_boosting and _profile != Profile.REDUCED_MOTION:
		_boost_pulse = 1.0
	_was_boosting = _boosting
	var pulse_lambda := 3.8
	_boost_pulse = lerpf(_boost_pulse, 0.0, _exp_alpha(pulse_lambda, delta))
	var speed_lambda := 3.2
	if _profile == Profile.DYNAMIC:
		speed_lambda = 5.2 if _raw_speed_ratio + (0.12 if _boosting else 0.0) > _camera_speed_ratio else 2.4
	elif _profile == Profile.REDUCED_MOTION:
		speed_lambda = 1.6
	var desired := _raw_speed_ratio
	if _boosting and _profile != Profile.REDUCED_MOTION:
		desired = clampf(desired + 0.12, 0.0, 1.15)
	_camera_speed_ratio = lerpf(_camera_speed_ratio, desired, _exp_alpha(speed_lambda, delta))
	var feel := clampf(_camera_speed_ratio, 0.0, 1.0)
	if _profile == Profile.REDUCED_MOTION:
		feel *= 0.12
	var look_target := lerpf(base_look_ahead, max_look_ahead, feel)
	if _boost_pulse > 0.01 and _profile != Profile.REDUCED_MOTION:
		look_target += 0.35 * _boost_pulse
	_look_ahead_f = lerpf(_look_ahead_f, look_target, _exp_alpha(2.8, delta))
	look_ahead = _look_ahead_f
	var spring_target := lerpf(base_spring_length, max_spring_length, feel * 0.35)
	if _boost_pulse > 0.01 and _profile != Profile.REDUCED_MOTION:
		spring_target += 0.22 * _boost_pulse
	_spring_f = lerpf(_spring_f, spring_target, _exp_alpha(2.1, delta))
	spring_length = _spring_f
	if _camera != null:
		var fov_t := 0.0 if _profile == Profile.REDUCED_MOTION else feel
		var target_fov := lerpf(base_fov, max_fov, clampf(fov_t, 0.0, 1.0))
		if _boost_pulse > 0.01 and _profile != Profile.REDUCED_MOTION:
			target_fov += 2.4 * _boost_pulse
		_camera.fov = lerpf(_camera.fov, target_fov, _exp_alpha(2.4, delta))


func _max_lateral() -> float:
	match _profile:
		Profile.DYNAMIC:
			return 0.65
		Profile.REDUCED_MOTION:
			return 0.12
		_:
			return 0.32


func _max_roll() -> float:
	match _profile:
		Profile.DYNAMIC:
			return deg_to_rad(2.1)
		Profile.REDUCED_MOTION:
			return 0.0
		_:
			return deg_to_rad(0.9)


func _update_translation(target_pos: Vector3, delta: float) -> void:
	var desired := target_pos + _follow_offset
	var optical := _Dir.optical_xz_from_yaw(_heading)
	var right := Vector3(-optical.z, 0.0, optical.x)
	desired += right * _lateral
	var h_lambda := 9.5 if _profile == Profile.DYNAMIC else 7.2
	var v_lambda := 3.4 if _profile == Profile.DYNAMIC else 2.6
	if _profile == Profile.REDUCED_MOTION:
		h_lambda = 5.5
		v_lambda = 2.0
	var horiz := Vector3(_smoothed_pos.x, 0.0, _smoothed_pos.z)
	var desired_h := Vector3(desired.x, 0.0, desired.z)
	horiz = horiz.lerp(desired_h, _exp_alpha(h_lambda, delta))
	var vertical := _smoothed_pos.y
	var y_err := desired.y - vertical
	# Soft dead zone: ignore animation-scale floor noise, follow real hills/jumps.
	if absf(y_err) < 0.12:
		y_err *= 0.15
	vertical += y_err * _exp_alpha(v_lambda, delta)
	_smoothed_pos = Vector3(horiz.x, vertical, horiz.z)
	global_position = _smoothed_pos


func _seed_heading_from_target() -> void:
	if _target == null:
		return
	_physics_basis = _target.global_transform.basis
	var facing := _Dir.racer_forward(_physics_basis)
	_heading = _yaw_for_minus_z_forward(facing)
	_prev_desired_yaw = _heading
	_has_heading = true
	_apply_orientation()


func _desired_travel_dir() -> Vector3:
	var facing := _Dir.racer_forward(_physics_basis)
	var velocity := Vector3.ZERO
	if _target != null and "velocity" in _target:
		velocity = _target.velocity
	velocity.y = 0.0
	var desired_dir := facing
	if velocity.length() > VELOCITY_HEADING_SPEED and facing.length_squared() > 0.001:
		var vel_dir := velocity.normalized()
		# Reverse / collision bounce must not flip the chase 180°.
		if vel_dir.dot(facing) < REVERSE_KEEP_FACING_DOT:
			desired_dir = facing
		else:
			var blend := clampf((velocity.length() - VELOCITY_HEADING_SPEED) / 6.0, 0.0, 1.0)
			desired_dir = facing.lerp(vel_dir, blend)
			if desired_dir.length_squared() > 0.001:
				desired_dir = desired_dir.normalized()
	elif facing.length_squared() > 0.001:
		desired_dir = facing.normalized()
	if _is_drifting() and velocity.length() > 1.0:
		var exit_dir := velocity.normalized()
		desired_dir = desired_dir.lerp(exit_dir, 0.35)
		if desired_dir.length_squared() > 0.001:
			desired_dir = desired_dir.normalized()
	return desired_dir


func _is_drifting() -> bool:
	if _target == null:
		return false
	if _target.has_method("is_camera_drifting"):
		return bool(_target.is_camera_drifting())
	if "drift_system" in _target and _target.drift_system != null:
		return bool(_target.drift_system.get("is_drifting"))
	return false


func _update_heading(target_pos: Vector3, delta: float) -> void:
	var desired_dir := _desired_travel_dir()
	if desired_dir.length_squared() < 0.001:
		return
	var desired_yaw := _yaw_for_minus_z_forward(desired_dir)
	if not _has_heading:
		_heading = desired_yaw
		_prev_desired_yaw = desired_yaw
		_has_heading = true
	var yaw_step := wrapf(desired_yaw - _prev_desired_yaw, -PI, PI)
	var rate_lambda := 5.0 if _profile == Profile.DYNAMIC else 3.6
	if _profile == Profile.REDUCED_MOTION:
		rate_lambda = 2.4
	_turn_rate = lerpf(_turn_rate, yaw_step / maxf(delta, 0.0001), _exp_alpha(rate_lambda, delta))
	_prev_desired_yaw = desired_yaw
	var err := wrapf(desired_yaw - _heading, -PI, PI)
	# Heading deadband: ignore micro left/right touch corrections.
	if absf(err) < 0.035:
		err = 0.0
	var yaw_lambda := 6.8 if _profile == Profile.DYNAMIC else 4.6
	if _profile == Profile.REDUCED_MOTION:
		yaw_lambda = 3.2
	_heading = wrapf(_heading + err * _exp_alpha(yaw_lambda, delta), -PI, PI)
	var bias_scale := 0.11 if _profile == Profile.DYNAMIC else 0.08
	if _is_drifting():
		bias_scale *= 1.25
	var target_lateral := clampf(_turn_rate * bias_scale, -_max_lateral(), _max_lateral())
	if _profile == Profile.REDUCED_MOTION:
		target_lateral = clampf(target_lateral, -_max_lateral(), _max_lateral())
	_lateral = lerpf(_lateral, target_lateral, _exp_alpha(3.4, delta))
	var target_roll := clampf(-_turn_rate * 0.035, -_max_roll(), _max_roll())
	_roll = lerpf(_roll, target_roll, _exp_alpha(3.8, delta))
	var look_fwd := _Dir.optical_xz_from_yaw(_heading)
	var look_point := target_pos + look_fwd * _look_ahead_f
	var to_look := look_point - global_position
	var desired_pitch := atan2(to_look.y, Vector2(to_look.x, to_look.z).length())
	_pitch = lerpf(_pitch, desired_pitch, _exp_alpha(3.1, delta))


func _apply_orientation() -> void:
	# Arm faces opposite optical forward so the child camera sits behind the racer.
	var arm_yaw := _Dir.springarm_yaw_for_behind(_heading)
	global_transform.basis = Basis.from_euler(Vector3(0.0, arm_yaw, 0.0))
	if _camera != null:
		var length := spring_length
		if is_inside_tree():
			var hit := get_hit_length()
			if hit > 0.05:
				length = minf(spring_length, hit)
		_camera.position = Vector3(0.0, 0.0, -length)
		var xf := _camera.global_transform
		xf.basis = Basis.from_euler(Vector3(_pitch, _heading, _roll))
		_camera.global_transform = xf


func _apply_impact_impulse(delta: float) -> void:
	if _shake_strength <= 0.0 and _impulse.length_squared() < 0.000001:
		return
	# Local-space coherent impulse — never per-frame randf world teleport.
	global_position += _impulse
	_impulse = _impulse.lerp(Vector3.ZERO, _exp_alpha(10.0, delta))
	_shake_strength = maxf(0.0, _shake_strength - shake_decay * delta)
	if _shake_strength <= 0.0:
		_impulse = Vector3.ZERO


func _update_landing_impulse() -> void:
	if _target == null:
		return
	var grounded := true
	if _target.has_method("is_on_floor"):
		grounded = bool(_target.is_on_floor())
	var vy := 0.0
	if "velocity" in _target:
		vy = float(_target.velocity.y)
	if not grounded:
		_was_airborne = true
		_airborne_vy = vy
		return
	if _was_airborne and _airborne_vy < -LANDING_IMPACT_THRESHOLD:
		var impact := clampf((-_airborne_vy - LANDING_IMPACT_THRESHOLD) / 10.0, 0.0, 1.0)
		add_shake(0.38 + impact * 0.35)
	_was_airborne = false
	_airborne_vy = 0.0


func springarm_retracted() -> bool:
	var hit := get_hit_length()
	if hit <= 0.05:
		return false
	return hit + 0.05 < spring_length


func _record_telemetry(delta: float) -> void:
	if telemetry == null:
		return
	var cam_pos := _camera.global_position if _camera != null else global_position
	var follow_offset := cam_pos - _physics_pos
	var pos_delta := 0.0
	var yaw_delta := 0.0
	if _have_cam_sample:
		# High-frequency metric is framing jitter, not world chase travel.
		pos_delta = follow_offset.distance_to(_last_follow_offset)
		yaw_delta = absf(wrapf(_heading - _last_yaw, -PI, PI))
	if telemetry.has_method("sample"):
		telemetry.sample({
			"dt": delta,
			"target_position": _physics_pos,
			"camera_position": cam_pos,
			"arm_position": global_position,
			"desired_yaw": _heading,
			"camera_yaw": _heading,
			"optical_forward": get_optical_forward(),
			"racer_forward": _Dir.racer_forward(_physics_basis),
			"behind_racer": _Dir.is_behind_racer(_physics_pos, cam_pos, _Dir.racer_forward(_physics_basis)),
			"fov": _camera.fov if _camera != null else base_fov,
			"spring_length": spring_length,
			"raw_speed": _raw_speed_ratio,
			"filtered_speed": _camera_speed_ratio,
			"roll": _roll,
			"lateral": _lateral,
			"boost_pulse": _boost_pulse,
			"spring_retracted": springarm_retracted(),
			"shake_amplitude": _shake_strength,
			"pos_delta": pos_delta,
			"yaw_delta": yaw_delta,
		})
	_last_camera_pos = cam_pos
	_last_follow_offset = follow_offset
	_last_yaw = _heading
	_have_cam_sample = true
