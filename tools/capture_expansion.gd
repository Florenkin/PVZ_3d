extends SceneTree
## Render actual adventure scenes; freeze fixtures without touching real progress.


func _initialize() -> void:
	_run.call_deferred()


func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://artifacts/" + filename)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("Saved " + path)


func _freeze(board: AdventureBoard) -> void:
	board.set_physics_process(false)
	board._dave.set_physics_process(false)
	board._dave.global_position = board.lawn.cell_to_world(2, 1) + Vector3(0.4, 0, 1.3)
	board._camera.look_at(board.lawn.cell_to_world(2, 4))
	for actor: Node in board._plants.get_children() + board._enemies.get_children():
		actor.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _run() -> void:
	GameConfiguration.current().use_values_for_tests(GameConfiguration.current().default_values())
	AdventureProgress.current().memory_only = true
	AdventureProgress.current().completed_level = 20
	var app := load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(app)
	await _capture("expanded_main_menu.png")
	app.show_levels(1)
	await _capture("adventure_day_levels.png")
	app.show_levels(2)
	await _capture("adventure_night_levels.png")
	app.start_level(5)
	var board := app.content as AdventureBoard
	var enemy := board.spawn_enemy("conehead_zombie", 2)
	enemy.global_position = board.lawn.cell_to_world(2, 6)
	board.plant_at("bowling_nut", Vector2i(2, 2))
	board.select_plant("explosive_nut")
	_freeze(board)
	board._dave.global_position = board.lawn.cell_to_world(2, 0) + Vector3(0.5, 0, 1.3)
	board._camera.look_at(board.lawn.cell_to_world(2, 3))
	await _capture("adventure_bowling.png")
	app.start_level(19)
	board = app.content as AdventureBoard
	board.sun_value = 1000
	for row in 5:
		board.cooldowns.clear()
		board.plant_at("fume_shroom", Vector2i(3, row))
		board.plant_at("sun_shroom", Vector2i(0, row))
	board.cooldowns.clear()
	enemy = board.spawn_enemy("dancing_zombie", 2)
	enemy.global_position = board.lawn.cell_to_world(2, 7)
	board.select_plant("ice_shroom")
	_freeze(board)
	await _capture("adventure_night.png")
	board.select_plant("")
	board.open_plant_picker()
	await _capture("adventure_night_picker.png")
	board.select_plant("")
	app.start_level(15)
	board = app.content as AdventureBoard
	enemy = board.spawn_enemy("buckethead_zombie", 2)
	enemy.global_position = board.lawn.cell_to_world(2, 5)
	_freeze(board)
	board._camera.look_at(enemy.global_position + Vector3.UP * 0.55)
	await _capture("adventure_whack.png")
	for number in [10, 20]:
		app.start_level(number)
		board = app.content as AdventureBoard
		for row in 5:
			var kind := "repeater" if number == 10 else "fume_shroom"
			board.supply.append(kind)
			board.plant_at(kind, Vector2i(3, row))
		board._update_supply(4.0)
		_freeze(board)
		await _capture("adventure_conveyor_%d.png" % number)
	app.show_almanac()
	await _capture("adventure_almanac.png")
	# Verify the actual minimum-size UI as well as the configured 1280x800 view.
	var fixture := GameConfiguration.current().default_values()
	fixture.display.window_width = 960
	fixture.display.window_height = 600
	fixture.display.viewport_width = 960
	fixture.display.viewport_height = 600
	GameConfiguration.current().use_values_for_tests(fixture)
	app.show_levels(2)
	await _capture("adventure_levels_small.png")
	app.start_level(19)
	board = app.content as AdventureBoard
	board.sun_value = 1000
	_freeze(board)
	root.size = Vector2i(960, 600)
	board.open_plant_picker()
	await _capture("adventure_picker_small.png")
	app.show_main_menu()
	await _capture("adventure_menu_small.png")
	app.show_almanac()
	await _capture("adventure_almanac_small.png")
	app.queue_free()
	for frame in 6:
		await process_frame
		await RenderingServer.frame_post_draw
	quit()
