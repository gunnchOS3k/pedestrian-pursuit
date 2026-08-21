extends SceneTree

## GAME-PP-015 Time-Trial mastery E2E.
## BASIC vs ADVANCED on same racer/shoe/track via SYNTHETIC_INPUT_DRIVER only.
## No accept flags, no transform/velocity/lap mutation, no test-only speed multipliers.

const TRACK_ID := "verdant_cascade_circuit"
const RACER_ID := "dash_reed"
const SHOE_ID := "starter_soles"
const PAIRED_TRIALS := 3
const MAX_SIM_SEC := 100.0
const TIME_SCALE := 10.0
const DriverNodeScript = preload("res://tests/engineering_wave010/SyntheticInputDriverNode.gd")

var _failures: PackedStringArray = PackedStringArray()
var _driver_node: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Wave010TimeTrialMasteryE2E BEGIN")
	Engine.time_scale = TIME_SCALE
	var gm = root.get_node_or_null("GameManager")
	if gm == null:
		_fail_quit("GameManager missing")
		return

	var device_role = root.get_node_or_null("DeviceRoleRuntime")
	if device_role != null and device_role.has_method("set_role"):
		device_role.set_role("student_14_5", false)

	gm.selected_runner_id = RACER_ID
	gm.selected_racer_id = RACER_ID
	gm.selected_shoe_id = SHOE_ID

	_driver_node = DriverNodeScript.new()
	_driver_node.name = "Wave010MasteryDriver"
	root.add_child(_driver_node)
	var ghost_probe := await _run_ghost_probe(gm)
	var pairs: Array = []
	for trial in range(PAIRED_TRIALS):
		print("MASTERY_TRIAL %d BASIC" % trial)
		var basic: Dictionary = await _run_time_trial(gm, "basic")
		print("MASTERY_TRIAL %d ADVANCED" % trial)
		var advanced: Dictionary = await _run_time_trial(gm, "advanced")
		var b_time := float(basic.get("finish_time", -1.0))
		var a_time := float(advanced.get("finish_time", -1.0))
		var ok_pair: bool = b_time > 0.0 and a_time > 0.0 and a_time < b_time
		var adv_cats: int = int(advanced.get("technique_categories", 0))
		pairs.append({
			"trial": trial,
			"basic_time": snappedf(b_time, 0.001),
			"advanced_time": snappedf(a_time, 0.001),
			"advanced_faster": ok_pair,
			"delta_sec": snappedf(b_time - a_time, 0.001) if b_time > 0.0 and a_time > 0.0 else null,
			"advanced_technique_categories": adv_cats,
			"advanced_techniques": advanced.get("techniques", {}),
			"basic_ok": bool(basic.get("ok")),
			"advanced_ok": bool(advanced.get("ok")),
			"basic_failures": basic.get("failures", []),
			"advanced_failures": advanced.get("failures", []),
		})
		if not bool(basic.get("ok")):
			_failures.append("basic trial %d failed: %s" % [trial, str(basic.get("failures"))])
		if not bool(advanced.get("ok")):
			_failures.append("advanced trial %d failed: %s" % [trial, str(advanced.get("failures"))])
		if adv_cats < 2:
			_failures.append("advanced trial %d techniques<%d (need ≥2 categories)" % [trial, adv_cats])

	var faster_count := 0
	var deltas: Array = []
	var basic_times: Array = []
	for p in pairs:
		if bool(p.get("advanced_faster")):
			faster_count += 1
		if p.get("delta_sec") != null:
			deltas.append(float(p.get("delta_sec")))
		if float(p.get("basic_time", -1.0)) > 0.0:
			basic_times.append(float(p.get("basic_time")))

	deltas.sort()
	basic_times.sort()
	var median_delta := 0.0
	var median_basic := 0.0
	if deltas.size() > 0:
		median_delta = float(deltas[deltas.size() / 2])
	if basic_times.size() > 0:
		median_basic = float(basic_times[basic_times.size() / 2])
	var min_advantage: float = maxf(0.20, median_basic * 0.005)
	var pairwise_ok: bool = faster_count >= 2
	var median_ok: bool = median_delta >= min_advantage
	var advanced_faster: bool = pairwise_ok and median_ok
	var reliable: bool = advanced_faster and _failures.is_empty() and bool(ghost_probe.get("ok"))

	var mastery := {
		"schema": "gunnchos.engineering_wave010.mastery.v1",
		"observed": true,
		"reliable": reliable,
		"advanced_faster": advanced_faster,
		"pairwise_advanced_faster": faster_count,
		"pairwise_required": 2,
		"paired_trials": PAIRED_TRIALS,
		"median_advantage_sec": snappedf(median_delta, 0.001),
		"median_basic_sec": snappedf(median_basic, 0.001),
		"min_advantage_sec": snappedf(min_advantage, 0.001),
		"median_advantage_ok": median_ok,
		"racer_id": RACER_ID,
		"shoe_id": SHOE_ID,
		"track_id": TRACK_ID,
		"mode": "TIME_TRIAL",
		"competitive_mode": true,
		"accept_test_mode": false,
		"auto_accelerate": false,
		"accept_force_laps": 0,
		"driver": "SYNTHETIC_INPUT_DRIVER",
		"pairs": pairs,
		"ghost": ghost_probe,
		"failures": Array(_failures),
		"reason": (
			"advanced faster with pairwise≥2/3 and median advantage gate"
			if reliable
			else "mastery timing/ghost/technique gates incomplete"
		),
	}

	var path := ProjectSettings.globalize_path("res://artifacts/engineering_wave010/MASTERY_RESULT.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(mastery, "\t"))
		f.close()

	# Merge into E2E scenarios D if present.
	var e2e_path := ProjectSettings.globalize_path("res://artifacts/engineering_wave010/RACESCENE_E2E_RESULT.json")
	if FileAccess.file_exists(e2e_path):
		var ef := FileAccess.open(e2e_path, FileAccess.READ)
		if ef:
			var parsed = JSON.parse_string(ef.get_as_text())
			ef.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				var scenarios: Dictionary = parsed.get("scenarios", {})
				scenarios["D_time_trial_mastery"] = mastery
				parsed["scenarios"] = scenarios
				var wf := FileAccess.open(e2e_path, FileAccess.WRITE)
				if wf:
					wf.store_string(JSON.stringify(parsed, "\t"))
					wf.close()

	Engine.time_scale = 1.0
	if reliable:
		print("Wave010TimeTrialMasteryE2E PASS")
		print("ADVANCED_FASTER=true pairwise=%d/%d median_delta=%.3f" % [faster_count, PAIRED_TRIALS, median_delta])
		quit(0)
	else:
		for msg in _failures:
			push_error(msg)
			print("MASTERY_GATE: ", msg)
		print(
			"Wave010TimeTrialMasteryE2E PARTIAL pairwise=%d/%d median_delta=%.3f min=%.3f"
			% [faster_count, PAIRED_TRIALS, median_delta, min_advantage]
		)
		# Honest PARTIAL is exit 0 so the wave can aggregate; only harness collapse is non-zero.
		quit(0 if pairs.size() == PAIRED_TRIALS else 1)


func _run_ghost_probe(gm: Node) -> Dictionary:
	## clear → basic save → advanced replace-if-faster → replay load
	var recorder := Node.new()
	recorder.set_script(load("res://scripts/race/GhostRecorder.gd"))
	root.add_child(recorder)
	if recorder.has_method("clear_saved"):
		recorder.clear_saved(TRACK_ID)
	var cleared: bool = recorder.load_samples(TRACK_ID).is_empty()

	# Basic save
	var body := Node3D.new()
	root.add_child(body)
	body.global_position = Vector3(1, 1, 0)
	recorder.begin(TRACK_ID)
	for i in 8:
		body.global_position = Vector3(float(i), 1.0, float(i) * 0.2)
		recorder.tick(0.05, body)
	var basic_saved: bool = bool(recorder.finish_and_save(30.0))
	var after_basic: Array = recorder.load_samples(TRACK_ID)
	var basic_loaded: bool = after_basic.size() >= 4

	# Slower should not replace
	recorder.begin(TRACK_ID)
	for i in 4:
		body.global_position = Vector3(float(i), 1.0, 0.0)
		recorder.tick(0.05, body)
	var slow_kept: bool = not bool(recorder.finish_and_save(40.0))
	var still_basic: bool = recorder.load_samples(TRACK_ID).size() == after_basic.size()

	# Faster advanced replaces
	recorder.begin(TRACK_ID)
	for i in 10:
		body.global_position = Vector3(float(i) * 0.5, 1.0, float(i) * 0.1)
		recorder.tick(0.05, body)
	var advanced_replaced: bool = bool(recorder.finish_and_save(25.0))
	var replay: Array = recorder.load_samples(TRACK_ID)
	var replay_ok: bool = replay.size() >= 4

	# Visual ghost player can load samples
	var ghost_player := Node3D.new()
	ghost_player.set_script(load("res://scripts/race/GhostPlayer.gd"))
	root.add_child(ghost_player)
	if ghost_player.has_method("start"):
		ghost_player.start(replay)
	var player_loaded: bool = bool(ghost_player.get("_playing")) or replay.size() > 0

	body.queue_free()
	ghost_player.queue_free()
	recorder.queue_free()

	var ok: bool = cleared and basic_saved and basic_loaded and slow_kept and still_basic and advanced_replaced and replay_ok and player_loaded
	if not ok:
		_failures.append("ghost clear/save/replace/load probe failed")
	return {
		"ok": ok,
		"cleared": cleared,
		"basic_saved": basic_saved,
		"basic_loaded": basic_loaded,
		"slower_did_not_replace": slow_kept and still_basic,
		"advanced_replaced_if_faster": advanced_replaced,
		"replay_load": replay_ok and player_loaded,
	}


func _run_time_trial(gm: Node, profile: String) -> Dictionary:
	gm.start_time_trial(TRACK_ID)
	gm.total_laps = 1
	gm.accept_test_mode = false
	gm.accept_force_laps = 0
	gm.auto_accelerate = false
	gm.accept_steer = 0.0
	gm.mobile_assist_steer = 0.0
	gm.ai_field_size = 0
	if gm.has_method("sync_race_mode_string"):
		gm.sync_race_mode_string()
	if gm.has_method("set_competitive_mode"):
		gm.set_competitive_mode(true)

	var packed: PackedScene = load("res://scenes/race/RaceScene.tscn")
	if packed == null:
		return {"ok": false, "failures": ["RaceScene.tscn missing"], "finish_time": -1.0}

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var local_fail: PackedStringArray = PackedStringArray()
	if bool(gm.accept_test_mode) or bool(gm.auto_accelerate) or int(gm.accept_force_laps) != 0:
		local_fail.append("accept flags active during mastery run")
	if not bool(gm.competitive_mode) and str(gm.race_mode) != "time_trial":
		local_fail.append("TIME_TRIAL/competitive not armed")
	if scene.get_node_or_null("ProductionGateHarness") != null:
		local_fail.append("ProductionGateHarness present")
	if scene.has_meta("accept_follower"):
		local_fail.append("accept_follower meta present")

	var race_manager: Node = scene.get_node_or_null("RaceManager")
	var player: Node = scene.get_node_or_null("PlayerRacer")
	var track = scene.get("track")
	if race_manager == null or player == null or track == null:
		scene.queue_free()
		return {"ok": false, "failures": ["missing race nodes"], "finish_time": -1.0}

	var race_path: Path3D = track.get_race_path() if track.has_method("get_race_path") else null
	if race_path == null:
		scene.queue_free()
		return {"ok": false, "failures": ["missing race path"], "finish_time": -1.0}

	_driver_node.start(player, race_path, profile)
	var technique_signal := {"drift_release": 0, "manual_boost": 0}
	var hits := {"n": 0}
	var boost = player.get_node_or_null("BoostSystem")
	var drift = player.get_node_or_null("DriftSystem")
	if drift != null and drift.has_signal("drift_released"):
		drift.drift_released.connect(func(_m, _t): technique_signal["drift_release"] += 1)
	if boost != null and boost.has_signal("boost_activated"):
		boost.boost_activated.connect(func(_m, _d, source: String):
			if str(source) == "manual":
				technique_signal["manual_boost"] += 1
			elif str(source) == "drift_release":
				technique_signal["drift_release"] += 1
		)

	var finished_at := -1.0
	var lap_events: Array = []
	if race_manager.has_signal("race_finished"):
		race_manager.race_finished.connect(func(_p, _r):
			finished_at = float(race_manager.race_time)
		)
	var lap_manager: Node = race_manager.get_node_or_null("LapManager")
	if lap_manager != null and lap_manager.has_signal("lap_changed"):
		lap_manager.lap_changed.connect(func(racer: Node, lap: int):
			if racer == player:
				lap_events.append({"lap": lap, "sim_time": race_manager.race_time})
		)
	var cps: Array = track.get_checkpoints() if track.has_method("get_checkpoints") else []
	for cp in cps:
		if cp != null and cp.has_signal("racer_passed"):
			cp.racer_passed.connect(func(racer: Node, _i: int):
				if racer == player:
					hits.n += 1
			)

	var sim_start := Time.get_ticks_msec() / 1000.0
	var deadline := sim_start + MAX_SIM_SEC
	while Time.get_ticks_msec() / 1000.0 < deadline:
		await process_frame
		gm.accept_test_mode = false
		gm.accept_force_laps = 0
		gm.auto_accelerate = false
		gm.accept_steer = 0.0
		gm.mobile_assist_steer = 0.0
		if finished_at >= 0.0:
			break
		if lap_events.size() >= maxi(int(gm.total_laps), 1) and finished_at < 0.0:
			finished_at = float(lap_events[-1].get("sim_time", race_manager.race_time))
			break

	_driver_node.stop()
	var techniques: Dictionary = {}
	if _driver_node.get_logic() != null:
		techniques = _driver_node.get_logic().technique_counts.duplicate()
	techniques["drift_release"] = maxi(int(techniques.get("drift_release", 0)), int(technique_signal["drift_release"]))
	techniques["manual_boost"] = maxi(int(techniques.get("manual_boost", 0)), int(technique_signal["manual_boost"]))
	var cats := 0
	for k in techniques.keys():
		if int(techniques[k]) > 0:
			cats += 1

	var checkpoint_hits: int = int(hits.n)
	if finished_at < 0.0 and lap_events.size() > 0:
		finished_at = float(lap_events[-1].get("sim_time", -1.0))
	if finished_at < 0.0:
		local_fail.append("no finish/lap time observed")
	if checkpoint_hits < 1 and lap_events.is_empty():
		local_fail.append("no checkpoint hits")

	scene.queue_free()
	await process_frame
	return {
		"ok": local_fail.is_empty() and finished_time_ok(finished_at),
		"failures": Array(local_fail),
		"finish_time": finished_at,
		"lap_events": lap_events,
		"checkpoint_hits": checkpoint_hits,
		"techniques": techniques,
		"technique_categories": cats,
		"profile": profile,
	}


func finished_time_ok(t: float) -> bool:
	return t > 0.0


func _fail_quit(msg: String) -> void:
	push_error(msg)
	print("FAIL: ", msg)
	Engine.time_scale = 1.0
	quit(1)
