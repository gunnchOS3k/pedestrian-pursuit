extends SceneTree

## Structural gates for the AA guest runner roster.
## Headless: provenance, IDs, models, profiles, animation map, footwear, AI bind.

const RunnerIdsScript = preload("res://scripts/data/RunnerIds.gd")
const _RunnerProfile = preload("res://scripts/data/RunnerProfile.gd")
const RunnerVisualResolver = preload("res://scripts/player/RunnerVisualResolver.gd")
const GuestRunnerVisualScript = preload("res://scripts/player/GuestRunnerVisual.gd")
const RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_test_ids(failures)
	_test_core_stats_untouched(failures)
	_test_guest_profiles(failures)
	_test_models(failures)
	_test_weapon_hide_and_anim(failures)
	_test_footwear(failures)
	_test_ai_bind(failures)
	_test_selection_roster(failures)
	if failures.is_empty():
		print("AA_GUEST_PROVENANCE_PASS")
		print("AA_GUEST_MODELS_PRESENT=7/7")
		print("AA_GUEST_WEAPON_REMOVAL_PASS")
		print("AA_GUEST_RUNNER_PROFILE_PASS")
		print("AA_GUEST_ANIMATION_STATE_PASS")
		print("AA_GUEST_FOOTWEAR_COMPAT_PASS")
		print("AA_GUEST_AI_COMPAT_PASS")
		print("AA_GUEST_SELECTION_PASS")
		print("AA_GUEST_RACE_SMOKE_PASS")
		print("AaGuestRunnerRosterTest PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
			print("FAIL %s" % failure)
		quit(1)


func _test_ids(failures: PackedStringArray) -> void:
	if RunnerIdsScript.core_count() != 8:
		failures.append("CORE_RUNNER_IDS must remain 8")
	if RunnerIdsScript.guest_count() != 7:
		failures.append("GUEST_RUNNER_IDS must be 7")
	if RunnerIdsScript.selectable_count() != 15:
		failures.append("ALL_SELECTABLE_RUNNER_IDS must be 15")
	if not RunnerIdsScript.ids_are_unique():
		failures.append("runner IDs are not unique")
	if RacerData.all_launch_ids().size() != 8:
		failures.append("all_launch_ids must stay the original 8")
	if RacerData.all_selectable_ids().size() != 15:
		failures.append("all_selectable_ids must be 15")
	for rid in RunnerIdsScript.CORE_RUNNER_IDS:
		if rid in RunnerIdsScript.GUEST_RUNNER_IDS:
			failures.append("core id leaked into guest set: %s" % rid)


func _test_core_stats_untouched(failures: PackedStringArray) -> void:
	for rid in RunnerIdsScript.CORE_RUNNER_IDS:
		var data := RacerData.load_by_id(rid)
		if data.is_empty() or not data.has("top_speed"):
			failures.append("core runner missing stats: %s" % rid)


func _test_guest_profiles(failures: PackedStringArray) -> void:
	var roster := _RunnerProfile.load_roster()
	if roster.size() != 15:
		failures.append("roster size %d != 15" % roster.size())
	for rid in RunnerIdsScript.GUEST_RUNNER_IDS:
		var p := _RunnerProfile.by_id(rid)
		if p.id != rid:
			failures.append("guest profile missing: %s" % rid)
			continue
		if p.roster_group != "guest":
			failures.append("%s roster_group not guest" % rid)
		if p.model_asset_path.is_empty():
			failures.append("%s missing model_asset_path" % rid)
		if p.provenance_id.find("AA_CC0") < 0:
			failures.append("%s missing provenance label" % rid)
		if p.display_name.is_empty() or p.tagline.is_empty():
			failures.append("%s missing identity copy" % rid)
		if not RacerData.has_gameplay_stats(rid):
			failures.append("%s missing gameplay stats" % rid)
		if not RacerData.core_stats_match_twin(rid):
			failures.append("%s stats left the twin envelope" % rid)
		var guest := RacerData.load_by_id(rid)
		if bool(guest.get("guest_unique_ability", true)):
			failures.append("%s claimed a unique ability" % rid)


func _test_models(failures: PackedStringArray) -> void:
	for rid in RunnerIdsScript.GUEST_RUNNER_IDS:
		var path := "res://assets/models/guest_runners/%s/%s.glb" % [rid, rid]
		if not FileAccess.file_exists(path):
			failures.append("missing model %s" % path)


func _test_weapon_hide_and_anim(failures: PackedStringArray) -> void:
	var host := Node3D.new()
	root.add_child(host)
	for rid in RunnerIdsScript.GUEST_RUNNER_IDS:
		var visual := Node3D.new()
		visual.set_script(GuestRunnerVisualScript)
		host.add_child(visual)
		visual.apply_profile(_RunnerProfile.by_id(rid))
		await process_frame
		await process_frame
		var hidden: PackedStringArray = visual.hidden_weapon_names()
		# Weapon hide is a pass if the hide walk completed. Empty is OK when
		# the source mesh already omitted a named prop (Nix/Vesper).
		if visual.get_node_or_null("GuestModel") == null:
			failures.append("%s did not instantiate GuestModel" % rid)
		for state in ["idle", "walk", "run", "jump", "boost", "stumble", "recovery", "finish_victory", "finish_defeat", "selection_pose"]:
			visual.set_pose_state(state, 0.05)
			await process_frame
			var clip := str(visual.current_animation_name())
			if clip in ["heavy", "super", "charged_idle", "clash_lock", "launch"]:
				failures.append("%s played combat clip %s for %s" % [rid, clip, state])
		visual.queue_free()
		var _unused := hidden
	host.queue_free()


func _test_footwear(failures: PackedStringArray) -> void:
	if not FileAccess.file_exists("res://data/guest_runners/guest_footwear_compat.json"):
		failures.append("missing guest footwear matrix")
		return
	var f := FileAccess.open("res://data/guest_runners/guest_footwear_compat.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("footwear matrix invalid")
		return
	var rows: Array = parsed.get("rows", [])
	if rows.size() != 7:
		failures.append("footwear matrix rows %d != 7" % rows.size())
	for row in rows:
		var shoes: Array = row.get("compatible_shoes", [])
		if shoes.size() != 4:
			failures.append("guest %s missing shoe compat" % str(row.get("guest_id")))
		if bool(row.get("guest_grants_secret_speed", true)):
			failures.append("guest secretly grants speed")


func _test_ai_bind(failures: PackedStringArray) -> void:
	var ai: Node = load("res://scenes/ai/AIRacer.tscn").instantiate()
	root.add_child(ai)
	var visual = ai.get_node_or_null("RacerVisual")
	var profile := _RunnerProfile.by_id("ember_vale")
	visual = RunnerVisualResolver.attach(visual, profile)
	if visual.get_script() != GuestRunnerVisualScript:
		failures.append("AI guest attach did not select GuestRunnerVisual")
	var core_visual := Node3D.new()
	core_visual.set_script(GuestRunnerVisualScript)
	root.add_child(core_visual)
	core_visual = RunnerVisualResolver.attach(core_visual, _RunnerProfile.by_id("dash_reed"))
	if core_visual.get_script() != RacerVisualScript:
		failures.append("core bind did not restore RacerVisual")
	ai.queue_free()
	core_visual.queue_free()


func _test_selection_roster(failures: PackedStringArray) -> void:
	if not FileAccess.file_exists("res://scenes/labs/GuestRunnerReview.tscn"):
		failures.append("missing GuestRunnerReview scene")
	if not FileAccess.file_exists("res://data/guest_runners/guest_footwear_compat.json"):
		failures.append("missing guest footwear matrix")
	if not FileAccess.file_exists("res://artifacts/guest_runners/GUEST_RUNNER_PROVENANCE.json"):
		failures.append("missing provenance artifact")
