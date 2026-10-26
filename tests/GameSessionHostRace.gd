extends SceneTree

## Authoritative race process for the host player. The guest process supplies
## Player2Racer input. The course AI is not the guest.

const COURSE_ID := "verdant_cascade_circuit"
const ENTER_FRAMES := 180
const COUNTDOWN_WAIT_MSEC := 8000
const DRIVE_BOUND_MSEC := 150000
const GUEST_WAIT_MSEC := 45000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dir := OS.get_environment("GAME_SESSION_DIR").strip_edges()
	var session := _read_json(dir.path_join("host_view.json"))
	if session.is_empty() or str(session.get("role", "")) != "host":
		_fail(dir, {}, "host view is missing")
		return
	var gm := get_root().get_node_or_null("GameManager")
	var input := get_root().get_node_or_null("InputManager")
	if gm == null or not gm.has_method("start_local_mp"):
		_fail(dir, session, "GameManager.start_local_mp is missing")
		return
	var packed: PackedScene = load("res://scenes/race/RaceScene.tscn") as PackedScene
	if packed == null:
		_fail(dir, session, "RaceScene did not load")
		return
	if "accept_test_mode" in gm:
		gm.accept_test_mode = false
	if "accept_force_laps" in gm:
		gm.accept_force_laps = 0
	_release_input(input)
	gm.start_local_mp(COURSE_ID, 2)
	var scene := packed.instantiate()
	get_root().add_child(scene)
	var player: Node = null
	var guest: Node = null
	var track: Node = null
	var race_manager: Node = null
	var entered := false
	for _i in ENTER_FRAMES:
		await physics_frame
		if not is_instance_valid(scene):
			break
		track = scene.get_node_or_null("CourseTrack")
		player = scene.get_node_or_null("PlayerRacer")
		guest = scene.get_node_or_null("Player2Racer")
		race_manager = scene.get_node_or_null("RaceManager")
		if track == null or player == null or guest == null or race_manager == null:
			continue
		if not bool(guest.get("is_player")) or int(guest.get("local_player_index")) != 1:
			_fail(dir, session, "Player2Racer is not an independent player")
			return
		if track.get_race_path() == null:
			continue
		var state := int(race_manager.get("state"))
		if state >= 1 and state <= 3:
			entered = true
			break
	if not entered:
		_fail(dir, session, "race did not reach countdown")
		return
	_write_path(dir, track)
	var course := _load_course(COURSE_ID)
	var expected_laps := int(course.get("lap_count", -1))
	if int(gm.get("total_laps")) != expected_laps or expected_laps < 1:
		_fail(dir, session, "runtime lap count does not match the course")
		return
	var counts := {"host": 0, "guest": 0}
	if track.has_method("get_checkpoints"):
		for checkpoint in track.get_checkpoints():
			if checkpoint != null and checkpoint.has_signal("racer_passed"):
				checkpoint.racer_passed.connect(func(racer: Node, index: int) -> void:
					if index <= 0:
						return
					if racer == player:
						counts["host"] = int(counts["host"]) + 1
					elif racer == guest:
						counts["guest"] = int(counts["guest"]) + 1
				)
	var flags := {"results": false}
	if race_manager.has_signal("race_finished"):
		race_manager.race_finished.connect(func(_finished_player: Node, _finish_results: Array) -> void:
			flags["results"] = true
		)
	var ready_deadline := Time.get_ticks_msec() + GUEST_WAIT_MSEC
	var guest_ready := false
	while Time.get_ticks_msec() < ready_deadline:
		_write_snapshot(dir, race_manager, guest, flags)
		var ready := _read_json(dir.path_join("sync/guest_ready.json"))
		if str(ready.get("source", "")) == "guest-process":
			guest_ready = true
			break
		await physics_frame
	if not guest_ready:
		_fail(dir, session, "guest process did not attach")
		return
	var countdown_finished := false
	var countdown_deadline := Time.get_ticks_msec() + COUNTDOWN_WAIT_MSEC
	while Time.get_ticks_msec() < countdown_deadline:
		_write_snapshot(dir, race_manager, guest, flags)
		_apply_guest_input(dir, guest)
		await physics_frame
		if is_instance_valid(race_manager) and int(race_manager.get("state")) >= 2:
			countdown_finished = true
			break
	var follower: Node = null
	if countdown_finished and is_instance_valid(player) and is_instance_valid(track):
		follower = _attach_line_steer(player, track)
	var driven_msec := 0
	var guest_commands := 0
	var guest_max_speed := 0.0
	var lap_manager: Node = null
	if is_instance_valid(race_manager):
		lap_manager = race_manager.get_node_or_null("LapManager")
	if countdown_finished:
		var started := Time.get_ticks_msec()
		var deadline := started + DRIVE_BOUND_MSEC
		var last_tick := started
		while Time.get_ticks_msec() < deadline:
			var now := Time.get_ticks_msec()
			var delta := clampf(float(now - last_tick) / 1000.0, 0.001, 0.05)
			last_tick = now
			_write_snapshot(dir, race_manager, guest, flags)
			if _apply_guest_input(dir, guest):
				guest_commands += 1
			if "horizontal_speed" in guest:
				guest_max_speed = maxf(guest_max_speed, float(guest.horizontal_speed))
			_hold_input(input, follower, player, delta)
			await physics_frame
			if not is_instance_valid(scene):
				break
			var panel := scene.get_node_or_null("ResultsScreen/Panel")
			if panel != null and bool(panel.get("visible")):
				flags["results"] = true
			if bool(flags["results"]) and _laps(lap_manager, player) >= 1 and _laps(lap_manager, guest) >= 1 and int(counts["host"]) >= 1 and int(counts["guest"]) >= 1 and guest_commands > 20:
				break
		driven_msec = Time.get_ticks_msec() - started
		_release_input(input)
	_write_snapshot(dir, race_manager, guest, flags)
	var host_laps := _laps(lap_manager, player)
	var guest_laps := _laps(lap_manager, guest)
	var host_checks := int(counts["host"])
	var guest_checks := int(counts["guest"])
	var results_path := bool(flags["results"])
	var both := (
		guest_ready
		and guest_commands > 20
		and results_path
		and host_laps >= 1
		and guest_laps >= 1
		and host_checks >= 1
		and guest_checks >= 1
		and driven_msec >= 1
		and driven_msec <= DRIVE_BOUND_MSEC
	)
	var finish: Array = [str(session["hostId"]), str(session["memberId"])]
	if guest_laps > host_laps:
		finish = [str(session["memberId"]), str(session["hostId"])]
	var result := {
		"applicationId": str(session["applicationId"]),
		"roomCode": str(session["roomCode"]),
		"courseId": COURSE_ID,
		"hostMemberId": str(session["hostId"]),
		"guestMemberId": str(session["memberId"]),
		"lapsCompleted": {"host": host_laps, "guest": guest_laps},
		"checkpointCrossings": {"host": host_checks, "guest": guest_checks},
		"drivenMsec": driven_msec,
		"finishOrder": finish,
		"bothFinished": both,
		"producedBy": "pedestrian-pursuit-race-runtime",
		"sourceLog": {
			"resultsPath": results_path,
			"hostLapCompleted": host_laps >= 1,
			"guestLapCompleted": guest_laps >= 1,
			"hostCheckpoint": host_checks >= 1,
			"guestCheckpoint": guest_checks >= 1,
		},
		"guestSeat": "Player2Racer",
		"guestControl": "guest-process",
		"hostControl": "host-process",
		"courseAiIsGuest": false,
		"hostPid": OS.get_process_id(),
		"guestCommands": guest_commands,
		"guestMaxSpeed": guest_max_speed,
		"ecosystemReturn": "ready",
	}
	_write_json(dir.path_join("result.json"), result)
	print("GAME_SESSION_ROLE=host")
	print("GAME_SESSION_GUEST_SEAT=Player2Racer")
	print("GAME_SESSION_COURSE_AI_IS_GUEST=false")
	print("GAME_SESSION_COURSE=%s" % COURSE_ID)
	print("GAME_SESSION_RESULTS_PATH=%s" % str(results_path).to_lower())
	print("GAME_SESSION_HOST_LAPS=%d" % host_laps)
	print("GAME_SESSION_GUEST_LAPS=%d" % guest_laps)
	print("GAME_SESSION_HOST_CHECKS=%d" % host_checks)
	print("GAME_SESSION_GUEST_CHECKS=%d" % guest_checks)
	print("GAME_SESSION_DRIVEN_MSEC=%d" % driven_msec)
	print("GAME_SESSION_GUEST_COMMANDS=%d" % guest_commands)
	print("GAME_SESSION_GUEST_MAX_SPEED=%.3f" % guest_max_speed)
	print("GAME_SESSION_BOTH_FINISHED=%s" % str(both).to_lower())
	print("ECOSYSTEM_RETURN=ready")
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	quit(0 if both else 1)


