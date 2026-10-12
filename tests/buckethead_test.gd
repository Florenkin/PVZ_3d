extends SceneTree
## Bucket armor, rigid-body debris, full-health respawn and real Gatling combat.

var _failed: bool = false
var _main: Node3D
var _lawn: LawnGrid
var _zombie: Zombie
var _parts: Array[ZombieDebris] = []
var _death_frames: Array[int] = []
var _respawn_frames: Array[int] = []
var _natural: bool = false
var _cycle_hits: int = 0
var _other_respawns: Array[int] = [0, 0]


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for index in range(frames):
		await physics_frame


func _watch(zombie: Zombie) -> void:
	if not zombie.part_detached.is_connected(_on_part):
		zombie.part_detached.connect(_on_part)
		zombie.defeated.connect(_on_defeated)
		zombie.damaged.connect(_on_damage)


func _on_part(part: ZombieDebris) -> void:
	_parts.append(part)
	_check(part is RigidBody3D and part.gravity_scale == 1.0 and part.collision_layer == 16 and part.collision_mask == 17, "Buckethead parts do not use independent rigid-body physics.")
	_check(part.lifetime == (5.0 if part.part_kind == &"corpse" else 10.0), "Incorrect buckethead part lifetime.")


func _on_damage(amount: int) -> void:
	if _natural:
		_check(amount == 20, "Gatling dealt incorrect damage to the buckethead.")
		_cycle_hits += 1


func _on_defeated() -> void:
	_death_frames.append(Engine.get_physics_frames())
	if _natural:
		_check(_cycle_hits == 69, "A 1370-HP buckethead was not defeated in exactly 69 pea impacts.")


func _on_respawn(zombie: Zombie) -> void:
	if not zombie.has_bucket:
		_other_respawns[1 if zombie.has_cone else 0] += 1
		return
	_zombie = zombie
	_watch(zombie)
	_respawn_frames.append(Engine.get_physics_frames())
	_check(zombie.health == 1370 and zombie.has_bucket and not zombie.has_cone and zombie.get_node("Visuals/Head/Bucket").visible, "Buckethead respawn lost its type, full health or armor.")
	_check(zombie.global_position.distance_to(_lawn.cell_to_world(0, 8)) < 0.001, "Buckethead did not respawn at the Gatling lane's far baseline.")
	_check(_main.get_node("Enemies").get_child_count() == 5 and get_nodes_in_group("zombies").size() == 5, "Independent respawns duplicated living enemies.")
	_check(_main._bucket_health_bar.value == 1370, "Respawn did not update buckethead health UI.")
	if not _death_frames.is_empty():
		_check(absf(float(_respawn_frames[-1] - _death_frames[-1]) / Engine.physics_ticks_per_second - 1.0) < 0.035, "Buckethead did not respawn 1 second after death.")
	if _natural:
		_check(_cycle_hits == 69, "Buckethead respawn interrupted its final damage count.")
		_cycle_hits = 0


func _part(kind: StringName) -> ZombieDebris:
	for part: ZombieDebris in _parts:
		if is_instance_valid(part) and part.part_kind == kind:
			return part
	return null


