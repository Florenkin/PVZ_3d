extends SceneTree
## Four real muzzle launches, burst timing, impacts, cancellation and garden combat.

var _failed: bool = false
var _main: Node3D
var _plant: GatlingPea
var _target: Zombie
var _lawn: LawnGrid
var _shots: Array[Dictionary] = []
var _damage: Array[int] = []
var _long_hits: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for index in range(frames):
		await physics_frame


func _on_shot(pea: PeaProjectile) -> void:
	_shots.append({"frame": Engine.get_physics_frames(), "pea": pea, "launch": pea.global_position, "barrel": (_plant._barrel_index + 3) % 4, "angle": _plant._recoil_angle})
	_check(pea.damage == 20 and pea.speed == 10.0, "Gatling peas changed the existing projectile stats.")
	_check(is_zero_approx(pea.direction.y) and pea.direction.dot(Vector3.RIGHT) > 0.999, "Gatling recoil tilted a pea's flight direction.")
	_check(absf(pea.global_position.z - _plant.global_position.z) < 0.15, "A Gatling pea launched outside its own lane.")
	_check(pea.get_parent() == _main._projectiles, "Gatling pea did not use the shared independent container.")
	_check(_plant._recoil_angle >= deg_to_rad(20.0) - 0.00001 and _plant._recoil_angle <= deg_to_rad(30.0) + 0.00001, "A Gatling shot did not kick or exceeded the 30-degree limit.")
	var head := _plant.get_node("Head") as Node3D
	var stem := _plant.get_node("Stem") as Node3D
	_check((stem.transform.affine_inverse() * head.transform).is_equal_approx(_plant._stem_rest_transform.affine_inverse() * _plant._head_rest_transform), "The Gatling head, helmet and stem lost their shared recoil pose.")


func _on_damage(amount: int) -> void:
	_check(amount == 20, "A Gatling impact did not deal exactly 20 damage.")
	_damage.append(amount)


func _on_long_hit(amount: int) -> void:
	_check(amount == 20, "Long combat dealt incorrect Gatling damage.")
	_long_hits += 1


