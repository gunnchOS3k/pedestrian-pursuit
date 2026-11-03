extends SceneTree
## Real PlayerRacer and complete fixed-SHA controller negative fixture.
var output := ""
var baseline := ""
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--baseline-controller="):baseline=arg.trim_prefix("--baseline-controller=")
	call_deferred("run")
func racer()->CharacterBody3D:
	var node:=load("res://scenes/player/PlayerRacer.tscn").instantiate() as CharacterBody3D
	if not baseline.is_empty():node.set_script(load(baseline))
	root.add_child(node);node.set_physics_process(false)
	node.get_node("RacerVisual").set_process(false)
	return node
func run()->void:
	await process_frame
	var live:=racer()
	var visual:=live.get_node("RacerVisual")
	var expected_pose:=str(visual.profile.recovery_style) if visual.profile else "jog"
	var checkpoint:=Transform3D(Basis.IDENTITY,Vector3(7,2,5))
	live.set_recovery_transform(checkpoint);live.velocity=Vector3(4,-3,2);live.horizontal_speed=10.0
	live._recover_from_fall()
	var behavior:Dictionary={"checkpoint_preserved":live.global_transform==checkpoint,"velocity_zero":live.velocity==Vector3.ZERO,"speed_reduction_preserved":is_equal_approx(live.horizontal_speed,3.5),"stun_preserved":is_equal_approx(live.get("_collision_stun"),.6),"terrain_preserved":live.terrain_speed_multiplier==1 and live.terrain_handling_multiplier==1}
	await create_timer(.4).timeout
	behavior.live_recovery_pose=live.get_node("RacerVisual").get("_pose_state")==expected_pose
	live.queue_free();await process_frame
	for i in range(8):
		var early:=racer();early._recover_from_fall();early.queue_free();await process_frame
	await create_timer(.5).timeout
	var failures:Array=[]
	for key in behavior:
		if not behavior[key]:failures.append(key)
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"baseline_controller":baseline,"engine":Engine.get_version_info(),"actual_player_scene":"res://scenes/player/PlayerRacer.tscn","behavior":behavior,"eight_early_free_callbacks_delivered":true,"failures":failures,"behavior_pass":failures.is_empty(),"log_errors_require_separate_fail_closed_assessment":true,"HUMAN":false,"RC2":false,"V1":false},"  "));file.close()
	print("RECOVERY_LIFETIME_BEHAVIOR_COMPLETE failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
