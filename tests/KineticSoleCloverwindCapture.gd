extends SceneTree

## Captures Cloverwind Ranch + Mira Lane from the real RaceScene path.
## Rejects near-black early frames. Prefer xvfb (Gate 1).

const OUT_DIR := "res://artifacts/kinetic_sole_cloverwind"
const COURSE_ID := "cloverwind_ranch"
const RUNNER_ID := "mira_lane"
const MIN_MEAN_LUMA := 18.0


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
				"Before this Kinetic Sole pass, Cloverwind used four hay cylinders and two timber crosses. No barn collision, mud read, windmill, or Grip Green footwear stack.\n"
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
	for _i in 240:
		await physics_frame
		if (
			scene.get_node_or_null("CourseTrack") != null
			and scene.get_node_or_null("PlayerRacer") != null
			and scene.get_node_or_null("CourseTrack/WorldEnvironment") != null
		):
			break
	## Extra settle so the first PNG is not a black clear-color frame.
	for _i in 30:
		await process_frame
		await physics_frame
	var player := scene.get_node_or_null("PlayerRacer")
	var cam: Camera3D = null
	var rig := scene.get_node_or_null("CameraRig")
	if rig != null:
		cam = rig.get_node_or_null("Camera3D") as Camera3D
	if cam != null:
		cam.current = true
	_add_footwear_rim(player)
	var shots: Array = []
	shots.append(await _capture(abs_out, "01_cloverwind_boot_or_countdown"))
	if player != null and cam != null:
		## Footwear close-up: drop chase cam toward the Kinetic Sole stack.
		cam.global_position = player.global_position + Vector3(1.1, 0.85, 2.4)
		cam.look_at(player.global_position + Vector3(0.0, 0.35, 0.0), Vector3.UP)
		cam.current = true
		for _i in 8:
			await process_frame
		shots.append(await _capture(abs_out, "02_mira_lane_sole_closeup"))
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
	shots.append(await _capture(abs_out, "03_cloverwind_in_motion"))
	Input.action_release("accelerate")
	if cam != null:
		cam.global_position = Vector3(-18.0, 14.0, 28.0)
		cam.look_at(Vector3(-2.0, 3.0, 14.0), Vector3.UP)
		cam.current = true
		await physics_frame
		await physics_frame
		shots.append(await _capture(abs_out, "04_barn_windmill_landmark"))
	_write_manifest(abs_out, shots, "")
	var captured := 0
	for s in shots:
		if str(s.get("status", "")) == "CAPTURED":
			captured += 1
	print(
		"KINETIC_SOLE_CAPTURE course=%s runner=%s shots=%d captured=%d"
		% [COURSE_ID, RUNNER_ID, shots.size(), captured]
	)
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	quit(0 if captured >= 2 else 1)


func _add_footwear_rim(player: Node) -> void:
	if player == null:
		return
	var rim := OmniLight3D.new()
	rim.name = "KineticSoleRim"
	rim.light_energy = 3.2
	rim.light_color = Color(1.0, 0.95, 0.85)
	rim.omni_range = 6.0
	rim.position = Vector3(0.4, 0.55, 1.2)
	player.add_child(rim)


func _capture(abs_out: String, name: String) -> Dictionary:
	var meta := {
		"id": name,
		"course": COURSE_ID,
		"runner": RUNNER_ID,
		"timestamp": Time.get_datetime_string_from_system(true),
	}
	var img: Image = null
	for attempt in range(8):
		await process_frame
		await physics_frame
		await process_frame
		img = root.get_viewport().get_texture().get_image()
		if img == null:
			continue
		var luma := _mean_luma(img)
		meta["mean_luma"] = luma
		meta["attempt"] = attempt + 1
		if luma >= MIN_MEAN_LUMA:
			break
		print("KINETIC_SOLE_SHOT black_retry %s luma=%.1f" % [name, luma])
		img = null
	if img == null:
		meta["status"] = "CAPTURE_FAILED"
		print("KINETIC_SOLE_SHOT fail %s" % name)
		return meta
	var path := abs_out.path_join("%s.png" % name)
	var err := img.save_png(path)
	meta["status"] = "CAPTURED" if err == OK else "SAVE_FAILED"
	meta["path"] = path
	print("KINETIC_SOLE_SHOT %s %s luma=%.1f" % [meta["status"], path, float(meta.get("mean_luma", 0.0))])
	return meta


func _mean_luma(img: Image) -> float:
	## Sample a coarse grid — black clear frames average near 0.
	var w := img.get_width()
	var h := img.get_height()
	if w < 4 or h < 4:
		return 0.0
	var total := 0.0
	var count := 0
	var step_x := maxi(1, w / 16)
	var step_y := maxi(1, h / 16)
	for y in range(0, h, step_y):
		for x in range(0, w, step_x):
			var c := img.get_pixel(x, y)
			total += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			count += 1
	return (total / float(count)) * 255.0 if count > 0 else 0.0


func _write_manifest(abs_out: String, shots: Array, fail: String) -> void:
	var manifest := {
		"schema": "gunnchos.pedestrian.kinetic_sole_capture/v1",
		"course": COURSE_ID,
		"runner": RUNNER_ID,
		"direction": "KINETIC_SOLE",
		"fail": fail,
		"shots": shots,
	}
	var f := FileAccess.open(abs_out.path_join("CAPTURE_RUN.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(manifest, "\t"))
