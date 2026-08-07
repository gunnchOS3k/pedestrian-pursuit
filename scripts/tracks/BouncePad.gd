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
	body.velocity.y = bounce_force
	var forward := -body.global_transform.basis.z
	body.velocity.x += forward.x * forward_boost
	body.velocity.z += forward.z * forward_boost
