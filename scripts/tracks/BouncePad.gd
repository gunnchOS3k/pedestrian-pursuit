extends Area3D

## Bounce pad — launches racers upward.

@export var bounce_force: float = 16.0
@export var forward_boost: float = 4.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.velocity.y = bounce_force
		var forward := -body.global_transform.basis.z
		body.velocity.x += forward.x * forward_boost
		body.velocity.z += forward.z * forward_boost
