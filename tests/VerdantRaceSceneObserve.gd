extends SceneTree

## Headless observer for the one shared race scene on Verdant Cascade Circuit.
## Records whether a lap, a non-start checkpoint, and the results screen actually run.
## Does not accept the course and does not claim a device run.
## Exits nonzero when the scene cannot be entered.

const TRACK_ID := "verdant_cascade_circuit"
const DISPLAY_NAME := "Verdant Cascade Circuit"
const ENTER_FRAMES := 180
const OBSERVE_MSEC := 12000


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
	var deadline := Time.get_ticks_msec() + OBSERVE_MSEC
	while Time.get_ticks_msec() < deadline:
		if input != null and input.has_method("set_touch_accelerate"):
			input.set_touch_accelerate(true)
		await physics_frame
		if not is_instance_valid(scene):
			break
		if results != null:
			var panel := results.get_node_or_null("Panel")
			if panel != null and bool(panel.get("visible")):
				observed["results"] = true
		if lap_manager != null and player != null and lap_manager.has_method("get_lap"):
			if int(lap_manager.get_lap(player)) >= 1:
				observed["lap"] = true
	var state_after := -1
	if is_instance_valid(race_manager):
		state_after = int(race_manager.get("state"))
	print("RACE_ENTERED=true")
	print("TRACK_ID=%s" % TRACK_ID)
	print("RACE_STATE=%d" % state_after)
	print("LAP_COMPLETED=%s" % str(bool(observed["lap"])).to_lower())
	print("CHECKPOINT_CROSSED=%s" % str(bool(observed["checkpoint"])).to_lower())
	print("RESULTS_PATH=%s" % str(bool(observed["results"])).to_lower())
	print("COURSE_ACCEPTED=false")
	print("DEVICE_RUN=false")
	print("RACE_SCENE_OBSERVE_ENTERED %s" % TRACK_ID)
	quit(0)


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
