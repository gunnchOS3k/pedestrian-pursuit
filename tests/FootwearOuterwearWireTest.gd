extends SceneTree

## Reviewed Codex wave pieces must mount. Fails if a sole or outerwear id is unwired.
## Cosmetic only. COURSE/HUMAN/RC2/V1 false. Not an 8-human PartyLink claim.

const RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")
const WardrobeCatalogScript = preload("res://scripts/data/WardrobeCatalog.gd")

const FOOTWEAR: PackedStringArray = [
	"reedline_circlers",
	"slipstream_inlines",
	"heelspin_quads",
	"cloudsole_striders",
	"tidefin_runners",
	"snowglobe_galoshes",
	"beatlink_tapstep_oxfords",
	"sofa_surfers",
]
const OUTERWEAR: PackedStringArray = [
	"metro_pulse_outer",
	"harbor_linen_outer",
	"neon_track_outer",
	"midnight_outer",
	"orbit_outer",
	"archive_cardigan",
]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var failures: PackedStringArray = []
	var visual: Node3D = RacerVisualScript.new()
	root.add_child(visual)
	await process_frame
	for id in FOOTWEAR:
		if str(visual.get("vehicle_id")) == id:
			visual.set_vehicle_id("voltstep_coils")
			await process_frame
		visual.set_vehicle_id(id)
		await process_frame
		_check_footwear(visual, id, failures)
	for id in OUTERWEAR:
		var garment: Dictionary = WardrobeCatalogScript.garment_by_id(id)
		if garment.is_empty() or str(garment.get("slot", "")) != "outerwear":
			failures.append("catalog missing outerwear %s" % id)
			continue
		visual.apply_wardrobe_outfit({"outerwear": id})
		await process_frame
		_check_outerwear(visual, id, failures)
	visual.free()
	await process_frame
	if failures.is_empty():
		print("FootwearOuterwearWireTest PASS — 8 authored soles + 6 atelier outerwear mounted · COURSE/HUMAN false")
		quit(0)
		return
	print("FootwearOuterwearWireTest FAIL:")
	for failure in failures:
		print(" - ", failure)
	quit(1)


func _check_footwear(visual: Node, id: String, failures: PackedStringArray) -> void:
	var left := visual.find_child("AuthoredSoleLeft", true, false) as MeshInstance3D
	var right := visual.find_child("AuthoredSoleRight", true, false) as MeshInstance3D
	if left == null or right == null:
		failures.append("footwear unwired %s" % id)
		return
	for mount in [left, right]:
		if str(mount.get_meta("vehicle_id", "")) != id:
			failures.append("footwear mount id mismatch %s" % id)
		if str(mount.get_meta("art_status", "")) != "runtime_candidate_pending_visual_review":
			failures.append("footwear review status missing %s" % id)
		if mount.get_child_count() < 1:
			failures.append("footwear mesh missing %s" % id)
		if not mount.find_children("*", "CollisionObject3D", true, false).is_empty():
			failures.append("footwear added gameplay collision %s" % id)


func _check_outerwear(visual: Node, id: String, failures: PackedStringArray) -> void:
	var torso := visual.get("_torso") as Node3D
	var garment := torso.get_node_or_null("Atelier_%s" % id) if torso != null else null
	if garment == null:
		failures.append("outerwear unwired %s" % id)
		return
	if str(garment.get_meta("garment_id", "")) != id:
		failures.append("outerwear id mismatch %s" % id)
	if int(garment.get_meta("layer_sample_count", 0)) <= 0:
		failures.append("outerwear not fitted to inner layers %s" % id)
	if not bool(garment.get_meta("cosmetic_only", false)):
		failures.append("outerwear not marked cosmetic %s" % id)
	if bool(garment.get_meta("human_approved", true)):
		failures.append("outerwear falsely human-approved %s" % id)
	for arm_name in ["_arm_l", "_arm_r"]:
		var arm := visual.get(arm_name) as Node
		if arm == null or arm.get_node_or_null("AtelierSleeve_%s" % id) == null:
			failures.append("outerwear sleeve unwired %s %s" % [id, arm_name])
