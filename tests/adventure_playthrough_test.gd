extends SceneTree
## Play all four levels with real sun, costs, cooldowns, waves and combat.
## This bot invokes the same planting transaction as UI input; it grants no funds.

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	if not value:
		_failed = true
		push_error(message)


func _count(board: AdventureBoard, row: int, kind: String) -> int:
	var count := 0
	for plant: StagePlant in board.live_plants():
		if plant.plant_kind == kind and board.lawn.world_to_cell(plant.global_position).y == row:
			count += 1
	return count


func _try_plant(board: AdventureBoard, row: int, kind: String, columns: Array[int]) -> bool:
	var cost := int(GameConfiguration.current().section("stages.plants." + kind).sun_cost)
	if board.sun_value < cost or float(board.cooldowns.get(kind, 0)) > 0:
		return false
	for column in columns:
		if not board._occupied.has(Vector2i(column, row)):
			return board.plant_at(kind, Vector2i(column, row))
	return false


func _tick(board: AdventureBoard) -> void:
	for item: Node in board._suns.get_children():
		if item is SunPickup and not item.is_queued_for_deletion():
			item.collect()
	# Defend attacked rows first, then build income and cover remaining rows.
	for enemy: StageZombie in board.live_enemies():
		var row := board.lawn.world_to_cell(enemy.global_position).y
		if row < 0:
			row = clampi(int(round(enemy.global_position.z / board.lawn.cell_size + 2)), 0, 4)
		if _count(board, row, "peashooter") < 2 and _try_plant(board, row, "peashooter", [2, 3, 4]):
			return
	if board.level_number > 1:
		for row in board.active_rows:
			if _count(board, row, "sunflower") == 0 and _try_plant(board, row, "sunflower", [0, 1]):
				return
	for row in board.active_rows:
		if _count(board, row, "peashooter") == 0 and _try_plant(board, row, "peashooter", [2, 3, 4]):
			return
	if board.level_number > 1:
		for row in board.active_rows:
			if _count(board, row, "sunflower") < 2 and _try_plant(board, row, "sunflower", [0, 1]):
				return
	for row in board.active_rows:
		if _count(board, row, "peashooter") < 3 and _try_plant(board, row, "peashooter", [2, 3, 4]):
			return
	if board.level_number == 4:
		for row in board.active_rows:
			if _count(board, row, "wall_nut") == 0 and _try_plant(board, row, "wall_nut", [6]):
				return


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	var profile := AdventureProgress.current()
	profile.memory_only = true
	profile.completed_level = 0
	var app := load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(app)
	for number in range(1, 5):
		app.start_level(number)
		var board := app.content as AdventureBoard
		board._random.seed = 1000 + number
		var frames := 0
		while board.state == AdventureBoard.State.PLAYING and frames < 36000:
			if frames % 15 == 0:
				_tick(board)
			await physics_frame
			frames += 1
		_check(board.state == AdventureBoard.State.WON, "1-%d must be completable using real resources and normal planting rules." % number)
		_check(board.wave_index == AdventureLevels.WAVE_COUNTS[number - 1] and board.live_enemies().is_empty() and board._spawn_queue.is_empty(), "Victory must require all original-count waves and zombies to be cleared.")
		_check(profile.completed_level == number, "An actual victory must unlock the next level.")
		print("1-%d: %.1f simulated seconds, %d zombies defeated, %d sun remaining." % [number, frames / 60.0, board.kills, board.sun_value])
		if _failed:
			break
	app.queue_free()
	await process_frame
	print("Adventure playthrough: ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
