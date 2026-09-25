extends SceneTree

## Authored dynamism gates. Chronic shake stays illegal. Human fun stays false.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_test_speed_fov(failures)
	_test_turn_anticipation(failures)
	_test_boost_pulse(failures)
	_test_drift_framing(failures)
	_test_landing_impulse(failures)
	_test_reduced_motion(failures)
	_test_no_run_shake(failures)
	if failures.is_empty():
		print("CAMERA_DIRECTION_PASS=true")
		print("CAMERA_NORMAL_RUN_STABILITY_PASS=true")
		print("CAMERA_SPEED_RESPONSE_PASS=true")
		print("CAMERA_TURN_ANTICIPATION_PASS=true")
		print("CAMERA_BOOST_RESPONSE_PASS=true")
		print("CAMERA_DRIFT_RESPONSE_PASS=true")
		print("CAMERA_LANDING_IMPULSE_BOUNDED_PASS=true")
		print("CAMERA_REDUCED_MOTION_PASS=true")
		print("OWNER_CAMERA_EXCITEMENT_PASS=false")
		print("CameraDynamismTest PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_speed_fov(failures: PackedStringArray) -> void:
	var cam := _make_rig()
	cam._apply_profile(cam.Profile.COMFORT)
	var low := _fov_after_speed(cam, 4.0, 40)
	var high := _fov_after_speed(cam, 24.0, 80)
	if high <= low + 0.4:
		failures.append("comfort FOV did not rise with speed (%.2f -> %.2f)" % [low, high])
	if float(cam.base_fov) < 64.0 or float(cam.base_fov) > 66.0:
		failures.append("comfort base FOV out of authored range")
	if float(cam.max_fov) < 72.0 or float(cam.max_fov) > 75.0:
		failures.append("comfort max FOV out of authored range")
	cam._apply_profile(cam.Profile.DYNAMIC)
	if float(cam.base_fov) < 65.0 or float(cam.base_fov) > 67.0:
		failures.append("dynamic base FOV out of authored range")
	if float(cam.max_fov) < 77.0 or float(cam.max_fov) > 80.0:
		failures.append("dynamic max FOV out of authored range")
	cam.free()


func _test_turn_anticipation(failures: PackedStringArray) -> void:
	var cam := _make_rig()
	var target := _make_target(Vector3(0, 0, -1), Vector3(0, 0, -10))
	cam.set_target(target)
	_settle(cam, 40)
	var peak_lat := 0.0
	var peak_roll := 0.0
	for i in range(50):
		var yaw := float(i) * 0.035
		var facing := Vector3(-sin(yaw), 0.0, -cos(yaw))
		target.global_transform.basis = Basis.looking_at(facing, Vector3.UP)
		target.velocity = facing * 12.0
		cam._physics_process(1.0 / 60.0)
		cam._process(1.0 / 60.0)
		peak_lat = maxf(peak_lat, absf(float(cam._lateral)))
		peak_roll = maxf(peak_roll, absf(float(cam._roll)))
	if peak_lat < 0.04:
		failures.append("sustained turn produced no lateral framing")
	if peak_lat > 0.40:
		failures.append("comfort lateral bias exceeded bound (%.3f)" % peak_lat)
	if peak_roll > deg_to_rad(1.30):
		failures.append("comfort roll exceeded bound")
	if peak_roll < deg_to_rad(0.05):
		failures.append("comfort turn produced no authored roll")
	target.global_transform.basis = Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	target.velocity = Vector3(0, 0, -10)
	_settle(cam, 90)
	if absf(float(cam._lateral)) > 0.08:
		failures.append("lateral bias snapped or failed to settle (%.3f)" % float(cam._lateral))
	cam.free()
	target.free()


func _test_boost_pulse(failures: PackedStringArray) -> void:
	var cam := _make_rig()
	cam._apply_profile(cam.Profile.DYNAMIC)
	cam._raw_speed_ratio = 0.85
	cam._apply_speed_presentation(0.16)
	var before: float = float(cam._camera.fov)
	cam.set_boosting(true)
	cam._apply_speed_presentation(1.0 / 60.0)
	var pulsed: float = float(cam._camera.fov)
	if pulsed <= before:
		failures.append("boost did not pulse FOV")
	if float(cam._boost_pulse) <= 0.5:
		failures.append("boost pulse missing")
	# Holding boost must not keep adding shake.
	for _i in range(30):
		cam._apply_speed_presentation(1.0 / 60.0)
	if float(cam._shake_strength) > 0.0:
		failures.append("boost sustain applied shake")
	if float(cam._boost_pulse) >= 0.98:
		failures.append("boost pulse did not settle")
	cam.free()


func _test_drift_framing(failures: PackedStringArray) -> void:
	var cam := _make_rig()
	var target := CharacterBody3D.new()
	target.set_script(load("res://tests/_camera_drift_stub.gd"))
	get_root().add_child(target)
	target.global_position = Vector3(0, 1, 0)
	target.global_transform.basis = Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	target.velocity = Vector3(8, 0, -6)
	cam.set_target(target)
	_settle(cam, 70)
	var optical: Vector3 = cam.get_optical_forward()
	if optical.dot(Vector3(8, 0, -6).normalized()) < 0.55:
		failures.append("drift framing ignored travel/exit")
	if absf(float(cam._heading) - float(cam._prev_desired_yaw)) > 0.9:
		failures.append("drift camera fishtailed")
	cam.free()
	target.free()


func _test_landing_impulse(failures: PackedStringArray) -> void:
	var cam := _make_rig()
	var floor_body := Node3D.new()
	floor_body.set_script(load("res://tests/_camera_grounded_stub.gd"))
	get_root().add_child(floor_body)
	floor_body.global_position = Vector3(0, 1, 0)
	floor_body.velocity = Vector3(0, 0, -8)
	cam.set_target(floor_body)
	cam._was_airborne = true
	cam._airborne_vy = -2.0
	cam._update_landing_impulse()
	if float(cam._shake_strength) > 0.0:
		failures.append("sub-threshold landing applied impulse")
	cam._was_airborne = true
	cam._airborne_vy = -11.0
	cam._update_landing_impulse()
	if float(cam._shake_strength) <= 0.0:
		failures.append("above-threshold landing produced no impulse")
	cam.free()
	floor_body.free()


func _test_reduced_motion(failures: PackedStringArray) -> void:
	var cam := _make_rig()
	cam._apply_profile(cam.Profile.REDUCED_MOTION)
	cam._raw_speed_ratio = 1.2
	cam.set_boosting(true)
	cam._apply_speed_presentation(0.2)
	if float(cam._camera.fov) > float(cam.base_fov) + 1.5:
		failures.append("reduced motion FOV still swings")
	if absf(float(cam._roll)) > 0.0001 and absf(cam._max_roll()) > 0.0:
		failures.append("reduced motion allowed roll")
	if absf(cam._max_roll()) > 0.0001:
		failures.append("reduced motion roll bound must be 0")
	cam.add_shake(1.0)
	if float(cam._shake_strength) > 0.0:
		failures.append("reduced motion allowed landing/impact impulse")
	cam.free()


func _test_no_run_shake(failures: PackedStringArray) -> void:
	var cam := _make_rig()
	var target := _make_target(Vector3(0, 0, -1), Vector3(0, 0, -16))
	cam.set_target(target)
	cam._on_speed_changed(20.0)
	for _i in range(60):
		target.global_position += Vector3(0, 0, -0.28)
		cam._physics_process(1.0 / 60.0)
		cam._process(1.0 / 60.0)
	if float(cam._shake_strength) > 0.0:
		failures.append("normal sprint applied shake")
	cam.free()
	target.free()


func _fov_after_speed(cam: SpringArm3D, speed: float, frames: int) -> float:
	cam._on_speed_changed(speed)
	for _i in range(frames):
		cam._apply_speed_presentation(1.0 / 60.0)
	return float(cam._camera.fov)


func _settle(cam: SpringArm3D, frames: int) -> void:
	for _i in range(frames):
		cam._physics_process(1.0 / 60.0)
		cam._process(1.0 / 60.0)


func _make_target(facing: Vector3, velocity: Vector3) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	get_root().add_child(target)
	target.global_position = Vector3(0, 1, 0)
	target.global_transform.basis = Basis.looking_at(Vector3(facing.x, 0, facing.z).normalized(), Vector3.UP)
	target.velocity = velocity
	return target


func _make_rig() -> SpringArm3D:
	var cam := SpringArm3D.new()
	cam.set_script(load("res://scripts/player/CameraRig.gd"))
	var cam3d := Camera3D.new()
	cam3d.name = "Camera3D"
	cam3d.fov = 65.0
	cam.add_child(cam3d)
	get_root().add_child(cam)
	cam._camera = cam3d
	cam.position = Vector3(0, 4, 0)
	cam._ready()
	cam.set_profile(cam.Profile.COMFORT)
	return cam
