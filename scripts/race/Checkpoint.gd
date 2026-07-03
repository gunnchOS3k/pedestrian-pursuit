extends Area3D

## Ordered checkpoint trigger.

@export var checkpoint_index: int = 0

signal racer_passed(racer: Node, index: int)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("racers"):
		racer_passed.emit(body, checkpoint_index)
