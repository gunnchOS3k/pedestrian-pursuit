extends SceneTree

## Headless: full 50-vehicle Kinetic Sole garage, six items intact.
## Tribute art may be procedural_final_for_garage or promoted native_v1 candidates (never commercial).

const VehicleCatalogScript = preload("res://scripts/data/VehicleCatalog.gd")
const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")
const ItemDataScript = preload("res://scripts/data/ItemData.gd")
const GarageProgressionScript = preload("res://scripts/data/GarageProgression.gd")

const PLAYABLE_ART := ["native_v1", "procedural_final_for_garage"]


func _init() -> void:
	var failures: PackedStringArray = []
	## CI/test harness unlocks all race-capable vehicles without claiming career unlocks.
	GarageProgressionScript.set_test_unlock_all(true)
	VehicleCatalogScript.load_registry(true)
	var ids := VehicleCatalogScript.all_ids()
	if ids.size() != 50:
		failures.append("registry size %d != 50" % ids.size())
	var playable := VehicleCatalogScript.playable_ids()
	if playable.size() != 50:
		failures.append("playable size %d != 50" % playable.size())
	var stubs := VehicleCatalogScript.stub_ids()
	if stubs.size() != 0:
		failures.append("stub size %d != 0" % stubs.size())
	var family_expect := {
		"street_legends": 8,
		"roller_revolution": 7,
		"hover_couture": 7,
		"elemental_amphibious": 6,
		"beautifully_ridiculous": 6,
		"gunnchos_crossover": 7,
		"anime_aggressors": 9,
	}
	for family_id in family_expect.keys():
		var family := VehicleCatalogScript.vehicles_in_family(family_id)
		var expect: int = int(family_expect[family_id])
		if family.size() != expect:
			failures.append("%s size %d != %d" % [family_id, family.size(), expect])
		for entry in family:
			if not bool(entry.get("playable", false)):
				failures.append("%s not playable: %s" % [family_id, str(entry.get("id", ""))])
			var art := str(entry.get("art_status", ""))
			if art not in PLAYABLE_ART:
				failures.append("%s art not garage-final: %s (%s)" % [family_id, str(entry.get("id", "")), art])
			if art == "stub_not_final":
				failures.append("%s still stub_not_final: %s" % [family_id, str(entry.get("id", ""))])
		if family_id == "anime_aggressors":
			## Tribute: procedural garage or native_v1 candidate — never commercial / Anime assets.
			for entry in family:
				var tribute_art := str(entry.get("art_status", ""))
				if tribute_art not in PLAYABLE_ART:
					failures.append(
						"tribute art must be procedural_final_for_garage or native_v1: %s"
						% str(entry.get("id", ""))
					)
				if bool(entry.get("human_commercial_art_approved", false)):
					failures.append("tribute commercial art must stay false: %s" % str(entry.get("id", "")))
				## Movement archetypes must be Pedestrian tribute_* — not Anime asset hooks.
				var arch := str(entry.get("movement_archetype", ""))
				if not arch.begins_with("tribute_"):
					failures.append("tribute archetype must be tribute_*: %s (%s)" % [str(entry.get("id", "")), arch])
	## Themed soles must keep grounded collision contracts + distinct fingerprints.
	for family_id in ["hover_couture", "elemental_amphibious", "beautifully_ridiculous", "gunnchos_crossover", "anime_aggressors"]:
		var themed := VehicleCatalogScript.vehicles_in_family(family_id)
		var fps: Dictionary = {}
		for hv in themed:
			var contract := str(hv.get("collision_contract", "")).to_lower()
			if "grounded" not in contract and "checkpoint" not in contract:
				failures.append("%s missing grounded collision contract: %s" % [family_id, str(hv.get("id"))])
			if "skip" in contract and "never" not in contract:
				failures.append("%s contract must forbid skipping: %s" % [family_id, str(hv.get("id"))])
			if family_id == "anime_aggressors" and "phase" in contract:
				if "never" not in contract and "not" not in contract:
					failures.append("tribute phase wording must forbid phase-through: %s" % str(hv.get("id")))
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
			if fps.has(fp):
				failures.append("duplicate %s fingerprint %s vs %s" % [family_id, fps[fp], str(hv.get("id"))])
			else:
				fps[fp] = str(hv.get("id"))
	for vid in playable:
		var shoe := ShoeDataScript.load_by_id(str(vid))
		if shoe.is_empty():
			failures.append("playable shoe missing %s" % vid)
			continue
		if not bool(shoe.get("playable", false)):
			failures.append("playable flag false for %s" % vid)
		var shoe_art := str(shoe.get("art_status", ""))
		if shoe_art not in PLAYABLE_ART:
			failures.append("playable art_status not garage-final: %s (%s)" % [vid, shoe_art])
		if float(shoe.get("handling_modifier", 0.0)) <= 0.0:
			failures.append("handling missing for %s" % vid)
	var race_ids := ShoeDataScript.race_selectable_ids()
	if race_ids.size() != 50:
		failures.append("race_selectable_ids %d != 50" % race_ids.size())
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
		print("VehicleGarageTest PASS — 50 IDs, 50 playable, 0 stubs, 6 items (tribute candidates, commercial false).")
		quit(0)
	else:
		print("VehicleGarageTest FAIL:")
		for f in failures:
			print(" - ", f)
		quit(1)
