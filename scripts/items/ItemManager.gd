extends Node

## Holds and uses the racer's current item. Offensive tools emit warnings for counterplay.
## Position-aware grant uses FairComebackPolicy — never decides races via extreme RNG.

signal item_changed(item_id: String)
signal item_warning(item_id: String, seconds: float, target: Node)
signal item_countered(item_id: String, by: String)

const FairComebackPolicyScript = preload("res://scripts/race/FairComebackPolicy.gd")

var held_item_id: String = ""
var _item_defs: Dictionary = {}
var _bubble_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _grant_seed_offset: int = 0


func _ready() -> void:
	_rng.randomize()
	for id in ItemData.all_alpha_ids():
		_item_defs[id] = ItemData.load_by_id(id)


func _process(delta: float) -> void:
	if _bubble_timer > 0.0:
		_bubble_timer = maxf(0.0, _bubble_timer - delta)


func set_deterministic_seed(seed: int) -> void:
	_rng.seed = seed
	_grant_seed_offset = 0


func grant_random_item() -> void:
	grant_position_weighted_item(-1, 4)


func grant_position_weighted_item(place: int = -1, field_size: int = 4) -> void:
	if not held_item_id.is_empty():
		return
	var resolved_place := place
	var parent := get_parent()
	if resolved_place < 1 and parent != null and parent.has_meta("race_place_estimate"):
		resolved_place = int(parent.get_meta("race_place_estimate"))
	if resolved_place < 1:
		resolved_place = field_size
	var competitive := FairComebackPolicyScript.is_competitive(GameManager)
	_grant_seed_offset += 1
	held_item_id = FairComebackPolicyScript.weighted_item_id(
		resolved_place, maxi(field_size, 2), _rng, competitive
	)
	item_changed.emit(held_item_id)
	if TelemetryBus != null:
		TelemetryBus.record("item_acquired", {
			"item_id": held_item_id,
			"place": resolved_place,
			"competitive": competitive,
		})


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
	var audio := get_tree().root.get_node_or_null("AudioDirector")
	if audio and audio.has_method("play_item"):
		audio.play_item(used_id)
	if TelemetryBus != null and racer != null and racer.get("is_player") == true:
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
	item_countered.emit("incoming", "bounce_bubble")
	return true


func _use_turbo_toes(racer: Node) -> void:
	if racer.has_node("BoostSystem"):
		var boost = racer.get_node("BoostSystem")
		if boost.has_method("apply_external_boost"):
			boost.apply_external_boost(1.45, 2.0, "item_turbo_toes")
		if boost.has_method("add_boost"):
			boost.add_boost(10.0, "item_turbo_toes")


func _use_lace_trap(racer: Node) -> void:
	var def: Dictionary = _item_defs.get("lace_trap", {})
	var warn := float(def.get("warning_seconds", 0.35))
	item_warning.emit("lace_trap", warn, null)
	var scene := load("res://scenes/items/LaceTrap.tscn") as PackedScene
	if scene == null or racer == null:
		return
	var tree := racer.get_tree()
	if tree == null:
		return
	var trap := scene.instantiate()
	var host: Node = tree.current_scene
	if host == null:
		host = tree.root
	host.add_child(trap)
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
	tree.create_timer(warn).timeout.connect(func ():
		if not is_instance_valid(racer) or not (racer is Node3D):
			return
		var source := racer as Node3D
		for other in tree.get_nodes_in_group("racers"):
			if other == racer or not (other is Node3D):
				continue
			var victim := other as Node3D
			var to_other: Vector3 = victim.global_position - source.global_position
			to_other.y = 0.0
			if to_other.length() > 14.0:
				continue
			var forward: Vector3 = -source.global_transform.basis.z
			forward.y = 0.0
			if forward.length_squared() < 0.001:
				continue
			if forward.normalized().dot(to_other.normalized()) < 0.55:
				continue
			_apply_hazard(other, duration * strength, "pulse_horn")
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
			_apply_hazard(target, duration * 0.45, "magnet_lace")
	)


func _use_bounce_bubble(racer: Node) -> void:
	_bubble_timer = float(_item_defs.get("bounce_bubble", {}).get("duration", 4.0))
	if racer.has_method("activate_shield"):
		racer.activate_shield()
	if racer is CharacterBody3D:
		(racer as CharacterBody3D).velocity.y = maxf((racer as CharacterBody3D).velocity.y, 8.5)


func _apply_hazard(target: Node, slow_duration: float, item_id: String = "") -> void:
	if target == null:
		return
	var items := target.get_node_or_null("ItemManager")
	if items != null and items.has_method("consume_bounce_bubble") and items.consume_bounce_bubble():
		if target is CharacterBody3D:
			(target as CharacterBody3D).velocity.y = maxf((target as CharacterBody3D).velocity.y, 7.0)
		item_countered.emit(item_id, "bounce_bubble")
		return
	# Slide / shield counters.
	var sm := target.get_node_or_null("RacerStateMachine")
	if sm != null and sm.get("current_state") != null:
		var slide_state = sm.State.SLIDE if "State" in sm else null
		if slide_state != null and sm.current_state == slide_state:
			item_countered.emit(item_id, "slide")
			return
	if target.get("shield_active") == true:
		target.set("shield_active", false)
		item_countered.emit(item_id, "shield")
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
