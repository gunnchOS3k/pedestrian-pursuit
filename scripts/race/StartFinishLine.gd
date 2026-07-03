extends Area3D

## Start/finish line — checkpoint 0 on each lap completion path.

signal racer_crossed(racer: Node)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("racers"):
		racer_crossed.emit(body)
