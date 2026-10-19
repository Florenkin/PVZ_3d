extends SceneTree
## Thresholds, stationary anger, real speed/ice/pea collisions, debris and lifecycle.

var failed: bool = false
var main: Node3D
var zombie: NewspaperZombie
var parts: Array[ZombieDebris] = []
var rage_frames: Array[int] = []
var natural: bool = false
var cycle_hits: int = 0
var respawns: Dictionary = {}


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func step(frames: int) -> void:
	for index in frames:
		await physics_frame


func watch(target: NewspaperZombie) -> void:
	target.part_detached.connect(func(part: ZombieDebris): parts.append(part))
	target.rage_started.connect(func(): rage_frames.append(Engine.get_physics_frames()))
	target.damaged.connect(func(amount: int):
		if natural:
			check(amount == 20, "Natural combat changed the pea damage.")
			cycle_hits += 1)
	target.defeated.connect(func():
		if natural:
			check(cycle_hits == 18, "350 HP must require exactly 18 real 20-damage hits."))


func on_respawn(target: Zombie) -> void:
	var key := GameConfiguration.current().entity_key(target)
	respawns[key] = int(respawns.get(key, 0)) + 1
	if target is NewspaperZombie:
		zombie = target
		watch(zombie)
		check(zombie.health == 350 and zombie.has_newspaper and not zombie.is_angry and not zombie.is_enraged and zombie._anger_remaining == 0.0, "Respawn inherited paper loss, rage or damage.")
		check(zombie.global_position.is_equal_approx(main._lawn.cell_to_world(3, 8)), "Newspaper respawn missed row 4's baseline.")
		if natural:
			check(cycle_hits == 18, "Respawn lost the complete natural fight.")
			cycle_hits = 0
	check(main.get_node("Enemies").get_child_count() == 5, "Respawn duplicated an enemy.")


func reset() -> void:
	main.auto_respawn_enabled = false
	for plant: Node in main.get_node("Plants").get_children():
		if plant is Peashooter:
			plant.combat_enabled = false
	main._reset_view()
	zombie = main._newspaper_zombie
	zombie.movement_enabled = false
	zombie.knockback_speed = 1.4
	zombie.set_spawn(main._lawn.cell_to_world(3, 8), PI / 2.0)
	await step(3)
	parts.clear()
	rage_frames.clear()


func paper_part() -> ZombieDebris:
	for part: ZombieDebris in parts:
		if is_instance_valid(part) and part.part_kind == &"newspaper":
			return part
	return null


