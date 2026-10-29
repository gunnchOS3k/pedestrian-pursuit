extends SceneTree

## Headless observer for the eight launch courses on the shared RaceScene.
## Verdant runs first. Each course uses the lap count in its track file.
## The same ground-restore steer and accelerate path is used for every course.
## A course is not owner-accepted. An unfinished course is printed and the run
## continues so the acceptance gate can fail that course without hiding it.
## Exits 0 after every course is printed. tests/verdant_race_acceptance_gate.py
## fails the job unless each course saw a checkpoint, a lap, and results.

## Cups 1–2 launch set, then cups 3–8 championship matrix (Metro → Wonder).
const COURSE_IDS: Array[String] = [
	"verdant_cascade_circuit",
	"cloverwind_ranch",
	"prism_apex",
	"emberkeep_gauntlet",
	"tideglass_harbor",
	"neon_switchyard",
	"cloudstep_ridge",
	"mirage_mesa",
	"sneaker_city_sprintway",
	"metro_pulse_loop",
	"crosswalk_canyon",
	"transit_spiral",
	"saltline_boardwalk",
	"cliffside_draft",
	"tidal_bridge_run",
	"seaglass_switchback",
	"lantern_corridor",
	"mirror_boulevard",
	"afterglow_overpass",
	"signal_storm_yard",
	"rooftop_ribbon",
	"skybridge_sprint",
	"antenna_ascent",
	"cloud_deck_circuit",
	"marble_foyer_loop",
	"stack_corridor",
	"gallery_grand_oval",
	"vault_gate_gauntlet",
	"cascade_colossus",
	"aurora_amphitheater",
	"origami_orchard",
	"horizon_crown_finale",
]
## Cup 3 Metro Motion.
const CUP3_COURSE_IDS: Array[String] = [
	"sneaker_city_sprintway",
	"metro_pulse_loop",
	"crosswalk_canyon",
	"transit_spiral",
]
## Cup 4 Kinetic Coast.
const CUP4_COURSE_IDS: Array[String] = [
	"saltline_boardwalk",
	"cliffside_draft",
	"tidal_bridge_run",
	"seaglass_switchback",
]
## Cup 5 Neon Night.
const CUP5_COURSE_IDS: Array[String] = [
	"lantern_corridor",
	"mirror_boulevard",
	"afterglow_overpass",
	"signal_storm_yard",
]
## Cup 6 Skyline Relay.
const CUP6_COURSE_IDS: Array[String] = [
	"rooftop_ribbon",
	"skybridge_sprint",
	"antenna_ascent",
	"cloud_deck_circuit",
]
## Cup 7 Archive Relay.
const CUP7_COURSE_IDS: Array[String] = [
	"marble_foyer_loop",
	"stack_corridor",
	"gallery_grand_oval",
	"vault_gate_gauntlet",
]
## Cup 8 World Wonder Grand Prix.
const CUP8_COURSE_IDS: Array[String] = [
	"cascade_colossus",
	"aurora_amphitheater",
	"origami_orchard",
	"horizon_crown_finale",
]
## Cups 3–8 elevated courses need a soft racing-line magnet under headless steer.
const ELEVATED_COURSE_IDS: Array[String] = [
	"sneaker_city_sprintway",
	"metro_pulse_loop",
	"crosswalk_canyon",
	"transit_spiral",
	"saltline_boardwalk",
	"cliffside_draft",
	"tidal_bridge_run",
	"seaglass_switchback",
	"lantern_corridor",
	"mirror_boulevard",
	"afterglow_overpass",
	"signal_storm_yard",
	"rooftop_ribbon",
	"skybridge_sprint",
	"antenna_ascent",
	"cloud_deck_circuit",
	"marble_foyer_loop",
	"stack_corridor",
	"gallery_grand_oval",
	"vault_gate_gauntlet",
	"cascade_colossus",
	"aurora_amphitheater",
	"origami_orchard",
	"horizon_crown_finale",
]
const ENTER_FRAMES := 180
## Countdown holds movement. Wait for RACING before any drive time counts.
const COUNTDOWN_WAIT_MSEC := 8000
## Per-course bound after GO. Not extended, and not a substitute for the gate.
const DRIVE_BOUND_MSEC := 150000
const TELEMETRY_INTERVAL_MSEC := 1000
const TELEMETRY_MAX_SAMPLES := 160


