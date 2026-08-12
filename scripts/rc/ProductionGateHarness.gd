extends Node

## WP-014 ACTUAL_PRODUCTION_RUNTIME harness.
##
## Boots the REAL shipped project (main scene + every autoload, exactly as a
## player's build would) and drives it with the REAL Input singleton — the
## same InputMap actions PlayerController/InputManager read at runtime — no
## GameManager.accept_test_mode autopilot. This exists because prior "Gate 1"
## evidence (gate1/tools/core_loop_runner.py) is a Python mirror of
## GameManager, not the Godot engine, and prior `--script` SceneTree smokes
## (tests/*.gd) cannot see autoloads at all, so any script that touches an
## autoload (ItemManager, InputProfileCatalog, CrashWatchdog, ...) silently
## fails to compile under them while the harness still prints PASS. Running
## as a normal headless boot (no `--script`) closes both gaps: autoloads are
## live, and failures here are real engine failures.
##
## Invoke: godot --headless --path . -- --production-gate
## Evidence: gate1/evidence/out/actual_production_runtime.json

const OUT_PATH := "res://gate1/evidence/out/actual_production_runtime.json"
const RACE_TRACK_ID := "verdant_cascade_circuit"
const CrashWatchdogScript := preload("res://scripts/rc/CrashWatchdog.gd")

var _steps: Array = []
var _t_start_msec: int = 0
var _frame_deltas: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _should_run():
		return
	_t_start_msec = Time.get_ticks_msec()
	call_deferred("_run")


func _should_run() -> bool:
	for arg in OS.get_cmdline_user_args():
		if str(arg).find("production-gate") != -1:
			return true
	for arg in OS.get_cmdline_args():
		if str(arg).find("production-gate") != -1:
			return true
	return false


func _process(delta: float) -> void:
	if _should_run():
		_frame_deltas.append(delta)


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_step_title_menu()
	await _step_new_session_and_input()
	await _step_checkpoint_core_loop()
	await _step_pause_resume()
	_step_settings_a11y()
	_step_audio_hook()
	_step_save_load_lifecycle()
	await _step_suspend_resume_and_crash_recovery()
	_step_logging_and_perf()
	_finish_and_quit()


func _emit(name: String, ok: bool, detail: Dictionary = {}) -> void:
	_steps.append({
		"step": name,
		"result": "pass" if ok else "fail",
		"timestamp": Time.get_datetime_string_from_system(true),
		"detail": detail,
	})
	if not ok:
		push_error("PRODUCTION_GATE_FAIL[%s]: %s" % [name, JSON.stringify(detail)])


func _step_title_menu() -> void:
	var scene := get_tree().current_scene
	var ok := scene != null and scene.scene_file_path == "res://scenes/main/MainMenu.tscn"
	_emit("title_menu", ok, {"scene_file_path": scene.scene_file_path if scene else ""})


func _step_new_session_and_input() -> void:
	GameManager.start_single_race(RACE_TRACK_ID)
	GameManager.accept_test_mode = false
	GameManager.auto_accelerate = false
	SceneLoader.go_to_race()
	var race: Node = null
	for _i in 30:
		await get_tree().process_frame
		race = get_tree().current_scene
		if race != null and race.scene_file_path == "res://scenes/race/RaceScene.tscn":
			break
	var session_ok := race != null and race.scene_file_path == "res://scenes/race/RaceScene.tscn"
	_emit("new_game_session", session_ok, {"scene_file_path": race.scene_file_path if race else ""})
	if not session_ok:
		return
	# Let the race scene finish wiring (RaceScene._ready) and the 3s countdown clear.
	for _i in 6:
		await get_tree().process_frame
	await get_tree().create_timer(4.2).timeout

	var player: Node3D = race.get_node_or_null("PlayerRacer")
	if player == null:
		_emit("real_input_drive", false, {"reason": "PlayerRacer missing"})
		return
	var start_pos: Vector3 = player.global_position

	# REAL Input singleton — identical state InputManager.get_steer()/
	# is_accelerating() read for a physical keyboard/gamepad player.
	Input.action_press("accelerate")
	Input.action_press("move_right")
	var input_active_mid_drive := false
	for _i in 90:
		await get_tree().process_frame
		if Input.is_action_pressed("accelerate") and InputManager.is_accelerating():
			input_active_mid_drive = true
	Input.action_release("accelerate")
	Input.action_release("move_right")
	await get_tree().process_frame

	var end_pos: Vector3 = player.global_position
	var moved := start_pos.distance_to(end_pos)
	_emit("real_input_drive", moved > 1.0 and input_active_mid_drive, {
		"distance_traveled": moved,
		"start": [start_pos.x, start_pos.y, start_pos.z],
		"end": [end_pos.x, end_pos.y, end_pos.z],
		"input_source": InputManager.get_active_source_name(),
		"engine_reported_accelerating_during_drive": input_active_mid_drive,
	})


