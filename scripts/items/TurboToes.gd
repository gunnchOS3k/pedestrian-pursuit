extends Node

## Turbo Toes — instant speed boost item logic (used via ItemManager).

static func apply(racer: Node) -> void:
	if racer.has_node("BoostSystem"):
		racer.get_node("BoostSystem").apply_external_boost(1.45, 2.0)
