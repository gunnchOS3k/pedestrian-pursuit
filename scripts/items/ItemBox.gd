extends Area3D

## Item box pickup — grants random MVP item.

@export var respawn_time: float = 5.0

var _active: bool = true
@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body.is_in_group("racers") and body.has_node("ItemManager"):
		var mgr = body.get_node("ItemManager")
		var place := int(body.get_meta("race_place_estimate", 4))
		var field := 4
		var tree := body.get_tree()
		if tree != null:
			field = maxi(tree.get_nodes_in_group("racers").size(), 2)
		if mgr.has_method("grant_position_weighted_item"):
			mgr.grant_position_weighted_item(place, field)
		else:
			mgr.grant_random_item()
		_deactivate()


func _deactivate() -> void:
	_active = false
	if mesh:
		mesh.visible = false
	await get_tree().create_timer(respawn_time).timeout
	_active = true
	if mesh:
		mesh.visible = true
