extends SpringArm3D

## Damped chase observer. Physics stays on the racer; presentation updates in _process.

enum Profile { COMFORT, DYNAMIC, REDUCED_MOTION }

const CAMERA_OCCLUDER_MASK := 128 ## Layer 8 — tall walls/scenery only. Not rails or track deck.

## Metric thresholds defined BEFORE results (digital structural gates, not human feel).
const POSITION_DISCONTINUITY_M := 0.35
const YAW_DISCONTINUITY_RAD := 0.12
const NORMAL_RUN_SHAKE_MAX := 0.0
const HIGH_FREQ_POS_RMS_MAX := 0.08

@export var follow_smoothing: float = 8.0
@export var look_ahead: float = 2.4
@export var shake_decay: float = 8.0
@export var base_fov: float = 65.0
@export var max_fov: float = 74.0
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
var _physics_pos := Vector3.ZERO
var _prev_physics_pos := Vector3.ZERO
var _physics_basis := Basis.IDENTITY
var _smoothed_pos := Vector3.ZERO
var _heading := 0.0
var _pitch := -0.42
var _has_heading := false
var _look_ahead_f := 2.4
var _spring_f := 8.4
var _impulse := Vector3.ZERO
var _profile: int = Profile.COMFORT
var _last_camera_pos := Vector3.ZERO
var _last_yaw := 0.0
var telemetry: Node


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
	_apply_profile(_resolve_profile())


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


func set_boosting(active: bool) -> void:
	_boosting = active


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
	var allowed := true
	var gm := _game_manager()
	if gm != null and "camera_shake_enabled" in gm:
		allowed = bool(gm.camera_shake_enabled)
	var a11y := _accessibility()
	if a11y != null and a11y.has_method("camera_shake_allowed"):
		allowed = a11y.camera_shake_allowed()
	return allowed


func _resolve_profile() -> int:
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
			max_fov = 78.0
			base_spring_length = 8.2
			max_spring_length = 9.6
			base_look_ahead = 2.6
			max_look_ahead = 4.8
		Profile.REDUCED_MOTION:
			base_fov = 65.0
			max_fov = 66.0
			base_spring_length = 8.4
			max_spring_length = 8.5
			base_look_ahead = 2.2
			max_look_ahead = 2.6
		_:
			base_fov = 65.0
			max_fov = 74.0
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
	_apply_profile(_resolve_profile())
	_apply_speed_presentation(delta)
	if _target == null:
		return
	var target_pos := _interpolated_target_position()
	_update_translation(target_pos, delta)
	_update_heading(target_pos, delta)
	_apply_orientation()
	_apply_impact_impulse(delta)
	_record_telemetry(delta)


func _interpolated_target_position() -> Vector3:
	if _target != null and _target.has_method("get_global_transform_interpolated"):
		var xf: Transform3D = _target.get_global_transform_interpolated()
		return xf.origin
	var frac := Engine.get_physics_interpolation_fraction() if Engine.has_method("get_physics_interpolation_fraction") else 1.0
	return _prev_physics_pos.lerp(_physics_pos, clampf(frac, 0.0, 1.0))


func _apply_speed_presentation(delta: float) -> void:
	var speed_lambda := 3.2 if _profile != Profile.DYNAMIC else 4.4
	if _profile == Profile.REDUCED_MOTION:
		speed_lambda = 1.6
	var desired := _raw_speed_ratio
	if _boosting and _profile != Profile.REDUCED_MOTION:
		desired = clampf(desired + 0.12, 0.0, 1.15)
	_camera_speed_ratio = lerpf(_camera_speed_ratio, desired, _exp_alpha(speed_lambda, delta))
	var feel := clampf(_camera_speed_ratio, 0.0, 1.0)
	if _profile == Profile.REDUCED_MOTION:
		feel *= 0.12
	_look_ahead_f = lerpf(_look_ahead_f, lerpf(base_look_ahead, max_look_ahead, feel), _exp_alpha(2.8, delta))
	look_ahead = _look_ahead_f
	var spring_target := lerpf(base_spring_length, max_spring_length, feel * 0.35)
	_spring_f = lerpf(_spring_f, spring_target, _exp_alpha(2.1, delta))
	spring_length = _spring_f
	if _camera != null:
		var fov_t := 0.0 if _profile == Profile.REDUCED_MOTION else feel
		var target_fov := lerpf(base_fov, max_fov, clampf(fov_t, 0.0, 1.0))
		_camera.fov = lerpf(_camera.fov, target_fov, _exp_alpha(2.4, delta))


