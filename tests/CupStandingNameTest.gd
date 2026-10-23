extends SceneTree

## Headless: cup standings follow runner_display_name across finish slots.
## A rival with no name is "Runner", not "AI 2" / "AI 3".


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var gm = preload("res://scripts/core/GameManager.gd").new()
	get_root().add_child(gm)
	if not gm.start_cup("sole_surge_cup", ["verdant_cascade_circuit"]):
		failures.append("start_cup failed")
		_finish(failures)
		return
	var mira := Node.new()
	mira.set_meta("runner_display_name", "Mira Lane")
	get_root().add_child(mira)
	var unnamed := Node.new()
	get_root().add_child(unnamed)
	# 2nd, then 3rd: the same runner must keep one standings row.
	_record(gm, mira, unnamed, 1)
	_record(gm, unnamed, mira, 2)
	if int(gm.cup_standings.get("Mira Lane", 0)) != 12:
		failures.append(
			"Mira Lane points followed finish slot, got %s" % str(gm.cup_standings)
		)
	if int(gm.cup_standings.get("Runner", 0)) != 12:
		failures.append("unnamed rival should be 'Runner', got %s" % str(gm.cup_standings))
	if int(gm.cup_standings.get("You", 0)) != 20:
		failures.append("player row changed, got %s" % str(gm.cup_standings))
	for key in gm.cup_standings.keys():
		if str(key).begins_with("AI "):
			failures.append("finish-slot label remained: %s" % str(key))
	_finish(failures)


func _record(gm, second: Node, third: Node, round_index: int) -> void:
	gm.record_race_result("verdant_cascade_circuit", 90.0 + float(round_index), 1)
	gm.record_field_results([
		{"racer": null, "is_player": true},
		{"racer": second, "is_player": false},
		{"racer": third, "is_player": false},
	])


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("Cup standing name PASS — runner_display_name, fallback Runner")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
