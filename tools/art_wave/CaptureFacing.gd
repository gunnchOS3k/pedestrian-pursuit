extends SceneTree
## Normal input in the actual race, plus declared negative/visual-effect fixtures.
var out := ""
var vehicle := "slipstream_inlines"
var garment := "metro_pulse_outer"
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):out=arg.trim_prefix("--output=")
		if arg.begins_with("--vehicle="):vehicle=arg.trim_prefix("--vehicle=")
		if arg.begins_with("--garment="):garment=arg.trim_prefix("--garment=")
	call_deferred("run")
func horizontal(v:Vector3)->Vector3:return Vector3(v.x,0,v.z).normalized()
func contract(body:CharacterBody3D)->Dictionary:
	var collider:=body.get_node("CollisionShape3D") as CollisionShape3D
	var shape:=collider.shape as CapsuleShape3D
	return {"body":var_to_str(body.global_transform),"velocity":var_to_str(body.velocity),"capsule_transform":var_to_str(collider.transform),"height":shape.height,"radius":shape.radius,"layer":body.collision_layer,"mask":body.collision_mask}
func shot(name:String)->int:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(out.path_join(name+".png"))
func run()->void:
	if out.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(out);await process_frame
	var gm:=root.get_node("GameManager")
	gm.selected_runner_id="dash_reed";gm.selected_racer_id="dash_reed";gm.selected_shoe_id=vehicle
	gm.accept_test_mode=false;gm.accept_force_laps=0;gm.auto_accelerate=false
	gm.start_single_race("sneaker_city_sprintway");gm.ai_field_size=0
	var packed:=load("res://scenes/race/RaceScene.tscn") as PackedScene
	var scene:=packed.instantiate() as Node3D;root.add_child(scene);current_scene=scene
	for f in range(210):await physics_frame
	var body:=scene.get_node("PlayerRacer") as CharacterBody3D
	var visual:=body.get_node("RacerVisual") as Node3D
	var slots:Dictionary=preload("res://scripts/data/WardrobeCatalog.gd").preset("metro_pulse_default").get("slots",{}).duplicate(true)
	slots.outerwear=garment;visual.apply_wardrobe_outfit(slots)
	var start:=body.global_position
	for f in range(45):Input.action_press("accelerate");await physics_frame
	var movement:=horizontal(body.velocity)
	var face_dot:=horizontal(visual.global_basis.z).dot(movement)
	var before:=contract(body)
	var yaw:=visual.rotation.y;visual.rotation.y=0.0
	var negative_dot:=horizontal(visual.global_basis.z).dot(movement)
	visual.rotation.y=yaw
	var body_unchanged:=before==contract(body)
	var effects:Array=[]
	for child in visual.find_children("*","GPUParticles3D",true,false):
		var particles:=child as GPUParticles3D
		var material:=particles.process_material as ParticleProcessMaterial
		if material==null:continue
		effects.append({"path":str(visual.get_path_to(child)),"direction_behind_dot":horizontal(particles.global_basis*material.direction).dot(-movement),"spawn_behind_dot":horizontal(particles.global_position-body.global_position).dot(-movement)})
	var data:Dictionary={"vehicle":vehicle,"garment":garment,"engine":Engine.get_version_info(),"scope":"Actual RaceScene ordinary accelerate; unrotated negative control changes only visual yaw. Boost screenshot invokes visual API only, not earned gameplay boost. Paused front inspection is declared.","distance_m":body.global_position.distance_to(start),"velocity":str(body.velocity),"face_aligned_with_actual_velocity":face_dot,"unrotated_negative_control":negative_dot,"body_capsule_velocity_unchanged_by_visual_negative":body_unchanged,"effects":effects,"chase_capture":await shot("chase")}
	visual.set_boosting(true)
	for f in range(12):await physics_frame
	var torso:=visual.get("_torso") as Node3D
	data.boost_visual_fixture_forward_lean=horizontal(torso.global_basis.y).dot(horizontal(body.velocity))
	data.boost_visual_fixture_capture=await shot("boost-visual-FIXTURE")
	visual.set_boosting(false);Input.action_release("accelerate")
	paused=true
	var camera:=Camera3D.new();camera.near=.02;camera.fov=34;scene.add_child(camera)
	camera.global_position=visual.global_transform*Vector3(1.35,1.3,2.5)
	camera.look_at(visual.global_transform*Vector3(0,.8,0),Vector3.UP);camera.current=true
	for f in range(4):await process_frame
	data.front_inspection_capture=await shot("front-inspection")
	var saved:=contract(body)
	visual.set_menu_preview(true)
	data.preview_source_front_preserved=visual.basis.z.is_equal_approx(Vector3.BACK)
	visual.set_menu_preview(false)
	data.racer_front_restored=horizontal(visual.global_basis.z).dot(movement)>.8
	data.body_unchanged_by_preview_toggle=saved==contract(body)
	paused=false
	var failures:Array=[]
	if face_dot<.8 or negative_dot>-.8 or not body_unchanged:failures.append("travel_axis_contract")
	if data.boost_visual_fixture_forward_lean<.8:failures.append("boost_visual_lean")
	if effects.size()<3:failures.append("missing_effect_emitters")
	for effect in effects:
		if effect.direction_behind_dot<.8 or effect.spawn_behind_dot<.8:failures.append("forward_effect:"+effect.path)
	if not data.preview_source_front_preserved or not data.racer_front_restored or not data.body_unchanged_by_preview_toggle:failures.append("preview_contract")
	if data.chase_capture!=OK or data.boost_visual_fixture_capture!=OK or data.front_inspection_capture!=OK:failures.append("capture")
	data.failures=failures;data.pass=failures.is_empty();data.HUMAN=false;data.RC2=false;data.V1=false
	current_scene=null;scene.queue_free()
	for f in range(6):await process_frame
	var file:=FileAccess.open(out.path_join("RUNTIME.json"),FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "));file.close()
	print("RACING_FACING_RUNTIME_COMPLETE pass=",data.pass," failures=",failures)
	quit(0 if failures.is_empty() else 1)