func _write_snapshot(dir: String, race_manager: Node, guest: Node, flags: Dictionary) -> void:
	if dir.is_empty() or guest == null or not is_instance_valid(guest):
		return
	var position := Vector3.ZERO
	var forward := Vector3.FORWARD
	if guest is Node3D:
		var body := guest as Node3D
		position = body.global_position
		forward = -body.global_transform.basis.z
	var speed := 0.0
	if "horizontal_speed" in guest:
		speed = float(guest.horizontal_speed)
	var state := -1
	if race_manager != null and is_instance_valid(race_manager):
		state = int(race_manager.get("state"))
	_write_json(dir.path_join("sync/snapshot.json"), {
		"raceState": state,
		"finished": bool(flags.get("results", false)),
		"guestPosition": [position.x, position.y, position.z],
		"guestForward": [forward.x, forward.y, forward.z],
		"guestSpeed": speed,
		"hostPid": OS.get_process_id(),
		"pathStart": _path_start(race_manager),
	})


func _apply_guest_input(dir: String, guest: Node) -> bool:
	var cmd := _read_json(dir.path_join("sync/guest_input.json"))
	if str(cmd.get("source", "")) != "guest-process" or guest == null or not guest.has_method("set_remote_drive"):
		return false
	guest.set_remote_drive(float(cmd.get("steer", 0.0)), bool(cmd.get("accelerate", false)))
	return true


