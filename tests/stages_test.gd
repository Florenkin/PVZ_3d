extends SceneTree
## Real scenes, physics, keyboard switching, cleanup, original stats and reset.

var _failed: bool = false
var _switcher: StageSwitcher


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _step(frames: int) -> void:
	for frame in frames:
		await physics_frame


func _quiet(demo: StageDemo) -> void:
	demo._dave.set_physics_process(false)
	demo._sun_system._timer.stop()
	for actor: Node in demo.get_node("Plants").get_children() + demo.get_node("Enemies").get_children():
		actor.set_physics_process(false)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	for frame in 3:
		await process_frame


func _enemy(demo: StageDemo, kind: String) -> StageZombie:
	for actor: StageZombie in demo.get_node("Enemies").get_children():
		if actor.enemy_kind == kind and not actor.get_meta("summoned", false):
			return actor
	return null


func _plant(demo: StageDemo, kind: String) -> StagePlant:
	for actor: StagePlant in demo.get_node("Plants").get_children():
		if actor.plant_kind == kind:
			return actor
	return null


func _run() -> void:
	var config := GameConfiguration.current()
	config.emit_warnings = false
	var defaults := config.default_values()
	var invalid := defaults.duplicate(true)
	invalid.stages.start_stage = 8
	invalid.stages.plant_columns = 6
	invalid.stages.board_columns = 9
	invalid.stages.plants.sunflower.attack_interval = 0
	invalid.stages.zombies.zombie.body_health = -1
	config.use_values_for_tests(invalid)
	_check(config.values.stages.start_stage == 1 and config.values.stages.board_columns == 13, "Invalid stage index and overlapping layout must fall back.")
	_check(config.values.stages.plants.sunflower.attack_interval == 24 and config.values.stages.zombies.zombie.body_health == 270, "Invalid stage stats must fall back.")
	config.use_values_for_tests(defaults)
	_switcher = load("res://scenes/adventure.tscn").instantiate() as StageSwitcher
	_switcher.stage_changed.connect(func(number: int) -> void:
		if number > 0:
			_quiet(_switcher.current_demo as StageDemo)
	)
	root.add_child(_switcher)
	var counts := [9, 17, 25, 33, 40]
	var enemy_counts := [5, 10, 12, 14, 17]
	var rows := [6, 6, 8, 10, 10]
	var previous: StageDemo
	for number in range(1, 6):
		await _key([KEY_1, KEY_2, KEY_3, KEY_4, KEY_5][number - 1])
		var demo := _switcher.current_demo as StageDemo
		_check(_switcher.current_stage == number and demo.stage_number == number, "Main-row digits must load the requested stage.")
		if previous != null:
			_check(not is_instance_valid(previous), "Outgoing stage must be freed after keyboard switching.")
		_quiet(demo)
		_check(demo._plant_slots.size() == counts[number - 1] and demo._enemy_slots.size() == enemy_counts[number - 1], "Stage rosters must match the requested cumulative unlocks and area enemies.")
		_check(demo.lawn.row_count == rows[number - 1] and demo.lawn.column_count == 13, "Board must expand with the cumulative roster.")
		_check(get_nodes_in_group("stage_plants").size() == counts[number - 1], "Switching must not retain old plants in scene groups.")
		_check(demo._sun_system.settings.enabled == not (number in [2, 4]) and demo._sun_system.settings.medium_value == 25, "Night stops sky sun; new stages use 25-point sun.")
		var occupied: Dictionary = {}
		for plant: StagePlant in demo.get_node("Plants").get_children():
			var cell := demo.lawn.world_to_cell(plant.global_position)
			_check(cell.x >= 1 and cell.x <= 4 and cell.y >= 0, "Plants must stay in the left planting area.")
			_check(not occupied.has(cell), "Plant showcase cells must be unique.")
			occupied[cell] = true
			if plant.plant_kind in StageCatalog.AQUATIC:
				_check((cell.y in demo.lawn.water_rows) if number in [3, 4] else plant.display_only, "Aquatic plants need water or an explicitly marked exhibit pond.")
			else:
				_check(not cell.y in demo.lawn.water_rows, "Land plants must stay off the pool.")
			_check(plant.sleeping == (plant.plant_kind in StageCatalog.MUSHROOMS and number in [1, 3, 5]), "Mushrooms must follow the stage day/night rule at start.")
		for enemy: StageZombie in demo.get_node("Enemies").get_children():
			var cell := demo.lawn.world_to_cell(enemy.global_position)
			_check(cell.x >= 10 and cell.y >= 0, "Stage zombies must start in the right area.")
			_check((cell.y in demo.lawn.water_rows) == (enemy.enemy_kind in StageCatalog.WATER_ENEMIES and number in [3, 4]), "Water enemies and land enemies need the correct rows.")
		if number == 3:
			_check(demo.live_enemies().filter(func(actor: StageZombie) -> bool: return actor.enemy_kind == "bobsled_team").size() == 4, "A bobsled team must contain four independently living members.")
		if number == 5:
			_check(demo.lawn.cell_to_local(0, 4).y > demo.lawn.cell_to_local(0, 0).y + 1.0, "Roof must have a real rising surface.")
		previous = demo
	await _key(KEY_KP_2)
	_check(_switcher.current_stage == 2, "Keypad must also switch stages.")
	var night := _switcher.current_demo as StageDemo
	_quiet(night)
	var door := _enemy(night, "screen_door_zombie")
	door.receive_hit(20, Vector3.RIGHT)
	_check(door.shield_health == 1080 and door.body_health == 270, "Ordinary shots must damage a screen door shield first.")
	door.receive_hit(40, Vector3.RIGHT, true)
	_check(door.shield_health == 1080 and door.body_health == 230, "Lobbed/piercing hits must bypass a screen door shield.")
	var paper := _enemy(night, "newspaper_zombie")
	paper.receive_hit(150, Vector3.RIGHT)
	_check(paper.shield_health == 0 and paper.body_health == 270 and paper._rage_remaining == 1.0, "Newspaper loss must trigger the one-second anger pause.")
	var bucket := _enemy(night, "buckethead_zombie")
	_check(bucket.health == 1370 and bucket.remove_metal() and bucket.health == 270, "Magnet must remove the 1100-HP bucket without damaging its body.")
	var ordinary := _enemy(night, "zombie")
	ordinary.apply_slow(0.5, 10.0)
	ordinary._physics_process(1.0)
	_check(is_equal_approx(ordinary._slow_remaining, 9.0), "Stage movement must advance slow timers exactly once.")
	var old_id := ordinary.get_instance_id()
	ordinary.receive_hit(1800, Vector3.RIGHT, true)
	_check(not night._pending.is_empty(), "Defeat must schedule an owned respawn.")
	await _step(65)
	ordinary = _enemy(night, "zombie")
	_check(ordinary.get_instance_id() != old_id and ordinary.health == 270, "Dead zombies must respawn as fresh instances with full original health.")
	var cone := _enemy(night, "conehead_zombie")
	cone.receive_hit(1800, Vector3.RIGHT, true)
	await _step(65)
	cone = _enemy(night, "conehead_zombie")
	_check(cone.has_cone and cone.get_node("Visuals/Head/Cone").visible, "A dynamically refreshed conehead must keep its visible armor.")
	_quiet(night)
	var pea := _plant(night, "peashooter")
	pea.take_damage(300)
	_check(not pea.is_alive(), "Zombies can consume stage plants.")
	night.effect(Vector3.ZERO, Color.ORANGE, 1.0)
	night.add_coins(10, Vector3.ZERO)
	night.spawn_plant_sun(pea.global_position, 25).collect()
	_check(night._sun_system.sun_value == 25, "Plant sun must credit the stage balance once.")
	await _key(KEY_R)
	_quiet(night)
	_check(night._pending.is_empty() and night.coins == 0 and night._sun_system.sun_value == 0 and _plant(night, "peashooter").health == 300, "R must cancel refreshes, restore actors and clear resources/effect tweens.")
	# Actual swept projectile collision in a quiet day scene.
	await _key(KEY_1)
	var day := _switcher.current_demo as StageDemo
	_quiet(day)
	ordinary = _enemy(day, "zombie")
	ordinary.global_position = day.lawn.cell_to_world(0, 7)
	await _step(2)
	var shot := StageProjectile.new()
	shot.stage = day
	shot.cold = true
	day.projectiles.add_child(shot)
	shot.global_position = ordinary.global_position + Vector3(-2, 1.05, 0)
	shot.set_start(shot.global_position)
	await _step(20)
	_check(ordinary.health == 250 and ordinary._slow_remaining > 9.0, "A real swept frost pea must deal 20 damage and apply ten-second slow.")
	var chomper := _plant(day, "chomper")
	ordinary.global_position = chomper.global_position + Vector3.RIGHT * 2.0
	chomper._physics_process(1.5)
	_check(not ordinary.is_alive() and chomper._digestion_remaining == 42.0, "A hungry Chomper must eat promptly, then digest for 42 seconds.")
	# Leave a pending death refresh and projectile behind, then switch repeatedly.
	ordinary.receive_hit(1800, Vector3.RIGHT, true)
	var old_demo_id := day.get_instance_id()
	await _key(KEY_5)
	_quiet(_switcher.current_demo as StageDemo)
	await _step(70)
	_check(not is_instance_id_valid(old_demo_id) and _switcher.current_demo.get_node("Projectiles").get_child_count() == 0, "Switch must dispose outgoing projectiles and pending refreshes.")
	for number in [1, 4, 2, 5, 3, 1]:
		_switcher.switch_stage(number)
		_quiet(_switcher.current_demo as StageDemo)
		await process_frame
		_check(get_nodes_in_group("stage_plants").size() == counts[number - 1], "Repeated switches must not accumulate actors.")
	await _key(KEY_0)
	_check(_switcher.current_stage == 0 and _switcher.current_demo.scene_file_path == "res://scenes/main.tscn", "0 must preserve access to the original demo.")
	await _key(KEY_KP_5)
	_check(_switcher.current_stage == 5, "Keypad switching must return from the legacy scene.")
	_switcher.queue_free()
	await process_frame
	print("Stages integration: ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
