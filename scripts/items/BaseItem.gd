class_name BaseItem
extends Node3D

## Base class for deployable items.

@export var item_id: String = ""
@export var duration: float = 5.0


func activate(_user: Node) -> void:
	pass


func _expire() -> void:
	queue_free()
