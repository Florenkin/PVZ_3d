extends SceneTree
## Real icy impacts, timed slowing, flash/frost priority and clean lifecycle resets.

var _failed: bool = false
var _main: Node3D
var _plant: SnowPea
var _target: Zombie
var _lawn: LawnGrid
var _shots: Array[Dictionary] = []
var _damage: Array[int] = []
var _record_damage: bool = true


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
	_shots.append({"frame": Engine.get_physics_frames(), "pea": pea, "launch": pea.global_position})
	_check(pea.damage == 20 and pea.speed == 10.0 and pea.slow_multiplier == 0.5 and pea.slow_duration == 10.0, "Snow peas have incorrect damage, speed or slow settings.")
	_check(pea.get_parent() == _main._projectiles and is_zero_approx(pea.direction.y) and pea.direction.dot(Vector3.RIGHT) > 0.999, "Snow pea did not use a horizontal independent trajectory.")
	var color: Color = pea.get_node("Mesh").material_override.albedo_color
	_check(color.b > color.g and color.g > color.r, "Snow pea does not have its own ice-blue palette.")
	_check(_plant._recoil_angle > 0.0 and _plant._recoil_angle <= deg_to_rad(30.0), "Snow pea firing omitted recoil or exceeded its limit.")


func _on_damage(amount: int) -> void:
	if _record_damage:
		_check(amount == 20, "A snow pea impact did not deal exactly 20 damage.")
		_damage.append(amount)


func _reset(row: int = 4, column: int = 8) -> void:
	_plant.combat_enabled = false
	_main.auto_respawn_enabled = false
	_main._reset_view()
	_target = _main._zombie
	if not _target.damaged.is_connected(_on_damage):
		_target.damaged.connect(_on_damage)
	_target.is_ground_zombie = true
	_target.movement_enabled = false
	_target.knockback_speed = 0.0
	_target.set_spawn(_lawn.cell_to_world(row, column), PI / 2.0)
	await _step(3)
	_shots.clear()
	_damage.clear()


func _launch_at_target(icy: bool = true) -> PeaProjectile:
	var path := "res://scenes/projectiles/snow_pea.tscn" if icy else "res://scenes/projectiles/pea.tscn"
	var pea := load(path).instantiate() as PeaProjectile
	GameConfiguration.current().apply_entity(pea)
	pea.speed = 50.0
	_main._projectiles.add_child(pea)
	pea.global_position = _target.global_position + Vector3(-1.0, 1.2, 0)
	return pea


func _all_white(zombie: Zombie) -> bool:
	for mesh: MeshInstance3D in zombie._materials:
		if mesh.material_override != Zombie.HIT_MATERIAL:
			return false
	return true


