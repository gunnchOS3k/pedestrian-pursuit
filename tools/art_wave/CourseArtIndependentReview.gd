extends SceneTree
## Distinct reviewer harness. Runs real CourseTrack/build and CourseWorldArt/_install,
## then compares collision, trigger, checkpoint, path and road-deck geometry.
## This is an isolated scene fixture, NOT race completion, visual approval or device proof.
## Deliberate negative mutations exist only in this disposable fixture and are restored.
const Catalog = preload("res://scripts/data/TrackCatalog.gd")
const Track = preload("res://scripts/tracks/CourseTrack.gd")
const Art = preload("res://scripts/art/CourseWorldArt.gd")
const Relay = preload("res://scripts/art/RelayPickupArt.gd")

class ReviewHost extends Node3D:
	var course_data: Dictionary = {}

var output := ""
var results: Array = []
var failures: Array[String] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	call_deferred("run")

func _vector(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _shape(shape: Shape3D) -> Dictionary:
	if shape == null:
		return {"type": "null"}
	var value := {"type": shape.get_class(), "margin": shape.margin}
	if shape is BoxShape3D:
		value.size = _vector(shape.size)
	elif shape is CylinderShape3D or shape is CapsuleShape3D:
		value.radius = shape.radius
		value.height = shape.height
	elif shape is SphereShape3D:
		value.radius = shape.radius
	elif shape is ConvexPolygonShape3D:
		value.points = var_to_str(shape.points)
	elif shape is ConcavePolygonShape3D:
		value.faces = var_to_str(shape.get_faces())
	else:
		# Unrecognized future shapes must not silently lose their dimensions.
		failures.append("Uncovered collision shape class: " + shape.get_class())
	return value

func _walk_contract(base: Node, node: Node, rows: Dictionary) -> void:
	var key := str(base.get_path_to(node))
	var row: Dictionary = {}
	if node is CollisionObject3D:
		row = {"kind": node.get_class(), "transform": var_to_str(node.transform),
			"layer": node.collision_layer, "mask": node.collision_mask,
			"script": node.get_script().resource_path if node.get_script() != null else ""}
		if node is Area3D:
			row.monitoring = node.monitoring
			row.monitorable = node.monitorable
		if node.get("checkpoint_index") != null:
			row.checkpoint_index = node.get("checkpoint_index")
	elif node is CollisionShape3D:
		row = {"kind": "CollisionShape3D", "transform": var_to_str(node.transform),
			"disabled": node.disabled, "shape": _shape(node.shape)}
	elif node is MeshInstance3D and str(node.name) == "TrackVisual":
		row = {"kind": "road_deck", "transform": var_to_str(node.transform),
			"mesh_type": node.mesh.get_class(), "faces": var_to_str(node.mesh.get_faces()).sha256_text()}
	elif node is Path3D:
		row = {"kind": "race_path", "transform": var_to_str(node.transform),
			"point_count": node.curve.get_point_count(), "bake_interval": node.curve.bake_interval,
			"points": var_to_str(node.curve.get_baked_points()).sha256_text()}
	if not row.is_empty():
		rows[key] = row
	for child in node.get_children():
		_walk_contract(base, child, rows)

func _contract(track: Node) -> Dictionary:
	var rows := {}
	_walk_contract(track, track, rows)
	rows["@start"] = var_to_str(track.get_start_transform())
	return rows

func _first_kind(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _first_kind(child, type_name)
		if found != null:
			return found
	return null

func _first_deck(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and str(node.name) == "TrackVisual":
		return node
	for child in node.get_children():
		var found := _first_deck(child)
		if found != null:
			return found
	return null

func _physics_count(node: Node) -> int:
	var count := 1 if node is CollisionObject3D or node is CollisionShape3D else 0
	for child in node.get_children():
		count += _physics_count(child)
	return count

func _first_relay(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.get_script() == Relay:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_relay(child)
		if found != null:
			return found
	return null

func _pickup_live_motion_probe(track: Node) -> Dictionary:
	var relay := _first_relay(track)
	var accessibility := root.get_node_or_null("AccessibilitySettings")
	var manager := root.get_node_or_null("GameManager")
	if relay == null or accessibility == null or manager == null:
		return {"fixture_available": false}
	var saved_reduce: bool = accessibility.get("reduce_motion")
	var saved_shake: bool = manager.get("camera_shake_enabled")
	var saved_transform := relay.transform
	var saved_phase: float = relay.get("_phase")
	var saved_motion: bool = relay.get("_motion")
	var before := _contract(track)
	# Change only ephemeral preference fields, not their persistence/UI setters.
	# The SAME real product pickup instance must respond without scene recreation.
	accessibility.set("reduce_motion", false)
	manager.set("camera_shake_enabled", true)
	relay.call("_process", 0.2)
	var initially_moves := absf(relay.rotation.y) > 0.001 and absf(relay.position.y) > 0.001
	accessibility.set("reduce_motion", true)
	relay.call("_process", 0.2)
	var becomes_still := relay.rotation.is_zero_approx() and is_zero_approx(relay.position.y)
	relay.call("_process", 0.2)
	var stays_still := relay.rotation.is_zero_approx() and is_zero_approx(relay.position.y)
	accessibility.set("reduce_motion", false)
	relay.call("_process", 0.2)
	var resumes := absf(relay.rotation.y) > 0.001 and absf(relay.position.y) > 0.001
	accessibility.set("reduce_motion", saved_reduce)
	manager.set("camera_shake_enabled", saved_shake)
	relay.transform = saved_transform
	relay.set("_phase", saved_phase)
	relay.set("_motion", saved_motion)
	return {"fixture_available": true, "same_instance_initially_moves": initially_moves,
		"live_preference_stops_and_resets_pose": becomes_still, "remains_still": stays_still,
		"live_preference_restores_motion": resumes, "collision_and_trigger_contract_restored": before == _contract(track)}

func _nearest_lane(point: Vector3, course: Dictionary) -> Dictionary:
	var raw: Array = course.get("path_points", [])
	var best := INF
	var relative_height := INF
	var best_segment := -1
	var best_point := Vector3.ZERO
	for i in range(raw.size()):
		var a := Vector3(raw[i][0], raw[i][1], raw[i][2])
		var b_raw: Array = raw[(i + 1) % raw.size()]
		var b := Vector3(b_raw[0], b_raw[1], b_raw[2])
		var flat := Vector2(b.x-a.x, b.z-a.z)
		var t := clampf(Vector2(point.x-a.x, point.z-a.z).dot(flat) / maxf(flat.length_squared(), 0.001), 0.0, 1.0)
		var near := a.lerp(b, t)
		var distance := Vector2(point.x-near.x, point.z-near.z).length()
		if distance < best:
			best = distance
			relative_height = point.y-near.y
			best_segment = i
			best_point = near
	return {"distance": best, "relative_height": relative_height, "segment": best_segment, "nearest_road": _vector(best_point)}

func _scan_visual_clearance(node: Node, course: Dictionary, hits: Array) -> void:
	# Samples triangle centroids and vertices within the inner authored lane and
	# 0.15..3m above its interpolated height. Diagnostics, not exhaustive occlusion proof.
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		var visual := node as MeshInstance3D
		var faces: PackedVector3Array = visual.mesh.get_faces()
		var count := 0
		var surface_ends: Array[int] = []
		var offset := 0
		var attributions: Dictionary = {}
		for s in range(visual.mesh.get_surface_count()):
			var arrays: Array = visual.mesh.surface_get_arrays(s)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			offset += indices.size() if not indices.is_empty() else vertices.size()
			surface_ends.append(offset)
		for i in range(0, faces.size(), 3):
			var samples: Array[Vector3] = [faces[i], faces[i+1], faces[i+2], (faces[i]+faces[i+1]+faces[i+2])/3.0]
			for sample in samples:
				var point: Vector3 = visual.global_transform * sample
				var lane := _nearest_lane(point, course)
				if lane.distance < float(course.get("lane_width", 14.0))*0.5-0.6 and lane.relative_height > 0.15 and lane.relative_height < 3.0:
					count += 1
					var surface := 0
					while surface < surface_ends.size()-1 and i >= surface_ends[surface]:
						surface += 1
					var key := str(surface)
					if not attributions.has(key):
						var material: Material = visual.get_active_material(surface)
						attributions[key] = {"surface": surface, "material_class": material.get_class() if material != null else "none", "color": str((material as StandardMaterial3D).albedo_color) if material is StandardMaterial3D else "", "triangles": 0, "examples": []}
					attributions[key].triangles += 1
					if attributions[key].examples.size() < 8:
						attributions[key].examples.append({"point": _vector(point), "lane": lane})
					break
		if count > 0:
			hits.append({"mesh": str(node.get_path()), "sampled_intruding_triangles": count, "surfaces": attributions.values()})
	for child in node.get_children():
		_scan_visual_clearance(child, course, hits)

func _negative_detectors(track: Node, art: Node3D, before: Dictionary, course: Dictionary) -> Dictionary:
	var shape_node := _first_kind(track, "CollisionShape3D") as CollisionShape3D
	var saved_shape := shape_node.shape
	var saved_shape_transform := shape_node.transform
	shape_node.shape = saved_shape.duplicate()
	if shape_node.shape is BoxShape3D:
		shape_node.shape.size += Vector3(0.25, 0, 0)
	else:
		shape_node.transform.origin += Vector3(0.25, 0, 0)
	var collider_detected := _contract(track) != before
	shape_node.shape = saved_shape
	shape_node.transform = saved_shape_transform
	var deck := _first_deck(track)
	var saved_mesh := deck.mesh
	var altered := BoxMesh.new()
	altered.size = Vector3(1, 1, 1)
	deck.mesh = altered
	var deck_detected := _contract(track) != before
	deck.mesh = saved_mesh
	var checkpoint: Node3D = track.get_checkpoints()[0]
	var saved_pose := checkpoint.transform
	checkpoint.position += Vector3(1, 0, 0)
	var checkpoint_detected := _contract(track) != before
	checkpoint.transform = saved_pose
	var fixture := StaticBody3D.new()
	var fixture_shape := CollisionShape3D.new()
	fixture_shape.shape = BoxShape3D.new()
	fixture.add_child(fixture_shape)
	art.add_child(fixture)
	var added_collision_detected := _physics_count(art) > 0
	fixture.free()
	var obstruction := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(1.5, 2, 1.5)
	obstruction.mesh = cube
	art.add_child(obstruction)
	var p: Array = course.path_points[0]
	obstruction.global_position = Vector3(p[0], p[1]+1.1, p[2])
	var obstruction_hits: Array = []
	_scan_visual_clearance(obstruction, course, obstruction_hits)
	var obstruction_detected := not obstruction_hits.is_empty()
	obstruction.free()
	return {"collider_change_rejected": collider_detected, "deck_change_rejected": deck_detected,
		"checkpoint_change_rejected": checkpoint_detected, "added_art_collision_rejected": added_collision_detected,
		"deliberate_visual_lane_obstruction_detected": obstruction_detected,
		"restored_contract": _contract(track) == before}

func run() -> void:
	if output.is_empty():
		push_error("Required --output=absolute-review-json; no implicit release artifact")
		quit(2)
		return
	await process_frame
	for id in Catalog.list_all_track_ids():
		var host := ReviewHost.new()
		host.name = "IndependentArtReview"
		host.course_data = Catalog.load_track(id)
		root.add_child(host)
		var track := Track.new()
		track.name = "CourseTrack"
		host.add_child(track)
		track.configure(host.course_data)
		if not track.build():
			failures.append(id + ": real track build rejected")
			host.free()
			continue
		var before := _contract(track)
		var data_before := JSON.stringify(host.course_data)
		var art := Node3D.new()
		art.set_script(Art)
		host.add_child(art)
		# Host ready has already fired; invoke the same production installer once.
		art._install()
		var after := _contract(track)
		var hits: Array = []
		_scan_visual_clearance(art, host.course_data, hits)
		var authored := art.get_node_or_null("AuthoredCourseWorld") as MeshInstance3D
		var authored_triangles := 0
		var authored_binding := false
		if authored != null and authored.mesh != null:
			var authored_faces: PackedVector3Array = authored.mesh.get_faces()
			authored_triangles = floori(float(authored_faces.size()) / 3.0)
			authored_binding = str(authored.mesh.get_meta("source_course", "")) == id
		var negatives := _negative_detectors(track, art, before, host.course_data)
		var pickup_motion := _pickup_live_motion_probe(track)
		var row := {"course": id, "protected_contract_unchanged": before == after,
			"course_data_unchanged": data_before == JSON.stringify(host.course_data),
			"added_art_collision_nodes": _physics_count(art), "negative_detectors": negatives,
			"contract_rows": before.size(), "contract_sha256": JSON.stringify(before).sha256_text(),
			"sampled_visual_lane_intrusions": hits, "live_pickup_reduced_motion": pickup_motion,
			"authored_mesh_triangle_count": authored_triangles, "exact_course_asset_binding": authored_binding}
		results.append(row)
		if not row.protected_contract_unchanged or not row.course_data_unchanged or row.added_art_collision_nodes != 0:
			failures.append(id + ": art modified protected racing contract")
		if authored_triangles <= 0 or not authored_binding:
			failures.append(id + ": missing authored mesh or wrong course asset binding")
		for key in negatives:
			if not negatives[key]:
				failures.append(id + ": negative detector failed: " + key)
		for key in pickup_motion:
			if not pickup_motion[key]:
				failures.append(id + ": live pickup motion fixture failed: " + key)
		host.free()
		await process_frame
	var packet := {"schema": "pp.distinct_course_art_contract_review.v1", "reviewer": "Codex distinct review lane",
		"scope": "Real isolated CourseTrack plus production CourseWorldArt installer, 32 catalog courses. No race completion, running-camera/aesthetic acceptance or device-performance claim.",
		"courses": results, "failures": failures, "source_contract_pass": failures.is_empty() and results.size() == 32,
		"visual_clearance_method": "Triangle vertex/centroid samples in inner lane 0.15..3m above interpolated road; diagnostics need actual camera review, not exhaustive visibility proof.",
		"HUMAN": false, "RC2": false, "V1": false}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(packet, "  "))
	file.close()
	print("DISTINCT_ART_CONTRACT_REVIEW courses=", results.size(), " failures=", failures.size())
	quit(0 if packet.source_contract_pass else 1)
