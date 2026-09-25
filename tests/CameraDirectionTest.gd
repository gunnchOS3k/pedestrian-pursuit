extends SceneTree
const _Dir = preload("res://scripts/player/CameraDirection.gd")

## Hard camera-direction gates. Digital only — human fun stays false.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var cardinal := _test_cardinals(failures)
	var diagonal := _test_diagonals(failures)
	var behind := _test_behind_racer(failures)
	var transitions := _test_velocity_facing(failures)
	var start_ok := _test_start_of_race(failures)
	if cardinal != 4:
		failures.append("cardinal headings %d/4" % cardinal)
	if diagonal != 4:
		failures.append("diagonal headings %d/4" % diagonal)
	if failures.is_empty():
		print("CAMERA_FORWARD_CONVENTION_PASS=true")
		print("CAMERA_CARDINAL_DIRECTION_PASS=%d/4" % cardinal)
		print("CAMERA_DIAGONAL_DIRECTION_PASS=%d/4" % diagonal)
		print("CAMERA_BEHIND_RACER_PASS=%s" % ("true" if behind else "false"))
		print("CAMERA_START_DIRECTION_PASS=%s" % ("true" if start_ok else "false"))
		print("CAMERA_VELOCITY_FACING_TRANSITION_PASS=%s" % ("true" if transitions else "false"))
		print("OWNER_CAMERA_DIRECTION_PASS=false")
		print("CameraDirectionTest PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_cardinals(failures: PackedStringArray) -> int:
	var dirs := [
		Vector3(0, 0, -1),
		Vector3(0, 0, 1),
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
	]
	var passed := 0
	for dir in dirs:
		var dot := _settle_optical_dot(dir, dir * 10.0)
		if dot >= 0.95:
			passed += 1
		else:
			failures.append("cardinal %s optical_dot=%.3f" % [dir, dot])
	return passed


func _test_diagonals(failures: PackedStringArray) -> int:
	var dirs := [
		Vector3(1, 0, -1).normalized(),
		Vector3(-1, 0, -1).normalized(),
		Vector3(1, 0, 1).normalized(),
		Vector3(-1, 0, 1).normalized(),
	]
	var passed := 0
	for dir in dirs:
		var dot := _settle_optical_dot(dir, dir * 10.0)
		if dot >= 0.95:
			passed += 1
		else:
			failures.append("diagonal %s optical_dot=%.3f" % [dir, dot])
	return passed


func _test_behind_racer(failures: PackedStringArray) -> bool:
	var cam := _make_rig()
	var target := _make_target(Vector3(0, 0, -1), Vector3(0, 0, -10))
	cam.set_target(target)
	_settle(cam, 90)
	var cam3d: Camera3D = cam.get_camera3d()
	if cam3d == null:
		failures.append("Camera3D missing for behind-racer contract")
		cam.free()
		target.free()
		return false
	var forward := _Dir.racer_forward(target.global_transform.basis)
	var ok := _Dir.is_behind_racer(target.global_position, cam3d.global_position, forward)
	if not ok:
		failures.append("camera not behind racer (used Camera3D.global_position)")
	cam.free()
	target.free()
	return ok


func _test_velocity_facing(failures: PackedStringArray) -> bool:
	var ok := true
	# Standing / low speed uses facing, not a tiny reverse velocity.
	var stand_dot := _settle_optical_dot(Vector3(0, 0, -1), Vector3(0, 0, 0.4))
	if stand_dot < 0.95:
		failures.append("low-speed facing lost travel heading (dot=%.3f)" % stand_dot)
		ok = false
	# Acceleration transitions to velocity (facing -Z, velocity +X should ease toward +X).
	var cam := _make_rig()
	var target := _make_target(Vector3(0, 0, -1), Vector3.ZERO)
	cam.set_target(target)
	_settle(cam, 40)
	target.velocity = Vector3(10, 0, 0)
	_settle(cam, 90)
	var accel_dot: float = cam.get_optical_forward().dot(Vector3(1, 0, 0))
	if accel_dot < 0.85:
		failures.append("acceleration did not transition toward velocity (dot=%.3f)" % accel_dot)
		ok = false
	cam.free()
	target.free()
	# Braking / reverse collision velocity must not instantly flip 180°.
	cam = _make_rig()
	target = _make_target(Vector3(0, 0, -1), Vector3(0, 0, -10))
	cam.set_target(target)
	_settle(cam, 50)
	var before: Vector3 = cam.get_optical_forward()
	target.velocity = Vector3(0, 0, 14)
	cam._physics_process(1.0 / 60.0)
	cam._process(1.0 / 60.0)
	var after: Vector3 = cam.get_optical_forward()
	if before.dot(after) < 0.70:
		failures.append("reverse velocity instantly flipped chase heading")
		ok = false
	_settle(cam, 40)
	if cam.get_optical_forward().dot(Vector3(0, 0, -1)) < 0.85:
		failures.append("reverse/transient velocity left camera staring backward")
		ok = false
	cam.free()
	target.free()
	return ok


func _test_start_of_race(failures: PackedStringArray) -> bool:
	var cam := _make_rig()
	var target := _make_target(Vector3(0, 0, -1), Vector3.ZERO)
	cam.set_target(target)
	cam._physics_process(1.0 / 60.0)
	cam._process(1.0 / 60.0)
	var first: Vector3 = cam.get_optical_forward()
	if first.dot(Vector3(0, 0, -1)) < 0.95:
		failures.append("countdown start heading not course-forward (dot=%.3f)" % first.dot(Vector3(0, 0, -1)))
		cam.free()
		target.free()
		return false
	var cam3d: Camera3D = cam.get_camera3d()
	if cam3d == null or not _Dir.is_behind_racer(target.global_position, cam3d.global_position, Vector3(0, 0, -1)):
		failures.append("countdown camera not behind runner")
		cam.free()
		target.free()
		return false
	var yaw0: float = float(cam._heading)
	target.velocity = Vector3(0, 0, -8)
	cam._physics_process(1.0 / 60.0)
	cam._process(1.0 / 60.0)
	if absf(wrapf(float(cam._heading) - yaw0, -PI, PI)) > 0.35:
		failures.append("GO caused a first-frame 180 snap")
		cam.free()
		target.free()
		return false
	cam.free()
	target.free()
	return true


func _settle_optical_dot(facing: Vector3, velocity: Vector3) -> float:
	var cam := _make_rig()
	var target := _make_target(facing, velocity)
	cam.set_target(target)
	_settle(cam, 90)
	var expected: Vector3 = _Dir.flatten(facing if velocity.length() <= 2.4 else velocity)
	var dot: float = cam.get_optical_forward().dot(expected)
	cam.free()
	target.free()
	return dot


func _settle(cam: SpringArm3D, frames: int) -> void:
	for _i in range(frames):
		cam._physics_process(1.0 / 60.0)
		cam._process(1.0 / 60.0)


func _make_target(facing: Vector3, velocity: Vector3) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	get_root().add_child(target)
	target.global_position = Vector3(0, 1, 0)
	target.global_transform.basis = Basis.looking_at(_Dir.flatten(facing), Vector3.UP)
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
	return cam
