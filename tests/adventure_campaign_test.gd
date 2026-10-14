extends SceneTree
## Real scene, terrain, layering, special challenge and boss integration.

var failed: bool = false
var app: GameApplication


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)


func step(frames: int) -> void:
	for frame in frames:
		await physics_frame
	await process_frame


func board(number: int) -> AdventureBoard:
	app.start_level(number)
	var result := app.content as AdventureBoard
	result._wave_remaining = 9999
	result.sun_value = 10000
	return result


func aim(game: AdventureBoard, at: Vector3) -> Vector2:
	game._dave.global_position = at + Vector3(-2.4, -at.y + game.lawn.surface_at(at), 0)
	game._dave.velocity = Vector3.ZERO
	game._camera.look_at(at)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return root.get_visible_rect().get_center()


func click(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await step(2)
	event = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	root.push_input(event, true)
	await step(2)


func _run() -> void:
	var config := GameConfiguration.current()
	config.use_values_for_tests(config.default_values())
	AdventureProgress.current().memory_only = true
	AdventureProgress.current().completed_level = 50
	app = load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(app)
	await step(2)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	check(AdventureLevels.LEVEL_COUNT == 50 and AdventureLevels.parse_code("5-10") == 50 and AdventureLevels.parse_code("6-1") == 0, "The campaign must provide exactly five worlds and fifty entries.")
	var random := RandomNumberGenerator.new()
	random.seed = 30150
	for number in range(21, 51):
		var game := board(number)
		await step(2)
		check(game.level_number == number and game.lawn.row_count == (6 if number in range(21, 41) and number != 35 else 5), "Each late scene must load the correct six- or five-lane terrain.")
		check(game.lawn.water_rows.size() == (2 if StageCatalog.has_pool(game.stage_number) else 0), "Only the actual pool/fog terrain must contain water lanes.")
		check(root.get_camera_3d() == game._dave.camera, "Late stages must retain Dave's first-person camera.")
		for wave in AdventureLevels.WAVE_COUNTS[number - 1]:
			for kind: String in AdventureLevels.wave(number, wave, random):
				check(kind in AdventureLevels.ENEMIES[number - 1] or kind == "flag_zombie", "Late waves must respect their own roster.")
		game.select_plant("")
		game.open_plant_picker()
		check(game._cards.size() == game.available_plants().size() and paused, "All late cards must remain reachable in the paused picker.")
		game.select_plant("")
	var game := board(29)
	var cell := Vector2i(2, 2)
	check(not game.plant_at("peashooter", cell) and not game.plant_at("lily_pad", Vector2i(2, 0)), "Water needs a lily, and lilies must reject land without charging sun.")
	check(game.plant_at("lily_pad", cell) and game.plant_at("peashooter", cell), "A real lily and shooter must coexist in one water cell.")
	check(game.world_rules.bases.has(cell) and game._occupied.has(cell) and game.live_plants().size() == 2, "Both layers must be separate living plants.")
	var lily := game.world_rules.bases[cell] as AdventurePlant
	check(game.shovel_at(cell) and game.world_rules.bases.get(cell) == lily and not game._occupied.has(cell), "Shoveling the upper plant must preserve its lily.")
	game.cooldowns.clear()
	game.plant_at("wall_nut", cell)
	lily.take_damage(300)
	await step(2)
	check(not game._occupied.has(cell) and not game.world_rules.bases.has(cell), "Destroying a base must remove the upper plant.")
	var duck := game.spawn_enemy("buckethead_zombie", 3)
	check(duck.enemy_kind == "ducky_tube_zombie" and duck.helmet_health == 1100 and duck.health == 1370, "Water armor forms must retain the original bucket's real health.")
	var dolphin := game.spawn_enemy("dolphin_rider", 0)
	check(game.lawn.world_to_cell(dolphin.global_position + Vector3.LEFT * game.lawn.cell_size).y in game.lawn.water_rows, "Water-only zombies must be routed into valid water lanes.")
	game = board(24)
	cell = Vector2i(4, 2)
	check(game.plant_at("tangle_kelp", cell), "Kelp must be plantable directly in water without a lily.")
	var snorkel := game.spawn_enemy("snorkel_zombie", 2)
	snorkel.global_position = game.lawn.cell_to_world(2, 4) + Vector3.RIGHT * 0.6
	await step(100)
	check(not is_instance_valid(snorkel) and not game._occupied.has(cell), "Real kelp contact must consume both the submerged zombie and kelp.")
	game = board(47)
	cell = Vector2i(1, 2)
	game.plant_at("cabbage_pult", cell)
	game.plant_at("pumpkin", cell)
	var upper := game._occupied[cell] as AdventurePlant
	var shell := game.world_rules.shells[cell] as AdventurePlant
	var plain := game.spawn_enemy("zombie", 2)
	plain.global_position = upper.global_position + Vector3.RIGHT * 0.7
	await step(60)
	check(upper.health == 300 and shell.health < 4000, "Zombies must bite the pumpkin before the protected plant or pot.")
	check(not game.plant_at("peashooter", Vector2i(4, 0)) and game.plant_at("flower_pot", Vector2i(4, 0)), "Unseeded roof cells must require a real flower pot.")
	game.cooldowns.clear()
	game.plant_at("magnet_shroom", Vector2i(0, 0))
	var sleeping := game._occupied[Vector2i(0, 0)] as AdventurePlant
	check(sleeping.sleeping and not game.plant_at("coffee_bean", Vector2i(2, 0)), "Day mushrooms must sleep and coffee must reject a different empty cell.")
	game.plant_at("coffee_bean", Vector2i(0, 0))
	await step(100)
	check(not sleeping.sleeping and game._occupied[Vector2i(0, 0)] == sleeping, "Coffee must wake exactly the covered mushroom and preserve it.")
	var roof_point := game.lawn.cell_to_world(1, 4)
	var center := aim(game, roof_point)
	await step(2)
	check(game.cell_at_screen(center) == Vector2i(4, 1), "First-person roof picking must hit the actual sloped surface.")
	var arriving := game.spawn_enemy("zombie", 4)
	var arrival_x := arriving.global_position.x
	await step(240)
	check(arriving.global_position.x < arrival_x - 1 and arriving.global_position.y > 1.0, "A roof zombie must walk onto the high roof instead of falling outside and getting stuck at its edge.")
	game = board(27)
	game.add_ice(Vector2i(5, 0))
	check(not game.plant_at("peashooter", Vector2i(5, 0)), "Ice tracks must block planting.")
	game._create_plant("wall_nut", Vector2i(5, 0))
	check(not game.plant_at("jalapeno", Vector2i(5, 0)), "Chili on ice must still reject an occupied cell rather than orphaning the existing plant.")
	var sled := game.spawn_enemy("bobsled_team", 4)
	check(game.live_enemies().size() == 4 and game.lawn.world_to_cell(sled.global_position + Vector3.LEFT * game.lawn.cell_size).y == 0, "A sled must use an ice lane and spawn four independent members.")
	game.plant_at("jalapeno", Vector2i(2, 0))
	await step(65)
	check(game.world_rules.ice.is_empty() and game.hostile_enemies().is_empty(), "A real chili fuse must clear its lane and ice track.")
	game = board(25)
	game.supply.assign(["peashooter"])
	game.plant_at("peashooter", Vector2i(2, 0))
	plain = game.spawn_enemy("zombie", 0)
	plain.global_position = game.lawn.cell_to_world(0, 4)
	plain.set_physics_process(false)
	check(plain.health == 135 and plain.get_meta("mini", false), "Mini zombies must have reduced body health and a visibly scaled model.")
	await step(720)
	check(not is_instance_valid(plain), "Real low-fired peas must hit the miniature collider.")
	game = board(33)
	var balloon := game.spawn_enemy("balloon_zombie", 0)
	balloon.global_position = game.lawn.cell_to_world(0, 6) + Vector3.UP * 1.7
	game.plant_at("cactus", Vector2i(2, 0))
	await step(200)
	check(not balloon.is_flying(), "Actual cactus projectile collisions must bring a balloon down.")
	game = board(34)
	game.plant_at("plantern", Vector2i(4, 0))
	await step(2)
	var dark := 0
	for cloud: Node3D in game.world_rules.fog.get_children():
		if not cloud.visible:
			dark += 1
	check(dark > 0, "A real plantern must reveal nearby fog volumes.")
	game.plant_at("blover", Vector2i(2, 0))
	await step(65)
	check(not game.world_rules.fog.visible and game.world_rules.fog_clear_remaining > 24, "A blover must clear fog even without a flying target.")
	game.open_plant_picker()
	var clear_time := game.world_rules.fog_clear_remaining
	await step(60)
	check(game.world_rules.fog_clear_remaining == clear_time, "Fog recovery must freeze in the picker.")
	game.select_plant("")
	game = board(40)
	var rain := game.world_rules.get_node_or_null("StormRain") as CPUParticles3D
	check(rain != null and rain.emitting and rain.mesh != null, "Stormy night must contain actual falling rain particles.")
	game.open_plant_picker()
	check(not rain.can_process(), "Storm rain must pause while selecting a plant.")
	game.select_plant("")
	game.world_rules.storm_remaining = 0.01
	await step(2)
	check(game.world_rules.flash_remaining > 1.9 and not game.world_rules.fog.visible and game.world_rules.storm_light.light_energy > 2, "A storm flash must temporarily reveal and illuminate the whole field.")
	var flash_time := game.world_rules.flash_remaining
	game.open_plant_picker()
	await step(60)
	check(game.world_rules.flash_remaining == flash_time and not rain.can_process(), "The flash and rain must both freeze during plant selection.")
	game.select_plant("")
	await step(125)
	check(game.world_rules.fog.visible and is_equal_approx(game.world_rules.storm_light.light_energy, game.world_rules.storm_light_energy), "After a flash the fog and original night lighting must return.")
	game = board(47)
	var bungee := game.spawn_enemy("bungee_zombie", 0)
	game.plant_at("umbrella_leaf", Vector2i(0, 0))
	game.plant_at("sunflower", Vector2i(1, 0))
	await step(370)
	check(not is_instance_valid(bungee) and game._occupied.has(Vector2i(0, 0)), "An umbrella must block a finite bungee visit, which must then leave.")
	game = board(35)
	check(game.world_rules.vases.size() == 15 and game.lawn.row_count == 5 and game.lawn.water_rows.is_empty(), "4-5 must start its exact first vase group in the night front yard.")
	cell = game.world_rules.vases.keys()[0]
	var vase_at := game.lawn.cell_to_world(cell.y, cell.x) + Vector3.UP * 0.7
	center = aim(game, vase_at)
	await step(2)
	await click(center)
	check(game.world_rules.vases.size() == 14, "A real empty-hand left click must break one visible vase.")
	for group in range(1, 4):
		for vase_cell: Vector2i in game.world_rules.vases.keys():
			game.world_rules.break_vase(vase_cell)
		for enemy: StageZombie in game.hostile_enemies():
			enemy.receive_hit(enemy.maximum_health, Vector3.RIGHT, true, true)
		await step(2)
		if group < 3:
			check(game.world_rules.waiting_group and paused, "A cleared vase group must pause before the next group.")
			game.world_rules.start_vase_group()
			check(game.world_rules.vases.size() == (20 if group == 1 else 25), "Each following group must contain its original number of vases.")
			check(game.world_rules.vases.values().filter(func(item: Dictionary) -> bool: return item.green).size() == group + 1, "The second and third group must reveal exactly two and three green plant vases.")
	check(game.state == AdventureBoard.State.WON, "All three vase groups must complete the level.")
	game = board(50)
	var boss := game.world_rules.boss
	var health := boss.health
	boss.receive_hit(1000, Vector3.RIGHT)
	check(boss.health == health, "Closed boss armor must reject direct damage.")
	boss.exposed = true
	boss.head_remaining = 20
	game.supply.assign(["melon_pult", "ice_shroom", "jalapeno"])
	game.plant_at("melon_pult", Vector2i(0, 0))
	await step(270)
	check(boss.health < health, "Real lobbed melon projectiles must hit an exposed boss from a different lane.")
	var boss_mower := game._mowers[2] as AdventureMower
	boss_mower.global_position.x = boss.global_position.x - 1.5
	boss_mower.trigger()
	await step(15)
	check(is_instance_valid(boss) and boss.health > 30000, "A sweeping mower must not instantly defeat the exposed boss.")
	var fire := AdventureBossBall.new()
	fire.stage = game
	fire.row = 0
	fire.position = game.lawn.cell_to_local(0, 7)
	game.projectiles.add_child(fire)
	game.plant_at("ice_shroom", Vector2i(1, 0))
	await step(65)
	check(not is_instance_valid(fire) and boss._freeze_remaining > 3, "An actual ice-shroom must remove fireballs and freeze the boss.")
	var ice_ball := AdventureBossBall.new()
	ice_ball.stage = game
	ice_ball.fire = false
	ice_ball.row = 0
	ice_ball.position = game.lawn.cell_to_local(0, 7)
	game.projectiles.add_child(ice_ball)
	game.plant_at("jalapeno", Vector2i(2, 0))
	await step(65)
	check(not is_instance_valid(ice_ball), "An actual same-lane chili must remove an iceball.")
	AdventureProgress.current().completed_level = 49
	boss.exposed = true
	boss.receive_hit(boss.maximum_health, Vector3.RIGHT, true, true)
	await step(3)
	check(game.state == AdventureBoard.State.WON and AdventureProgress.current().completed_level == 50 and not AdventureProgress.current().can_play(51), "Defeating the boss must award the final trophy without creating level 51.")
	game = board(50)
	boss = game.world_rules.boss
	check(boss.health == 40000, "The boss must start with its complete forty-thousand HP body.")
	boss.attack_count = 2
	boss.attack_remaining = 0.01
	await step(2)
	check(game.projectiles.get_children().any(func(node: Node) -> bool: return node is AdventureBossBall and node.fire), "The real boss timer must launch a fireball in the first cycle.")
	boss.attack_count = 8
	boss.attack_remaining = 0.01
	await step(2)
	check(game.projectiles.get_children().any(func(node: Node) -> bool: return node is AdventureBossBall and not node.fire), "The next boss cycle must alternate to an iceball.")
	boss.attack_count = 3
	boss.attack_remaining = 0.01
	await step(2)
	check(game.hostile_enemies().filter(func(enemy: StageZombie) -> bool: return enemy.enemy_kind == "bungee_zombie").size() == 2, "A timed boss bungee attack must create two finite visitors.")
	for projectile: Node in game.projectiles.get_children():
		projectile.queue_free()
	await step(2)
	for row in game.active_rows:
		for column in range(3, 9):
			game._create_plant("flower_pot", Vector2i(column, row))
	var bases_before := game.world_rules.bases.size()
	boss.attack_count = 4
	boss.attack_remaining = 0.01
	await step(2)
	check(game.world_rules.bases.size() == bases_before - 2, "A timed stomp must clear exactly two front-row cells.")
	bases_before = game.world_rules.bases.size()
	boss.attack_count = 5
	boss.attack_remaining = 0.01
	await step(2)
	check(game.world_rules.bases.size() < bases_before and game._hint_label.text.contains("房车"), "A timed RV attack must actually clear a patch of the roof.")
	boss.attack_remaining = 0.01
	await step(2)
	check(game.hostile_enemies().size() > 3, "The boss must summon a real independent enemy after its RV cycle.")
	var path := "user://adventure_campaign_test.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":1,"completed_level":20}')
	file.close()
	AdventureProgress.current().load_progress(path)
	check(AdventureProgress.current().can_play(21), "An old 2-10 save must directly continue with 3-1.")
	AdventureProgress.current().completed_level = 50
	AdventureProgress.current().save_progress(path)
	AdventureProgress.current().load_progress(path)
	check(AdventureProgress.current().completed_level == 50, "The final fifty-level completion must survive saving and reloading.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	app.queue_free()
	await step(6)
	if DisplayServer.get_name() != "headless":
		for frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
	print("Full campaign integration: ", "FAILED" if failed else "PASSED")
	quit(1 if failed else 0)
