extends SceneTree
## Actual RaceScene captures; never an acceptance driver or release flag setter.
var output := ""
var stage := "before"
var ids: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
		if arg.begins_with("--courses="):
			for id in arg.trim_prefix("--courses=").split(","): ids.append(id)
	call_deferred("run")
func shot(file: String) -> int:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(output.path_join(file))
func run() -> void:
	if output.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	var gm := root.get_node("GameManager")
	if ids.is_empty():
		var catalog := load("res://scripts/data/TrackCatalog.gd")
		for cup in catalog.list_cup_ids():
			for id in catalog.load_cup(cup).get("track_ids", []): ids.append(str(id))
	var packed := load("res://scenes/race/RaceScene.tscn") as PackedScene
	var results: Array = []
	for id in ids:
		gm.selected_runner_id = "dash_reed"
		gm.selected_racer_id = "dash_reed"
		gm.selected_shoe_id = "voltstep_coils"
		gm.accept_test_mode = false
		gm.accept_force_laps = 0
		gm.auto_accelerate = false
		gm.start_single_race(id)
		gm.ai_field_size = 1
		var scene := packed.instantiate()
		root.add_child(scene)
		current_scene = scene
		for f in range(210): await physics_frame
		var player: Node3D = scene.get_node("PlayerRacer")
		var start := player.global_position
		var samples: Array = []
		for f in range(45):
			Input.action_press("accelerate")
			var t := Time.get_ticks_usec()
			await physics_frame
			samples.append((Time.get_ticks_usec()-t)/1000.0)
		Input.action_release("accelerate")
		var camera := root.get_camera_3d()
		var err := await shot(stage+"_"+id+"_chase.png")
		var course: Dictionary = scene.get("course_data")
		var points: Array = course.get("path_points", [])
		var center := Vector3.ZERO
		for p in points: center += Vector3(float(p[0]),float(p[1]),float(p[2]))
		center /= maxf(points.size(),1)
		var overview := Camera3D.new()
		scene.add_child(overview)
		overview.global_position = center+Vector3(20,80,88)
		overview.look_at(center,Vector3.UP)
		overview.fov = 57
		overview.current = true
		for f in range(3): await process_frame
		var overview_err := await shot(stage+"_"+id+"_overview.png")
		if camera != null: camera.current = true
		samples.sort()
		results.append({"course":id,"scene":scene.scene_file_path,"chase_error":err,"overview_error":overview_err,"distance_m":player.global_position.distance_to(start),"player_position":player.global_position,"chase_camera":camera.global_transform if camera else null,"frame_ms_median":samples[samples.size()/2],"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		print("ART_CAPTURE ",stage," ",id," distance=",results[-1]["distance_m"])
		current_scene = null
		scene.queue_free()
		for f in range(4): await process_frame
	var file := FileAccess.open(output.path_join(stage+"_RUNTIME.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Actual native RaceScene; ordinary input, gameplay camera plus declared overview, not human acceptance","stage":stage,"engine":Engine.get_version_info(),"user_data":OS.get_user_data_dir(),"courses":results,"HUMAN":false,"RC2":false,"V1":false},"  "));file.close()
	quit(0)
