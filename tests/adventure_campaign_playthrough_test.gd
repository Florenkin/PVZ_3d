extends SceneTree
## Play the remaining thirty levels with default economy, cooldowns and stock.

var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _row(game: AdventureBoard, enemy: StageZombie) -> int:
	return clampi(roundi((enemy.global_position.z - game.lawn.global_position.z) / game.lawn.cell_size + (game.lawn.row_count - 1) * 0.5), 0, game.lawn.row_count - 1)


func _count(game: AdventureBoard, row: int, kind: String) -> int:
	var total := 0
	for plant: StagePlant in game.live_plants():
		if plant.plant_kind == kind and game.lawn.world_to_cell(plant.global_position).y == row:
			total += 1
	return total


func _plant(game: AdventureBoard, row: int, kind: String, columns: Array, replace: bool = false) -> bool:
	if not kind in game.available_plants() or not game.seed_ready(kind):
		return false
	if not game.uses_supply() and game.sun_value < game.seed_cost(kind):
		return false
	if kind in StageCatalog.MUSHROOMS and not AdventureLevels.is_night(game.level_number):
		return false
	for column in columns:
		var cell := Vector2i(column, row)
		if game.world_rules.vases.has(cell) or (game.world_rules.ice.has(cell) and kind != "jalapeno") or game._craters.has(cell):
			continue
		var base := "flower_pot" if game.stage_number == 5 else ("lily_pad" if row in game.lawn.water_rows else "")
		if not base.is_empty() and kind != base and not kind in ["tangle_kelp", "sea_shroom"] and not game.world_rules.bases.has(cell):
			if not base in game.available_plants() or not game.seed_ready(base):
				continue
			if not game.uses_supply() and game.sun_value < game.seed_cost(kind) + game.seed_cost(base):
				continue
			if not game.plant_at(base, cell):
				continue
		var existing := game._occupied.get(cell) as AdventurePlant
		if is_instance_valid(existing) and (replace or (existing.plant_kind in ["puff_shroom", "sea_shroom", "peashooter"] and kind in ["fume_shroom", "repeater", "snow_pea", "cabbage_pult", "melon_pult"])):
			game.shovel_at(cell)
		if game.placement_error(kind, cell).is_empty():
			return game.plant_at(kind, cell)
	return false


func _defend(game: AdventureBoard, row: int, immediate: bool = false) -> bool:
	if game.stage_number == 5:
		if _count(game, row, "cabbage_pult") < (1 if immediate else 2) and _plant(game, row, "cabbage_pult", [2, 3, 4, 5, 6]):
			return true
		if not immediate:
			if _count(game, row, "melon_pult") < 2 and _plant(game, row, "melon_pult", [3, 4, 5, 2, 6]):
				return true
			if _count(game, row, "kernel_pult") < 1 and _plant(game, row, "kernel_pult", [4, 3, 5, 6]):
				return true
		return false
	if AdventureLevels.is_night(game.level_number):
		if row in game.lawn.water_rows and _count(game, row, "sea_shroom") < 2 and _plant(game, row, "sea_shroom", [4, 5, 6]):
			return true
		if _count(game, row, "puff_shroom") < 2 and _plant(game, row, "puff_shroom", [4, 3, 2]):
			return true
		if _count(game, row, "fume_shroom") < (1 if immediate else 2) and _plant(game, row, "fume_shroom", [3, 4, 2, 5]):
			return true
	if _count(game, row, "peashooter") < 1 and _plant(game, row, "peashooter", [2, 3, 4, 5]):
		return true
	if immediate:
		return false
	if _count(game, row, "snow_pea") < 1 and _plant(game, row, "snow_pea", [3, 4, 2, 5]):
		return true
	if _count(game, row, "repeater") < 2 and _plant(game, row, "repeater", [4, 5, 3, 2, 6]):
		return true
	if _count(game, row, "peashooter") < 2 and _plant(game, row, "peashooter", [2, 3, 4, 5, 6]):
		return true
	return false


