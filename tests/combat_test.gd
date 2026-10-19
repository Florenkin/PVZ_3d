extends SceneTree
## Integration checks against the real Godot physics world.
## godot --headless --path . --fixed-fps 60 --script res://tests/combat_test.gd

var _failed: bool = false
var _main: Node3D
var _plant: Peashooter
var _zombie: Zombie
var _lawn: LawnGrid
var _projectiles: Node3D
var _shots: Array[float] = []
var _damage_events: Array[int] = []
var _health_events: Array[int] = []


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
	_check(pea.damage == 20, "Pea damage must be 20.")
	_check(is_zero_approx(pea.direction.y), "Peas must launch horizontally.")
	_check(pea.direction.dot(Vector3.RIGHT) > 0.999, "Peas must travel forward along the lane.")


func _on_damage(amount: int) -> void:
	_damage_events.append(amount)
	_health_events.append(_zombie.health)


func _reset() -> void:
	_plant.combat_enabled = false
	_zombie.movement_enabled = false
	_zombie.is_ground_zombie = true
	_main._reset_view()
	await _step(3)
	_shots.clear()
	_damage_events.clear()
	_health_events.clear()


func _all_white(model: Node) -> bool:
	var visuals: Node = model.get_node("Visuals") if model is Zombie else model
	for mesh: MeshInstance3D in visuals.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override != Zombie.HIT_MATERIAL:
			return false
	return true


func _spawn_pea(position: Vector3, speed: float = 10.0) -> PeaProjectile:
	var pea := load("res://scenes/projectiles/pea.tscn").instantiate() as PeaProjectile
	GameConfiguration.current().apply_entity(pea)
	pea.direction = Vector3.RIGHT
	pea.speed = speed
	_projectiles.add_child(pea)
	pea.global_position = position
	return pea


