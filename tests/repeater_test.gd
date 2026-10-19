extends SceneTree
## Check the placed Repeater and its real two-pea attacks in the physics world.
## godot --headless --path . --fixed-fps 60 --script res://tests/repeater_test.gd

var _failed: bool = false
var _main: Node3D
var _repeater: Repeater
var _zombie: Zombie
var _lawn: LawnGrid
var _shots: Array[float] = []
var _damage: Array[int] = []


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
	_shots.append(float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second)
	_check(pea.damage == 20, "Repeater peas must deal 20 damage each.")
	_check(is_zero_approx(pea.direction.y) and pea.direction.dot(Vector3.RIGHT) > 0.999, "Repeater peas must fly horizontally forward.")
	_check(absf(pea.global_position.z - _repeater.global_position.z) < 0.001, "Repeater fired outside its own lane.")
	_check(pea.get_parent() == _main.get_node("Projectiles"), "Repeater did not use the shared projectile container.")


func _on_damage(amount: int) -> void:
	_damage.append(amount)


func _reset_in_lane() -> void:
	_repeater.combat_enabled = false
	_main._reset_view()
	_zombie.global_position = _lawn.cell_to_world(1, 8)
	_zombie.is_ground_zombie = true
	_zombie.movement_enabled = false
	await _step(3)
	_shots.clear()
	_damage.clear()
	_repeater.combat_enabled = true


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
	_repeater = _main.get_node("Plants/Repeater") as Repeater
	_zombie = _main.get_node("Enemies/Zombie") as Zombie
	_lawn = _main.get_node("LawnGrid") as LawnGrid
	var original := _main.get_node("Plants/Peashooter") as Peashooter
	var dave := _main.get_node("Characters/CrazyDave") as CrazyDave
	original.combat_enabled = false
	_main._threepeater.combat_enabled = false
	_main._gatling.combat_enabled = false
	_main._snowpea.combat_enabled = false
	_main._bucket_zombie.is_ground_zombie = false
	_main._bucket_zombie.movement_enabled = false
	_main._bucket_zombie.set_spawn(_lawn.cell_to_world(0, 8) + Vector3(3, 0, 0), PI / 2.0)
	# Isolate the test target from the new default conehead in this lane.
	_main._cone_zombie.is_ground_zombie = false
	_main._cone_zombie.movement_enabled = false
	_main._cone_zombie.set_spawn(_lawn.cell_to_world(0, 8), PI / 2.0)
	_zombie.movement_enabled = false
	_repeater.shot_fired.connect(_on_shot)
	_zombie.damaged.connect(_on_damage)
	await _step(3)

	# Native entities share the lawn but remain separate plants with distinct looks.
	_check(_lawn.world_to_cell(_repeater.global_position) == Vector2i(1, 1), "Repeater was not placed in row 2, column 2.")
	_check(_lawn.world_to_cell(original.global_position) == Vector2i(1, 2), "Original plant was moved from row 3, column 2.")
	_check((_repeater.global_position - original.global_position).dot(dave.global_basis.x) < -2.39, "Repeater is not to Dave's left of the original plant.")
	_check(_repeater.get_parent() == original.get_parent() and _repeater != original, "The two plants are not independent entities.")
	_check(_lawn.get_node("Tiles").get_child_count() == 45, "Adding a plant changed the lawn layout.")
	_check(_repeater.has_node("Head/Eyes/NearBrow") and _repeater.has_node("Head/Crest/Leaf3"), "Repeater is missing its brows or leaf crest.")
	_check(_repeater.get_node("Head/HeadBody").material_override != original.get_node("Head/HeadBody").material_override, "Repeater changed the original plant's palette.")
	_main._toggle_idle()
	_check(not original.idle_animation_enabled and not _repeater.idle_animation_enabled, "Pause did not stop both plant animations.")
	_main._toggle_idle()
	_check(original.idle_animation_enabled and _repeater.idle_animation_enabled, "Resume did not restore both plant animations.")
	_repeater.idle_animation_enabled = false

	# The existing zombie in the neighboring lane does not trigger the Repeater.
	await _step(120)
	_check(_shots.is_empty(), "Repeater attacked the original plant's neighboring lane.")

	# Same-lane targeting starts 1.5-second attack cycles, each with two peas.
	await _reset_in_lane()
	var begin := float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	await _step(89)
	_check(_shots.is_empty(), "Repeater fired before its first 1.5-second interval.")
	await _step(5)
	_check(_shots.size() == 1, "The attack did not start with one pea.")
	await _step(4)
	_check(_shots.size() == 1, "The second pea fired without its short burst delay.")
	await _step(8)
	_check(_shots.size() == 2, "The attack did not fire a second pea.")
	if not _shots.is_empty():
		_check(absf(_shots[0] - begin - 1.5) < 0.035, "Incorrect first-shot delay.")
	await _step(210)
	_check(_shots.size() >= 6 and _damage.size() >= 4, "Repeated bursts did not create real damaging impacts.")
	for i in range(0, _shots.size() - 1, 2):
		_check(absf(_shots[i + 1] - _shots[i] - 0.18) < 0.025, "Two-pea burst spacing differs from 0.18 seconds.")
		if i + 2 < _shots.size():
			_check(absf(_shots[i + 2] - _shots[i] - 1.5) < 0.025, "Attack cycles differ from 1.5 seconds.")
	for amount in _damage:
		_check(amount == 20, "A Repeater impact did not deal exactly 20 damage.")
	_check(_zombie.health == 200 - 20 * _damage.size(), "Repeater impacts dealt damage more than once.")

	# Losing a valid ground target cancels the second pea and restarts the cadence.
	await _reset_in_lane()
	await _step(94)
	_check(_shots.size() == 1, "Expected a pending second shot for the cancellation check.")
	_zombie.is_ground_zombie = false
	await _step(30)
	_check(_shots.size() == 1, "The pending second pea fired at an invalid ground target.")
	_zombie.is_ground_zombie = true
	await _step(89)
	_check(_shots.size() == 1, "Target reacquisition did not restart the 1.5-second cadence.")
	await _step(18)
	_check(_shots.size() == 3, "Repeater did not resume a complete two-pea burst after reacquisition.")

	# Restart also clears the pending second shot, projectiles, and both cooldowns.
	await _reset_in_lane()
	await _step(94)
	_check(_shots.size() == 1, "Expected a pending second shot for the restart check.")
	_main._reset_view()
	_check(_main.get_node("Projectiles").get_child_count() == 0, "Restart did not clear Repeater projectiles.")
	_check(_repeater._burst_shots_remaining == 0, "Restart left pending burst peas.")
	await _step(30)
	_check(_shots.size() == 1, "A pending burst survived restart.")
	_check(dave.camera.is_current(), "Adding the Repeater changed the waist camera.")
	if not _failed:
		print("PASS: independent Repeater model, left adjacent lawn cell, original plant/lawn preserved, shared idle controls, same-lane ground targeting, two horizontal 20-damage peas every 1.5s with 0.18s spacing, real collisions, target-loss cancellation and restart cleanup.")
	quit(1 if _failed else 0)