func _normal(game: AdventureBoard) -> void:
	var enemies := game.hostile_enemies()
	enemies.sort_custom(func(a: StageZombie, b: StageZombie) -> bool: return a.global_position.x < b.global_position.x)
	# Reserve income for the air counter before spending on ordinary ground upgrades.
	for enemy: StageZombie in enemies:
		if enemy.is_flying():
			var row := _row(game, enemy)
			if _plant(game, row, "blover", [1, 2, 3, 0]):
				return
			if _count(game, row, "cactus") < 1:
				_plant(game, row, "cactus", [3, 2, 4, 5], true)
				return
	for enemy: StageZombie in enemies:
		if game.stage_number == 5 and enemy.enemy_kind == "pogo_zombie" and "tall_nut" in game.available_plants() and game.seed_ready("tall_nut"):
			var row := _row(game, enemy)
			if _count(game, row, "tall_nut") == 0:
				var column := game.lawn.world_to_cell(enemy.global_position).x
				column = 7 if column < 0 else maxi(0, mini(7, column - 1))
				_plant(game, row, "tall_nut", [column, maxi(0, column - 1)], true)
				return
	# Save for a lane counter when ice vehicles arrive, before buying upgrades.
	for enemy: StageZombie in enemies:
		if enemy.enemy_kind not in ["zomboni", "bobsled_team"] or enemy.global_position.x > game.lawn.cell_to_world(0, 7).x:
			continue
		var row := _row(game, enemy)
		if _count(game, row, "jalapeno") > 0 or _count(game, row, "squash") > 0:
			continue
		if enemy.enemy_kind == "zomboni" and _plant(game, row, "spikeweed", [7, 6, 5, 4], true):
			return
		if "jalapeno" in game.available_plants() and game.seed_ready("jalapeno"):
			_plant(game, row, "jalapeno", [1, 2, 3, 4, 0, 5, 6, 7, 8], true)
			return
	for enemy: StageZombie in enemies:
		var row := _row(game, enemy)
		if enemy.is_flying():
			if _plant(game, row, "blover", [1, 2, 3, 0]):
				return
			if _count(game, row, "cactus") < 2 and _plant(game, row, "cactus", [3, 2, 4, 5], true):
				return
		if _defend(game, row, true):
			return
		var at := game.lawn.world_to_cell(enemy.global_position)
		if enemy.global_position.x < game.lawn.cell_to_world(row, 3).x and at.x >= 0:
			for kind: String in ["doom_shroom", "cherry_bomb", "jalapeno", "squash"]:
				if _count(game, row, kind) > 0:
					continue
				if _plant(game, row, kind, [at.x, maxi(0, at.x - 1), mini(8, at.x + 1)], true):
					return
		if enemy.enemy_kind in ["football_zombie", "dancing_zombie"] and _plant(game, row, "hypno_shroom", [7, 6, 5]):
			return
		if enemy.enemy_kind in ["snorkel_zombie", "dolphin_rider", "ducky_tube_zombie"] and _plant(game, row, "tangle_kelp", [6, 7, 5, 8]):
			return
		if enemy.enemy_kind == "zomboni" and _plant(game, row, "spikeweed", [7, 6, 5, 8]):
			return
		if enemy.enemy_kind == "digger_zombie" and not enemy._underground and _plant(game, row, "squash", [0, 1, 2], true):
			return
	var income := "sun_shroom" if AdventureLevels.is_night(game.level_number) else "sunflower"
	for target in [1, 2]:
		for row in game.active_rows:
			if _count(game, row, income) < target and _plant(game, row, income, [0, 1]):
				return
	if "balloon_zombie" in AdventureLevels.ENEMIES[game.level_number - 1]:
		for row in game.active_rows:
			if not row in game.lawn.water_rows and _count(game, row, "cactus") == 0:
				if _plant(game, row, "cactus", [3, 2, 4, 5], true):
					return
				if game.sun_value < game.seed_cost("cactus"):
					return
	if game.stage_number == 5 and "umbrella_leaf" in game.available_plants():
		# Two overlapping nine-cell canopies protect all five income lanes.
		for row in [1, 3]:
			if not game.is_umbrella_protected(game.lawn.cell_to_world(row, 0)) and _plant(game, row, "umbrella_leaf", [1], true):
				return
	var defense_rows: Array[int] = game.active_rows.duplicate()
	if game.stage_number == 5:
		defense_rows.sort_custom(func(a: int, b: int) -> bool: return _count(game, a, "cabbage_pult") + _count(game, a, "kernel_pult") + _count(game, a, "melon_pult") < _count(game, b, "cabbage_pult") + _count(game, b, "kernel_pult") + _count(game, b, "melon_pult"))
	else:
		defense_rows.sort_custom(func(a: int, b: int) -> bool: return _count(game, a, "peashooter") + _count(game, a, "snow_pea") + _count(game, a, "repeater") + _count(game, a, "fume_shroom") + _count(game, a, "puff_shroom") + _count(game, a, "sea_shroom") < _count(game, b, "peashooter") + _count(game, b, "snow_pea") + _count(game, b, "repeater") + _count(game, b, "fume_shroom") + _count(game, b, "puff_shroom") + _count(game, b, "sea_shroom"))
	for row in defense_rows:
		if _defend(game, row):
			return
		if _count(game, row, "wall_nut") == 0 and _plant(game, row, "wall_nut", [7, 6]):
			return
		if _count(game, row, "chomper") == 0 and _plant(game, row, "chomper", [6, 5]):
			return


