extends RefCounted
class_name OnlineArchitecture

## Digital RC online architecture scaffold (private/dev only — no public deploy claim).
## Mirrors the private-room pattern used elsewhere in the product spine.

const PROTOCOL_VERSION := 1
const SCOPE := "private_dev_loopback_only"

static func describe() -> Dictionary:
	return {
		"schema": "pp_online_architecture/v1",
		"protocol_version": PROTOCOL_VERSION,
		"scope": SCOPE,
		"public_matchmaking": false,
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


static func write_evidence(abs_path: String) -> String:
	var text := JSON.stringify(describe(), "\t")
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return abs_path
