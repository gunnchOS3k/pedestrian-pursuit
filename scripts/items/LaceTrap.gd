extends Area3D

## Lace Trap hazard dropped behind the racer.

@export var slow_duration: float = 1.2
@export var lifetime: float = 5.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("racers") and body.has_method("apply_lace_trap_slow"):
		body.apply_lace_trap_slow(slow_duration)
