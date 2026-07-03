extends Node

## Holds and uses the racer's current item.

signal item_changed(item_id: String)

var held_item_id: String = ""
var _item_defs: Dictionary = {}


func _ready() -> void:
	for id in ItemData.all_mvp_ids():
		_item_defs[id] = ItemData.load_by_id(id)


func grant_random_item() -> void:
	var ids := ItemData.all_mvp_ids()
	held_item_id = ids[randi() % ids.size()]
	item_changed.emit(held_item_id)


func use_held_item(racer: Node) -> void:
	if held_item_id.is_empty():
		return
	match held_item_id:
		"turbo_toes":
			_use_turbo_toes(racer)
		"lace_trap":
			_use_lace_trap(racer)
		"sole_shield":
			_use_sole_shield(racer)
	held_item_id = ""
	item_changed.emit("")


func _use_turbo_toes(racer: Node) -> void:
	if racer.has_node("BoostSystem"):
		racer.get_node("BoostSystem").apply_external_boost(1.45, 2.0)


func _use_lace_trap(racer: Node) -> void:
	var scene := load("res://scenes/items/LaceTrap.tscn") as PackedScene
	if scene == null:
		return
	var trap := scene.instantiate()
	racer.get_tree().current_scene.add_child(trap)
	var back := -racer.global_transform.basis.z
	trap.global_position = racer.global_position + back * 3.0


func _use_sole_shield(racer: Node) -> void:
	if racer.has_method("activate_shield"):
		racer.activate_shield()
