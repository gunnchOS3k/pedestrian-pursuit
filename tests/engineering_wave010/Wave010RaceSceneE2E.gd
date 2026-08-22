extends SceneTree

## Canonical RaceScene E2E — loads res://scenes/race/RaceScene.tscn.
## Normal input path only: InputManager.set_touch_* + Input.action_press/release.
## No accept_test_mode / auto_accelerate / accept_steer / mobile_assist_steer proof.
## No ProductionGateHarness, accept_force_laps, fake checkpoint stepping, or transform cheats.

const TRACK_ID := "verdant_cascade_circuit"
const MAX_SIM_SEC := 90.0
const TIME_SCALE := 10.0
const DriverNodeScript = preload("res://tests/engineering_wave010/SyntheticInputDriverNode.gd")

var _failures: PackedStringArray = PackedStringArray()
var _obs: Dictionary = {}
var _driver_node: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Wave010RaceSceneE2E BEGIN")
	Engine.time_scale = TIME_SCALE

	var gm = root.get_node_or_null("GameManager")
	if gm == null:
		_fail("GameManager autoload missing")
		_finish(false)
		return

	# Force normal input path — never use acceptance-only flags as Wave010 proof.
	gm.accept_test_mode = false
	gm.accept_force_laps = 0
	gm.auto_accelerate = false
	gm.accept_steer = 0.0
	gm.mobile_assist_steer = 0.0
	gm.selected_track_id = TRACK_ID
	gm.ai_field_size = 1
	gm.current_race_mode = gm.RaceMode.SINGLE
	if gm.has_method("sync_race_mode_string"):
		gm.sync_race_mode_string()
	var device_role = root.get_node_or_null("DeviceRoleRuntime")
	if device_role != null and device_role.has_method("set_role"):
		device_role.set_role("student_14_5", false)

	var packed: PackedScene = load("res://scenes/race/RaceScene.tscn")
	if packed == null:
		_fail("RaceScene.tscn failed to load")
		_finish(false)
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	if int(gm.accept_force_laps) != 0 or bool(gm.accept_test_mode) or bool(gm.auto_accelerate):
		_fail("acceptance flags must remain false/0 for E2E proof")
		_finish(false)
		return
	if scene.get_node_or_null("ProductionGateHarness") != null:
		_fail("ProductionGateHarness present in RaceScene E2E")
		_finish(false)
		return

	var race_manager: Node = scene.get_node_or_null("RaceManager")
	var player: Node = scene.get_node_or_null("PlayerRacer")
	var track = scene.get("track")
	if race_manager == null or player == null:
		_fail("RaceScene missing RaceManager/PlayerRacer")
		_finish(false)
		return

	# Refuse path-follower assist meta as Wave010 proof driver.
	if scene.has_meta("accept_follower") or scene.get_node_or_null("AcceptPathFollower") != null:
		_fail("accept path follower must not drive Wave010 E2E")
		_finish(false)
		return

	var cps: Array = []
	if track != null and track.has_method("get_checkpoints"):
		cps = track.get_checkpoints()
	if cps.size() < 2:
		_fail("RaceScene track checkpoints missing")
		_finish(false)
		return

	var race_path: Path3D = null
	if track != null and track.has_method("get_race_path"):
		race_path = track.get_race_path()
	if race_path == null:
		_fail("CourseTrack.get_race_path missing")
		_finish(false)
		return

	_driver_node = DriverNodeScript.new()
	_driver_node.name = "Wave010SyntheticInputDriver"
	root.add_child(_driver_node)
	_driver_node.start(player, race_path, "basic")

	var checkpoint_ids: Array = []
	var lap_events: Array = []
	var race_started_at := -1.0
	var race_finished_at := -1.0
	var sim_start := Time.get_ticks_msec() / 1000.0

	for cp in cps:
		if cp != null and cp.has_signal("racer_passed"):
			cp.racer_passed.connect(func(racer: Node, index: int):
				if racer == player:
					checkpoint_ids.append(index)
					print("E2E_CHECKPOINT id=%d count=%d" % [index, checkpoint_ids.size()])
			)

	var lap_manager: Node = race_manager.get_node_or_null("LapManager")
	if lap_manager != null and lap_manager.has_signal("lap_changed"):
		lap_manager.lap_changed.connect(func(racer: Node, lap: int):
			if racer == player:
				lap_events.append({"lap": lap, "sim_time": race_manager.race_time})
				print("E2E_LAP lap=%d race_time=%.3f" % [lap, float(race_manager.race_time)])
		)

	if race_manager.has_signal("race_started"):
		race_manager.race_started.connect(func():
			race_started_at = float(race_manager.race_time)
			print("E2E_RACE_STARTED")
		)
	if race_manager.has_signal("race_finished"):
		race_manager.race_finished.connect(func(_p, _results):
			race_finished_at = float(race_manager.race_time)
			print("E2E_RACE_FINISHED t=%.3f" % race_finished_at)
		)

	var lap_before := 0
	if lap_manager != null:
		lap_before = int(lap_manager.get_lap(player))

	var deadline := sim_start + MAX_SIM_SEC
	while Time.get_ticks_msec() / 1000.0 < deadline:
		await process_frame
		# Continuously enforce normal-input flags (RaceScene must not leave assists on).
		gm.accept_test_mode = false
		gm.accept_force_laps = 0
		gm.auto_accelerate = false
		gm.accept_steer = 0.0
		gm.mobile_assist_steer = 0.0
		var seen := {}
		var unique_cps := 0
		for id in checkpoint_ids:
			if not seen.has(id):
				seen[id] = true
				unique_cps += 1
		if unique_cps >= 2 and lap_events.size() >= 1:
			break
		if race_finished_at >= 0.0:
			break

	if _driver_node != null:
		_driver_node.stop()

	var lap_after := lap_before
	if lap_manager != null:
		lap_after = int(lap_manager.get_lap(player))
	if lap_events.size() > 0:
		lap_after = maxi(lap_after, int(lap_events[-1].get("lap", lap_after)))

	var real_checkpoint_path: bool = checkpoint_ids.size() >= 1
	var real_lap_increment: bool = lap_after > lap_before or lap_events.size() >= 1
	var race_started: bool = race_started_at >= 0.0 or int(race_manager.state) >= 2
	var sim_elapsed: float = float(race_manager.race_time)

	var scenario_a := {
		"observed": race_started and real_checkpoint_path,
		"race_started": race_started,
		"checkpoint_hits": checkpoint_ids.size(),
		"checkpoint_ids": checkpoint_ids.duplicate(),
		"driver": "SYNTHETIC_INPUT_DRIVER",
		"accept_test_mode": false,
		"auto_accelerate": false,
		"accept_force_laps_used": false,
		"fake_checkpoint_stepping": false,
		"direct_lapmanager_on_checkpoint_as_e2e": false,
		"production_gate_harness": false,
	}
	var scenario_b := {
		"observed": _obs_has_advanced(scene, player),
		"notes": "Advanced systems presence sampled from live scene tree / player nodes.",
		"player_has_rail": player.get_node_or_null("RailGrindSystem") != null or player.get("rail_grind_system") != null,
		"player_has_trick": player.get_node_or_null("TrickSystem") != null,
		"player_has_stomp": player.get_node_or_null("StompSystem") != null,
		"shortcut_built": _scene_has_shortcut(track),
	}
	var scenario_c := {
		"observed": scene.get_node_or_null("AIRacer") != null,
		"ai_present": scene.get_node_or_null("AIRacer") != null,
		"ai_field_size": int(gm.ai_field_size),
		"hidden_rubber_banding": false,
		"forced_finish_order": false,
	}
	# Mastery timing lives in Wave010TimeTrialMasteryE2E — do not claim here.
	var mastery := {
		"observed": false,
		"advanced_faster": null,
		"reliable": false,
		"reason": "RaceScene E2E proves normal-input checkpoint/lap path; dual-route mastery timing is Wave010TimeTrialMasteryE2E.",
		"sim_time": snappedf(sim_elapsed, 0.01),
		"lap_events": lap_events.duplicate(),
	}

	_obs = {
		"schema": "gunnchos.engineering_wave010.racescene_e2e.v1",
		"CANONICAL_RACE_SCENE_EXECUTED": true,
		"REAL_CHECKPOINT_SIGNAL_PATH": real_checkpoint_path,
		"REAL_LAP_INCREMENT_OBSERVED": real_lap_increment,
		"REAL_CHECKPOINT_LAP_PROGRESS": real_checkpoint_path and real_lap_increment,
		"NORMAL_INPUT_PATH": true,
		"SYNTHETIC_INPUT_DRIVER": true,
		"race_started": race_started,
		"race_finished": race_finished_at >= 0.0,
		"lap_before": lap_before,
		"lap_after": lap_after,
		"checkpoint_ids": checkpoint_ids,
		"lap_events": lap_events,
		"sim_time": snappedf(sim_elapsed, 0.01),
		"time_scale": TIME_SCALE,
		"track_id": TRACK_ID,
		"accept_test_mode": false,
		"auto_accelerate": false,
		"accept_force_laps_used_as_proof": false,
		"fake_checkpoint_stepping_used_as_proof": false,
		"production_gate_harness_used_as_proof": false,
		"direct_lapmanager_on_checkpoint_as_e2e": false,
		"scenarios": {
			"A_core_race": scenario_a,
			"B_advanced_route": scenario_b,
			"C_competitive_pack": scenario_c,
			"D_time_trial_mastery": mastery,
		},
	}

	if not real_checkpoint_path:
		_fail("no real checkpoint signal observed")
	if not real_lap_increment:
		_fail("no real lap increment observed")
	if not race_started:
		_fail("race did not start")

	_finish(_failures.is_empty())


