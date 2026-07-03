extends Area3D

## Boost energy orb pickup.

@export var respawn_time: float = 4.0

var _active: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body.has_method("collect_boost_pickup"):
		body.collect_boost_pickup()
		_active = false
		visible = false
		await get_tree().create_timer(respawn_time).timeout
		_active = true
		visible = true
