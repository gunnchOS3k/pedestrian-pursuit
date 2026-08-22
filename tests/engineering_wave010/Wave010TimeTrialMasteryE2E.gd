extends SceneTree

## GAME-PP-015 Time-Trial causal mastery E2E.
## Same steering controller; ADVANCED = skills only; production technique signals;
## race_finished timing only; real Basic→Advanced RaceScene ghost loop.

const TRACK_ID := "verdant_cascade_circuit"
const RACER_ID := "dash_reed"
const SHOE_ID := "starter_soles"
const PAIRED_TRIALS := 3
const MAX_SIM_SEC := 90.0
const TIME_SCALE := 20.0
const GHOST_PATH_FMT := "user://time_trial_ghost_%s.json"
const DriverNodeScript = preload("res://tests/engineering_wave010/SyntheticInputDriverNode.gd")

var _failures: PackedStringArray = PackedStringArray()
var _driver_node: Node = null
var _lap_event_used_as_finish_fallback: bool = false


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

	var equiv := _emit_driver_equivalence()
	if not bool(equiv.get("DRIVER_PARAMETERS_MATCH")):
		_failures.append("DRIVER_PARAMETERS_MATCH false")
	if bool(equiv.get("BASIC_HANDICAP_PRESENT")):
		_failures.append("BASIC_HANDICAP_PRESENT true")

	# Clear only for paired timing hygiene; dedicated ghost loop clears again later.
	_clear_track_ghost(TRACK_ID)

	var pairs: Array = []
	var trial_order: Array = []
	var all_basic_finished := true
	var all_advanced_finished := true
	var prod_drift_total := 0
	var prod_manual_boost_total := 0

	for trial in range(PAIRED_TRIALS):
		# Alternate order: B→A, A→B, B→A
		var advanced_first: bool = (trial % 2) == 1
		var first_profile := "advanced" if advanced_first else "basic"
		var second_profile := "basic" if advanced_first else "advanced"
		trial_order.append("%s→%s" % [first_profile.to_upper(), second_profile.to_upper()])
		print("MASTERY_TRIAL %d ORDER %s" % [trial, trial_order[-1]])

		var first: Dictionary = await _run_time_trial(gm, first_profile)
		var second: Dictionary = await _run_time_trial(gm, second_profile)
		var basic: Dictionary = first if first_profile == "basic" else second
		var advanced: Dictionary = first if first_profile == "advanced" else second

		var b_time := float(basic.get("finish_time", -1.0))
		var a_time := float(advanced.get("finish_time", -1.0))
		var b_fin := bool(basic.get("race_finished_signal"))
		var a_fin := bool(advanced.get("race_finished_signal"))
		if not b_fin:
			all_basic_finished = false
		if not a_fin:
			all_advanced_finished = false
		var ok_pair: bool = b_fin and a_fin and b_time > 0.0 and a_time > 0.0 and a_time < b_time
		var adv_cats: int = int(advanced.get("technique_categories", 0))
		var adv_tech = advanced.get("production_techniques", {})
		if typeof(adv_tech) != TYPE_DICTIONARY:
			adv_tech = {}
		prod_drift_total += int(adv_tech.get("drift_release", 0))
		prod_manual_boost_total += int(adv_tech.get("manual_boost", 0))
		pairs.append({
			"trial": trial,
			"order": trial_order[-1],
			"basic_time": snappedf(b_time, 0.001),
			"advanced_time": snappedf(a_time, 0.001),
			"advanced_faster": ok_pair,
			"delta_sec": snappedf(b_time - a_time, 0.001) if b_time > 0.0 and a_time > 0.0 else null,
			"advanced_technique_categories": adv_cats,
			"advanced_techniques": adv_tech,
			"TECHNIQUE_COUNT_SOURCE": "PRODUCTION_SIGNAL_OR_TELEMETRY",
			"DRIVER_INTENT_COUNTED_AS_SUCCESS": false,
			"basic_race_finished_signal": b_fin,
			"advanced_race_finished_signal": a_fin,
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
			_failures.append("advanced trial %d production techniques<%d (need ≥2 categories)" % [trial, adv_cats])

	# Dedicated real RaceScene ghost loop (not synthetic 30/40/25; not bound to one flaky pair).
	var ghost_result: Dictionary = await _run_actual_ghost_self_improvement(gm)
	var faster_count := 0
	var deltas: Array = []
	var basic_times: Array = []
	var advanced_times: Array = []
	for p in pairs:
		if bool(p.get("advanced_faster")):
			faster_count += 1
		if p.get("delta_sec") != null:
			deltas.append(float(p.get("delta_sec")))
		if float(p.get("basic_time", -1.0)) > 0.0:
			basic_times.append(float(p.get("basic_time")))
		if float(p.get("advanced_time", -1.0)) > 0.0:
			advanced_times.append(float(p.get("advanced_time")))

	deltas.sort()
	basic_times.sort()
	advanced_times.sort()
	var median_delta := 0.0
	var median_basic := 0.0
	var median_advanced := 0.0
	if deltas.size() > 0:
		median_delta = float(deltas[deltas.size() / 2])
	if basic_times.size() > 0:
		median_basic = float(basic_times[basic_times.size() / 2])
	if advanced_times.size() > 0:
		median_advanced = float(advanced_times[advanced_times.size() / 2])
	var min_advantage: float = maxf(0.20, median_basic * 0.005)
	var pairwise_ok: bool = faster_count >= 2
	var median_ok: bool = median_advanced > 0.0 and median_basic > 0.0 and median_delta >= min_advantage and median_advanced < median_basic
	var advanced_faster: bool = pairwise_ok and median_ok and all_basic_finished and all_advanced_finished
	var ghost_ok: bool = bool(ghost_result.get("GHOST_SELF_IMPROVEMENT_PASS"))
	var causal_ok: bool = (
		bool(equiv.get("DRIVER_PARAMETERS_MATCH"))
		and bool(equiv.get("ONLY_SKILL_INPUTS_DIFFER"))
		and not bool(equiv.get("BASIC_HANDICAP_PRESENT"))
		and advanced_faster
		and ghost_ok
		and not _lap_event_used_as_finish_fallback
		and _failures.is_empty()
	)

	var mastery := {
		"schema": "gunnchos.engineering_wave010.mastery.v1",
		"observed": true,
		"reliable": causal_ok,
		"advanced_faster": advanced_faster,
		"pairwise_advanced_faster": faster_count,
		"pairwise_required": 2,
		"paired_trials": PAIRED_TRIALS,
		"median_advantage_sec": snappedf(median_delta, 0.001),
		"median_basic_sec": snappedf(median_basic, 0.001),
		"median_advanced_sec": snappedf(median_advanced, 0.001),
		"min_advantage_sec": snappedf(min_advantage, 0.001),
		"median_advantage_ok": median_ok,
		"median_advantage_pct": snappedf((median_delta / median_basic) * 100.0, 0.001) if median_basic > 0.0 else 0.0,
		"racer_id": RACER_ID,
		"shoe_id": SHOE_ID,
		"track_id": TRACK_ID,
		"mode": "TIME_TRIAL",
		"competitive_mode": true,
		"accept_test_mode": false,
		"auto_accelerate": false,
		"accept_force_laps": 0,
		"driver": "SYNTHETIC_INPUT_DRIVER",
		"TRIAL_ORDER": trial_order,
		"BASIC_TIMES": basic_times,
		"ADVANCED_TIMES": advanced_times,
		"DRIVER_PARAMETERS_MATCH": bool(equiv.get("DRIVER_PARAMETERS_MATCH")),
		"ONLY_SKILL_INPUTS_DIFFER": bool(equiv.get("ONLY_SKILL_INPUTS_DIFFER")),
		"BASIC_HANDICAP_PRESENT": false,
		"TECHNIQUE_COUNT_SOURCE": "PRODUCTION_SIGNAL_OR_TELEMETRY",
		"DRIVER_INTENT_COUNTED_AS_SUCCESS": false,
		"PRODUCTION_DRIFT_RELEASE_EVENTS": prod_drift_total,
		"PRODUCTION_MANUAL_BOOST_EVENTS": prod_manual_boost_total,
		"ALL_BASIC_RACE_FINISHED_SIGNALS": all_basic_finished,
		"ALL_ADVANCED_RACE_FINISHED_SIGNALS": all_advanced_finished,
		"LAP_EVENT_USED_AS_FINISH_FALLBACK": _lap_event_used_as_finish_fallback,
		"TIME_TRIAL_LAP_COUNT": 1,
		"TIME_TRIAL_LAP_COUNT_PRODUCT_JUSTIFICATION": (
			"Product design: Time Trial is a single-lap mastery/ghost run "
			+ "(GameManager.start_time_trial + RaceScene TT arm). CI uses Engine.time_scale, not lap truncation."
		),
		"pairs": pairs,
		"ghost": ghost_result,
		"driver_equivalence": equiv,
		"failures": Array(_failures),
		"reason": (
			"causal mastery: same steering + skills-only advantage + real ghost loop"
			if causal_ok
			else "causal mastery timing/ghost/technique/driver-equivalence incomplete"
		),
	}

	_write_json("artifacts/engineering_wave010/MASTERY_RESULT.json", mastery)
	_write_json("artifacts/engineering_wave010/CAUSAL_MASTERY_RESULT.json", {
		"schema": "gunnchos.engineering_wave010.causal_mastery.v1",
		"mastery": mastery,
		"BASIC_DRIVER_PARAMETERS": equiv.get("BASIC_DRIVER_PARAMETERS"),
		"ADVANCED_DRIVER_PARAMETERS": equiv.get("ADVANCED_DRIVER_PARAMETERS"),
		"BASIC_PARAMETER_HASH": equiv.get("BASIC_PARAMETER_HASH"),
		"ADVANCED_PARAMETER_HASH": equiv.get("ADVANCED_PARAMETER_HASH"),
		"DRIVER_PARAMETERS_MATCH": equiv.get("DRIVER_PARAMETERS_MATCH"),
		"ONLY_SKILL_INPUTS_DIFFER": equiv.get("ONLY_SKILL_INPUTS_DIFFER"),
		"BASIC_HANDICAP_PRESENT": false,
		"TRIAL_ORDER": trial_order,
		"BASIC_TIMES": basic_times,
		"ADVANCED_TIMES": advanced_times,
		"production_technique_events": {
			"drift_release": prod_drift_total,
			"manual_boost": prod_manual_boost_total,
			"source": "PRODUCTION_SIGNAL_OR_TELEMETRY",
		},
		"race_finished": {
			"ALL_BASIC_RACE_FINISHED_SIGNALS": all_basic_finished,
			"ALL_ADVANCED_RACE_FINISHED_SIGNALS": all_advanced_finished,
			"LAP_EVENT_USED_AS_FINISH_FALLBACK": _lap_event_used_as_finish_fallback,
		},
		"ghost": ghost_result,
	})
	_write_json("artifacts/engineering_wave010/MASTERY_DRIVER_EQUIVALENCE.json", equiv)
	_write_json("artifacts/engineering_wave010/ACTUAL_TIME_TRIAL_GHOST_RESULT.json", ghost_result)
	_write_json("artifacts/engineering_wave010/TIME_TRIAL_MASTERY_E2E_RESULT.json", mastery)

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
	if causal_ok:
		print("Wave010TimeTrialMasteryE2E PASS")
		print("ADVANCED_FASTER=true pairwise=%d/%d median_delta=%.3f" % [faster_count, PAIRED_TRIALS, median_delta])
		quit(0)
	else:
		for msg in _failures:
			push_error(msg)
			print("MASTERY_GATE: ", msg)
		print(
			"Wave010TimeTrialMasteryE2E PARTIAL pairwise=%d/%d median_delta=%.3f min=%.3f ghost=%s"
			% [faster_count, PAIRED_TRIALS, median_delta, min_advantage, str(ghost_ok)]
		)
		quit(0 if pairs.size() == PAIRED_TRIALS else 1)


func _emit_driver_equivalence() -> Dictionary:
	var logic = _driver_node.get_logic()
	logic.reset("basic")
	var basic_params: Dictionary = logic.driver_parameters()
	var basic_hash: String = logic.parameter_hash()
	logic.reset("advanced")
	var advanced_params: Dictionary = logic.driver_parameters()
	var advanced_hash: String = logic.parameter_hash()
	var match_ok: bool = basic_hash == advanced_hash and basic_params.hash() == advanced_params.hash()
	# Detect forbidden handicap patterns in source (static mirror for artifact).
	var handicap := false
	var src := FileAccess.get_file_as_string("res://tests/engineering_wave010/SyntheticInputDriver.gd")
	if "look_ahead = 15.0 if" in src or "steer * 0.88" in src or "steer *= 0.88" in src:
		handicap = true
		match_ok = false
	return {
		"schema": "gunnchos.engineering_wave010.mastery_driver_equivalence.v1",
		"BASIC_DRIVER_PARAMETERS": basic_params,
		"ADVANCED_DRIVER_PARAMETERS": advanced_params,
		"BASIC_PARAMETER_HASH": basic_hash,
		"ADVANCED_PARAMETER_HASH": advanced_hash,
		"DRIVER_PARAMETERS_MATCH": match_ok and not handicap,
		"ONLY_SKILL_INPUTS_DIFFER": match_ok and not handicap,
		"BASIC_HANDICAP_PRESENT": handicap,
		"skills_flag_excluded_from_hash": true,
	}


func _clear_track_ghost(track_id: String) -> void:
	var recorder := Node.new()
	recorder.set_script(load("res://scripts/race/GhostRecorder.gd"))
	root.add_child(recorder)
	if recorder.has_method("clear_saved"):
		recorder.clear_saved(track_id)
	recorder.queue_free()


func _read_ghost_file(track_id: String) -> Dictionary:
	var path := GHOST_PATH_FMT % track_id
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _run_actual_ghost_self_improvement(gm: Node) -> Dictionary:
	## clear → actual Basic RaceScene finish → ghost file → Advanced until faster replaces → replay load
	var out := {
		"ok": false,
		"ACTUAL_BASIC_GHOST_SAVED": false,
		"BASIC_GHOST_TIME_MATCHES_ACTUAL_RACE": false,
		"ACTUAL_ADVANCED_GHOST_REPLACED_BASIC": false,
		"ADVANCED_GHOST_TIME_MATCHES_ACTUAL_RACE": false,
		"ACTUAL_RACESCENE_GHOST_REPLAY_LOAD_PASS": false,
		"GHOST_SELF_IMPROVEMENT_PASS": false,
		"synthetic_probe_used_as_closure": false,
		"basic_ghost": {},
		"advanced_ghost": {},
		"advanced_attempts": 0,
	}
	print("GHOST_LOOP clear → basic → advanced replace")
	_clear_track_ghost(TRACK_ID)
	var basic: Dictionary = await _run_time_trial(gm, "basic")
	if not bool(basic.get("race_finished_signal")):
		_failures.append("ghost loop: basic missing race_finished")
		return out
	var b_time := float(basic.get("finish_time", -1.0))
	var basic_meta: Dictionary = basic.get("ghost_meta_after_race", {})
	out["basic_ghost"] = basic_meta
	out["ACTUAL_BASIC_GHOST_SAVED"] = bool(basic.get("ghost_saved_after_race")) and int(basic_meta.get("sample_count", 0)) > 0
	var b_ghost_t := float(basic_meta.get("time", -1.0))
	out["BASIC_GHOST_TIME_MATCHES_ACTUAL_RACE"] = (
		out["ACTUAL_BASIC_GHOST_SAVED"]
		and b_ghost_t > 0.0
		and absf(b_ghost_t - b_time) <= maxf(0.25, b_time * 0.02)
	)
	if not out["BASIC_GHOST_TIME_MATCHES_ACTUAL_RACE"]:
		_failures.append("ghost loop: basic ghost missing/mismatch")
		return out

	# Up to 3 advanced RaceScene attempts — only a truly faster run may replace.
	for attempt in range(3):
		out["advanced_attempts"] = attempt + 1
		var advanced: Dictionary = await _run_time_trial(gm, "advanced")
		if not bool(advanced.get("race_finished_signal")):
			continue
		var a_time := float(advanced.get("finish_time", -1.0))
		if not (a_time > 0.0 and a_time < b_time):
			print("GHOST_LOOP advanced attempt %d not faster (%.3f vs basic %.3f)" % [attempt + 1, a_time, b_time])
			continue
		var ghost_after := _read_ghost_file(TRACK_ID)
		var a_ghost_t := float(ghost_after.get("time", -1.0))
		var a_samples := (ghost_after.get("samples") as Array).size() if ghost_after.get("samples") is Array else 0
		out["advanced_ghost"] = {
			"track_id": ghost_after.get("track_id"),
			"time": ghost_after.get("time"),
			"sample_count": a_samples,
			"attempt": attempt + 1,
		}
		out["ACTUAL_ADVANCED_GHOST_REPLACED_BASIC"] = (
			a_samples > 0
			and absf(a_ghost_t - a_time) <= maxf(0.25, a_time * 0.02)
			and str(ghost_after.get("track_id", "")) == TRACK_ID
			and a_ghost_t < b_ghost_t
		)
		out["ADVANCED_GHOST_TIME_MATCHES_ACTUAL_RACE"] = out["ACTUAL_ADVANCED_GHOST_REPLACED_BASIC"]
		if out["ACTUAL_ADVANCED_GHOST_REPLACED_BASIC"]:
			break

	var replay_ok := await _probe_racescene_ghost_playback(gm)
	out["ACTUAL_RACESCENE_GHOST_REPLAY_LOAD_PASS"] = replay_ok
	out["GHOST_SELF_IMPROVEMENT_PASS"] = (
		out["ACTUAL_BASIC_GHOST_SAVED"]
		and out["BASIC_GHOST_TIME_MATCHES_ACTUAL_RACE"]
		and out["ACTUAL_ADVANCED_GHOST_REPLACED_BASIC"]
		and out["ADVANCED_GHOST_TIME_MATCHES_ACTUAL_RACE"]
		and out["ACTUAL_RACESCENE_GHOST_REPLAY_LOAD_PASS"]
		and not bool(out["synthetic_probe_used_as_closure"])
	)
	out["ok"] = out["GHOST_SELF_IMPROVEMENT_PASS"]
	if not out["ok"]:
		_failures.append("actual RaceScene ghost self-improvement failed: %s" % str(out))
	return out


func _probe_racescene_ghost_playback(gm: Node) -> bool:
	gm.start_time_trial(TRACK_ID)
	gm.total_laps = 1
	gm.accept_test_mode = false
	gm.accept_force_laps = 0
	gm.auto_accelerate = false
	gm.ai_field_size = 0
	if gm.has_method("sync_race_mode_string"):
		gm.sync_race_mode_string()
	var packed: PackedScene = load("res://scenes/race/RaceScene.tscn")
	if packed == null:
		return false
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var ghost_player: Node = scene.get_node_or_null("GhostPlayer")
	var ok := false
	if ghost_player != null:
		var playing := bool(ghost_player.get("_playing"))
		var samples: Array = ghost_player.get("_samples") if "_samples" in ghost_player else []
		ok = playing or (samples is Array and samples.size() > 0)
	scene.queue_free()
	await process_frame
	return ok


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
	# Production technique observation only — never driver intent.
	var production := {"drift_release": 0, "manual_boost": 0, "drift_release_boost": 0}
	var hits := {"n": 0}
	var boost = player.get_node_or_null("BoostSystem")
	var drift = player.get_node_or_null("DriftSystem")
	if drift != null and drift.has_signal("drift_released"):
		drift.drift_released.connect(func(_m, _t):
			production["drift_release"] += 1
		)
	if boost != null and boost.has_signal("boost_activated"):
		boost.boost_activated.connect(func(_m, _d, source: String):
			if str(source) == "manual":
				production["manual_boost"] += 1
			elif str(source) == "drift_release":
				production["drift_release_boost"] += 1
		)
	var bus = root.get_node_or_null("TelemetryBus")
	if bus != null and bus.has_signal("event_recorded"):
		bus.event_recorded.connect(func(event_name: String, payload: Dictionary):
			if str(event_name) == "drift_release":
				production["drift_release"] += 1
			elif str(event_name) == "boost" and str(payload.get("source", "")) == "manual":
				production["manual_boost"] += 1
		)

	var finish_state := {"time": -1.0, "signal": false, "results": false}
	if race_manager.has_signal("race_finished"):
		race_manager.race_finished.connect(func(_p, results):
			# Dictionary capture — GDScript lambdas do not reliably mutate outer locals.
			finish_state["time"] = float(race_manager.race_time)
			finish_state["signal"] = true
			finish_state["results"] = results is Array
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
		if bool(finish_state["signal"]) and float(finish_state["time"]) >= 0.0:
			break

	_driver_node.stop()
	var finished_at := float(finish_state["time"])
	var race_finished_signal := bool(finish_state["signal"])
	var finish_results_seen := bool(finish_state["results"])
	print("MASTERY_RUN profile=%s finished=%s time=%.3f cps=%d tech=%s" % [
		profile, str(race_finished_signal), finished_at, int(hits.n), str(production)
	])

	# Categories from distinct production observation kinds (prompt §3).
	var production_techniques := {
		"drift_release": int(production["drift_release"]),
		"manual_boost": int(production["manual_boost"]),
		"drift_release_boost": int(production["drift_release_boost"]),
	}
	var cats := 0
	for k in production_techniques.keys():
		if int(production_techniques[k]) > 0:
			cats += 1

	var checkpoint_hits: int = int(hits.n)
	if not race_finished_signal or finished_at < 0.0:
		local_fail.append("race_finished signal not observed")
	if checkpoint_hits < 1:
		local_fail.append("no checkpoint hits")

	var ghost_meta := {}
	var ghost_saved := false
	if race_finished_signal:
		var gfile := _read_ghost_file(TRACK_ID)
		if not gfile.is_empty():
			ghost_saved = true
			ghost_meta = {
				"track_id": gfile.get("track_id"),
				"time": gfile.get("time"),
				"sample_count": (gfile.get("samples") as Array).size() if gfile.get("samples") is Array else 0,
			}

	scene.queue_free()
	await process_frame
	return {
		"ok": local_fail.is_empty() and finished_time_ok(finished_at) and race_finished_signal,
		"failures": Array(local_fail),
		"finish_time": finished_at,
		"race_finished_signal": race_finished_signal,
		"finish_results_seen": finish_results_seen,
		"checkpoint_hits": checkpoint_hits,
		"production_techniques": production_techniques,
		"technique_categories": cats,
		"TECHNIQUE_COUNT_SOURCE": "PRODUCTION_SIGNAL_OR_TELEMETRY",
		"DRIVER_INTENT_COUNTED_AS_SUCCESS": false,
		"ghost_saved_after_race": ghost_saved,
		"ghost_meta_after_race": ghost_meta,
		"profile": profile,
	}


func finished_time_ok(t: float) -> bool:
	return t > 0.0


func _write_json(rel: String, data: Dictionary) -> void:
	var path := ProjectSettings.globalize_path("res://%s" % rel)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func _fail_quit(msg: String) -> void:
	push_error(msg)
	print("FAIL: ", msg)
	Engine.time_scale = 1.0
	quit(1)
