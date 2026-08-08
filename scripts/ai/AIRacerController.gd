extends PlayerController

## AI-controlled racer using tiered route planning (no physics speed cheats).

var _ai_steer: float = 0.0
var _ai_accel: bool = true
var _ai_drift: bool = false
var _ai_use_item: bool = false
var ai_tier_name: String = "standard"

@onready var path_follower: Node = $AIPathFollower


func _ready() -> void:
	super._ready()
	is_player = false


func setup_ai_path(path: Path3D, start_offset: float, lane_offset: float = 0.0) -> void:
	path_follower.setup(path)
	path_follower.snap_to_path(self, start_offset, lane_offset)


func set_ai_tier(tier_name: String) -> void:
	ai_tier_name = tier_name
	if path_follower == null:
		return
	var tier_enum = path_follower.Tier.STANDARD
	match tier_name:
		"rookie":
			tier_enum = path_follower.Tier.ROOKIE
		"ace":
			tier_enum = path_follower.Tier.ACE
		_:
			tier_enum = path_follower.Tier.STANDARD
	path_follower.set_tier(tier_enum)
	path_follower.configure_route_plan(tier_name == "ace", 0.0 if tier_name != "ace" else -1.2)
	if path_follower.has_method("set_shoe_context"):
		path_follower.set_shoe_context(shoe_id)


func notify_shoe_changed() -> void:
	if path_follower != null and path_follower.has_method("set_shoe_context"):
		path_follower.set_shoe_context(shoe_id)


func _get_steer() -> float:
	return _ai_steer


func _get_accelerate_input() -> bool:
	return _ai_accel


func _get_drift_input() -> bool:
	return _ai_drift


func _compute_target_speed() -> float:
	return super._compute_target_speed() * path_follower.speed_multiplier


func _physics_process(delta: float) -> void:
	var cmd: Dictionary = path_follower.get_steer_and_accel(self, delta)
	_ai_steer = cmd.steer
	_ai_accel = cmd.accelerate
	_ai_drift = cmd.drift
	_ai_use_item = bool(cmd.get("use_item", false))
	var held := ""
	if item_manager != null and item_manager.get("held_item_id") != null:
		held = str(item_manager.get("held_item_id"))
	if _ai_use_item and not held.is_empty() and item_manager.has_method("use_held_item"):
		item_manager.use_held_item(self)
		held = str(item_manager.get("held_item_id")) if item_manager.get("held_item_id") != null else ""
	set_meta("held_item_ready", not held.is_empty())
	super._physics_process(delta)