func _initialize() -> void:
	call_deferred("_run")


func _observe_plan() -> Dictionary:
	var mode := OS.get_environment("RACE_OBSERVE_MODE").strip_edges()
	var track_filter := OS.get_environment("RACE_OBSERVE_TRACK").strip_edges()
	if not track_filter.is_empty():
		return {
			"mode": "single",
			"courses": PackedStringArray([track_filter]),
			"stop_after": 1,
		}
	if mode == "solo":
		return {
			"mode": "solo",
			"courses": PackedStringArray(["verdant_cascade_circuit"]),
			"stop_after": 1,
		}
	if mode == "batch-first":
		return {
			"mode": "batch-first",
			"courses": PackedStringArray(COURSE_IDS),
			"stop_after": 1,
		}
	if mode == "cup3":
		return {
			"mode": "cup3",
			"courses": PackedStringArray(CUP3_COURSE_IDS),
			"stop_after": CUP3_COURSE_IDS.size(),
		}
	if mode == "cup4":
		return {
			"mode": "cup4",
			"courses": PackedStringArray(CUP4_COURSE_IDS),
			"stop_after": CUP4_COURSE_IDS.size(),
		}
	if mode == "cup5":
		return {
			"mode": "cup5",
			"courses": PackedStringArray(CUP5_COURSE_IDS),
			"stop_after": CUP5_COURSE_IDS.size(),
		}
	if mode == "cup6":
		return {
			"mode": "cup6",
			"courses": PackedStringArray(CUP6_COURSE_IDS),
			"stop_after": CUP6_COURSE_IDS.size(),
		}
	if mode == "cup7":
		return {
			"mode": "cup7",
			"courses": PackedStringArray(CUP7_COURSE_IDS),
			"stop_after": CUP7_COURSE_IDS.size(),
		}
	if mode == "cup8":
		return {
			"mode": "cup8",
			"courses": PackedStringArray(CUP8_COURSE_IDS),
			"stop_after": CUP8_COURSE_IDS.size(),
		}
	if mode == "cups4-8":
		var cups48: Array[String] = []
		cups48.append_array(CUP4_COURSE_IDS)
		cups48.append_array(CUP5_COURSE_IDS)
		cups48.append_array(CUP6_COURSE_IDS)
		cups48.append_array(CUP7_COURSE_IDS)
		cups48.append_array(CUP8_COURSE_IDS)
		return {
			"mode": "cups4-8",
			"courses": PackedStringArray(cups48),
			"stop_after": cups48.size(),
		}
	if mode == "cups3-8":
		return {
			"mode": "cups3-8",
			"courses": PackedStringArray(ELEVATED_COURSE_IDS),
			"stop_after": ELEVATED_COURSE_IDS.size(),
		}
	if mode == "cups1-3":
		var cups13: Array[String] = [
			"verdant_cascade_circuit",
			"cloverwind_ranch",
			"prism_apex",
			"emberkeep_gauntlet",
			"tideglass_harbor",
			"neon_switchyard",
			"cloudstep_ridge",
			"mirage_mesa",
		]
		cups13.append_array(CUP3_COURSE_IDS)
		return {
			"mode": "cups1-3",
			"courses": PackedStringArray(cups13),
			"stop_after": cups13.size(),
		}
	## Default stays cups 1–2 launch set for Gate1 parity; cups 3–8 opt in via mode/track.
	var launch_only := PackedStringArray([
		"verdant_cascade_circuit",
		"cloverwind_ranch",
		"prism_apex",
		"emberkeep_gauntlet",
		"tideglass_harbor",
		"neon_switchyard",
		"cloudstep_ridge",
		"mirage_mesa",
	])
	return {
		"mode": "all",
		"courses": launch_only,
		"stop_after": launch_only.size(),
	}


