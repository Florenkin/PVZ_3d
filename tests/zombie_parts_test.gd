extends SceneTree
## Real rigid-body flight, ground contact, fall direction, cleanup and two-lane combat.
## godot --headless --path . --fixed-fps 60 --script res://tests/zombie_parts_test.gd

var _failed: bool = false
var _main: Node3D
var _lawn: LawnGrid
var _normal: Zombie
var _cone: Zombie
var _parts: Array[ZombieDebris] = []
var _normal_respawns: int = 0
var _cone_respawns: int = 0
var _normal_hits: int = 0
var _cone_hits: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for i in range(frames):
		await physics_frame


func _on_part(part: ZombieDebris) -> void:
	_parts.append(part)
	_check(part is RigidBody3D and not part.freeze and part.gravity_scale == 1.0, "Detached parts must use live rigid-body physics and gravity.")
	_check(part.collision_layer == 16 and part.collision_mask == 17, "Debris collision layers include living zombies or peas.")
	_check(part.has_node("CollisionShape3D"), "A physical part has no collision shape.")
	_check(part.lifetime == (5.0 if part.part_kind == &"corpse" else 10.0), "Incorrect body/part lifetime.")


func _part(kind: StringName, owner_id: int = 0) -> ZombieDebris:
	for body: ZombieDebris in _parts:
		if is_instance_valid(body) and body.part_kind == kind and (owner_id == 0 or body.owner_zombie_id == owner_id):
			return body
	return null


func _count(kind: StringName) -> int:
	var total := 0
	for body: ZombieDebris in _parts:
		if is_instance_valid(body) and body.part_kind == kind:
			total += 1
	return total


func _reset() -> void:
	_main.auto_respawn_enabled = false
	_main._plant.combat_enabled = false
	_main._repeater.combat_enabled = false
	_main._threepeater.combat_enabled = false
	_main._gatling.combat_enabled = false
	_main._snowpea.combat_enabled = false
	_main._bucket_zombie.is_ground_zombie = false
	_main._bucket_zombie.movement_enabled = false
	_main._bucket_zombie.set_spawn(_lawn.cell_to_world(0, 8) + Vector3(3, 0, 0), PI / 2.0)
	_main._reset_view()
	_normal = _main._zombie
	_cone = _main._cone_zombie
	_normal.movement_enabled = false
	_cone.movement_enabled = false
	_normal.set_spawn(_lawn.cell_to_world(2, 5), PI / 2.0)
	_cone.set_spawn(_lawn.cell_to_world(1, 5), PI / 2.0)
	await _step(3)
	_parts.clear()


func _on_normal_hit(_amount: int) -> void:
	_normal_hits += 1


func _on_cone_hit(_amount: int) -> void:
	_cone_hits += 1


