extends Area3D

## Ordered checkpoint trigger.
## Uses both Area body_entered and a distance poll so CharacterBody3D racers
## still register on Android where Area enter events can be flaky.

@export var checkpoint_index: int = 0

signal racer_passed(racer: Node, index: int)

var _shape_half: Vector3 = Vector3(6.0, 2.5, 1.8)
var _cooldown: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider == null:
		for child in get_children():
			if child is CollisionShape3D:
				collider = child
				break
	if collider != null and collider.shape is BoxShape3D:
		_shape_half = (collider.shape as BoxShape3D).size * 0.5


func _physics_process(delta: float) -> void:
	for id in _cooldown.keys():
		_cooldown[id] = float(_cooldown[id]) - delta
		if float(_cooldown[id]) <= 0.0:
			_cooldown.erase(id)
	for node in get_tree().get_nodes_in_group("racers"):
		if node is Node3D:
			_try_emit(node as Node3D)


func _on_body_entered(body: Node3D) -> void:
	_try_emit(body)


func _try_emit(body: Node3D) -> void:
	if body == null or not body.is_in_group("racers"):
		return
	if not _contains_point(body.global_position):
		return
	var id := body.get_instance_id()
	if _cooldown.has(id):
		return
	_cooldown[id] = 0.65
	racer_passed.emit(body, checkpoint_index)


func _contains_point(world_pos: Vector3) -> bool:
	var local := to_local(world_pos)
	return (
		absf(local.x) <= _shape_half.x + 0.35
		and absf(local.y) <= _shape_half.y + 0.85
		and absf(local.z) <= _shape_half.z + 0.35
	)
