extends SceneTree
## Actual game scene, ordinary input and declared paused inspection cameras.
const IDS := ["reedline_circlers","slipstream_inlines","heelspin_quads","cloudsole_striders","tidefin_runners","snowglobe_galoshes","beatlink_tapstep_oxfords","sofa_surfers"]
var out := ""
var stage := "after"
var ids:Array=IDS.duplicate()
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):out=arg.trim_prefix("--output=")
		if arg.begins_with("--stage="):stage=arg.trim_prefix("--stage=")
		if arg.begins_with("--ids="):ids=Array(arg.trim_prefix("--ids=").split(","))
	call_deferred("run")
func shot(name:String)->int:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(out.path_join(name+".png"))
func wheels(node:Node)->Dictionary:
	var result:Dictionary={}
	for child in node.find_children("WheelSpin*","Node3D",true,false):
		# The exported pivot and its mesh share a prefix; only the animated pivot is a wheel.
		if not child is MeshInstance3D:result[str(node.get_path_to(child))]=str(child.quaternion)
	return result
func run()->void:
	if out.is_empty() or ids.is_empty():quit(2);return
	for id in ids:
		if id not in IDS:quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var gm:=root.get_node("GameManager")
	var packed:=load("res://scenes/race/RaceScene.tscn") as PackedScene
	var rows:Array=[]
	var failures:Array=[]
	for id in ids:
		gm.selected_runner_id="dash_reed";gm.selected_racer_id="dash_reed";gm.selected_shoe_id=id
		gm.accept_test_mode=false;gm.accept_force_laps=0;gm.auto_accelerate=false
		gm.start_single_race("sneaker_city_sprintway");gm.ai_field_size=0
		print("FOOTWEAR_STEP ",id," instantiate");var scene:=packed.instantiate();root.add_child(scene);current_scene=scene
		print("FOOTWEAR_STEP ",id," countdown_wait")
		for f in range(210):await physics_frame
		print("FOOTWEAR_STEP ",id," ordinary_input")
		var player:CharacterBody3D=scene.get_node("PlayerRacer")
		var visual:Node3D=player.get_node("RacerVisual")
		var initial:=wheels(visual)
		var motion:Array=[]
		var start:=player.global_position
		for f in range(45):
			Input.action_press("accelerate");await physics_frame
			if f in [5,14,25,44]:motion.append(wheels(visual))
		print("FOOTWEAR_STEP ",id," chase_capture")
		var row:Dictionary={"id":id,"scene":scene.scene_file_path,"course":"sneaker_city_sprintway","distance_m":player.global_position.distance_to(start),"initial_wheels":initial,"motion_wheels":motion,"chase_capture":await shot(stage+"_"+id+"_chase"),"draw_calls_chase":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles_chase":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
		Input.action_release("accelerate")
		var mounts:Array=visual.find_children("AuthoredSole*","MeshInstance3D",true,false)
		row["mounts"]=[]
		for mount in mounts:
			var meshes:Array=mount.find_children("*","MeshInstance3D",true,false)
			var surfaces:=0;var missing:=0
			for mesh_node in meshes:
				if mesh_node.mesh==null:continue
				for i in range(mesh_node.mesh.get_surface_count()):
					surfaces+=1
					if mesh_node.mesh.surface_get_material(i)==null:missing+=1
			row["mounts"].append({"path":str(mount.get_path()),"asset":mount.get_meta("asset_path"),"surfaces":surfaces,"missing_materials":missing,"wheel_clip":mount.get_meta("wheel_clip",""),"collision_objects":mount.find_children("*","CollisionObject3D",true,false).size(),"support_contact_visual_y":mount.get_meta("support_contact_visual_y",0.0),"support_source":mount.get_meta("support_source","legacy"),"source_bottom_y_m":mount.get_meta("source_bottom_y_m",0.0),"rest_sole_visual_y":mount.get_meta("rest_sole_visual_y",0.0),"visible_leg_end_source_y":mount.get_meta("visible_leg_end_source_y",0.0)})
		for inspected in row["mounts"]:
			if inspected.surfaces==0 or inspected.missing_materials!=0 or inspected.collision_objects!=0:failures.append(id+": materialormountcontract")
		if row.distance_m<=0 or row.chase_capture!=OK:failures.append(id+": movementorcapturecontract")
		if stage=="after" and mounts.size()!=2:failures.append(id+": expected2authoredfeet")
		if id in ["slipstream_inlines","heelspin_quads"] and stage=="after":
			var changed:=false
			for sample in motion:
				if sample!=initial:changed=true
			row["actual_wheel_pose_changed_with_motion"]=changed
			if initial.size()!=8 or not changed:failures.append(id+": wheelposebindingmissing")
		print("FOOTWEAR_STEP ",id," paused_inspection")
		paused=true
		var old_cam:=root.get_camera_3d()
		var camera:=Camera3D.new();camera.near=.015;camera.fov=34;scene.add_child(camera)
		camera.global_position=player.global_transform*Vector3(.75,.35,.78)
		camera.look_at(player.global_transform*Vector3(0,.12,.035),Vector3.UP);camera.current=true
		for f in range(4):await process_frame
		row["close_capture"]=await shot(stage+"_"+id+"_close")
		camera.global_position=player.global_transform*Vector3(.72,.85,-.68)
		camera.look_at(player.global_transform*Vector3(0,.15,.035),Vector3.UP)
		for f in range(4):await process_frame
		row["fit_capture"]=await shot(stage+"_"+id+"_fit")
		if old_cam:old_cam.current=true
		paused=false
		player.set_physics_process(false);player.velocity=Vector3.ZERO
		if id in ["slipstream_inlines","heelspin_quads"] and stage=="after":
			var stopped:=wheels(visual)
			for f in range(6):await process_frame
			row["stationary_wheels_stop"]=stopped==wheels(visual)
			var access:=root.get_node("AccessibilitySettings")
			var old:bool=access.reduce_motion
			var old_shake:bool=gm.camera_shake_enabled
			gm.camera_shake_enabled=false;access.reduce_motion=false;player.velocity=Vector3(12,0,0)
			var no_shake_before:=wheels(visual)
			for f in range(6):await process_frame
			row["camera_shake_off_wheels_move"]=no_shake_before!=wheels(visual)
			gm.camera_shake_enabled=old_shake
			access.reduce_motion=true;player.velocity=Vector3(12,0,0)
			for f in range(3):await process_frame
			var reduced:=wheels(visual)
			for f in range(6):await process_frame
			row["live_reduced_motion_wheels_stop"]=reduced==wheels(visual)
			access.reduce_motion=old;player.velocity=Vector3.ZERO
			if not row["stationary_wheels_stop"] or not row["live_reduced_motion_wheels_stop"] or not row["camera_shake_off_wheels_move"]:failures.append(id+": motionstopcontract")
		if row.close_capture!=OK or row.fit_capture!=OK:failures.append(id+": inspectioncapturecontract")
		rows.append(row)
		write_receipt(rows,failures)
		print("FOOTWEAR_RUNTIME ",stage," ",id," mounts=",mounts.size()," moved=",row.distance_m)
		current_scene=null;scene.queue_free()
		for f in range(4):await process_frame
	write_receipt(rows,failures)
	quit(0 if failures.is_empty() else 1)

func write_receipt(rows:Array,failures:Array)->void:
	var file:=FileAccess.open(out.path_join("RUNTIME.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete":rows.size()==ids.size(),"stage":stage,"requested_ids":ids,"scope":"Actual RaceScene and controlled input; paused front/back cameras declared; authorvalidation nothuman/finalartapproval","engine":Engine.get_version_info(),"rows":rows,"failures":failures,"pass":failures.is_empty() and rows.size()==ids.size(),"HUMAN":false,"RC2":false,"V1":false},"  "));file.close()
