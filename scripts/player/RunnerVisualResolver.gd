class_name RunnerVisualResolver
extends RefCounted

## Presentation-only resolver.
## core runner -> existing RacerVisual procedural path
## guest runner -> skinned GLB GuestRunnerVisual path
## Does not rewrite physics, timing, collision, or shoe stats.

const RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")
const GuestRunnerVisualScript = preload("res://scripts/player/GuestRunnerVisual.gd")
const RunnerIdsScript = preload("res://scripts/data/RunnerIds.gd")


static func attach(visual: Node, profile: RunnerProfile) -> Node:
	if visual == null or profile == null:
		return visual
	var rid := str(profile.id)
	var want_guest := RunnerIdsScript.is_guest(rid)
	var current: Script = visual.get_script() as Script
	if want_guest:
		if current != GuestRunnerVisualScript:
			visual.set_script(GuestRunnerVisualScript)
	else:
		if current != RacerVisualScript:
			visual.set_script(RacerVisualScript)
	if visual.has_method("apply_profile"):
		visual.apply_profile(profile)
	return visual


static func presentation_path_for(runner_id: String) -> String:
	if RunnerIdsScript.is_guest(runner_id):
		return "skinned_glb"
	return "procedural_racer_visual"
