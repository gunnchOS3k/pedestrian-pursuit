extends SceneTree

## Headless observer for the eight launch courses on the shared RaceScene.
## Verdant runs first. Each course uses the lap count in its track file.
## The same ground-restore steer and accelerate path is used for every course.
## A course is not owner-accepted. An unfinished course is printed and the run
## continues so the acceptance gate can fail that course without hiding it.
## Exits 0 after every course is printed. tests/verdant_race_acceptance_gate.py
## fails the job unless each course saw a checkpoint, a lap, and results.

const COURSE_IDS: Array[String] = [
	"verdant_cascade_circuit",
	"cloverwind_ranch",
	"prism_apex",
	"emberkeep_gauntlet",
	"tideglass_harbor",
	"neon_switchyard",
	"cloudstep_ridge",
	"mirage_mesa",
]
const ENTER_FRAMES := 180
## Countdown holds movement. Wait for RACING before any drive time counts.
const COUNTDOWN_WAIT_MSEC := 8000
## Per-course bound after GO. Not extended, and not a substitute for the gate.
const DRIVE_BOUND_MSEC := 150000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gm := get_root().get_node_or_null("GameManager")
	var input := get_root().get_node_or_null("InputManager")
	if gm == null or not gm.has_method("start_quick_race"):
		for track_id in COURSE_IDS:
			_print_course(track_id, false, -1, -1, -1, false, 0, false, false, false, false, "GameManager.start_quick_race is missing")
		quit(0)
		return
	var packed: PackedScene = load("res://scenes/race/RaceScene.tscn") as PackedScene
	if packed == null:
		for track_id in COURSE_IDS:
			_print_course(track_id, false, -1, -1, -1, false, 0, false, false, false, false, "res://scenes/race/RaceScene.tscn did not load")
		quit(0)
		return
	for track_id in COURSE_IDS:
		await _observe_course(gm, input, packed, track_id)
	quit(0)


func _observe_course(gm: Node, input: Node, packed: PackedScene, track_id: String) -> void:
	if "accept_test_mode" in gm:
		gm.accept_test_mode = false
	if "accept_force_laps" in gm:
		gm.accept_force_laps = 0
	_release_gameplay_input(input)
	var course := _load_course_file(track_id)
	var expected_laps := int(course.get("lap_count", -1))
	var display_name := str(course.get("display_name", ""))
	if course.is_empty() or expected_laps < 1 or display_name.is_empty():
		_print_course(track_id, false, expected_laps, -1, -1, false, 0, false, false, false, false, "course file missing lap count or display name")
		return
	gm.start_quick_race(track_id)
	if str(gm.get("selected_track_id")) != track_id:
		_print_course(track_id, false, expected_laps, int(gm.get("total_laps")), -1, false, 0, false, false, false, false, "quick race did not select %s" % track_id)
		return
	var scene := packed.instantiate()
	if scene == null:
		_print_course(track_id, false, expected_laps, int(gm.get("total_laps")), -1, false, 0, false, false, false, false, "RaceScene instantiate returned null")
		return
	get_root().add_child(scene)
	var entered := false
	var track: Node = null
	var player: Node = null
	var race_manager: Node = null
	for _i in ENTER_FRAMES:
		await physics_frame
		if not is_instance_valid(scene):
			_print_course(track_id, false, expected_laps, int(gm.get("total_laps")), -1, false, 0, false, false, false, false, "RaceScene left the tree before the race was entered")
			return
		track = scene.get_node_or_null("CourseTrack")
		player = scene.get_node_or_null("PlayerRacer")
		race_manager = scene.get_node_or_null("RaceManager")
		if track == null or player == null or race_manager == null:
			continue
		if not track.has_method("get_race_path") or not track.has_method("get_display_name"):
			_print_course(track_id, false, expected_laps, int(gm.get("total_laps")), -1, false, 0, false, false, false, false, "CourseTrack is missing get_race_path or get_display_name")
			await _drop_scene(scene)
			return
		if track.get_race_path() == null:
			continue
		if str(track.get_display_name()) != display_name:
			_print_course(track_id, false, expected_laps, int(gm.get("total_laps")), int(race_manager.get("state")), false, 0, false, false, false, false, "entered display name %s" % str(track.get_display_name()))
			await _drop_scene(scene)
			return
		var state := int(race_manager.get("state"))
		# RaceManager.RaceState: WAITING=0, COUNTDOWN=1, RACING=2, FINISHED=3.
		if state >= 1 and state <= 3:
			entered = true
			break
	if not entered:
		_print_course(track_id, false, expected_laps, int(gm.get("total_laps")), -1, false, 0, false, false, false, false, "%s RaceScene did not reach countdown" % track_id)
		await _drop_scene(scene)
		return
	var runtime_laps := int(gm.get("total_laps"))
	if runtime_laps != expected_laps:
		_print_course(track_id, true, expected_laps, runtime_laps, int(race_manager.get("state")), false, 0, false, false, false, false, "runtime laps %d did not match course lap_count %d" % [runtime_laps, expected_laps])
		await _drop_scene(scene)
		return
	var observed := {"checkpoint": false, "lap": false, "results": false}
	var lap_manager := race_manager.get_node_or_null("LapManager")
	if lap_manager != null and lap_manager.has_signal("lap_changed"):
		lap_manager.lap_changed.connect(func(_racer: Node, lap: int) -> void:
			if lap >= 1:
				observed["lap"] = true
		)
	if track.has_method("get_checkpoints"):
		for checkpoint in track.get_checkpoints():
			if checkpoint != null and checkpoint.has_signal("racer_passed"):
				checkpoint.racer_passed.connect(func(_racer: Node, index: int) -> void:
					# Index 0 is the start line. Spawn overlap is not a crossing.
					if index > 0:
						observed["checkpoint"] = true
				)
	if race_manager.has_signal("race_finished"):
		race_manager.race_finished.connect(func(_finished_player: Node, _finish_results: Array) -> void:
			observed["results"] = true
		)
	var results := scene.get_node_or_null("ResultsScreen")
	var countdown_finished := false
	var countdown_deadline := Time.get_ticks_msec() + COUNTDOWN_WAIT_MSEC
	while Time.get_ticks_msec() < countdown_deadline:
		await physics_frame
		if not is_instance_valid(race_manager):
			break
		if int(race_manager.get("state")) >= 2:
			countdown_finished = true
			break
	var follower: Node = null
	var line_steer := false
	if countdown_finished and is_instance_valid(player) and is_instance_valid(track):
		follower = _attach_line_steer(player, track)
		line_steer = follower != null
	var driven_msec := 0
	if countdown_finished:
		var drive_started := Time.get_ticks_msec()
		var drive_deadline := drive_started + DRIVE_BOUND_MSEC
		var last_tick := drive_started
		while Time.get_ticks_msec() < drive_deadline:
			var now := Time.get_ticks_msec()
			var delta := clampf(float(now - last_tick) / 1000.0, 0.001, 0.05)
			last_tick = now
			_hold_gameplay_input(input, follower, player, delta)
			await physics_frame
			if not is_instance_valid(scene):
				break
			if results != null:
				var panel := results.get_node_or_null("Panel")
				if panel != null and bool(panel.get("visible")):
					observed["results"] = true
			if lap_manager != null and is_instance_valid(player) and lap_manager.has_method("get_lap"):
				if int(lap_manager.get_lap(player)) >= 1:
					observed["lap"] = true
			if bool(observed["checkpoint"]) and bool(observed["lap"]) and bool(observed["results"]):
				break
		driven_msec = Time.get_ticks_msec() - drive_started
		_release_gameplay_input(input)
	var state_after := -1
	if is_instance_valid(race_manager):
		state_after = int(race_manager.get("state"))
	_print_course(
		track_id,
		true,
		expected_laps,
		runtime_laps,
		state_after,
		countdown_finished,
		driven_msec,
		line_steer,
		bool(observed["lap"]),
		bool(observed["checkpoint"]),
		bool(observed["results"]),
		""
	)
	await _drop_scene(scene)


