extends SceneTree
## Render the real menu, level selector, boards and result screens.

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


func _run() -> void:
	AdventureProgress.current().memory_only = true
	AdventureProgress.current().completed_level = 0
	var app := load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(app)
	await _capture("main_menu.png")
	app.show_levels()
	await _capture("level_select.png")
	for number in range(1, 5):
		app.start_level(number, true)
		var board := app.content as AdventureBoard
		board.set_physics_process(false)
		board._dave.set_physics_process(false)
		board.sun_value = 1200
		for row in board.active_rows:
			board.cooldowns.clear()
			board.plant_at("peashooter", Vector2i(2, row))
			if number > 1:
				board.plant_at("sunflower", Vector2i(0, row))
			if number == 4:
				board.plant_at("wall_nut", Vector2i(5, row))
		var enemy := board.spawn_enemy("conehead_zombie" if number >= 3 else "zombie", board.active_rows[0])
		enemy.global_position.x -= 4
		enemy.set_physics_process(false)
		board.sun_value = 125
		board.spawn_plant_sun(board.lawn.cell_to_world(board.active_rows[0], 1), 25)
		await _capture("adventure_1_%d.png" % number)
		if number == 4:
			board.cooldowns.clear()
			board._dave.global_position = board.lawn.cell_to_world(2, 2) + Vector3(0.6, 0, 1.6)
			board._camera.look_at(board.lawn.cell_to_world(2, 4))
			board.open_plant_picker()
			await _capture("adventure_plant_picker.png")
			board.select_plant("peashooter")
			board._dave.global_position = board.lawn.cell_to_world(2, 2) + Vector3(0.6, 0, 1.6)
			board._camera.look_at(board.lawn.cell_to_world(2, 4))
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			board.set_process(false)
			board._update_placement_preview(root.get_visible_rect().get_center())
			board._update_interface()
			board._crosshair.show()
			await _capture("adventure_1_4.png")
			board.set_paused(true)
			await _capture("adventure_pause.png")
			board.set_paused(false)
			AdventureProgress.current().completed_level = 3
			board._finish(true)
			await _capture("adventure_victory.png")
	AdventureProgress.current().completed_level = 4
	app.start_level(4, true)
	var board := app.content as AdventureBoard
	board.set_physics_process(false)
	board._dave.set_physics_process(false)
	board.sun_value = 500
	board.plant_at("wall_nut", Vector2i(1, 2))
	board._dave.global_position = board.lawn.cell_to_world(2, 0) + Vector3(0, 0, 1.2)
	board._camera.look_at(board.lawn.cell_to_world(2, 1) + Vector3.UP * 0.35)
	board.select_plant("shovel")
	await _capture("adventure_shovel.png")
	board.select_plant("")
	board._dave.set_first_person_active(false)
	var inspection := Camera3D.new()
	inspection.cull_mask = 3
	board.add_child(inspection)
	inspection.global_position = board._dave.global_position + Vector3(-2.4, 1.65, 2.8)
	inspection.look_at(board._dave.global_position + Vector3.UP * 0.9)
	inspection.make_current()
	await _capture("adventure_stowed_shovel.png")
	app.queue_free()
	for frame in 10:
		await process_frame
		await RenderingServer.frame_post_draw
	quit()