func _reset() -> void:
	_main.auto_respawn_enabled = false
	for plant: Peashooter in [_main._plant, _main._repeater, _main._threepeater, _main._gatling, _main._snowpea]:
		plant.combat_enabled = false
	_main._reset_view()
	_zombie = _main._bucket_zombie
	_zombie.movement_enabled = false
	_zombie.set_spawn(_lawn.cell_to_world(0, 5), PI / 2.0)
	await _step(3)
	_parts.clear()
	_watch(_zombie)


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	GameConfiguration.current().apply_entity(_main)
	_main.auto_respawn_enabled = false
	root.add_child(_main)
	# Isolate these existing cases from the new fifth-lane enemy.
	_main._newspaper_zombie.movement_enabled = false
	_main._newspaper_zombie.is_ground_zombie = false
	_main._newspaper_zombie.set_spawn(_main._lawn.cell_to_world(3, 8) + Vector3(40, 0, 0), PI / 2.0)
	_main._pole_zombie.movement_enabled = false
	_main._pole_zombie.is_ground_zombie = false
	_main._pole_zombie.set_spawn(_main._lawn.cell_to_world(4, 8) + Vector3(3, 0, 0), PI / 2.0)
	_lawn = _main._lawn
	_main._pole_zombie.movement_enabled = false
	_main._pole_zombie.is_ground_zombie = false
	_main._pole_zombie.set_spawn(_lawn.cell_to_world(4, 8) + Vector3(3, 0, 0), PI / 2.0)
	_zombie = _main._bucket_zombie
	_main._zombie.movement_enabled = false
	_main._cone_zombie.movement_enabled = false
	_watch(_zombie)
	_main.zombie_respawned.connect(_on_respawn)
	_check(_zombie.health == 1370 and _zombie.has_bucket and not _zombie.has_cone, "Buckethead has the wrong initial health or armor type.")
	_check(_lawn.world_to_cell(_zombie.global_position) == Vector2i(8, 0) and _lawn.world_to_cell(_main._gatling.global_position) == Vector2i(1, 0), "Buckethead is not at the end of Gatling's lane.")
	_check((-_zombie.global_basis.z).dot(Vector3.LEFT) > 0.999 and _zombie.walk_speed == 0.5, "Buckethead does not face or walk toward the plant correctly.")
	_check(_zombie.has_node("Visuals/Head/Bucket/Handle") and _zombie.has_node("Visuals/Head/Bucket/Interior"), "Buckethead lacks the open metal bucket or handle.")
	var metal := _zombie.get_node("Visuals/Head/Bucket/Body").material_override as StandardMaterial3D
	_check(metal.metallic > 0.5, "The bucket lacks its metallic material.")
	_check(_main._bucket_health_label.text.contains("1370") and _main._bucket_health_bar.value == 1370, "Buckethead health did not appear in the interface.")
	await _reset()

	# 201 HP keeps the bucket; precisely 200 detaches it once with real gravity.
	_zombie.take_damage(1169, Vector3.RIGHT)
	_check(_zombie.health == 201 and _parts.is_empty() and _zombie.get_node("Visuals/Head/Bucket").visible, "The bucket detached above 200 HP.")
	_check(_zombie.get_node("Visuals/Head/Bucket/Body").material_override == Zombie.HIT_MATERIAL, "The bucket was omitted from the full-body hit flash.")
	_zombie.take_damage(1, Vector3.RIGHT)
	var bucket := _part(&"bucket")
	_check(bucket != null and _parts.size() == 1 and not _zombie.get_node("Visuals/Head/Bucket").visible, "Exactly one bucket did not detach at 200 HP.")
	await _step(3)
	if bucket != null:
		_check(bucket.get_parent() == _main._debris and bucket.get_node("CollisionShape3D").shape is CylinderShape3D, "The bucket does not have its own parent and physical collider.")
		var launch_y := bucket.global_position.y
		var vertical_speed := bucket.linear_velocity.y
		await _step(10)
		_check(bucket.global_position.y > launch_y and bucket.linear_velocity.y < vertical_speed, "The detached bucket did not rise under gravity on a ballistic path.")
		var landing_rotation := Quaternion.IDENTITY
		var landed_before := false
		var ground_tumble := 0.0
		for index in range(120):
			await _step(1)
			if bucket.has_landed:
				if not landed_before:
					landed_before = true
					landing_rotation = bucket.quaternion
				ground_tumble = maxf(ground_tumble, landing_rotation.angle_to(bucket.quaternion))
		_check(bucket.has_landed and ground_tumble > 0.1, "The bucket did not contact and tumble on the lawn.")
		_check(bucket.get_node("Model/Body").material_override == metal, "The physical bucket did not restore its steel palette after flashing.")
		_zombie.take_damage(1, Vector3.RIGHT)
		_check(_parts.size() == 1, "Repeated hits detached the bucket twice.")
		var remaining := int(ceil((10.0 - bucket.age) * Engine.physics_ticks_per_second))
		await _step(maxi(remaining - 2, 0))
		_check(is_instance_valid(bucket), "The bucket disappeared before its 10-second lifetime.")
		await _step(5)
		_check(not is_instance_valid(bucket), "The detached bucket survived its 10-second lifetime.")

	# Existing 100-HP arm loss and 0-HP physical death also apply to bucketheads.
	await _reset()
	_zombie.take_damage(1269, Vector3.RIGHT)
	_check(_zombie.health == 101 and _parts.size() == 1, "Buckethead lost a hand above 100 HP.")
	_zombie.take_damage(1, Vector3.RIGHT)
	_check(_parts.size() == 2 and (_part(&"left_hand") != null or _part(&"right_hand") != null), "Buckethead did not randomly lose one hand at 100 HP.")
	_zombie.take_damage(5, Vector3.RIGHT)
	_check(_parts.size() == 2, "Buckethead lost multiple hands from repeated threshold hits.")

	await _reset()
	_zombie.take_damage(9999, Vector3.RIGHT)
	_check(_parts.size() == 4 and _part(&"bucket") != null and _part(&"head") != null and _part(&"corpse") != null, "One lethal hit did not detach exactly a bucket, one hand, a head and a body.")
	var head := _part(&"head")
	var corpse := _part(&"corpse")
	_check(not head.get_node("Model/Bucket").visible and not _zombie.visible, "Death duplicated the bucket on the flying head or left a standing zombie.")
	await _step(303)
	_check(not is_instance_valid(corpse) and is_instance_valid(head) and is_instance_valid(_part(&"bucket")), "Buckethead body and detached parts do not have independent lifetimes.")
	await _step(310)
	_check(not is_instance_valid(head) and _main._debris.get_child_count() == 0, "Buckethead remains were not cleaned up after 10 seconds.")

	# Reset before deferred physics attachment cancels every part and restores armor.
	await _reset()
	_zombie.take_damage(9999, Vector3.RIGHT)
	_main._reset_view()
	await _step(3)
	_check(_main._debris.get_child_count() == 0 and _zombie.health == 1370 and _zombie.get_node("Visuals/Head/Bucket").visible, "An immediate restart left deferred bucket debris or missing armor.")

	# Respawn makes a fresh instance, preserves old debris and follows model inspection.
	await _reset()
	_zombie.set_spawn(_lawn.cell_to_world(0, 8), PI / 2.0)
	_main._toggle_bucket_view()
	_check(_main._inspect_bucket and _main._view_label.text.contains("铁桶"), "The buckethead inspection button did not select its model.")
	_main.auto_respawn_enabled = true
	_respawn_frames.clear()
	_death_frames.clear()
	var old_zombie := _zombie
	old_zombie.take_damage(9999, Vector3.RIGHT)
	var old_corpse := _part(&"corpse")
	var old_bucket := _part(&"bucket")
	_check(absf(_main._bucket_respawn_timer.time_left - 1.0) < 0.001 and _main._bucket_status.text.contains("刷新"), "Buckethead death did not start the independent 1-second timer.")
	await _step(58)
	_check(_respawn_frames.is_empty(), "Buckethead respawned before 1 second.")
	await _step(5)
	_check(_respawn_frames.size() == 1 and not is_instance_valid(old_zombie), "Buckethead respawn did not replace the old instance.")
	_check(is_instance_valid(old_corpse) and is_instance_valid(old_bucket), "Respawn prematurely removed old buckethead remains.")
	_check(_main._orbit.target.distance_to(_zombie.global_position + Vector3(0, 1.0, 0)) < 0.02, "Buckethead inspection did not follow the replacement.")
	_zombie.movement_enabled = true
	var start_x := _zombie.global_position.x
	await _step(60)
	_check(absf(start_x - _zombie.global_position.x - 0.5) < 0.025, "The new buckethead did not walk at 0.5 units per second.")
	_zombie.take_damage(1370, Vector3.RIGHT)
	await _step(30)
	_main._reset_view()
	await _step(90)
	_check(_respawn_frames.size() == 1 and _main._bucket_respawn_timer.is_stopped() and _main._bucket_zombie.health == 1370, "Restart did not cancel a pending buckethead respawn.")
	_main._toggle_bucket_view()
	_check(_main._dave.camera.is_current(), "Returning from buckethead inspection did not restore Dave's camera.")

	# All three enemy types fight their default lanes and independently respawn.
	await _reset()
	_zombie.set_spawn(_lawn.cell_to_world(0, 8), PI / 2.0)
	_main._zombie.movement_enabled = true
	_main._cone_zombie.movement_enabled = true
	_zombie.movement_enabled = true
	_main.auto_respawn_enabled = true
	_respawn_frames.clear()
	_death_frames.clear()
	_parts.clear()
	_cycle_hits = 0
	_other_respawns.assign([0, 0])
	_natural = true
	for plant: Peashooter in [_main._plant, _main._repeater, _main._threepeater, _main._gatling, _main._snowpea]:
		plant.combat_enabled = true
	await _step(5400)
	_check(_respawn_frames.size() >= 2 and _other_respawns[0] >= 6 and _other_respawns[1] >= 3, "Natural three-lane combat did not repeatedly defeat and refresh all three enemy types.")
	_check(_main.get_node("Enemies").get_child_count() == 5 and _main._projectiles.get_child_count() < 25 and _main._debris.get_child_count() < 28, "Long combat accumulated dead enemies, peas or debris.")
	_natural = false
	_main._reset_view()
	await _step(3)
	_check(_main._debris.get_child_count() == 0 and _main._projectiles.get_child_count() == 0 and _main._bucket_respawn_timer.is_stopped(), "Restart failed after prolonged buckethead combat.")
	if not _failed:
		print("PASS: metal buckethead at Gatling baseline, 1370 HP, exact 200/100/0 thresholds, one-time ballistic bucket with real ground tumbling and 10s cleanup, random hand/head/body death and separate lifetimes, fresh 1s respawn, inspection follow and restart, 69 actual Gatling impacts per kill and 90s of independent three-lane combat.")
	quit(1 if _failed else 0)
