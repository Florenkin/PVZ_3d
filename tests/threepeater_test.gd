extends SceneTree
## Exercise three real lane trajectories, collisions and shared plant controls.

var _failed: bool = false
var _main: Node3D
var _plant: Threepeater
var _lawn: LawnGrid
var _targets: Array[Zombie] = []
var _shots: Array[Dictionary] = []
var _hits: Array[int] = [0, 0, 0]
var _respawns: Array[int] = [0, 0]


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for i in range(frames):
		await physics_frame


func _on_shot(pea: PeaProjectile) -> void:
	_shots.append({"pea": pea, "row": pea._target_row, "frame": Engine.get_physics_frames(), "launch": pea.global_position})
	_check(pea.damage == 20 and pea.speed == 10.0, "Threepeater changed the existing pea damage or speed.")
	_check(is_zero_approx(pea.direction.y) and pea.direction.dot(Vector3.RIGHT) > 0.999, "A Threepeater pea tilted vertically.")
	_check(pea.get_parent() == _main.get_node("Projectiles"), "Threepeater did not use the independent projectile container.")
	_check(absf(_plant._recoil_angle - deg_to_rad(20.0)) < 0.0001, "A three-pea volley should trigger one shared 20-degree kick.")
	var stem := _plant.get_node("Stem") as Node3D
	var head := _plant.get_node("Head") as Node3D
	_check((stem.transform.affine_inverse() * head.transform).is_equal_approx(_plant._stem_rest_transform.affine_inverse() * _plant._head_rest_transform), "Three heads and branching stem did not lean together.")


func _on_damage(amount: int, index: int) -> void:
	_check(amount == 20, "A Threepeater impact did not deal exactly 20 damage.")
	_hits[index] += 1


func _on_respawn(zombie: Zombie) -> void:
	var index := 1 if zombie.has_cone else 0
	_respawns[index] += 1
	_check(zombie.health == (570 if zombie.has_cone else 200), "Combined combat respawned a damaged zombie.")
	_check(zombie.global_position.distance_to(_lawn.cell_to_world(1 if zombie.has_cone else 2, 8)) < 0.001, "Combined combat changed an enemy's baseline lane.")


func _reset() -> void:
	_plant.combat_enabled = false
	_plant.idle_animation_enabled = false
	_main._reset_view()
	_plant.global_position = _lawn.cell_to_world(3, 1)
	for index in range(3):
		_targets[index].reset_combat()
		_targets[index].is_ground_zombie = true
		_targets[index].movement_enabled = false
		# Keep unused live colliders outside all three firing lanes.
		_targets[index].set_spawn(_lawn.cell_to_world(0, 4 + index), PI / 2.0)
	await _step(3)
	_shots.clear()
	_hits.assign([0, 0, 0])