func _on_respawn(zombie: Zombie) -> void:
	zombie.part_detached.connect(_on_part)
	if zombie.has_cone:
		_cone_respawns += 1
		_check(_cone_hits == 29, "The 570-HP conehead was not defeated in exactly 29 pea impacts.")
		_cone_hits = 0
		zombie.damaged.connect(_on_cone_hit)
		_check(zombie.health == 570 and zombie.get_node("Visuals/Head/Cone").visible, "Replacement conehead did not restore 570 HP and the cone.")
		_check(zombie.global_position.distance_to(_lawn.cell_to_world(1, 8)) < 0.001, "Conehead respawned outside the Repeater's baseline.")
	else:
		_normal_respawns += 1
		_check(_normal_hits == 10, "The normal zombie was not defeated in exactly 10 pea impacts.")
		_normal_hits = 0
		zombie.damaged.connect(_on_normal_hit)
		_check(zombie.health == 200, "Replacement normal zombie did not restore 200 HP.")
		_check(zombie.global_position.distance_to(_lawn.cell_to_world(2, 8)) < 0.001, "Normal zombie respawned outside its baseline.")
	_check(zombie.get_node("Visuals/Head").visible, "Replacement inherited a missing head.")
	_check(zombie.get_node("Visuals/Arms/LeftHandAssembly").visible and zombie.get_node("Visuals/Arms/RightHandAssembly").visible, "Replacement inherited a missing hand.")
	_check(_main.get_node("Enemies").get_child_count() == 4, "Independent lane respawns created duplicate enemies.")


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	GameConfiguration.current().apply_entity(_main)
	_main.auto_respawn_enabled = false
	root.add_child(_main)
	_main._pole_zombie.movement_enabled = false
	_main._pole_zombie.is_ground_zombie = false
	_main._pole_zombie.set_spawn(_main._lawn.cell_to_world(4, 8) + Vector3(3, 0, 0), PI / 2.0)
	_lawn = _main.get_node("LawnGrid") as LawnGrid
	_normal = _main._zombie
	_cone = _main._cone_zombie
	_normal.part_detached.connect(_on_part)
	_cone.part_detached.connect(_on_part)
	_check(_cone.maximum_health == 570 and _cone.health == 570 and _cone.has_cone, "The default conehead does not have 570 HP and a cone.")
	_check(_lawn.world_to_cell(_cone.global_position) == Vector2i(8, 1), "Conehead is not at row 2, column 9.")
	await _reset()

	# Exactly 200 HP triggers a single cone detachment, including overlapping flashes.
	_cone.take_damage(369, Vector3.RIGHT)
	await _step(3)
	_check(_cone.health == 201 and _parts.is_empty() and _cone.get_node("Visuals/Head/Cone").visible, "Cone detached above 200 HP.")
	_cone.take_damage(1, Vector3.RIGHT)
	var hat := _part(&"cone")
	_check(hat != null and not _cone.get_node("Visuals/Head/Cone").visible, "Cone did not detach at exactly 200 HP.")
	_cone.take_damage(1, Vector3.RIGHT)
	_check(_count(&"cone") == 1, "Repeated low-health hits detached the cone twice.")
	await _step(3)
	var start := hat.global_position
	var launch_velocity := hat.linear_velocity
	await _step(12)
	_check(hat.global_position.y > start.y + 0.3 and hat.global_position.x > start.x + 0.2, "The cone did not launch upward and outward.")
	_check(hat.linear_velocity.y < launch_velocity.y, "Gravity did not bend the cone's flight downward.")
	var expected_y := start.y + launch_velocity.y * 0.2 - 0.5 * 9.8 * 0.2 * 0.2
	_check(absf(hat.global_position.y - expected_y) < 0.08, "The airborne cone did not follow a ballistic arc.")
	var flight_basis := hat.global_basis
	var ground_rotation := 0.0
	var previous_rotation := hat.global_basis.get_rotation_quaternion()
	for i in range(130):
		await _step(1)
		var current_rotation := hat.global_basis.get_rotation_quaternion()
		if hat.has_landed:
			ground_rotation += previous_rotation.angle_to(current_rotation)
		previous_rotation = current_rotation
	_check(hat.has_landed and hat.global_position.y >= 0.05 and hat.global_position.y < 0.85, "The cone did not collide with and land on the lawn.")
	_check(flight_basis.get_rotation_quaternion().angle_to(hat.global_basis.get_rotation_quaternion()) > 0.2, "The physical cone did not tumble.")
	_check(ground_rotation > 0.2, "The cone did not roll/tumble after ground contact.")
	_check(hat.linear_velocity.length() < 0.7, "Ground friction did not reduce the cone's motion.")
	while is_instance_valid(hat) and hat.age < 9.5:
		await _step(1)
	_check(is_instance_valid(hat), "The cone disappeared before 10 seconds.")
	await _step(40)
	_check(not is_instance_valid(hat), "The cone remained after 10 seconds.")

	# Exactly 100 HP detaches one randomly selected hand/forearm, never both.
	await _reset()
	_normal.take_damage(99, Vector3.RIGHT)
	await _step(3)
	_check(_normal.health == 101 and _parts.is_empty(), "A hand detached above 100 HP.")
	_normal.take_damage(1, Vector3.RIGHT)
	var hand := _part(&"left_hand")
	if hand == null:
		hand = _part(&"right_hand")
	_check(hand != null and _parts.size() == 1, "Exactly one hand did not detach at 100 HP.")
	var left_visible: bool = _normal.get_node("Visuals/Arms/LeftHandAssembly").visible
	var right_visible: bool = _normal.get_node("Visuals/Arms/RightHandAssembly").visible
	_check(left_visible != right_visible, "A low-health zombie must retain the other hand.")
	_normal.take_damage(1, Vector3.RIGHT)
	await _step(45)
	_check(_parts.size() == 1 and hand.has_landed, "Hand detachment repeated or did not produce ground contact.")
	for mesh: MeshInstance3D in hand.find_children("*", "MeshInstance3D", true, false):
		_check(mesh.material_override != Zombie.HIT_MATERIAL, "The detached hand kept an old white-flash material.")
	while is_instance_valid(hand) and hand.age < 9.5:
		await _step(1)
	_check(is_instance_valid(hand), "The detached hand disappeared before 10 seconds.")
	await _step(40)
	_check(not is_instance_valid(hand), "The detached hand remained after 10 seconds.")

	# A large lethal hit crosses every threshold once; body and head have independent TTLs.
	await _reset()
	_cone.take_damage(1000, Vector3.RIGHT)
	_check(_cone.health == 0 and not _cone.is_alive(), "Lethal damage did not clamp health to zero.")
	_check(_parts.size() == 4 and _count(&"cone") == 1 and _count(&"head") == 1 and _count(&"corpse") == 1, "A lethal conehead hit did not detach exactly cone, one hand, head and body.")
	var head := _part(&"head")
	var corpse := _part(&"corpse")
	_check(head.linear_velocity.y > 3.0 and head.linear_velocity.x > 1.8, "The severed head did not launch on an arc.")
	_check(not corpse.get_node("Model/Head").visible, "The corpse kept a duplicate attached head.")
	_cone.take_damage(1, Vector3.RIGHT)
	_check(_parts.size() == 4, "A dead zombie generated repeated body parts.")
	await _step(180)
	_check(corpse.has_node("ElbowJoint") and is_instance_valid(corpse.attached_part), "The remaining forearm was not physically joined to the corpse.")
	_check(corpse.has_landed and head.has_landed, "Head or body did not collide with the ground.")
	_check(absf(corpse.global_basis.y.dot(Vector3.UP)) < 0.45, "The corpse did not fall onto the lawn.")
	while is_instance_valid(corpse) and corpse.age < 4.8:
		await _step(1)
	_check(is_instance_valid(corpse) and is_instance_valid(head), "The body or head disappeared too early.")
	await _step(20)
	_check(not is_instance_valid(corpse) and is_instance_valid(head), "Body did not disappear at 5 seconds independently of the head.")
	while is_instance_valid(head) and head.age < 9.5:
		await _step(1)
	_check(is_instance_valid(head), "The head disappeared before 10 seconds.")
	await _step(40)
	_check(not is_instance_valid(head) and _main.get_node("Debris").get_child_count() == 0, "Physical parts did not disappear after 10 seconds.")

	# Fixed seeds exercise both hand choices and both actual forward/backward falls.
	var hands: Dictionary = {}
	var falls: Dictionary = {}
	var landed_directions: Dictionary = {}
	for i in range(12):
		await _reset()
		_normal._rng.seed = 9037 * i + 31
		_normal.take_damage(200, Vector3.RIGHT)
		for body: ZombieDebris in _parts:
			if body.part_kind == &"left_hand" or body.part_kind == &"right_hand":
				hands[body.part_kind] = true
		corpse = _part(&"corpse")
		falls[corpse.get_meta("fall_direction")] = true
		await _step(150)
		if absf(corpse.global_basis.y.dot(Vector3.UP)) < 0.45:
			landed_directions[signf(corpse.global_basis.y.dot(Vector3.RIGHT))] = true
	_check(hands.size() == 2 and falls.size() == 2, "Random selection did not exercise both hands and both fall directions.")
	_check(landed_directions.has(-1.0) and landed_directions.has(1.0), "Rigid corpses did not physically fall both forward and backward.")

	# Restart before deferred attachment must not leak invisible/off-tree bodies.
	await _reset()
	_normal.take_damage(200, Vector3.RIGHT)
	_main._reset_view()
	await _step(3)
	_check(_main.get_node("Debris").get_child_count() == 0, "A deferred body survived an immediate restart.")
	_check(_normal.get_node("Visuals/Head").visible and _normal.get_node("Visuals/Arms/LeftHandAssembly").visible and _normal.get_node("Visuals/Arms/RightHandAssembly").visible, "Restart did not restore the original zombie's missing parts.")

	# Both lanes run natural projectile fights and independently respawn their enemy type.
	_main._reset_view()
	_normal.set_spawn(_lawn.cell_to_world(2, 8), PI / 2.0)
	_cone.set_spawn(_lawn.cell_to_world(1, 8), PI / 2.0)
	_normal.movement_enabled = true
	_cone.movement_enabled = true
	_normal.damaged.connect(_on_normal_hit)
	_cone.damaged.connect(_on_cone_hit)
	_main.zombie_respawned.connect(_on_respawn)
	_main.auto_respawn_enabled = true
	_main._plant.combat_enabled = true
	_main._repeater.combat_enabled = true
	await _step(3600)
	_check(_normal_respawns >= 3 and _cone_respawns >= 2, "Natural combat did not repeatedly defeat and respawn both enemy types.")
	_check(_main.get_node("Enemies").get_child_count() == 4, "Long combat accumulated dead standing enemies.")
	_check(_main.get_node("Debris").get_child_count() < 15, "Long combat accumulated expired physical debris.")
	_main._reset_view()
	await _step(3)
	_check(_main.get_node("Debris").get_child_count() == 0, "Restart did not clear all remaining physical parts.")
	_check(_main._respawn_timer.is_stopped() and _main._cone_respawn_timer.is_stopped(), "Restart left one of the two lane timers active.")
	if not _failed:
		print("PASS: 570-HP conehead in Repeater lane, exact 200/100/0 thresholds, one-time/random detachment, rigid-body ballistic flight, ground contact/tumbling/friction, both physical death directions, 5s body / 10s parts cleanup, restored palettes/parts, immediate restart and 60s of real two-lane combat with independent respawns.")
	quit(1 if _failed else 0)
