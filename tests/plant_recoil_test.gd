extends SceneTree
## Check real shot-triggered poses and recovery on all native plant instances.
## godot --headless --path . --fixed-fps 60 --script res://tests/plant_recoil_test.gd

var _failed: bool = false
var _main: Node3D
var _plants: Array[Peashooter] = []
var _events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _check_limits() -> void:
	for plant: Peashooter in _plants:
		var angle: float = plant.get_node("Head").rotation.z - plant._head_rest_rotation.z
		_check(absf(angle) <= deg_to_rad(30.0) + 0.00001, "Combined idle motion and recoil exceeded 30 degrees.")
		var stem := plant.get_node("Stem") as Node3D
		var head := plant.get_node("Head") as Node3D
		_check(absf(stem.rotation.z) <= deg_to_rad(30.0) + 0.00001, "Stem recoil exceeded 30 degrees.")
		var rest_connection := plant._stem_rest_transform.affine_inverse() * plant._head_rest_transform
		_check((stem.transform.affine_inverse() * head.transform).is_equal_approx(rest_connection), "Head and stem did not move together or lost their connection.")


func _step(frames: int) -> void:
	for i in range(frames):
		await physics_frame
		_check_limits()


func _on_shot(pea: PeaProjectile, plant: Peashooter) -> void:
	var angle: float = plant.get_node("Head").rotation.z - plant._head_rest_rotation.z
	_events.append({"plant": plant, "angle": angle, "frame": Engine.get_physics_frames(), "pea": pea})
	_check(angle > 0.0, "A pea fired without visible backward recoil.")
	_check_limits()
	_check(is_zero_approx(pea.direction.y) and pea.direction.dot(plant._horizontal_forward()) > 0.999, "Visual recoil tilted the projectile's flight direction.")
	_check(pea.damage == 20 and pea.speed == 10.0, "Visual recoil changed projectile damage or speed.")


