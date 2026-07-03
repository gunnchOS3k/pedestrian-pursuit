extends Node

## Sole Shield — blocks one hit (applied via ItemManager.activate_shield).

static func apply(racer: Node) -> void:
	if racer.has_method("activate_shield"):
		racer.activate_shield()