func _step_checkpoint_core_loop() -> void:
	var race := get_tree().current_scene
	if race == null or race.scene_file_path != "res://scenes/race/RaceScene.tscn":
		_emit("checkpoint_core_loop", false, {"reason": "not in race scene"})
		return
	var race_manager: Node = race.get_node_or_null("RaceManager")
	var lap_manager: Node = race_manager.get_node_or_null("LapManager") if race_manager else null
	var player: Node = race.get_node_or_null("PlayerRacer")
	if lap_manager == null or player == null:
		_emit("checkpoint_core_loop", false, {"reason": "LapManager/PlayerRacer missing"})
		return
	var before := int(lap_manager.get_next_checkpoint(player)) if lap_manager.has_method("get_next_checkpoint") else -1
	var checkpoints: Array = race.track.get_checkpoints() if race.track else []
	var advanced := false
	if checkpoints.size() > 1:
		# Fire the real Area3D checkpoint signal a live racer would trigger on
		# contact — exercises the identical RaceManager -> LapManager wiring.
		checkpoints[1].racer_passed.emit(player, 1)
		await get_tree().process_frame
		var after := int(lap_manager.get_next_checkpoint(player)) if lap_manager.has_method("get_next_checkpoint") else -1
		advanced = after != before
	_emit("checkpoint_core_loop", advanced, {
		"checkpoint_before": before,
		"lap": int(lap_manager.get_lap(player)) if lap_manager.has_method("get_lap") else -1,
	})


func _step_pause_resume() -> void:
	var race := get_tree().current_scene
	if race == null:
		_emit("pause_resume", false, {"reason": "no active scene"})
		return
	var player: Node3D = race.get_node_or_null("PlayerRacer")
	var pos_before_pause: Vector3 = player.global_position if player else Vector3.ZERO

	_send_pause_key_tap()
	await get_tree().process_frame
	await get_tree().process_frame
	var paused_ok := get_tree().paused

	# While paused, drive real input again — position must not change.
	Input.action_press("accelerate")
	for _i in 10:
		await get_tree().process_frame
	Input.action_release("accelerate")
	var pos_during_pause: Vector3 = player.global_position if player else Vector3.ZERO
	var frozen_ok := pos_before_pause.distance_to(pos_during_pause) < 0.01

	# Second real key tap (press + release, not a held echo) must resume —
	# this is the exact defect the harness caught: RaceScene froze its own
	# pause listener once paused, so only PauseMenu's ALWAYS-mode node can
	# hear this second tap (see PauseMenu.gd fix).
	_send_pause_key_tap()
	await get_tree().process_frame
	await get_tree().process_frame
	var resumed_ok := not get_tree().paused

	_emit("pause_resume", paused_ok and frozen_ok and resumed_ok, {
		"paused_after_pause_action": paused_ok,
		"frame_frozen_while_paused": frozen_ok,
		"resumed_after_second_pause_action": resumed_ok,
	})