func _supply(game: AdventureBoard) -> void:
	var enemies := game.hostile_enemies()
	enemies.sort_custom(func(a: StageZombie, b: StageZombie) -> bool: return a.global_position.x < b.global_position.x)
	if game.rules_mode == "boss":
		for projectile: Node in game.projectiles.get_children():
			if projectile is AdventureBossBall and not projectile.is_queued_for_deletion():
				var kind := "ice_shroom" if projectile.fire else "jalapeno"
				var counter_rows: Array[int] = [projectile.row]
				if projectile.fire:
					for row in game.active_rows:
						if not row in counter_rows:
							counter_rows.append(row)
				for row in counter_rows:
					if _plant(game, row, kind, [0, 1, 2, 3, 4, 5, 6, 7, 8], true):
						return
		var boss := game.world_rules.boss
		for enemy: StageZombie in enemies:
			var reserve := 0 if enemy.enemy_kind == "zomboni" and enemy.global_position.x < game.lawn.cell_to_world(0, 2).x else 1
			if enemy.enemy_kind != "zomboss" and enemy.global_position.x < game.lawn.cell_to_world(0, 5).x and game.supply.count("jalapeno") > reserve and _count(game, _row(game, enemy), "jalapeno") == 0:
				if _plant(game, _row(game, enemy), "jalapeno", [1, 2, 3, 4, 0, 5, 6, 7, 8], true):
					return
		if is_instance_valid(boss) and boss.exposed:
			if game.supply.count("jalapeno") > 2 and _count(game, 2, "jalapeno") == 0 and _plant(game, 2, "jalapeno", [1, 2, 3, 4, 0, 5, 6, 7, 8], true):
				return
			if game.supply.count("ice_shroom") > 1 and boss._freeze_remaining < 0.3:
				for row in game.active_rows:
					if _plant(game, row, "ice_shroom", [1, 2, 3, 4, 0, 5, 6, 7, 8], true):
						return
	var rows: Array[int] = []
	for enemy: StageZombie in enemies:
		var row := _row(game, enemy)
		if not row in rows:
			rows.append(row)
	for row in game.active_rows:
		if not row in rows:
			rows.append(row)
	if game.rules_mode == "boss":
		# Distribute shooters across lanes so summons cannot exploit an empty lane.
		rows.sort_custom(func(a: int, b: int) -> bool: return _count(game, a, "cabbage_pult") + _count(game, a, "melon_pult") + _count(game, a, "kernel_pult") < _count(game, b, "cabbage_pult") + _count(game, b, "melon_pult") + _count(game, b, "kernel_pult"))
	for kind: String in game.supply.duplicate():
		if kind in ["ice_shroom", "jalapeno"] and game.rules_mode == "boss":
			continue
		if kind in ["cherry_bomb", "jalapeno", "squash"]:
			for enemy: StageZombie in enemies:
				if enemy.enemy_kind == "zomboss" or enemy.is_flying():
					continue
				var cell := game.lawn.world_to_cell(enemy.global_position)
				if cell.x >= 0 and _plant(game, cell.y, kind, [cell.x, maxi(0, cell.x - 1)], true):
					return
		elif kind in ["lily_pad", "flower_pot"]:
			for row in rows:
				if kind == "lily_pad" and not row in game.lawn.water_rows:
					continue
				if _plant(game, row, kind, [0, 1, 2, 3, 4, 5, 6, 7, 8] if game.rules_mode == "boss" else [3, 4, 2, 5, 1, 0, 6, 7, 8]):
					return
		else:
			for row in rows:
				if kind == "spikeweed" and row in game.lawn.water_rows:
					continue
				var columns: Array[int] = [4, 3, 2, 1, 0, 5, 6]
				if game.rules_mode == "boss":
					columns.assign([0, 1, 2, 3, 4, 5, 6, 7, 8])
				if kind in ["wall_nut", "tall_nut", "chomper", "hypno_shroom", "spikeweed", "tangle_kelp", "pumpkin"]:
					columns = [6, 7, 5, 8]
				if _plant(game, row, kind, columns):
					return


