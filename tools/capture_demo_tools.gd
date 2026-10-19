extends SceneTree
## Real rendering and input for the handheld shovel, removal and overview UI.


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


func _mouse(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = root.get_visible_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	for frame in 3:
		await physics_frame
	event = InputEventMouseButton.new()
	event.button_index = button
	root.push_input(event, true)


func _run() -> void:
	var app := load("res://scenes/game.tscn").instantiate() as GameApplication
	root.add_child(app)
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	app.show_demo()
	var switcher := app.content as StageSwitcher
	var demo := switcher.current_demo as StageDemo
	demo._dave.set_physics_process(false)
	demo._sun_system._timer.stop()
	for actor: Node in demo.get_node("Plants").get_children() + demo.get_node("Enemies").get_children():
		actor.set_physics_process(false)
	var plant := demo.get_node("Plants").get_child(0) as StagePlant
	demo._dave.global_position = plant.global_position + Vector3(-3.0, 0, 0)
	demo._dave.rotation.y = -PI * 0.5
	demo._dave.camera.look_at(plant.global_position + Vector3.UP * 0.72)
	await _mouse(MOUSE_BUTTON_WHEEL_UP)
	await _capture("demo_shovel.png")
	await _mouse(MOUSE_BUTTON_RIGHT)
	await _capture("demo_shovel_removed.png")
	demo._set_overview(true)
	await _capture("demo_shovel_overview.png")
	switcher.switch_stage(0)
	var legacy := switcher.current_demo
	legacy._dave.set_physics_process(false)
	legacy._dave.global_position = legacy._plant.global_position + Vector3(-3.0, 0, 0)
	legacy._dave.rotation.y = -PI * 0.5
	legacy._dave.camera.look_at(legacy._plant.global_position + Vector3.UP * 0.72)
	await _mouse(MOUSE_BUTTON_WHEEL_UP)
	await _capture("demo_shovel_legacy.png")
	app.queue_free()
	for frame in 10:
		await process_frame
		await RenderingServer.frame_post_draw
	quit()