func _activate(index: int, row: int, column: int = 8) -> void:
	_targets[index].set_spawn(_lawn.cell_to_world(row, column), PI / 2.0)
	await _step(3)


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
	_plant = _main._threepeater
	_lawn = _main._lawn
	_main._plant.combat_enabled = false
	_main._repeater.combat_enabled = false
	_main._gatling.combat_enabled = false
	_main._snowpea.combat_enabled = false
	_main._bucket_zombie.is_ground_zombie = false
	_main._bucket_zombie.movement_enabled = false
	_main._bucket_zombie.set_spawn(_lawn.cell_to_world(0, 8) + Vector3(3, 0, 0), PI / 2.0)
	_main._zombie.is_ground_zombie = false
	_main._zombie.movement_enabled = false
	_main._zombie.set_spawn(_lawn.cell_to_world(0, 8), PI / 2.0)
	_main._cone_zombie.is_ground_zombie = false
	_main._cone_zombie.movement_enabled = false
	for index in range(3):
		var zombie := load("res://scenes/enemies/zombie.tscn").instantiate() as Zombie
		GameConfiguration.current().apply_entity(zombie)
		zombie.name = "LaneTarget%d" % index
		_main.get_node("Enemies").add_child(zombie)
		zombie.configure_debris(_main._debris)
		zombie.damaged.connect(_on_damage.bind(index))
		_targets.append(zombie)
	_plant.shot_fired.connect(_on_shot)
	await _reset()

	_check(_lawn.world_to_cell(_plant.global_position) == Vector2i(1, 3), "Threepeater is not in row 4, column 2.")
	_check((_plant.global_position - _main._plant.global_position).dot(_main._dave.global_basis.x) > 2.39, "Threepeater is not to Dave's right of Peashooter.")
	_check(_main.get_node("Plants").get_child_count() == 6 and _lawn.get_node("Tiles").get_child_count() == 45, "The plant entities or lawn layout changed unexpectedly.")
	_check(_plant.has_node("Head/LeftHead/Eyes") and _plant.has_node("Head/RightHead/Eyes") and _plant.has_node("Stem/LeftBranch") and _plant.has_node("Stem/RightBranch"), "Threepeater lacks three complete heads or its branching stem.")
	_main._plant.idle_animation_enabled = true
	_main._toggle_idle()
	_check(not _plant.idle_animation_enabled and not _main._repeater.idle_animation_enabled, "Pause did not include the new plant.")
	_main._toggle_idle()
	_check(_plant.idle_animation_enabled and _main._repeater.idle_animation_enabled, "Resume did not include the new plant.")
	_plant.idle_animation_enabled = false
	_check(_main._dave.camera.is_current(), "Adding Threepeater changed Dave's waist camera.")

	# Uncovered lanes, airborne targets, targets behind the plant and dead targets.
	_plant.combat_enabled = true
	await _step(110)
	_check(_shots.is_empty(), "Uncovered lanes triggered a Threepeater volley.")
	await _reset()
	await _activate(0, 2)
	_targets[0].is_ground_zombie = false
	_plant.combat_enabled = true
	await _step(110)
	_check(_shots.is_empty(), "An airborne-type zombie triggered a Threepeater volley.")
	await _reset()
	await _activate(0, 3, 0)
	_plant.combat_enabled = true
	await _step(110)
	_check(_shots.is_empty(), "A zombie behind Threepeater triggered a volley.")
	await _reset()
	await _activate(0, 4)
	_targets[0].global_position.y += 2.0
	_targets[0].velocity = Vector3.ZERO
	_targets[0].move_and_slide()
	_targets[0].set_physics_process(false)
	await _step(3)
	_plant.combat_enabled = true
	await _step(110)
	_check(_shots.is_empty(), "A zombie off the ground triggered a volley.")
	_targets[0].set_physics_process(true)
	await _reset()
	await _activate(0, 4)
	_targets[0].damaged.disconnect(_on_damage.bind(0))
	_targets[0].take_damage(200, Vector3.RIGHT)
	_targets[0].damaged.connect(_on_damage.bind(0))
	_plant.combat_enabled = true
	await _step(110)
	_check(_shots.is_empty(), "A dead zombie triggered a Threepeater volley.")

	# A target in ANY of the three lanes starts complete, simultaneous volleys.
	for row in range(2, 5):
		await _reset()
		await _activate(0, row)
		var launch_positions: Array[Vector3] = [_plant._left_muzzle.global_position, _plant._muzzle_tip.global_position, _plant._right_muzzle.global_position]
		_plant.combat_enabled = true
		await _step(89)
		_check(_shots.is_empty(), "Threepeater fired before 1.5 seconds.")
		await _step(5)
		_check(_shots.size() == 3, "A single covered target did not trigger all three peas.")
		if _shots.size() == 3:
			for index in range(3):
				_check(_shots[index]["row"] == index + 2, "A volley did not cover rows 3, 4 and 5.")
				_check(_shots[index]["frame"] == _shots[0]["frame"], "The three peas were not fired simultaneously.")
				_check(_shots[index]["launch"].distance_to(launch_positions[index]) < 0.0001, "A pea teleported to its lane instead of starting at its own muzzle.")
		await _step(100)
		_check(_shots.size() == 6 and _hits[0] == 1, "Threepeater cadence or a real neighboring-lane impact failed.")
		if _shots.size() == 6:
			_check(absf(float(_shots[3]["frame"] - _shots[0]["frame"]) / Engine.physics_ticks_per_second - 1.5) < 0.025, "Threepeater volleys do not repeat every 1.5 seconds.")

	# Three different live colliders each take one hit, including both side lanes.
	await _reset()
	for index in range(3):
		await _activate(index, index + 2)
	_plant.combat_enabled = true
	await _step(94)
	_plant.combat_enabled = false
	await _step(25)
	for shot: Dictionary in _shots:
		var pea: PeaProjectile = shot["pea"]
		_check(is_instance_valid(pea), "A pea disappeared before reaching the targets.")
		if is_instance_valid(pea):
			_check(absf(pea.global_position.y - shot["launch"].y) < 0.0001, "A spreading pea changed flight height.")
			_check(absf(pea.global_position.z - _lawn.cell_to_world(shot["row"], 1).z) < 0.0001, "A side pea failed to settle onto its neighboring path.")
	await _step(95)
	_check(_hits == [1, 1, 1], "One volley did not hit all three targets exactly once.")
	for zombie: Zombie in _targets:
		_check(zombie.health == 180, "Lane targeting dealt duplicate or missing damage.")
	_check(_main._projectiles.get_child_count() == 0, "Impacted peas did not disappear.")

	# A wrong-lane collider at a side muzzle cannot steal its neighbor's pea.
	await _reset()
	await _activate(0, 2)
	_targets[1].set_spawn(Vector3(_plant._left_muzzle.global_position.x + 0.1, LawnGrid.SURFACE_HEIGHT, _plant._left_muzzle.global_position.z), PI / 2.0)
	await _step(3)
	_plant._fire()
	await _step(120)
	_check(_hits[0] == 1 and _hits[1] == 0, "The spreading side pea damaged a collider in the wrong lane.")

	# Boundary rows omit only the nonexistent off-board lane.
	for row in [0, 4]:
		await _reset()
		_plant.global_position = _lawn.cell_to_world(row, 1)
		await _activate(0, row)
		_plant._fire()
		_check(_shots.size() == 2, "An edge-row Threepeater fired outside the five-row lawn.")
		for shot: Dictionary in _shots:
			_check(shot["row"] >= 0 and shot["row"] < 5, "A pea targeted a nonexistent lawn lane.")

	# Losing targets stops volleys and lets the full plant recover; R resets all.
	await _reset()
	await _activate(0, 3)
	_plant.combat_enabled = true
	await _step(94)
	_targets[0].is_ground_zombie = false
	await _step(110)
	_check(_shots.size() == 3 and is_zero_approx(_plant._recoil_angle), "Target loss did not stop volleys or finish recoil recovery.")
	_targets[0].is_ground_zombie = true
	await _step(89)
	_check(_shots.size() == 3, "Target reacquisition did not restart the full firing delay.")
	await _step(5)
	_check(_shots.size() == 6, "Threepeater did not resume after a target returned.")
	_main._reset_view()
	_check(_main._projectiles.get_child_count() == 0 and is_zero_approx(_plant._recoil_angle) and _plant._shot_countdown == _plant.shot_interval, "Restart left peas, recoil or a partial cooldown.")
	_check(_plant.get_node("Stem").transform.is_equal_approx(_plant._stem_rest_transform) and _plant.get_node("Head").transform.is_equal_approx(_plant._head_rest_transform), "Restart left the three heads or branching stem displaced.")

	# The default three-plant garden runs repeated fights without accumulating entities.
	_plant.combat_enabled = false
	for zombie: Zombie in _targets:
		_main.get_node("Enemies").remove_child(zombie)
		zombie.queue_free()
	_main._zombie.is_ground_zombie = true
	_main._zombie.movement_enabled = true
	_main._zombie.set_spawn(_lawn.cell_to_world(2, 8), PI / 2.0)
	_main._cone_zombie.is_ground_zombie = true
	_main._cone_zombie.movement_enabled = true
	_main._reset_view()
	_main.auto_respawn_enabled = true
	_main.zombie_respawned.connect(_on_respawn)
	_main._plant.combat_enabled = true
	_main._repeater.combat_enabled = true
	_plant.combat_enabled = true
	await _step(3600)
	_check(_respawns[0] >= 4 and _respawns[1] >= 2, "The three-plant garden failed to repeatedly defeat and refresh both enemy types.")
	_check(_main.get_node("Enemies").get_child_count() == 5, "Combined combat accumulated dead standing enemies.")
	_check(_main._projectiles.get_child_count() < 18 and _main._debris.get_child_count() < 24, "Combined combat accumulated expired projectiles or debris.")
	_main._reset_view()
	_check(_main._projectiles.get_child_count() == 0 and _main._debris.get_child_count() == 0, "Restart failed after prolonged three-plant combat.")
	if not _failed:
		print("PASS: right-adjacent independent three-headed model, three-lane ground targeting, simultaneous 1.5s volleys, real muzzle launches, level spreading trajectories and 20-damage collisions in all three lanes, wrong-lane filtering, boundary rows, shared recoil/idle controls, target-loss recovery, restart cleanup and 60s of combined three-plant combat with repeated respawns.")
	quit(1 if _failed else 0)
