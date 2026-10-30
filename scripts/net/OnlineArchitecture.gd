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
		"field_size": PARTYLINK_FIELD_SIZE,
		"cpu_seats": cpu_count,
		"beatlink_sibling_humans": BEATLINK_SIBLING_CONTRACT_HUMANS,
		"independent_two_client_proven": true,
		"physical_eight_human_party": false,
		"bots_never_count_as_humans": true,
		"moltenvk_metal_pass": false,
		"COURSE_ACCEPTED": false,
		"HUMAN": false,
		"RC2": false,
		"V1": false,
		"seats": seats,
	}


static func write_evidence(abs_path: String) -> String:
	var text := JSON.stringify(describe(), "\t")
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return abs_path
