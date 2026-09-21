extends SceneTree

## VXP-3.3 human-feedback blockers: grounded settle + neutral steer.
## Deterministic headless regressions — no Pixel required for PASS/FAIL here.

const AIPathFollowerScript = preload("res://scripts/ai/AIPathFollower.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Vxp33PhysicsInputRegression BEGIN")
	_test_neutral_steer_zero()
	_test_touch_release_clears()
	_test_assist_only_while_accelerating()
	await _test_path_follower_no_y_teleport()
	await _test_spawn_fall_and_stable_ground()

	if _failures.is_empty():
		print("Vxp33PhysicsInputRegression PASS")
		print("VXP33_PHYSICS_INPUT_REGRESSION_PASS")
		quit(0)
	else:
		for f in _failures:
			push_error(f)
		print("Vxp33PhysicsInputRegression FAIL count=%d" % _failures.size())
		quit(1)


func _fail(msg: String) -> void:
	_failures.append(msg)
	push_error("VXP33 FAIL: " + msg)


func _gm() -> Node:
	var gm := root.get_node_or_null("GameManager")
	if gm == null:
		_fail("GameManager autoload missing")
	return gm


func _im() -> Node:
	var im := root.get_node_or_null("InputManager")
	if im == null or not im.has_method("get_steer"):
		_fail("InputManager autoload missing get_steer")
	return im


func _make_player() -> CharacterBody3D:
	var player: CharacterBody3D = load("res://scenes/player/PlayerRacer.tscn").instantiate()
	if player == null or not player.has_method("_do_jump"):
		_fail("PlayerRacer failed to instantiate with PlayerController")
		return CharacterBody3D.new()
	player.set("is_player", true)
	root.add_child(player)
	return player


func _test_neutral_steer_zero() -> void:
	var gm := _gm()
	var im := _im()
	if gm == null or im == null:
		return
	gm.set("auto_accelerate", false)
	gm.set("accept_test_mode", false)
	gm.set("mobile_assist_steer", 0.85)
	if im.has_method("clear_touch_state"):
		im.clear_touch_state()
	var steer: float = float(im.get_steer())
	if absf(steer) > 0.05:
		_fail("neutral steer not zero with assist present (got %.3f)" % steer)
	else:
		print("OK neutral_steer_zero got=%.4f" % steer)
	gm.set("mobile_assist_steer", 0.0)


func _test_touch_release_clears() -> void:
	var im := _im()
	if im == null:
		return
	im.set_touch_steer(1.0)
	im.set_touch_accelerate(true)
	Input.action_press("move_right")
	if im.has_method("clear_touch_state"):
		im.clear_touch_state()
	var steer: float = float(im.get_steer())
	var accel := bool(im.is_accelerating())
	if absf(steer) > 0.05 or accel:
		_fail("clear_touch_state left sticky input steer=%.3f accel=%s" % [steer, str(accel)])
	else:
		print("OK touch_release_clears")
	if Input.is_action_pressed("move_right"):
		Input.action_release("move_right")


func _test_assist_only_while_accelerating() -> void:
	var gm := _gm()
	var im := _im()
	if gm == null or im == null:
		return
	gm.set("auto_accelerate", false)
	gm.set("mobile_assist_steer", 1.0)
	if im.has_method("clear_touch_state"):
		im.clear_touch_state()
	var idle: float = float(im.get_steer())
	im.set_touch_accelerate(true)
	var running: float = float(im.get_steer())
	im.set_touch_accelerate(false)
	gm.set("mobile_assist_steer", 0.0)
	if absf(idle) > 0.05:
		_fail("assist applied while idle (%.3f)" % idle)
	if absf(running) < 0.5:
		_fail("assist missing while RUN held (%.3f)" % running)
	else:
		print("OK assist_only_while_accelerating idle=%.3f run=%.3f" % [idle, running])


