extends Area3D

## Base terrain modifier zone.

@export var terrain_name: String = "standard"
@export var speed_multiplier: float = 1.0
@export var handling_multiplier: float = 1.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_terrain_modifiers"):
		body.set_terrain_modifiers(terrain_name, speed_multiplier, handling_multiplier)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_terrain_modifiers"):
		body.set_terrain_modifiers("standard", 1.0, 1.0)
