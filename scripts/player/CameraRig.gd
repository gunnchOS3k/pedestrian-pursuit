extends SpringArm3D

## Third-person follow camera with optional shake and sense-of-speed response.

@export var follow_smoothing: float = 8.0
@export var look_ahead: float = 2.0
@export var shake_decay: float = 6.0
@export var base_fov: float = 68.0
@export var max_fov: float = 88.0
@export var base_spring_length: float = 7.6
@export var max_spring_length: float = 12.2
@export var base_look_ahead: float = 2.2
@export var max_look_ahead: float = 6.2
@export var speed_ref: float = 22.0

var _target: Node3D
var _shake_strength: float = 0.0
var _follow_offset: Vector3
var _camera: Camera3D
var _speed_ratio: float = 0.0
var _boosting: bool = false


func _ready() -> void:
	spring_length = base_spring_length
	_follow_offset = position
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera != null:
		_camera.fov = base_fov


func set_target(target: Node3D) -> void:
	_target = target
	global_position = _target.global_position + _follow_offset
	if _target != null and _target.has_signal("speed_changed"):
		if not _target.speed_changed.is_connected(_on_speed_changed):
			_target.speed_changed.connect(_on_speed_changed)


func set_boosting(active: bool) -> void:
	_boosting = active


func apply_course_identity(identity: String) -> void:
	## Per-course chase personality without changing collision or lap rules.
	match str(identity):
		"cascade_chase":
			base_fov = 70.0
			max_fov = 90.0
			base_spring_length = 7.4
			max_spring_length = 11.8
			base_look_ahead = 2.3
			max_look_ahead = 6.2
		"ranch_chase":
			base_fov = 72.0
			max_fov = 91.0
			base_spring_length = 7.8
			max_spring_length = 12.4
			base_look_ahead = 2.5
			max_look_ahead = 6.8
		"prism_chase":
			base_fov = 69.0
			max_fov = 93.0
			base_spring_length = 7.0
			max_spring_length = 11.2
			base_look_ahead = 2.2
			max_look_ahead = 6.0
		"ember_chase":
			base_fov = 68.0
			max_fov = 92.0
			base_spring_length = 7.2
			max_spring_length = 11.6
			base_look_ahead = 2.1
			max_look_ahead = 5.9
		"harbor_chase":
			base_fov = 71.0
			max_fov = 90.0
			base_spring_length = 7.9
			max_spring_length = 12.6
			base_look_ahead = 2.55
			max_look_ahead = 6.9
		"neon_yard_chase":
			base_fov = 67.0
			max_fov = 93.0
			base_spring_length = 6.9
			max_spring_length = 11.1
			base_look_ahead = 2.0
			max_look_ahead = 5.7
		"ridge_chase":
			base_fov = 73.0
			max_fov = 95.0
			base_spring_length = 8.2
			max_spring_length = 13.0
			base_look_ahead = 2.7
			max_look_ahead = 7.2
		"mesa_chase":
			base_fov = 72.0
			max_fov = 92.0
			base_spring_length = 8.0
			max_spring_length = 12.7
			base_look_ahead = 2.6
			max_look_ahead = 7.0
		"metro_chase", "sneaker_city_chase":
			base_fov = 70.0
			max_fov = 92.0
			base_spring_length = 7.2
			max_spring_length = 11.4
			base_look_ahead = 2.4
			max_look_ahead = 6.6
		"metro_pulse_chase":
			base_fov = 69.0
			max_fov = 93.0
			base_spring_length = 7.0
			max_spring_length = 11.2
			base_look_ahead = 2.35
			max_look_ahead = 6.4
		"crosswalk_chase":
			base_fov = 71.0
			max_fov = 91.0
			base_spring_length = 7.4
			max_spring_length = 11.8
			base_look_ahead = 2.5
			max_look_ahead = 6.8
		"transit_chase":
			base_fov = 68.0
			max_fov = 94.0
			base_spring_length = 6.9
			max_spring_length = 11.0
			base_look_ahead = 2.2
			max_look_ahead = 6.2
		"coast_chase", "saltline_chase":
			base_fov = 72.0
			max_fov = 90.0
			base_spring_length = 8.0
			max_spring_length = 12.8
			base_look_ahead = 2.6
			max_look_ahead = 7.0
		"cliffside_chase":
			base_fov = 74.0
			max_fov = 94.0
			base_spring_length = 8.3
			max_spring_length = 13.1
			base_look_ahead = 2.75
			max_look_ahead = 7.3
		"tidal_chase":
			base_fov = 71.0
			max_fov = 91.0
			base_spring_length = 7.9
			max_spring_length = 12.5
			base_look_ahead = 2.55
			max_look_ahead = 6.9
		"seaglass_chase":
			base_fov = 73.0
			max_fov = 92.0
			base_spring_length = 8.1
			max_spring_length = 12.9
			base_look_ahead = 2.65
			max_look_ahead = 7.1
		"neon_chase", "lantern_chase":
			base_fov = 68.0
			max_fov = 94.0
			base_spring_length = 6.8
			max_spring_length = 11.0
			base_look_ahead = 2.0
			max_look_ahead = 5.8
		"mirror_chase":
			base_fov = 67.0
			max_fov = 95.0
			base_spring_length = 6.6
			max_spring_length = 10.8
			base_look_ahead = 1.95
			max_look_ahead = 5.6
		"afterglow_chase":
			base_fov = 69.0
			max_fov = 93.0
			base_spring_length = 7.0
			max_spring_length = 11.3
			base_look_ahead = 2.15
			max_look_ahead = 6.0
		"signal_storm_chase":
			base_fov = 66.0
			max_fov = 96.0
			base_spring_length = 6.5
			max_spring_length = 10.6
			base_look_ahead = 1.9
			max_look_ahead = 5.5
		"skyline_chase", "rooftop_chase":
			base_fov = 74.0
			max_fov = 96.0
			base_spring_length = 8.4
			max_spring_length = 13.2
			base_look_ahead = 2.8
			max_look_ahead = 7.4
		"skybridge_chase":
			base_fov = 75.0
			max_fov = 97.0
			base_spring_length = 8.6
			max_spring_length = 13.5
			base_look_ahead = 2.9
			max_look_ahead = 7.6
		"antenna_chase":
			base_fov = 73.0
			max_fov = 95.0
			base_spring_length = 8.2
			max_spring_length = 13.0
			base_look_ahead = 2.7
			max_look_ahead = 7.2
		"cloud_deck_chase":
			base_fov = 76.0
			max_fov = 98.0
			base_spring_length = 8.8
			max_spring_length = 13.8
			base_look_ahead = 3.0
			max_look_ahead = 7.8
		"archive_chase", "foyer_chase":
			base_fov = 66.0
			max_fov = 86.0
			base_spring_length = 7.4
			max_spring_length = 11.6
			base_look_ahead = 2.1
			max_look_ahead = 5.6
		"stack_chase":
			base_fov = 65.0
			max_fov = 85.0
			base_spring_length = 7.1
			max_spring_length = 11.2
			base_look_ahead = 2.0
			max_look_ahead = 5.4
		"gallery_chase":
			base_fov = 67.0
			max_fov = 88.0
			base_spring_length = 7.6
			max_spring_length = 12.0
			base_look_ahead = 2.25
			max_look_ahead = 5.9
		"vault_chase":
			base_fov = 64.0
			max_fov = 84.0
			base_spring_length = 6.9
			max_spring_length = 10.9
			base_look_ahead = 1.95
			max_look_ahead = 5.3
		"wonder_chase", "colossus_chase":
			base_fov = 73.0
			max_fov = 95.0
			base_spring_length = 8.2
			max_spring_length = 13.0
			base_look_ahead = 2.7
			max_look_ahead = 7.2
		"aurora_chase":
			base_fov = 72.0
			max_fov = 94.0
			base_spring_length = 8.0
			max_spring_length = 12.7
			base_look_ahead = 2.6
			max_look_ahead = 7.0
		"origami_chase":
			base_fov = 71.0
			max_fov = 93.0
			base_spring_length = 7.8
			max_spring_length = 12.4
			base_look_ahead = 2.5
			max_look_ahead = 6.8
		"crown_chase":
			base_fov = 75.0
			max_fov = 97.0
			base_spring_length = 8.5
			max_spring_length = 13.4
			base_look_ahead = 2.85
			max_look_ahead = 7.5
		_:
			pass
	spring_length = base_spring_length
	look_ahead = base_look_ahead
	if _camera != null:
		_camera.fov = base_fov


