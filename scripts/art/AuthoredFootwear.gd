extends Node
## Original GLB candidates. Visuals and sampled wheel pose only; no collision/stat ownership.
const ASSETS := {
 "reedline_circlers":"ReedlineCirclers", "slipstream_inlines":"SlipstreamInlines",
 "heelspin_quads":"HeelspinQuads", "cloudsole_striders":"CloudsoleStriders",
 "tidefin_runners":"TidefinRunners", "snowglobe_galoshes":"SnowglobeGaloshes",
 "beatlink_tapstep_oxfords":"BeatLinkTapstepOxfords", "sofa_surfers":"SofaSurfers"
}
## Source-space ankle center (Godot -Z at rest) and visible leg endpoint Y.
## The endpoint lies just inside each authored cuff/seat, not at the outsole.
## Shoe child translation is in holder units; its parent scale applies once.
const ANKLE_FIT := {
 "reedline_circlers":Vector2(.083,.095),
 "slipstream_inlines":Vector2(.071,.165),
 "heelspin_quads":Vector2(.078,.180),
 "cloudsole_striders":Vector2(.090,.096),
 "tidefin_runners":Vector2(.082,.085),
 "snowglobe_galoshes":Vector2(.073,.198),
 "beatlink_tapstep_oxfords":Vector2(.080,.067),
 "sofa_surfers":Vector2(.045,.055)
}
## Actual rest-pose GLB bounds from EXPORTED_GLB_INSPECTION.json; meters, Y-up.
const SOURCE_BOTTOM_Y := {
 "reedline_circlers":-.059598077,
 "slipstream_inlines":-.060000008,
 "heelspin_quads":-.060000011,
 "cloudsole_striders":-.060000002,
 "tidefin_runners":-.059437320,
 "snowglobe_galoshes":-.060000002,
 "beatlink_tapstep_oxfords":-.059999999,
 "sofa_surfers":-.059864253
}
var _body: Node3D
var _animation: AnimationPlayer
var _clip := ""
var _phase := 0.0
var _circumference := 1.0

static func mount(leg:Node3D,id:String,left:bool,leg_len:float,ws:float,shoe_scale:float,body:Node3D)->MeshInstance3D:
	if OS.get_cmdline_user_args().has("--baseline-footwear"):return null
	if not ASSETS.has(id):return null
	var path := "res://assets/models/footwear/wave1/%s.glb" % ASSETS[id]
	var scene:=load(path) as PackedScene
	if scene==null:return null
	var holder:=MeshInstance3D.new();holder.name="AuthoredSoleLeft" if left else "AuthoredSoleRight"
	holder.scale=Vector3(ws,1,1)*shoe_scale*1.2
	var support:=_capsule_support_in_visual(leg.get_parent() as Node3D,body)
	var contact_y:float=support.contact_y
	var source_bottom:float=SOURCE_BOTTOM_Y[id]
	# New leg pivots are unrotated when attached. Match the source outsole to the
	# actual collider's support plane, not the legacy hip-minus-leg-length origin.
	holder.position=Vector3(0,contact_y-leg.position.y-source_bottom*holder.scale.y,0)
	holder.set_meta("vehicle_id",id);holder.set_meta("asset_path",path)
	holder.set_meta("art_status","runtime_candidate_pending_visual_review")
	holder.set_meta("support_contact_visual_y",contact_y)
	holder.set_meta("support_source",support.source)
	holder.set_meta("support_shape_path",support.get("shape_path",""))
	holder.set_meta("source_bottom_y_m",source_bottom)
	holder.set_meta("scaled_source_bottom_y_m",source_bottom*holder.scale.y)
	holder.set_meta("rest_sole_visual_y",leg.position.y+holder.position.y+source_bottom*holder.scale.y)
	holder.set_meta("legacy_leg_length_m",leg_len)
	leg.add_child(holder)
	var model:=scene.instantiate() as Node3D
	if model==null:
		holder.queue_free()
		return null
	var fit:Vector2=ANKLE_FIT[id]
	model.position.z=fit.x
	holder.add_child(model)
	holder.set_meta("ankle_anchor_source_m",fit.x)
	holder.set_meta("visible_leg_end_source_y",fit.y)
	_trim_visible_leg(leg,holder.position.y+fit.y*holder.scale.y)
	var mixer:=_find_animation(model)
	if mixer!=null and id in ["slipstream_inlines","heelspin_quads"]:
		var driver = load("res://scripts/art/AuthoredFootwear.gd").new()
		driver.name="SpeedBoundWheelPose";driver._body=body;driver._animation=mixer
		var radius:=.0365 if id=="slipstream_inlines" else .034
		driver._circumference=TAU*radius*holder.scale.y
		for clip in mixer.get_animation_list():
			if str(clip).ends_with("WheelSpin"):
				driver._clip=str(clip);mixer.play(clip);mixer.pause();mixer.seek(0,true);break
		holder.add_child(driver)
		holder.set_meta("wheel_clip",driver._clip)
	return holder

