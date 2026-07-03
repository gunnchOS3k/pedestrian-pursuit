extends Node3D

## Sneaker City Sprintway track root — exposes checkpoints and start position.

@onready var checkpoints_node: Node3D = $Checkpoints
@onready var race_path: Path3D = $RacePath


func _ready() -> void:
	_ensure_race_path()


func _ensure_race_path() -> void:
	if race_path == null or race_path.curve == null or race_path.curve.get_point_count() < 2:
		var curve := Curve3D.new()
		var points := [
			Vector3(0, 1, 18), Vector3(0, 1, -18), Vector3(-28, 1, -18),
			Vector3(-28, 1, 18), Vector3(28, 1, 18), Vector3(28, 1, -18), Vector3(0, 1, 18)
		]
		for p in points:
			curve.add_point(p)
		if race_path:
			race_path.curve = curve


func get_checkpoints() -> Array:
	var cps: Array = []
	for child in checkpoints_node.get_children():
		if child is Area3D and "checkpoint_index" in child:
			cps.append(child)
	cps.sort_custom(func(a, b): return a.checkpoint_index < b.checkpoint_index)
	return cps


func get_start_transform() -> Transform3D:
	var start := get_node_or_null("StartPosition") as Node3D
	if start:
		return start.global_transform
	return global_transform


func get_race_path() -> Path3D:
	return race_path
