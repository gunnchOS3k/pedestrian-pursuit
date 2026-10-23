extends SceneTree

## Proves the racing-line estimate uses one physics tick and reacquires only
## after a grounded landing. Does not start a race and does not move a body.
## The numbers are the Verdant crossing measured on CI run 39966865889.

const FollowerScript = preload("res://scripts/ai/AIPathFollower.gd")
const PATH_LENGTH := 270.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_test_physics_step_not_wall_clock(failures)
	_test_slow_body_has_no_speed_floor(failures)
	_test_airborne_gap_does_not_reacquire(failures)
	_test_grounded_gap_reacquires_estimate_only(failures)
	_test_racing_speed_keeps_the_forward_estimate(failures)
	_test_small_grounded_gap_integrates(failures)
	_test_rising_body_does_not_reacquire(failures)
	if failures.is_empty():
		print("COURSE_PROGRESS_REACQUIRE=pass")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
		print("COURSE_PROGRESS_FAIL %s" % failure)
	quit(1)


func _follower(failures: PackedStringArray):
	var follower = FollowerScript.new()
	if follower == null or not follower.has_method("advance_course_estimate"):
		failures.append("AIPathFollower did not compile")
		return null
	follower._path_length = PATH_LENGTH
	follower._progress = 0.0
	follower.reacquire_count = 0
	return follower


func _test_physics_step_not_wall_clock(failures: PackedStringArray) -> void:
	var follower = _follower(failures)
	if follower == null:
		return
	var step := float(follower.physics_step_seconds())
	var tick := 1.0 / float(maxi(Engine.get_physics_ticks_per_second(), 1))
	if not is_equal_approx(step, tick * maxf(Engine.time_scale, 0.0)):
		failures.append("physics step %.6f is not one engine tick" % step)
	follower._progress = 10.0
	var result: Dictionary = follower.advance_course_estimate(20.0, true, 0.0, 10.2)
	var expected := fposmod(10.0 + 20.0 * step, PATH_LENGTH)
	if bool(result["reacquired"]):
		failures.append("a 0.2 m gap reacquired")
	if not is_equal_approx(float(result["progress"]), expected):
		failures.append(
			"progress %.4f followed something other than speed * physics tick %.4f" % [
				float(result["progress"]), expected
			]
		)
	# A 50 ms wall gap would have moved 1.0 m at 20 m/s. The estimate must not.
	if float(result["progress"]) > 10.0 + 20.0 * step + 0.001:
		failures.append("progress advanced by more than one physics tick")


func _test_slow_body_has_no_speed_floor(failures: PackedStringArray) -> void:
	var follower = _follower(failures)
	if follower == null:
		return
	follower._progress = 50.0
	var step := float(follower.physics_step_seconds())
	follower.advance_course_estimate(2.0, true, 0.0, 50.1)
	var with_floor := fposmod(50.0 + 2.5 * step, PATH_LENGTH)
	var with_speed := fposmod(50.0 + 2.0 * step, PATH_LENGTH)
	if is_equal_approx(float(follower._progress), with_floor) and not is_equal_approx(with_floor, with_speed):
		failures.append("a 2 m/s body used the 2.5 m/s floor")
	if not is_equal_approx(float(follower._progress), with_speed):
		failures.append("slow progress %.4f != %.4f" % [float(follower._progress), with_speed])


func _test_airborne_gap_does_not_reacquire(failures: PackedStringArray) -> void:
	# CI sample t=11006: airborne, closest fell behind the estimate, vy negative.
	var follower = _follower(failures)
	if follower == null:
		return
	follower._progress = 215.0
	var step := float(follower.physics_step_seconds())
	var result: Dictionary = follower.advance_course_estimate(20.6, false, -5.75, 172.0)
	if bool(result["reacquired"]) or int(follower.reacquire_count) != 0:
		failures.append("airborne Verdant crossing reacquired onto closest offset")
	var expected := fposmod(215.0 + 20.6 * step, PATH_LENGTH)
	if not is_equal_approx(float(follower._progress), expected):
		failures.append("airborne progress %.4f != integrated %.4f" % [float(follower._progress), expected])
	if is_equal_approx(float(follower._progress), 172.0):
		failures.append("airborne progress snapped to closest offset 172")


func _test_grounded_gap_reacquires_estimate_only(failures: PackedStringArray) -> void:
	# CI sample t=12006: back on the ground, estimate 228, closest 173, vy 0.
	var follower = _follower(failures)
	if follower == null:
		return
	follower._progress = 228.0
	var result: Dictionary = follower.advance_course_estimate(2.0, true, 0.0, 173.0)
	if not bool(result["reacquired"]):
		failures.append("grounded gap of 55 m did not reacquire")
	if not is_equal_approx(float(follower._progress), 173.0):
		failures.append("reacquire left progress at %.2f" % float(follower._progress))
	if int(follower.reacquire_count) != 1:
		failures.append("reacquire_count %d" % int(follower.reacquire_count))


func _test_racing_speed_keeps_the_forward_estimate(failures: PackedStringArray) -> void:
	# Run 39972796105 snapped this gap at racing speed and never reached checkpoint 4.
	var follower = _follower(failures)
	if follower == null:
		return
	follower._progress = 228.0
	var step := float(follower.physics_step_seconds())
	var result: Dictionary = follower.advance_course_estimate(22.0, true, 0.0, 173.0)
	if bool(result["reacquired"]) or int(follower.reacquire_count) != 0:
		failures.append("a 22 m/s body reacquired and gave up the forward line")
	var expected := fposmod(228.0 + 22.0 * step, PATH_LENGTH)
	if not is_equal_approx(float(follower._progress), expected):
		failures.append("racing progress %.4f != integrated %.4f" % [float(follower._progress), expected])


func _test_small_grounded_gap_integrates(failures: PackedStringArray) -> void:
	var follower = _follower(failures)
	if follower == null:
		return
	follower._progress = 100.0
	var result: Dictionary = follower.advance_course_estimate(22.0, true, 0.0, 99.0)
	if bool(result["reacquired"]):
		failures.append("a 1 m grounded gap reacquired")


func _test_rising_body_does_not_reacquire(failures: PackedStringArray) -> void:
	var follower = _follower(failures)
	if follower == null:
		return
	follower._progress = 228.0
	var step := float(follower.physics_step_seconds())
	var result: Dictionary = follower.advance_course_estimate(10.0, true, 2.0, 173.0)
	if bool(result["reacquired"]) or int(follower.reacquire_count) != 0:
		failures.append("a rising body reacquired during the crossing")
	var expected := fposmod(228.0 + 10.0 * step, PATH_LENGTH)
	if not is_equal_approx(float(follower._progress), expected):
		failures.append("rising progress %.4f != integrated %.4f" % [float(follower._progress), expected])
