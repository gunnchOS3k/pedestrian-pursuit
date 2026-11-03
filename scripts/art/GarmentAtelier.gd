extends RefCounted
## Original shaped outerwear source. Runtime fit/motion and visual review pending.
## Cosmetic meshes only; never changes bodies, outfit selections, collision or stats.

const SUPPORTED := {
	"metro_pulse_outer": "windshell",
	"harbor_linen_outer": "linen",
	"neon_track_outer": "track",
	"midnight_outer": "tailcoat",
	"orbit_outer": "mantle",
	"archive_cardigan": "cardigan",
}


static func attach(visual: Node3D, g: Dictionary, hs: float, ws: float) -> bool:
	var id := str(g.get("id", ""))
	if not SUPPORTED.has(id) or str(g.get("slot", "")) != "outerwear":
		return false
	if not is_instance_valid(visual) or int(visual.get("visual_lod")) >= 2:
		return false
	if not is_finite(hs) or not is_finite(ws) or hs <= 0.0 or ws <= 0.0:
		return false
	var torso := visual.get("_torso") as MeshInstance3D
	if torso == null or torso.mesh == null:
		return false
	var node_name := "Atelier_" + id
	if torso.get_node_or_null(NodePath(node_name)) != null:
		return true
	var box: AABB = torso.mesh.get_aabb()
	if box.size.x < 0.01 or box.size.y < 0.01 or box.size.z < 0.01:
		return false
	# Mesh-local space follows the actual torso's animated transform. Measure the
	# selected inner layers too: WardrobeRoot overlays do not inherit that animation.
	var fit := {"rx": box.size.x * 0.5 + 0.034 * ws,
		"rz": box.size.z * 0.5 + 0.034 * ws,
		"h": box.size.y, "cy": box.get_center().y,
		"cx": box.get_center().x, "cz": box.get_center().z}
	_measure_inner_layers(visual, torso, fit, hs, ws)
	var colors: Dictionary = g.get("colors", {})
	var primary := Color.from_string(str(colors.get("primary", "#34495E")), Color("34495e"))
	var accent := Color.from_string(str(colors.get("accent", "#D7CBB8")), Color("d7cbb8"))
	var style: String = SUPPORTED[id]
	var materials := {"main": _material(primary, 0.84 if style in ["linen", "cardigan"] else 0.54),
		"accent": _material(accent, 0.65),
		"facing": _material(primary.darkened(0.24), 0.78)}
	var streams := {}
	match style:
		"windshell": _windshell(streams, fit)
		"linen": _linen(streams, fit)
		"track": _track(streams, fit)
		"tailcoat": _tailcoat(streams, fit)
		"mantle": _mantle(streams, fit)
		"cardigan": _cardigan(streams, fit)
	var garment := _finish(streams, materials, node_name)
	garment.set_meta("garment_id", id)
	garment.set_meta("source_family", g.get("family_id", ""))
	garment.set_meta("asset_status", "original_native_mesh_candidate_runtime_review_pending")
	garment.set_meta("cosmetic_only", true)
	garment.set_meta("torso_aabb", box)
	garment.set_meta("measured_inner_layers", fit.layer_sources)
	garment.set_meta("layer_sample_count", fit.layer_sample_count)
	garment.set_meta("layer_vertical_clearance_m", fit.layer_vertical_clearance)
	garment.set_meta("layer_radial_clearance_m", fit.layer_radial_clearance)
	garment.set_meta("human_approved", false)
	torso.add_child(garment)
	# Each sleeve follows the existing shoulder pivot rather than a static wardrobe root.
	var fraction := 0.93
	if style == "linen": fraction = 0.65
	elif style == "mantle": fraction = 0.19
	for property in ["_arm_l", "_arm_r"]:
		var arm := visual.get(property) as Node3D
		if arm != null:
			_attach_sleeve(arm, id, style, materials, ws, hs, fraction)
	return true