func _reset() -> void:
	for plant: Peashooter in _plants:
		plant.combat_enabled = false
		plant.idle_animation_enabled = false
	_main._reset_view()
	await _step(3)
	_events.clear()


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	GameConfiguration.current().apply_entity(_main)
	_main.auto_respawn_enabled = false
	root.add_child(_main)
	_main._pole_zombie.movement_enabled = false
	_main._pole_zombie.is_ground_zombie = false
	_main._pole_zombie.set_spawn(_main._lawn.cell_to_world(4, 8) + Vector3(3, 0, 0), PI / 2.0)
	_plants.assign([_main._plant, _main._repeater, _main._threepeater, _main._gatling, _main._snowpea])
	_main._zombie.movement_enabled = false
	_main._cone_zombie.movement_enabled = false
	_main._bucket_zombie.movement_enabled = false
	for plant: Peashooter in _plants:
		plant.shot_fired.connect(_on_shot.bind(plant))
	await _reset()

	# Head and stem lean together while the planted root and leaves stay fixed.
	for plant: Peashooter in _plants:
		await _reset()
		var root_pose := plant.global_transform
		var head := plant.get_node("Head") as Node3D
		var rest_position := head.position
		var rest_scale := head.scale
		var stem := plant.get_node("Stem") as Node3D
		var stem_pose := stem.transform
		var root_mesh_pose: Transform3D = plant.get_node("Stem/Root").global_transform
		var leaves_pose: Transform3D = plant.get_node("Leaves").transform
		plant._fire()
		_check(head.rotation.z > deg_to_rad(10.0), "A normal shot did not produce a visible kick.")
		_check(head.position.x < rest_position.x - 0.01, "The head did not move slightly backward.")
		_check(plant.global_transform.is_equal_approx(root_pose), "Recoil displaced the planted entity.")
		_check(not stem.transform.is_equal_approx(stem_pose) and stem.rotation.z > deg_to_rad(10.0), "Recoil did not lean the stem together with the head.")
		_check(absf(stem.rotation.z - head.rotation.z) < 0.00001, "Head and stem did not share the same recoil angle.")
		_check(plant.get_node("Leaves").transform.is_equal_approx(leaves_pose), "Recoil leaned the ground leaves.")
		_check(plant.get_node("Stem/Root").global_transform.is_equal_approx(root_mesh_pose), "Recoil moved the root mesh off its planted position.")
		_check(head.scale.is_equal_approx(rest_scale), "Recoil changed the Repeater's model scale.")
		var peak := head.rotation.z
		var pea: PeaProjectile = _events[-1]["pea"]
		var launch_y := pea.global_position.y
		await _step(6)
		_check(head.rotation.z > 0.0 and head.rotation.z < peak, "The firing pose did not recover gradually.")
		_check(is_instance_valid(pea) and absf(pea.global_position.y - launch_y) < 0.0001, "The pea changed height during recoil.")
		await _step(20)
		_check(absf(head.rotation.z) < 0.00001 and head.position.is_equal_approx(rest_position), "The head did not fully recover to its rest pose.")
		_check(stem.transform.is_equal_approx(stem_pose), "The stem did not recover together with the head.")

	# Repeated kicks plus active idle motion respect the hard limit, even if a
	# runtime setting exceeds the Inspector's range.
	await _reset()
	var original: Peashooter = _main._plant
	original.idle_animation_enabled = true
	original.recoil_degrees = 120.0
	for i in range(8):
		original._fire()
		_check_limits()
	_check(absf(original.get_node("Head").rotation.z - deg_to_rad(30.0)) < 0.00001, "Repeated firing did not saturate at the 30-degree cap.")
	await _step(24)
	_check(is_zero_approx(original._recoil_angle), "Recoil did not finish while idle motion remained active.")
	original.recoil_degrees = 20.0

	# Both real shots of an automatic Repeater burst trigger the shared effect.
	await _reset()
	var repeater: Repeater = _main._repeater
	repeater.combat_enabled = true
	await _step(94)
	_check(_events.size() == 1, "The first automatic Repeater shot did not trigger recoil.")
	await _step(14)
	_check(_events.size() == 2, "The second automatic Repeater shot did not trigger recoil.")
	if _events.size() == 2:
		var elapsed := float(_events[1]["frame"] - _events[0]["frame"]) / Engine.physics_ticks_per_second
		_check(absf(elapsed - 0.18) < 0.025, "Recoil changed the two-pea burst timing.")
		_check(_events[1]["angle"] > _events[0]["angle"], "The second shot did not add a fresh kick while recovering.")
	var recovering_angle: float = repeater.get_node("Head").rotation.z
	_main._cone_zombie.is_ground_zombie = false
	await _step(3)
	_check(repeater.get_node("Head").rotation.z > 0.0 and repeater.get_node("Head").rotation.z < recovering_angle, "Losing the target abruptly cleared the recoil instead of recovering.")
	await _step(20)
	_check(is_zero_approx(repeater._recoil_angle) and _events.size() == 2, "Target loss did not stop firing and finish recoil recovery.")

	# Restart removes all residual angles and backward offsets immediately.
	for plant: Peashooter in _plants:
		plant._fire()
	_main._reset_view()
	for plant: Peashooter in _plants:
		_check(is_zero_approx(plant._recoil_angle) and is_zero_approx(plant.get_node("Head").rotation.z), "Restart left a firing angle on a plant.")
		_check(plant.get_node("Head").position.is_equal_approx(plant._head_rest_position), "Restart left a backward head offset.")
		_check(plant.get_node("Stem").transform.is_equal_approx(plant._stem_rest_transform), "Restart left the stem leaning backward.")
	_check(_main.get_node("Projectiles").get_child_count() == 0, "Restart left recoil-test peas in the scene.")
	_check(repeater._burst_shots_remaining == 0, "Restart left burst shots pending.")
	if not _failed:
		print("PASS: shared root-pivot recoil of head and full stem on all five plants, preserved head/stem connection, fixed root meshes/leaves, smooth recovery, 30deg combined-motion limit, runtime/rapid-fire cap, model scale, horizontal peas, both automatic burst shots, target-loss recovery and restart cleanup.")
	quit(1 if _failed else 0)
