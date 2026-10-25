extends Area3D

## Bounce pad — launches racers upward.

@export var bounce_force: float = 16.0
@export var forward_boost: float = 4.0
@export var cooldown_sec: float = 0.45

var _last_hit: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return
	var id := body.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	if float(_last_hit.get(id, -999.0)) + cooldown_sec > now:
		return
	_last_hit[id] = now
	var force := bounce_force
	var forward_kick := forward_boost
	# Accessibility: soften launch impulse when reduce-motion is on.
	var a11y := _accessibility()
	if a11y != null and bool(a11y.get("reduce_motion")):
		force *= 0.72
		forward_kick *= 0.72
	body.velocity.y = force
	var facing := -body.global_transform.basis.z
	facing.y = 0.0
	if facing.length_squared() < 0.001:
		facing = Vector3.FORWARD
	else:
		facing = facing.normalized()
	var along_line := _racing_line_forward()
	var horiz := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var carried := horiz.length()
	# A misaligned hop leaves the next segment and never reaches the gate.
	# Keep the speed already earned and aim it along the racing line.
	if along_line.length_squared() > 0.01 and facing.dot(along_line) < 0.9 and carried > 1.0:
		body.velocity.x = along_line.x * (carried + forward_kick)
		body.velocity.z = along_line.z * (carried + forward_kick)
		var look := body.global_position + along_line
		look.y = body.global_position.y
		body.look_at(look, Vector3.UP)
	else:
		body.velocity.x += facing.x * forward_kick
		body.velocity.z += facing.z * forward_kick


func _racing_line_forward() -> Vector3:
	var node := get_parent()
	while node != null and not node.has_method("get_race_path"):
		node = node.get_parent()
	if node == null:
		return Vector3.ZERO
	var path: Path3D = node.get_race_path()
	if path == null or path.curve == null:
		return Vector3.ZERO
	var length := path.curve.get_baked_length()
	if length < 1.0:
		return Vector3.ZERO
	var offset := path.curve.get_closest_offset(path.to_local(global_position))
	var ahead := path.to_global(path.curve.sample_baked(fposmod(offset + 8.0, length)))
	var tangent := ahead - global_position
	tangent.y = 0.0
	if tangent.length_squared() < 0.01:
		return Vector3.ZERO
	return tangent.normalized()


func _accessibility() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("AccessibilitySettings")
