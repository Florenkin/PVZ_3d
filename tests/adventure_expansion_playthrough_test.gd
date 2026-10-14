extends SceneTree
## Continue a 1-4 save through 2-10 with real economy, stock, cooldown and combat.

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _count(board: AdventureBoard, row: int, kind: String) -> int:
	var count := 0
	for plant: StagePlant in board.live_plants():
		if plant.plant_kind == kind and board.lawn.world_to_cell(plant.global_position).y == row:
			count += 1
	return count


func _try_plant(board: AdventureBoard, row: int, kind: String, columns: Array[int], replace: bool = false) -> bool:
	if not kind in board.available_plants() or not board.seed_ready(kind):
		return false
	if not board.uses_supply() and board.sun_value < board.seed_cost(kind):
		return false
	for column in columns:
		var cell := Vector2i(column, row)
		var existing := board._occupied.get(cell) as AdventurePlant
		if is_instance_valid(existing) and (replace or (existing.plant_kind == "puff_shroom" and kind in ["fume_shroom", "repeater", "snow_pea"])):
			board.shovel_at(cell)
		if board.placement_error(kind, cell).is_empty():
			return board.plant_at(kind, cell)
	return false


func _defend(board: AdventureBoard, row: int, immediate: bool = false) -> bool:
	if board.stage_number == 2:
		if _count(board, row, "puff_shroom") < 2 and _try_plant(board, row, "puff_shroom", [4, 3, 2]):
			return true
		if _count(board, row, "fume_shroom") < (1 if immediate else 2) and _try_plant(board, row, "fume_shroom", [3, 2, 5, 4]):
			return true
	if _count(board, row, "peashooter") < 1 and _try_plant(board, row, "peashooter", [2, 3, 4]):
		return true
	if immediate:
		return false
	if _count(board, row, "snow_pea") < 1 and _try_plant(board, row, "snow_pea", [3, 2, 4, 5]):
		return true
	if _count(board, row, "repeater") < 2 and _try_plant(board, row, "repeater", [4, 5, 3, 2]):
		return true
	if _count(board, row, "peashooter") < 3 and _try_plant(board, row, "peashooter", [2, 3, 4, 5]):
		return true
	return false


func _tick_normal(board: AdventureBoard) -> void:
	var enemies := board.hostile_enemies()
	enemies.sort_custom(func(a: StageZombie, b: StageZombie) -> bool: return a.global_position.x < b.global_position.x)
	for enemy: StageZombie in enemies:
		var row := clampi(int(round(enemy.global_position.z / board.lawn.cell_size + 2)), 0, 4)
		var at := board.lawn.world_to_cell(enemy.global_position)
		if at.x >= 0 and at.x < 3:
			if _try_plant(board, row, "cherry_bomb", [at.x, maxi(0, at.x - 1), mini(8, at.x + 1)], true):
				return
		if _defend(board, row, true):
			return
		if enemy.global_position.x > board.lawn.cell_to_world(row, 7).x and _count(board, row, "potato_mine") == 0 and _try_plant(board, row, "potato_mine", [6, 5]):
			return
		if enemy.global_position.x < 6.0:
			if enemy.enemy_kind in ["football_zombie", "dancing_zombie"] and _try_plant(board, row, "hypno_shroom", [7, 6, 5]):
				return
			if _count(board, row, "wall_nut") == 0 and _try_plant(board, row, "wall_nut", [7, 6]):
				return
			if enemy.enemy_kind == "buckethead_zombie" and _count(board, row, "chomper") == 0 and _try_plant(board, row, "chomper", [6, 5]):
				return
		if enemy.enemy_kind == "buckethead_zombie" and _count(board, row, "snow_pea") == 0 and _try_plant(board, row, "snow_pea", [3, 2, 4, 5]):
			return
	var income := "sun_shroom" if "sun_shroom" in board.available_plants() else "sunflower"
	for desired in [1, 2]:
		for row in board.active_rows:
			if _count(board, row, income) < desired and _try_plant(board, row, income, [0, 1]):
				return
	var defense_rows: Array[int] = board.active_rows.duplicate()
	defense_rows.sort_custom(func(a: int, b: int) -> bool: return _count(board, a, "peashooter") + _count(board, a, "snow_pea") + _count(board, a, "repeater") + _count(board, a, "fume_shroom") < _count(board, b, "peashooter") + _count(board, b, "snow_pea") + _count(board, b, "repeater") + _count(board, b, "fume_shroom"))
	for row in defense_rows:
		if _defend(board, row):
			return
	for row in board.active_rows:
		if _count(board, row, "wall_nut") == 0 and _try_plant(board, row, "wall_nut", [7, 6]):
			return
		if _count(board, row, "chomper") == 0 and _try_plant(board, row, "chomper", [6, 5]):
			return
	# Once income and firepower exist, remove graves to prevent final-wave spawns.
	for cell: Vector2i in board.grave_cells():
		if board.placement_error("grave_buster", cell).is_empty() and board.plant_at("grave_buster", cell):
			return


