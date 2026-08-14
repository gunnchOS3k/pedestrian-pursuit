extends RefCounted
class_name ConsolePlatformBridge

## Digital preparation only for Xbox / PlayStation / Nintendo.
## No proprietary SDK code. No fake certification evidence.

const PLATFORMS := ["xbox", "playstation", "nintendo"]

static func feature_gap_register() -> Dictionary:
	return {
		"schema": "gunnchos.console_feature_gap/v1",
		"state": "EXTERNAL_PENDING",
		"platforms": {
			"xbox": {"sdk_access": false, "devkit": false, "certification": false},
			"playstation": {"sdk_access": false, "devkit": false, "certification": false},
			"nintendo": {"sdk_access": false, "devkit": false, "certification": false},
		},
		"abstractions_present": [
			"controller",
			"save",
			"entitlement",
			"network",
			"achievement_trophy",
			"build_config_separation",
		],
		"notes": "Godot console delivery requires approved platform SDK access plus an appropriate export/porting path.",
	}
