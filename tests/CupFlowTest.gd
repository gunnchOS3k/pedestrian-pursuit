extends SceneTree

## Headless Sole Surge cup state smoke — 4 rounds + standings accumulation.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var gm = preload("res://scripts/core/GameManager.gd").new()
	get_root().add_child(gm)
	var cup: Dictionary = TrackCatalog.load_cup("sole_surge_cup")
	if cup.is_empty():
		cup = TrackCatalog.load_cup()
	var track_ids: Array = cup.get("track_ids", [])
	if track_ids.size() != 4:
		failures.append("expected 4 Sole Surge courses, got %d" % track_ids.size())
	if not gm.start_cup(str(cup.get("id", "sole_surge_cup")), track_ids):
		failures.append("start_cup failed")
	for i in track_ids.size():
		var tid := str(track_ids[i])
		if gm.selected_track_id != tid:
			failures.append("round %d expected track %s got %s" % [i, tid, gm.selected_track_id])
		var fake_results: Array = [
			{"racer": null, "time": 90.0 + float(i), "is_player": true},
			{"racer": null, "time": 95.0 + float(i), "is_player": false},
			{"racer": null, "time": 100.0 + float(i), "is_player": false},
			{"racer": null, "time": 105.0 + float(i), "is_player": false},
		]
		gm.record_race_result(tid, 90.0 + float(i), 1)
		gm.record_field_results(fake_results)
		if i < track_ids.size() - 1:
			if not gm.advance_cup():
				failures.append("advance_cup failed after round %d" % i)
		elif gm.has_next_cup_race():
			failures.append("cup should be complete after round 4")
	if gm.get_cup_total_points() < 10:
		failures.append("player points were not accumulated")
	if gm.get_cup_standings_lines().is_empty():
		failures.append("cup standings empty")
	gm.save_cup_progress()
	var gm2 = preload("res://scripts/core/GameManager.gd").new()
	get_root().add_child(gm2)
	if not gm2.load_cup_progress():
		failures.append("cup progress save/load failed")
	elif int(gm2.get_cup_total_points()) != int(gm.get_cup_total_points()):
		failures.append("loaded points mismatched saved points")
	if failures.is_empty():
		print(
			"Cup flow smoke PASS — 4 courses, points=%d, standings=%s"
			% [gm.get_cup_total_points(), " | ".join(gm.get_cup_standings_lines())]
		)
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)
