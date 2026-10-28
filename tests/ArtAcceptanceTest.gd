extends SceneTree

## Final-art acceptance is distinct from runtime playability.

const ArtAcceptanceScript = preload("res://scripts/data/ArtAcceptance.gd")
const VehicleCatalogScript = preload("res://scripts/data/VehicleCatalog.gd")


func _init() -> void:
	var failures: PackedStringArray = []
	ArtAcceptanceScript.load_registry(true)
	VehicleCatalogScript.load_registry(true)
	var counts := ArtAcceptanceScript.counts()
	if int(counts.get("total", 0)) != 50:
		failures.append("art acceptance total %s != 50" % str(counts.get("total")))
	if int(counts.get("playable_runtime", 0)) != 50:
		failures.append("playable_runtime %s != 50" % str(counts.get("playable_runtime")))
	if int(counts.get("final_art_approved", 0)) != 0:
		failures.append("commercial final_art_approved must be 0")
	if not ArtAcceptanceScript.procedural_never_satisfies_commercial():
		failures.append("procedural/garage art silently claimed commercial approval")
	for vid in VehicleCatalogScript.all_ids():
		var entry := ArtAcceptanceScript.by_id(vid)
		if entry.is_empty():
			failures.append("missing art acceptance for %s" % vid)
			continue
		if str(entry.get("runtime_status", "")) != "playable_runtime":
			failures.append("%s runtime_status not playable_runtime" % vid)
		var fas := str(entry.get("final_art_status", ""))
		if fas not in ["final_art_pending", "final_art_candidate"]:
			failures.append("%s unexpected final_art_status %s" % [vid, fas])
		if bool(entry.get("human_commercial_art_approved", false)):
			failures.append("%s commercial art approved without human gate" % vid)
		## Runtime playability must not imply commercial art.
		if VehicleCatalogScript.is_playable(vid) and fas == "final_art_approved":
			failures.append("%s playable silently marked final_art_approved" % vid)
	if int(counts.get("final_art_candidate", 0)) < 1:
		failures.append("expected some final_art_candidate entries")
	if int(counts.get("final_art_pending", 0)) < 1:
		failures.append("expected some final_art_pending entries")

	if failures.is_empty():
		print(
			"ArtAcceptanceTest PASS — runtime %d · pending %d · candidate %d · commercial approved 0"
			% [
				int(counts.get("playable_runtime", 0)),
				int(counts.get("final_art_pending", 0)),
				int(counts.get("final_art_candidate", 0)),
			]
		)
		quit(0)
	else:
		print("ArtAcceptanceTest FAIL:")
		for f in failures:
			print(" - ", f)
		quit(1)