static func _measure_inner_layers(visual: Node3D, torso: MeshInstance3D,
		fit: Dictionary, hs: float, ws: float) -> void:
	# Only body/inner clothing is fitted. Bags, scarves, identity props, headwear,
	# particles and the selected outer garment are never swallowed or hidden.
	var layers: Array[Dictionary] = [{"mesh": torso.mesh, "transform": Transform3D.IDENTITY,
		"source": "torso"}]
	var jacket := visual.get("_jacket") as MeshInstance3D
	if jacket != null and jacket.mesh != null:
		layers.append({"mesh": jacket.mesh, "transform": jacket.transform,
			"source": "existing_body_shirt_overlay"})
	var wardrobe := visual.get("_wardrobe_root") as Node3D
	if wardrobe != null:
		var into_torso := torso.transform.affine_inverse() * wardrobe.transform
		for child in wardrobe.get_children():
			var layer := child as MeshInstance3D
			if layer != null and layer.mesh is CapsuleMesh and layer.visible:
				layers.append({"mesh": layer.mesh, "transform": into_torso * layer.transform,
					"source": "attached_inner_capsule:" + str(layer.name)})
	# 1cm slices are expanded during lookup rather than copying points into many bins.
	# The margin covers the measured top's static parent versus the torso's existing
	# +/-2cm bob and small sprint lean/roll. It is not a cloth or boost-pose guarantee.
	fit.layer_bin_size = 0.01 * hs
	fit.layer_vertical_clearance = 0.05 * hs
	fit.layer_radial_clearance = 0.014 * ws + 0.014 * hs
	fit.layer_slices = {}
	fit.layer_sources = []
	fit.layer_sample_count = 0
	for layer in layers:
		var mesh: Mesh = layer.mesh
		var transform: Transform3D = layer.transform
		fit.layer_sources.append(layer.source)
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for point in points:
				var p: Vector3 = transform * point
				var bin := int(floor(p.y / float(fit.layer_bin_size)))
				var prior: Vector2 = fit.layer_slices.get(bin, Vector2.ZERO)
				fit.layer_slices[bin] = Vector2(maxf(prior.x, absf(p.x-float(fit.cx))),
					maxf(prior.y, absf(p.z-float(fit.cz))))
				fit.layer_sample_count += 1


static func _layer_radius_at(f: Dictionary, y: float) -> Vector2:
	var center := int(floor(y / float(f.layer_bin_size)))
	var spread := int(ceil(float(f.layer_vertical_clearance) / float(f.layer_bin_size)))
	var radius := Vector2.ZERO
	for bin in range(center-spread, center+spread+1):
		var slice: Vector2 = f.layer_slices.get(bin, Vector2.ZERO)
		radius.x = maxf(radius.x, slice.x)
		radius.y = maxf(radius.y, slice.y)
	if radius != Vector2.ZERO:
		radius += Vector2.ONE * float(f.layer_radial_clearance)
	return radius


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _tri(s: Dictionary, a: Vector3, b: Vector3, c: Vector3, key := "main") -> void:
	var cross := (b - a).cross(c - a)
	if cross.length_squared() < 0.000000000001:
		return
	if not s.has(key):
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		s[key] = builder
	var st: SurfaceTool = s[key]
	for point in [a, b, c]:
		st.set_normal(cross.normalized())
		st.add_vertex(point)


static func _quad(s: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, key := "main") -> void:
	_tri(s, a, b, c, key)
	_tri(s, a, c, d, key)


static func _finish(streams: Dictionary, materials: Dictionary, name: String) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for key in streams:
		var st: SurfaceTool = streams[key]
		st.index()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[key])
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	return instance