func _test_path_follower_no_y_teleport() -> void:
	var path := Path3D.new()
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3(0, 0, 0))
	path.curve.add_point(Vector3(0, 0, -40))
	root.add_child(path)

	var body := CharacterBody3D.new()
	root.add_child(body)
	body.global_position = Vector3(0, 0.05, 0)

	var follower: Node = AIPathFollowerScript.new()
	body.add_child(follower)
	follower.setup(path)

	var y_before := body.global_position.y
	follower.get_steer_and_accel(body, 0.016)
	var y_after := body.global_position.y
	if absf(y_after - y_before) > 0.001:
		_fail("path follower rewrote Y (%.3f -> %.3f) — vertical cycle source" % [y_before, y_after])
	else:
		print("OK path_follower_no_y_teleport")

	body.queue_free()
	path.queue_free()
	await process_frame


func _test_spawn_fall_and_stable_ground() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	floor_shape.shape = box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	var path := Path3D.new()
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3(0, 0, 0))
	path.curve.add_point(Vector3(0, 0, -60))
	root.add_child(path)

	var player := _make_player()
	if not player.has_method("enable_movement"):
		floor_body.queue_free()
		path.queue_free()
		return

	player.global_position = Vector3(0, 2.4, 0)
	player.velocity = Vector3.ZERO
	player.set("movement_enabled", false)

	var follower: Node = AIPathFollowerScript.new()
	player.add_child(follower)
	follower.setup(path)

	var gm := _gm()
	var im := _im()
	if gm != null:
		gm.set("auto_accelerate", false)
		gm.set("mobile_assist_steer", 0.0)
		gm.set("accept_test_mode", false)
	if im != null and im.has_method("clear_touch_state"):
		im.clear_touch_state()

	for i in 20:
		follower.get_steer_and_accel(player, 0.016)
		await physics_frame

	player.enable_movement()
	if player.has_method("begin_vertical_impulse_instrumentation"):
		player.begin_vertical_impulse_instrumentation()

	var landed := false
	var land_frame := -1
	var max_y := player.global_position.y
	var yaw0 := player.rotation.y
	var positive_vy_after_land := 0
	var max_abs_steer := 0.0

	for i in 660:
		var cmd: Dictionary = follower.get_steer_and_accel(player, 0.016)
		if gm != null and im != null:
			if im.is_accelerating():
				gm.set("mobile_assist_steer", float(cmd.get("steer", 0.0)))
			else:
				gm.set("mobile_assist_steer", 0.0)
			max_abs_steer = maxf(max_abs_steer, absf(float(im.get_steer())))
		await physics_frame
		max_y = maxf(max_y, player.global_position.y)
		if not landed and player.is_on_floor():
			landed = true
			land_frame = i
			continue
		if landed and i > land_frame + 30 and player.velocity.y > 0.35:
			positive_vy_after_land += 1

	var impulses: Array = []
	if player.has_method("end_vertical_impulse_instrumentation"):
		impulses = player.end_vertical_impulse_instrumentation()

	if not landed:
		_fail("never landed after spawn fall")
	if positive_vy_after_land > 2:
		_fail("repeated positive vertical velocity after land (%d frames)" % positive_vy_after_land)
	if impulses.size() > 0:
		_fail("uncommanded vertical impulses after land: %s" % str(impulses))
	if max_abs_steer > 0.08:
		_fail("neutral steer drifted (max abs %.3f)" % max_abs_steer)
	var yaw_delta := absf(player.rotation.y - yaw0)
	if yaw_delta > 0.35:
		_fail("autonomous yaw turn under neutral (delta=%.3f)" % yaw_delta)
	if max_y > 4.5:
		_fail("vertical sky cycle suspected max_y=%.3f" % max_y)

	print(
		"OK spawn_fall_stable landed=%s land_frame=%d max_y=%.2f yaw_delta=%.3f steer_max=%.3f"
		% [str(landed), land_frame, max_y, yaw_delta, max_abs_steer]
	)

	player.queue_free()
	path.queue_free()
	floor_body.queue_free()
	await process_frame
