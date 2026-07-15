extends SceneTree

## Visible (non-headless) runner character review capture for all eight roster runners.
## Do not pass --headless — screenshots require a real display renderer.
##
## Usage:
##   ~/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot \
##     --path . -s res://tests/accept_character_review.gd
##
## Output: user://character_review/ → copy into docs/character-design/pedestrian-character-review/

const OUT := "user://character_review"
const _RunnerProfile = preload("res://scripts/data/RunnerProfile.gd")
const _RacerVisual = preload("res://scripts/player/RacerVisual.gd")

const YAWS := [
	{"name": "front", "yaw": 0.0},
	{"name": "side", "yaw": 90.0},
	{"name": "back", "yaw": 180.0},
	{"name": "three-quarter", "yaw": -35.0},
]


func _init() -> void:
	call_deferred("_run")


func _log(msg: String) -> void:
	print("[character_review] %s" % msg)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _ensure_out() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if img == null:
		_log("WARN shot failed %s" % name)
		return
	var path := "%s/%s.png" % [OUT, name]
	var err := img.save_png(path)
	_log("shot %s err=%s" % [name, str(err)])


func _run() -> void:
	_ensure_out()
	DisplayServer.window_set_title("Pedestrian Pursuit — Character Review Capture")
	get_root().size = Vector2i(1280, 720)

	var world := Node3D.new()
	world.name = "ReviewWorld"
	root.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	light.light_energy = 1.15
	world.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.4, 1.8, 2.0)
	fill.light_energy = 0.5
	world.add_child(fill)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.12, 0.14, 0.12)
	floor_mesh.material_override = floor_mat
	world.add_child(floor_mesh)

	var cam := Camera3D.new()
	cam.position = Vector3(1.4, 1.35, 2.6)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.current = true
	world.add_child(cam)

	var hud := CanvasLayer.new()
	root.add_child(hud)
	var caption := Label.new()
	caption.position = Vector2(24, 24)
	caption.add_theme_font_size_override("font_size", 22)
	hud.add_child(caption)

	var roster: Array = _RunnerProfile.load_roster()
	if roster.size() < 8:
		_log("FAIL expected 8 runners got %d" % roster.size())
		quit(1)
		return

	# Group roster — eight side-by-side along X
	var group_root := Node3D.new()
	group_root.name = "RosterGroup"
	world.add_child(group_root)
	var group_visuals: Array = []
	for i in roster.size():
		var profile = roster[i]
		var visual := Node3D.new()
		visual.set_script(_RacerVisual)
		visual.name = "Runner_%s" % str(profile.id)
		visual.position = Vector3(-3.15 + i * 0.9, 0, 0)
		group_root.add_child(visual)
		visual.call("apply_profile", profile)
		visual.call("set_menu_preview", true)
		group_visuals.append(visual)
		await _wait(0.03)

	cam.position = Vector3(0.0, 1.6, 6.2)
	cam.look_at(Vector3(0, 0.85, 0))
	caption.text = "Roster — eight stylized production runners (rear-readable)"
	await _wait(0.9)
	await _shot("00-roster-group")
	# Second view for rear silhouette identity
	cam.position = Vector3(0.0, 1.5, -5.4)
	cam.look_at(Vector3(0, 0.85, 0))
	caption.text = "Roster — rear chase-camera identity"
	await _wait(0.7)
	await _shot("00-roster-group-rear")

	for v in group_visuals:
		v.queue_free()
	group_visuals.clear()
	await _wait(0.15)

	# Solo stage
	cam.position = Vector3(1.35, 1.35, 2.55)
	cam.look_at(Vector3(0, 0.95, 0))

	var failed := 0
	for profile in roster:
		var rid := str(profile.id)
		var display := str(profile.display_name)
		_log("capturing %s" % display)

		var visual := Node3D.new()
		visual.set_script(_RacerVisual)
		visual.name = "Solo_%s" % rid
		world.add_child(visual)
		visual.call("apply_profile", profile)
		visual.call("set_menu_preview", true)

		for yaw in YAWS:
			visual.rotation_degrees.y = float(yaw["yaw"])
			caption.text = "%s — turnaround %s" % [display, str(yaw["name"])]
			await _wait(0.35)
			await _shot("%s-turnaround-%s" % [rid, str(yaw["name"])])

		visual.rotation_degrees.y = -25.0
		caption.text = "%s — idle preview" % display
		await _wait(0.45)
		await _shot("%s-picker-idle" % rid)

		visual.call("play_start_line")
		caption.text = "%s — start-line personality" % display
		await _wait(0.7)
		await _shot("%s-start" % rid)

		visual.call("set_boosting", true)
		caption.text = "%s — boost" % display
		await _wait(0.55)
		await _shot("%s-boost" % rid)
		visual.call("set_boosting", false)

		visual.call("play_stumble")
		caption.text = "%s — stumble" % display
		await _wait(0.55)
		await _shot("%s-stumble" % rid)

		visual.call("play_recovery")
		caption.text = "%s — recovery" % display
		await _wait(0.55)
		await _shot("%s-recovery" % rid)

		visual.call("play_finish", true)
		caption.text = "%s — finish / podium pose" % display
		await _wait(0.7)
		await _shot("%s-finish" % rid)
		await _shot("%s-freeze" % rid)

		# Gait oscillation stills (menu preview keeps a light swing; label as review stills)
		visual.call("set_menu_preview", true)
		visual.call("set_pose_state", "run", 2.0)
		for frame_i in 6:
			caption.text = "%s — gait/3s frame %d/6" % [display, frame_i + 1]
			await _wait(0.5)
			await _shot("%s-gait-%02d" % [rid, frame_i + 1])
			await _shot("%s-three-second-%02d" % [rid, frame_i + 1])

		visual.queue_free()
		await process_frame

	# Character picker scene if available
	if ResourceLoader.exists("res://scenes/main/MainMenu.tscn"):
		change_scene_to_file("res://scenes/main/MainMenu.tscn")
		await _wait(1.5)
		caption = null
		await _shot("99-character-picker-main-menu")

	_log("DONE failed=%d out=%s" % [failed, ProjectSettings.globalize_path(OUT)])
	quit(0 if failed == 0 else 1)
