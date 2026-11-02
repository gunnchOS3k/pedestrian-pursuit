extends RefCounted
class_name OnlineArchitecture

## Digital RC online architecture scaffold (private/dev only — no public deploy claim).
## Mirrors the private-room pattern used elsewhere in the product spine.

const PROTOCOL_VERSION := 1
const SCOPE := "private_dev_loopback_only"

const PARTYLINK_MIN_HUMAN_SEATS := 2
const PARTYLINK_MAX_HUMAN_SEATS := 8
const PARTYLINK_FIELD_SIZE := 8
## BeatLink sibling game-session contract remains host+guest (2 humans).
## Larger PartyLink fields fill non-human seats with CPU — never counted as humans.
const BEATLINK_SIBLING_CONTRACT_HUMANS := 2


static func describe() -> Dictionary:
	return {
		"schema": "pp_online_architecture/v1",
		"protocol_version": PROTOCOL_VERSION,
		"scope": SCOPE,
		"public_matchmaking": false,
		"partylink": {
			"min_human_seats": PARTYLINK_MIN_HUMAN_SEATS,
			"max_human_seats": PARTYLINK_MAX_HUMAN_SEATS,
			"field_size": PARTYLINK_FIELD_SIZE,
			"beatlink_sibling_contract_humans": BEATLINK_SIBLING_CONTRACT_HUMANS,
			"cpu_fills_remaining_seats": true,
			"bots_never_count_as_humans": true,
			"independent_two_process_proven": true,
			"physical_eight_human_party": false,
			"runtime_roster": "partylink_runtime_roster(allocated, connected)",
			"note": "Allocated seats 2–8 ≠ connected humans ≠ physical 8p. CPU fills empty seats. BeatLink sibling stays 2. No Mac MoltenVK invent.",
		},
		"modes": {
			"private_room": {
				"host_authoritative": true,
				"guest_join": true,
				"spectator": "planned",
				"input_sync": "snapshot_delta_v1",
				"rollback": false,
				"note": "Foot-racing netcode scaffold; not shipped as public online.",
			},
			"ghost_share": {
				"enabled_digital": true,
				"transport": "local_file_exchange",
				"note": "Time Trial ghosts already persist under user://.",
			},
		},
		"anti_cheat_digital": [
			"no_server_speed_override",
			"client_physics_shared_rules",
			"ghost_checksum_planned",
		],
		"status": "architecture_documented",
	}


static func partylink_seat_map(human_seats: int) -> Dictionary:
	## Allocated PartyLink capacity only — not connected humans and not physical 8p.
	## Prefer partylink_runtime_roster() when stamping live actors.
	var allocated := clampi(human_seats, PARTYLINK_MIN_HUMAN_SEATS, PARTYLINK_MAX_HUMAN_SEATS)
	var seats: Array = []
	for i in range(PARTYLINK_FIELD_SIZE):
		var allocated_human := i < allocated
		seats.append({
			"seat": i,
			"owner": "allocated_human" if allocated_human else "cpu",
			"counts_as_human_participant": false,
			"allocated_human_capacity": allocated_human,
			"note": "allocated_capacity_only_not_connected",
		})
	return {
		"human_seats": allocated,
		"allocated_human_seats": allocated,
		"connected_humans": 0,
		"field_size": PARTYLINK_FIELD_SIZE,
		"cpu_seats": PARTYLINK_FIELD_SIZE - allocated,
		"beatlink_sibling_humans": BEATLINK_SIBLING_CONTRACT_HUMANS,
		"physical_eight_human_party": false,
		"bots_never_count_as_humans": true,
		"seats": seats,
	}


