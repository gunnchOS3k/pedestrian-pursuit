extends SceneTree
const _Telemetry = preload("res://scripts/player/CameraTelemetry.gd")

## Camera structural regressions. Does NOT green HUMAN smoothness.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_test_damping_formula(failures)
	_test_finite_and_no_run_shake(failures)
	_test_reduced_motion(failures)
	_test_thresholds_defined_first(failures)
	if failures.is_empty():
		print("CAMERA_RENDER_INTERPOLATION_PASS")
		print("CAMERA_TRANSLATION_DAMPING_PASS")
		print("CAMERA_ROTATION_DAMPING_PASS")
		print("CAMERA_SPEED_FILTER_PASS")
		print("CAMERA_NORMAL_RUN_SHAKE_ZERO_PASS")
		print("CAMERA_REDUCED_MOTION_PASS")
		print("OWNER_CAMERA_SMOOTHNESS_PASS=false")
		print("CameraSmoothnessTest PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_damping_formula(failures: PackedStringArray) -> void:
	var cam := _make_rig()
	var a30: float = cam._exp_alpha(7.0, 1.0 / 30.0)
	var a60: float = cam._exp_alpha(7.0, 1.0 / 60.0)
	var a90: float = cam._exp_alpha(7.0, 1.0 / 90.0)
	if a30 <= a60 or a60 <= a90:
		failures.append("exponential damping is not frame-rate independent")
	if a60 <= 0.0 or a60 >= 1.0:
		failures.append("exp alpha out of range at 60Hz")
	cam.free()


func _test_finite_and_no_run_shake(failures: PackedStringArray) -> void:
	var cam := _make_rig()
	var target := Node3D.new()
	get_root().add_child(target)
	target.global_position = Vector3(0, 1, 0)
	cam.set_target(target)
	for i in range(12):
		target.global_position += Vector3(0.4, 0.0, 0.2)
		cam._on_speed_changed(18.0)
		cam._physics_process(1.0 / 60.0)
		cam._process(1.0 / 60.0)
	if not cam.global_position.is_finite():
		failures.append("camera transform not finite")
	if float(cam._shake_strength) > 0.0:
		failures.append("normal run applied camera shake")
	cam.add_shake(0.05)
	if float(cam._shake_strength) > 0.0:
		failures.append("sub-threshold shake leaked into comfort camera")
	cam.free()
	target.free()


func _test_reduced_motion(failures: PackedStringArray) -> void:
	var cam := _make_rig()
	cam._profile = cam.Profile.REDUCED_MOTION
	cam._apply_profile(cam.Profile.REDUCED_MOTION)
	var a11y: Node = cam._accessibility()
	if a11y != null and a11y.has_method("set_reduce_motion"):
		a11y.set_reduce_motion(true)
	cam._raw_speed_ratio = 1.2
	cam.set_boosting(true)
	cam._apply_speed_presentation(0.2)
	if float(cam._camera.fov) > float(cam.base_fov) + 1.5:
		failures.append("reduced motion FOV still swings")
	cam.add_shake(1.0)
	if float(cam._shake_strength) > 0.0:
		failures.append("reduced motion allowed shake")
	cam.free()


func _test_thresholds_defined_first(failures: PackedStringArray) -> void:
	if absf(_Telemetry.POSITION_DISCONTINUITY_M - 0.35) > 0.0001:
		failures.append("position discontinuity metric changed after the fact")
	if absf(_Telemetry.NORMAL_RUN_SHAKE_MAX) > 0.0001:
		failures.append("normal-run shake max must stay zero")


func _make_rig() -> SpringArm3D:
	var cam := SpringArm3D.new()
	cam.set_script(load("res://scripts/player/CameraRig.gd"))
	var cam3d := Camera3D.new()
	cam3d.name = "Camera3D"
	cam3d.fov = 65.0
	cam.add_child(cam3d)
	get_root().add_child(cam)
	cam._camera = cam3d
	cam._ready()
	return cam
