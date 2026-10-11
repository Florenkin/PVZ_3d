extends SceneTree
## Real startup/configuration integration; never writes config/game_config.json.

var failed: bool = false
var main: Node3D
var config: GameConfiguration


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func step(frames: int) -> void:
	for index in frames:
		await physics_frame


func _run() -> void:
	config = GameConfiguration.current()
	config.emit_warnings = false
	var original_text := FileAccess.get_file_as_string("res://config/game_config.json")
	config.load_config()
	check(config.warnings.is_empty(), "Shipped JSON produces validation warnings.")
	check(config.values == config.default_values(), "Shipped JSON and embedded fallback differ.")
	# Missing, malformed, partial, wrongly typed, out-of-range and conflicting layouts.
	config.load_config("user://pvz_config_missing.json")
	check(config.values == config.default_values() and not config.warnings.is_empty(), "Missing configuration did not fall back.")
	var fixture_path := "user://pvz_config_test.json"
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	file.store_string("{invalid")
	file.close()
	config.load_config(fixture_path)
	check(config.values == config.default_values() and config.warnings[0].contains("JSON"), "Malformed JSON did not report parse location.")
	file = FileAccess.open(fixture_path, FileAccess.WRITE)
	file.store_string('{"plants":{"common":{"pea_damage":31,"shot_interval":"bad","maximum_recoil_degrees":40}},"zombies":{"common":{"maximum_health":0}},"models":{"peashooter":{"parts":{"Head":{"scale":[1,0,1]}}}}}')
	file.close()
	config.load_config(fixture_path)
	check(config.values.plants.common.pea_damage == 31 and config.values.plants.common.shot_interval == 1.5, "Field fallback discarded valid neighbor.")
	check(config.values.plants.common.maximum_recoil_degrees == 30 and config.values.zombies.common.maximum_health == 200, "Invalid ranges did not fall back.")
	check(config.values.models.peashooter.parts.Head.scale == config.default_values().models.peashooter.parts.Head.scale and config.warnings.size() == 4, "Model validation or diagnostics failed.")
	config.use_values_for_tests({"lawn": {"rows": 4}})
	check(config.values.lawn.rows == 5 and config.values.placements.wall_nut.row == 5, "Conflicting layout did not fall back coherently.")
	config.use_values_for_tests({"plants": {"common": {"pea_damage": 35}, "types": {"repeater": {"pea_damage": 45}}}})
	check(config.entity_stats("peashooter").pea_damage == 35 and config.entity_stats("repeater").pea_damage == 45, "Type override precedence failed.")
	var settings := config.default_values()
	settings.plants.common.pea_damage = 37
	settings.plants.common.pea_speed = 12.0
	settings.plants.common.shot_interval = 0.3
	settings.plants.common.combat_enabled = false
	settings.plants.common.idle_animation_enabled = false
	settings.plants.common.idle_bend_degrees = 0
	settings.plants.common.recoil_degrees = 12
	settings.plants.types.repeater.burst_size = 3
	settings.plants.types.repeater.burst_spacing = 0.07
	settings.plants.types.gatling_pea.burst_size = 6
	settings.plants.types.gatling_pea.burst_spacing = 0.04
	settings.zombies.common.maximum_health = 111
	settings.zombies.common.walk_speed = 1.25
	settings.zombies.common.flash_duration = 0.12
	settings.zombies.common.recoil_recovery_time = 0.25
	settings.zombies.common.knockback_speed = 0.4
	settings.zombies.common.knockback_deceleration = 8.0
	settings.zombies.common.armor_drop_health = 150
	settings.zombies.types.conehead_zombie.maximum_health = 333
	settings.zombies.types.pole_vaulting_zombie.pole_length = 4.2
	settings.respawn.respawn_delay = 0.2
	settings.lawn.rows = 6
	settings.lawn.columns = 10
	settings.lawn.cell_size = 3.0
	settings.lawn.tile_width = 2.8
	settings.lawn.tile_thickness = 0.6
	settings.lawn.surface_height = 0.15
	for key: String in ["zombie", "conehead_zombie", "buckethead_zombie", "pole_vaulting_zombie"]:
		settings.placements[key].column = 10
	settings.dave.waist_height = 1.15
	settings.cameras.first_person.fov = 55
	settings.models.peashooter.scale = 1.2
	settings.models.peashooter.parts.Head.scale = [0.8, 0.8, 0.8]
	settings.models.zombie.scale = 1.2
	settings.models.zombie.parts["Visuals/Head"].scale = [1.1, 1.1, 1.1]
	settings.projectiles.radius = 0.08
	settings.projectiles.maximum_distance = 40
	settings.physics.parts.cone.mass = 0.8
	settings.physics.gravity = 6.0
	settings.physics.parts.cone.lifetime = 0.4
	settings.physics.parts.corpse.lifetime = 0.4
	settings.physics.parts.head.lifetime = 0.5
	settings.environment.sun_energy = 0.6
	file = FileAccess.open(fixture_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings))
	file.close()
	config.load_config(fixture_path)
	check(config.warnings.is_empty(), "Valid custom configuration rejected.")
	main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	for enemy: Zombie in main.get_node("Enemies").get_children():
		enemy.movement_enabled = false
	await step(5)
	var lawn: LawnGrid = main._lawn
	var plant: Peashooter = main._plant
	var zombie: Zombie = main._zombie
	check(lawn.get_node("Tiles").get_child_count() == 60 and lawn.row_count == 6 and lawn.column_count == 10, "Configured lawn was not generated.")
	check(lawn.world_to_cell(lawn.cell_to_world(5, 9)) == Vector2i(9, 5), "Configured lawn coordinate conversion failed.")
	var tile: GrassTile = lawn.get_tile(5, 9)
	check(is_equal_approx(tile.get_node("GroundBody/CollisionShape3D").shape.size.x, 2.8), "Tile collider width did not follow configuration.")
	check(plant.pea_damage == 37 and plant.pea_speed == 12 and zombie.health == 111 and zombie.walk_speed == 1.25, "Entity values were applied too late or not at all.")
	check(main._cone_zombie.health == 333 and main._dave.camera.fov == 55 and is_equal_approx(main._dave.waist_mount.position.y, 1.15), "Type stats or waist camera did not apply.")
	check(main._dave.movement_bounds.size.is_equal_approx(Vector2(29.1, 17.1)), "Dave movement bounds did not follow lawn.")
	check(is_equal_approx(plant.get_node("Head").scale.x, 0.96), "Model overall/head scales did not combine.")
	check(plant.scale == Vector3.ONE and zombie.scale == Vector3.ONE and zombie.get_node("CollisionShape3D").scale == Vector3.ONE, "Physics root/collider was scaled.")
	check(zombie.get_node("CollisionShape3D").shape.height > 1.82, "Zombie collider did not follow resized body.")
	check(main._combat_status.text.contains("伤害 37") and main._combat_status.text.contains("0.3"), "HUD retained hardcoded attack values.")
	check(is_equal_approx(main.get_node("Sun").light_energy, 0.6), "Scene lighting did not apply.")
	check(main._dave._gravity == 6.0 and zombie._gravity == 6.0, "Character gravity did not apply.")
	var probe := ZombieDebris.new()
	config.configure_debris(probe, "")
	probe.position = Vector3(0, 20, 0)
	main.get_node("Debris").add_child(probe)
	await step(10)
	check(probe.linear_velocity.y < -0.85 and probe.linear_velocity.y > -1.05, "Rigid-body gravity did not use configured world gravity.")
	probe.queue_free()
	var pole: PoleVaultingZombie = main._pole_zombie
	check(is_equal_approx(pole.get_node("Visuals/Pole/Shaft").mesh.height, 4.2), "Pole mesh length did not apply.")
	var pea: PeaProjectile
	# Capture in an array because lambda capture of locals is by value.
	var peas: Array[PeaProjectile] = []
	plant.shot_fired.connect(func(p: PeaProjectile): peas.append(p))
	zombie.set_spawn(plant.global_position + Vector3(4, 0, 0), PI / 2)
	await step(3)
	var muzzle_position := plant._muzzle_tip.global_position
	plant._fire()
	check(peas.size() == 1 and peas[0].global_position.is_equal_approx(muzzle_position), "Projectile did not launch from resized model muzzle.")
	pea = peas[0]
	check(pea.damage == 37 and pea.speed == 12 and pea.maximum_distance == 40 and is_equal_approx(pea.get_node("CollisionShape3D").shape.radius, 0.08), "Spawned projectile did not use snapshot.")
	await step(25)
	check(zombie.health == 74, "Configured projectile damage did not affect actual collision.")
	main._cone_zombie.take_damage(183, Vector3.RIGHT)
	await step(2)
	var cone: ZombieDebris
	for part: ZombieDebris in get_nodes_in_group("zombie_debris"):
		if part.part_kind == &"cone": cone = part
	check(cone != null and is_equal_approx(cone.mass, 0.8) and cone.lifetime == 0.4, "Configured threshold/mass/lifetime did not apply to dropped cone.")
	await step(27)
	check(not is_instance_valid(cone), "Configured part lifetime did not clean up cone.")
	# Six-shot Gatling uses its four barrels cyclically, without missing nodes.
	var shots: Array[PeaProjectile] = []
	main._gatling.shot_fired.connect(func(p: PeaProjectile): shots.append(p))
	main._bucket_zombie.set_spawn(main._gatling.global_position + Vector3(6, 0, 0), PI / 2)
	await step(3)
	main._gatling.combat_enabled = true
	await step(31)
	main._gatling.combat_enabled = false
	check(shots.size() == 6, "Custom Gatling burst count/spacing failed.")
	var repeat_shots: Array[PeaProjectile] = []
	main._repeater.shot_fired.connect(func(p: PeaProjectile): repeat_shots.append(p))
	main._cone_zombie.set_spawn(main._repeater.global_position + Vector3(6, 0, 0), PI / 2)
	await step(3)
	main._repeater.combat_enabled = true
	await step(28)
	main._repeater.combat_enabled = false
	check(repeat_shots.size() == 3, "Custom Repeater burst count/spacing failed.")
	var previous := zombie.get_instance_id()
	zombie.take_damage(zombie.health, Vector3.RIGHT)
	check(absf(main._respawn_timer.time_left - 0.2) < 0.001, "Configured respawn delay did not start.")
	await step(2)
	var dead_body: ZombieDebris
	var dead_head: ZombieDebris
	for part: ZombieDebris in get_nodes_in_group("zombie_debris"):
		if part.owner_zombie_id == previous:
			if part.part_kind == &"corpse": dead_body = part
			if part.part_kind == &"head": dead_head = part
	check(dead_body != null and dead_body.lifetime == 0.4 and dead_head != null and dead_head.lifetime == 0.5, "Custom corpse/head lifetimes did not apply.")
	await step(15)
	zombie = main._zombie
	check(zombie.get_instance_id() != previous and zombie.health == 111 and zombie.walk_speed == 1.25, "Replacement zombie lost configured stats.")
	check(zombie._spawn_transform.origin.is_equal_approx(lawn.cell_to_world(2, 9)), "Replacement spawned in hardcoded cell.")
	check(zombie.get_node("Visuals").scale.is_equal_approx(Vector3.ONE * 1.2), "Replacement model lost configured size.")
	await step(16)
	check(not is_instance_valid(dead_body) and not is_instance_valid(dead_head), "Custom corpse/head lifetimes did not clean up.")
	main._reset_view()
	check(zombie.health == 111 and plant.pea_damage == 37 and lawn.row_count == 6, "R reset reloaded or lost startup configuration.")
	# Independent instance resources and the customized shaft survive the planted pose/drop.
	pole = main._pole_zombie
	pole.set_spawn(main._wallnut.global_position + Vector3(1.1, 0, 0), PI / 2)
	pole.movement_enabled = true
	await step(30)
	check(pole.is_vaulting and is_equal_approx(pole.get_node("Visuals/Pole/Shaft").mesh.height, 4.2), "Customized pole length changed during vault.")
	pole._release_pole()
	await step(2)
	var fallen_pole: ZombieDebris
	for part: ZombieDebris in get_nodes_in_group("zombie_debris"):
		if part.part_kind == &"pole": fallen_pole = part
	check(fallen_pole != null and is_equal_approx(fallen_pole.get_node("CollisionShape3D").shape.height, 4.2) and fallen_pole.scale.is_equal_approx(Vector3.ONE), "Pole physics geometry did not follow configured shaft.")
	check(FileAccess.get_file_as_string("res://config/game_config.json") == original_text, "Test changed editable user configuration.")
	main._reset_view()
	main.queue_free()
	await step(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	if not failed:
		print("PASS: startup JSON/default equality, missing/malformed/invalid fallback, type precedence, custom real combat/bursts/respawn/debris TTL, 6x10 lawn, model/collider/muzzle/pole/camera synchronization and reset snapshot; user JSON untouched.")
	quit(1 if failed else 0)
