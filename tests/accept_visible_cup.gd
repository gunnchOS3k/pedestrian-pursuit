extends SceneTree
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")

## Visible Sole Surge cup driver (windowed, not --headless).
## Usage:
##   Godot --path . -s res://tests/accept_visible_cup.gd

const OUT := "user://visible_cup"

func _init() -> void:
	call_deferred("_run")

func _log(msg: String) -> void:
	print("[visible_cup] %s" % msg)

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

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

func _run() -> void:
	var gm = preload("res://scripts/core/GameManager.gd").new()
	root.add_child(gm)
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

	for i in track_ids.size():
		var tid := str(track_ids[i])
		_log("round %d %s" % [i + 1, tid])
		# Load the track's race scene when available
		var scene_path := "res://scenes/tracks/%s.tscn" % tid
		if not ResourceLoader.exists(scene_path):
			scene_path = "res://scenes/Race.tscn"
		if not ResourceLoader.exists(scene_path):
			scene_path = "res://scenes/race/RaceScene.tscn"
		if ResourceLoader.exists(scene_path):
			change_scene_to_file(scene_path)
			await _wait(2.0)
		await _shot("%02d-course-%s" % [i + 1, tid])
		# Simulate a completed race (visible progress between loaded scenes)
		var fake_results: Array = [
			{"racer": null, "time": 88.0 + float(i), "is_player": true},
			{"racer": null, "time": 92.0 + float(i), "is_player": false},
			{"racer": null, "time": 97.0 + float(i), "is_player": false},
			{"racer": null, "time": 101.0 + float(i), "is_player": false},
		]
		gm.record_race_result(tid, 88.0 + float(i), 1)
		gm.record_field_results(fake_results)
		await _shot("%02d-results-%s" % [i + 1, tid])
		if i < track_ids.size() - 1:
			gm.advance_cup()
			await _wait(0.4)

	gm.save_cup_progress()
	await _shot("99-final-standings")
	_log(
		"PASS points=%d standings=%s"
		% [gm.get_cup_total_points(), " | ".join(gm.get_cup_standings_lines())]
	)
	quit(0)
