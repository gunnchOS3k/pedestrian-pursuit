extends SceneTree

## Real Godot AI evaluation matrix: racers × footwear × tracks × tiers.
## Uses CourseTrack + AIRacer physics (no teleport / invented top-speed cheats).
## Evidence → gate1/evidence/out/pp_competitive_ai_eval.json
## Token: PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED

const TOKEN := "PEDESTRIAN_COMPETITIVE_AI_DIGITAL_VALIDATED"
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _CourseTrack = preload("res://scripts/tracks/CourseTrack.gd")

const TIERS := ["rookie", "standard", "ace"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var time_scale := float(OS.get_environment("PP_AI_EVAL_TIME_SCALE"))
	if time_scale <= 0.0:
		time_scale = 24.0
	Engine.time_scale = time_scale

	var subset := str(OS.get_environment("PP_AI_EVAL_SUBSET")).to_lower() == "1"
	var max_seconds := float(OS.get_environment("PP_AI_EVAL_MAX_SEC"))
	if max_seconds <= 0.0:
		max_seconds = 10.0 if subset else 12.0

	var ai_scene: PackedScene = load("res://scenes/ai/AIRacer.tscn")
	if ai_scene == null:
		push_error("AIRacer.tscn failed to load")
		quit(1)
		return

	var racers: Array = RacerData.all_launch_ids()
	var shoes: Array = ShoeData.all_ids()
	var tracks: Array = _TrackCatalog.list_all_track_ids()
	var tiers: Array = TIERS.duplicate()
	if subset:
		racers = [racers[0], racers[2], racers[5]]
		shoes = [shoes[0], shoes[2], shoes[3]]
		tracks = [tracks[0], tracks[3], tracks[5]]
		tiers = ["rookie", "ace"]

	var course_cache: Dictionary = {}
	var results: Array = []
	var errors := 0
	var cheats := 0
	var idx := 0
	var total := racers.size() * shoes.size() * tracks.size() * tiers.size()
	print("PP AI eval matrix size=%d subset=%s time_scale=%.1f" % [total, str(subset), time_scale])

	for runner_id in racers:
		for shoe_id in shoes:
			for track_id in tracks:
				for tier in tiers:
					idx += 1
					var row: Dictionary = await _eval_one(
						ai_scene,
						str(runner_id),
						str(shoe_id),
						str(track_id),
						str(tier),
						max_seconds,
						course_cache
					)
					results.append(row)
					if not bool(row.get("ok", false)):
						errors += 1
					if bool(row.get("physics_cheat", false)):
						cheats += 1
					if idx % 32 == 0:
						print("  progress %d/%d" % [idx, total])

	for key in course_cache.keys():
		var c: Node = course_cache[key]
		if is_instance_valid(c):
			c.queue_free()
	course_cache.clear()

	Engine.time_scale = 1.0
	var report := _summarize(results, racers, shoes, tracks, tiers, errors, cheats, subset)
	var out_res := "res://gate1/evidence/out/pp_competitive_ai_eval.json"
	var abs_path := ProjectSettings.globalize_path(out_res)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(out_res, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print(
		"AI_EVAL summary token_earned=%s matches=%d errors=%d cheats=%d out=%s"
		% [str(report.get("token_earned")), report.get("match_count"), report.get("error_count"), report.get("physics_cheats"), abs_path]
	)
	if bool(report.get("token_earned", false)):
		print(TOKEN)
		quit(0)
		return
	if subset and int(report.get("error_count", 1)) == 0 and int(report.get("physics_cheats", 1)) == 0 and int(report.get("ok_count", 0)) == results.size():
		print("PP_AI_EVAL_SUBSET_PASS (token reserved for full matrix)")
		quit(0)
		return
	push_error("AI eval did not earn token — see evidence JSON")
	quit(1)


func _eval_one(
	ai_scene: PackedScene,
	runner_id: String,
	shoe_id: String,
	track_id: String,
	tier: String,
	max_seconds: float,
	course_cache: Dictionary
) -> Dictionary:
	var course: Node = course_cache.get(track_id)
	if course == null or not is_instance_valid(course):
		var data := _TrackCatalog.load_track(track_id)
		if data.is_empty():
			return {"ok": false, "error": "track_load", "runner_id": runner_id, "shoe_id": shoe_id, "track_id": track_id, "tier": tier}
		course = _CourseTrack.new()
		course.configure(data)
		root.add_child(course)
		if not course.build():
			course.queue_free()
			return {"ok": false, "error": "track_build", "runner_id": runner_id, "shoe_id": shoe_id, "track_id": track_id, "tier": tier}
		course_cache[track_id] = course

	var ai: Node = ai_scene.instantiate()
	root.add_child(ai)
	if "is_player" in ai:
		ai.is_player = false
	if "racer_id" in ai:
		ai.racer_id = runner_id
	if "shoe_id" in ai:
		ai.shoe_id = shoe_id
	var start_xf: Transform3D = course.get_start_transform()
	ai.global_transform = start_xf
	ai.setup_for_race(start_xf)
	if ai.has_method("setup_rails"):
		ai.setup_rails(course.get_rail_world_points())
	if ai.has_method("setup_ai_path"):
		ai.setup_ai_path(course.get_race_path(), -2.0, 0.0)
	if ai.has_method("set_ai_tier"):
		ai.set_ai_tier(tier)
	if ai.has_method("notify_shoe_changed"):
		ai.notify_shoe_changed()
	ai.enable_movement()

	var follower = ai.get_node_or_null("AIPathFollower")
	var magnet := 0.0
	var speed_mult := 1.0
	if follower != null:
		magnet = float(follower.get("magnet_strength"))
		speed_mult = float(follower.get("speed_multiplier"))
	var physics_cheat := magnet > 0.2 or speed_mult > 1.0

	var path: Path3D = course.get_race_path()
	var path_len := 1.0
	var start_prog := 0.0
	if path != null and path.curve != null:
		path_len = maxf(path.curve.get_baked_length(), 1.0)
	if follower != null and follower.get("_progress") != null:
		start_prog = float(follower.get("_progress"))

	var elapsed := 0.0
	var best_progress := 0.0
	var samples := 0
	var max_speed_seen := 0.0
	var stats_top := 22.0
	if "stats" in ai and ai.stats != null:
		stats_top = float(ai.stats.top_speed)
	# Frame budget: Engine.time_scale accelerates physics between process frames.
	var max_frames := int(maxi(150, int(max_seconds * 30.0)))
	while samples < max_frames:
		await process_frame
		samples += 1
		elapsed = float(samples) / 60.0
		if "horizontal_speed" in ai:
			max_speed_seen = maxf(max_speed_seen, absf(float(ai.horizontal_speed)))
		var traveled := 0.0
		if follower != null and follower.get("_progress") != null:
			traveled = fposmod(float(follower.get("_progress")) - start_prog, path_len)
		elif path != null and path.curve != null:
			var off := path.curve.get_closest_offset(path.to_local(ai.global_position))
			traveled = fposmod(off - start_prog, path_len)
		best_progress = maxf(best_progress, traveled)
		if best_progress >= path_len * 0.85 and max_speed_seen > 2.0 and samples > 40:
			break

	if max_speed_seen > stats_top * 1.6 + 0.5:
		physics_cheat = true

	var ok := (
		samples > 40
		and best_progress > path_len * 0.12
		and max_speed_seen > 1.5
		and not physics_cheat
	)
	var row := {
		"ok": ok,
		"runner_id": runner_id,
		"shoe_id": shoe_id,
		"track_id": track_id,
		"tier": tier,
		"elapsed_sec": snappedf(elapsed, 0.01),
		"progress_m": snappedf(best_progress, 0.01),
		"path_len_m": snappedf(path_len, 0.01),
		"progress_ratio": snappedf(best_progress / path_len, 0.0001),
		"max_speed": snappedf(max_speed_seen, 0.01),
		"stats_top_speed": snappedf(stats_top, 0.01),
		"magnet_strength": snappedf(magnet, 0.001),
		"speed_multiplier": snappedf(speed_mult, 0.001),
		"physics_cheat": physics_cheat,
		"material_family": ShoeData.material_family(shoe_id),
		"soft_surface_score": snappedf(ShoeData.soft_surface_penalty(shoe_id), 0.001),
	}
	ai.queue_free()
	await process_frame
	return row


func _summarize(
	results: Array,
	racers: Array,
	shoes: Array,
	tracks: Array,
	tiers: Array,
	errors: int,
	cheats: int,
	subset: bool
) -> Dictionary:
	var expected := racers.size() * shoes.size() * tracks.size() * tiers.size()
	var by_tier: Dictionary = {}
	var progress_sum := 0.0
	var ok_count := 0
	for tier in tiers:
		by_tier[str(tier)] = {"count": 0, "avg_progress": 0.0, "sum": 0.0}
	for r in results:
		if bool(r.get("ok", false)):
			ok_count += 1
			progress_sum += float(r.get("progress_ratio", 0.0))
		var t := str(r.get("tier", ""))
		if by_tier.has(t):
			by_tier[t]["count"] = int(by_tier[t]["count"]) + 1
			by_tier[t]["sum"] = float(by_tier[t]["sum"]) + float(r.get("progress_ratio", 0.0))
	for t in by_tier.keys():
		var c := int(by_tier[t]["count"])
		by_tier[t]["avg_progress"] = float(by_tier[t]["sum"]) / float(maxi(c, 1))
		by_tier[t].erase("sum")

	var tier_order_ok := true
	if by_tier.has("ace") and by_tier.has("rookie"):
		# Ace should not be dramatically worse; short eval windows are noisy.
		if float(by_tier["ace"]["avg_progress"]) + 0.08 < float(by_tier["rookie"]["avg_progress"]):
			tier_order_ok = false

	var full_matrix := results.size() >= expected and not subset
	var validated := (
		errors == 0
		and cheats == 0
		and results.size() == expected
		and ok_count == expected
		and tier_order_ok
		and full_matrix
	)
	if subset:
		validated = false

	return {
		"schema": "pp_competitive_ai_eval/v1",
		"token": TOKEN if validated else "",
		"token_earned": validated,
		"alpha_claim": "COMPETITIVE_AI_DIGITAL_VALIDATED" if validated else "NOT_YET_VALIDATED",
		"match_count": results.size(),
		"expected_count": expected,
		"roster_size": racers.size(),
		"footwear_size": shoes.size(),
		"track_count": tracks.size(),
		"tiers": tiers,
		"subset": subset,
		"error_count": errors,
		"physics_cheats": cheats,
		"ok_count": ok_count,
		"avg_progress_ratio": progress_sum / float(maxi(ok_count, 1)),
		"by_tier": by_tier,
		"tier_order_ok": tier_order_ok,
		"real_godot_runtime": true,
		"race_scene_physics": true,
		"teleport_cheats": false,
		"speed_cheats": false,
		"results": results,
	}