func _write_path(dir: String, track: Node) -> void:
	if track == null or not track.has_method("get_race_path"):
		return
	var path: Path3D = track.get_race_path()
	if path == null or path.curve == null:
		return
	var length := path.curve.get_baked_length()
	var points: Array = []
	var distance := 0.0
	while distance <= length:
		var point := path.to_global(path.curve.sample_baked(distance))
		points.append([point.x, point.y, point.z])
		distance += 2.0
	_write_json(dir.path_join("sync/path.json"), {"points": points})


func _path_start(race_manager: Node) -> Array:
	var scene := race_manager.get_parent() if race_manager != null else null
	var track: Node = scene.get_node_or_null("CourseTrack") if scene != null else null
	if track == null or not track.has_method("get_race_path"):
		return [0.0, 0.0, 0.0]
	var path: Path3D = track.get_race_path()
	if path == null or path.curve == null:
		return [0.0, 0.0, 0.0]
	var point: Vector3 = path.to_global(path.curve.sample_baked(0.0))
	return [point.x, point.y, point.z]


func _read_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.contains("hostSession") or text.contains("hostToken"):
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


func _load_course(track_id: String) -> Dictionary:
	var path := "res://data/tracks/%s.json" % track_id
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


func _laps(lap_manager: Node, racer: Node) -> int:
	if lap_manager == null or racer == null or not is_instance_valid(racer):
		return 0
	if lap_manager.has_method("get_lap"):
		return int(lap_manager.get_lap(racer))
	return 0


func _attach_line_steer(player: Node, track: Node) -> Node:
	if not track.has_method("get_race_path"):
		return null
	var path: Path3D = track.get_race_path()
	if path == null or path.curve == null:
		return null
	var follower_script = load("res://scripts/ai/AIPathFollower.gd")
	if follower_script == null:
		return null
	var follower: Node = follower_script.new()
	follower.name = "HeadlessLineSteer"
	player.add_child(follower)
	follower.setup(path)
	follower.set("look_ahead", 5.5)
	follower.set("magnet_strength", 0.0)
	return follower


func _hold_input(input: Node, follower: Node, player: Node, delta: float) -> void:
	var accelerate := true
	var steer := 0.0
	if follower != null and player is CharacterBody3D and follower.has_method("get_steer_and_accel"):
		var body := player as CharacterBody3D
		var grounded_y: float = body.global_position.y
		var cmd: Dictionary = follower.get_steer_and_accel(body, delta)
		var restored_position := body.global_position
		restored_position.y = grounded_y
		body.global_position = restored_position
		steer = float(cmd.get("steer", 0.0))
		accelerate = bool(cmd.get("accelerate", true))
	if input != null and input.has_method("set_touch_steer"):
		input.set_touch_steer(steer)
	if accelerate:
		Input.action_press("accelerate")
		if input != null and input.has_method("set_touch_accelerate"):
			input.set_touch_accelerate(true)
	else:
		Input.action_release("accelerate")
		if input != null and input.has_method("set_touch_accelerate"):
			input.set_touch_accelerate(false)


func _release_input(input: Node) -> void:
	Input.action_release("accelerate")
	Input.action_release("p2_accelerate")
	Input.action_release("p2_move_left")
	Input.action_release("p2_move_right")
	if input == null:
		return
	if input.has_method("set_touch_accelerate"):
		input.set_touch_accelerate(false)
	if input.has_method("set_touch_steer"):
		input.set_touch_steer(0.0)


func _write_json(path: String, value: Dictionary) -> void:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(value))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)


func _fail(dir: String, session: Dictionary, reason: String) -> void:
	print("GAME_SESSION_ROLE=host")
	print("GAME_SESSION_RACE_FAIL %s" % reason)
	print("GAME_SESSION_COURSE_AI_IS_GUEST=false")
	if not dir.is_empty():
		_write_json(dir.path_join("result.json"), {
			"applicationId": str(session.get("applicationId", "pedestrian-pursuit")),
			"roomCode": str(session.get("roomCode", "")),
			"bothFinished": false,
			"failReason": reason,
			"guestSeat": "Player2Racer",
			"guestControl": "guest-process",
			"hostControl": "host-process",
			"courseAiIsGuest": false,
			"producedBy": "pedestrian-pursuit-race-runtime",
		})
	quit(1)