static func _shell_radii(f: Dictionary, y: float) -> Vector2:
	var width := 1.0
	if f.has("shell_rows"):
		var rows: Array[Vector3] = f.shell_rows
		width = rows.back().y
		var fraction := (y-float(f.cy))/float(f.h)
		if fraction <= rows.front().x: width = rows.front().y
		for j in range(rows.size()-1):
			if fraction >= rows[j].x and fraction <= rows[j+1].x:
				width = lerpf(rows[j].y,rows[j+1].y,
					(fraction-rows[j].x)/(rows[j+1].x-rows[j].x))
				break
	var layer_radius := _layer_radius_at(f,y)
	return Vector2(maxf(float(f.rx)*width,layer_radius.x),
		maxf(float(f.rz),layer_radius.y))*1.018


static func _front(f: Dictionary, x: float, y: float, depth := 0.0) -> Vector3:
	var height := float(f.cy)+y*float(f.h)
	var radius := _shell_radii(f,height)
	# Trim, pockets and zipper follow the corrected shell instead of sinking into it.
	return Vector3(float(f.cx)+x*radius.x,height,
		float(f.cz)+sqrt(maxf(0.0,1.0-x*x))*radius.y+depth)


static func _line(s: Dictionary, points: Array[Vector3], radius: float, key := "accent") -> void:
	for j in range(points.size() - 1):
		var tangent := points[j + 1] - points[j]
		if tangent.length_squared() < 0.00000001: continue
		tangent = tangent.normalized()
		var u := tangent.cross(Vector3.UP)
		if u.length() < 0.01: u = Vector3.RIGHT
		u = u.normalized()
		var v := tangent.cross(u).normalized()
		for i in range(5):
			var a := TAU * i / 5.0
			var b := TAU * (i + 1) / 5.0
			var p := (u*cos(a) + v*sin(a)) * radius
			var q := (u*cos(b) + v*sin(b)) * radius
			_quad(s, points[j] + p, points[j] + q, points[j+1] + q, points[j+1] + p, key)


static func _shell(s: Dictionary, f: Dictionary, rows: Array[Vector3], tail := 0.0,
		key := "main", back_vent := false) -> void:
	# Rows are (height/torso-height, width multiplier, front-opening half-angle).
	# Retain each design's open front, neck, hem and vent. Intermediate tailored
	# rows follow the measured underlayer curve rather than cutting a chord through it.
	f.shell_rows = rows
	var levels: Array[Vector3] = []
	var tail_weights: Array[float] = []
	for j in range(rows.size()-1):
		for step in range(4):
			var t := step/4.0
			levels.append(rows[j].lerp(rows[j+1],t))
			tail_weights.append(1.0-t if j==0 else 0.0)
	levels.append(rows.back())
	tail_weights.append(0.0)
	var rings: Array = []
	for j in range(levels.size()):
		var row: Vector3 = levels[j]
		var ring: Array[Vector3] = []
		for i in range(19):
			var a := lerpf(row.z, TAU-row.z, i/18.0)
			var y := float(f.cy)+(row.x+tail*tail_weights[j]*(1.0-cos(a))*0.5)*float(f.h)
			# Polygon chords sit inside their ellipse; the shared radius helper reserves
			# that allowance and keeps front trim fitted to the same authored contour.
			var radius := _shell_radii(f,y)
			ring.append(Vector3(float(f.cx)+sin(a)*radius.x,y,float(f.cz)+cos(a)*radius.y))
		rings.append(ring)
	for j in range(levels.size()-1):
		for i in range(18):
			if back_vent and j<4 and i in [8,9]: continue
			_quad(s,rings[j][i],rings[j][i+1],rings[j+1][i+1],rings[j+1][i],key)
	var hem: Array[Vector3] = rings[0]
	_line(s,hem,0.003,"facing")
	for edge in [0,18]:
		var seam: Array[Vector3] = []
		for ring in rings: seam.append(ring[edge]+Vector3(0,0,0.002))
		_line(s,seam,0.003,"facing")


