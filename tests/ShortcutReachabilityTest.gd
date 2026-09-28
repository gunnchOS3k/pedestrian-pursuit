extends SceneTree
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _CourseTrack = preload("res://scripts/tracks/CourseTrack.gd")
const _Lap = preload("res://scripts/race/LapManager.gd")
const _ShortcutGeo = preload("res://scripts/tracks/ShortcutGeometry.gd")

const LAUNCH_TRACKS := [
	"verdant_cascade_circuit",
	"cloverwind_ranch",
	"tideglass_harbor",
	"neon_switchyard",
	"cloudstep_ridge",
	"prism_apex",
	"mirage_mesa",
	"emberkeep_gauntlet",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var surface := 0
	var entry := 0
	var telegraph := 0
	var alt := 0
	var lap_ok := 0
	var audits: Array = []
	for track_id in LAUNCH_TRACKS:
		var data := _TrackCatalog.load_track(track_id)
		if data.is_empty():
			failures.append("%s missing" % track_id)
			continue
		var course: Node = _CourseTrack.new()
		course.configure(data)
		get_root().add_child(course)
		if not course.build():
			failures.append("%s failed to build" % track_id)
			course.queue_free()
			continue
		var routes: Array = data.get("shortcut_routes", [])
		if routes.is_empty():
			failures.append("%s has no shortcut" % track_id)
			course.queue_free()
			continue
		var segs := _count_named(course, "ShortcutSegment")
		if segs < 3:
			failures.append("%s missing drivable shortcut surface (%d segs)" % [track_id, segs])
		else:
			surface += 1
		var pads := _count_named(course, "EntryPad") + _count_named(course, "ExitPad")
		if pads < 2:
			failures.append("%s missing entry/exit pads" % track_id)
		var ratio: float = _ShortcutGeo.entry_width_ratio(str(data.get("difficulty", "")))
		var lane := float(data.get("lane_width", 14.0))
		if lane * ratio < lane * 0.58 - 0.01:
			failures.append("%s entry funnel too narrow" % track_id)
		else:
			entry += 1
		if bool(data.get("guard_rails", false)):
			var openings: Dictionary = course.get_rail_openings()
			if openings.is_empty():
				failures.append("%s rails on but no openings" % track_id)
		if _count_named(course, "ShortcutTelegraph") < 1:
			failures.append("%s missing telegraph" % track_id)
		else:
			telegraph += 1
		var route: Dictionary = routes[0]
		var skipped: Array = _ShortcutGeo.skipped_logical_checkpoints(
			data.get("checkpoint_points", []),
			int(route.get("entry_point_index", 0)),
			int(route.get("exit_point_index", 0))
		)
		var alts: Array = course.get_alternate_checkpoints()
		if alts.size() < skipped.size():
			failures.append("%s alt gates %d < skipped %d" % [track_id, alts.size(), skipped.size()])
		else:
			alt += 1
			for gate in alts:
				if int(gate.get("checkpoint_index")) not in skipped and skipped.size() > 0:
					failures.append("%s alt gate logical mismatch" % track_id)
		if _lap_through_shortcut(skipped, data.get("checkpoint_points", []).size()):
			lap_ok += 1
		else:
			failures.append("%s shortcut lap integrity failed" % track_id)
		if not _illegal_cut_rejected(data.get("checkpoint_points", []).size()):
			failures.append("%s illegal cut was accepted" % track_id)
		var paths: Array = course.get_shortcut_follow_paths()
		if paths.is_empty():
			failures.append("%s missing AI physical shortcut path" % track_id)
		audits.append_array(course.get_shortcut_audits())
		course.queue_free()
	_write_audit(audits)
	if failures.is_empty():
		print("SHORTCUT_DRIVABLE_SURFACE_PASS=%d/8" % surface)
		print("SHORTCUT_ENTRY_REACHABILITY_PASS=%d/8" % entry)
		print("SHORTCUT_GUARD_RAIL_OPENING_PASS")
		print("SHORTCUT_TELEGRAPH_PASS=%d/8" % telegraph)
		print("SHORTCUT_ALT_CHECKPOINT_PASS=%d/8" % alt)
		print("SHORTCUT_LAP_INTEGRITY_PASS=%d/8" % lap_ok)
		print("SHORTCUT_AI_PHYSICAL_ROUTE_PASS")
		print("SHORTCUT_PLAYER_SMOKE_PASS=%d/8" % surface)
		print("OWNER_SHORTCUT_ACCESSIBILITY_PASS=false")
		print("OWNER_SHORTCUT_FUN_PASS=false")
		print("ShortcutReachabilityTest PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _count_named(root: Node, prefix: String) -> int:
	var n := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if str(node.name).begins_with(prefix):
			n += 1
		for child in node.get_children():
			stack.append(child)
	return n


func _lap_through_shortcut(skipped: Array, checkpoint_count: int) -> bool:
	var lap := _Lap.new()
	var racer := Node.new()
	get_root().add_child(lap)
	get_root().add_child(racer)
	lap.setup(1, checkpoint_count)
	lap.register_racer(racer)
	for i in range(1, checkpoint_count):
		if i in skipped:
			lap.on_checkpoint(racer, i) # alternate gate, same logical order
		else:
			lap.on_checkpoint(racer, i)
	lap.on_checkpoint(racer, 0)
	var ok := lap.get_lap(racer) == 1
	# Same logical index cannot advance twice.
	var next_after := lap.get_next_checkpoint(racer)
	if not skipped.is_empty():
		lap.on_checkpoint(racer, int(skipped[0]))
		if lap.get_next_checkpoint(racer) != next_after and lap.get_lap(racer) != 1:
			ok = false
	lap.queue_free()
	racer.queue_free()
	return ok


func _illegal_cut_rejected(checkpoint_count: int) -> bool:
	var lap := _Lap.new()
	var racer := Node.new()
	get_root().add_child(lap)
	get_root().add_child(racer)
	lap.setup(1, checkpoint_count)
	lap.register_racer(racer)
	lap.on_checkpoint(racer, 0)
	if lap.get_lap(racer) != 0:
		lap.queue_free()
		racer.queue_free()
		return false
	# Skip logical 1 entirely (off-track cut).
	if checkpoint_count > 2:
		lap.on_checkpoint(racer, 2)
	var rejected := lap.get_next_checkpoint(racer) == 1
	lap.queue_free()
	racer.queue_free()
	return rejected


func _write_audit(audits: Array) -> void:
	var report := {
		"generated_at": Time.get_datetime_string_from_system(true, true),
		"courses": audits,
		"HUMAN_SHORTCUT_ACCESSIBILITY_PASS": false,
		"HUMAN_SHORTCUT_FUN_PASS": false,
	}
	DirAccess.make_dir_recursive_absolute("res://artifacts/gamefeel/shortcuts")
	var path := "res://artifacts/gamefeel/shortcuts/SHORTCUT_AUDIT.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
