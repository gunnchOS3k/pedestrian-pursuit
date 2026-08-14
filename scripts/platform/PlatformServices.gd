extends Node
class_name PlatformServices

## GAME-RC-003 multi-platform abstraction. Console SDKs are EXTERNAL_PENDING —
## this module never claims proprietary SDK access or certification.

signal achievement_bridged(achievement_id: String, platform: String)

enum Host {
	UNKNOWN,
	DESKTOP,
	WEB,
	ANDROID,
	IOS,
	STEAM,
	CONSOLE_ABSTRACT,
}

var host: int = Host.UNKNOWN
var save_root_override: String = ""


func _ready() -> void:
	host = detect_host()


func detect_host() -> int:
	var name := OS.get_name()
	match name:
		"Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return Host.DESKTOP
		"macOS":
			return Host.DESKTOP
		"Android":
			return Host.ANDROID
		"iOS":
			return Host.IOS
		"Web":
			return Host.WEB
		_:
			return Host.UNKNOWN


func platform_id() -> String:
	match host:
		Host.DESKTOP:
			return OS.get_name().to_lower()
		Host.ANDROID:
			return "android"
		Host.IOS:
			return "ios"
		Host.WEB:
			return "web"
		Host.STEAM:
			return "steam"
		Host.CONSOLE_ABSTRACT:
			return "console_abstract"
		_:
			return "unknown"


func save_path(relative: String) -> String:
	if not save_root_override.is_empty():
		return save_root_override.path_join(relative)
	return "user://".path_join(relative)


func bridge_achievement(achievement_id: String) -> void:
	achievement_bridged.emit(achievement_id, platform_id())


func controller_scheme() -> String:
	return "generic_gamepad"


func network_available() -> bool:
	return true


func entitlements_ready() -> bool:
	return true


func describe() -> Dictionary:
	return {
		"schema": "gunnchos.platform_services/v1",
		"platform_id": platform_id(),
		"os_name": OS.get_name(),
		"console_sdk": "EXTERNAL_PENDING",
		"steam_sdk": "FOUNDATION_ONLY",
		"save_policy": "user_data_dir",
	}
