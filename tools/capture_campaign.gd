extends SceneTree
## Actual Compatibility renders; fixtures never overwrite the player's save.


func _initialize() -> void:
	_run.call_deferred()


func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://artifacts/" + filename)
	root.get_texture().get_image().save_png(path)
	print("Saved ", path)


func freeze(game: AdventureBoard) -> void:
	game.set_physics_process(false)
	game._dave.set_physics_process(false)
	game._dave.global_position = game.lawn.cell_to_world(1, 0) + Vector3(0.3, 0.1, 0.8)
	game._camera.look_at(game.lawn.cell_to_world(2, 4))
	for actor: Node in game._plants.get_children() + game._enemies.get_children():
		actor.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _run() -> void:
	var config := GameConfiguration.current()
	config.use_values_for_tests(config.default_values())
	AdventureProgress.current().memory_only = true
	AdventureProgress.current().completed_level = 50
	var app := load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(app)
	await capture("campaign_menu.png")
	for world in [3, 4, 5]:
		app.show_levels(world)
		await capture("campaign_levels_%d.png" % world)
	for number in [29, 39, 35, 47, 50]:
		app.start_level(number)
		var game := app.content as AdventureBoard
		game.sun_value = 10000
		if number in [29, 39]:
			for row in game.active_rows:
				game.cooldowns.clear()
				if row in game.lawn.water_rows:
					game.plant_at("lily_pad", Vector2i(3, row))
				game.plant_at("repeater", Vector2i(3, row))
			game.cooldowns.clear()
			game.select_plant("lily_pad" if number == 29 else "pumpkin")
			if number == 39:
				game.plant_at("plantern", Vector2i(4, 0))
				game.select_plant("pumpkin")
		elif number == 47:
			for row in game.active_rows:
				game.cooldowns.clear()
				game.plant_at("cabbage_pult", Vector2i(2, row))
				game.plant_at("pumpkin", Vector2i(2, row))
			game.cooldowns.clear()
			game.select_plant("flower_pot")
		elif number == 50:
			game.supply.assign(["melon_pult", "cabbage_pult", "ice_shroom"])
			game.plant_at("melon_pult", Vector2i(2, 0))
			game.world_rules.boss.exposed = true
			game.select_plant("ice_shroom")
		freeze(game)
		if number == 35:
			game._camera.look_at(game.lawn.cell_to_world(2, 7) + Vector3.UP * 0.5)
		await capture("campaign_%d.png" % number)
		if number == 47:
			game.select_plant("")
			game.open_plant_picker()
			await capture("campaign_picker.png")
			game.select_plant("")
	app.start_level(40)
	var storm := app.content as AdventureBoard
	for frame in 120:
		await physics_frame
	freeze(storm)
	await capture("campaign_storm.png")
	storm.world_rules.storm_remaining = 0.01
	storm.world_rules.update(0.02)
	await capture("campaign_storm_flash.png")
	var fixture := config.default_values()
	fixture.display.window_width = 960
	fixture.display.window_height = 600
	fixture.display.viewport_width = 960
	fixture.display.viewport_height = 600
	config.use_values_for_tests(fixture)
	app.show_levels(5)
	await capture("campaign_levels_small.png")
	app.queue_free()
	for frame in 6:
		await process_frame
		await RenderingServer.frame_post_draw
	quit()
