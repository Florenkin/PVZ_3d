extends SceneTree
## Every level entry, real special-mode hits, night rules, rewards and old saves.

var _failed: bool = false
var _app: GameApplication


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	if not value:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for frame in frames:
		await physics_frame
	await process_frame


func _mouse(button: MouseButton, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.pressed = true
	root.push_input(event, true)
	await _step(2)
	event = InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	root.push_input(event, true)
	await _step(2)


func _aim(board: AdventureBoard, at: Vector3) -> Vector2:
	board._dave.global_position = Vector3(at.x - 2.4, board.lawn.surface_height, at.z)
	board._dave.rotation.y = -PI * 0.5
	board._dave.waist_mount.rotation.x = -atan2(board._camera.global_position.y - at.y, 2.4)
	board._camera.rotation = Vector3.ZERO
	board._dave.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return root.get_visible_rect().get_center()


func _board(number: int) -> AdventureBoard:
	_app.start_level(number)
	var board := _app.content as AdventureBoard
	board._wave_remaining = 999
	return board


func _run() -> void:
	var config := GameConfiguration.current()
	config.emit_warnings = false
	var fixture := config.default_values()
	fixture.adventure.conveyor_capacity = 17
	fixture.adventure.whack_damage = 12.5
	fixture.adventure.crater_lifetime = -1.0
	fixture.adventure.card_cooldowns.doom_shroom = 0.0
	config.use_values_for_tests(fixture)
	_check(config.warnings.size() == 4 and config.values.adventure == config.default_values().adventure, "Invalid stock capacity, fractional damage, negative crater time and zero cooldown must individually fall back.")
	fixture = config.default_values()
	fixture.adventure.conveyor_capacity = 1
	fixture.adventure.whack_damage = 600
	fixture.adventure.grave_eat_time = 2.0
	config.use_values_for_tests(fixture)
	_check(config.warnings.is_empty() and config.values.adventure.conveyor_capacity == 1 and config.values.adventure.whack_damage == 600 and config.values.adventure.grave_eat_time == 2.0, "Valid special-mode configuration must be accepted.")
	config.use_values_for_tests(config.default_values())
	var profile := AdventureProgress.current()
	profile.memory_only = true
	profile.completed_level = 20
	_app = load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(_app)
	await _step(2)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	_check(AdventureLevels.parse_code("2-10") == 20 and AdventureLevels.parse_code("1-5") == 5 and AdventureLevels.parse_code("3-1") == 21 and AdventureLevels.parse_code("51") == 0, "Command-line level codes must stay inside implemented levels.")
	var random := RandomNumberGenerator.new()
	random.seed = 9345
	for number in range(1, 21):
		var board := _board(number)
		await _step(2)
		_check(board.level_number == number and board.stage_number == AdventureLevels.area(number) and root.get_camera_3d() == board._dave.camera, "Every entry must load its own level with Dave's perspective camera.")
		_check(board.available_plants() == AdventureLevels.plants(number), "Each level must provide exactly its unlocked plants or special supply.")
		for index in AdventureLevels.WAVE_COUNTS[number - 1]:
			for kind: String in AdventureLevels.wave(number, index, random):
				_check(kind in AdventureLevels.ENEMIES[number - 1] or kind == "flag_zombie", "A wave must never introduce a zombie outside its level roster.")
		for kind: String in AdventureLevels.ENEMIES[number - 1]:
			var enemy := board.spawn_enemy(kind, 2)
			var stats := config.section("stages.zombies." + kind)
			_check(enemy is AdventureZombie and enemy.health == int(stats.body_health + stats.helmet_health + stats.shield_health), "Adventure zombies must use their real armor/body configuration.")
			if kind == "buckethead_zombie":
				_check(enemy.get_node("Visuals/Head/Bucket").visible, "Adventure buckets must retain their authored model.")
			elif kind == "pole_vaulting_zombie":
				_check(enemy.has_node("Visuals/Pole"), "Adventure pole-vaulters must use the pole model.")
			elif kind == "newspaper_zombie":
				_check(enemy.has_node("Visuals/Newspaper"), "Adventure newspaper zombies must use the newspaper model.")
		board.select_plant("")
		board.open_plant_picker()
		_check(board._cards.size() == board.available_plants().size() and paused, "The paused picker must accommodate every plant, including more than nine.")
		board.select_plant("")
	_check(not "snow_pea" in AdventureLevels.plants(6) and "snow_pea" in AdventureLevels.plants(7) and "puff_shroom" in AdventureLevels.plants(11) and not "lily_pad" in AdventureLevels.plants(19), "Rewards must become usable after their corresponding victory.")
	# Bowling uses real swept projectile collisions and spends only actual stock.
	var board := _board(5)
	var sky := (board.get_node("WorldEnvironment") as WorldEnvironment).environment.sky.sky_material as ProceduralSkyMaterial
	_check(sky.sky_top_color.is_equal_approx(config.color(config.section("environment").sky_top_color)), "Returning from night to day must reset the shared sky resource.")
	board.supply = ["bowling_nut", "explosive_nut"]
	_check(not board.plant_at("bowling_nut", Vector2i(3, 2)) and board.supply.size() == 2, "Bowling must reject throws beyond the red line without consuming a card.")
	var normal := board.spawn_enemy("zombie", 2)
	normal.global_position = board.lawn.cell_to_world(2, 4)
	normal.set_physics_process(false)
	var cone := board.spawn_enemy("conehead_zombie", 3)
	cone.global_position = board.lawn.cell_to_world(3, 5)
	cone.set_physics_process(false)
	_check(board.plant_at("bowling_nut", Vector2i(1, 2)) and board.sun_value == 0 and board.cooldowns.is_empty(), "Bowling must throw without sun or cooldown.")
	await _step(90)
	_check(not is_instance_valid(normal) and cone.health == 240, "A real normal nut must kill a plain zombie, ricochet and deal one 400-HP hit to the next cone.")
	normal = board.spawn_enemy("zombie", 4)
	normal.global_position = board.lawn.cell_to_world(4, 5)
	normal.set_physics_process(false)
	_check(board.plant_at("explosive_nut", Vector2i(1, 3)), "An actual explosive card must launch a red nut.")
	await _step(90)
	_check(not is_instance_valid(cone) and not is_instance_valid(normal), "Red nuts must explode on contact and damage neighboring lanes.")
	board = _board(9)
	board.sun_value = 200
	board.plant_at("repeater", Vector2i(2, 2))
	var repeater := board._occupied[Vector2i(2, 2)] as AdventurePlant
	normal = board.spawn_enemy("zombie", 2)
	normal.global_position = board.lawn.cell_to_world(2, 5)
	repeater._fire([normal])
	normal.receive_hit(normal.maximum_health, Vector3.RIGHT, true)
	await _step(15)
	_check(repeater._burst.is_empty(), "A Repeater's pending second shot must safely discard a freed adventure target.")
	# Both conveyor rosters, cancellation, rejection, refill, capacity and pause.
	for number in [10, 20]:
		board = _board(number)
		var initial := board.supply.duplicate()
		board.select_plant(board.supply[0])
		board.select_plant("")
		_check(board.supply == initial, "Canceling a supply selection must return the unspent card.")
		var kind: String = board.supply[0]
		_check(board.plant_at(kind, Vector2i(0, 2)) and board.supply.size() == initial.size() - 1 and board.sun_value == 0 and board.cooldowns.is_empty(), "A conveyor planting must consume exactly one card without sun or cooldown.")
		var remaining := board.supply.duplicate()
		_check(not board.plant_at(kind, Vector2i(0, 2)) and board.supply == remaining, "An occupied conveyor planting must not consume stock.")
		board.open_plant_picker()
		var timer := board._supply_remaining
		await _step(270)
		_check(board.supply == remaining and board._supply_remaining == timer, "Selection must freeze conveyor production.")
		board.select_plant("")
		await _step(245)
		_check(board.supply.size() == remaining.size() + 1, "Real time must refill the conveyor after resuming.")
		for frame in 20:
			board._update_supply(4.0)
		_check(board.supply.size() == int(board.settings.conveyor_capacity), "Conveyor stock must be bounded by its configured capacity.")
	# Night economy: no sky sun, awake free mushrooms and real plant production.
	board = _board(11)
	await _step(300)
	_check(board._suns.get_child_count() == 0 and board._sun_count == 0 and not board._graves.is_empty(), "Night must have graves and no sky sun.")
	_check(board.plant_at("puff_shroom", Vector2i(4, 2)) and board.sun_value == 50 and not (board._occupied[Vector2i(4, 2)] as AdventurePlant).sleeping, "Night puff-shrooms must be free and awake.")
	_check(board.plant_at("sunflower", Vector2i(0, 2)), "Unlocked sunflowers must remain available at night.")
	await _step(365)
	_check(board._suns.get_child_count() == 1, "Night income must come from actual plants.")
	board = _board(12)
	board.plant_at("sun_shroom", Vector2i(0, 2))
	var mushroom := board._occupied[Vector2i(0, 2)] as AdventurePlant
	mushroom._production_timer = 0.01
	await _step(2)
	_check((board._suns.get_child(0) as SunPickup).value == 15, "Young sun-shrooms must produce 15 sun.")
	mushroom._age = 120.0
	mushroom._production_timer = 0.01
	await _step(2)
	_check((board._suns.get_child(1) as SunPickup).value == 25 and mushroom._visuals.scale == Vector3.ONE, "Mature sun-shrooms must grow and produce 25 sun.")
	# Real piercing spores hit several bodies behind a shield and pass friendly zombies.
	board = _board(13)
	board.sun_value = 1000
	board.plant_at("fume_shroom", Vector2i(2, 2))
	var fume := board._occupied[Vector2i(2, 2)] as AdventurePlant
	fume.set_physics_process(false)
	var friendly := board.spawn_enemy("zombie", 2)
	friendly.global_position = board.lawn.cell_to_world(2, 3)
	friendly.hypnotize()
	friendly.set_physics_process(false)
	var door := board.spawn_enemy("screen_door_zombie", 2)
	door.global_position = board.lawn.cell_to_world(2, 4)
	door.set_physics_process(false)
	normal = board.spawn_enemy("zombie", 2)
	normal.global_position = board.lawn.cell_to_world(2, 5)
	normal.set_physics_process(false)
	await _step(2)
	fume._fire([door, normal])
	await _step(100)
	_check(friendly.health == 270 and door.body_health == 250 and door.shield_health == 1100 and normal.health == 250, "A physical fume projectile must spare allies, bypass the door shield and pierce two enemy bodies.")
	# Exact grave placement and removal; remaining graves spawn only in the final wave.
	board = _board(14)
	board.sun_value = 1000
	var cell := board.grave_cells()[0]
	_check(not board.plant_at("peashooter", cell) and not board.plant_at("grave_buster", Vector2i(0, 2)) and board.sun_value == 1000, "Graves must block ordinary plants and grave-busters must require an exact grave.")
	board.select_plant("grave_buster")
	var center := _aim(board, board.lawn.cell_to_world(cell.y, cell.x) + Vector3.UP * 0.5)
	_check(board.cell_at_screen(center) == cell, "A first-person ray hitting a grave must resolve its cell.")
	await _mouse(MOUSE_BUTTON_LEFT, center)
	_check(board._occupied.has(cell) and board.sun_value == 925, "A real grave click must plant the grave-buster and charge 75 sun.")
	await _step(245)
	_check(not board._graves.has(cell) and not board._occupied.has(cell), "Grave-busters must remove only their own grave after four seconds and consume themselves.")
	board.wave_index = AdventureLevels.WAVE_COUNTS[13] - 1
	board._dispatch_wave()
	_check(board.live_enemies().size() == board._graves.size(), "Only remaining graves must immediately release enemies in the final wave.")
	# Mine arming, instantaneous mushrooms and persistent craters.
	board = _board(6)
	board.plant_at("potato_mine", Vector2i(2, 2))
	var mine := board._occupied[Vector2i(2, 2)] as AdventurePlant
	normal = board.spawn_enemy("zombie", 2)
	normal.global_position = mine.global_position + Vector3.RIGHT * 0.7
	normal.set_physics_process(false)
	await _step(301)
	_check(normal.health == 270 and board._occupied.has(Vector2i(2, 2)), "An unarmed mine must not explode early.")
	await _step(610)
	_check(not is_instance_valid(normal) and not board._occupied.has(Vector2i(2, 2)), "A mine must arm after fifteen seconds and explode on contact.")
	board = _board(19)
	board.sun_value = 1000
	cone = board.spawn_enemy("conehead_zombie", 4)
	cone.global_position = board.lawn.cell_to_world(4, 8)
	board.plant_at("ice_shroom", Vector2i(1, 2))
	await _step(65)
	_check(cone.health == 620 and cone._freeze_remaining > 3.0 and cone._slow_remaining > 19.0, "Planted ice-shrooms must detonate without a nearby target and control the whole lawn.")
	normal = board.spawn_enemy("zombie", 2)
	normal.global_position = board.lawn.cell_to_world(2, 5)
	board.plant_at("doom_shroom", Vector2i(4, 2))
	await _step(65)
	_check(not is_instance_valid(normal) and board._craters.has(Vector2i(4, 2)), "Doom-shrooms must explode over a large area and leave a real crater.")
	_check(not board.plant_at("peashooter", Vector2i(4, 2)), "A crater must reject planting.")
	board.open_plant_picker()
	var life: float = board._craters[Vector2i(4, 2)]
	await _step(60)
	_check(board._craters[Vector2i(4, 2)] == life, "A crater's recovery timer must freeze while choosing a plant.")
	board.select_plant("")
	board._craters[Vector2i(4, 2)] = 0.02
	await _step(3)
	_check(board.plant_at("peashooter", Vector2i(4, 2)), "The same cell must become plantable after crater recovery.")
	# Hypnosis requires a bite, and both factions fight rather than crossing through.
	board = _board(16)
	board.sun_value = 500
	board.plant_at("hypno_shroom", Vector2i(3, 2))
	var football := board.spawn_enemy("football_zombie", 2)
	football.global_position = board.lawn.cell_to_world(2, 3) + Vector3.RIGHT * 0.7
	await _step(2)
	_check(football.hypnotized and not board._occupied.has(Vector2i(3, 2)), "A football zombie eating a hypno-shroom must switch sides and consume it.")
	normal = board.spawn_enemy("zombie", 2)
	normal.global_position = football.global_position + Vector3.RIGHT * 0.7
	var health := football.health
	await _step(60)
	_check(normal.health < 270 and football.health < health, "A hypnotized zombie and a hostile zombie must damage each other.")
	football.global_position.x = board.lawn.cell_to_world(2, 0).x - 2.2
	await _step(2)
	_check(board.state == AdventureBoard.State.PLAYING and not (board._mowers[2] as AdventureMower).spent, "Friendly zombies must not trigger mowers or defeat Dave.")
	# Four individually replenished dancing slots, all inheriting hypnosis.
	board = _board(18)
	var dancer := board.spawn_enemy("dancing_zombie", 2) as AdventureZombie
	dancer.global_position = board.lawn.cell_to_world(2, 6)
	dancer._ability_remaining = 0.01
	await _step(2)
	_check(dancer._dancer_slots.size() == 4 and board.live_enemies().size() == 5, "A dancing zombie must summon four directions within the lawn.")
	var backup := dancer._dancer_slots[0] as StageZombie
	var old_id := backup.get_instance_id()
	backup.receive_hit(backup.maximum_health, Vector3.RIGHT, true)
	await _step(2)
	dancer._ability_remaining = 0.01
	await _step(2)
	_check((dancer._dancer_slots[0] as StageZombie).get_instance_id() != old_id and board.live_enemies().size() == 5, "A dancer must replace one missing companion while preserving the other three.")
	dancer.hypnotize()
	_check(board.hostile_enemies().is_empty(), "Hypnotizing a dancing zombie must also turn its companions friendly.")
	# Hammer hits use actual input and occlusion, with armor-dependent hit counts.
	board = _board(15)
	_check(board.selected_kind == "hammer" and is_instance_valid(board._hand.held_plant), "Whack-a-zombie must start with a visible right-hand hammer.")
	for kind: String in ["zombie", "conehead_zombie", "buckethead_zombie"]:
		var enemy := board.spawn_enemy(kind, 2)
		enemy.global_position = board.lawn.cell_to_world(2, 3)
		enemy.set_physics_process(false)
		center = _aim(board, enemy.global_position + Vector3.UP * 1.25)
		await _step(2)
		var hits := ceili(enemy.health / float(board.settings.whack_damage))
		for hit in hits:
			await _mouse(MOUSE_BUTTON_LEFT, center)
		_check(not is_instance_valid(enemy), "The hammer must defeat each zombie through real left clicks and its actual armor.")
	_check(board.kills == 3 and board._suns.get_child_count() == 3, "Whack kills must generate their configured collectible sun reward.")
	normal = board.spawn_enemy("zombie", 2)
	normal.global_position = board.lawn.cell_to_world(2, 3)
	normal.set_physics_process(false)
	center = _aim(board, normal.global_position + Vector3.UP * 1.25)
	var barrier := StaticBody3D.new()
	barrier.collision_layer = 1
	var barrier_shape := CollisionShape3D.new()
	var barrier_box := BoxShape3D.new()
	barrier_box.size = Vector3(0.3, 3, 1)
	barrier_shape.shape = barrier_box
	barrier.add_child(barrier_shape)
	board.add_child(barrier)
	barrier.global_position = normal.global_position + Vector3(-1.2, 1.5, 0)
	await _step(2)
	await _mouse(MOUSE_BUTTON_LEFT, center)
	_check(normal.health == 270, "A hammer click must not hit a zombie through a world obstacle.")
	barrier.queue_free()
	await _step(2)
	await _mouse(MOUSE_BUTTON_LEFT, center)
	_check(not is_instance_valid(normal), "The same hammer aim must hit after removing the obstacle.")
	# Progress remains version 1, supports old four-level saves and stops at 2-10.
	profile.completed_level = 0
	for number in range(1, 21):
		profile.complete(number)
		_check(profile.completed_level == number and profile.unlocked_level() == 50 and profile.recommended_level() == number + 1, "Every sequential victory must update the recommendation without restricting selection.")
	profile.complete(51)
	_check(profile.completed_level == 20 and profile.can_play(21) and profile.can_play(50) and not profile.can_play(51), "Every supported level must stay selectable while invalid completion is rejected.")
	var path := "user://adventure_expansion_test_progress.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":1,"completed_level":4}')
	file.close()
	profile.load_progress(path)
	_check(profile.completed_level == 4 and profile.can_play(5), "An old save completing 1-4 must directly continue with 1-5.")
	profile.completed_level = 20
	_check(profile.save_progress(path) == OK, "Expanded progress must save without changing the format.")
	profile.load_progress(path)
	_check(profile.completed_level == 20, "2-10 progress must survive reload.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_app.show_almanac()
	await _step(2)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	_check(_app.current_mode == "almanac" and not paused, "The 2-4 almanac reward must expose a usable page.")
	_app.show_levels(2)
	await _step(2)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	_check((_app._canvas.find_children("Level20Button", "Button", true, false)[0] as Button).disabled == false, "The night page must expose the unlocked 2-10 button.")
	fixture = config.default_values()
	fixture.display.window_width = 960
	fixture.display.window_height = 600
	fixture.display.viewport_width = 960
	fixture.display.viewport_height = 600
	config.use_values_for_tests(fixture)
	_app.show_main_menu()
	await _step(3)
	var almanac_button := _app._canvas.find_children("AlmanacButton", "Button", true, false)[0] as Button
	_check(root.get_visible_rect().encloses(almanac_button.get_global_rect()), "The actual almanac button must remain fully visible with a 960x600 viewport.")
	await _mouse(MOUSE_BUTTON_LEFT, almanac_button.get_global_rect().get_center())
	_check(_app.current_mode == "almanac", "A real main-menu click must open the awarded almanac.")
	_app.queue_free()
	await _step(6)
	if DisplayServer.get_name() != "headless":
		for frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
	print("Adventure expansion integration: ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
