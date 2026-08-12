extends Node

## Wires accepted special_ability_id values to existing movement systems.
## Controllable via InputMap "special" (R / gamepad Y). Does not invent new vehicles.

signal ability_activated(ability_id: String)
signal ability_ready_changed(ready: bool, cooldown_left: float)

const CATALOG_PATH := "res://data/mechanics/special_abilities.json"

var ability_id: String = "clean_lines"
var _catalog: Dictionary = {}
var _cooldown_left: float = 0.0
var _active_left: float = 0.0
var _def: Dictionary = {}
var _racer: Node
var _handling_mult: float = 1.0
var _speed_hold_mult: float = 1.0
var _speed_decay_resist: float = 0.0
var _slow_resist: float = 0.0
var _drift_charge_mult: float = 1.0


func setup(racer: Node, special_id: String) -> void:
	_racer = racer
	_ensure_catalog()
	ability_id = special_id if _catalog.has(special_id) else "clean_lines"
	_def = (_catalog.get(ability_id, {}) as Dictionary).duplicate(true)
	_cooldown_left = 0.0
	_clear_active()


func _ensure_catalog() -> void:
	if not _catalog.is_empty():
		return
	if not FileAccess.file_exists(CATALOG_PATH):
		_catalog = {}
		return
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_catalog = {}
		return
	var abilities = parsed.get("abilities", {})
	if typeof(abilities) == TYPE_DICTIONARY:
		_catalog = abilities


func tick(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
		if _cooldown_left <= 0.0:
			ability_ready_changed.emit(true, 0.0)
	if _active_left > 0.0:
		_active_left = maxf(0.0, _active_left - delta)
		if _active_left <= 0.0:
			_clear_active()


func try_activate() -> bool:
	if _cooldown_left > 0.0 or _def.is_empty():
		return false
	var effect := str(_def.get("effect", ""))
	match effect:
		"handling_hold":
			_handling_mult = float(_def.get("handling_mult", 1.2))
			_speed_hold_mult = float(_def.get("speed_hold_mult", 1.05))
			_active_left = float(_def.get("duration_sec", 2.0))
		"external_boost":
			var boost = _racer.get_node_or_null("BoostSystem") if _racer else null
			if boost != null and boost.has_method("apply_external_boost"):
				boost.apply_external_boost(
					float(_def.get("boost_mult", 1.25)),
					float(_def.get("duration_sec", 1.0))
				)
			_active_left = float(_def.get("duration_sec", 1.0))
		"parkour_read":
			_handling_mult = float(_def.get("handling_mult", 1.2))
			if _racer != null and "_wall_kick_cooldown" in _racer:
				_racer._wall_kick_cooldown = 0.0
			_active_left = float(_def.get("duration_sec", 2.0))
		"tempo_hold":
			_speed_decay_resist = float(_def.get("speed_decay_resist", 0.5))
			_active_left = float(_def.get("duration_sec", 2.5))
		"shoulder_drive":
			_slow_resist = float(_def.get("slow_resist", 0.6))
			_speed_hold_mult = float(_def.get("strength_speed_mult", 1.05))
			_active_left = float(_def.get("duration_sec", 2.0))
		"style_to_boost":
			var boost2 = _racer.get_node_or_null("BoostSystem") if _racer else null
			var stats = _racer.get_node_or_null("MovementStats") if _racer else null
			var skill := 8.0
			if stats != null:
				skill = float(stats.trick_skill)
			if boost2 != null and boost2.has_method("add_boost"):
				boost2.add_boost(float(_def.get("boost_from_trick_skill", 15.0)) * (skill / 10.0))
			_active_left = 0.05
		"apex_drift":
			_drift_charge_mult = float(_def.get("drift_charge_mult", 1.4))
			_active_left = float(_def.get("duration_sec", 2.5))
		_:
			return false
	_cooldown_left = float(_def.get("cooldown_sec", 10.0))
	ability_activated.emit(ability_id)
	ability_ready_changed.emit(false, _cooldown_left)
	return true


func get_handling_multiplier() -> float:
	return _handling_mult if _active_left > 0.0 else 1.0


func get_speed_multiplier() -> float:
	return _speed_hold_mult if _active_left > 0.0 else 1.0


func get_speed_decay_resist() -> float:
	return _speed_decay_resist if _active_left > 0.0 else 0.0


func get_slow_resist() -> float:
	return _slow_resist if _active_left > 0.0 else 0.0


func get_drift_charge_multiplier() -> float:
	return _drift_charge_mult if _active_left > 0.0 else 1.0


func is_ready() -> bool:
	return _cooldown_left <= 0.0


func cooldown_left() -> float:
	return _cooldown_left


func _clear_active() -> void:
	_active_left = 0.0
	_handling_mult = 1.0
	_speed_hold_mult = 1.0
	_speed_decay_resist = 0.0
	_slow_resist = 0.0
	_drift_charge_mult = 1.0
