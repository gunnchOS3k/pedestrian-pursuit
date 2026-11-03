extends SceneTree
## Declared outfit fixture using the real race scene and production outfit API.
## Does not unlock, save, teleport or claim the creator UI journey.
const IDS := ["metro_pulse_outer","harbor_linen_outer","neon_track_outer","midnight_outer","orbit_outer","archive_cardigan"]
const Catalog = preload("res://scripts/data/WardrobeCatalog.gd")
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
func run()->void:
	if out.is_empty() or ids.is_empty():quit(2);return
	for id in ids:
		if id not in IDS:quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var gm:=root.get_node("GameManager")
	var packed:=load("res://scenes/race/RaceScene.tscn") as PackedScene
	var rows:Array=[];var failures:Array=[]
	for id in ids:
		gm.selected_runner_id="dash_reed";gm.selected_racer_id="dash_reed";gm.selected_shoe_id="reedline_circlers"
		gm.accept_test_mode=false;gm.accept_force_laps=0;gm.auto_accelerate=false
		gm.start_single_race("sneaker_city_sprintway");gm.ai_field_size=0
		var scene:=packed.instantiate();root.add_child(scene);current_scene=scene
		for f in range(210):await physics_frame
		var player:CharacterBody3D=scene.get_node("PlayerRacer")
		var visual:Node3D=player.get_node("RacerVisual")
		var collision:CollisionShape3D=player.get_node("CollisionShape3D")
		var collision_before:=var_to_str(collision.shape)+var_to_str(collision.transform)
		var slots:Dictionary=Catalog.preset("metro_pulse_default").get("slots",{}).duplicate(true)
		slots.outerwear=id
		visual.apply_wardrobe_outfit(slots)
		await process_frame
		var sleeves:Array=visual.find_children("AtelierSleeve*","MeshInstance3D",true,false)
		var pose_before:Array=[]
		for sleeve in sleeves:pose_before.append(var_to_str(sleeve.get_parent().quaternion))
		var start:=player.global_position
		var moved_sleeve:=false
		for f in range(45):
			Input.action_press("accelerate");await physics_frame
			var pose:Array=[]
			for sleeve in sleeves:pose.append(var_to_str(sleeve.get_parent().quaternion))
			if pose!=pose_before:moved_sleeve=true
		Input.action_release("accelerate")
		var garment:=visual.find_child("Atelier_"+id,true,false) as MeshInstance3D
		var row:Dictionary={"id":id,"fixture":"Actual race scene, selected catalog outfit through production apply_wardrobe_outfit; no creator UI journey claim","chase_capture":await shot(stage+"_"+id+"_chase"),"distance_m":player.global_position.distance_to(start),"authored_mount":garment!=null,"sleeves":sleeves.size(),"shoulder_rotations_change":moved_sleeve,"sleeves_parented_to_shoulders":sleeves.all(func(sleeve):return sleeve.get_parent() in [visual.get("_arm_l"),visual.get("_arm_r")]),"collision_preserved":collision_before==var_to_str(collision.shape)+var_to_str(collision.transform)}
		if stage=="after":
			if garment==null or garment.mesh==null:failures.append(id+": missingauthoredmesh")
			else:
				row.surfaces=garment.mesh.get_surface_count();row.triangles=garment.mesh.get_faces().size()/3
				row.collision_objects=garment.find_children("*","CollisionObject3D",true,false).size()
				row.materials=[]
				for s in range(garment.mesh.get_surface_count()):
					var material:=garment.mesh.surface_get_material(s) as StandardMaterial3D
					if material==null:failures.append(id+": missingmaterial")
					else:row.materials.append(str(material.albedo_color))
			if sleeves.size()!=2 or not moved_sleeve or not row.sleeves_parented_to_shoulders:failures.append(id+": sleeveattachment")
		if not row.collision_preserved or row.distance_m<=0 or row.chase_capture!=OK:failures.append(id+": behaviororcapturecontract")
		paused=true
		var old_cam:=root.get_camera_3d()
		var camera:=Camera3D.new();camera.near=.02;camera.fov=34;scene.add_child(camera)
		camera.global_position=player.global_transform*Vector3(1.35,1.3,2.5)
		camera.look_at(player.global_transform*Vector3(0,.8,0),Vector3.UP);camera.current=true
		for f in range(4):await process_frame
		row.front_capture=await shot(stage+"_"+id+"_front")
		camera.global_position=player.global_transform*Vector3(-1.3,1.2,-2.5)
		camera.look_at(player.global_transform*Vector3(0,.8,0),Vector3.UP)
		for f in range(4):await process_frame
		row.back_capture=await shot(stage+"_"+id+"_back")
		if row.front_capture!=OK or row.back_capture!=OK:failures.append(id+": inspectioncapture")
		if old_cam:old_cam.current=true
		paused=false
		rows.append(row);write_receipt(rows,failures);print("WARDROBE_RUNTIME ",stage," ",id," moved=",row.distance_m)
		current_scene=null;scene.queue_free()
		for f in range(4):await process_frame
	write_receipt(rows,failures)
	quit(0 if failures.is_empty() else 1)

func write_receipt(rows:Array,failures:Array)->void:
	var file:=FileAccess.open(out.path_join("RUNTIME.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete":rows.size()==ids.size(),"requested_ids":ids,"stage":stage,"engine":Engine.get_version_info(),"rows":rows,"failures":failures,"pass":failures.is_empty() and rows.size()==ids.size(),"HUMAN":false,"RC2":false,"V1":false},"  "));file.close()