static func _capsule_support_in_visual(visual:Node3D,body:Node3D)->Dictionary:
	var result:Dictionary={"contact_y":0.0,"source":"menu_visual_floor_y_zero"}
	if not is_instance_valid(body) or not is_instance_valid(visual):
		return result
	result.source="no_enabled_body_capsule_visual_floor_y_zero"
	var found:=false
	for child in body.get_children():
		var collider:=child as CollisionShape3D
		if collider==null or collider.disabled:
			continue
		var capsule:=collider.shape as CapsuleShape3D
		if capsule==null:
			continue
		var local:=Transform3D.IDENTITY
		var transform_source:="direct_body_sibling_local_transform"
		if visual.get_parent()==body:
			# Normal runtime and off-tree preview construction share this hierarchy.
			local=visual.transform.affine_inverse()*collider.transform
		elif visual.is_inside_tree() and collider.is_inside_tree():
			local=visual.global_transform.affine_inverse()*collider.global_transform
			transform_source="in_tree_global_relative_transform"
		else:
			if not found:result.source="unsupported_offtree_transform_visual_floor_y_zero"
			continue
		# Support of a capsule segment plus its end spheres along visual -Y.
		# This includes the collider's offset/basis and the visual's transform.
		var segment_half:=maxf(capsule.height*.5-capsule.radius,0.0)
		var sphere_extent:=capsule.radius*Vector3(local.basis.x.y,local.basis.y.y,local.basis.z.y).length()
		var bottom:=local.origin.y-absf(local.basis.y.y)*segment_half-sphere_extent
		if not found or bottom<float(result.contact_y):
			found=true
			result={"contact_y":bottom,"source":"enabled_body_capsule_bottom",
				"shape_path":str(collider.get_path()) if collider.is_inside_tree() else str(collider.name),
				"transform_source":transform_source,"capsule_height":capsule.height,
				"capsule_radius":capsule.radius}
	return result

static func _trim_visible_leg(leg:Node3D,bottom:float)->void:
	# Preserve the shoulder/hip pivot and original cylinder top. Only this visible
	# cosmetic cylinder changes; the controller and all collision shapes stay intact.
	for child in leg.get_children():
		var limb:=child as MeshInstance3D
		if limb==null:
			continue
		var source:=limb.mesh as CylinderMesh
		if source==null:
			continue
		if limb.scale.y<=0.0:
			return
		var top:=limb.position.y+source.height*limb.scale.y*.5
		var endpoint:=minf(bottom,top-.01)
		var trimmed:=source.duplicate() as CylinderMesh
		trimmed.height=(top-endpoint)/limb.scale.y
		limb.mesh=trimmed
		limb.position.y=(top+endpoint)*.5
		limb.set_meta("authored_footwear_leg_trim",true)
		limb.set_meta("unchanged_visible_leg_top",top)
		limb.set_meta("visible_leg_endpoint",endpoint)
		return

static func _find_animation(node:Node)->AnimationPlayer:
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var found:=_find_animation(child)
		if found!=null:return found
	return null

func _process(delta:float)->void:
	if _animation==null or _clip.is_empty():return
	var access:=get_tree().root.get_node_or_null("AccessibilitySettings")
	var allow_motion:=true
	if access!=null:allow_motion=not bool(access.get("reduce_motion"))
	if not allow_motion:
		_phase=0;_animation.seek(0,true);return
	if not is_instance_valid(_body):return
	var velocity:Vector3=_body.get("velocity")
	var speed:=Vector2(velocity.x,velocity.z).length()
	if speed<.03:return
	_phase=fposmod(_phase+speed*delta/maxf(_circumference,.001),1.0)
	_animation.seek(_phase*_animation.get_animation(_clip).length,true)
