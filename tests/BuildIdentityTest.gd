extends SceneTree

const BuildIdentityScript := preload("res://scripts/core/BuildIdentity.gd")


func _init() -> void:
	var identity = BuildIdentityScript.new()
	identity._load()
	var failures: PackedStringArray = []
	if identity.is_review_flavor() and not identity.review_sha_known():
		failures.append("review_flavor_embedded_UNKNOWN")
	if FileAccess.file_exists(BuildIdentityScript.PATH):
		if identity.git_sha() == BuildIdentityScript.UNKNOWN:
			failures.append("stamped_identity_UNKNOWN")
		if str(identity.git_sha()).is_empty():
			failures.append("stamped_identity_empty")
	if failures.is_empty():
		print("BUILD_IDENTITY_TEST=PASS")
		print("flavor=%s sha=%s" % [identity.build_flavor(), identity.git_sha()])
		quit(0)
	else:
		print("BUILD_IDENTITY_TEST=FAIL")
		for row in failures:
			print("FAIL %s" % row)
		quit(1)