static func _panel(s: Dictionary, f: Dictionary, outline: Array[Vector2], depth: float, key: String) -> void:
	# Curved panels use the same fitted ellipse as the torso shell.
	var indices := Geometry2D.triangulate_polygon(PackedVector2Array(outline))
	for i in range(0,indices.size(),3):
		var a: Vector2 = outline[indices[i]]
		var b: Vector2 = outline[indices[i+1]]
		var c: Vector2 = outline[indices[i+2]]
		_tri(s,_front(f,a.x,a.y,depth),_front(f,b.x,b.y,depth),_front(f,c.x,c.y,depth),key)


static func _pocket(s: Dictionary, f: Dictionary, side: float, y: float, width := 0.32) -> void:
	var x := side * 0.58
	var a := _front(f, x-width*0.5, y-0.14, 0.014)
	var b := _front(f, x+width*0.5, y-0.14, 0.014)
	var c := _front(f, x+width*0.5, y+0.025, 0.014)
	var d := _front(f, x-width*0.5, y+0.025, 0.014)
	_quad(s, a,b,c,d)
	# Raised pocket front, closed bottom/sides, an actual open top and stitched lip.
	for edge in [[a,b],[b,c],[d,a]]:
		_quad(s, edge[0]-Vector3(0,0,0.012),edge[1]-Vector3(0,0,0.012),edge[1],edge[0],"facing")
	_line(s,[d,c],0.004)
	_line(s,[d,a,b,c],0.0018,"facing")


static func _zip(s: Dictionary, f: Dictionary, x: float, low: float, high: float) -> void:
	_line(s,[_front(f,x,low,0.008),_front(f,x,high,0.008)],0.003,"facing")
	for i in range(13):
		var y := lerpf(low,high,i/12.0)
		_line(s,[_front(f,x-0.018,y,0.012),_front(f,x+0.018,y,0.012)],0.0014)
	var p := _front(f,x,high-0.065,0.015)
	_line(s,[p,p+Vector3(0,-0.017,0.006),p+Vector3(0.008,-0.025,0.006)],0.003)


static func _button(s: Dictionary, center: Vector3, radius: float) -> void:
	for i in range(8):
		var a := TAU*i/8.0
		var b := TAU*(i+1)/8.0
		_tri(s,center+Vector3(0,0,0.003),center+Vector3(cos(a),sin(a),0)*radius,
			center+Vector3(cos(b),sin(b),0)*radius,"accent")


static func _windshell(s: Dictionary, f: Dictionary) -> void:
	_shell(s,f,[Vector3(-0.43,1.05,0.16),Vector3(-0.12,1.0,0.18),Vector3(0.26,1.04,0.23),Vector3(0.45,0.65,0.4)],-0.12)
	for side in [-1.0,1.0]:
		_panel(s,f,[Vector2(side*0.27,0.30),Vector2(side*0.84,0.25),Vector2(side*0.84,0.12),Vector2(side*0.26,0.19)],0.009,"accent")
		_line(s,[_front(f,side*0.7,-0.22,0.012),_front(f,side*0.42,-0.12,0.012)],0.004,"facing")
	_zip(s,f,0.18,-0.38,0.3)
	# Stand collar has two folded halves, not a closed capsule around the neck.
	for side in [-1.0,1.0]:
		_panel(s,f,[Vector2(side*0.1,0.39),Vector2(side*0.51,0.44),Vector2(side*0.41,0.54),Vector2(side*0.15,0.51)],-0.025,"main")


static func _linen(s: Dictionary, f: Dictionary) -> void:
	_shell(s,f,[Vector3(-0.68,1.17,0.33),Vector3(-0.24,1.06,0.31),Vector3(0.22,1.02,0.37),Vector3(0.43,0.72,0.5)],-0.045)
	for side in [-1.0,1.0]:
		_panel(s,f,[Vector2(side*0.26,0.33),Vector2(side*0.66,0.30),Vector2(side*0.34,0.06),Vector2(side*0.21,0.16)],0.009,"accent")
		_pocket(s,f,side,-0.32,0.37)
		_line(s,[_front(f,side*0.77,-0.54,0.004),_front(f,side*0.71,-0.02,0.005),_front(f,side*0.76,0.26,0.004)],0.0025,"facing")
	# Loose sash ends remain outside the open front without replacing the selected top.
	_panel(s,f,[Vector2(-0.82,-0.18),Vector2(-0.32,-0.21),Vector2(-0.27,-0.26),Vector2(-0.8,-0.25)],0.018,"accent")


