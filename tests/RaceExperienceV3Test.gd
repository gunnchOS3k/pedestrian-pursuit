extends SceneTree

## V3 race-experience digital gates. Human fun stays false.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_test_hud_hierarchy(failures)
	_test_start_go(failures)
	_test_draft_phases(failures)
	_test_boost_presentation(failures)
	_test_comfort_profiles(failures)
	_test_camera_contract_untouched(failures)
	_test_audio_cues(failures)
	if failures.is_empty():
		print("HUD_HIERARCHY_PASS=true")
		print("START_SEQUENCE_GO_PASS=true")
		print("DRAFT_PHASE_PASS=true")
		print("BOOST_PRESENTATION_START_STOP_PASS=true")
		print("COMFORT_DYNAMIC_REDUCED_MOTION_PASS=true")
		print("CAMERA_CONTRACT_PRESERVED_PASS=true")
		print("OWNER_RACE_FEEL_PASS=false")
		print("OWNER_DRAFTING_FEEL_PASS=false")
		print("OWNER_BOOST_FEEL_PASS=false")
		print("RaceExperienceV3Test PASS")
		quit(0)
	else:
		for row in failures:
			push_error(row)
		print("RaceExperienceV3Test FAIL count=%d" % failures.size())
		quit(1)


func _test_hud_hierarchy(failures: PackedStringArray) -> void:
	var director := Node.new()
	director.set_script(load("res://scripts/gamefeel/RaceExperienceDirector.gd"))
	root.add_child(director)
	director.setup(null, null, null, {"id": "verdant_cascade_circuit", "display_name": "Verdant Cascade Circuit"})
	var snap: Dictionary = director.snapshot()
	var hier: Dictionary = snap.get("hierarchy", {})
	var primary: Array = hier.get("primary", [])
	var hidden: Array = hier.get("hidden_normal", [])
	if not ("position" in primary and "lap_progress" in primary and "shortcut_cue" in primary):
		failures.append("HUD primary hierarchy missing required facts")
	if not ("footwear" in hidden and "debug_metrics" in hidden):
		failures.append("HUD still exposes telemetry-heavy fields as primary")
	director.free()


func _test_start_go(failures: PackedStringArray) -> void:
	var mgr := Node.new()
	mgr.set_script(load("res://scripts/race/RaceManager.gd"))
	var lap := Node.new()
	lap.name = "LapManager"
	lap.set_script(load("res://scripts/race/LapManager.gd"))
	var tracker := Node.new()
	tracker.name = "PositionTracker"
	tracker.set_script(load("res://scripts/race/PositionTracker.gd"))
	mgr.add_child(lap)
	mgr.add_child(tracker)
	root.add_child(mgr)
	var ticks: PackedStringArray = []
	mgr.countdown_tick.connect(func(v): ticks.append(str(v)))
	mgr.begin_countdown()
	await create_timer(0.05).timeout
	if ticks.is_empty() or str(ticks[0]) != "3":
		failures.append("authored countdown did not start on 3")
	# Failsafe GO token must be GO, not GO!
	mgr.state = 1
	mgr._countdown_timer = 0.0
	mgr._process_countdown(0.016)
	if not ("GO" in ticks) or ("GO!" in ticks):
		failures.append("GO token must be GO (got %s)" % ",".join(ticks))
	if int(mgr.state) != 2:
		failures.append("GO did not release race state")
	mgr.free()


func _test_draft_phases(failures: PackedStringArray) -> void:
	var draft := Node.new()
	draft.set_script(load("res://scripts/player/DraftingSystem.gd"))
	root.add_child(draft)
	var seen: PackedStringArray = []
	draft.draft_phase_changed.connect(func(phase, _s): seen.append(str(phase)))
	draft._set_phase("entering")
	draft._set_phase("building")
	draft._set_phase("active")
	draft._set_phase("leaving")
	draft._set_phase("none")
	if seen != PackedStringArray(["entering", "building", "active", "leaving", "none"]):
		failures.append("draft phases incomplete: %s" % ",".join(seen))
	if not is_equal_approx(float(draft.draft_multiplier), 1.08):
		failures.append("draft power changed without evidence")
	draft.free()


func _test_boost_presentation(failures: PackedStringArray) -> void:
	var boost := Node.new()
	boost.set_script(load("res://scripts/player/BoostSystem.gd"))
	root.add_child(boost)
	var fx := Node.new()
	fx.set_script(load("res://scripts/gamefeel/BoostFeedback.gd"))
	root.add_child(fx)
	var started := [false]
	var stopped := [false]
	fx.presentation_started.connect(func(): started[0] = true)
	fx.presentation_stopped.connect(func(): stopped[0] = true)
	boost.boost_activated.connect(func(_m, _d, _s): fx.set_active(true, false))
	boost.boost_ended.connect(func(): fx.set_active(false, false))
	boost.current_boost = 100.0
	if not boost.try_consume_boost():
		failures.append("boost consume failed")
	if not bool(started[0]) or not bool(fx.presenting):
		failures.append("boost presentation did not start with boost state")
	boost._active_time = 0.001
	boost.tick(0.02)
	if not bool(stopped[0]) or bool(fx.presenting):
		failures.append("boost presentation did not stop with boost end")
	boost.free()
	fx.free()


func _test_comfort_profiles(failures: PackedStringArray) -> void:
	var layer := CanvasLayer.new()
	layer.set_script(load("res://scripts/gamefeel/SpeedPresentationLayer.gd"))
	root.add_child(layer)
	layer.apply(1.0, true, 1)
	if not bool(layer.presenting):
		failures.append("dynamic profile should show speed presentation")
	layer.apply(1.0, true, 2)
	if bool(layer.presenting):
		failures.append("reduced motion must suppress speed-line motion")
	layer.free()


func _test_camera_contract_untouched(failures: PackedStringArray) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player/CameraRig.gd")
	if src.find("randf(") >= 0 or src.find("randf_range") >= 0:
		failures.append("CameraRig restored randf shake")
	if src.find(".look_at(") >= 0:
		failures.append("CameraRig restored unsmoothed look_at")
	var dir := preload("res://scripts/player/CameraDirection.gd")
	var yaw: float = dir.yaw_for_minus_z_forward(Vector3(0, 0, -1))
	if absf(yaw) > 0.01:
		failures.append("minus-Z yaw contract drifted")


func _test_audio_cues(failures: PackedStringArray) -> void:
	var audio := root.get_node_or_null("AudioDirector")
	if audio == null:
		audio = Node.new()
		audio.set_script(load("res://scripts/audio/AudioDirector.gd"))
		root.add_child(audio)
	if not audio.has_method("play_race_cue") or not audio.has_method("cue_caption"):
		failures.append("audio director missing race cues")
		return
	if str(audio.cue_caption("go")) != "GO" or str(audio.cue_caption("final_lap")) != "FINAL LAP":
		failures.append("critical cue captions missing")
	var desc: Dictionary = audio.describe()
	if not bool(desc.get("licensed_or_procedural_only", false)):
		failures.append("audio audit must stay licensed/procedural")