func _run() -> void:
	var plan := _observe_plan()
	print("OBSERVE_MODE=%s" % str(plan["mode"]))
	print("OBSERVE_STOP_AFTER=%d" % int(plan["stop_after"]))
	var courses := PackedStringArray(plan["courses"])
	var gm := get_root().get_node_or_null("GameManager")
	var input := get_root().get_node_or_null("InputManager")
	if gm == null or not gm.has_method("start_quick_race"):
		for track_id in courses:
			_print_course(track_id, false, -1, -1, -1, false, 0, false, false, false, false, "GameManager.start_quick_race is missing")
		quit(0)
		return
	var packed: PackedScene = load("res://scenes/race/RaceScene.tscn") as PackedScene
	if packed == null:
		for track_id in courses:
			_print_course(track_id, false, -1, -1, -1, false, 0, false, false, false, false, "res://scenes/race/RaceScene.tscn did not load")
		quit(0)
		return
	var seen := 0
	for track_id in courses:
		await _observe_course(gm, input, packed, track_id)
		seen += 1
		if seen >= int(plan["stop_after"]):
			break
	quit(0)


func _observe_course(gm: Node, input: Node, packed: PackedScene, track_id: String) -> void:
	if "accept_test_mode" in gm:
		gm.accept_test_mode = false
	if "accept_force_laps" in gm:
		gm.accept_force_laps = 0
	## Proven observe footwear — matches last green Gate 1 shoe default.
	if "selected_shoe_id" in gm:
		gm.selected_shoe_id = "starter_soles"
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
		lap_manager.lap_changed.connect(func(racer: Node, lap: int) -> void:
			if racer == player and lap >= 1:
				observed["lap"] = true
		)
	var checkpoint_history: Array = []
	if track.has_method("get_checkpoints"):
		for checkpoint in track.get_checkpoints():
			if checkpoint != null and checkpoint.has_signal("racer_passed"):
				checkpoint.racer_passed.connect(func(racer: Node, index: int) -> void:
					# Index 0 is the start line. Spawn overlap is not a crossing.
					# Prefix the racer so an AI lap cannot satisfy the player gate.
					if racer == player and index > 0:
						observed["checkpoint"] = true
					if checkpoint_history.size() < 64:
						var who := "p" if racer == player else "a"
						checkpoint_history.append("%s%d" % [who, index])
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
		follower = _attach_line_steer(player, track, track_id)
		line_steer = follower != null
	var driven_msec := 0
	var sample_count := 0
	var max_gap := 0.0
	var max_lateral := 0.0
	var max_speed := 0.0
	var completed_laps := 0
	if countdown_finished:
		var drive_started := Time.get_ticks_msec()
		var drive_deadline := drive_started + DRIVE_BOUND_MSEC
		var last_tick := drive_started
		var next_sample := drive_started
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
				completed_laps = int(lap_manager.get_lap(player))
				if completed_laps >= 1:
					observed["lap"] = true
			if sample_count < TELEMETRY_MAX_SAMPLES and now >= next_sample:
				var snap := _sample_driver(track_id, now - drive_started, delta, player, follower, lap_manager, race_manager, results, input)
				sample_count += 1
				next_sample = now + TELEMETRY_INTERVAL_MSEC
				max_gap = maxf(max_gap, absf(float(snap.get("progress_gap", 0.0))))
				max_lateral = maxf(max_lateral, float(snap.get("lateral", 0.0)))
				max_speed = maxf(max_speed, float(snap.get("hspeed", 0.0)))
			if bool(observed["checkpoint"]) and bool(observed["lap"]) and bool(observed["results"]):
				break
		driven_msec = Time.get_ticks_msec() - drive_started
		_release_gameplay_input(input)
	var reacquire_count := 0
	if follower != null and is_instance_valid(follower) and "reacquire_count" in follower:
		reacquire_count = int(follower.reacquire_count)
	print("DRIVER_SUMMARY track=%s samples=%d max_gap=%.3f max_lateral=%.3f max_hspeed=%.3f completed_laps=%d reacquire_count=%d checkpoint_history=%s" % [
		track_id,
		sample_count,
		max_gap,
		max_lateral,
		max_speed,
		completed_laps,
		reacquire_count,
		",".join(PackedStringArray(checkpoint_history)),
	])
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


func _attach_line_steer(player: Node, track: Node, track_id: String = "") -> Node:
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
	## Flat launch cups stay magnet-off. Elevated cup-3+ courses need a soft
	## racing-line magnet (same assist AI rookies use) so headless accelerate+steer
	## can finish without path-snapping or accept_test_mode.
	var elevated := track_id in ELEVATED_COURSE_IDS
	if elevated:
		follower.set("look_ahead", 8.0)
		follower.set("magnet_strength", 0.08)
	else:
		follower.set("look_ahead", 5.5)
		follower.set("magnet_strength", 0.0)
	return follower


func _sample_driver(
	track_id: String,
	elapsed_msec: int,
	wall_delta: float,
	player: Node,
	follower: Node,
	lap_manager: Node,
	race_manager: Node,
	results: Node,
	input: Node
) -> Dictionary:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var hspeed := 0.0
	var grounded := false
	var movement := false
	var slides := 0
	if player is CharacterBody3D:
		var body := player as CharacterBody3D
		pos = body.global_position
		vel = body.velocity
		grounded = body.is_on_floor()
		slides = body.get_slide_collision_count()
		if "horizontal_speed" in body:
			hspeed = float(body.horizontal_speed)
		if "movement_enabled" in body:
			movement = bool(body.movement_enabled)
	var steer := 0.0
	var accelerate := Input.is_action_pressed("accelerate")
	if input != null:
		if input.has_method("get_steer"):
			steer = float(input.get_steer())
		if input.has_method("is_accelerating"):
			accelerate = bool(input.is_accelerating())
	var follower_progress := 0.0
	var closest := 0.0
	var gap := 0.0
	var lateral := 0.0
	if follower != null and follower.has_method("measure_course_progress") and player is Node3D:
		var measured: Dictionary = follower.measure_course_progress(player)
		follower_progress = float(measured.get("follower_progress", 0.0))
		closest = float(measured.get("closest_offset", 0.0))
		gap = float(measured.get("progress_gap", 0.0))
		lateral = float(measured.get("lateral", 0.0))
	var reacquired := false
	if follower != null and "last_reacquired" in follower:
		reacquired = bool(follower.last_reacquired)
	var lap := 0
	var next_cp := -1
	if lap_manager != null and is_instance_valid(player):
		if lap_manager.has_method("get_lap"):
			lap = int(lap_manager.get_lap(player))
		if lap_manager.has_method("get_next_checkpoint"):
			next_cp = int(lap_manager.get_next_checkpoint(player))
	var race_state := -1
	if race_manager != null and is_instance_valid(race_manager):
		race_state = int(race_manager.get("state"))
	var results_visible := false
	if results != null:
		var panel := results.get_node_or_null("Panel")
		if panel != null:
			results_visible = bool(panel.get("visible"))
	print(
		"DRIVER_SAMPLE track=%s t_ms=%d pos=%.2f,%.2f,%.2f vel=%.2f,%.2f,%.2f hspeed=%.3f grounded=%s movement=%s phys_delta=%.4f wall_delta=%.4f accel=%s steer=%.3f follower_progress=%.2f closest=%.2f gap=%.2f lateral=%.2f slides=%d lap=%d next_cp=%d race_state=%d results=%s reacquired=%s" % [
			track_id,
			elapsed_msec,
			pos.x, pos.y, pos.z,
			vel.x, vel.y, vel.z,
			hspeed,
			str(grounded).to_lower(),
			str(movement).to_lower(),
			1.0 / float(Engine.get_physics_ticks_per_second()),
			wall_delta,
			str(accelerate).to_lower(),
			steer,
			follower_progress,
			closest,
			gap,
			lateral,
			slides,
			lap,
			next_cp,
			race_state,
			str(results_visible).to_lower(),
			str(reacquired).to_lower(),
		]
	)
	return {"progress_gap": gap, "lateral": lateral, "hspeed": hspeed, "reacquired": reacquired}


func _hold_gameplay_input(input: Node, follower: Node, player: Node, delta: float) -> void:
	var accelerate := true
	var steer := 0.0
	if follower != null and player is CharacterBody3D and follower.has_method("get_steer_and_accel"):
		# The follower lifts any body below y=0.2 onto the path. A grounded
		# capsule origin sits near y=0, so that lift fires before physics and
		# the racer never stays on the floor. Throttle only builds speed there.
		# player is typed as Node, so assigning global_position.y edits a copy.
		# Course progress uses the physics tick inside the follower. `delta`
		# remains the wall gap and is not course distance.
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
