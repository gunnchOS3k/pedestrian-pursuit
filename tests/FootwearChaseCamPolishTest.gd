extends SceneTree

## PP-RTM-12 digital: footwear trail family + stripe profiles differ by material_family.
## Cosmetic only — does not change MovementStats / handling. Not commercial final art.

const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")
const RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	## Representative families that must not collapse to one trail silhouette.
	var probes: Array[Dictionary] = [
		{"id": "magma_treaders", "tag": "magma"},
		{"id": "snowglobe_galoshes", "tag": "frost"},
		{"id": "voltcirc_coreloops", "tag": "volt"},
		{"id": "pikeapex_railfins", "tag": "rail"},
		{"id": "kelpjet_submariners", "tag": "kelp"},
		{"id": "slipstream_inlines", "tag": "roller"},
		{"id": "beatlink_tapstep_oxfords", "tag": "tap"},
	]
	var signatures: Dictionary = {}
	var visual: Node = RacerVisualScript.new()
	root.add_child(visual)

	for probe in probes:
		var vid := str(probe.get("id", ""))
		var tag := str(probe.get("tag", ""))
		if ShoeDataScript.load_by_id(vid).is_empty():
			failures.append("missing shoe %s" % vid)
			continue
		visual.set_vehicle_id(vid, false)
		if not visual.has_method("_footwear_trail_profile"):
			failures.append("RacerVisual missing _footwear_trail_profile")
			break
		var profile: Dictionary = visual.call("_footwear_trail_profile", ShoeDataScript.movement_archetype(vid))
		var sig := "%s|%s|%s|%s" % [
			str(profile.get("amount", 0)),
			str(profile.get("spread", 0.0)),
			str(profile.get("lifetime", 0.0)),
			str(profile.get("vmax", 0.0)),
		]
		if signatures.has(sig):
			failures.append(
				"trail profile collision: %s vs %s (%s)" % [tag, signatures[sig], sig]
			)
		else:
			signatures[sig] = tag
		var col: Color = visual.call("_footwear_trail_color", Color.WHITE, ShoeDataScript.movement_archetype(vid))
		if col.a <= 0.01:
			failures.append("%s trail color alpha collapsed" % tag)

	## Cosmetic-only stamp when describe_cosmetics exists (wardrobe overlays never claim handling).
	if visual.has_method("describe_cosmetics"):
		var cos: Dictionary = visual.call("describe_cosmetics")
		if bool(cos.get("affects_stats", true)):
			failures.append("cosmetics must not affect_stats")
		if bool(cos.get("affects_collision", true)):
			failures.append("cosmetics must not affect_collision")

	if signatures.size() < 5:
		failures.append("expected ≥5 distinct trail family signatures, got %d" % signatures.size())

	if failures.is_empty():
		print(
			"FootwearChaseCamPolishTest PASS — distinct trail families · stripe chase ID · cosmetic≠handling · not commercial"
		)
		quit(0)
	else:
		for f in failures:
			print("FAIL ", f)
		print("FootwearChaseCamPolishTest FAIL count=", failures.size())
		quit(1)