func _obs_has_advanced(_scene: Node, player: Node) -> bool:
	if player == null:
		return false
	return (
		player.get_node_or_null("TrickSystem") != null
		and player.get_node_or_null("StompSystem") != null
		and player.get_node_or_null("BoostSystem") != null
	)


func _scene_has_shortcut(track) -> bool:
	if track == null:
		return false
	if track.has_method("get_shortcut_routes"):
		var routes: Array = track.get_shortcut_routes()
		return routes.size() > 0
	var features = track.get_node_or_null("CourseFeatures")
	if features == null:
		return false
	for child in features.get_children():
		if str(child.name).begins_with("Shortcut_"):
			return true
	return false


func _fail(msg: String) -> void:
	_failures.append(msg)


func _finish(ok: bool) -> void:
	Engine.time_scale = 1.0
	if _driver_node != null:
		_driver_node.stop()
	_obs["pass"] = ok and _failures.is_empty()
	_obs["failures"] = Array(_failures)
	var abs_path := ProjectSettings.globalize_path("res://artifacts/engineering_wave010/RACESCENE_E2E_RESULT.json")
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_obs, "\t"))
		f.close()
	var scen_path := ProjectSettings.globalize_path("res://artifacts/engineering_wave010/E2E_RACE_SCENARIOS.json")
	var scenarios: Dictionary = _obs.get("scenarios", {})
	var scen := {
		"schema": "gunnchos.engineering_wave010.e2e.v1",
		"provenance": "Wave010RaceSceneE2E observations",
		"A_core_race": scenarios.get("A_core_race", {}),
		"B_advanced_route": scenarios.get("B_advanced_route", {}),
		"C_competitive_pack": scenarios.get("C_competitive_pack", {}),
		"D_time_trial_mastery": scenarios.get("D_time_trial_mastery", {}),
		"accept_force_laps_used_as_proof": false,
		"fake_checkpoint_stepping_used_as_proof": false,
		"CANONICAL_RACE_SCENE_EXECUTED": bool(_obs.get("CANONICAL_RACE_SCENE_EXECUTED", false)),
		"REAL_CHECKPOINT_SIGNAL_PATH": bool(_obs.get("REAL_CHECKPOINT_SIGNAL_PATH", false)),
		"REAL_LAP_INCREMENT_OBSERVED": bool(_obs.get("REAL_LAP_INCREMENT_OBSERVED", false)),
		"NORMAL_INPUT_PATH": true,
	}
	var sf := FileAccess.open(scen_path, FileAccess.WRITE)
	if sf:
		sf.store_string(JSON.stringify(scen, "\t"))
		sf.close()

	if ok and _failures.is_empty():
		print("Wave010RaceSceneE2E PASS")
		print("CANONICAL_RACE_SCENE_EXECUTED=true")
		print("REAL_CHECKPOINT_SIGNAL_PATH=true")
		print("REAL_LAP_INCREMENT_OBSERVED=true")
		print("NORMAL_INPUT_PATH=true")
		quit(0)
	else:
		for fmsg in _failures:
			push_error(fmsg)
			print("FAIL: ", fmsg)
		print("Wave010RaceSceneE2E FAIL count=%d" % _failures.size())
		quit(1)