func _run() -> void:
	# This suite verifies the retained physical-parts mode; the imported model's
	# default lifecycle is exercised separately by animated_zombie_test.gd.
	var legacy_values := GameConfiguration.current().default_values()
	legacy_values.demo_zombie_animation.enabled = false
	GameConfiguration.current().use_values_for_tests(legacy_values)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	GameConfiguration.current().apply_entity(_main)
	# Keep individual combat cases isolated from the main scene's respawn loop.
	_main.auto_respawn_enabled = false
	root.add_child(_main)
	# Isolate these existing cases from the new fifth-lane enemy.
	_main._newspaper_zombie.movement_enabled = false
	_main._newspaper_zombie.is_ground_zombie = false
	_main._newspaper_zombie.set_spawn(_main._lawn.cell_to_world(3, 8) + Vector3(40, 0, 0), PI / 2.0)
	_main._pole_zombie.movement_enabled = false
	_main._pole_zombie.is_ground_zombie = false
	_main._pole_zombie.set_spawn(_main._lawn.cell_to_world(4, 8) + Vector3(3, 0, 0), PI / 2.0)
	_plant = _main.get_node("Plants/Peashooter") as Peashooter
	_zombie = _main.get_node("Enemies/Zombie") as Zombie
	_lawn = _main.get_node("LawnGrid") as LawnGrid
	_projectiles = _main.get_node("Projectiles") as Node3D
	_main._repeater.combat_enabled = false
	_main._threepeater.combat_enabled = false
	_main._gatling.combat_enabled = false
	_main._snowpea.combat_enabled = false
	_main._bucket_zombie.is_ground_zombie = false
	_main._bucket_zombie.movement_enabled = false
	_main._bucket_zombie.set_spawn(_lawn.cell_to_world(0, 8) + Vector3(3, 0, 0), PI / 2.0)
	_main._cone_zombie.movement_enabled = false
	_plant.shot_fired.connect(_on_shot)
	_zombie.damaged.connect(_on_damage)
	await _reset()

	# No ground target in the firing lane: no shots, including the first one.
	_zombie.global_position = _lawn.cell_to_world(1, 8)
	_plant.combat_enabled = true
	await _step(120)
	_check(_shots.is_empty(), "A zombie in another lane triggered shooting.")
	await _reset()
	_zombie.is_ground_zombie = false
	_plant.combat_enabled = true
	await _step(120)
	_check(_shots.is_empty(), "An airborne-type zombie triggered shooting.")
	await _reset()
	_zombie.global_position = _lawn.cell_to_world(2, 0)
	_plant.combat_enabled = true
	await _step(120)
	_check(_shots.is_empty(), "A zombie behind the muzzle triggered shooting.")
	await _reset()
	_zombie.take_damage(200, Vector3.RIGHT)
	_plant.combat_enabled = true
	await _step(120)
	_check(_shots.is_empty() and not _zombie.visible, "A defeated zombie kept triggering shots or remained visible.")

	# Fire exactly every 1.5 seconds and keep each projectile's Y constant.
	await _reset()
	var begin := float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	_plant.combat_enabled = true
	await _step(89)
	_check(_shots.is_empty(), "The first shot fired before 1.5 seconds.")
	await _step(5)
	_check(_shots.size() == 1, "The first shot did not fire at 1.5 seconds.")
	if not _shots.is_empty():
		_check(absf(_shots[0] - begin - 1.5) <= 0.035, "Incorrect first-shot delay.")
	var pea := _projectiles.get_child(0) as PeaProjectile
	var launch_y := pea.global_position.y
	var start_x := pea.global_position.x
	await _step(8)
	_check(is_instance_valid(pea) and is_equal_approx(pea.global_position.y, launch_y), "Pea height changed during flight.")
	_check(pea.global_position.x > start_x, "The pea did not travel toward the zombie.")
	await _step(300)
	_check(_shots.size() >= 4, "Expected repeated automatic fire.")
	for i in range(1, _shots.size()):
		_check(absf(_shots[i] - _shots[i - 1] - 1.5) <= 0.02, "Shot cadence differs from 1.5 seconds.")
	for amount in _damage_events:
		_check(amount == 20, "A pea dealt damage more than once or used the wrong damage value.")
	for i in range(_health_events.size()):
		_check(_health_events[i] == 200 - 20 * (i + 1), "Damage events did not subtract exactly 20 HP per hit.")

	# Only the first physical zombie on the projectile's path is hit.
	await _reset()
	var near := load("res://scenes/enemies/zombie.tscn").instantiate() as Zombie
	GameConfiguration.current().apply_entity(near)
	near.position = _lawn.cell_to_world(2, 5)
	near.rotation.y = PI / 2.0
	near.movement_enabled = false
	_main.get_node("Enemies").add_child(near)
	await _step(3)
	_plant.combat_enabled = true
	await _step(165)
	_check(near.health == 180 and _zombie.health == 200, "The pea hit more than the first zombie on its path.")
	_check(_projectiles.get_child_count() == 0, "A pea survived contact with a zombie.")
	near.queue_free()
	await _step(2)

	# Fast center crossings and grazing volume contacts both cause one hit.
	await _reset()
	pea = _spawn_pea(_zombie.global_position + Vector3(-1.0, 1.2, 0), 2000.0)
	await _step(4)
	_check(_zombie.health == 180 and not is_instance_valid(pea), "Fast pea tunneled through the zombie or damaged it twice.")
	await _reset()
	pea = _spawn_pea(_zombie.global_position + Vector3(-1.0, 1.2, 0.35))
	await _step(15)
	_check(_zombie.health == 180 and not is_instance_valid(pea), "A grazing pea contact did not damage and disappear.")

	# Every body part flashes for 0.5 seconds; per-instance palettes survive.
	await _reset()
	var other := load("res://scenes/enemies/zombie.tscn").instantiate() as Zombie
	GameConfiguration.current().apply_entity(other)
	other.position = _lawn.cell_to_world(0, 8)
	other.movement_enabled = false
	_main.get_node("Enemies").add_child(other)
	await _step(3)
	var originals: Dictionary = {}
	for mesh: MeshInstance3D in _zombie.get_node("Visuals").find_children("*", "MeshInstance3D", true, false):
		originals[mesh] = mesh.material_override
	var before_hit := _zombie.global_position
	_zombie.take_damage(20, Vector3.RIGHT)
	_check(_all_white(_zombie), "Not all zombie parts flashed white.")
	_check(not _all_white(other), "Hit flash leaked to a different zombie instance.")
	_check(absf(_zombie.get_node("Visuals").rotation.x) <= deg_to_rad(30.0) + 0.00001, "Hit tilt exceeded 30 degrees.")
	await _step(6)
	_check(_zombie.global_position.x > before_hit.x + 0.04, "The hit did not push the zombie backward.")
	await _step(21)
	_check(_all_white(_zombie), "White flash ended before 0.5 seconds.")
	await _step(7)
	for mesh: MeshInstance3D in originals:
		_check(mesh.material_override == originals[mesh], "Hit flash did not restore a body material.")
	_check(is_zero_approx(_zombie.get_node("Visuals").rotation.x), "Zombie did not recover from recoil.")
	for i in range(3):
		_zombie.take_damage(20, Vector3.RIGHT)
	_check(absf(_zombie.get_node("Visuals").rotation.x) <= deg_to_rad(30.0) + 0.00001, "Repeated hits accumulated tilt beyond 30 degrees.")
	other.queue_free()
	await _step(2)

	# The killing pea also produces the complete visible hit response.
	await _reset()
	_zombie.take_damage(180, Vector3.RIGHT)
	await _step(40)
	before_hit = _zombie.global_position
	_zombie.take_damage(20, Vector3.RIGHT)
	var corpse: ZombieDebris = _zombie._spawned_debris[-1]
	_check(_zombie.health == 0 and not _zombie.visible and corpse.part_kind == &"corpse", "The final hit did not replace the standing model with a corpse.")
	_check(absf(corpse.linear_velocity.dot(Vector3.RIGHT)) > 0.5, "The final hit did not initiate the random forward/backward fall.")
	await _step(2)
	_check(corpse.visible and _all_white(corpse), "The physical corpse did not preserve the final white flash.")
	await _step(6)
	_check(corpse.global_position.distance_to(before_hit) > 0.1, "The physical corpse did not move after the killing hit.")
	await _step(30)
	_check(corpse.visible and not _all_white(corpse), "The corpse did not remain visible with restored materials after its flash.")
	await _step(270)
	_check(not is_instance_valid(corpse), "The corpse did not disappear after 5 seconds.")

	# Default slow walk and complete ten-hit fight, death and restart.
	await _reset()
	_zombie.movement_enabled = true
	var walk_start := _zombie.global_position
	await _step(60)
	_check(absf(walk_start.x - _zombie.global_position.x - 0.5) < 0.025, "Zombie walking speed is not 0.5 units/second.")
	_check(absf(_zombie.global_position.z - walk_start.z) < 0.001, "Zombie left its lane while walking.")
	await _reset()
	_zombie.movement_enabled = true
	_plant.combat_enabled = true
	await _step(1200)
	_check(_zombie.health == 0 and not _zombie.visible, "The zombie was not defeated after ten 20-damage hits.")
	_check(_damage_events.size() == 10, "The full fight did not produce exactly ten damaging impacts.")
	for i in range(1, _shots.size()):
		_check(absf(_shots[i] - _shots[i - 1] - 1.5) <= 0.02, "Walking across tile seams interrupted the firing cadence.")
	var shots_after_death := _shots.size()
	await _step(180)
	_check(_shots.size() == shots_after_death, "The plant kept shooting after all valid zombies died.")
	_check(_projectiles.get_child_count() == 0, "Projectiles were left behind after combat.")
	_main._reset_view()
	await _step(3)
	_check(_zombie.health == 200 and _zombie.visible, "Restart did not restore the zombie and its health.")
	_check(_projectiles.get_child_count() == 0, "Restart did not clear projectiles.")
	_check(_main.get_node("Characters/CrazyDave").camera.is_current(), "Combat replaced Dave's waist camera.")
	if not _failed:
		print("PASS: lane/ground/alive filtering, 1.5s cadence, horizontal peas, single 20-damage collision, fast/grazing hits, 0.5s full-body white flash, instance isolation, backward knockback <=30deg, slow walking, ten-hit defeat, cleanup and restart.")
	quit(1 if _failed else 0)