static func _track(s: Dictionary, f: Dictionary) -> void:
	_shell(s,f,[Vector3(-0.36,1.03,0.10),Vector3(-0.14,1.0,0.10),Vector3(0.24,1.08,0.14),Vector3(0.43,0.70,0.28)])
	for side in [-1.0,1.0]:
		_panel(s,f,[Vector2(side*0.14,0.28),Vector2(side*0.8,0.27),Vector2(side*0.98,0.11),Vector2(side*0.54,0.14)],0.012,"accent")
		_panel(s,f,[Vector2(side*0.62,0.10),Vector2(side*0.85,-0.04),Vector2(side*0.78,-0.29),Vector2(side*0.58,-0.22)],0.008,"facing")
		_line(s,[_front(f,side*0.58,-0.12,0.016),_front(f,side*0.78,-0.06,0.016)],0.003,"accent")
	_zip(s,f,0.10,-0.31,0.35)
	for j in range(12):
		var x := lerpf(-0.75,0.75,j/11.0)
		_line(s,[_front(f,x,-0.35,0.004),_front(f,x,-0.30,0.004)],0.0014,"accent")


static func _tailcoat(s: Dictionary, f: Dictionary) -> void:
	_shell(s,f,[Vector3(-0.72,1.14,0.55),Vector3(-0.24,0.98,0.28),Vector3(0.20,1.03,0.26),Vector3(0.43,0.69,0.48)],-0.14,"main",true)
	for side in [-1.0,1.0]:
		_panel(s,f,[Vector2(side*0.22,0.36),Vector2(side*0.62,0.35),Vector2(side*0.43,0.22),Vector2(side*0.54,0.20),Vector2(side*0.22,-0.04)],0.014,"accent")
		_line(s,[_front(f,side*0.52,-0.27,0.012),_front(f,side*0.86,-0.24,0.012)],0.004,"accent")
		_panel(s,f,[Vector2(side*0.28,-0.23),Vector2(side*0.90,-0.31),Vector2(side*0.88,-0.70),Vector2(side*0.48,-0.77)],0.007,"main")
	for y in [-0.18,-0.02,0.14]:
		_button(s,_front(f,0.30,y,0.018),0.0045)
	# A visible center-back vent divides the tail rather than making a rigid skirt.
	var z: float = float(f.cz)-float(f.rz)-0.006
	for side in [-1.0,1.0]:
		_line(s,[Vector3(float(f.cx)+side*float(f.rx)*0.22,float(f.cy)-float(f.h)*0.25,z),
			Vector3(float(f.cx)+side*float(f.rx)*0.32,float(f.cy)-float(f.h)*0.83,z)],0.002,"facing")


static func _mantle(s: Dictionary, f: Dictionary) -> void:
	# Cropped shoulder shell above an open lower torso; six long cut cape panels.
	_shell(s,f,[Vector3(0.08,1.22,0.36),Vector3(0.30,1.18,0.4),Vector3(0.48,0.66,0.56)])
	for i in range(6):
		var origin := Vector3(float(f.cx),0,float(f.cz))
		var a := lerpf(0.72,TAU-0.72,i/5.0)
		var b := a+0.42
		var top_y: float = float(f.cy)+float(f.h)*0.19
		var bottom_y: float = float(f.cy)-float(f.h)*(0.35+0.12*sin(a))
		var p := Vector3(sin(a)*float(f.rx)*1.14,top_y,cos(a)*float(f.rz)*1.06)
		var q := Vector3(sin(b)*float(f.rx)*1.14,top_y,cos(b)*float(f.rz)*1.06)
		var r := Vector3(sin(b)*float(f.rx)*1.24,bottom_y,cos(b)*float(f.rz)*1.2)
		var t := Vector3(sin(a)*float(f.rx)*1.24,bottom_y,cos(a)*float(f.rz)*1.2)
		_quad(s,p+origin,q+origin,r+origin,t+origin,"main" if i%2==0 else "facing")
		_line(s,[p+origin,t+origin,r+origin],0.003,"accent")
	_panel(s,f,[Vector2(-0.7,0.27),Vector2(-0.22,0.36),Vector2(-0.14,0.27),Vector2(-0.6,0.18)],0.02,"accent")
	_panel(s,f,[Vector2(0.2,0.34),Vector2(0.65,0.30),Vector2(0.58,0.20),Vector2(0.16,0.25)],0.02,"accent")


