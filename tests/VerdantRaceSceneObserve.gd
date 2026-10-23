extends SceneTree

## Headless observer for the one shared race scene on Verdant Cascade Circuit.
## Records whether a lap, a non-start checkpoint, and the results screen actually run.
## A 12-second watch is not acceptance. This script does not accept the course,
## does not force laps, and does not claim a device run.
## Exits nonzero when the scene cannot be entered. A finished observation with
## an incomplete lap still exits 0; tests/verdant_race_acceptance_gate.py fails
## the job unless checkpoint, lap, and results were all observed.

const TRACK_ID := "verdant_cascade_circuit"
const DISPLAY_NAME := "Verdant Cascade Circuit"
const ENTER_FRAMES := 180
## Countdown holds movement. Wait for RACING before any drive time counts.
const COUNTDOWN_WAIT_MSEC := 8000
## Bounded racing window after GO. Not long enough to declare the other courses,
## and not a substitute for the acceptance gate.
const DRIVE_BOUND_MSEC := 150000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gm := get_root().get_node_or_null("GameManager")
	if gm == null or not gm.has_method("start_quick_race"):
		_fail("GameManager.start_quick_race is missing")
		return
	if "accept_test_mode" in gm:
		gm.accept_test_mode = false
	if "accept_force_laps" in gm:
		gm.accept_force_laps = 0
	gm.start_quick_race(TRACK_ID)
	if str(gm.get("selected_track_id")) != TRACK_ID:
		_fail("quick race did not select %s" % TRACK_ID)
		return
	var packed: PackedScene = load("res://scenes/race/RaceScene.tscn") as PackedScene
	if packed == null:
		_fail("res://scenes/race/RaceScene.tscn did not load")
		return
	var scene := packed.instantiate()
	if scene == null:
		_fail("RaceScene instantiate returned null")
		return
	get_root().add_child(scene)
	var entered := false
	var track: Node = null
	var player: Node = null
	var race_manager: Node = null
	for _i in ENTER_FRAMES:
		await physics_frame
		if not is_instance_valid(scene):
			_fail("RaceScene left the tree before the race was entered")
			return
		track = scene.get_node_or_null("CourseTrack")
		player = scene.get_node_or_null("PlayerRacer")
		race_manager = scene.get_node_or_null("RaceManager")
		if track == null or player == null or race_manager == null:
			continue
		if not track.has_method("get_race_path") or not track.has_method("get_display_name"):
			_fail("CourseTrack is missing get_race_path or get_display_name")
			return
		if track.get_race_path() == null:
			continue
		if str(track.get_display_name()) != DISPLAY_NAME:
			_fail("entered display name %s" % str(track.get_display_name()))
			return
		var state := int(race_manager.get("state"))
		# RaceManager.RaceState: WAITING=0, COUNTDOWN=1, RACING=2, FINISHED=3.
		if state >= 1 and state <= 3:
			entered = true
			break
	if not entered:
		_fail("Verdant RaceScene did not reach countdown")
		return
	# Dictionary so signal callbacks mutate the same record. A bool capture would not.
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
	var input := get_root().get_node_or_null("InputManager")
	var countdown_finished := false
	var countdown_deadline := Time.get_ticks_msec() + COUNTDOWN_WAIT_MSEC
	while Time.get_ticks_msec() < countdown_deadline:
		await physics_frame
		if not is_instance_valid(race_manager):
			break
		# RaceManager.RaceState: RACING=2, FINISHED=3. Movement stays off until then.
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
	print("RACE_ENTERED=true")
	print("TRACK_ID=%s" % TRACK_ID)
	print("RACE_STATE=%d" % state_after)
	print("COUNTDOWN_FINISHED=%s" % str(countdown_finished).to_lower())
	print("DRIVE_BOUND_MSEC=%d" % DRIVE_BOUND_MSEC)
	print("DRIVEN_MSEC=%d" % driven_msec)
	print("LINE_STEER=%s" % str(line_steer).to_lower())
	print("INPUT_PATH=accelerate_action+touch_accelerate+touch_steer")
	print("LAP_COMPLETED=%s" % str(bool(observed["lap"])).to_lower())
	print("CHECKPOINT_CROSSED=%s" % str(bool(observed["checkpoint"])).to_lower())
	print("RESULTS_PATH=%s" % str(bool(observed["results"])).to_lower())
	print("COURSE_ACCEPTED=false")
	print("DEVICE_RUN=false")
	print("RACE_SCENE_OBSERVE_ENTERED %s" % TRACK_ID)
	quit(0)


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
		var cmd: Dictionary = follower.get_steer_and_accel(player, delta)
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


func _fail(reason: String) -> void:
	print("RACE_ENTERED=false")
	print("TRACK_ID=%s" % TRACK_ID)
	print("LAP_COMPLETED=false")
	print("CHECKPOINT_CROSSED=false")
	print("RESULTS_PATH=false")
	print("COURSE_ACCEPTED=false")
	print("DEVICE_RUN=false")
	print("RACE_SCENE_FAIL %s" % reason)
	push_error(reason)
	quit(1)
