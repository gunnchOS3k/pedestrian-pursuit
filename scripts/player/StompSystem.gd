extends Node

## Ground stomp pulse and airborne downward stomp.

signal stomp_executed(is_airborne: bool)

@export var ground_pulse_radius: float = 4.0
@export var ground_slow_duration: float = 0.8
@export var air_stomp_velocity: float = -22.0
@export var stomp_cooldown: float = 0.4

var _cooldown: float = 0.0


func tick(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func can_stomp() -> bool:
	return _cooldown <= 0.0


func execute_ground_stomp(origin: Vector3, owner: Node) -> void:
	if not can_stomp():
		return
	_cooldown = stomp_cooldown
	stomp_executed.emit(false)
	var space := owner.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = ground_pulse_radius
	query.shape = shape
	query.transform = Transform3D(Basis(), origin)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [owner.get_rid()] if owner is CollisionObject3D else []
	for hit in space.intersect_shape(query, 16):
		var collider: Object = hit.collider
		if collider.has_method("apply_stomp_slow"):
			collider.apply_stomp_slow(ground_slow_duration)


func execute_air_stomp(body: CharacterBody3D) -> void:
	if not can_stomp():
		return
	_cooldown = stomp_cooldown
	body.velocity.y = air_stomp_velocity
	stomp_executed.emit(true)