func _all_original(zombie: Zombie) -> bool:
	for mesh: MeshInstance3D in zombie._materials:
		if mesh.material_override != zombie._materials[mesh]:
			return false
	return true


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	GameConfiguration.current().apply_entity(_main)
	_main.auto_respawn_enabled = false
	root.add_child(_main)
	_main._pole_zombie.movement_enabled = false
	_main._pole_zombie.is_ground_zombie = false
	_main._pole_zombie.set_spawn(_main._lawn.cell_to_world(4, 8) + Vector3(3, 0, 0), PI / 2.0)
	_lawn = _main._lawn
	_plant = _main._snowpea
	_target = _main._zombie
	for plant: Peashooter in [_main._plant, _main._repeater, _main._threepeater, _main._gatling]:
		plant.combat_enabled = false
	_main._cone_zombie.movement_enabled = false
	_main._bucket_zombie.movement_enabled = false
	_plant.combat_enabled = false
	_plant.shot_fired.connect(_on_shot)
	await _reset()
	_check(_lawn.world_to_cell(_plant.global_position) == Vector2i(1, 4), "Snow Pea is not in row 5, column 2.")
	_check((_plant.global_position - _main._threepeater.global_position).dot(_main._dave.global_basis.x) > 2.39, "Snow Pea is not to the right of Threepeater from Dave's view.")
	_check(_main.get_node("Plants").get_child_count() == 6 and _lawn.get_node("Tiles").get_child_count() == 45, "Adding Snow Pea changed independent plant or tile counts.")
	_check(_plant.has_node("Head/IceCrest/Crystal3") and _plant.get_node("Head/HeadBody").material_override != _main._plant.get_node("Head/HeadBody").material_override, "Snow Pea lacks its ice crest or isolated blue material.")
	_main._toggle_idle()
	_check(not _plant.idle_animation_enabled, "Idle pause did not include Snow Pea.")
	_main._toggle_idle()
	_check(_plant.idle_animation_enabled, "Idle resume did not include Snow Pea.")
	_plant.idle_animation_enabled = false
	_check(_main._dave.camera.is_current(), "Adding Snow Pea changed Dave's waist camera.")

	# Own-lane ground targeting and the first full 1.5-second firing delay.
	await _reset(3)
	_plant.combat_enabled = true
	await _step(110)
	_check(_shots.is_empty(), "Snow Pea attacked a neighboring lane.")
	await _reset()
	_target.is_ground_zombie = false
	_plant.combat_enabled = true
	await _step(110)
	_check(_shots.is_empty(), "Snow Pea acquired an airborne-type zombie.")
	await _reset(4, 0)
	_plant.combat_enabled = true
	await _step(110)
	_check(_shots.is_empty(), "Snow Pea acquired a target behind it.")
	await _reset()
	_plant.combat_enabled = true
	await _step(89)
	_check(_shots.is_empty(), "Snow Pea fired before 1.5 seconds.")
	await _step(5)
	_check(_shots.size() == 1, "Snow Pea did not launch exactly one first pea.")
	_plant.combat_enabled = false
	if _shots.size() == 1:
		var pea: PeaProjectile = _shots[0]["pea"]
		var launch_y: float = _shots[0]["launch"].y
		await _step(8)
		_check(is_instance_valid(pea) and absf(pea.global_position.y - launch_y) < 0.0001, "Recoil changed the snow pea's flight height.")
	await _step(92)
	_check(_target.health == 180 and _damage.size() == 1 and _main._projectiles.get_child_count() == 0, "The real snow pea did not deal one 20-damage impact and disappear.")
	_check(_target._slow_remaining > 9.0 and _target._slow_multiplier == 0.5 and _all_white(_target), "The icy impact failed to start slowing with the white hit flash on top.")
	await _step(40)
	_check(not _all_white(_target) and not _all_original(_target), "The white hit flash did not give way to the blue frost tint.")
	_check(_all_original(_main._cone_zombie) and _all_original(_main._bucket_zombie), "Freezing one zombie changed other enemy instances' materials.")
	_target.movement_enabled = true
	var start_x := _target.global_position.x
	await _step(60)
	_check(absf(start_x - _target.global_position.x - 0.25) < 0.025 and _target.walk_speed == 0.5, "The frost did not halve actual walking speed while preserving the base stat.")

	# A second icy collision refreshes duration without stacking to quarter speed.
	await _step(180)
	var before_refresh := _target._slow_remaining
	var refreshing_pea := _launch_at_target()
	await _step(5)
	_check(not is_instance_valid(refreshing_pea) and _target.health == 160 and _damage.size() == 2, "A refreshing icy collision did not deal one hit.")
	_check(_target._slow_remaining > before_refresh + 2.0 and _target._slow_remaining > 9.8 and _target._slow_multiplier == 0.5, "Repeated frost did not refresh the timer or stacked its movement penalty.")
	var remaining_before_normal := _target._slow_remaining
	_launch_at_target(false)
	await _step(5)
	_check(_target.health == 140 and _target._slow_remaining < remaining_before_normal and _target._slow_multiplier == 0.5, "An ordinary pea changed or refreshed the icy slow effect.")
	await _step(int(ceil(_target._slow_remaining * Engine.physics_ticks_per_second)) + 2)
	_check(_all_original(_target) and _target._slow_remaining == 0.0 and _target._slow_multiplier == 1.0, "Frost did not expire and restore original materials and movement.")
	start_x = _target.global_position.x
	await _step(60)
	_check(absf(start_x - _target.global_position.x - 0.5) < 0.025, "Walking speed did not return to 0.5 after frost expired.")

	# Expiring frost must not erase a still-active white hit flash.
	await _reset()
	_target.apply_slow(0.5, 0.1)
	_record_damage = false
	_target.take_damage(1, Vector3.RIGHT)
	_record_damage = true
	await _step(12)
	_check(_target._slow_remaining == 0.0 and _all_white(_target), "Frost expiry prematurely cleared the white hit flash.")
	await _step(25)
	_check(_all_original(_target), "The final white flash did not restore original materials after frost expired.")

	# Cold death clears the status; debris and the replacement keep original palettes.
	await _reset()
	_target.apply_slow(0.5, 10.0)
	var frosted_materials := _target._frost_materials.values()
	_target.health = 20
	_main.auto_respawn_enabled = true
	_launch_at_target()
	await _step(5)
	var old_target := _target
	var remains: Array[ZombieDebris] = old_target._spawned_debris.duplicate()
	_check(not old_target.is_alive() and old_target._slow_remaining == 0.0 and old_target._slow_multiplier == 1.0, "Cold death retained the living slowdown status.")
	await _step(36)
	for part: ZombieDebris in remains:
		if is_instance_valid(part):
			for mesh: MeshInstance3D in part._materials:
				_check(mesh.material_override != Zombie.HIT_MATERIAL and mesh.material_override not in frosted_materials, "Detached remains inherited the living frost tint or an expired hit flash.")
	await _step(29)
	_target = _main._zombie
	_check(not is_instance_valid(old_target) and _target.health == 200 and _target._slow_remaining == 0.0 and _target._slow_multiplier == 1.0 and _all_original(_target), "A new zombie inherited the previous zombie's frost state.")
	_check(_lawn.world_to_cell(_target.global_position).y == 2, "The normal zombie's default respawn lane changed.")

	# Continuous Snow Pea attacks retain the standard cadence; R clears every status.
	await _reset()
	_plant.combat_enabled = true
	await _step(365)
	_check(_shots.size() == 4 and _damage.size() >= 2, "Continuous Snow Pea attacks did not keep their real 1.5-second cadence.")
	for index in range(1, _shots.size()):
		_check(absf(float(_shots[index]["frame"] - _shots[index - 1]["frame"]) / Engine.physics_ticks_per_second - 1.5) < 0.025, "Snow Pea cadence drifted after repeated hits.")
	for zombie: Zombie in [_main._zombie, _main._cone_zombie, _main._bucket_zombie]:
		zombie.apply_slow(0.5, 10.0)
	_plant._fire()
	_main._reset_view()
	_check(_main._projectiles.get_child_count() == 0 and _main._debris.get_child_count() == 0 and _plant._shot_countdown == _plant.shot_interval and is_zero_approx(_plant._recoil_angle), "Restart left snow peas, debris, cooldown or recoil.")
	for zombie: Zombie in [_main._zombie, _main._cone_zombie, _main._bucket_zombie]:
		_check(zombie._slow_remaining == 0.0 and zombie._slow_multiplier == 1.0 and _all_original(zombie), "Restart retained slowing or frost materials on an enemy type.")
	if not _failed:
		print("PASS: right of Threepeater, independent icy model and projectile, own-lane ground targeting, horizontal 20-damage peas every 1.5s, actual 50% slowing for 10s, refreshed nonstacking slow, instance palette isolation, white flash priority, timed movement/color recovery, original debris and fresh respawn state, shared recoil and complete restart cleanup.")
	quit(1 if _failed else 0)
