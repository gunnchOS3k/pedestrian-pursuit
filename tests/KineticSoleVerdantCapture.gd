extends SceneTree

## Captures Verdant Cascade + Dash Reed from the real RaceScene path.
## Prefer xvfb (Gate 1). Writes PNGs under artifacts/kinetic_sole_verdant/.

const OUT_DIR := "res://artifacts/kinetic_sole_verdant"
const COURSE_ID := "verdant_cascade_circuit"
const RUNNER_ID := "dash_reed"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var abs_out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_out)
	var before_note := abs_out.path_join("BEFORE_NOTE.txt")
	if not FileAccess.file_exists(before_note):
		var note := FileAccess.open(before_note, FileAccess.WRITE)
		if note:
			note.store_string(
				"Before this Kinetic Sole pass, Verdant used a flat box basin, five cascade cylinders, and four sphere trees. Dash Reed shoes were a single accent box + heel.\n"
			)
	var gm := get_root().get_node_or_null("GameManager")
	var packed: PackedScene = load("res://scenes/race/RaceScene.tscn") as PackedScene
	if gm == null or packed == null or not gm.has_method("start_quick_race"):
		_write_manifest(abs_out, [], "GameManager or RaceScene missing")
		print("KINETIC_SOLE_CAPTURE=fail setup")
		quit(1)
		return
	if "accept_test_mode" in gm:
		gm.accept_test_mode = false
	if "accept_force_laps" in gm:
		gm.accept_force_laps = 0
	gm.selected_runner_id = RUNNER_ID
	gm.selected_racer_id = RUNNER_ID
	gm.start_quick_race(COURSE_ID)
	var scene := packed.instantiate()
	get_root().add_child(scene)
	var shots: Array = []
	for _i in 180:
		await physics_frame
		if scene.get_node_or_null("CourseTrack") != null and scene.get_node_or_null("PlayerRacer") != null:
			break
	shots.append(await _capture(abs_out, "01_verdant_boot_or_countdown"))
	var player := scene.get_node_or_null("PlayerRacer")
	var cam: Camera3D = null
	var rig := scene.get_node_or_null("CameraRig")
	if rig != null:
		cam = rig.get_node_or_null("Camera3D") as Camera3D
	if player != null and cam != null:
		## Character footwear close-up from chase camera.
		cam.current = true
		shots.append(await _capture(abs_out, "02_dash_reed_chase"))
	var race_manager := scene.get_node_or_null("RaceManager")
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if race_manager != null and int(race_manager.get("state")) >= 2:
			break
	if player != null and player.has_method("enable_movement"):
		player.enable_movement()
	var input := get_root().get_node_or_null("InputManager")
	for _i in 90:
		if input != null and input.has_method("set_touch_accelerate"):
			input.set_touch_accelerate(true)
		Input.action_press("accelerate")
		await physics_frame
	shots.append(await _capture(abs_out, "03_verdant_in_motion"))
	Input.action_release("accelerate")
	## Landmark framing: look toward cascade basin from a known scenic offset.
	if cam != null:
		cam.global_position = Vector3(8.0, 12.0, 28.0)
		cam.look_at(Vector3(0.0, 4.0, -8.0), Vector3.UP)
		cam.current = true
		await physics_frame
		await physics_frame
		shots.append(await _capture(abs_out, "04_cascade_landmark"))
	_write_manifest(abs_out, shots, "")
	var captured := 0
	for s in shots:
		if str(s.get("status", "")) == "CAPTURED":
			captured += 1
	print("KINETIC_SOLE_CAPTURE course=%s runner=%s shots=%d captured=%d" % [COURSE_ID, RUNNER_ID, shots.size(), captured])
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	quit(0 if captured >= 1 else 1)


func _capture(abs_out: String, name: String) -> Dictionary:
	await physics_frame
	await physics_frame
	var img := root.get_viewport().get_texture().get_image()
	var meta := {
		"id": name,
		"course": COURSE_ID,
		"runner": RUNNER_ID,
		"timestamp": Time.get_datetime_string_from_system(true),
	}
	if img == null:
		meta["status"] = "CAPTURE_FAILED"
		print("KINETIC_SOLE_SHOT fail %s" % name)
		return meta
	var path := abs_out.path_join("%s.png" % name)
	var err := img.save_png(path)
	meta["status"] = "CAPTURED" if err == OK else "SAVE_FAILED"
	meta["path"] = path
	print("KINETIC_SOLE_SHOT %s %s" % [meta["status"], path])
	return meta


func _write_manifest(abs_out: String, shots: Array, fail: String) -> void:
	var manifest := {
		"schema": "gunnchos.pedestrian.kinetic_sole_capture/v1",
		"course": COURSE_ID,
		"runner": RUNNER_ID,
		"direction": "KINETIC_SOLE",
		"fail": fail,
		"shots": shots,
	}
	var file := FileAccess.open(abs_out.path_join("CAPTURE_RUN.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