func run() -> void:
	var config := GameConfiguration.current()
	config.emit_warnings = false
	config.use_values_for_tests({"zombies": {"types": {"newspaper_zombie": {"newspaper_drop_health": 200.5, "anger_pause_duration": 0, "enraged_speed_multiplier": 1}}}})
	check(config.entity_stats("newspaper_zombie").newspaper_drop_health == 200 and config.entity_stats("newspaper_zombie").anger_pause_duration == 1.0 and config.entity_stats("newspaper_zombie").enraged_speed_multiplier == 2.0 and config.warnings.size() == 3, "Newspaper configuration accepted invalid threshold/pause/multiplier.")
	config.use_values_for_tests(config.default_values())
	main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	zombie = main._newspaper_zombie
	watch(zombie)
	main.zombie_respawned.connect(on_respawn)
	check(zombie.health == 350 and zombie.has_newspaper and zombie.get_walk_speed() == 0.5, "Newspaper initial HP, newspaper or speed is incorrect.")
	check(main._lawn.world_to_cell(zombie.global_position) == Vector2i(8, 3) and (-zombie.global_basis.z).dot(Vector3.LEFT) > 0.999, "Newspaper is not facing the Threepeater from row 4 column 9.")
	check(zombie.has_node("Visuals/Head/Glasses/LeftRim") and zombie.has_node("Visuals/Newspaper/RightPage/Headline") and not zombie.get_node("Visuals/Head/AngryEyes").visible, "Reading model lacks glasses, printed newspaper or a separate angry face.")
	check(main._newspaper_health_bar.value == 350 and main._newspaper_health_label.text.contains("350"), "Newspaper HP did not reach the sidebar.")
	var inspect := InputEventKey.new()
	inspect.keycode = KEY_N
	inspect.pressed = true
	root.push_input(inspect, true)
	await step(2)
	check(main._inspect_newspaper and main._selected_enemy() == zombie and absf(main._orbit.default_yaw - deg_to_rad(-80.0)) < 0.001, "N did not select the configured newspaper inspection angle.")
	root.push_input(inspect, true)
	await step(2)
	check(main._dave.camera.is_current(), "Second N did not return to Dave's camera.")
	# Other enemies remain counted, but cannot interfere with isolated trajectories.
	for other: Zombie in main.get_node("Enemies").get_children():
		if other != zombie:
			other.movement_enabled = false
			other.is_ground_zombie = false
			other.set_spawn(other.global_position + Vector3(40, 0, 0), PI / 2.0)
	await reset()
	zombie.movement_enabled = true
	var start := zombie.global_position
	await step(60)
	check(absf(start.x - zombie.global_position.x - 0.5) < 0.025, "Reading speed is not 0.5 units/s.")
	await reset()
	zombie.take_damage(149, Vector3.RIGHT)
	check(zombie.health == 201 and zombie.has_newspaper and parts.is_empty(), "Paper detached above 200 HP.")
	zombie.movement_enabled = true
	var drop_frame := Engine.get_physics_frames()
	zombie.take_damage(1, Vector3.RIGHT)
	var paper := paper_part()
	start = zombie.global_position
	check(zombie.health == 200 and not zombie.has_newspaper and zombie.is_angry and not zombie.is_enraged and paper != null and parts.size() == 1, "Exactly one paper must detach at 200 HP and start the outburst.")
	check(not zombie.get_node("Visuals/Head/Glasses").visible and zombie.get_node("Visuals/Head/AngryEyes").visible and main._newspaper_status.text.contains("停步"), "The angry face or outburst HUD did not activate.")
	await step(20)
	zombie.take_damage(1, Vector3.RIGHT)
	await step(38)
	check(zombie.global_position.distance_to(start) < 0.005 and rage_frames.is_empty() and parts.size() == 1 and zombie._anger_remaining < 0.1, "Outburst moved, detached twice or restarted its timer on a later hit.")
	await step(5)
	check(zombie.is_enraged and rage_frames.size() == 1 and absf(float(rage_frames[0] - drop_frame) / 60.0 - 1.0) < 0.04, "Rage did not begin once after one second.")
	zombie.knockback_speed = 0.0
	start = zombie.global_position
	await step(60)
	check(absf(start.x - zombie.global_position.x - 1.0) < 0.025 and zombie.walk_speed == 0.5 and zombie.get_walk_speed() == 1.0, "Rage did not double actual speed while retaining the base stat.")
	zombie.apply_slow(0.5, 1.5)
	start = zombie.global_position
	await step(60)
	check(absf(start.x - zombie.global_position.x - 0.5) < 0.025 and zombie.is_enraged, "Cold did not halve rage movement or erased rage.")
	await step(40)
	check(zombie.get_walk_speed() == 1.0 and zombie.is_enraged, "Cold expiry failed to restore rage speed.")
	zombie.movement_enabled = false
	check(is_equal_approx(paper.mass, 0.12) and paper.lifetime == 10.0 and paper.get_node("CollisionShape3D").shape is BoxShape3D and paper.scale.is_equal_approx(Vector3.ONE), "Dropped newspaper lacks independent physical shape/mass/lifetime.")
	check(paper.has_landed, "The physical newspaper never contacted the ground.")
	await step(620)
	check(not is_instance_valid(paper), "Paper survived its ten-second lifetime.")
	# A real pea crosses the threshold; armor remains one shared health pool.
	await reset()
	zombie.health = 210
	var pea := load("res://scenes/projectiles/pea.tscn").instantiate() as PeaProjectile
	pea.speed = 50.0
	main._projectiles.add_child(pea)
	pea.global_position = zombie.global_position + Vector3(-1, 1.2, 0)
	await step(5)
	check(not is_instance_valid(pea) and zombie.health == 190 and not zombie.has_newspaper and zombie.is_angry and parts.size() == 1, "Actual pea collision failed to cross the paper threshold once.")
	main._reset_view()
	await step(3)
	check(zombie.health == 350 and zombie.has_newspaper and not zombie.is_angry and not zombie.is_enraged and main._debris.get_child_count() == 0 and main._projectiles.get_child_count() == 0, "R retained paper loss, anger, projectiles or debris.")
	# Immediate reset must also cancel off-tree deferred parts and rage emission.
	await reset()
	zombie.take_damage(250, Vector3.RIGHT)
	check(zombie.health == 100 and parts.size() == 2, "A large nonlethal hit must drop both paper and one hand.")
	main._reset_view()
	await step(70)
	check(rage_frames.is_empty() and zombie.has_newspaper and main._debris.get_child_count() == 0, "An old outburst or deferred part survived reset.")
	await reset()
	zombie.take_damage(9999, Vector3.RIGHT)
	check(parts.size() == 4 and zombie.health == 0 and zombie._anger_remaining == 0 and not zombie.is_enraged and not zombie.is_angry, "Lethal threshold crossing failed to drop paper/hand/head/corpse or started rage after death.")
	var corpse: ZombieDebris = parts[-1]
	await step(303)
	check(not is_instance_valid(corpse) and is_instance_valid(paper_part()), "Death lost the independent five-second corpse/ten-second paper lifetimes.")
	await step(310)
	check(main._debris.get_child_count() == 0, "Lethal newspaper remains failed to expire.")
	# Death during the stationary outburst cancels rage and preserves fresh respawn.
	await reset()
	main._toggle_newspaper_view()
	zombie.take_damage(150, Vector3.RIGHT)
	await step(12)
	main.auto_respawn_enabled = true
	var previous := zombie
	zombie.take_damage(9999, Vector3.RIGHT)
	check(zombie._anger_remaining == 0 and not zombie.is_enraged and absf(main._newspaper_respawn_timer.time_left - 1.0) < 0.001, "Death in outburst did not stop anger and schedule respawn.")
	await step(65)
	check(not is_instance_valid(previous) and zombie.health == 350 and zombie.has_newspaper and rage_frames.is_empty(), "Replacement reused the old instance or inherited a late rage event.")
	check(main._selected_enemy() == zombie and main._orbit.target.distance_to(zombie.global_position + Vector3(0, 0.78, 0)) < 0.03, "Inspection did not follow the newspaper replacement.")
	zombie.take_damage(350, Vector3.RIGHT)
	main._reset_view()
	await step(70)
	check(main._newspaper_respawn_timer.is_stopped() and main._newspaper_zombie == zombie and zombie.has_newspaper, "Reset failed to cancel newspaper respawn.")
	main._toggle_bucket_view()
	check(not main._inspect_newspaper and main._selected_enemy() == main._bucket_zombie, "Changing model inspection kept the newspaper selection.")
	main._set_model_view(false)
	# Natural five-lane fights must sustain all types and exactly 18 hits per newspaper.
	await reset()
	for other: Zombie in main.get_node("Enemies").get_children():
		var key := config.entity_key(other)
		other.is_ground_zombie = true
		other.movement_enabled = true
		other.set_spawn(main._placement_position(key), main._placement_yaw(key))
	main.auto_respawn_enabled = true
	# Keep the faster enemy ahead of the fixed shooter while exercising full kills.
	# In the normal demo it can pass plants; that is not a victory/failure condition.
	zombie.maximum_walk_distance = 12.0
	respawns.clear()
	cycle_hits = 0
	natural = true
	for plant: Node in main.get_node("Plants").get_children():
		if plant is Peashooter:
			plant.combat_enabled = true
	await step(5400)
	for key: String in ["zombie", "conehead_zombie", "buckethead_zombie", "pole_vaulting_zombie", "newspaper_zombie"]:
		check(int(respawns.get(key, 0)) >= 2, "Natural five-lane combat failed to independently respawn " + key)
	check(main.get_node("Enemies").get_child_count() == 5 and main._projectiles.get_child_count() < 40 and main._debris.get_child_count() < 45, "Natural combat accumulated expired entities.")
	natural = false
	main._reset_view()
	await step(3)
	check(main._debris.get_child_count() == 0 and main._projectiles.get_child_count() == 0 and main._dave.camera.is_current(), "Five-lane reset failed to restore the clean game.")
	main.queue_free()
	await step(2)
	# A separate configured instance verifies the custom pause/speed and resized paper.
	var custom := config.default_values()
	custom.zombies.types.newspaper_zombie.anger_pause_duration = 0.3
	custom.zombies.types.newspaper_zombie.enraged_speed_multiplier = 3.0
	custom.models.newspaper_zombie.scale = 1.25
	custom.models.newspaper_zombie.parts["Visuals/Newspaper"].scale = [1.2, 1.2, 1.2]
	config.use_values_for_tests(custom)
	main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	zombie = main._newspaper_zombie
	for plant: Node in main.get_node("Plants").get_children():
		if plant is Peashooter: plant.combat_enabled = false
	await step(3)
	zombie.take_damage(150, Vector3.RIGHT)
	await step(22)
	check(zombie.is_enraged and zombie.get_walk_speed() == 1.5 and zombie.scale.is_equal_approx(Vector3.ONE), "Custom pause/multiplier or physical unit scale failed.")
	var scaled_paper: ZombieDebris
	for part: ZombieDebris in zombie._spawned_debris:
		if part.part_kind == &"newspaper": scaled_paper = part
	check(scaled_paper != null and absf(scaled_paper.get_node("CollisionShape3D").shape.size.y - 0.99) < 0.001 and scaled_paper.scale.is_equal_approx(Vector3.ONE), "Configured paper size did not reach its detached collider.")
	main.queue_free()
	await step(2)
	if not failed:
		print("PASS: 350-HP reading model, exact 200-HP paper threshold, one stationary 1s outburst, 0.5-to-1.0 movement and ice, real pea collision, physical paper TTL, lethal/in-outburst death, fresh respawn/inspection/reset, custom geometry/configuration and 90s five-lane combat with controlled travel bounds and 18 hits per newspaper.")
	quit(1 if failed else 0)
