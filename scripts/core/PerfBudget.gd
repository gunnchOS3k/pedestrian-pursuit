extends RefCounted
class_name PerfBudget

## Digital performance budgets for RC packaging (measurable in headless / editor).

const BUDGETS := {
	"target_fps_desktop": 60,
	"target_fps_android_mid": 30,
	"max_draw_calls_race_hint": 450,
	"max_mesh_instances_course_hint": 220,
	"max_active_particles_hint": 64,
	"max_ai_field": 4,
	"shadows_default": false,
	"renderer": "gl_compatibility",
}


static func as_dict() -> Dictionary:
	return {
		"schema": "pp_perf_budget/v1",
		"budgets": BUDGETS,
		"notes": [
			"GL Compatibility renderer is required for mobile mid-tier.",
			"CourseTrack uses material cache + procedural-final launch scenery.",
			"Device FPS certification is PEDESTRIAN_PHYSICAL_PERFORMANCE_PENDING (separate from digital RC).",
			"AI eval uses time_scale; production races run at 1.0.",
		],
	}


static func write_evidence(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(as_dict(), "\t"))
	f.close()
	return path