func _vases(game: AdventureBoard) -> void:
	if game.world_rules.waiting_group:
		game.world_rules.start_vase_group()
		return
	var enemies := game.hostile_enemies()
	enemies.sort_custom(func(a: StageZombie, b: StageZombie) -> bool: return a.global_position.x < b.global_position.x)
	var need_card := false
	for enemy: StageZombie in enemies:
		var cell := game.lawn.world_to_cell(enemy.global_position)
		var shooters := _count(game, cell.y, "peashooter") + _count(game, cell.y, "snow_pea")
		if _count(game, cell.y, "squash") > 0 or _count(game, cell.y, "hypno_shroom") > 0:
			continue
		var urgent := enemy.health > 500 or enemy.enemy_kind in ["dancing_zombie", "jack_in_the_box"] or cell.x < 3
		if urgent:
			for kind: String in ["squash", "hypno_shroom"]:
				if _plant(game, cell.y, kind, [maxi(0, cell.x - 1), cell.x], true):
					return
		need_card = need_card or shooters == 0 or enemy.health > 500
	var rows: Array[int] = game.active_rows.duplicate()
	rows.sort_custom(func(a: int, b: int) -> bool: return _count(game, a, "peashooter") + _count(game, a, "snow_pea") < _count(game, b, "peashooter") + _count(game, b, "snow_pea"))
	for enemy: StageZombie in enemies:
		var row := _row(game, enemy)
		if _count(game, row, "peashooter") + _count(game, row, "snow_pea") < 1:
			rows.erase(row)
			rows.push_front(row)
	for kind: String in ["snow_pea", "peashooter"]:
		for row in rows:
			if _plant(game, row, kind, [0, 1, 2, 3]):
				return
	var cells: Array = game.world_rules.vases.keys()
	# Only the visible green marker is inspected; hidden contents are never read.
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x)
	for cell: Vector2i in cells:
		if game.world_rules.vases[cell].green:
			game.world_rules.break_vase(cell)
			return
	if not cells.is_empty() and (enemies.is_empty() or need_card):
		game.world_rules.break_vase(cells[0])


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	var profile := AdventureProgress.current()
	profile.memory_only = true
	var first := 21
	var last := 50
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--from="):
			first = maxi(21, AdventureLevels.parse_code(argument.trim_prefix("--from=")))
		elif argument.begins_with("--until="):
			last = AdventureLevels.parse_code(argument.trim_prefix("--until="))
	profile.completed_level = first - 1
	var app := load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(app)
	await process_frame
	for number in range(first, last + 1):
		app.start_level(number)
		var game := app.content as AdventureBoard
		game._random.seed = 8000 + number
		game._row_cursor = number % game.active_rows.size()
		var frames := 0
		while (game.state == AdventureBoard.State.PLAYING or game.world_rules.waiting_group) and frames < 120000:
			if frames % 15 == 0:
				for sun: SunPickup in game._suns.get_children():
					if not sun.is_queued_for_deletion():
						sun.collect()
				if game.rules_mode == "vases":
					_vases(game)
				elif game.uses_supply():
					_supply(game)
				else:
					_normal(game)
			await physics_frame
			frames += 1
		var won := game.state == AdventureBoard.State.WON and profile.completed_level == number and game.hostile_enemies().is_empty() and game._spawn_queue.is_empty()
		print("%s: %s, %.1f seconds, %d kills, %d sun, %d plants." % [AdventureLevels.code(number), "PASSED" if won else "FAILED", frames / 60.0, game.kills, game.sun_value, game.live_plants().size()])
		if not won:
			print("Failure state: ", game.state, "; hint: ", game._hint_label.text, "; stock: ", game.supply, "; boss: ", game.world_rules.boss.health if is_instance_valid(game.world_rules.boss) else -1)
			for enemy: StageZombie in game.hostile_enemies():
				print("Remaining: ", enemy.enemy_kind, " HP=", enemy.health, " at=", enemy.global_position)
			print("Plants: ", game.live_plants().map(func(plant: StagePlant) -> String: return "%s@%s" % [plant.plant_kind, game.lawn.world_to_cell(plant.global_position)]))
			failed = true
			push_error("Late campaign must be completable using actual resources: " + AdventureLevels.code(number))
			break
	app.queue_free()
	await process_frame
	print("Campaign %s through %s playthrough: %s" % [AdventureLevels.code(first), AdventureLevels.code(last), "FAILED" if failed else "PASSED"])
	quit(1 if failed else 0)
