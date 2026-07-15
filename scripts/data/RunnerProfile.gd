extends RefCounted
class_name RunnerProfile

## Character-life profile loaded from data/racers/runner_roster.json

var id: String = "dash_reed"
var display_name: String = "Dash Reed"
var archetype: String = "all_terrain"
var body_color: Color = Color(1.0, 0.82, 0.35)
var accent_color: Color = Color(1.0, 0.35, 0.2)
var height_scale: float = 1.0
var width_scale: float = 1.0
var leg_scale: float = 1.0
var cadence_scale: float = 1.0
var stride_scale: float = 1.0
var bounce_scale: float = 1.0
var lean_scale: float = 1.0
var arm_scale: float = 1.0
var head_bob: float = 1.0
var start_pose: String = "lace_check"
var boost_style: String = "forward_lean"
var stumble_style: String = "stutter"
var recovery_style: String = "jog"
var finish_style: String = "arms_up"
var tagline: String = ""


static func from_dict(data: Dictionary) -> RunnerProfile:
	var p := RunnerProfile.new()
	p.id = str(data.get("id", p.id))
	p.display_name = str(data.get("display_name", p.display_name))
	p.archetype = str(data.get("archetype", p.archetype))
	p.body_color = Color.html(str(data.get("body_color", "#FFD159")))
	p.accent_color = Color.html(str(data.get("accent_color", "#FF5933")))
	p.height_scale = float(data.get("height_scale", 1.0))
	p.width_scale = float(data.get("width_scale", 1.0))
	p.leg_scale = float(data.get("leg_scale", 1.0))
	p.cadence_scale = float(data.get("cadence_scale", 1.0))
	p.stride_scale = float(data.get("stride_scale", 1.0))
	p.bounce_scale = float(data.get("bounce_scale", 1.0))
	p.lean_scale = float(data.get("lean_scale", 1.0))
	p.arm_scale = float(data.get("arm_scale", 1.0))
	p.head_bob = float(data.get("head_bob", 1.0))
	p.start_pose = str(data.get("start_pose", p.start_pose))
	p.boost_style = str(data.get("boost_style", p.boost_style))
	p.stumble_style = str(data.get("stumble_style", p.stumble_style))
	p.recovery_style = str(data.get("recovery_style", p.recovery_style))
	p.finish_style = str(data.get("finish_style", p.finish_style))
	p.tagline = str(data.get("tagline", ""))
	return p


static func load_roster() -> Array[RunnerProfile]:
	var out: Array[RunnerProfile] = []
	var path := "res://data/racers/runner_roster.json"
	if not FileAccess.file_exists(path):
		out.append(RunnerProfile.new())
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		out.append(RunnerProfile.new())
		return out
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		out.append(RunnerProfile.new())
		return out
	var runners: Array = parsed.get("runners", [])
	for item in runners:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(from_dict(item))
	if out.is_empty():
		out.append(RunnerProfile.new())
	return out


static func by_id(runner_id: String) -> RunnerProfile:
	for p in load_roster():
		if p.id == runner_id:
			return p
	var roster := load_roster()
	return roster[0]
