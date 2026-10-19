extends SceneTree
## Real imported skin, bone playback and demo combat/lifecycle integration.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	if not value:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for frame in frames:
		await physics_frame


func _normal(demo: StageDemo) -> StageZombie:
	for actor: StageZombie in demo.get_node("Enemies").get_children():
		if actor.enemy_kind == "zombie":
			return actor
	return null


func _quiet(demo: StageDemo) -> void:
	demo._dave.set_physics_process(false)
	demo._sun_system._timer.stop()
	for plant: Node in demo.get_node("Plants").get_children():
		plant.set_physics_process(false)
	for enemy: StageZombie in demo.get_node("Enemies").get_children():
		if enemy.enemy_kind != "zombie":
			enemy.set_physics_process(false)


func _run() -> void:
	create_timer(90.0).timeout.connect(func():
		push_error("Animated zombie test watchdog")
		quit(1)
	)
	var config := GameConfiguration.current()
	config.emit_warnings = false
	var defaults := config.default_values()
	var invalid := defaults.duplicate(true)
	invalid.demo_zombie_animation.enabled = "yes"
	config.use_values_for_tests(invalid)
	_check(config.values.demo_zombie_animation.enabled == true, "Invalid model toggle must fall back to true")
	config.use_values_for_tests(defaults)
	var demo := load("res://scenes/stages/day.tscn").instantiate() as StageDemo
	root.add_child(demo)
	_quiet(demo)
	await _step(3)
	var actor := _normal(demo)
	_check(actor != null and actor.animated_visual != null, "Default day demo must use imported normal-zombie model")
	if actor == null or actor.animated_visual == null:
		quit(1)
		return
	var visual := actor.animated_visual
	_check(visual.skeleton.get_bone_count() == 25, "Expected the 25-bone authored humanoid rig")
	_check(visual.skinned_mesh.skin != null and visual.skinned_mesh.skin.get_bind_count() >= 24, "Mesh must have actual skin binds")
	for name: StringName in [&"Idle", &"Walk", &"Eat", &"Hit", &"Fall"]:
		_check(visual.clip_names.has(name), "Missing imported clip: " + String(name))
	for mesh: MeshInstance3D in actor._legacy_meshes:
		_check(not mesh.visible, "Legacy body must stay hidden under imported model")
	for enemy: StageZombie in demo.get_node("Enemies").get_children():
		if enemy.enemy_kind != "zombie":
			_check(enemy.animated_visual == null, "Other zombie types must retain their existing models")
	actor.set_spawn(demo.lawn.cell_to_world(0, 9), PI * 0.5)
	var start := actor.global_position
	var thigh := visual.skeleton.find_bone("Thigh.L")
	var initial_leg := visual.skeleton.get_bone_pose_rotation(thigh)
	await _step(12)
	_check(visual.current_state == &"Walk", "Moving zombie must play Walk")
	_check(absf(start.x - actor.global_position.x - 0.1) < .025, "Rig must preserve the existing 0.5-unit/s movement")
	_check(visual.skeleton.get_bone_pose_rotation(thigh).angle_to(initial_leg) > .02, "Leg skin must be driven by changing bone rotations")
	actor.apply_slow(.5, 2.0)
	var before_slow := visual.player.current_animation_position
	await _step(12)
	var slow_progress := fposmod(visual.player.current_animation_position - before_slow, 1.1)
	_check(absf(slow_progress - .1) < .035, "Cold must halve skeletal walk playback as well as movement")
	actor.apply_freeze(.5)
	var frozen_time := visual.player.current_animation_position
	var frozen_leg := visual.skeleton.get_bone_pose_rotation(thigh)
	await _step(14)
	_check(absf(visual.player.current_animation_position - frozen_time) < .0001, "Freeze must stop the imported animation clock")
	_check(visual.skeleton.get_bone_pose_rotation(thigh).angle_to(frozen_leg) < .0001, "Freeze must hold the exact bone pose")
	await _step(22)
	_check(absf(visual.player.current_animation_position - frozen_time) > .01, "Animation must resume after freezing")
	actor.reset_combat()
	var victim := demo.get_node("Plants").get_child(0) as StagePlant
	victim.display_only = false
	victim.global_position = demo.lawn.cell_to_world(0, 6)
	actor.set_spawn(victim.global_position + Vector3.RIGHT * .85, PI * .5)
	var victim_health := victim.health
	var bite_position := actor.global_position
	await _step(30)
	_check(visual.current_state == &"Eat", "A plant in range must select Eat")
	_check(victim.health < victim_health, "Imported zombie must still inflict real bite damage")
	_check(absf(actor.global_position.x - bite_position.x) < .02, "Zombie must stop walking while eating")
	var jaw := visual.skeleton.find_bone("Jaw")
	_check(visual.skeleton.get_bone_pose_rotation(jaw).get_angle() > .01, "Biting must animate the skinned lower jaw")
	actor.take_damage(20, Vector3.RIGHT)
	_check(visual.current_state == &"Hit", "Nonlethal damage must trigger Hit")
	_check(visual.skinned_mesh.material_override == Zombie.HIT_MATERIAL, "Imported mesh must retain hit flash")
	await _step(34)
	_check(visual.current_state == &"Eat", "Hit must blend back into the current bite state")
	_check(visual.skinned_mesh.material_override != Zombie.HIT_MATERIAL, "Hit flash must restore the original textured material")
	actor.apply_slow(.5, 10)
	var frost_material := visual.skinned_mesh.material_override
	actor.take_damage(actor.health, Vector3.RIGHT)
	_check(not actor.visible and not actor.is_alive(), "Death must remove the standing target immediately")
	_check(actor._animated_corpses.size() == 1, "Death must create exactly one independent animated body")
	var corpse := actor._animated_corpses[0]
	_check(corpse.visual.current_state == &"Fall", "Corpse must start the authored Fall clip")
	_check(corpse.visual.skinned_mesh.material_override != frost_material and corpse.visual.skinned_mesh.get_active_material(0) != Zombie.HIT_MATERIAL, "Independent corpse must keep the original texture instead of frost or hit material")
	await _step(20)
	_check(corpse.visual.player.current_animation_position > .25, "Fall must visibly advance")
	var pause_position := corpse.visual.player.current_animation_position
	paused = true
	await _step(8)
	_check(absf(corpse.visual.player.current_animation_position - pause_position) < .0001, "SceneTree pause must also hold the falling corpse")
	paused = false
	await _step(48)
	var replacement := _normal(demo)
	_check(replacement != actor and replacement.is_alive() and replacement.animated_visual != null, "One-second respawn must create a fresh rigged actor")
	_check(is_instance_valid(corpse) and corpse.age > 1, "Respawn must not interrupt the old full-body fall")
	await _step(50)
	_check(not corpse.visual.player.is_playing(), "Fall must stop at its final resting pose, not loop")
	var root_bone := corpse.visual.skeleton.find_bone("Root")
	_check(corpse.visual.skeleton.get_bone_pose_rotation(root_bone).get_angle() > 1.4, "Final corpse must lie down instead of standing")
	demo.reset_stage()
	await _step(3)
	_check(get_nodes_in_group("animated_zombie_corpses").is_empty(), "R/reset must remove old animated bodies")
	_check(_normal(demo).animated_visual.current_state in [&"Idle", &"Walk"], "Reset must restore normal playback")
	root.remove_child(demo)
	demo.queue_free()
	await _step(3)
	for stage_name: String in ["night", "pool", "fog", "roof"]:
		var other := load("res://scenes/stages/" + stage_name + ".tscn").instantiate() as StageDemo
		root.add_child(other)
		_quiet(other)
		await _step(3)
		_check(_normal(other).animated_visual != null, "Imported model missing from " + stage_name)
		if stage_name == "roof":
			var roof_actor := _normal(other)
			roof_actor.take_damage(roof_actor.health, Vector3.RIGHT)
			var roof_corpse := roof_actor._animated_corpses[0]
			var p := roof_actor.global_position
			var dx := (other.lawn.surface_at(p + Vector3.RIGHT * .1) - other.lawn.surface_at(p - Vector3.RIGHT * .1)) / .2
			var expected_up := Vector3(-dx,1,0).normalized()
			_check(roof_corpse.global_basis.y.normalized().dot(expected_up) > .999, "Roof corpse must align with the roof support plane")
		root.remove_child(other)
		other.queue_free()
		await _step(2)
	var original_demo := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(original_demo)
	await _step(2)
	_check(original_demo._zombie.animated_visual != null, "Original demo 0 must also show the imported model")
	original_demo._toggle_zombie_view()
	await _step(2)
	_check(original_demo._orbit.camera.is_current(), "Z inspection must still focus the imported zombie")
	original_demo._zombie.take_damage(original_demo._zombie.health, Vector3.RIGHT)
	await _step(2)
	_check(original_demo._zombie._animated_corpses.size() == 1, "Original flat demo must support death without stage-lawn metadata")
	root.remove_child(original_demo)
	original_demo.queue_free()
	await _step(2)
	var board := load("res://scenes/adventure/level_1.tscn").instantiate() as AdventureBoard
	root.add_child(board)
	await _step(2)
	var adventure_enemy := board.spawn_enemy("zombie", 2)
	_check(adventure_enemy.animated_visual == null, "Adventure must retain its existing zombie pipeline")
	root.remove_child(board)
	board.queue_free()
	await _step(2)
	var legacy_config := defaults.duplicate(true)
	legacy_config.demo_zombie_animation.enabled = false
	config.use_values_for_tests(legacy_config)
	var legacy := load("res://scenes/stages/day.tscn").instantiate() as StageDemo
	root.add_child(legacy)
	await _step(2)
	_check(_normal(legacy).animated_visual == null, "Disabling the model toggle must preserve the original visual/debris path")
	root.remove_child(legacy)
	legacy.queue_free()
	await _step(2)
	var short_corpse := DemoZombieCorpse.new()
	short_corpse.lifetime = .4
	root.add_child(short_corpse)
	await _step(20)
	_check(not short_corpse.visual.player.is_playing(), "Short corpse lifetimes must finish an accelerated fall before fading")
	await _step(8)
	_check(not is_instance_valid(short_corpse), "Configured short corpse lifetime must clean up the animated body")
	if not _failed:
		print("PASS: 25-bone skin and five clips, walking speed/pose, slowed playback, freeze/resume, actual bite and jaw, hit recovery, complete fall across respawn, pause/reset cleanup, all demo stages and Z view, adventure isolation and validated legacy option.")
	quit(1 if _failed else 0)