func _load_course_file(track_id: String) -> Dictionary:
	var path := "res://data/tracks/%s.json" % track_id
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


func _print_course(
	track_id: String,
	entered: bool,
	expected_laps: int,
	runtime_laps: int,
	race_state: int,
	countdown_finished: bool,
	driven_msec: int,
	line_steer: bool,
	lap_completed: bool,
	checkpoint_crossed: bool,
	results_path: bool,
	fail_reason: String
) -> void:
	print("COURSE_OBSERVE_BEGIN")
	print("TRACK_ID=%s" % track_id)
	print("RACE_ENTERED=%s" % str(entered).to_lower())
	print("RACE_STATE=%d" % race_state)
	print("LAP_COUNT=%d" % expected_laps)
	print("LAP_COUNT_RUNTIME=%d" % runtime_laps)
	print("COUNTDOWN_FINISHED=%s" % str(countdown_finished).to_lower())
	print("DRIVE_BOUND_MSEC=%d" % DRIVE_BOUND_MSEC)
	print("DRIVEN_MSEC=%d" % driven_msec)
	print("LINE_STEER=%s" % str(line_steer).to_lower())
	print("INPUT_PATH=accelerate_action+touch_accelerate+touch_steer")
	print("LAP_COMPLETED=%s" % str(lap_completed).to_lower())
	print("CHECKPOINT_CROSSED=%s" % str(checkpoint_crossed).to_lower())
	print("RESULTS_PATH=%s" % str(results_path).to_lower())
	print("COURSE_ACCEPTED=false")
	print("DEVICE_RUN=false")
	if not fail_reason.is_empty():
		print("RACE_SCENE_FAIL %s" % fail_reason)
	print("COURSE_OBSERVE_END")


func _drop_scene(scene: Node) -> void:
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	for _i in 3:
		await physics_frame


func _attach_line_steer(player: Node, track: Node) -> Node:
	## Feed the existing racing-line steer through touch input. Do not snap the
	## body onto the path and do not enable accept_test_mode.
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


func _hold_gameplay_input(input: Node, follower: Node, player: Node, delta: float) -> void:
	var accelerate := true
	var steer := 0.0
	if follower != null and player is CharacterBody3D and follower.has_method("get_steer_and_accel"):
		# The follower lifts any body below y=0.2 onto the path. A grounded
		# capsule origin sits near y=0, so that lift fires before physics and
		# the racer never stays on the floor. Throttle only builds speed there.
		# player is typed as Node, so assigning global_position.y edits a copy.
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


func _release_gameplay_input(input: Node) -> void:
	Input.action_release("accelerate")
	if input == null:
		return
	if input.has_method("set_touch_accelerate"):
		input.set_touch_accelerate(false)
	if input.has_method("set_touch_steer"):
		input.set_touch_steer(0.0)
