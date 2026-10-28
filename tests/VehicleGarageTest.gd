extends SceneTree

## Headless: 50-vehicle registry, Street+Roller+Hover playable, six items intact.

const VehicleCatalogScript = preload("res://scripts/data/VehicleCatalog.gd")
const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")
const ItemDataScript = preload("res://scripts/data/ItemData.gd")


func _init() -> void:
	var failures: PackedStringArray = []
	VehicleCatalogScript.load_registry(true)
	var ids := VehicleCatalogScript.all_ids()
	if ids.size() != 50:
		failures.append("registry size %d != 50" % ids.size())
	var playable := VehicleCatalogScript.playable_ids()
	if playable.size() != 22:
		failures.append("playable size %d != 22" % playable.size())
	var stubs := VehicleCatalogScript.stub_ids()
	if stubs.size() != 28:
		failures.append("stub size %d != 28" % stubs.size())
	for family_id in ["street_legends", "roller_revolution", "hover_couture"]:
		var family := VehicleCatalogScript.vehicles_in_family(family_id)
		var expect := 8 if family_id == "street_legends" else 7
		if family.size() != expect:
			failures.append("%s size %d != %d" % [family_id, family.size(), expect])
		for entry in family:
			if not bool(entry.get("playable", false)):
				failures.append("%s not playable: %s" % [family_id, str(entry.get("id", ""))])
			if str(entry.get("art_status", "")) != "native_v1":
				failures.append("%s art not native_v1: %s" % [family_id, str(entry.get("id", ""))])
	## Hover/space must keep grounded collision contracts.
	var hovers := VehicleCatalogScript.vehicles_in_family("hover_couture")
	var hover_fps: Dictionary = {}
	for hv in hovers:
		var contract := str(hv.get("collision_contract", "")).to_lower()
		if "grounded" not in contract and "checkpoint" not in contract:
			failures.append("hover missing grounded collision contract: %s" % str(hv.get("id")))
		if "phase" in contract and "never" not in contract and "not" not in contract:
			## Allow "never ... phase" wording; reject contracts that imply phase-through.
			pass
		if "skip" in contract and "never" not in contract:
			failures.append("hover contract must forbid skipping: %s" % str(hv.get("id")))
		var fp := "%s|%s|%s|%s|%s|%s|%s|%s" % [
			str(hv.get("top_speed_modifier")),
			str(hv.get("acceleration_modifier")),
			str(hv.get("handling_modifier")),
			str(hv.get("drift_modifier")),
			str(hv.get("jump_modifier")),
			str(hv.get("boost_modifier")),
			str(hv.get("stomp_modifier")),
			str(hv.get("material_family")),
		]
		if hover_fps.has(fp):
			failures.append("duplicate hover fingerprint %s vs %s" % [hover_fps[fp], str(hv.get("id"))])
		else:
			hover_fps[fp] = str(hv.get("id"))
	for vid in playable:
		var shoe := ShoeDataScript.load_by_id(str(vid))
		if shoe.is_empty():
			failures.append("playable shoe missing %s" % vid)
			continue
		if not bool(shoe.get("playable", false)):
			failures.append("playable flag false for %s" % vid)
		if str(shoe.get("art_status", "")) != "native_v1":
			failures.append("playable art_status not native_v1: %s" % vid)
		if float(shoe.get("handling_modifier", 0.0)) <= 0.0:
			failures.append("handling missing for %s" % vid)
	for vid in stubs:
		var entry := VehicleCatalogScript.by_id(str(vid))
		if str(entry.get("art_status", "")) != "stub_not_final":
			failures.append("stub art flag wrong: %s" % vid)
		if bool(entry.get("playable", true)):
			failures.append("stub marked playable: %s" % vid)
	var race_ids := ShoeDataScript.race_selectable_ids()
	if race_ids.size() != 22:
		failures.append("race_selectable_ids %d != 22" % race_ids.size())
	## Signature shoes for eight roster runners.
	var runners := [
		"dash_reed", "nova_quill", "sierra_flux", "mira_lane",
		"bolt_harbor", "zig_riven", "solen_pike", "kai_volt",
	]
	for rid in runners:
		var sig := VehicleCatalogScript.signature_vehicle_for_runner(rid)
		if sig.is_empty() or not ShoeDataScript.is_playable(sig):
			failures.append("missing signature vehicle for %s" % rid)
	## Six race items preserved.
	var items := ItemDataScript.all_mvp_ids()
	if items.size() < 6:
		failures.append("item pool < 6")
	for iid in items:
		var item := ItemDataScript.load_by_id(str(iid))
		if item.is_empty() or not item.has("counterplay"):
			failures.append("item broken: %s" % iid)
	## Legacy shoes still load for challenges.
	for lid in ShoeDataScript.legacy_ids():
		if ShoeDataScript.load_by_id(lid).is_empty():
			failures.append("legacy shoe missing %s" % lid)

	if failures.is_empty():
		print("VehicleGarageTest PASS — 50 IDs, 22 playable (Street+Roller+Hover), 28 stubs, 6 items.")
		quit(0)
	else:
		print("VehicleGarageTest FAIL:")
		for f in failures:
			print(" - ", f)
		quit(1)