func _tick_bowling(board: AdventureBoard) -> void:
	var enemies := board.hostile_enemies()
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a: StageZombie, b: StageZombie) -> bool: return a.global_position.x < b.global_position.x)
	var target := enemies[0]
	var row := clampi(int(round(target.global_position.z / board.lawn.cell_size + 2)), 0, 4)
	var kind := "explosive_nut" if board.supply.has("explosive_nut") else "bowling_nut"
	if board.supply.has(kind):
		board.plant_at(kind, Vector2i(0, row))


func _tick_conveyor(board: AdventureBoard) -> void:
	var enemies := board.hostile_enemies()
	enemies.sort_custom(func(a: StageZombie, b: StageZombie) -> bool: return a.global_position.x < b.global_position.x)
	var rows: Array[int] = []
	for enemy: StageZombie in enemies:
		var row := clampi(int(round(enemy.global_position.z / board.lawn.cell_size + 2)), 0, 4)
		if not row in rows:
			rows.append(row)
	for row in board.active_rows:
		if not row in rows:
			rows.append(row)
	for kind: String in board.supply.duplicate():
		if kind == "grave_buster":
			for cell: Vector2i in board.grave_cells():
				if board.plant_at(kind, cell):
					return
		elif kind in ["cherry_bomb", "doom_shroom", "ice_shroom"]:
			if not enemies.is_empty():
				var at := board.lawn.world_to_cell(enemies[0].global_position)
				if at.x >= 0:
					for column in [clampi(at.x, 0, 8), clampi(at.x - 1, 0, 8), clampi(at.x + 1, 0, 8)]:
						if _try_plant(board, at.y, kind, [column]):
							return
		else:
			for row in rows:
				var columns: Array[int] = [4, 3, 2, 1, 0, 5]
				if kind in ["wall_nut", "hypno_shroom", "chomper", "potato_mine"]:
					columns = [7, 6, 5, 8]
				if _try_plant(board, row, kind, columns):
					return


func _tick_whack(board: AdventureBoard) -> void:
	var enemies := board.hostile_enemies()
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a: StageZombie, b: StageZombie) -> bool: return a.global_position.x < b.global_position.x)
	board.select_plant("hammer")
	board._camera.look_at(enemies[0].global_position + Vector3.UP * 1.3)
	board.whack_at_screen(board.get_viewport().get_visible_rect().get_center())


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	var profile := AdventureProgress.current()
	profile.memory_only = true
	var first := 5
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--from="):
			first = maxi(5, AdventureLevels.parse_code(argument.trim_prefix("--from=")))
	profile.completed_level = first - 1
	var app := load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(app)
	await process_frame
	for number in range(first, 21):
		app.start_level(number)
		var board := app.content as AdventureBoard
		board._random.seed = 5000 + number
		board._row_cursor = number % 5
		var frames := 0
		while board.state == AdventureBoard.State.PLAYING and frames < 54000:
			if frames % 15 == 0:
				for sun: SunPickup in board._suns.get_children():
					if not sun.is_queued_for_deletion():
						sun.collect()
				match board.rules_mode:
					"bowling": _tick_bowling(board)
					"conveyor": _tick_conveyor(board)
					"whack": _tick_whack(board)
					_: _tick_normal(board)
			await physics_frame
			frames += 1
		var victory := board.state == AdventureBoard.State.WON and profile.completed_level == number and board.wave_index == AdventureLevels.WAVE_COUNTS[number - 1] and board._spawn_queue.is_empty() and board.hostile_enemies().is_empty()
		print("%s: %s, %.1f simulated seconds, wave %d/%d, %d kills, %d sun, %d stock, %d plants." % [AdventureLevels.code(number), "PASSED" if victory else "FAILED", frames / 60.0, board.wave_index, AdventureLevels.WAVE_COUNTS[number - 1], board.kills, board.sun_value, board.supply.size(), board.live_plants().size()])
		if not victory:
			for enemy: StageZombie in board.hostile_enemies():
				print("Remaining: ", enemy.enemy_kind, " HP=", enemy.health, " at=", enemy.global_position)
			print("Plants: ", board.live_plants().map(func(plant: StagePlant) -> String: return "%s@%s" % [plant.plant_kind, board.lawn.world_to_cell(plant.global_position)]))
			_failed = true
			push_error("Expanded adventure must be completable with actual resources and player actions: " + AdventureLevels.code(number))
			break
	app.queue_free()
	await process_frame
	print("Expanded adventure playthrough: ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