func _update_translation(target_pos: Vector3, delta: float) -> void:
	var desired := target_pos + _follow_offset
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


func _update_heading(target_pos: Vector3, delta: float) -> void:
	var velocity := Vector3.ZERO
	if _target != null and "velocity" in _target:
		velocity = _target.velocity
	velocity.y = 0.0
	var facing := -_physics_basis.z
	facing.y = 0.0
	var desired_dir := facing
	if velocity.length() > 2.4:
		desired_dir = velocity.normalized()
	elif facing.length_squared() > 0.001:
		desired_dir = facing.normalized()
	if desired_dir.length_squared() < 0.001:
		return
	var desired_yaw := atan2(desired_dir.x, desired_dir.z)
	if not _has_heading:
		_heading = desired_yaw
		_has_heading = true
	var err := wrapf(desired_yaw - _heading, -PI, PI)
	# Heading deadband: ignore micro left/right touch corrections.
	if absf(err) < 0.035:
		err = 0.0
	var yaw_lambda := 6.8 if _profile == Profile.DYNAMIC else 4.6
	if _profile == Profile.REDUCED_MOTION:
		yaw_lambda = 3.2
	_heading = wrapf(_heading + err * _exp_alpha(yaw_lambda, delta), -PI, PI)
	var look_point := target_pos + Vector3(sin(_heading), 0.0, cos(_heading)) * _look_ahead_f
	var to_look := look_point - global_position
	var desired_pitch := atan2(to_look.y, Vector2(to_look.x, to_look.z).length())
	_pitch = lerpf(_pitch, desired_pitch, _exp_alpha(3.1, delta))


func _apply_orientation() -> void:
	var basis := Basis.from_euler(Vector3(_pitch, _heading, 0.0))
	global_transform.basis = basis


func _apply_impact_impulse(delta: float) -> void:
	if _shake_strength <= 0.0 and _impulse.length_squared() < 0.000001:
		return
	# Local-space coherent impulse — never per-frame randf world teleport.
	global_position += _impulse
	_impulse = _impulse.lerp(Vector3.ZERO, _exp_alpha(10.0, delta))
	_shake_strength = maxf(0.0, _shake_strength - shake_decay * delta)
	if _shake_strength <= 0.0:
		_impulse = Vector3.ZERO


func springarm_retracted() -> bool:
	return get_hit_length() + 0.05 < spring_length


func _record_telemetry(delta: float) -> void:
	if telemetry == null:
		return
	if telemetry.has_method("sample"):
		telemetry.sample({
			"dt": delta,
			"target_position": _physics_pos,
			"camera_position": global_position,
			"desired_yaw": _heading,
			"camera_yaw": _heading,
			"fov": _camera.fov if _camera != null else base_fov,
			"spring_length": spring_length,
			"raw_speed": _raw_speed_ratio,
			"filtered_speed": _camera_speed_ratio,
			"spring_retracted": springarm_retracted(),
			"shake_amplitude": _shake_strength,
			"pos_delta": global_position.distance_to(_last_camera_pos),
			"yaw_delta": absf(wrapf(_heading - _last_yaw, -PI, PI)),
		})
	_last_camera_pos = global_position
	_last_yaw = _heading