func _reset_in_lane(row: int = 0, column: int = 8) -> void:
	_plant.combat_enabled = false
	_main._reset_view()
	_target.is_ground_zombie = true
	_target.movement_enabled = false
	_target.set_spawn(_lawn.cell_to_world(row, column), PI / 2.0)
	await _step(3)
	_shots.clear()
	_damage.clear()
	_plant.combat_enabled = true


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
	_plant = _main._gatling
	_target = _main._zombie
	_lawn = _main._lawn
	_main._bucket_zombie.is_ground_zombie = false
	_main._bucket_zombie.movement_enabled = false
	_main._bucket_zombie.set_spawn(_lawn.cell_to_world(0, 8) + Vector3(3, 0, 0), PI / 2.0)
	_main._plant.combat_enabled = false
	_main._repeater.combat_enabled = false
	_main._threepeater.combat_enabled = false
	_main._snowpea.combat_enabled = false
	_main._cone_zombie.movement_enabled = false
	_plant.idle_animation_enabled = false
	_plant.combat_enabled = false
	_target.movement_enabled = false
	_plant.shot_fired.connect(_on_shot)
	_target.damaged.connect(_on_damage)
	await _step(3)

	_check(_lawn.world_to_cell(_plant.global_position) == Vector2i(1, 0), "Gatling is not in row 1, column 2.")
	_check((_plant.global_position - _main._repeater.global_position).dot(_main._dave.global_basis.x) < -2.39, "Gatling is not on the left of Repeater from Dave's view.")
	_check(_plant.get_parent() == _main._repeater.get_parent() and _main.get_node("Plants").get_child_count() == 6, "The Gatling plant is not an independent entity.")
	_check(_lawn.get_node("Tiles").get_child_count() == 45, "Adding Gatling modified the lawn grid.")
	_check(_plant.has_node("Head/Helmet/Dome") and _plant.has_node("Head/Muzzle/BarrelRotor/Barrel4/MuzzleTip"), "Gatling lacks its helmet or four complete barrels.")
	_check(_plant.get_node("Head/HeadBody").material_override != _main._plant.get_node("Head/HeadBody").material_override, "Gatling altered the original plant's materials.")
	_main._toggle_idle()
	_check(not _plant.idle_animation_enabled, "Pause did not include Gatling.")
	_main._toggle_idle()
	_check(_plant.idle_animation_enabled, "Resume did not include Gatling.")
	_plant.idle_animation_enabled = false
	_check(_main._dave.camera.is_current(), "Adding Gatling changed Dave's waist camera.")

	# Other lanes, airborne types and targets behind the plant do not start bursts.
	await _reset_in_lane(2)
	await _step(120)
	_check(_shots.is_empty(), "Gatling attacked another lane.")
	await _reset_in_lane()
	_target.is_ground_zombie = false
	await _step(120)
	_check(_shots.is_empty(), "An airborne target triggered Gatling.")
	await _reset_in_lane(0, 0)
	await _step(120)
	_check(_shots.is_empty(), "A target behind Gatling triggered a burst.")

	# Start after 1.5 seconds and emit exactly four separated, real muzzle shots.
	await _reset_in_lane()
	var begin := Engine.get_physics_frames()
	await _step(89)
	_check(_shots.is_empty(), "Gatling fired before its initial 1.5-second delay.")
	await _step(5)
	_check(_shots.size() == 1 and _plant._burst_shots_remaining == 3, "Gatling did not start with one pea and three pending shots.")
	await _step(8)
	_check(_shots.size() == 2, "Gatling did not emit its second pea.")
	await _step(11)
	_check(_shots.size() == 3, "Gatling did not emit its third pea.")
	await _step(11)
	_check(_shots.size() == 4 and _plant._burst_shots_remaining == 0, "Gatling did not finish with exactly four peas.")
	if _shots.size() == 4:
		_check(absf(float(_shots[0]["frame"] - begin) / Engine.physics_ticks_per_second - 1.5) < 0.035, "Incorrect initial Gatling firing delay.")
		for index in range(4):
			_check(_shots[index]["barrel"] == index, "Four-shot burst did not visit all four barrels in order.")
			if index > 0:
				_check(absf(float(_shots[index]["frame"] - _shots[index - 1]["frame"]) / Engine.physics_ticks_per_second - 0.18) < 0.025, "Burst spacing differs from 0.18 seconds.")
		_check(_shots[1]["angle"] > _shots[0]["angle"], "The second Gatling shot did not add fresh recoil.")
		var pea: PeaProjectile = _shots[-1]["pea"]
		var launch_y: float = _shots[-1]["launch"].y
		await _step(5)
		_check(is_instance_valid(pea) and absf(pea.global_position.y - launch_y) < 0.0001, "Gatling pea changed flight height during recoil.")
	await _step(115)
	_check(_shots.size() == 8 and _damage.size() == 4, "A complete four-shot burst did not cause four real impacts or the next burst failed.")
	if _shots.size() >= 8:
		_check(absf(float(_shots[4]["frame"] - _shots[0]["frame"]) / Engine.physics_ticks_per_second - 1.5) < 0.025, "Gatling burst cycles differ from 1.5 seconds.")
	_plant.combat_enabled = false
	await _step(120)
	_check(_damage.size() == 8 and _target.health == 40, "Two four-shot bursts did not deal exactly 160 total damage.")
	_check(_main._projectiles.get_child_count() == 0, "Impacted Gatling peas did not disappear.")

	# Losing a valid ground target cancels every remaining pea, then restarts cadence.
	await _reset_in_lane()
	await _step(102)
	_check(_shots.size() == 2, "Expected half a burst before target loss.")
	_target.is_ground_zombie = false
	await _step(30)
	_check(_shots.size() == 2 and _plant._burst_shots_remaining == 0 and is_zero_approx(_plant._recoil_angle), "Target loss left pending peas or interrupted recoil recovery.")
	_target.is_ground_zombie = true
	await _step(89)
	_check(_shots.size() == 2, "Target reacquisition skipped the full firing delay.")
	await _step(36)
	_check(_shots.size() == 6, "Gatling did not resume a complete four-shot burst.")

	# A nearby weak target dies from the first pea, preventing further burst shots.
	await _reset_in_lane(0, 2)
	_target.health = 20
	await _step(140)
	_check(not _target.is_alive() and _damage.size() == 1 and _shots.size() == 1 and _plant._burst_shots_remaining == 0, "Target death did not cancel the remaining Gatling burst.")

	# Restart clears the remainder of a burst, all peas and the whole firing pose.
	await _reset_in_lane()
	await _step(94)
	_check(_shots.size() == 1 and _plant._burst_shots_remaining == 3, "Expected three pending shots before restart.")
	_main._reset_view()
	_check(_main._projectiles.get_child_count() == 0 and _plant._burst_shots_remaining == 0 and _plant._barrel_index == 0, "Restart left Gatling projectiles or a partial burst.")
	_check(is_zero_approx(_plant._recoil_angle) and _plant.get_node("Head").transform.is_equal_approx(_plant._head_rest_transform) and _plant.get_node("Stem").transform.is_equal_approx(_plant._stem_rest_transform), "Restart left the head, helmet or stem leaning.")
	await _step(30)
	_check(_shots.size() == 1, "A pending Gatling burst survived restart.")

	# All four plants fight together for 60 seconds with bounded projectile/debris counts.
	_plant.combat_enabled = false
	_main._zombie.set_spawn(_lawn.cell_to_world(2, 8), PI / 2.0)
	_main._reset_view()
	_main._zombie.movement_enabled = true
	_main._cone_zombie.movement_enabled = true
	_main.auto_respawn_enabled = true
	var sustained_target := load("res://scenes/enemies/zombie.tscn").instantiate() as Zombie
	GameConfiguration.current().apply_entity(sustained_target)
	sustained_target.maximum_health = 5000
	sustained_target.movement_enabled = false
	sustained_target.knockback_speed = 0.0
	_main.get_node("Enemies").add_child(sustained_target)
	sustained_target.set_spawn(_lawn.cell_to_world(0, 8), PI / 2.0)
	sustained_target.damaged.connect(_on_long_hit)
	await _step(3)
	_shots.clear()
	_main._plant.combat_enabled = true
	_main._repeater.combat_enabled = true
	_main._threepeater.combat_enabled = true
	_plant.combat_enabled = true
	await _step(3600)
	_check(_shots.size() >= 152 and _long_hits >= 140 and sustained_target.health == 5000 - 20 * _long_hits, "Sustained four-plant combat lost Gatling shots or dealt incorrect damage.")
	_check(_main.get_node("Enemies").get_child_count() == 6 and _main._projectiles.get_child_count() < 25 and _main._debris.get_child_count() < 24, "Sustained four-plant combat accumulated expired entities.")
	_main._reset_view()
	_check(_main._projectiles.get_child_count() == 0 and _main._debris.get_child_count() == 0 and _plant._burst_shots_remaining == 0, "Restart failed after sustained four-plant combat.")
	if not _failed:
		print("PASS: independent helmet/four-barrel model, left of Repeater, own-lane ground targeting, exactly four horizontal peas every 1.5s with 0.18s spacing, four real 20-damage impacts, shared recoil <=30deg, invalid/dead-target burst cancellation, restart cleanup and 60s of combined four-plant combat.")
	quit(1 if _failed else 0)