func _send_pause_key_tap() -> void:
	# A real key press-then-release, not a held InputEventAction (which the
	# Input singleton otherwise flags as an echo on the second identical
	# "pressed" state and event.is_action_pressed() then ignores).
	var down := InputEventAction.new()
	down.action = "pause"
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = "pause"
	up.pressed = false
	Input.parse_input_event(up)


func _step_settings_a11y() -> void:
	var a11y: Node = get_node_or_null("/root/AccessibilitySettings")
	if a11y == null:
		_emit("settings_a11y", false, {"reason": "AccessibilitySettings autoload missing"})
		return
	a11y.set_colorblind_safe_hud(false)
	var default_player: Color = a11y.get_marker_color("player")
	a11y.set_colorblind_safe_hud(true)
	var cb_player: Color = a11y.get_marker_color("player")
	a11y.set_larger_ui(true)
	var scale_up: float = a11y.get_ui_scale_multiplier()
	a11y.set_reduce_motion(true)
	var shake_disabled: bool = not a11y.camera_shake_allowed()
	# Persisted to disk immediately (save_settings runs inside every setter).
	var cfg := ConfigFile.new()
	var persisted := cfg.load("user://accessibility.cfg") == OK and bool(cfg.get_value("a11y", "colorblind_safe_hud", false))
	# Restore defaults so this gate run does not leak into future sessions.
	a11y.set_colorblind_safe_hud(false)
	a11y.set_larger_ui(false)
	a11y.set_reduce_motion(false)
	_emit("settings_a11y_baseline", (not default_player.is_equal_approx(cb_player)) and scale_up >= 1.2 and shake_disabled and persisted, {
		"colorblind_markers_differ": not default_player.is_equal_approx(cb_player),
		"larger_ui_scale": scale_up,
		"reduce_motion_disables_shake": shake_disabled,
		"persisted_to_disk": persisted,
	})


func _step_audio_hook() -> void:
	var audio: Node = get_node_or_null("/root/AudioDirector")
	if audio == null:
		_emit("audio_hook", false, {"reason": "AudioDirector autoload missing"})
		return
	var has_hooks := audio.has_method("play_ui") and audio.has_method("play_menu_music") and audio.has_method("play_race_music")
	var no_crash := true
	if audio.has_method("play_ui"):
		audio.play_ui("confirm")
	_emit("audio_hook", has_hooks and no_crash, {"hooks_present": has_hooks})


func _step_save_load_lifecycle() -> void:
	var prog: Node = get_node_or_null("/root/ProgressionSave")
	if prog == null:
		_emit("save_load_lifecycle", false, {"reason": "ProgressionSave autoload missing"})
		return
	var xp_before := int(prog.xp)
	var level_before := int(prog.level)
	prog.add_xp(37)
	var xp_after_add := int(prog.xp)
	# Confirm the write actually reached user:// (not just in-memory state).
	var cfg := ConfigFile.new()
	var disk_ok := cfg.load("user://pp_progression.cfg") == OK
	var disk_xp := int(cfg.get_value("career", "xp", -1)) if disk_ok else -1
	var disk_level := int(cfg.get_value("career", "level", -1)) if disk_ok else -1
	# Simulate a relaunch: a brand-new ProgressionSave instance reading only
	# from disk, independent of the live autoload's in-memory state.
	var fresh_prog = load("res://scripts/core/ProgressionSave.gd").new()
	fresh_prog.load_or_migrate()
	var reload_matches := int(fresh_prog.xp) == xp_after_add and int(fresh_prog.level) == int(prog.level)
	var tt_saved: bool = prog.record_time_trial_pb(RACE_TRACK_ID, 42.5)
	_emit("save_load_lifecycle", disk_ok and disk_xp == xp_after_add and reload_matches, {
		"xp_before": xp_before,
		"level_before": level_before,
		"xp_after_add_xp": xp_after_add,
		"disk_xp": disk_xp,
		"disk_level": disk_level,
		"fresh_instance_reload_matches_live": reload_matches,
		"time_trial_pb_recorded": tt_saved,
	})