func add_shake(strength: float) -> void:
	var allowed := GameManager.camera_shake_enabled
	var a11y := _accessibility()
	if a11y != null and a11y.has_method("camera_shake_allowed"):
		allowed = a11y.camera_shake_allowed()
	if allowed:
		_shake_strength = maxf(_shake_strength, strength)


func _accessibility() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("AccessibilitySettings")


func _on_speed_changed(speed: float) -> void:
	_speed_ratio = clampf(speed / maxf(speed_ref, 0.01), 0.0, 1.35)


func _physics_process(delta: float) -> void:
	var feel := clampf(_speed_ratio, 0.0, 1.0)
	if _boosting:
		## Stronger boost punch for racing-feel (does not retune per-track chase identities).
		## Reduce-motion path below still freezes FOV punch.
		feel = clampf(feel + 0.32, 0.0, 1.25)
	# Reduce-motion: keep FOV static, still allow mild look-ahead.
	var a11y := _accessibility()
	var reduce_motion := false
	if a11y != null and a11y.has_method("camera_shake_allowed"):
		reduce_motion = not a11y.camera_shake_allowed()
	var fov_t := 0.0 if reduce_motion else feel
	# Reduce-motion keeps chase readable without speed FOV/spring punch.
	var motion_feel := 0.15 if reduce_motion else feel
	look_ahead = lerpf(base_look_ahead, max_look_ahead, motion_feel)
	## Slight pull-back under boost so FOV punch reads as speed, not zoom-in.
	var spring_feel := motion_feel * (0.92 if (_boosting and not reduce_motion) else 0.85)
	spring_length = lerpf(base_spring_length, max_spring_length, spring_feel)
	if _camera != null:
		var target_fov := lerpf(base_fov, max_fov, clampf(fov_t, 0.0, 1.0))
		_camera.fov = lerpf(_camera.fov, target_fov, clampf(7.5 * delta, 0.0, 1.0))

	if _target == null:
		return
	var desired_position := _target.global_position + _follow_offset
	global_position = global_position.lerp(
		desired_position, clampf(follow_smoothing * delta, 0.0, 1.0)
	)
	if _shake_strength > 0.0:
		global_position += (
			Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
			* _shake_strength
			* 0.15
		)
		_shake_strength = maxf(0.0, _shake_strength - shake_decay * delta)

	look_at(_target.global_position + _target.global_transform.basis.z * -look_ahead, Vector3.UP)