static func partylink_runtime_roster(allocated_human_seats: int, connected_humans: int) -> Dictionary:
	## Live field ownership: connected humans vs CPU fill. Never invents humans.
	## Distinct from: 2-client Gate1, allocated lobby seats, physical 8-human PartyLink.
	var allocated := clampi(
		allocated_human_seats,
		PARTYLINK_MIN_HUMAN_SEATS,
		PARTYLINK_MAX_HUMAN_SEATS
	)
	var connected := clampi(connected_humans, 0, allocated)
	var seats: Array = []
	var cpu_count := 0
	var human_count := 0
	for i in range(PARTYLINK_FIELD_SIZE):
		var entry: Dictionary = {
			"seat": i,
			"allocated_human_capacity": i < allocated,
			"counts_as_human_participant": false,
			"control": "cpu",
			"owner": "cpu",
		}
		if i < connected:
			entry["owner"] = "human"
			entry["control"] = "human_input"
			entry["counts_as_human_participant"] = true
			human_count += 1
		else:
			cpu_count += 1
			if i < allocated:
				entry["owner"] = "cpu"
				entry["control"] = "cpu"
				entry["unoccupied_allocated_seat"] = true
				entry["note"] = "allocated_seat_cpu_fill_not_a_connected_human"
			else:
				entry["note"] = "field_cpu_fill"
		seats.append(entry)
	return {
		"schema": "pp_partylink_runtime_roster/v1",
		"allocated_human_seats": allocated,
		"connected_humans": connected,
		"human_seats_connected": human_count,
		"human_participant_count": human_count,
		"bot_participant_count": cpu_count,
		"field_size": PARTYLINK_FIELD_SIZE,
		"cpu_seats": cpu_count,
		"field_sum_humans_plus_bots": human_count + cpu_count,
		"beatlink_sibling_humans": BEATLINK_SIBLING_CONTRACT_HUMANS,
		"independent_two_client_proven": true,
		"physical_eight_human_party": false,
		"bots_never_count_as_humans": true,
		"bots_count_as_humans": false,
		"moltenvk_metal_pass": false,
		"COURSE_ACCEPTED": false,
		"HUMAN": false,
		"RC2": false,
		"V1": false,
		"seats": seats,
	}


static func partylink_human_bot_accounting(allocated_human_seats: int, connected_humans: int) -> Dictionary:
	## Explicit bots≠humans ledger for digital deepen / capacity gates.
	var roster := partylink_runtime_roster(allocated_human_seats, connected_humans)
	var humans := int(roster.get("human_participant_count", -1))
	var bots := int(roster.get("bot_participant_count", -1))
	return {
		"schema": "pp_partylink_human_bot_accounting/v1",
		"allocated_human_seats": int(roster.get("allocated_human_seats", 0)),
		"connected_humans": humans,
		"bot_participant_count": bots,
		"field_size": PARTYLINK_FIELD_SIZE,
		"humans_plus_bots": humans + bots,
		"bots_never_count_as_humans": true,
		"bots_count_as_humans": false,
		"physical_eight_human_party": false,
		"COURSE_ACCEPTED": false,
		"HUMAN": false,
	}


