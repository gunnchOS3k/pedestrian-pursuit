extends Node

const Provider = preload("res://scripts/cross_device/CrossDeviceContractProvider.gd")


func _ready() -> void:
	if not Provider.should_run_from_cli():
		return
	var snap := Provider.build_snapshot()
	var out_path := ProjectSettings.globalize_path(Provider.OUT_PATH)
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write contract: %s" % out_path)
		get_tree().quit(1)
		return
	f.store_string(JSON.stringify(snap, "\t"))
	f.close()
	print("cross_device_contract written: ", out_path)
	get_tree().call_deferred("quit", 0)
