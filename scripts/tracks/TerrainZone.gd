extends Area3D

## Terrain modifier zone. Shoe surface affinities multiply zone effects.

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
		var affinity := 1.0
		if "stats" in body and body.stats != null and body.stats.has_method("affinity_for"):
			affinity = float(body.stats.affinity_for(terrain_name))
		elif body.has_method("get") and body.get("shoe_id") != null:
			affinity = ShoeData.surface_affinity(str(body.shoe_id), terrain_name)
		# Affinity > 1 softens penalties / boosts bonuses; < 1 worsens soft ground.
		var speed := speed_multiplier
		var handling := handling_multiplier
		if speed_multiplier < 1.0:
			speed = lerpf(speed_multiplier, 1.0, clampf((affinity - 0.7) / 0.5, 0.0, 1.0))
			# Hard plates on mud stay slow.
			if affinity < 0.85:
				speed = speed_multiplier * affinity
		elif speed_multiplier > 1.0:
			speed = speed_multiplier * clampf(affinity, 0.85, 1.25)
		if handling_multiplier < 1.0 and affinity > 1.05:
			handling = lerpf(handling_multiplier, 1.0, 0.45)
		elif handling_multiplier >= 1.0:
			handling = handling_multiplier * clampf(affinity, 0.85, 1.2)
		body.set_terrain_modifiers(terrain_name, speed, handling)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_terrain_modifiers"):
		body.set_terrain_modifiers("standard", 1.0, 1.0)