func _step_suspend_resume_and_crash_recovery() -> void:
	# Suspend/resume: freeze the whole tree (mirrors OS backgrounding the app)
	# then confirm cup/career state survives the freeze and a fresh load.
	var gm := GameManager
	gm.start_cup("sole_surge_cup", ["verdant_cascade_circuit", "mirage_mesa"])
	gm.record_race_result("verdant_cascade_circuit", 88.4, 1)
	gm.record_field_results([
		{"racer": null, "time": 88.4, "is_player": true},
		{"racer": null, "time": 91.0, "is_player": false},
	])
	gm.save_cup_progress()
	get_tree().paused = true
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().paused = false
	var loaded_ok := gm.load_cup_progress() if gm.has_method("load_cup_progress") else false
	CrashWatchdogScript.note_event("production_gate_suspend_resume", "verdant_cascade_circuit")
	var last: Dictionary = CrashWatchdogScript.last_event()
	var crash_ok := str(last.get("kind", "")) == "production_gate_suspend_resume"
	_emit("suspend_resume_checkpoint", loaded_ok and crash_ok, {
		"cup_reload_ok": loaded_ok,
		"crash_watchdog_last_kind": str(last.get("kind", "")),
	})
	gm.clear_cup()


func _step_logging_and_perf() -> void:
	var before := TelemetryBus.get_event_count()
	TelemetryBus.race_start(RACE_TRACK_ID, "single", 3)
	TelemetryBus.checkpoint(RACE_TRACK_ID, 1, 0, true)
	TelemetryBus.finish(RACE_TRACK_ID, 41.2, 1, true, {"avg_fps": _avg_fps()})
	var logged_ok := TelemetryBus.get_event_count() >= before + 3
	var log_written := FileAccess.file_exists("user://telemetry/race_events.jsonl")
	_emit("logging_perf_telemetry", logged_ok and log_written, {
		"events_recorded_this_run": TelemetryBus.get_event_count() - before,
		"jsonl_present": log_written,
		"avg_fps": _avg_fps(),
		"frame_samples": _frame_deltas.size(),
		"min_fps": _min_fps(),
	})


func _avg_fps() -> float:
	if _frame_deltas.is_empty():
		return 0.0
	var total := 0.0
	for d in _frame_deltas:
		total += d
	var avg_delta := total / _frame_deltas.size()
	return 1.0 / avg_delta if avg_delta > 0.0 else 0.0


func _min_fps() -> float:
	var worst_delta := 0.0
	for d in _frame_deltas:
		worst_delta = maxf(worst_delta, d)
	return 1.0 / worst_delta if worst_delta > 0.0 else 0.0


func _finish_and_quit() -> void:
	var all_pass := true
	for s in _steps:
		if s.get("result") != "pass":
			all_pass = false
	var summary := {
		"schema": "pp_actual_production_runtime/v1",
		"game": "pedestrian-pursuit",
		"engine": "godot",
		"engine_version": Engine.get_version_info().get("string", "unknown"),
		"headless": OS.has_feature("headless") or DisplayServer.get_name() == "headless",
		"run_mode": "main_scene_boot_with_autoloads",
		"commit": _git_commit(),
		"started_at": Time.get_datetime_string_from_system(true),
		"duration_msec": Time.get_ticks_msec() - _t_start_msec,
		"steps": _steps,
		"all_steps_pass": all_pass,
	}
	var dir := DirAccess.open("res://gate1/evidence/out")
	if dir == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://gate1/evidence/out"))
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(summary, "  "))
		f.close()
	print("PRODUCTION_GATE_%s" % ("PASS" if all_pass else "FAIL"))
	for s in _steps:
		print("  [%s] %s" % [str(s.get("result")).to_upper(), s.get("step")])
	get_tree().quit(0 if all_pass else 1)


func _git_commit() -> String:
	var out := []
	OS.execute("git", ["rev-parse", "HEAD"], out)
	if out.is_empty():
		return "unknown"
	return str(out[0]).strip_edges()
