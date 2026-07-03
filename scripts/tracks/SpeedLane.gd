extends Area3D

## Speed lane — increases racer top speed while inside.

@export var speed_bonus: float = 1.25


func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	collision_layer = 0
	collision_mask = 2


func _on_enter(body: Node3D) -> void:
	if body.has_method("set_terrain_modifiers"):
		body.set_terrain_modifiers("speed_lane", speed_bonus, 1.0)


func _on_exit(body: Node3D) -> void:
	if body.has_method("set_terrain_modifiers"):
		body.set_terrain_modifiers("standard", 1.0, 1.0)