static func partylink_seat_cosmetic_bindings(
	allocated_human_seats: int,
	connected_humans: int,
	human_payloads: Array = []
) -> Dictionary:
	## Fashion deepen: bind chase-cam trail / appearance fingerprints onto seats.
	## Cosmetics never invent humans; bot seats may carry default CPU cosmetics only.
	var roster := partylink_runtime_roster(allocated_human_seats, connected_humans)
	var humans := int(roster.get("human_participant_count", 0))
	var bindings: Array = []
	var cosmetic_bound := 0
	for entry in roster.get("seats", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var seat_i := int(entry.get("seat", -1))
		var is_human := bool(entry.get("counts_as_human_participant", false))
		var fp := ""
		var trail_id := ""
		if is_human and seat_i >= 0 and seat_i < human_payloads.size():
			var payload: Variant = human_payloads[seat_i]
			if typeof(payload) == TYPE_DICTIONARY:
				fp = str(payload.get("fingerprint", payload.get("racer_id", "")))
				trail_id = str(payload.get("trail_expression_id", ""))
				if trail_id.is_empty():
					var slots: Dictionary = payload.get("outfit_slots", {})
					trail_id = str(slots.get("trail_expression", ""))
				cosmetic_bound += 1
		bindings.append({
			"seat": seat_i,
			"counts_as_human_participant": is_human,
			"appearance_fingerprint": fp,
			"trail_expression_id": trail_id,
			"cosmetics_count_as_human": false,
			"handling_owner": "footwear",
		})
	return {
		"schema": "pp_partylink_seat_cosmetic_bindings/v1",
		"allocated_human_seats": int(roster.get("allocated_human_seats", 0)),
		"connected_humans": humans,
		"cosmetic_bindings": bindings,
		"human_cosmetics_bound": cosmetic_bound,
		"bots_never_count_as_humans": true,
		"cosmetics_never_invent_humans": true,
		"physical_eight_human_party": false,
		"COURSE_ACCEPTED": false,
		"HUMAN": false,
	}


static func partylink_private_scope_honesty() -> Dictionary:
	## S7V: PartyLink stays private/dev loopback — no public matchmaking claim.
	var d := describe()
	return {
		"schema": "pp_partylink_private_scope_honesty/v1",
		"scope": str(d.get("scope", "")),
		"public_matchmaking": bool(d.get("public_matchmaking", true)),
		"private_scope_ok": str(d.get("scope", "")) == SCOPE and bool(d.get("public_matchmaking", true)) == false,
		"physical_eight_human_party": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


static func partylink_beatlink_sibling_honesty() -> Dictionary:
	## S7U: BeatLink sibling stays host+guest (2); PartyLink larger fields ≠ BeatLink.
	return {
		"schema": "pp_partylink_beatlink_sibling_honesty/v1",
		"beatlink_sibling_humans": BEATLINK_SIBLING_CONTRACT_HUMANS,
		"sibling_is_two": BEATLINK_SIBLING_CONTRACT_HUMANS == 2,
		"partylink_max_human_seats": PARTYLINK_MAX_HUMAN_SEATS,
		"partylink_neq_beatlink_sibling": PARTYLINK_MAX_HUMAN_SEATS != BEATLINK_SIBLING_CONTRACT_HUMANS,
		"physical_eight_human_party": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


static func partylink_allocated_bounds_honesty(requested_seats: int) -> Dictionary:
	## S7T: allocated seats clamp 2..8; never invent physical eight-human party.
	var map := partylink_seat_map(requested_seats)
	var allocated := int(map.get("allocated_human_seats", 0))
	var bounds_ok := allocated >= 2 and allocated <= 8
	return {
		"schema": "pp_partylink_allocated_bounds_honesty/v1",
		"requested_seats": requested_seats,
		"allocated_human_seats": allocated,
		"bounds_ok": bounds_ok,
		"physical_eight_human_party": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


static func partylink_field_sum_honesty(
	allocated_human_seats: int,
	connected_humans: int
) -> Dictionary:
	## S7R: humans+bots always sum to 8; never invent physical eight-human party.
	var acct := partylink_human_bot_accounting(allocated_human_seats, connected_humans)
	var humans := int(acct.get("connected_humans", 0))
	var bots := int(acct.get("bot_participant_count", 0))
	var total := int(acct.get("humans_plus_bots", humans + bots))
	return {
		"schema": "pp_partylink_field_sum_honesty/v1",
		"connected_humans": humans,
		"bot_participant_count": bots,
		"humans_plus_bots": total,
		"field_sum_ok": total == 8,
		"bots_never_count_as_humans": bool(acct.get("bots_never_count_as_humans", false)),
		"physical_eight_human_party": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


static func partylink_bot_cosmetics_never_humans(
	allocated_human_seats: int,
	connected_humans: int
) -> Dictionary:
	## S7Q: bot seats may carry default CPU cosmetics but never count as humans.
	var bindings := partylink_seat_cosmetic_bindings(allocated_human_seats, connected_humans, [])
	var bot_seats := 0
	var bot_marked_human := 0
	for b in bindings.get("cosmetic_bindings", []):
		if typeof(b) != TYPE_DICTIONARY:
			continue
		if bool(b.get("counts_as_human_participant", false)):
			continue
		bot_seats += 1
		if bool(b.get("cosmetics_count_as_human", false)):
			bot_marked_human += 1
	return {
		"schema": "pp_partylink_bot_cosmetics_never_humans/v1",
		"connected_humans": int(bindings.get("connected_humans", 0)),
		"bot_seats": bot_seats,
		"bot_cosmetics_marked_human": bot_marked_human,
		"bots_never_count_as_humans": bot_marked_human == 0,
		"physical_eight_human_party": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


static func partylink_seat_fingerprint_uniqueness(
	allocated_human_seats: int,
	connected_humans: int,
	human_payloads: Array = []
) -> Dictionary:
	## S7P: distinct human seat fingerprints stay unique; duplicates never mint seats.
	var bindings := partylink_seat_cosmetic_bindings(
		allocated_human_seats, connected_humans, human_payloads
	)
	var seen := {}
	var duplicate_fps := 0
	var human_fps := 0
	for b in bindings.get("cosmetic_bindings", []):
		if typeof(b) != TYPE_DICTIONARY:
			continue
		if not bool(b.get("counts_as_human_participant", false)):
			continue
		var fp := str(b.get("appearance_fingerprint", ""))
		if fp.is_empty():
			continue
		human_fps += 1
		if seen.has(fp):
			duplicate_fps += 1
		else:
			seen[fp] = true
	return {
		"schema": "pp_partylink_seat_fingerprint_uniqueness/v1",
		"connected_humans": int(bindings.get("connected_humans", 0)),
		"human_fingerprints": human_fps,
		"unique_fingerprints": seen.size(),
		"duplicate_fingerprints": duplicate_fps,
		"uniqueness_ok": duplicate_fps == 0,
		"cosmetics_never_invent_humans": bool(bindings.get("cosmetics_never_invent_humans", false)),
		"physical_eight_human_party": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


static func partylink_cosmetic_gap_integrity(
	allocated_human_seats: int,
	connected_humans: int,
	human_payloads: Array = []
) -> Dictionary:
	## S7O: sparse/missing cosmetic payloads must never invent human seats.
	var bindings := partylink_seat_cosmetic_bindings(
		allocated_human_seats, connected_humans, human_payloads
	)
	var humans := int(bindings.get("connected_humans", 0))
	var bound := int(bindings.get("human_cosmetics_bound", 0))
	var payload_n := human_payloads.size()
	var invents := bound > humans or bound > payload_n
	var human_seats_with_empty_cosmetics := 0
	for b in bindings.get("cosmetic_bindings", []):
		if typeof(b) != TYPE_DICTIONARY:
			continue
		if not bool(b.get("counts_as_human_participant", false)):
			continue
		if str(b.get("appearance_fingerprint", "")).is_empty():
			human_seats_with_empty_cosmetics += 1
	return {
		"schema": "pp_partylink_cosmetic_gap_integrity/v1",
		"connected_humans": humans,
		"payload_count": payload_n,
		"human_cosmetics_bound": bound,
		"human_seats_with_empty_cosmetics": human_seats_with_empty_cosmetics,
		"cosmetics_never_invent_humans": not invents,
		"gap_ok": not invents and humans == int(bindings.get("connected_humans", -1)),
		"bots_never_count_as_humans": true,
		"physical_eight_human_party": false,
		"COURSE_ACCEPTED": false,
		"HUMAN": false,
	}


static func write_evidence(abs_path: String) -> String:
	var text := JSON.stringify(describe(), "\t")
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return abs_path