static func _cardigan(s: Dictionary, f: Dictionary) -> void:
	_shell(s,f,[Vector3(-0.48,1.04,0.21),Vector3(-0.14,1.0,0.20),Vector3(0.19,1.01,0.42),Vector3(0.43,0.68,0.68)])
	for side in [-1.0,1.0]:
		var edge: Array[Vector3] = [_front(f,side*0.23,-0.44,0.012),_front(f,side*0.24,-0.05,0.012),_front(f,side*0.52,0.31,0.012)]
		_line(s,edge,0.008,"accent")
		_pocket(s,f,side,-0.26,0.3)
	for y in [-0.32,-0.17,-0.02]: _button(s,_front(f,0.24,y,0.025),0.004)
	for j in range(15):
		var x := lerpf(-0.86,0.86,j/14.0)
		if absf(x)<0.25: continue
		_line(s,[_front(f,x,-0.47,0.005),_front(f,x,-0.40,0.005)],0.0017,"accent")


static func _attach_sleeve(arm: Node3D, id: String, style: String, materials: Dictionary,
		ws: float, hs: float, fraction: float) -> void:
	var length := 0.42*hs
	var rx := 0.045*ws
	var rz := rx
	for child in arm.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var box: AABB = child.transform * child.mesh.get_aabb()
			length = box.size.y
			rx = box.size.x*0.5
			rz = box.size.z*0.5
			break
	rx += 0.012*ws
	rz += 0.012*ws
	var s := {}
	var end := -length*fraction
	var rows := [Vector2(0.012,1.12),Vector2(end*0.45,1.05),Vector2(end,0.9)]
	for j in range(rows.size()-1):
		for i in range(12):
			var a := TAU*i/12.0
			var b := TAU*(i+1)/12.0
			_quad(s,Vector3(cos(a)*rx*rows[j].y,rows[j].x,sin(a)*rz*rows[j].y),
				Vector3(cos(b)*rx*rows[j].y,rows[j].x,sin(b)*rz*rows[j].y),
				Vector3(cos(b)*rx*rows[j+1].y,rows[j+1].x,sin(b)*rz*rows[j+1].y),
				Vector3(cos(a)*rx*rows[j+1].y,rows[j+1].x,sin(a)*rz*rows[j+1].y))
	var cuff: Array[Vector3] = []
	for i in range(25):
		var a := TAU*i/24.0
		cuff.append(Vector3(cos(a)*rx*0.94,end,sin(a)*rz*0.94))
	_line(s,cuff,0.007*ws if style=="linen" else 0.004*ws,"accent")
	# Construction seams, not a detached sleeve capsule. Low LOD adds no animation.
	_line(s,[Vector3(rx,0.005,0),Vector3(rx*1.04,end*0.5,0),Vector3(rx*0.9,end,0)],0.002*ws,"facing")
	if style in ["track","windshell"]:
		_line(s,[Vector3(0,0.0,rz*1.14),Vector3(0,end*0.8,rz)],0.004*ws,"accent")
	var sleeve := _finish(s,materials,"AtelierSleeve_"+id)
	sleeve.set_meta("garment_id",id)
	sleeve.set_meta("arm_attachment","existing_shoulder_pivot")
	arm.add_child(sleeve)
