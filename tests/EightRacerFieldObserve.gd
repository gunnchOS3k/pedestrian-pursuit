extends SceneTree

## Dedicated eight-actor PartyLink field observe (headless).
## Proves spawn/control of 8 racers with honest human vs CPU labels + results path.
## Does NOT claim physical 8-human PartyLink, Mac Metal/MoltenVK, COURSE_ACCEPTED, or HUMAN/RC2/V1.
## Distinct from: independent 2-client Gate1, allocated lobby seats, physical 8p.

const TRACK_ID := "verdant_cascade_circuit"
const ALLOCATED_HUMAN_SEATS := 8
const CONNECTED_HUMANS := 1
const ENTER_FRAMES := 180
const COUNTDOWN_WAIT_MSEC := 8000
const DRIVE_BOUND_MSEC := 120000
## Observe bound only — shortens headless proof; not COURSE_ACCEPTED.
const OBSERVE_FORCE_LAPS := 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("EIGHT_RACER_FIELD_OBSERVE_BEGIN")
	print("TRACK_ID=%s" % TRACK_ID)
	print("ALLOCATED_HUMAN_SEATS=%d" % ALLOCATED_HUMAN_SEATS)
	print("CONNECTED_HUMANS=%d" % CONNECTED_HUMANS)
	print("PHYSICAL_EIGHT_HUMAN_PARTY=false")
	print("INDEPENDENT_TWO_CLIENT=false")
	print("MOLTENVK_METAL_PASS=false")
	print("COURSE_ACCEPTED=false")
	print("HUMAN=false")
	print("RC2=false")
	print("V1=false")

	var failures: PackedStringArray = []
	var gm := get_root().get_node_or_null("GameManager")
	var input := get_root().get_node_or_null("InputManager")
	if gm == null or not gm.has_method("start_party_link"):
		_fail_quit(["GameManager.start_party_link missing"])
		return

	if "accept_test_mode" in gm:
		gm.accept_test_mode = false
	if "accept_force_laps" in gm:
		gm.accept_force_laps = OBSERVE_FORCE_LAPS
	if "selected_shoe_id" in gm:
		gm.selected_shoe_id = "starter_soles"
	_release_input(input)

	gm.start_party_link(TRACK_ID, ALLOCATED_HUMAN_SEATS, CONNECTED_HUMANS)
	if not bool(gm.is_party_link()):
		failures.append("party_link not active")
	if int(gm.party_link_human_seats) != ALLOCATED_HUMAN_SEATS:
		failures.append("allocated seats mismatch")
	if int(gm.party_link_connected_humans) != CONNECTED_HUMANS:
		failures.append("connected humans invented or mismatched")
	if int(gm.ai_field_size) != 7:
		failures.append("ai_field_size must be 7 for field of 8")

	var packed: PackedScene = load("res://scenes/race/RaceScene.tscn") as PackedScene
	if packed == null:
		_fail_quit(["RaceScene.tscn failed to load"])
		return
	var scene := packed.instantiate()
	if scene == null:
		_fail_quit(["RaceScene instantiate null"])
		return
	get_root().add_child(scene)

	var track: Node = null
	var player: Node = null
	var race_manager: Node = null
	var entered := false
	for _i in ENTER_FRAMES:
		await physics_frame
		if not is_instance_valid(scene):
			_fail_quit(["RaceScene left tree before enter"])
			return
		track = scene.get_node_or_null("CourseTrack")
		player = scene.get_node_or_null("PlayerRacer")
		race_manager = scene.get_node_or_null("RaceManager")
		if track == null or player == null or race_manager == null:
			continue
		if track.has_method("get_race_path") and track.get_race_path() == null:
			continue
		var state := int(race_manager.get("state"))
		if state >= 1 and state <= 3:
			entered = true
			break
	if not entered:
		_fail_quit(["RaceScene did not reach countdown"])
		return

	var ownership: Dictionary = {}
	if scene.has_meta("field_ownership"):
		ownership = scene.get_meta("field_ownership")
	var actor_count := int(ownership.get("actor_count", 0))
	var connected := int(ownership.get("connected_humans", -1))
	var cpu_actors := int(ownership.get("cpu_actors", -1))
	print("ACTOR_COUNT=%d" % actor_count)
	print("FIELD_CONNECTED_HUMANS=%d" % connected)
	print("FIELD_CPU_ACTORS=%d" % cpu_actors)
	print("FIELD_OWNERSHIP_JSON=%s" % JSON.stringify(ownership))

	if actor_count != 8:
		failures.append("actor_count %d != 8" % actor_count)
	if connected != CONNECTED_HUMANS:
		failures.append("field connected_humans %d != %d (do not invent humans)" % [connected, CONNECTED_HUMANS])
	if cpu_actors != 8 - CONNECTED_HUMANS:
		failures.append("cpu_actors mismatch")
	if bool(ownership.get("physical_eight_human_party", true)):
		failures.append("physical_eight_human_party must stay false")
	if bool(ownership.get("COURSE_ACCEPTED", true)):
		failures.append("COURSE_ACCEPTED must stay false")

	var lap_manager := race_manager.get_node_or_null("LapManager")
	var registered := 0
	if lap_manager != null and lap_manager.has_method("get_racer_states"):
		registered = lap_manager.get_racer_states().size()
	print("LAP_REGISTERED_ACTORS=%d" % registered)
	if registered != 8:
		failures.append("LapManager registered %d != 8" % registered)

	## Seat honesty matrix lines for evidence.
	print("SEAT_HONESTY_MATRIX_BEGIN")
	print("seat\towner\tcontrol\tcounts_as_human\tracer_id")
	for row in ownership.get("seats", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		print(
			"%d\t%s\t%s\t%s\t%s" % [
				int(row.get("seat", -1)),
				str(row.get("owner", "")),
				str(row.get("control", "")),
				str(bool(row.get("counts_as_human_participant", false))).to_lower(),
				str(row.get("racer_id", "")),
			]
		)
	print("SEAT_HONESTY_MATRIX_END")

	var observed := {
		"checkpoint": false,
		"lap": false,
		"results": false,
		"actors_with_checkpoint": {},
		"actors_with_lap": {},
	}
	if lap_manager != null and lap_manager.has_signal("lap_changed"):
		lap_manager.lap_changed.connect(func(racer: Node, lap: int) -> void:
			if lap >= 1 and racer != null:
				observed["actors_with_lap"][racer.get_instance_id()] = true
				if racer == player:
					observed["lap"] = true
		)
	if track != null and track.has_method("get_checkpoints"):
		for checkpoint in track.get_checkpoints():
			if checkpoint != null and checkpoint.has_signal("racer_passed"):
				checkpoint.racer_passed.connect(func(racer: Node, index: int) -> void:
					if racer == null or index <= 0:
						return
					observed["actors_with_checkpoint"][racer.get_instance_id()] = true
					if racer == player:
						observed["checkpoint"] = true
				)
	if race_manager.has_signal("race_finished"):
		race_manager.race_finished.connect(func(_fp: Node, _fr: Array) -> void:
			observed["results"] = true
		)

	var countdown_finished := false
	var countdown_deadline := Time.get_ticks_msec() + COUNTDOWN_WAIT_MSEC
	while Time.get_ticks_msec() < countdown_deadline:
		await physics_frame
		if not is_instance_valid(race_manager):
			break
		if int(race_manager.get("state")) >= 2:
			countdown_finished = true
			break
	print("COUNTDOWN_FINISHED=%s" % str(countdown_finished).to_lower())
	if not countdown_finished:
		failures.append("countdown did not finish")

	var follower: Node = null
	if countdown_finished and is_instance_valid(player) and is_instance_valid(track):
		follower = _attach_line_steer(player, track)

	var driven_msec := 0
	var results := scene.get_node_or_null("ResultsScreen")
	if countdown_finished:
		var drive_started := Time.get_ticks_msec()
		var drive_deadline := drive_started + DRIVE_BOUND_MSEC
		var last_tick := drive_started
		while Time.get_ticks_msec() < drive_deadline:
			var now := Time.get_ticks_msec()
			var delta := clampf(float(now - last_tick) / 1000.0, 0.001, 0.05)
			last_tick = now
			_hold_input(input, follower, player, delta)
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
		_release_input(input)

	var actors_cp := int(observed["actors_with_checkpoint"].size())
	var actors_lap := int(observed["actors_with_lap"].size())
	print("DRIVEN_MSEC=%d" % driven_msec)
	print("PLAYER_CHECKPOINT=%s" % str(bool(observed["checkpoint"])).to_lower())
	print("PLAYER_LAP=%s" % str(bool(observed["lap"])).to_lower())
	print("RESULTS_PATH=%s" % str(bool(observed["results"])).to_lower())
	print("ACTORS_WITH_CHECKPOINT=%d" % actors_cp)
	print("ACTORS_WITH_LAP=%d" % actors_lap)
	print("LAP_HONESTY_NOTE=all_8_registered;checkpoints/laps per-actor;bots_not_labeled_human")

	if not bool(observed["checkpoint"]):
		failures.append("player checkpoint not observed")
	if not bool(observed["lap"]):
		failures.append("player lap not observed")
	if not bool(observed["results"]):
		failures.append("RESULTS_PATH false")
	## At least the local human must progress; CPU may also — never required to invent humans.
	if actors_cp < 1:
		failures.append("no actor checkpoint progress")

	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	for _i in 3:
		await physics_frame

	if failures.is_empty():
		print("EIGHT_RACER_FIELD_OBSERVE_PASS")
		print("EIGHT_RACER_FIELD_OBSERVE_END")
		quit(0)
		return
	print("EIGHT_RACER_FIELD_OBSERVE_FAIL")
	for f in failures:
		print(" - %s" % f)
	print("EIGHT_RACER_FIELD_OBSERVE_END")
	quit(1)


func _fail_quit(failures: PackedStringArray) -> void:
	print("EIGHT_RACER_FIELD_OBSERVE_FAIL")
	for f in failures:
		print(" - %s" % f)
	print("EIGHT_RACER_FIELD_OBSERVE_END")
	quit(1)


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
	if input == null:
		return
	if input.has_method("set_touch_accelerate"):
		input.set_touch_accelerate(false)
	if input.has_method("set_touch_steer"):
		input.set_touch_steer(0.0)
