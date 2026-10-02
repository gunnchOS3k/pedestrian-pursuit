extends Area3D

## Pursuit Pod — original Pedestrian Pursuit item pickup (shoe-tech capsule).
## Distance-readable silhouette, animated rim, hover, pickup burst.

@export var respawn_time: float = 5.0

var _active: bool = true
var _pod: Node3D
var _rim: MeshInstance3D
var _core: MeshInstance3D
var _marker: MeshInstance3D
var _label: Label3D
var _spin: float = 0.0
var _hover_t: float = 0.0

const FX := preload("res://scripts/items/ItemEffectVisuals.gd")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2
	_ensure_collision()
	_build_pursuit_pod()


func _process(delta: float) -> void:
	if not _active or _pod == null:
		return
	_spin += delta * 1.6
	_hover_t += delta * 2.4
	_pod.rotation.y = _spin
	_pod.position.y = 0.15 + sin(_hover_t) * 0.22
	if _rim != null:
		_rim.rotation.y = -_spin * 1.4
	if _marker != null:
		_marker.rotation.y = _spin * 0.5


func _ensure_collision() -> void:
	var existing := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if existing != null:
		var shape := CylinderShape3D.new()
		shape.radius = 1.35
		shape.height = 2.8
		existing.shape = shape
		return
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = 1.35
	shape.height = 2.8
	collider.shape = shape
	add_child(collider)


func _build_pursuit_pod() -> void:
	# Hide legacy box mesh if present from scene.
	var legacy := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if legacy != null:
		legacy.visible = false
	var legacy_label := get_node_or_null("Label3D") as Label3D
	if legacy_label != null:
		legacy_label.visible = false

	_pod = Node3D.new()
	_pod.name = "PursuitPod"
	add_child(_pod)

	# Capsule body — tall shoe-tech silhouette readable at ~30m.
	_core = MeshInstance3D.new()
	_core.name = "PodCore"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.55
	capsule.height = 1.8
	_core.mesh = capsule
	_core.material_override = _mat(Color(0.25, 0.85, 1.0, 0.85), Color(0.15, 0.7, 1.0), true)
	_pod.add_child(_core)

	# Animated emissive rim ring.
	_rim = MeshInstance3D.new()
	_rim.name = "PodRim"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.72
	ring.outer_radius = 0.95
	_rim.mesh = ring
	_rim.position = Vector3(0, 0.15, 0)
	_rim.material_override = _mat(Color(1.0, 0.45, 0.95), Color(1.0, 0.3, 0.9), true)
	_pod.add_child(_rim)

	# Icon disc on top.
	var icon := MeshInstance3D.new()
	icon.name = "PodIcon"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.35
	disc.bottom_radius = 0.35
	disc.height = 0.12
	icon.mesh = disc
	icon.position = Vector3(0, 1.05, 0)
	icon.material_override = _mat(Color(1.0, 0.95, 0.4), Color(1.0, 0.85, 0.2), true)
	_pod.add_child(icon)

	# Vertical marker for distance readability.
	_marker = MeshInstance3D.new()
	_marker.name = "DistanceMarker"
	var pole := CylinderMesh.new()
	pole.top_radius = 0.08
	pole.bottom_radius = 0.08
	pole.height = 2.4
	_marker.mesh = pole
	_marker.position = Vector3(0, 2.2, 0)
	_marker.material_override = _mat(Color(1.0, 0.9, 0.3), Color(1.0, 0.8, 0.15), true)
	add_child(_marker)

	_label = Label3D.new()
	_label.name = "PodLabel"
	_label.text = "POD"
	_label.font_size = 56
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.95, 1.0)
	_label.position = Vector3(0, 3.5, 0)
	add_child(_label)


func _mat(albedo: Color, emission: Color, emissive: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	if albedo.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.35
	if emissive:
		mat.emission_enabled = true
		mat.emission = emission
	return mat


func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body.is_in_group("racers") and body.has_node("ItemManager"):
		var mgr = body.get_node("ItemManager")
		var place := int(body.get_meta("race_place_estimate", 4))
		var field := 4
		var tree := body.get_tree()
		if tree != null:
			field = maxi(tree.get_nodes_in_group("racers").size(), 2)
		if mgr.has_method("grant_position_weighted_item"):
			mgr.grant_position_weighted_item(place, field)
		else:
			mgr.grant_random_item()
		FX.spawn_item_acquire_burst(global_position + Vector3(0, 1.2, 0), tree)
		_deactivate()


func _deactivate() -> void:
	_active = false
	if _pod:
		_pod.visible = false
	if _marker:
		_marker.visible = false
	if _label:
		_label.visible = false
	await get_tree().create_timer(respawn_time).timeout
	_active = true
	if _pod:
		_pod.visible = true
	if _marker:
		_marker.visible = true
	if _label:
		_label.visible = true
