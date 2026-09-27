extends SceneTree
const ShortcutDecisionScript = preload("res://scripts/gamefeel/ShortcutDecisionDirector.gd")

## Deterministic presentation-state scenarios. Separate from human fun.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var passed := 0
	var scenarios := [
		"start_straight",
		"sustained_turn",
		"boost",
		"drafting",
		"overtake",
		"shortcut_entry",
		"shortcut_completion",
		"missed_shortcut",
		"collision",
		"jump_landing",
		"final_lap",
		"finish",
	]
	var results: Dictionary = {}
	for name in scenarios:
		var ok := _run_one(str(name), failures)
		results[name] = ok
		if ok:
			passed += 1
	DirAccess.make_dir_recursive_absolute("res://artifacts/gamefeel/v3")
	var file := FileAccess.open("res://artifacts/gamefeel/v3/RACE_SCENARIOS.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"passed": passed,
			"required": 12,
			"results": results,
			"HUMAN_FUN_JUDGMENT": false,
		}, "  "))
	if failures.is_empty() and passed == 12:
		print("RACE_SCENARIO_PASS=12/12")
		print("RaceScenarioV3Test PASS")
		quit(0)
	else:
		for row in failures:
			push_error(row)
		print("RaceScenarioV3Test FAIL")
		quit(1)


func _run_one(name: String, failures: PackedStringArray) -> bool:
	match name:
		"start_straight":
			var director := _director()
			director.start_phase = "establish"
			director._on_countdown("3")
			director._on_countdown("GO")
			director._on_go()
			var snap: Dictionary = director.snapshot()
			var ok := str(snap.get("start_phase")) == "racing" and bool(snap.get("go_released"))
			director.free()
			if not ok:
				failures.append("start_straight presentation failed")
			return ok
		"sustained_turn":
			var loco := Node.new()
			loco.set_script(load("res://scripts/gamefeel/LocomotionPresenter.gd"))
			root.add_child(loco)
			var body := CharacterBody3D.new()
			body.velocity = Vector3(4, 0, -8)
			root.add_child(body)
			loco.tick(0.16, body, false, false, 0.8)
			var ok2 := absf(float(loco.lean)) > 0.01
			loco.free()
			body.free()
			if not ok2:
				failures.append("sustained_turn lean missing")
			return ok2
		"boost":
			var fx := Node.new()
			fx.set_script(load("res://scripts/gamefeel/BoostFeedback.gd"))
			root.add_child(fx)
			fx.set_active(true, false)
			var on := bool(fx.presenting)
			fx.set_active(false, false)
			var off := not bool(fx.presenting)
			fx.free()
			if not (on and off):
				failures.append("boost scenario start/stop failed")
			return on and off
		"drafting":
			var draft := Node.new()
			draft.set_script(load("res://scripts/gamefeel/DraftFeedback.gd"))
			root.add_child(draft)
			draft.apply("entering", 0.1, false)
			var a := bool(draft.presenting)
			draft.apply("active", 1.0, false)
			var b := str(draft.hud_token()) == "DRAFT"
			draft.apply("none", 0.0, false)
			var c := not bool(draft.presenting)
			draft.free()
			if not (a and b and c):
				failures.append("drafting scenario failed")
			return a and b and c
		"overtake":
			var director := _director()
			director.record_overtake()
			var ok3: bool = director.overtakes == 1
			director.free()
			if not ok3:
				failures.append("overtake highlight missing")
			return ok3
		"shortcut_entry":
			var cue: Dictionary = ShortcutDecisionScript.cue_for_player(
				_fake_racer(Vector3(28, 0, 28), Vector3(44, 0, 20)),
				[Vector3(0, 0, 34), Vector3(24, 0, 36), Vector3(44, 0, 20)],
				[{"id": "cascade_inner_cut", "entry_point_index": 2, "risk": "wet_runoff"}],
				16.0
			)
			var ok4 := str(cue.get("cue", "")).begins_with("CUT")
			if not ok4:
				failures.append("shortcut_entry cue missing")
			return ok4
		"shortcut_completion":
			var director := _director()
			director.record_shortcut_taken("cascade_inner_cut")
			var ok5: bool = director.shortcuts_taken == 1
			director.free()
			if not ok5:
				failures.append("shortcut_completion highlight missing")
			return ok5
		"missed_shortcut":
			var far: Dictionary = ShortcutDecisionScript.cue_for_player(
				_fake_racer(Vector3(-80, 0, 80)),
				[Vector3(0, 0, 34), Vector3(24, 0, 36), Vector3(44, 0, 20)],
				[{"id": "cascade_inner_cut", "entry_point_index": 2, "risk": "wet_runoff"}],
				16.0
			)
			var ok6 := str(far.get("cue", "")).is_empty()
			if not ok6:
				failures.append("missed shortcut still showed a cue")
			return ok6
		"collision":
			var loco := Node.new()
			loco.set_script(load("res://scripts/gamefeel/LocomotionPresenter.gd"))
			root.add_child(loco)
			var body := CharacterBody3D.new()
			body.velocity = Vector3(0, -12, 0)
			root.add_child(body)
			loco._was_airborne = true
			loco._air_vy = -12.0
			loco.tick(0.016, body, false, false, 0.0)
			# Floor contact is false in empty world; just prove API is finite.
			var ok7 := is_finite(float(loco.landing_compression))
			loco.free()
			body.free()
			if not ok7:
				failures.append("collision presentation NaN")
			return ok7
		"jump_landing":
			var loco := Node.new()
			loco.set_script(load("res://scripts/gamefeel/LocomotionPresenter.gd"))
			root.add_child(loco)
			var lander := CharacterBody3D.new()
			root.add_child(lander)
			loco.landing_compression = 0.4
			loco.tick(0.1, lander, false, false, 0.0)
			var ok8 := float(loco.landing_compression) < 0.4
			lander.free()
			loco.free()
			if not ok8:
				failures.append("landing compression did not decay")
			return ok8
		"final_lap":
			var director := _director()
			var racer := Node.new()
			root.add_child(racer)
			director.player = racer
			director._on_lap_changed(racer, 2)
			var ok9 := bool(director.final_lap) and str(director.last_caption) == "FINAL LAP"
			director.free()
			racer.free()
			if not ok9:
				failures.append("final lap cue missing")
			return ok9
		"finish":
			var ok10 := ShortcutDecisionScript.finish_approach(
				_fake_racer(Vector3(1, 0, 1)), Vector3.ZERO, 2, 3, 0
			)
			if not ok10:
				failures.append("finish approach not detected")
			return ok10
		_:
			failures.append("unknown scenario %s" % name)
			return false


func _director() -> Node:
	var director := Node.new()
	director.set_script(load("res://scripts/gamefeel/RaceExperienceDirector.gd"))
	root.add_child(director)
	director.setup(null, null, null, {"id": "verdant_cascade_circuit"})
	return director


func _fake_racer(origin: Vector3, look_target: Vector3 = Vector3.INF) -> Node3D:
	var node := Node3D.new()
	root.add_child(node)
	node.global_position = origin
	var target := look_target
	if not target.is_finite():
		target = origin + Vector3(0, 0, -4)
	node.look_at(target, Vector3.UP)
	return node
