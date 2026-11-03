extends SceneTree

## Bounded authored asset import and exact-vehicle integration test.
## Does not establish human art acceptance or a gameplay/performance benchmark.
const RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")
var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("run")


func authored_nodes(visual: Node) -> Array[Node]:
	return visual.find_children("VoltstepCoils_AuthoredFootwear", "", true, false)


func run() -> void:
	var visual: Node3D = RacerVisualScript.new()
	visual.set_vehicle_id("voltstep_coils", false)
	root.add_child(visual)
	await process_frame
	var nodes: Array[Node] = authored_nodes(visual)
	if nodes.size() != 2:
		failures.append("expected the actual imported asset at both animated feet")
	if visual.find_child("VoltstepAuthoredMountLeft", true, false) == null:
		failures.append("missing left animated leg mount")
	if visual.find_child("VoltstepAuthoredMountRight", true, false) == null:
		failures.append("missing right animated leg mount")
	var checked_meshes := 0
	for node in nodes:
		var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
		if node is MeshInstance3D:
			meshes.append(node)
		for mesh_node in meshes:
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			checked_meshes += 1
			if mesh_instance.mesh.get_surface_count() != 7:
				failures.append("authored mesh must retain seven material surfaces")
			for surface in range(mesh_instance.mesh.get_surface_count()):
				if mesh_instance.mesh.surface_get_material(surface) == null:
					failures.append("imported surface has no assigned material")
		if not node.find_children("*", "CollisionObject3D", true, false).is_empty():
			failures.append("cosmetic imported asset must not add gameplay collision")
	if checked_meshes != 2:
		failures.append("expected two nonempty authored meshes")
	visual.set_vehicle_id("reedline_circlers")
	if not authored_nodes(visual).is_empty():
		failures.append("authored Voltstep model leaked into another vehicle")
	visual.free()
	await process_frame
	if failures.is_empty():
		print("VoltstepAuthoredIntegrationTest PASS: two imported meshes, seven materials, exact footwear binding, cosmetic-only")
		quit(0)
	else:
		for failure in failures:
			print("FAIL: ", failure)
		quit(1)
