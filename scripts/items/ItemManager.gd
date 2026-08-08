extends Node

## Holds and uses the racer's current item. Offensive tools emit warnings for counterplay.

signal item_changed(item_id: String)
signal item_warning(item_id: String, seconds: float, target: Node)

var held_item_id: String = ""
var _item_defs: Dictionary = {}
var _bubble_timer: float = 0.0


func _ready() -> void:
	for id in ItemData.all_alpha_ids():
		_item_defs[id] = ItemData.load_by_id(id)


func _process(delta: float) -> void:
	if _bubble_timer > 0.0:
		_bubble_timer = maxf(0.0, _bubble_timer - delta)


func grant_random_item() -> void:
	var ids := ItemData.all_alpha_ids()
	held_item_id = ids[randi() % ids.size()]
	item_changed.emit(held_item_id)


func use_held_item(racer: Node) -> void:
	if held_item_id.is_empty():
		return
	var used_id := held_item_id
	match held_item_id:
		"turbo_toes":
			_use_turbo_toes(racer)
		"lace_trap":
			_use_lace_trap(racer)
		"sole_shield":
			_use_sole_shield(racer)
		"pulse_horn":
			_use_pulse_horn(racer)
		"magnet_lace":
			_use_magnet_lace(racer)
		"bounce_bubble":
			_use_bounce_bubble(racer)
	held_item_id = ""
	item_changed.emit("")
	if TelemetryBus != null and racer != null and bool(racer.get("is_player")):
		var track_id := ""
		if GameManager != null:
			track_id = GameManager.selected_track_id
		TelemetryBus.item_use(used_id, track_id)


func has_bounce_bubble() -> bool:
	return _bubble_timer > 0.0


func consume_bounce_bubble() -> bool:
	if _bubble_timer <= 0.0:
		return false
	_bubble_timer = 0.0
	return true


func _use_turbo_toes(racer: Node) -> void:
	if racer.has_node("BoostSystem"):
		racer.get_node("BoostSystem").apply_external_boost(1.45, 2.0)


func _use_lace_trap(racer: Node) -> void:
	var def: Dictionary = _item_defs.get("lace_trap", {})
	var warn := float(def.get("warning_seconds", 0.35))
	item_warning.emit("lace_trap", warn, null)
	var scene := load("res://scenes/items/LaceTrap.tscn") as PackedScene
	if scene == null:
		return
	var trap := scene.instantiate()
	racer.get_tree().current_scene.add_child(trap)
	var back: Vector3 = racer.global_transform.basis.z
	trap.global_position = racer.global_position + back * 3.0


func _use_sole_shield(racer: Node) -> void:
	if racer.has_method("activate_shield"):
		racer.activate_shield()


func _use_pulse_horn(racer: Node) -> void:
	var def: Dictionary = _item_defs.get("pulse_horn", {})
	var warn := float(def.get("warning_seconds", 0.85))
	var strength := float(def.get("effect_strength", 0.65))
	var duration := float(def.get("duration", 1.2))
	item_warning.emit("pulse_horn", warn, null)
	var tree := racer.get_tree()
	if tree == null:
		return
	# Delayed hit so victims can shield / slide / break draft.
	tree.create_timer(warn).timeout.connect(func ():
		if not is_instance_valid(racer):
			return
		for other in tree.get_nodes_in_group("racers"):
			if other == racer or not (other is Node3D):
				continue
			var to_other: Vector3 = other.global_position - racer.global_position
			to_other.y = 0.0
			if to_other.length() > 14.0:
				continue
			var forward := -racer.global_transform.basis.z
			forward.y = 0.0
			if forward.length_squared() < 0.001:
				continue
			if forward.normalized().dot(to_other.normalized()) < 0.55:
				continue
			_apply_hazard(other, duration * strength)
	)


func _use_magnet_lace(racer: Node) -> void:
	var def: Dictionary = _item_defs.get("magnet_lace", {})
	var warn := float(def.get("warning_seconds", 1.1))
	var duration := float(def.get("duration", 2.4))
	var target := _find_leader(racer)
	item_warning.emit("magnet_lace", warn, target)
	var tree := racer.get_tree()
	if tree == null or target == null:
		return
	tree.create_timer(warn).timeout.connect(func ():
		if is_instance_valid(target):
			_apply_hazard(target, duration * 0.45)
	)


func _use_bounce_bubble(racer: Node) -> void:
	_bubble_timer = float(_item_defs.get("bounce_bubble", {}).get("duration", 4.0))
	if racer.has_method("activate_shield"):
		racer.activate_shield()
	if racer is CharacterBody3D:
		(racer as CharacterBody3D).velocity.y = maxf((racer as CharacterBody3D).velocity.y, 8.5)


func _apply_hazard(target: Node, slow_duration: float) -> void:
	if target == null:
		return
	var items := target.get_node_or_null("ItemManager")
	if items != null and items.has_method("consume_bounce_bubble") and items.consume_bounce_bubble():
		# Reflect: short hop, no slow.
		if target is CharacterBody3D:
			(target as CharacterBody3D).velocity.y = maxf((target as CharacterBody3D).velocity.y, 7.0)
		return
	if target.get("shield_active") == true:
		target.set("shield_active", false)
		return
	if target.has_method("apply_lace_trap_slow"):
		target.apply_lace_trap_slow(slow_duration)


func _find_leader(racer: Node) -> Node:
	var best: Node = null
	var best_place := 999
	var tree := racer.get_tree()
	if tree == null:
		return null
	for other in tree.get_nodes_in_group("racers"):
		if other == racer:
			continue
		var place := int(other.get_meta("race_place_estimate", 99))
		if place < best_place:
			best_place = place
			best = other
	return best
