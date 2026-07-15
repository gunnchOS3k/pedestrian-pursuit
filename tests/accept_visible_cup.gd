extends SceneTree
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")

## Visible Sole Surge cup driver (windowed, not --headless).
## Acceptance-only overrides: accept_test_mode + accept_force_laps=1 + auto_accelerate.
## Production defaults remain when those flags are false/0.
## Usage:
##   Godot --path . -s res://tests/accept_visible_cup.gd

const OUT := "user://visible_cup"
const RACE_TIMEOUT_SEC := 180.0

func _init() -> void:
	call_deferred("_run")

func _log(msg: String) -> void:
	print("[visible_cup] %s" % msg)

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _gm():
	return root.get_node_or_null("/root/GameManager")

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if img == null:
		_log("WARN shot fail %s" % name)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var err := img.save_png("%s/%s.png" % [OUT, name])
	_log("shot %s err=%s" % [name, str(err)])

func _await_race_finish(gm) -> bool:
	var elapsed := 0.0
	while elapsed < RACE_TIMEOUT_SEC:
		if bool(gm.last_race_finished):
			return true
		await _wait(0.5)
		elapsed += 0.5
	return false

func _run() -> void:
	var gm = _gm()
	if gm == null:
		_log("FAIL GameManager autoload missing")
		quit(1)
		return
	gm.accept_test_mode = true
	gm.accept_force_laps = 1
	gm.auto_accelerate = true
	gm.last_race_finished = false

	var cup: Dictionary = _TrackCatalog.load_cup("sole_surge_cup")
	if cup.is_empty():
		cup = _TrackCatalog.load_cup()
	var track_ids: Array = cup.get("track_ids", [])
	if track_ids.size() != 4:
		_log("FAIL expected 4 tracks got %d" % track_ids.size())
		quit(1)
		return
	if not gm.start_cup(str(cup.get("id", "sole_surge_cup")), track_ids):
		_log("FAIL start_cup")
		quit(1)
		return
	await _shot("00-cup-start")

	var failed := 0
	for i in track_ids.size():
		var tid := str(track_ids[i])
		_log("round %d %s" % [i + 1, tid])
		gm.last_race_finished = false
		var scene_path := "res://scenes/tracks/%s.tscn" % tid
		if not ResourceLoader.exists(scene_path):
			scene_path = "res://scenes/Race.tscn"
		if not ResourceLoader.exists(scene_path):
			scene_path = "res://scenes/race/RaceScene.tscn"
		if not ResourceLoader.exists(scene_path):
			_log("FAIL missing race scene for %s" % tid)
			failed += 1
			break
		change_scene_to_file(scene_path)
		await _wait(3.5)
		await _shot("%02d-course-%s" % [i + 1, tid])
		if not await _await_race_finish(gm):
			_log("FAIL race timeout %s — not faking finish" % tid)
			failed += 1
			break
		await _wait(1.2)
		await _shot("%02d-results-%s" % [i + 1, tid])
		if i < track_ids.size() - 1:
			gm.advance_cup()
			await _wait(0.4)

	gm.save_cup_progress()
	await _shot("99-final-standings")
	_log(
		"RESULT failed=%d points=%d standings=%s"
		% [failed, gm.get_cup_total_points(), " | ".join(gm.get_cup_standings_lines())]
	)
	gm.accept_test_mode = false
	gm.accept_force_laps = 0
	gm.auto_accelerate = false
	gm.accept_steer = 0.0
	quit(0 if failed == 0 else 1)
